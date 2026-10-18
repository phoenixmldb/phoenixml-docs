---
title: Indexing
description: Name, path, value, full-text, structural, and metadata indexes
sort: 5
---

# Indexing

Indexes give PhoenixmlDb access paths into stored documents and their metadata. Six kinds can be declared on a container; how much each one is used today differs a lot, and [What uses each index today](#what-uses-each-index-today) says exactly which reads consult which index.

> **Note:** Indexes are declared once, at container-creation time, via `ContainerOptions.Indexes`. There is no API to add or drop an index against a container that already exists — see [Indexes are declared at creation time only](#indexes-are-declared-at-creation-time-only), below.

## Index Types

### Name Index

A name index records elements and attributes by name.

```csharp
var container = await db.CreateContainerAsync("products", opts =>
    opts.Indexes.AddNameIndex((string?)null));
```

Pass a namespace URI to restrict the index to names in that namespace, or `null` to index names in every namespace. `AddNameIndex` is overloaded for a `string?` or a `Uri?` namespace URI; `null` alone is ambiguous between the two, so cast it as shown, or pass an actual URI.

### Path Index

A path index records the nodes that match a path pattern.

```csharp
var container = await db.CreateContainerAsync("products", opts =>
    opts.Indexes.AddPathIndex("/product/price"));
```

**Multiple path patterns** are added with successive calls, chained fluently:

```csharp
opts.Indexes
    .AddPathIndex("/product/name")
    .AddPathIndex("/product/category")
    .AddPathIndex("/product/price");
```

### Value Index

A value index records the typed values found at a path.

```csharp
// Numeric value index on an attribute
opts.Indexes.AddValueIndex("/catalog/product/@price", XdmValueType.XdmDecimal);

// Date value index
opts.Indexes.AddValueIndex("/order/@orderDate", XdmValueType.Date);

// String value index
opts.Indexes.AddValueIndex("/customer/@name", XdmValueType.XdmString);
```

`AddValueIndex` also takes an optional `collation` argument.

**Value types** (`PhoenixmlDb.Core.XdmValueType`): `XdmString`, `XdmInteger`, `XdmLong`,
`XdmDecimal`, `XdmDouble`, `XdmFloat`, `Boolean`, `Date`, `DateTime`, `Time`, `Duration`, `AnyUri`,
`QName`, `Base64Binary`, `HexBinary`. Which comparisons each one answers is in the table below.

A value index changes how fast a query answers, never the answer: the same items, in the same order,
or the same error, as on a container with no index. A container query is evaluated once per
document; with a value index, the index names the documents that can hold a match and the query is
evaluated on those only.

**Queries that use it.** An index declared on `/order/@total` is used by a query that is a path from
the document root to `order` with one predicate on its last step, comparing `@total` with a literal or
a variable:

```xquery
/order[@total = 100]
/order[100 <= @total]
declare variable $v external; /order[@total = $v]
let $v := xs:decimal('99.50') return /order[@total = $v]
/order[@total = 100] ! string(@id)
/order[@total = 100]/string(@id)
```

- The steps are child steps with element names: no `//`, no `*`, no name in a namespace.
- The operator is `=`, `<`, `<=`, `>` or `>=`; or `eq` with a string literal.
- The path may be followed by `!` or by further steps, and may stand under `let` clauses and prolog
  variables. Every variable and `let` of the query has a constant value: a literal; a sequence,
  cast, arithmetic operation or concatenation of constants; an `xs:` constructor call on constants;
  another constant variable of the query; or it is external.
- Function declarations are allowed.
- A query that imports a module uses the index when the comparand is a literal, the query has no
  variable and no `let`, and every variable the imported modules declare has a constant value.

| Index type | Comparisons that use the index |
|---|---|
| `xs:integer`, `xs:long`, `xs:decimal`, `xs:double`, `xs:float` | `=` with a number or with text; `<`, `<=`, `>`, `>=` with a number |
| `xs:boolean` | `=` with a boolean or with text |
| `xs:string` | `=` with text |
| `xs:dateTime`, `xs:date`, `xs:time` | `=` with a string literal that is a value of the type ([Dates and Times](dates-and-times.md#value-indexes-on-dates-and-times)) |
| `xs:duration`, `xs:anyURI`, `xs:QName`, `xs:hexBinary`, `xs:base64Binary` | none |

A number is an `xs:integer`, `xs:decimal`, `xs:double` or `xs:float` value; text is an `xs:string`
or `xs:untypedAtomic` value; a variable is decided by the value it holds when the query runs. Whether
the index is used for a query it can answer is the planner's choice by cost: a comparison that selects
a large part of the container is evaluated on every document.

An index on element content, such as `/order/orderDate`, is maintained on every write, but no XQuery
query uses it: the planner offers a value index only for a predicate on an attribute of the last step
of the path, and a query that compares element content is answered by a scan. An embedded host that
holds the `IndexManager` (`PhoenixmlDb.Indexing`) can read any value index directly with
`IndexManager.QueryByValue(tx, container, pathPattern, value)`, which returns node ids; the two
servers do not expose it. On a container whose value indexes are in an earlier key format it throws
`InvalidOperationException` naming `DocumentDatabase.RebuildIndexesAsync`.

**Evaluated on every document**, with the answer of a container without the index:

- `count(/order[@total = 100])`, `exists(…)`, `if (…) then … else …` and any other expression around
  the path;
- `for $o in /order[@total = 100] return …`, with or without `order by`;
- a query with `fn:collection()` and an aggregate or `order by`;
- two predicates, `and` / `or`, a function of the attribute (`starts-with(@id, 'a')`), a predicate on
  a step that is not the last, a path that continues with `/` and a name after the predicate
  (`/order[@total = 100]/item`);
- `eq`, `lt`, `le`, `gt`, `ge` with a number or a variable; `!=`, `ne`;
- a typed constructor, arithmetic or a function call as the comparand (`@total = xs:decimal('100')`,
  `@flag = true()`);
- a name in a namespace, `*:order`, a query with `declare default element namespace`;
- `declare default collation` with any collation but the Unicode codepoint collation, also on an
  index declared with a collation;
- `<`, `<=`, `>`, `>=` on a string index, and with text on any index;
- a comparand that is a sequence, the empty sequence, a node, an `xs:anyURI`, a date, time or
  duration, or a CLR value of a type the XQuery library does not compare as a number (`Int16`,
  `Char`, `Uri`, `byte[]`);
- a number or boolean comparand while some document holds, at the indexed path, text that is not a
  number (not a boolean on a boolean index): the comparison raises `FORG0001`, with or without the
  index. An equality with text still uses the index;
- a variable or `let` whose value is not a constant, used in the comparison or not: a function call
  (`uri-collection()`, `collection()`, `doc()`, `current-dateTime()`, a declared or imported
  function), a path, a variable of an imported module, an external variable with a default that is
  not a constant;
- a query that declares the prefix `xs`, or a context item (`declare context item`);
- any query on a container whose indexes are stale (below).

A query that used an index is also evaluated on the first document of the container. An error the
query raises on every document (`let $v := xs:integer('abc')`) is raised with an index as without.

**Numeric and boolean indexes.** A numeric index holds every attribute value the XQuery library reads
as a number in a comparison: white space around it, a sign, a decimal point, an exponent, `INF`,
`-INF`, `NaN`. `1.5`, `+1.5`, `1.50`, `01.5` and `15E-1` are one value; `-0` and `0` are one value;
`NaN` equals no value and is in no range. A comparison of an attribute with a number also reads these
forms as numbers, with a value index and without one: a thousands separator (`1,000` is 1000),
`Infinity` and `-Infinity`, a number in parentheses (`(5)` is -5) and the generic currency sign
U+00A4 (`¤5` is 5). `$5` and `+INF` are not numbers. The five numeric index types hold the same values
and answer the same comparisons; values are compared as `xs:double`. A boolean index holds `true`,
`1`, `false` and `0`, with white space around them. `/order[@total = '1.50']` compares text: it
returns the documents whose attribute is written `1.50`.

**Writes.** A write is never refused because of a value index. A string longer than an index key is
stored and found by `=`. A value that is not of the index's type is stored; while a numeric or boolean
index covers such a value, comparisons with a number or boolean on that path are evaluated on every
document. The empty string is indexed in a string index.

**Result order.** The answer of a query that used an index is in the order of the answer without the
index: documents in the order of their names (the bytes of the UTF-8 name), and within a document in
document order. `QueryMetadataAsync` and `QueryMetadataRangeAsync` on a name with a metadata index
return documents in the order they return them without the index.

#### Indexes created by an earlier build

Value indexes have a key format, recorded per container; this build writes format 2. A container with
a value index created by an earlier build has format 1. On such a container:

- queries are evaluated on every document, and answer as they do without an index;
- the container's metadata and full-text indexes are used as before;
- writes are accepted and indexed;
- `DocumentDatabase.ContainersWithStaleIndexes()` lists the container;
- opening the database logs warning 1025 `ValueIndexesOutdated` once per container, naming the
  rebuild operations.

A rebuild writes the container's indexes in the current format; its queries then use them. A rebuild
holds the database write lock, so writes wait until it ends.

| Host | Rebuild |
|---|---|
| gRPC server | at startup, in the background, for every container with stale indexes; or `IndexService.RebuildIndex` |
| EPS REST server | `POST /api/containers/{containerId}/indexes/rebuild` |
| Embedded | `DocumentDatabase.RebuildIndexesAsync(containerName)`, or `RebuildStaleIndexesAsync()` for all |

A container without a value index is not affected. This build writes container records in record
format 5; an earlier build that reads a format 5 record fails with
`Unsupported container record version: 5`.

### Full-Text Index

Full-text indexes tokenize text content into a Lucene index stored inside LMDB, searched through `IndexManager.SearchFullText`. This is a large enough topic to have [its own page](full-text-search.md), covering the write path, the query-time staleness guarantee, and how to run and rebuild it.

```csharp
// Basic full-text index — every element in every document
opts.Indexes.AddFullTextIndex();

// Restricted to one path, with custom options
opts.Indexes.AddFullTextIndex("/product/description", new FullTextIndexOptions
{
    Language = "en",
    Stemming = true,
    CaseSensitive = false,
});
```

> **Note:** Indexing (of every kind, not just full-text) is opt-in *per process*: declaring `AddFullTextIndex` configures what should be indexed, but nothing is actually maintained until the process calls `db.EnableIndexing()`. See [Enabling indexing](#enabling-indexing), below.

### Structural Index

A structural index records parent-child relationships between nodes. It is enabled by default for every container.

```csharp
// On by default; turn it off for a container that doesn't need it.
opts.Indexes.EnableStructuralIndex(enabled: false);
```

XQuery axis navigation does not read the structural index; it walks the stored node tree. The index is reachable through `IndexManager` (`GetChildren`, `GetParent`, `GetDescendants`, `GetAncestors`).

### Metadata Index

A metadata index records document metadata values. Because metadata names are qualified names (`XdmQName`), not bare strings, the index is declared against a qualified name too. See [Metadata](metadata.md) for how metadata is namespaced.

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Xdm;

const string appNs = "urn:example:app";
var ns = db.GetOrCreateNamespaceId(appNs);

var container = await db.CreateContainerAsync("products", opts =>
{
    // Unqualified names passed to SetMetadataAsync(doc, "author", ...) land in this namespace,
    // so the index below covers them.
    opts.DefaultMetadataNamespace = appNs;
    opts.Indexes
        .AddMetadataIndex(new XdmQName(ns, "author"), XdmValueType.XdmString)
        .AddMetadataIndex(new XdmQName(ns, "created"), XdmValueType.DateTime);
});
```

The name must match the stored name exactly, namespace included. A container that sets no `DefaultMetadataNamespace` stores unqualified names in `https://schemas.phoenixml.dev/2026/app` (`Container.DefaultApplicationMetadataNamespace`), not in no namespace, so an index on `new XdmQName(NamespaceId.None, "author")` would not cover them.

**Reads that use it:** `IContainer.QueryMetadataAsync` and `QueryMetadataRangeAsync`. `phx:metadata()` in XQuery does not consult it.

```csharp
await foreach (var info in container.QueryMetadataAsync(
    new XdmQName(ns, "author"), XdmValue.From("admin")))
{
    Console.WriteLine(info.Name);
}
```

## Creating Indexes

### Indexes are declared at creation time only

Every index type above is configured through the same fluent `ContainerOptions.Indexes` builder, passed to `CreateContainerAsync` (or `OpenOrCreateContainerAsync`):

```csharp
var container = await db.CreateContainerAsync("products", opts =>
{
    opts.Indexes
        .AddNameIndex((string?)null)
        .AddPathIndex("/product/name")
        .AddPathIndex("/product/category")
        .AddValueIndex("/product/price", XdmValueType.XdmDecimal)
        .AddFullTextIndex("/product/description");
});
```

There is no equivalent of adding or dropping an index against a container that already exists — indexes are part of a container's configuration, fixed at creation. Documents inserted afterward are indexed automatically (once indexing is enabled — see below); documents that existed before an index was declared are not retroactively indexed until you [rebuild](#rebuilding-and-stale-indexes). If your requirements change, create a new container with the index configuration you need and migrate documents into it.

### Enabling indexing

Declaring `opts.Indexes` only records what *should* be indexed. Nothing is actually maintained — for any index type — until the process calls:

```csharp
var manager = db.EnableIndexing();
```

`EnableIndexing()` is an extension method on `DocumentDatabase` (`PhoenixmlDb.Indexing`). It returns an `IndexManager`, which is also where the full-text-specific operations live (searching, draining the queue, and so on — see [Full-Text Search](full-text-search.md)). It is idempotent: a second call on the same database returns the manager already attached. The database owns the manager and disposes it. Don't call it while holding a transaction from `BeginWriteAsync`: it may need the database's write lock, which is not reentrant, and would block forever.

Without `EnableIndexing()`, queries still return correct results: `ContainerOptions.Indexes` is declarative-only until indexing is turned on, and every read falls back to a scan.

## Managing Indexes

### Rebuilding and stale indexes

A container's indexes can become **stale**: written to while indexing was not enabled for the process, or last touched by an engine version that predates a given index. Find out which containers need attention:

```csharp
IReadOnlyList<string> stale = db.ContainersWithStaleIndexes();
```

A container whose full-text index cannot be read is listed too ([Full-Text Search: An index that cannot be read](full-text-search.md#an-index-that-cannot-be-read)).

Rebuild a container's indexes from its stored documents:

```csharp
var result = await db.RebuildIndexesAsync("products");
// result.DocumentsIndexed, result.EntriesRemoved, result.EntriesWritten
```

`RebuildStaleIndexesAsync()` rebuilds every container `ContainersWithStaleIndexes()` lists and returns the results by container name. Until a stale container is rebuilt, reads against it scan instead of using its indexes.

`RebuildIndexesAsync` requires `EnableIndexing()` to have been called first (it throws `InvalidOperationException` otherwise). It runs in one write transaction holding the database's write lock, so writes to every container wait for it; don't call it while holding a transaction from `BeginWriteAsync`. It clears the container's previous index entries, walks every stored document, and re-indexes (or, for full-text, re-enqueues) each one — see [Rebuilding](full-text-search.md#rebuilding) for the full-text-specific guarantees this gives you immediately, before any drain.

## What uses each index today

Index use is automatic: there is no index hint or `pragma` syntax. An index changes how fast a read answers, never what it answers. Every index kind is maintained on write once indexing is enabled, but the readers that consult them are fewer:

| Index | Consulted by |
|-------|--------------|
| Value | XQuery, only for `/a/b[@attr op value]` against an index on `/a/b/@attr` (see [Value Index](#value-index)); `IndexManager.QueryByValue` |
| Full-text | `IndexManager.SearchFullText` |
| Metadata | `IContainer.QueryMetadataAsync`, `QueryMetadataRangeAsync` |
| Name | `IndexManager.QueryElements`, `QueryAttributes` only; not XQuery |
| Path | `IndexManager.QueryByPath` only; not XQuery |
| Structural | `IndexManager.GetChildren`, `GetParent`, `GetDescendants`, `GetAncestors` only; not XQuery |

A name, path or structural index therefore costs write time and storage without speeding up any XQuery today.

## Best Practices

**Do:**

1. **Index for the reads that consult the index** — see [What uses each index today](#what-uses-each-index-today).
2. **Use appropriate value types** — match `XdmValueType` to your data so range comparisons are typed correctly, not lexicographic.
3. **Declare all the indexes a container needs up front** — there is no way to add one later without recreating the container.
4. **Rebuild after enabling indexing on documents written before it was on** — otherwise those documents are correct but silently unindexed until you do.

**Don't:**

1. **Over-index** — each index adds storage and write overhead, and full-text indexing in particular moves work onto a background queue that still has to drain.
2. **Expect a name, path or structural index to speed up XQuery** — none of them is read by the query path yet.
3. **Assume `AddFullTextIndex()` with no path pattern means "the document as a whole"** — it means every element; see [the warning on that page](full-text-search.md#declaring-a-full-text-index).

## Next Steps

| Concepts | Execution | Reference |
|----------|-----------|-----------|
| **[Full-Text Search](full-text-search.md)**<br>The Lucene-backed full-text index in depth | **[Metadata](metadata.md)**<br>Qualified metadata and metadata indexes | **[Indexes API](api-reference/indexes.md)**<br>Full configuration reference |
