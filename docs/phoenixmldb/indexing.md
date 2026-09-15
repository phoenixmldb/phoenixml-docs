---
title: Indexing
description: Name, path, value, full-text, structural, and metadata indexes
sort: 5
---

# Indexing

Indexes dramatically improve query performance by providing fast access paths to your data. PhoenixmlDb supports multiple index types optimized for different query patterns.

> **Note:** Indexes are declared once, at container-creation time, via `ContainerOptions.Indexes`. There is no API to add or drop an index against a container that already exists — see [Indexes are declared at creation time only](#indexes-are-declared-at-creation-time-only), below.

## Index Types

### Name Index

Name indexes accelerate queries that look up elements or attributes by name, such as `//product`.

```csharp
var container = await db.CreateContainerAsync("products", opts =>
    opts.Indexes.AddNameIndex((string?)null));
```

Pass a namespace URI to restrict the index to names in that namespace, or `null` to index names in every namespace. `AddNameIndex` is overloaded for a `string?` or a `Uri?` namespace URI; `null` alone is ambiguous between the two, so cast it as shown, or pass an actual URI.

### Path Index

Path indexes accelerate queries that navigate to specific elements or attributes by path.

```csharp
var container = await db.CreateContainerAsync("products", opts =>
    opts.Indexes.AddPathIndex("/product/price"));

// Queries that benefit:
// - collection('products')/product/price
// - collection('products')//product/price
// - $doc/product/price
```

**Multiple path patterns** are added with successive calls, chained fluently:

```csharp
opts.Indexes
    .AddPathIndex("/product/name")
    .AddPathIndex("/product/category")
    .AddPathIndex("/product/price");
```

### Value Index

Value indexes enable efficient range queries and sorting on typed values.

```csharp
// Numeric value index
opts.Indexes.AddValueIndex("/product/price", XdmValueType.XdmDecimal);

// Date value index
opts.Indexes.AddValueIndex("/order/orderDate", XdmValueType.Date);

// String value index
opts.Indexes.AddValueIndex("/customer/name", XdmValueType.XdmString);
```

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

**Queries that benefit:**
```xquery
(: Range queries :)
//product[price > 10 and price < 100]

(: Sorting :)
for $p in //product order by $p/price return $p
```

### Full-Text Index

Full-text indexes tokenize text content into a Lucene index stored inside LMDB, so it can be searched without a full document scan. This is a large enough topic to have [its own page](full-text-search.md), covering the write path, the query-time staleness guarantee, and how to run and rebuild it.

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

Structural indexes maintain parent-child and sibling relationships between nodes, accelerating navigation queries (parent, child, sibling, ancestor, descendant). They are enabled by default for every container.

```csharp
// Structural indexing is on by default — disable it only for append-only
// containers that are never navigated with XQuery axis steps.
opts.Indexes.EnableStructuralIndex(enabled: false);
```

**Queries that benefit:**
```xquery
(: Parent/child navigation :)
$element/parent::*
$element/child::item

(: Ancestor/descendant :)
$element/ancestor::section
$element//nested-item

(: Sibling navigation :)
$element/following-sibling::*
$element/preceding-sibling::*
```

### Metadata Index

Metadata indexes allow efficient queries on document metadata. Because metadata keys are qualified names (`XdmQName`), not bare strings, the index is declared against a qualified name too — see [Metadata](metadata.md) for how metadata itself is namespaced.

```csharp
using PhoenixmlDb.Xdm;

opts.Indexes.AddMetadataIndex(new XdmQName(NamespaceId.None, "author"), XdmValueType.XdmString);
opts.Indexes.AddMetadataIndex(new XdmQName(NamespaceId.None, "created"), XdmValueType.DateTime);
```

**Queries that benefit:**
```xquery
(: Filter by metadata :)
for $doc in collection('products')
where doc-metadata($doc, 'author') = 'admin'
return $doc
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

`EnableIndexing()` is an extension method on `DocumentDatabase` (`PhoenixmlDb.Indexing`). It returns an `IndexManager`, which is also where the full-text-specific operations live (searching, draining the queue, and so on — see [Full-Text Search](full-text-search.md)). Call it once per `DocumentDatabase`; a second call would build independent state rather than reuse the first.

Without `EnableIndexing()`, queries still return correct results — `ContainerOptions.Indexes` is declarative-only until indexing is turned on, and every query falls back to a scan.

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

`RebuildIndexesAsync` requires `EnableIndexing()` to have been called first. It clears the container's previous index entries, walks every stored document, and re-indexes (or, for full-text, re-enqueues) each one — see [Rebuilding](full-text-search.md#rebuilding) for the full-text-specific guarantees this gives you immediately, before any drain.

## Query Optimization

The query optimizer chooses among the declared indexes automatically based on the shape of each query — there is no manual index hint or `pragma` syntax. `//product[price > 100]` uses a value index on `price` if one is declared; without one, it scans. This is why declaring the right indexes for your actual query patterns, rather than indexing everything, matters: an index changes how fast a query answers, never what it answers, so over-indexing only costs storage and write throughput.

## Index Selection Guidelines

| Query Pattern | Recommended Index |
|---------------|-------------------|
| Look up by element/attribute name | Name Index |
| Navigate to a specific path | Path Index |
| Range comparison (`<`, `>`, `between`) | Value Index |
| Sorting (`order by`) | Value Index |
| Full-text search via `IndexManager.SearchFullText` | Full-Text Index |
| Tree navigation (parent, ancestor, sibling) | Structural Index (on by default) |
| Metadata filtering | Metadata Index |

## Best Practices

**Do:**

1. **Index frequently queried paths** — start with your most common queries.
2. **Use appropriate value types** — match `XdmValueType` to your data so range comparisons are typed correctly, not lexicographic.
3. **Declare all the indexes a container needs up front** — there is no way to add one later without recreating the container.
4. **Rebuild after enabling indexing on documents written before it was on** — otherwise those documents are correct but silently unindexed until you do.

**Don't:**

1. **Over-index** — each index adds storage and write overhead, and full-text indexing in particular moves work onto a background queue that still has to drain.
2. **Index rarely queried paths** — unused indexes waste resources without ever paying for themselves.
3. **Assume `AddFullTextIndex()` with no path pattern means "the document as a whole"** — it means every element; see [the warning on that page](full-text-search.md#declaring-a-full-text-index).

## Next Steps

| Concepts | Execution | Reference |
|----------|-----------|-----------|
| **[Full-Text Search](full-text-search.md)**<br>The Lucene-backed full-text index in depth | **[Metadata](metadata.md)**<br>Qualified metadata and metadata indexes | **[Indexes API](api-reference/indexes.md)**<br>Full configuration reference |
