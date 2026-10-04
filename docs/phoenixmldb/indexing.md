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

A value index records the typed values found at a path, so equality and range lookups compare them as numbers, dates and so on rather than as text.

```csharp
// Numeric value index on an attribute
opts.Indexes.AddValueIndex("/catalog/product/@price", XdmValueType.XdmDecimal);

// Date value index
opts.Indexes.AddValueIndex("/order/orderDate", XdmValueType.Date);

// String value index
opts.Indexes.AddValueIndex("/customer/name", XdmValueType.XdmString);
```

`AddValueIndex` also takes an optional `collation` argument.

**Supported value types** (`PhoenixmlDb.Core.XdmValueType`):

| XdmValueType | Use Case |
|--------------|----------|
| `XdmString` | Text comparisons, sorting |
| `XdmInteger` | Whole number ranges |
| `XdmLong` | Large whole number ranges |
| `XdmDecimal` | Precise decimal ranges |
| `XdmDouble` / `XdmFloat` | Scientific calculations |
| `Date` / `DateTime` / `Time` | Date and time ranges |
| `Boolean` | True/false filtering |
| `Duration`, `AnyUri`, `QName`, `Base64Binary`, `HexBinary` | Typed equality and ordering for the corresponding XSD type |

**Queries that use it:** only one shape, today. The index must be declared on an attribute at the end of a path of plain child steps (`/catalog/product/@price`, not `//product/@price` or `/catalog/*/@price`), and the query must be an absolute path to those same elements with a single predicate comparing that attribute to a literal or a variable, using `=`, `eq`, `<`, `<=`, `>`, `>=`, `lt`, `le`, `gt` or `ge`:

```xquery
/catalog/product[@price > 100]
/catalog/product[@price = $price]
```

Anything else, including a value index on element content such as `/order/orderDate`, a `//` step, a second predicate, `order by`, or a path that starts from `collection()`, is evaluated by scanning. A value index on element content is still maintained, and `IndexManager.QueryByValue` can read it directly; XQuery does not use it yet.

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
