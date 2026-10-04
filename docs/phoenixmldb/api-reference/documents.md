---
title: Documents API
description: Document storage, retrieval, metadata, bulk operations, and error handling
sort: 2
---

# Document API

The Document API provides operations for storing, retrieving, and managing XML and JSON documents. Document methods live on `IContainer` (`PhoenixmlDb.Core`); retrieved documents are `IDocument`.

## Storing Documents

### XML Documents

```csharp
// From string
await container.PutDocumentAsync("product.xml", """
    <product id="1">
        <name>Widget</name>
        <price>29.99</price>
    </product>
    """);

// From file
await container.PutDocumentAsync("data.xml", await File.ReadAllTextAsync("data.xml"));

// From stream
await using var stream = File.OpenRead("large-document.xml");
await container.PutDocumentAsync("large.xml", stream);
```

The `Stream` overload reads the whole stream as UTF-8 text (honouring a byte-order mark) and then stores it like the string overload. The caller keeps ownership of the stream; it is not disposed.

Storing a document under an existing name replaces it (see `Overwrite` below). Content that does not parse is rejected and nothing is written: malformed XML throws `System.Xml.XmlException`, malformed JSON throws `System.Text.Json.JsonException`.

### JSON Documents

There is no separate JSON method. `PutDocumentAsync` stores JSON when the content's first non-whitespace character is `{` or `[`, or when `DocumentOptions.ContentType` is `ContentType.Json`:

```csharp
// Detected as JSON from its content
await container.PutDocumentAsync("user.json", """
    {"id": 1, "name": "Alice", "roles": ["admin"]}
    """);

// From an object
var user = new { Id = 1, Name = "Alice", Roles = new[] { "admin" } };
await container.PutDocumentAsync("user.json", JsonSerializer.Serialize(user));
```

JSON is stored as its XML representation; see [JSON Storage](../json-support/json-storage.md).

### With Metadata

`DocumentOptions.Metadata` writes metadata in the same transaction as the document. Its keys are qualified `XdmQName` names:

```csharp
using PhoenixmlDb.Xdm;

var author = db.MetadataName(container, null, "author");   // container's default metadata namespace

await container.PutDocumentAsync("doc.xml", content, new DocumentOptions
{
    Metadata = new Dictionary<XdmQName, XdmValue>
    {
        [author] = XdmValue.From("john.doe")
    }
});
```

### Storage Options

```csharp
await container.PutDocumentAsync("doc.xml", content, new DocumentOptions
{
    Overwrite = false,             // Throw if the document exists (default: true)
    ContentType = ContentType.Xml  // Skip content sniffing (default: null = detect)
});
```

`DocumentOptions` (`PhoenixmlDb.Core`) is a record with three properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ContentType` | `ContentType?` | `null` | `Xml` or `Json`; `null` detects from the content |
| `Metadata` | `IReadOnlyDictionary<XdmQName, XdmValue>?` | `null` | Metadata to write with the document |
| `Overwrite` | `bool` | `true` | When `false`, storing over an existing name throws `DocumentExistsException` |

If indexing is enabled on the database (`db.EnableIndexing()`), the container's declared indexes are updated in the same write transaction as the document.

## Retrieving Documents

### As String

```csharp
IDocument? doc = await container.GetDocumentAsync("product.xml");
if (doc is not null)
{
    string xml = await doc.GetContentAsync();
}
```

`GetDocumentAsync` returns `null` when the document does not exist. `GetContentAsync` serializes the stored node tree back to XML, with an XML declaration; it does not return the original bytes. A JSON document returns its XML representation.

### As Stream

```csharp
await using Stream stream = await doc.GetContentStreamAsync();
```

`GetContentStreamAsync` serializes the whole document and wraps the result in a read-only `MemoryStream`; it is a convenience for stream-based consumers, not a streaming read.

### As a Node

```csharp
IXdmNode root = await doc.GetRootNodeAsync();
Console.WriteLine(root.NodeKind);    // Document
```

### Check Existence

```csharp
if (await container.DocumentExistsAsync("product.xml"))
{
    var doc = await container.GetDocumentAsync("product.xml");
}
```

## Document Metadata

Metadata names are qualified. The `string`-name overloads place the name in the container's default metadata namespace (`ContainerOptions.DefaultMetadataNamespace`, or the engine's application namespace when that is not set). Every metadata method throws `DocumentNotFoundException` when the document does not exist. See [Metadata](../metadata.md) for the model.

### Get Metadata

```csharp
using PhoenixmlDb.Core.Metadata;   // MetadataCollection
using PhoenixmlDb.Xdm;             // XdmQName, XdmValue

string? author = await container.GetMetadataAsync("product.xml", "author");

// All entries, keyed by XdmQName
MetadataCollection all = await container.GetAllMetadataAsync("product.xml");
foreach (var (name, value) in all)
{
    Console.WriteLine($"{name}: {value}");
}

// Also available from a retrieved document
MetadataCollection fromDoc = await doc.GetAllMetadataAsync();
```

### Set Metadata

```csharp
// Set a single value (replaces any previous value under that name)
await container.SetMetadataAsync("product.xml", "author", "jane.doe");

// Set a multi-value set (PhoenixmlDb.Storage extension method)
await container.SetMetadataValuesAsync("product.xml", "tags", new[] { "sale", "featured" });

