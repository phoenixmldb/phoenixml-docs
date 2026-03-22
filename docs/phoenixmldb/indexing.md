---
title: Indexing
description: Path, value, full-text, structural, name, and metadata indexes
sort: 5
---

# Indexing

Indexes dramatically improve query performance by providing fast access paths to your data. PhoenixmlDb supports multiple index types optimized for different query patterns.

## Index Types

### Path Index

Path indexes accelerate queries that navigate to specific elements or attributes by path.

```csharp
// Create path index
container.CreateIndex(new PathIndex("price-idx", "/product/price"));

// Queries that benefit:
// - collection('products')/product/price
// - collection('products')//product/price
// - $doc/product/price
```

**Multi-path index:**
```csharp
container.CreateIndex(new PathIndex("product-paths",
    "/product/name",
    "/product/category",
    "/product/price"));
```

### Value Index

Value indexes enable efficient range queries and sorting on typed values.

```csharp
// Numeric value index
container.CreateIndex(new ValueIndex("price-val",
    "/product/price",
    ValueType.Decimal));

// Date value index
container.CreateIndex(new ValueIndex("date-val",
    "/order/orderDate",
    ValueType.Date));

// String value index
container.CreateIndex(new ValueIndex("name-val",
    "/customer/name",
    ValueType.String));
```

**Supported value types:**

| ValueType | XSD Type | Use Case |
|-----------|----------|----------|
| `String` | xs:string | Text comparisons, sorting |
| `Integer` | xs:integer | Whole number ranges |
| `Decimal` | xs:decimal | Precise decimal ranges |
| `Double` | xs:double | Scientific calculations |
| `Date` | xs:date | Date ranges |
| `DateTime` | xs:dateTime | Timestamp ranges |
| `Boolean` | xs:boolean | True/false filtering |

**Queries that benefit:**
```xquery
(: Range queries :)
//product[price > 10 and price < 100]

(: Sorting :)
for $p in //product order by $p/price return $p

(: Min/Max :)
min(//product/price)
```

### Full-Text Index

Full-text indexes support natural language search with tokenization, stemming, and relevance ranking.

```csharp
// Basic full-text index
container.CreateIndex(new FullTextIndex("desc-ft",
    "/product/description"));

// With custom options
container.CreateIndex(new FullTextIndex("content-ft",
    "/article/content",
    new FullTextOptions
    {
        Language = "en",
        Stemming = true,
        StopWords = true,
        CaseSensitive = false,
        MinTokenLength = 2
    }));
```

**Queries that benefit:**
```xquery
(: Contains search :)
//product[contains(description, 'wireless')]

(: Full-text functions :)
//product[ft:contains(description, 'wireless bluetooth')]

(: Phrase search :)
//product[ft:contains(description, '"noise canceling"')]

(: Boolean operators :)
//product[ft:contains(description, 'wireless AND NOT wired')]
```

### Structural Index

Structural indexes accelerate navigation queries (parent, child, sibling, ancestor, descendant).

```csharp
// Enable structural indexing for a container
container.CreateIndex(new StructuralIndex("struct-idx"));
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

Metadata indexes allow efficient queries on document metadata.

```csharp
container.CreateIndex(new MetadataIndex("meta-idx",
    "author", "created", "version"));
```

**Queries that benefit:**
```xquery
(: Filter by metadata :)
for $doc in collection('products')
where doc-metadata($doc, 'author') = 'admin'
return $doc
```

## Creating Indexes

### During Container Creation

```csharp
var container = db.CreateContainer("products", new ContainerOptions
{
    Indexes =
    [
        new PathIndex("paths", "/product/name", "/product/category"),
        new ValueIndex("price", "/product/price", ValueType.Decimal),
        new FullTextIndex("search", "/product/description")
    ]
});
```

### On Existing Container

```csharp
var container = db.GetContainer("products");

// Create if not exists
container.CreateIndexIfNotExists(new PathIndex("name-idx", "/product/name"));

