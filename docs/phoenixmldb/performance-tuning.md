---
title: Performance Tuning
description: Query optimization, storage tuning, memory management, and monitoring
sort: 9
---

# Performance Tuning

Optimize PhoenixmlDb for your specific workload with these tuning guidelines.

## Query Optimization

### Use Indexes

The most important optimization is proper indexing:

```csharp
// Create indexes for frequently queried paths
container.CreateIndex(new PathIndex("product-idx",
    "/product/name", "/product/category"));

container.CreateIndex(new ValueIndex("price-idx",
    "/product/price", ValueType.Decimal));
```

### Check Query Plans

```csharp
var plan = db.Explain(query);
Console.WriteLine(plan);

// Verify indexes are used
if (!plan.IndexesUsed.Any())
{
    Console.WriteLine("Warning: Full scan, consider adding indexes");
}
```

### Optimize XQuery

```xquery
(: Good - filter early :)
for $p in collection('products')//product[category = 'Electronics']
where $p/price > 100
return $p

(: Less efficient - filter late :)
for $p in collection('products')//product
where $p/category = 'Electronics' and $p/price > 100
return $p
```

### Limit Results

```xquery
(: Always limit when you don't need all results :)
(for $p in collection('products')//product
 order by $p/date descending
 return $p)[position() <= 100]
```

### Use Parameters

```csharp
// Good - compiled once, parameters bound
var prepared = db.Prepare("""
    for $p in //product where $p/category = $cat return $p
    """);
var results = prepared.Execute(new QueryParameters { ["cat"] = "Electronics" });

// Bad - recompiled every time
var results = db.Query($"for $p in //product where $p/category = '{category}' return $p");
```

## Storage Optimization

### Appropriate Map Size

```csharp
// Too small causes "map full" errors
// Too large wastes address space
var options = new DatabaseOptions
{
    MapSize = dataSize * 2  // 2x expected data size
};
```

### Sync Mode

```csharp
// For highest performance (reduced durability)
var options = new DatabaseOptions
{
    NoMetaSync = true  // ~10% faster commits
};

// For bulk imports (recoverable data)
var options = new DatabaseOptions
{
    NoSync = true  // ~50% faster, but data at risk
};
```

### Batch Writes

```csharp
// Good - single transaction for multiple writes
using (var txn = db.BeginTransaction())
{
    foreach (var doc in documents)
    {
        container.PutDocument(doc.Name, doc.Content);
    }
    txn.Commit();
}

// Bad - separate transaction for each write
foreach (var doc in documents)
{
    container.PutDocument(doc.Name, doc.Content);
}
```

## Memory Management

### Read-Only Transactions

```csharp
// Prefer read-only - no write locks, concurrent access
using (var txn = db.BeginTransaction(readOnly: true))
{
    // Multiple concurrent readers allowed
}
```

### Dispose Promptly

```csharp
// Good - dispose immediately
using (var txn = db.BeginTransaction(readOnly: true))
{
    var result = txn.Query(xquery);
    ProcessResults(result.ToList());
}

// Bad - holding transaction open
var txn = db.BeginTransaction(readOnly: true);
var result = txn.Query(xquery);
// ... long processing ...
txn.Dispose();  // Blocks other writers
```

### Stream Large Documents

```csharp
// Good - streaming for large documents
using var stream = container.GetDocumentAsStream("large.xml");
ProcessStream(stream);

// Bad - loads entire document into memory
var xml = container.GetDocument("large.xml");
```

## Index Tuning

### Index Selectivity

High-selectivity indexes are more effective:

```csharp
// Good - unique or high cardinality
container.CreateIndex(new PathIndex("id-idx", "/@id"));
container.CreateIndex(new ValueIndex("email-idx", "/user/email", ValueType.String));

// Less effective - low cardinality
container.CreateIndex(new PathIndex("status-idx", "/order/status"));  // Only few values
```

### Composite Indexes

```csharp
// Single index for common query pattern
container.CreateIndex(new PathIndex("order-lookup",
    "/order/customerId", "/order/date", "/order/status"));
```

### Index Maintenance

```csharp
// Rebuild fragmented indexes
var stats = container.GetIndexStats("price-idx");
if (stats.Fragmentation > 0.3)  // > 30% fragmented
{
    container.RebuildIndex("price-idx");
}
```

## Monitoring

### Database Statistics

```csharp
var stats = db.GetStatistics();
Console.WriteLine($"Containers: {stats.ContainerCount}");
Console.WriteLine($"Documents: {stats.DocumentCount}");
Console.WriteLine($"Size: {stats.UsedBytes / 1024 / 1024} MB");
Console.WriteLine($"Readers: {stats.ActiveReaders}");
```

### Query Metrics

```csharp
var options = new QueryOptions
{
    CollectMetrics = true
};

var results = db.Query(xquery, options);

Console.WriteLine($"Parse time: {results.Metrics.ParseTime}");
Console.WriteLine($"Optimize time: {results.Metrics.OptimizeTime}");
Console.WriteLine($"Execute time: {results.Metrics.ExecuteTime}");
Console.WriteLine($"Rows scanned: {results.Metrics.RowsScanned}");
Console.WriteLine($"Index hits: {results.Metrics.IndexHits}");
```

## Benchmarking

### Measure Operations

```csharp
var sw = Stopwatch.StartNew();

for (int i = 0; i < iterations; i++)
{
    db.Query(xquery);
}

sw.Stop();
Console.WriteLine($"Avg: {sw.ElapsedMilliseconds / iterations} ms/query");
```

### Compare Approaches

```csharp
// Test different index configurations
var configs = new[]
{
    () => container.CreateIndex(new PathIndex("p1", "/a/b")),
    () => container.CreateIndex(new ValueIndex("v1", "/a/b", ValueType.String)),
    () => { /* no index */ }
};

foreach (var config in configs)
{
    ResetDatabase();
    config();
    var time = BenchmarkQuery(query);
    Console.WriteLine($"Time: {time}");
}
```

## Common Bottlenecks

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Slow queries | Missing index | Add appropriate index |
| High memory | Large transactions | Use smaller batches |
| Slow writes | Sync overhead | Use NoMetaSync or batch |
| Lock contention | Long transactions | Keep transactions short |
| "Map full" | Insufficient size | Increase MapSize |

## Platform Tuning

### Linux

```bash
# Increase max open files
ulimit -n 65536

# Disable transparent huge pages (can hurt LMDB)
echo never > /sys/kernel/mm/transparent_hugepage/enabled
```

### Windows

```powershell
# Increase working set
# Use SSD storage
# Disable antivirus scanning on data directory
```

## Best Practices Summary

1. **Index first** — Create indexes for query patterns
2. **Batch writes** — Group writes in transactions
3. **Use read-only** — When only reading
4. **Check plans** — Verify index usage
5. **Monitor metrics** — Track performance over time
6. **Keep transactions short** — Minimize lock duration
7. **Stream large data** — Avoid loading into memory
8. **SSD storage** — For production workloads
