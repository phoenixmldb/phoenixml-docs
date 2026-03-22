---
title: Indexes API
description: Index creation, management, statistics, and query optimization
sort: 3
---

# Index API

The Index API provides methods for creating and managing indexes to optimize query performance.

## Creating Indexes

### Path Index

```csharp
// Single path
container.CreateIndex(new PathIndex("name-idx", "/product/name"));

// Multiple paths
container.CreateIndex(new PathIndex("product-paths",
    "/product/name",
    "/product/category",
    "/product/brand"));

// Attribute path
container.CreateIndex(new PathIndex("id-idx", "/product/@id"));
```

### Value Index

```csharp
// Numeric index for range queries
container.CreateIndex(new ValueIndex("price-idx",
    "/product/price",
    ValueType.Decimal));

// Date index
container.CreateIndex(new ValueIndex("date-idx",
    "/order/orderDate",
    ValueType.Date));

// String index (for sorting and equality)
container.CreateIndex(new ValueIndex("name-val-idx",
    "/product/name",
    ValueType.String));
```

### Full-Text Index

```csharp
// Basic full-text
container.CreateIndex(new FullTextIndex("description-idx",
    "/product/description"));

// With options
container.CreateIndex(new FullTextIndex("content-idx",
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

### Structural Index

```csharp
// Enable structural navigation optimization
container.CreateIndex(new StructuralIndex("struct-idx"));
```

### Metadata Index

```csharp
// Index document metadata fields
container.CreateIndex(new MetadataIndex("meta-idx",
    "author", "created", "category"));
```

## Index Definition Classes

### PathIndex

```csharp
var index = new PathIndex
{
    Name = "product-paths",
    Paths = ["/product/name", "/product/category"],
    IncludeNamespaces = false  // Ignore namespaces in matching
};
```

### ValueIndex

```csharp
var index = new ValueIndex
{
    Name = "price-idx",
    Path = "/product/price",
    ValueType = ValueType.Decimal,
    Collation = null  // Use default collation
};
```

### FullTextIndex

```csharp
var index = new FullTextIndex
{
    Name = "content-idx",
    Path = "/article/content",
    Options = new FullTextOptions
    {
        Language = "en",
        Stemming = true,
        StopWords = true,
        CustomStopWords = ["the", "a", "an"],
        CaseSensitive = false,
        MinTokenLength = 2,
        MaxTokenLength = 50
    }
};
```

## Index Options

### Create If Not Exists

```csharp
container.CreateIndexIfNotExists(new PathIndex("name-idx", "/product/name"));
```

### Recreate Index

```csharp
container.CreateIndex(index, recreateIfExists: true);
```

### Deferred Indexing

```csharp
container.CreateIndex(index, new IndexOptions
{
    BuildImmediately = false  // Create definition only, build later
});

// Later: build the index
container.RebuildIndex("price-idx");
```

## Managing Indexes

### List Indexes

```csharp
foreach (var info in container.ListIndexes())
{
    Console.WriteLine($"Name: {info.Name}");
    Console.WriteLine($"Type: {info.Type}");
    Console.WriteLine($"Paths: {string.Join(", ", info.Paths)}");
    Console.WriteLine($"Size: {info.SizeBytes} bytes");
    Console.WriteLine($"Entries: {info.EntryCount}");
    Console.WriteLine();
}
```

### Get Index Info

```csharp
var info = container.GetIndexInfo("price-idx");

Console.WriteLine($"Name: {info.Name}");
Console.WriteLine($"Type: {info.Type}");
Console.WriteLine($"Created: {info.CreatedAt}");
Console.WriteLine($"Last rebuilt: {info.LastRebuiltAt}");
Console.WriteLine($"Size: {info.SizeBytes}");
Console.WriteLine($"Entry count: {info.EntryCount}");
```

### Drop Index

```csharp
container.DropIndex("old-idx");

// Safe drop
if (container.IndexExists("old-idx"))
{
    container.DropIndex("old-idx");
}
```

### Rebuild Index

```csharp
// Rebuild specific index
container.RebuildIndex("price-idx");

// Rebuild all indexes
container.RebuildIndexes();

// Rebuild with progress
container.RebuildIndex("price-idx", new RebuildOptions
{
    Progress = new Progress<IndexRebuildProgress>(p =>
    {
        Console.WriteLine($"Progress: {p.DocumentsProcessed}/{p.TotalDocuments}");
    })
});
```

## Index Statistics

```csharp
var stats = container.GetIndexStats("price-idx");

Console.WriteLine($"Entry count: {stats.EntryCount}");
Console.WriteLine($"Unique values: {stats.UniqueValueCount}");
Console.WriteLine($"Size: {stats.SizeBytes} bytes");
Console.WriteLine($"Tree depth: {stats.TreeDepth}");
Console.WriteLine($"Fragmentation: {stats.Fragmentation:P}");
Console.WriteLine($"Avg entry size: {stats.AverageEntrySize} bytes");
```

## Query Optimization

### Explain Index Usage

```csharp
var plan = db.Explain("""
    for $p in collection('products')//product
    where $p/price > 100
    order by $p/name
    return $p
    """);

foreach (var index in plan.IndexesUsed)
{
    Console.WriteLine($"Using index: {index.Name}");
    Console.WriteLine($"  Type: {index.Type}");
    Console.WriteLine($"  Estimated selectivity: {index.Selectivity:P}");
}
```

### Force Index Usage

```csharp
var results = db.Query("""
    (: pragma use-index=price-idx :)
    for $p in collection('products')//product
    where $p/price > 100
    return $p
    """);
```

### Disable Index Usage

```csharp
var results = db.Query("""
    (: pragma no-index :)
    for $p in collection('products')//product
    return $p
    """);
```

## Index Selection Guidelines

| Query Pattern | Recommended Index |
|---------------|-------------------|
| `/product/name` | Path Index |
| `//product[@id='123']` | Path Index on `/@id` |
| `price > 100` | Value Index (Decimal) |
| `order by date` | Value Index (Date) |
| `contains(description, 'keyword')` | Full-Text Index |
| `parent::*`, `ancestor::*` | Structural Index |
| `doc-metadata($doc, 'author')` | Metadata Index |

## Error Handling

```csharp
try
{
    container.CreateIndex(index);
}
catch (IndexExistsException ex)
{
    Console.WriteLine($"Index already exists: {ex.IndexName}");
}
catch (InvalidIndexDefinitionException ex)
{
    Console.WriteLine($"Invalid index: {ex.Message}");
}

try
{
    container.DropIndex("nonexistent");
}
catch (IndexNotFoundException ex)
{
    Console.WriteLine($"Index not found: {ex.IndexName}");
}
```

## Best Practices

1. **Index selectively** - Only index frequently queried paths
2. **Match query patterns** - Design indexes for your actual queries
3. **Use value indexes for ranges** - Path indexes only help with existence
4. **Monitor index size** - Large indexes slow writes
5. **Rebuild periodically** - After bulk deletes
6. **Test with explain** - Verify indexes are being used
7. **Consider composite indexes** - Multiple paths in one index

## Next Steps

| Concepts | Execution | Optimization |
|----------|-----------|--------------|
| **[Indexing](../indexing.md)**<br>Indexing concepts | **[Query API](queries.md)**<br>Query execution | **[Performance Tuning](../performance-tuning.md)**<br>Optimization tips |