// Remove a name (PhoenixmlDb.Storage extension method; returns false if it was not set)
bool removed = await container.DeleteMetadataAsync("product.xml",
    db.MetadataName(container, null, "temporary"));
```

`SetMetadataAsync` also has `MetadataProperty<T>` and `XdmQName`/`XdmValue` overloads. The multi-value and delete methods (`SetMetadataValuesAsync`, `GetMetadataValuesAsync`, `DeleteMetadataAsync`, `GetAllMetadataEntriesAsync`, `PutDocumentWithMetadataValuesAsync`) are extension methods on `IContainer` in `ContainerMetadataExtensions` (`PhoenixmlDb.Storage`).

### Query by Metadata

```csharp
// Exact match
var author = db.MetadataName(container, null, "author");
await foreach (DocumentInfo info in container.QueryMetadataAsync(author, XdmValue.From("john.doe")))
{
    Console.WriteLine(info.Name);
}
```

`QueryMetadataRangeAsync` answers range queries. From XQuery, `phx:metadata($node, $key)` returns a metadata value of the document containing `$node` (the `phx` prefix is predeclared):

```csharp
await foreach (var name in container.QueryAsync(
    "/product[phx:metadata(., 'author') = 'john.doe']/name/string()"))
{
    Console.WriteLine(name);
}
```

## Listing Documents

### All Documents

```csharp
await foreach (DocumentInfo info in container.ListDocumentsAsync())
{
    Console.WriteLine(info.Name);
}
```

### With Prefix

```csharp
// Virtual directory structure
await foreach (var info in container.ListDocumentsAsync("2024/01/"))
{
    Console.WriteLine(info.Name);  // 2024/01/order-001.xml, 2024/01/order-002.xml
}
```

There is no skip/take overload; page with LINQ over the async sequence if needed.

## Deleting Documents

### Single Document

```csharp
// Returns false if the document did not exist
bool deleted = await container.DeleteDocumentAsync("old-product.xml");
```

Deleting a document also removes its metadata and its index entries.

### Multiple Documents

```csharp
var names = new List<string>();
await foreach (var info in container.ListDocumentsAsync("temp/"))
    names.Add(info.Name);

foreach (var name in names)
    await container.DeleteDocumentAsync(name);
```

### In Transaction

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.DeleteDocumentAsync(container.Id, "product1.xml");
    await txn.DeleteDocumentAsync(container.Id, "product2.xml");

    await txn.CommitAsync();
}
```

## Document Information

`ListDocumentsAsync` yields `DocumentInfo` records; `IDocument` exposes the same fields:

```csharp
IDocument? doc = await container.GetDocumentAsync("product.xml");

Console.WriteLine($"Id: {doc!.Id}");
Console.WriteLine($"Name: {doc.Name}");
Console.WriteLine($"Size: {doc.SizeBytes} bytes");
Console.WriteLine($"Content type: {doc.ContentType}");
Console.WriteLine($"Created: {doc.Created}");
Console.WriteLine($"Modified: {doc.Modified}");
```

`SizeBytes` is the UTF-8 length of the content as it was submitted.

## Bulk Operations

### Store Many Documents

```csharp
var inputs = Directory.EnumerateFiles("./xml-files", "*.xml")
    .Select(path => new DocumentInput(Path.GetFileName(path), File.ReadAllText(path)));

int stored = await container.PutDocumentsAsync(inputs);
```

`PutDocumentsAsync` writes up to 1,000 documents per LMDB write transaction and returns the number stored. A failure aborts only the batch in progress; batches already committed stay committed.

There are no built-in directory import or export methods.

## Error Handling

```csharp
try
{
    await container.SetMetadataAsync("nonexistent.xml", "author", "jdoe");
}
catch (DocumentNotFoundException ex)
{
    Console.WriteLine($"Document not found: {ex.DocumentName}");
}

try
{
    await container.PutDocumentAsync("doc.xml", content, new DocumentOptions { Overwrite = false });
}
catch (DocumentExistsException ex)
{
    Console.WriteLine(ex.Message);
}
catch (System.Xml.XmlException ex)
{
    // Content is not well-formed XML
    Console.WriteLine($"Line {ex.LineNumber}, position {ex.LinePosition}: {ex.Message}");
}
```

`GetDocumentAsync` and `DeleteDocumentAsync` report a missing document through their return values (`null` / `false`).

## Document Names

### Naming Conventions

```csharp
// Simple names
"product.xml"
"user.json"

// Virtual paths (for organization; listable by prefix)
"products/electronics/laptop.xml"
"2024/01/15/order-001.xml"
```

### Name Validation

A name must not be `null`, empty, or whitespace (`ArgumentException`). The name is not otherwise restricted, and the extension does not determine the content type.

## Best Practices

1. **Use meaningful names** - Names should identify content
2. **Organize with virtual paths** - Use `/` for logical grouping and list with a prefix
3. **Add metadata** - Store non-content information as metadata
4. **Use transactions** - For related document operations
5. **Batch bulk loads** - `PutDocumentsAsync` amortizes commits across up to 1,000 documents

## Next Steps

| Management | Querying | Performance |
|------------|----------|-------------|
| **[Container API](containers.md)**<br>Container management | **[Query API](queries.md)**<br>Query documents | **[Index API](indexes.md)**<br>Index for performance |
