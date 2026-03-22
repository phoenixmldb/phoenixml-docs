---
title: Containers API
description: Container creation, configuration, operations, and management
sort: 1
---

# Container API

Containers organize documents into logical groups within a database.

## Creating Containers

### Basic Creation

```csharp
var container = db.CreateContainer("products");
```

### With Options

```csharp
var container = db.CreateContainer("orders", new ContainerOptions
{
    ValidationMode = ValidationMode.WellFormed,
    PreserveWhitespace = false,
    DefaultNamespaces = new Dictionary<string, string>
    {
        [""] = "http://example.com/orders",
        ["xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    },
    IndexOnStore = true
});
```

### Open or Create

```csharp
// Creates if doesn't exist, opens if exists
var container = db.OpenOrCreateContainer("products");
```

## ContainerOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ValidationMode` | `ValidationMode` | `WellFormed` | Document validation level |
| `PreserveWhitespace` | `bool` | `true` | Keep whitespace-only text nodes |
| `DefaultNamespaces` | `Dictionary<string, string>` | Empty | Default namespace bindings |
| `IndexOnStore` | `bool` | `true` | Auto-index documents when stored |
| `JsonSchema` | `string` | `null` | JSON Schema for validation |

### ValidationMode

```csharp
enum ValidationMode
{
    None,        // No validation
    WellFormed,  // XML well-formedness only
    DTD,         // Validate against DTD
    Schema       // Validate against XML Schema
}
```

## Getting Containers

```csharp
// Get existing container (throws if not found)
var container = db.GetContainer("products");

// Try get pattern
if (db.TryGetContainer("products", out var container))
{
    // Use container
}
```

## Listing Containers

```csharp
foreach (var name in db.ListContainers())
{
    Console.WriteLine(name);
}

// With info
foreach (var name in db.ListContainers())
{
    var info = db.GetContainerInfo(name);
    Console.WriteLine($"{name}: {info.DocumentCount} documents, {info.SizeBytes} bytes");
}
```

## Container Information

```csharp
var info = db.GetContainerInfo("products");

Console.WriteLine($"Name: {info.Name}");
Console.WriteLine($"Documents: {info.DocumentCount}");
Console.WriteLine($"Size: {info.SizeBytes} bytes");
Console.WriteLine($"Created: {info.CreatedAt}");
Console.WriteLine($"Modified: {info.ModifiedAt}");
Console.WriteLine($"Indexes: {info.IndexCount}");
```

## Deleting Containers

```csharp
// Delete container and all its documents
db.DeleteContainer("temp-data");

// Safe delete
if (db.ContainerExists("temp-data"))
{
    db.DeleteContainer("temp-data");
}
```

> **Warning:** Deleting a container removes all documents and indexes. This operation cannot be undone.

## Container Settings

### Get/Set Options

```csharp
// Get current option
var preserveWs = container.GetOption<bool>("PreserveWhitespace");

// Set option
container.SetOption("IndexOnStore", false);
```

### Available Options

```csharp
container.SetOption("PreserveWhitespace", true);
container.SetOption("IndexOnStore", true);
container.SetOption("ValidationMode", "WellFormed");
```

## Statistics

```csharp
var stats = container.GetStatistics();

Console.WriteLine($"Document count: {stats.DocumentCount}");
Console.WriteLine($"Total nodes: {stats.TotalNodeCount}");
Console.WriteLine($"Storage size: {stats.StorageSizeBytes}");
Console.WriteLine($"Index size: {stats.IndexSizeBytes}");
Console.WriteLine($"Average doc size: {stats.AverageDocumentSize}");
```

## In Transactions

```csharp
using (var txn = db.BeginTransaction())
{
    // Get container in transaction context
    var container = txn.GetContainer("products");

    // Operations are isolated
    container.PutDocument("p1.xml", xml1);
    container.PutDocument("p2.xml", xml2);

    // Commit or rollback
    txn.Commit();
}
```

## Error Handling

```csharp
try
{
    var container = db.GetContainer("nonexistent");
}
catch (ContainerNotFoundException ex)
{
    Console.WriteLine($"Container '{ex.ContainerName}' not found");
}

try
{
    db.CreateContainer("existing");
}
catch (ContainerExistsException ex)
{
    Console.WriteLine($"Container '{ex.ContainerName}' already exists");
}
```

## Best Practices

1. **Meaningful names** - Use descriptive container names
2. **Group related documents** - Keep related data together
3. **Consider query patterns** - Documents queried together should be in the same container
4. **Use transactions** - For multi-document operations
5. **Monitor size** - Large containers may benefit from partitioning

## Next Steps

| Documentation | API Reference | Advanced Topics |
|---------------|---------------|-----------------|
| **[Document API](documents.md)**<br>Document operations | **[Index API](indexes.md)**<br>Container indexes | **[Transaction API](transactions.md)**<br>Transactional access |
