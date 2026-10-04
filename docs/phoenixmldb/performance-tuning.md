---
title: Performance Tuning
description: Query optimization, storage tuning, memory management, and monitoring
sort: 10
---

# Performance Tuning

What the engine actually does on the paths that matter for performance, and the settings that change it. There are no published benchmark figures here: measure your own workload (see [Benchmarking](#benchmarking)).

## Query Optimization

### Use Indexes Where the Query Path Reads Them

Indexes are declared when a container is created and maintained once the process calls `db.EnableIndexing()`:

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Indexing;
using PhoenixmlDb.Storage;

using var db = new DocumentDatabase("./data");
db.EnableIndexing();

var products = await db.CreateContainerAsync("products", opts =>
    opts.Indexes.AddValueIndex("/catalog/product/@price", XdmValueType.XdmDecimal));

// Answered from the value index
await foreach (var p in products.QueryAsync("/catalog/product[@price > 100]"))
{
    Console.WriteLine(p);
}
```

Today XQuery reads only value indexes, and only for one shape: an absolute path of child steps whose last step has a single predicate comparing an attribute to a literal or variable, against a value index on exactly that attribute path. Every other query scans the container's documents. Metadata indexes speed up `QueryMetadataAsync`/`QueryMetadataRangeAsync`, and full-text indexes back `IndexManager.SearchFullText`. See [Indexing](indexing.md#what-uses-each-index-today) for the full list before adding an index for speed.

### Know How a Container Query Runs

`IContainer.QueryAsync` classifies each query when it compiles it:

- **Row-wise** queries (a per-document filter, map or projection) are compiled once and run against each document in turn, with that document as the context item. Results are concatenated in document order.
- **Cross-document** queries (`sum`/`avg`/`min`/`max` over the collection, `count(collection())`, `distinct-values` across documents, a FLWOR `order by` or `group by`) run as one evaluation in which `fn:collection()` is every document in the container.

Either way, without a usable index every document in the container is visited. Keeping unrelated documents in separate containers reduces what a scan has to touch.

### Use Variables

Bind values as external variables instead of concatenating them into the query text:

```csharp
var variables = new Dictionary<string, object> { ["cat"] = "Electronics" };

await foreach (var p in products.QueryAsync("""
    declare variable $cat external;
    //product[category = $cat]
    """, variables))
{
    Console.WriteLine(p);
}
```

This also avoids XQuery injection. The value-index shape above accepts a variable as the comparand (`/catalog/product[@price > $min]`).

## Storage Optimization

### Map Size

`LmdbStorageOptions.MapSize` is the fixed virtual address-space reservation for the memory map. The default is 50 GiB in a 64-bit process and 1 GiB in a 32-bit one. It reserves address space, not memory or disk: the data file grows only as data is written. The engine never grows the map at runtime, so when it fills, writes fail with a `PhoenixmlDbStorageException` (MDB_MAP_FULL) until the database is reopened with a larger `MapSize`:

```csharp
using PhoenixmlDb.Storage.Lmdb;

using var db = new DocumentDatabase("./data", new LmdbStorageOptions
{
    MapSize = 200L * 1024 * 1024 * 1024 // 200 GiB
});
```

Opening an existing database with a `MapSize` at or below the size its data already uses throws `LmdbMapSizeTooSmallException`.

### Sync Mode

```csharp
// For bulk loads of data you can regenerate
using var db = new DocumentDatabase("./data", new LmdbStorageOptions
{
    NoSync = true // LMDB MDB_NOSYNC: no fsync on commit
});
```

`NoSync` skips flushing to disk on commit, at the cost of durability: committed data can be lost in a system crash. `DocumentDatabase.FlushAsync()` forces a flush. There is no separate metadata-only sync setting.

### Batch Writes

Every direct container write is its own LMDB commit. For many documents, use `PutDocumentsAsync`, which commits in chunks of up to 1,000, or one write transaction when they must commit together:

```csharp
// Good - one commit per 1,000 documents
await container.PutDocumentsAsync(
    documents.Select(d => new DocumentInput(d.Name, d.Content)));

// Good - one commit for the whole group, all or nothing
await using (var txn = await db.BeginWriteAsync())
{
    foreach (var d in documents)
    {
        await txn.PutDocumentAsync(container.Id, d.Name, d.Content);
    }
    await txn.CommitAsync();
}

// Slower - one commit per document
foreach (var d in documents)
{
    await container.PutDocumentAsync(d.Name, d.Content);
}
```

A write transaction buffers every operation in memory until `CommitAsync`, so very large groups cost memory.

## Memory Management

### Keep Write Transactions Short

Only one `IWriteTransaction` can be open per database. While it is open, other `BeginWriteAsync` calls, `CreateContainerAsync`, `DeleteContainerAsync` and `RebuildIndexesAsync` wait for it. Commit or dispose promptly:

```csharp
// Good - prepare first, then open, buffer and commit
var xml = BuildDocument();
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(container.Id, "doc.xml", xml);
    await txn.CommitAsync();
}
```

`IReadTransaction` holds no LMDB transaction or lock, so keeping one open costs nothing; it also provides no snapshot across calls (see [Transactions](transactions.md#read-transactions)).

### Large Documents

`IDocument.GetContentAsync` and `GetContentStreamAsync` both serialize the whole document from its stored node tree; the stream is an in-memory buffer over that result, not a streaming read. Query a document for the parts you need rather than fetching it whole:

```csharp
await foreach (var title in container.QueryAsync("/book/chapter/title/string()"))
{
    Console.WriteLine(title);
}
```

## Index Tuning

### Choose Indexes the Engine Reads

Each declared index adds write work and storage. A name, path or structural index is maintained on every write but not read by XQuery today, and the structural index is enabled by default. A container that never uses `IndexManager`'s structural lookups can turn it off at creation:

```csharp
var container = await db.CreateContainerAsync("events", opts =>
    opts.Indexes.EnableStructuralIndex(enabled: false));
```

### Index Maintenance

Indexes can't be added to, or dropped from, an existing container. A container written while indexing was not enabled becomes stale, and reads against it scan until it is rebuilt:

```csharp
foreach (var name in db.ContainersWithStaleIndexes())
{
    var result = await db.RebuildIndexesAsync(name);
    Console.WriteLine($"{name}: {result.DocumentsIndexed} documents, {result.EntriesWritten} entries");
}
```

`RebuildStaleIndexesAsync()` does the same for every stale container. A rebuild holds the database write lock and re-reads every document in the container, so schedule it for large containers. See [Indexing](indexing.md#rebuilding-and-stale-indexes).

## Monitoring

### Database Statistics

```csharp
DatabaseStatistics stats = db.Statistics;
Console.WriteLine($"Containers: {stats.ContainerCount}");
Console.WriteLine($"Documents: {stats.TotalDocumentCount}");
Console.WriteLine($"Nodes: {stats.TotalNodeCount}");

StorageUsage usage = db.GetStorageUsage();
Console.WriteLine($"Map: {usage.UsedBytes / 1024 / 1024} MB of {usage.MapSize / 1024 / 1024} MB ({usage.PercentUsed:F1}%)");
```

`db.GetHealth()` returns the same map figures as a `StorageHealth` and never throws.

### Metrics and Traces

The engine publishes `System.Diagnostics.Metrics` instruments and `ActivitySource` traces, including a per-container `db.client.operation.duration` histogram for queries, puts, gets and deletes, and map usage against the map limit. Read them with any `MeterListener`, `dotnet-counters` or OpenTelemetry. The names and tags are listed in [Logging and Telemetry](logging.md#metrics-and-traces).

## Benchmarking

### Measure Operations

```csharp
var sw = Stopwatch.StartNew();

for (int i = 0; i < iterations; i++)
{
    await foreach (var _ in container.QueryAsync(xquery))
    {
    }
}

sw.Stop();
Console.WriteLine($"Avg: {sw.Elapsed.TotalMilliseconds / iterations:F2} ms/query");
```

Enumerate the results: `QueryAsync` does its work as the sequence is consumed.

### Compare Approaches

Indexes are fixed at container creation, so compare configurations by creating one container per configuration and loading the same documents into each:

```csharp
var configs = new (string Name, Action<ContainerOptions> Configure)[]
{
    ("no-index", _ => { }),
    ("value-index", o => o.Indexes.AddValueIndex("/a/b/@id", XdmValueType.XdmString)),
};

foreach (var (name, configure) in configs)
{
    var c = await db.CreateContainerAsync($"bench-{name}", configure);
    await c.PutDocumentsAsync(testDocuments);
    var time = await BenchmarkQueryAsync(c, query);
    Console.WriteLine($"{name}: {time}");
}
```

Call `db.EnableIndexing()` before loading, or the indexed container is stale and scans like the other.

## Common Bottlenecks

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Slow queries | Full scan of the container | Check whether an index the query path reads applies; split containers |
| High memory | Large write transactions | Use smaller batches, or `PutDocumentsAsync` |
| Slow writes | One commit per document | Batch writes; `NoSync` only for recoverable data |
| Writes waiting | Long-lived write transaction | Keep write transactions short |
| `MDB_MAP_FULL` | Map reservation exhausted | Reopen with a larger `MapSize` |

## Best Practices Summary

1. **Index for the readers that use indexes** — see [Indexing](indexing.md#what-uses-each-index-today)
2. **Enable indexing** at startup, and rebuild stale containers
3. **Batch writes** — `PutDocumentsAsync` or one write transaction
4. **Keep write transactions short**
5. **Bind variables** instead of building query text
6. **Monitor** the storage metrics and map usage