// Force recreation
container.CreateIndex(new PathIndex("name-idx", "/product/name"),
    recreateIfExists: true);
```

### Deferred Indexing

For bulk imports, defer indexing for better performance:

```csharp
// Disable auto-indexing
container.SetOption("IndexOnStore", false);

// Bulk import
using (var txn = db.BeginTransaction())
{
    foreach (var doc in documents)
    {
        container.PutDocument(doc.Name, doc.Content);
    }
    txn.Commit();
}

// Rebuild indexes
container.RebuildIndexes();

// Re-enable auto-indexing
container.SetOption("IndexOnStore", true);
```

## Managing Indexes

### List Indexes

```csharp
foreach (var index in container.ListIndexes())
{
    Console.WriteLine($"{index.Name}: {index.Type}");
    Console.WriteLine($"  Paths: {string.Join(", ", index.Paths)}");
    Console.WriteLine($"  Size: {index.SizeBytes} bytes");
    Console.WriteLine($"  Entries: {index.EntryCount}");
}
```

### Drop Index

```csharp
container.DropIndex("old-index");
```

### Rebuild Index

```csharp
// Rebuild specific index
container.RebuildIndex("price-idx");

// Rebuild all indexes
container.RebuildIndexes();
```

### Index Statistics

```csharp
var stats = container.GetIndexStats("price-idx");
Console.WriteLine($"Entries: {stats.EntryCount}");
Console.WriteLine($"Size: {stats.SizeBytes}");
Console.WriteLine($"Depth: {stats.TreeDepth}");
Console.WriteLine($"Fragmentation: {stats.Fragmentation:P}");
```

## Query Optimization

### Explain Plan

```csharp
var plan = db.Explain("""
    for $p in collection('products')//product
    where $p/price > 100
    order by $p/name
    return $p
    """);

Console.WriteLine(plan.ToString());
```

Output:
```
Query Plan:
├─ For: $p
│  ├─ Source: collection('products')//product
│  │  └─ Index: path-idx (estimated: 1000 nodes)
│  ├─ Where: $p/price > 100
│  │  └─ Index: price-val (estimated: 250 matches)
│  └─ OrderBy: $p/name
│     └─ Index: name-val (sorted access)
└─ Return: $p

Estimated cost: 250
Index usage: 3 indexes
```

### Index Hints

```csharp
// Force specific index usage
var results = db.Query("""
    (: pragma index=price-idx :)
    for $p in collection('products')//product
    where $p/price > 100
    return $p
    """);

// Disable index usage (for testing)
var results = db.Query("""
    (: pragma no-index :)
    for $p in collection('products')//product
    return $p
    """);
```

## Index Selection Guidelines

| Query Pattern | Recommended Index |
|---------------|-------------------|
| Navigate to element/attribute | Path Index |
| Equality comparison | Value Index or Path Index |
| Range comparison (<, >, between) | Value Index |
| Sorting (order by) | Value Index |
| Text search | Full-Text Index |
| Tree navigation (parent, ancestor) | Structural Index |
| Metadata filtering | Metadata Index |

## Best Practices

**Do:**

1. **Index frequently queried paths** — Start with your most common queries
2. **Use appropriate value types** — Match the index type to your data
3. **Create composite indexes** — Combine related paths in one index
4. **Monitor index usage** — Use explain plans to verify indexes are used
5. **Rebuild after bulk updates** — Fragmented indexes slow queries

**Don't:**

1. **Over-index** — Each index adds storage and write overhead
2. **Index rarely queried paths** — Unused indexes waste resources
3. **Use wrong value types** — String indexes won't help numeric ranges
4. **Forget to rebuild** — After bulk deletes, indexes may be fragmented

## Performance Impact

| Operation | Without Index | With Index |
|-----------|---------------|------------|
| Path lookup | O(n) scan | O(log n) |
| Range query | O(n) scan | O(log n + k) |
| Full-text search | O(n) scan | O(k) |
| Sort | O(n log n) | O(n) or O(k) |

Where n = total nodes, k = matching nodes
