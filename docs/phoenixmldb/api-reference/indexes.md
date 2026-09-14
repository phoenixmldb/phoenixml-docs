---
title: Indexes API
description: Index configuration, enabling indexing, rebuilding, and the full-text search surface
sort: 3
---

# Index API

Indexes are configured on `ContainerOptions.Indexes` — a fluent `IndexConfiguration` builder (`PhoenixmlDb.Core`) — when a container is created. There is no live API to add, drop, list, or inspect an index against a container that already exists; a container's index set is fixed at creation. See [Indexing](../indexing.md) for a conceptual walkthrough and [Full-Text Search](../full-text-search.md) for the full-text index in depth.

## `IndexConfiguration`

Reached via `ContainerOptions.Indexes` inside the `configure` delegate passed to `CreateContainerAsync` / `OpenOrCreateContainerAsync`. Every `Add*Index` method returns `this`, so calls chain.

### AddNameIndex

```csharp
IndexConfiguration AddNameIndex(string? namespaceUri = null)
IndexConfiguration AddNameIndex(Uri? namespaceUri = null)
```

Speeds up element/attribute name lookups. Pass a namespace URI to restrict the index to that namespace, or `null` to index names in every namespace. Because both overloads default to `null`, calling `AddNameIndex()` with no argument is ambiguous (`CS0121`) — pass an explicit `(string?)null` / `(Uri?)null`, or a real URI.

```csharp
opts.Indexes.AddNameIndex((string?)null);
```

### AddPathIndex

```csharp
IndexConfiguration AddPathIndex(string pathPattern)
```

Speeds up path expression evaluation. `pathPattern` is an XPath-like pattern: `/` (child), `//` (descendant-or-self), `@` (attribute), `*` (wildcard) — e.g. `"/product/name"`, `"//customer/address"`. Call it once per path; there is no multi-path overload, so index several paths with successive chained calls:

```csharp
opts.Indexes
    .AddPathIndex("/product/name")
    .AddPathIndex("/product/category");
```

### AddValueIndex

```csharp
IndexConfiguration AddValueIndex(string pathPattern, XdmValueType valueType, string? collation = null)
```

Enables typed range queries and sorting. `valueType` is `PhoenixmlDb.Core.XdmValueType`:

```
XdmString, XdmInteger, XdmLong, XdmDecimal, XdmDouble, XdmFloat,
Boolean, DateTime, Date, Time, Duration, AnyUri, QName,
Base64Binary, HexBinary
```

```csharp
opts.Indexes.AddValueIndex("/product/price", XdmValueType.XdmDecimal);
```

`collation` is `null` (binary/codepoint comparison) unless you need locale-aware string ordering.

### AddFullTextIndex

```csharp
IndexConfiguration AddFullTextIndex(string? pathPattern = null, FullTextIndexOptions? options = null)
```

Declares a Lucene-backed full-text index — see [Full-Text Search](../full-text-search.md) for the write path, staleness guarantee, and operational detail this page doesn't repeat. `pathPattern` of `null` indexes **every element**, not the document as a whole.

```csharp
opts.Indexes.AddFullTextIndex("/product/description", new FullTextIndexOptions
{
    Language = "en",
    Stemming = true,
    CaseSensitive = false,
});
```

`FullTextIndexOptions` (`PhoenixmlDb.Core`):

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `Language` | `string` | `"en"` | |
| `CaseSensitive` | `bool` | `false` | |
| `Stemming` | `bool` | `true` | |
| `StopWords` | `IReadOnlySet<string>?` | `null` | **Accepted but has no effect** — nothing reads it yet. |

### AddMetadataIndex

```csharp
IndexConfiguration AddMetadataIndex(XdmQName metadataName, XdmValueType valueType = XdmValueType.XdmString)
IndexConfiguration AddMetadataIndex<T>(MetadataProperty<T> descriptor, XdmValueType valueType = XdmValueType.XdmString)
```

Enables efficient queries by document metadata key/value. The name is a qualified `XdmQName` (`PhoenixmlDb.Xdm`), not a bare string — metadata itself is namespaced (see [Metadata](../metadata.md)), and an index declared for one namespace's key does not answer for another's.

```csharp
using PhoenixmlDb.Xdm;

opts.Indexes.AddMetadataIndex(new XdmQName(NamespaceId.None, "status"), XdmValueType.XdmString);
```

### EnableStructuralIndex

```csharp
IndexConfiguration EnableStructuralIndex(bool enabled = true)
```

