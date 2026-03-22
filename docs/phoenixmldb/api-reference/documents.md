---
title: Documents API
description: Document storage, retrieval, metadata, bulk operations, and error handling
sort: 2
---

# Document API

The Document API provides operations for storing, retrieving, and managing XML and JSON documents.

## Storing Documents

### XML Documents

```csharp
// From string
container.PutDocument("product.xml", """
    <product id="1">
        <name>Widget</name>
        <price>29.99</price>
    </product>
    """);

// From file
container.PutDocument("data.xml", File.ReadAllText("data.xml"));

// From stream (for large documents)
using var stream = File.OpenRead("large-document.xml");
container.PutDocument("large.xml", stream);

// From XDocument
var xdoc = new XDocument(new XElement("root", new XElement("item", "value")));
container.PutDocument("from-xdoc.xml", xdoc);
```

### JSON Documents

```csharp
// JSON string
container.PutJsonDocument("user.json", """
    {"id": 1, "name": "Alice", "roles": ["admin"]}
    """);

// From object
var user = new { Id = 1, Name = "Alice", Roles = new[] { "admin" } };
container.PutJsonDocument("user.json", JsonSerializer.Serialize(user));
```

### With Metadata

```csharp
container.PutDocument("doc.xml", content, new DocumentMetadata
{
    ["author"] = "john.doe",
    ["created"] = DateTime.UtcNow.ToString("O"),
    ["version"] = "1.0",
    ["category"] = "products"
});
```

### Storage Options

```csharp
container.PutDocument("doc.xml", content, new DocumentStorageOptions
{
    Overwrite = true,           // Overwrite if exists (default: true)
    IndexImmediately = true,    // Index after store (default: true)
    ValidateContent = true      // Validate XML (default: follows container setting)
});
```

## Retrieving Documents

### As String

```csharp
// Get XML
string xml = container.GetDocument("product.xml");

// Get JSON
string json = container.GetJsonDocument("user.json");
```

### As XDocument

```csharp
XDocument xdoc = container.GetDocumentAsXDocument("product.xml");
```

### As Stream

```csharp
using var stream = container.GetDocumentAsStream("large.xml");
// Process stream without loading entire document into memory
```

### Check Existence

```csharp
if (container.DocumentExists("product.xml"))
{
    var doc = container.GetDocument("product.xml");
}

// Or use TryGet
if (container.TryGetDocument("product.xml", out var doc))
{
    Console.WriteLine(doc);
}
```

## Document Metadata

### Get Metadata

```csharp
var metadata = container.GetMetadata("product.xml");

Console.WriteLine($"Author: {metadata["author"]}");
Console.WriteLine($"Created: {metadata["created"]}");
Console.WriteLine($"Version: {metadata["version"]}");

// Check if key exists
if (metadata.ContainsKey("category"))
{
    Console.WriteLine($"Category: {metadata["category"]}");
}
```

### Set Metadata

```csharp
// Replace all metadata
container.SetMetadata("product.xml", new DocumentMetadata
{
    ["author"] = "jane.doe",
    ["modified"] = DateTime.UtcNow.ToString("O"),
    ["version"] = "2.0"
});

// Set single value
container.SetMetadataValue("product.xml", "lastAccessed", DateTime.UtcNow.ToString("O"));

// Remove metadata key
container.RemoveMetadataValue("product.xml", "temporary");
```

### Query by Metadata

```csharp
// Using XQuery
var authorDocs = db.Query("""
    for $doc in collection('products')
    where doc-metadata($doc, 'author') = 'john.doe'
    return document-uri($doc)
    """);
```

## Listing Documents

### All Documents

```csharp
foreach (var name in container.ListDocuments())
{
    Console.WriteLine(name);
}
```

### With Prefix

```csharp
// Virtual directory structure
foreach (var name in container.ListDocuments(prefix: "2024/01/"))
{
    Console.WriteLine(name);  // 2024/01/order-001.xml, 2024/01/order-002.xml
}
```

### With Pagination

```csharp
var documents = container.ListDocuments(
    prefix: null,
    skip: 100,
    take: 50
);
```

## Deleting Documents

### Single Document

```csharp
container.DeleteDocument("old-product.xml");
```

### Multiple Documents

```csharp
foreach (var name in container.ListDocuments(prefix: "temp/"))
{
    container.DeleteDocument(name);
}
```

### In Transaction

```csharp
using (var txn = db.BeginTransaction())
{
    var container = txn.GetContainer("products");

    container.DeleteDocument("product1.xml");
    container.DeleteDocument("product2.xml");

    txn.Commit();
}
```

## Document Information

```csharp
var info = container.GetDocumentInfo("product.xml");

Console.WriteLine($"Name: {info.Name}");
Console.WriteLine($"Size: {info.SizeBytes} bytes");
Console.WriteLine($"Node count: {info.NodeCount}");
Console.WriteLine($"Created: {info.CreatedAt}");
Console.WriteLine($"Modified: {info.ModifiedAt}");
Console.WriteLine($"Content hash: {info.ContentHash}");
```

## Bulk Operations

### Import Multiple Documents

```csharp
// From directory
container.ImportFromDirectory("./xml-files", "*.xml", new ImportOptions
{
    Recursive = true,
    PreserveSubdirectories = true  // Keep folder structure in names
});
```

### Export Documents

```csharp
// Export to directory
container.ExportToDirectory("./backup", new ExportOptions
{
    IncludeMetadata = true
});
```

## Error Handling

```csharp
try
{
    var doc = container.GetDocument("nonexistent.xml");
}
catch (DocumentNotFoundException ex)
{
    Console.WriteLine($"Document not found: {ex.DocumentName}");
    Console.WriteLine($"Container: {ex.ContainerName}");
}

try
{
    container.PutDocument("doc.xml", invalidXml);
}
catch (XmlValidationException ex)
{
    Console.WriteLine($"Validation failed: {ex.Message}");
    Console.WriteLine($"Line: {ex.LineNumber}, Position: {ex.LinePosition}");
}
```

## Document Names

### Naming Conventions

```csharp
// Simple names
"product.xml"
"user.json"

// Virtual paths (for organization)
"products/electronics/laptop.xml"
"2024/01/15/order-001.xml"

// With metadata in name
"order_12345_pending.xml"
```

### Name Validation

```csharp
// Valid characters: alphanumeric, dash, underscore, dot, slash
container.PutDocument("valid-name_123.xml", content);  // OK
container.PutDocument("path/to/doc.xml", content);     // OK

// Invalid characters will throw ArgumentException
```

## Best Practices

1. **Use meaningful names** - Names should identify content
2. **Organize with virtual paths** - Use `/` for logical grouping
3. **Add metadata** - Store non-content information as metadata
4. **Use transactions** - For related document operations
5. **Stream large documents** - Use stream APIs for documents > 1MB
6. **Validate on store** - Enable validation for data integrity

## Next Steps

| Management | Querying | Performance |
|------------|----------|-------------|
| **[Container API](containers.md)**<br>Container management | **[Query API](queries.md)**<br>Query documents | **[Index API](indexes.md)**<br>Index for performance |
