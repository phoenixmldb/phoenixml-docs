---
title: JSON Storage
description: How JSON documents are stored, the XML mapping, and storage options
sort: 1
---

# JSON Storage

This guide covers JSON document storage options, validation, and performance considerations.

## Storing JSON Documents

### Basic Storage

```csharp
var container = db.GetContainer("data");

// Store JSON string
container.PutJsonDocument("doc.json", jsonString);

// Store from object (with serialization)
var user = new { Name = "Alice", Age = 30 };
container.PutJsonDocument("user.json", JsonSerializer.Serialize(user));
```

### Storage Options

```csharp
container.PutJsonDocument("doc.json", json, new JsonStorageOptions
{
    PreserveOriginal = true,      // Keep original JSON for exact retrieval
    ValidateJson = true,          // Validate JSON syntax
    StoreArraysCompact = false    // Use expanded array format
});
```

### Preserve Original

When `PreserveOriginal` is true, the exact JSON string is stored alongside the XML representation:

```csharp
// Store with preservation
container.PutJsonDocument("user.json", """
    {
        "name": "Alice",
        "score": 95.5
    }
    """, new JsonStorageOptions { PreserveOriginal = true });

// Retrieve exact original
string original = container.GetJsonDocument("user.json");
// Returns: {"name": "Alice", "score": 95.5}

// Without preservation, JSON is reconstructed from XML
// Formatting may differ
```

## JSON Validation

### Syntax Validation

```csharp
// Validate JSON syntax before storage
container.PutJsonDocument("doc.json", json, new JsonStorageOptions
{
    ValidateJson = true  // Throws JsonException on invalid JSON
});
```

### Schema Validation

```csharp
// Define JSON Schema
var schema = """
    {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "required": ["id", "name"],
        "properties": {
            "id": { "type": "integer" },
            "name": { "type": "string", "minLength": 1 },
            "email": { "type": "string", "format": "email" }
        }
    }
    """;

// Create container with schema validation
var container = db.CreateContainer("users", new ContainerOptions
{
    JsonSchema = schema
});

// This succeeds
container.PutJsonDocument("u1.json", """{"id": 1, "name": "Alice"}""");

// This throws ValidationException
container.PutJsonDocument("u2.json", """{"id": "not-a-number", "name": ""}""");
```

## Indexing JSON

Indexes are defined using XPath paths against the XML representation. See [JSON Indexing](json-indexing.md) for the full indexing story.

### Path Index

```csharp
// Index specific JSON paths
container.CreateIndex(new PathIndex("user-email-idx",
    "/map/email"));

container.CreateIndex(new PathIndex("nested-idx",
    "/map/profile/city"));
```

### Value Index

```csharp
// Index for range queries
container.CreateIndex(new ValueIndex("age-idx",
    "/map/profile/age",
    ValueType.Integer));

// Date values
container.CreateIndex(new ValueIndex("created-idx",
    "/map/createdAt",
    ValueType.DateTime));
```

### Full-Text Index

```csharp
// Index text content for search
container.CreateIndex(new FullTextIndex("description-idx",
    "/map/description"));
```

### Array Element Index

```csharp
// Index array elements
container.CreateIndex(new PathIndex("tags-idx",
    "/map/tags/_"));
```

## Bulk Import

### Streaming Import

```csharp
// Import large JSON array file
using var stream = File.OpenRead("large-data.json");
var count = container.ImportJsonArray(stream, new ImportOptions
{
    BatchSize = 1000,
    DocumentNameTemplate = "item-{index}.json"
});
Console.WriteLine($"Imported {count} documents");
```

### NDJSON Import

```csharp
// Import newline-delimited JSON
using var stream = File.OpenRead("data.ndjson");
var count = container.ImportNdjson(stream, new ImportOptions
{
    DocumentNameGenerator = (json, index) => $"record-{json["id"]}.json"
});
```

## Performance Considerations

### XML Conversion Overhead

JSON is converted to XML for storage, which adds a small overhead on write. Query performance is identical to XML once indexed.

| Operation | Overhead |
|-----------|----------|
| Store JSON | ~5-10% slower than XML |
| Retrieve JSON | ~5-10% slower (if not preserved) |
| Query | Same as XML queries |

### Optimize for Queries

```csharp
// For query-heavy workloads
var options = new JsonStorageOptions
{
    PreserveOriginal = false,     // Save storage space
    StoreArraysCompact = true     // Faster array traversal
};
```

### Optimize for Round-Trip

```csharp
// For read-heavy workloads needing exact JSON
var options = new JsonStorageOptions
{
    PreserveOriginal = true       // Fast retrieval, uses more space
};
```

## JSON Document Metadata

```csharp
// Store with metadata
container.PutJsonDocument("user.json", json, metadata: new DocumentMetadata
{
    ["source"] = "api",
    ["version"] = "1.0",
    ["imported"] = DateTime.UtcNow.ToString("O")
});

// Query by metadata
var apiDocs = db.Query("""
    for $doc in collection('data')/map
    where doc-metadata($doc, 'source') = 'api'
    return $doc
    """);
```

## Migration from Other Formats

### From MongoDB BSON

```csharp
// Convert BSON to JSON and store
foreach (var doc in mongoCollection.Find(_ => true))
{
    var json = doc.ToJson();
    container.PutJsonDocument($"{doc["_id"]}.json", json);
}
```

### From CSV

```csharp
// Convert CSV rows to JSON documents
using var reader = new StreamReader("data.csv");
using var csv = new CsvReader(reader, CultureInfo.InvariantCulture);

var records = csv.GetRecords<dynamic>();
int index = 0;
foreach (var record in records)
{
    var json = JsonSerializer.Serialize(record);
    container.PutJsonDocument($"row-{index++}.json", json);
}
```

## Best Practices

1. **Consistent naming** — Use `.json` extension for JSON documents
2. **Index key paths** — Create indexes for frequently queried paths
3. **Schema validation** — Use JSON Schema for data integrity
4. **Batch imports** — Use bulk import for large datasets
5. **Consider preservation** — Enable `PreserveOriginal` if exact format matters

## Next Steps

| Queries | Indexing | Performance |
|---------|----------|-------------|
| **[JSON Queries](json-queries.md)**<br>Query patterns for JSON | **[JSON Indexing](json-indexing.md)**<br>Full indexing through XML | **[Performance Tuning](../performance-tuning.md)**<br>Optimization tips |