Controls the parent-child/sibling index that accelerates axis navigation (`parent::`, `ancestor::`, `following-sibling::`, ...). Enabled by default; disable only for containers that are never navigated with XQuery axis steps.

## Enabling and running indexing

### `DocumentDatabase.EnableIndexing()`

```csharp
// PhoenixmlDb.Indexing
public static IndexManager EnableIndexing(this DocumentDatabase db)
```

Declaring indexes in `ContainerOptions.Indexes` only records configuration; nothing is maintained until the owning process calls this once per `DocumentDatabase`. Returns the `IndexManager` used for rebuilds and for every full-text operation below.

```csharp
using var db = DocumentDatabase.Open(dbPath);
var manager = db.EnableIndexing();
```

### `DocumentDatabase.RebuildIndexesAsync`

```csharp
ValueTask<IndexRebuildResult> RebuildIndexesAsync(string containerName, CancellationToken cancellationToken = default)
```

Requires `EnableIndexing()` to have been called first. Clears the container's previous index entries, walks every stored document, and re-indexes each one — clearing the container's stale flag as part of the same commit.

```csharp
var result = await db.RebuildIndexesAsync("products");
// result.DocumentsIndexed, result.EntriesRemoved, result.EntriesWritten
```

`IndexRebuildResult` is `readonly record struct IndexRebuildResult(long DocumentsIndexed, long EntriesRemoved, long EntriesWritten)`.

### `DocumentDatabase.ContainersWithStaleIndexes()`

```csharp
IReadOnlyList<string> ContainersWithStaleIndexes()
```

Names every container whose indexes need a rebuild: written to while indexing was disabled, or last touched by an engine version that predates one of its declared indexes.

## Full-text search (`IndexManager`)

These members live on the `IndexManager` returned by `EnableIndexing()`. Full detail, including the exactness guarantee while the background worker lags, is on the [Full-Text Search](../full-text-search.md) page — this is the member-by-member reference.

| Member | Signature | Purpose |
|--------|-----------|---------|
| `SearchFullText` | `IReadOnlyList<FullTextSearchHit> SearchFullText(ContainerId container, string text, int limit = 100)` | Search; throws `InvalidOperationException` if the container's indexes are stale. |
| `PendingFullTextDocuments` | `IReadOnlyCollection<DocumentId> PendingFullTextDocuments(ContainerId container)` | Documents the Lucene index does not yet (or no longer) correctly reflect. |
| `CountFullTextIndexEntries` | `long CountFullTextIndexEntries(ContainerId container)` | Diagnostic: entries currently held in the Lucene index. |
| `DrainFullTextQueueAsync` | `Task<int> DrainFullTextQueueAsync(DocumentDatabase db, int batchSize = 500, CancellationToken ct = default)` | Applies up to `batchSize` queued documents in one LMDB write transaction; returns the count indexed. |
| `StartFullTextIndexing` | `IAsyncDisposable StartFullTextIndexing(DocumentDatabase db, FullTextIndexingOptions? options = null)` | Starts a background drain loop; disposing stops it and awaits completion. |

`FullTextSearchHit` is `readonly record struct FullTextSearchHit(DocumentId Document, NodeId Node, double Score)`.

`FullTextIndexingOptions` (`PhoenixmlDb.Indexing`) controls the background loop:

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `BatchSize` | `int` | `500` | Maximum queued documents applied per drain. |
| `Budget` | `TimeSpan` | `2s` | Per-batch time budget; bounds worst-case shutdown latency. |
| `IdleDelay` | `TimeSpan` | `500ms` | How long the loop waits after a batch drains nothing. |

## Error Handling

`SearchFullText` throws `InvalidOperationException` when the container's indexes are stale — call `RebuildIndexesAsync` first (see [Rebuilding](../full-text-search.md#rebuilding)). `RebuildIndexesAsync` throws `InvalidOperationException` if `EnableIndexing()` was never called. Beyond those two, index configuration errors surface as ordinary argument validation on `IndexConfiguration`'s `Add*Index` methods (e.g. a `null` required path pattern) — there is no dedicated `IndexExistsException` / `InvalidIndexDefinitionException` family, because there is no live create/drop to raise them against.

## Next Steps

| Concepts | Execution | Optimization |
|----------|-----------|--------------|
| **[Indexing](../indexing.md)**<br>Indexing concepts | **[Queries API](queries.md)**<br>Query execution | **[Full-Text Search](../full-text-search.md)**<br>The full-text index in depth |
