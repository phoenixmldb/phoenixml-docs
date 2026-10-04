---
title: Containers API
description: Container creation, configuration, operations, and management
sort: 1
---

# Container API

Containers organize documents into logical groups within a database. Container methods live on `DocumentDatabase` (`PhoenixmlDb.Storage`) and return `IContainer` (`PhoenixmlDb.Core`).

## Creating Containers

### Basic Creation

```csharp
IContainer container = await db.CreateContainerAsync("products");
```

Creating a container whose name is already taken throws `DocumentExistsException`.

### With Options

Options are set through a configuration delegate that receives a fresh `ContainerOptions`:

```csharp
var container = await db.CreateContainerAsync("orders", opts =>
{
    opts.PreserveWhitespace = false;
    opts.DefaultNamespaces["o"] = "http://example.com/orders";
    opts.DefaultMetadataNamespace = "http://example.com/meta";
    opts.Indexes.AddPathIndex("/o:order/o:id");
});
```

### Open or Create

```csharp
// Creates if it doesn't exist, opens if it does
var container = await db.OpenOrCreateContainerAsync("products");
```

When the container already exists, the `configure` delegate is not applied; the container keeps the options it was created with.

## ContainerOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ValidationMode` | `ValidationMode` | `None` | Stored with the container; not enforced on write today (every stored document must be well-formed XML or valid JSON regardless) |
| `PreserveWhitespace` | `bool` | `false` | Keep whitespace-only text nodes |
| `DefaultNamespaces` | `Dictionary<string, string>` | Empty | Prefix → namespace URI bindings available to every query on the container |
| `DefaultMetadataNamespace` | `string?` | `null` | Namespace for unqualified metadata names; `null` uses the engine's application default |
| `Indexes` | `IndexConfiguration` | Structural index only | Index declarations — see [Index API](indexes.md) |

`DefaultNamespaces` is validated when the container is created: a binding the XQuery compiler would refuse (rebinding a predeclared prefix such as `fn` or `xs`, `xmlns`, an empty URI, or a prefix that is not an NCName) throws `ArgumentException` from `CreateContainerAsync`.

### ValidationMode

```csharp
public enum ValidationMode
{
    None,
    Schema,
    WellFormed
}
```

## Getting Containers

```csharp
// Returns null if the container does not exist
IContainer? container = await db.OpenContainerAsync("products");

if (container is not null)
{
    // Use container
}
```

## Listing Containers

```csharp
await foreach (ContainerInfo info in db.ListContainersAsync())
{
    Console.WriteLine($"{info.Name}: {info.DocumentCount} documents");
}
```

## Container Information

`ContainerInfo` (`PhoenixmlDb.Core`) is returned by `ListContainersAsync`:

| Property | Type |
|----------|------|
| `Id` | `ContainerId` |
| `Name` | `string` |
| `Created` | `DateTimeOffset` |
| `Modified` | `DateTimeOffset` |
| `DocumentCount` | `long` |

An open `IContainer` exposes `Id`, `Name` and `Options`.

## Deleting Containers

```csharp
// Returns false if no container has that name
bool deleted = await db.DeleteContainerAsync("temp-data");
```

> **Warning:** Deleting a container removes it from the database's catalogue; its documents are no longer reachable through any API. This operation cannot be undone.

## Statistics

Database-wide statistics are available from `DocumentDatabase.Statistics` (`DatabaseStatistics`, `PhoenixmlDb.Core`):

```csharp
var stats = db.Statistics;

Console.WriteLine($"Containers: {stats.ContainerCount}");
Console.WriteLine($"Documents: {stats.TotalDocumentCount}");
Console.WriteLine($"Nodes: {stats.TotalNodeCount}");
Console.WriteLine($"Database size: {stats.DatabaseSizeBytes}");
Console.WriteLine($"Used size: {stats.UsedSizeBytes}");
```

There is no per-container statistics API beyond `ContainerInfo.DocumentCount`.

## In Transactions

Write transactions address a container by its `ContainerId`:

```csharp
var products = await db.OpenOrCreateContainerAsync("products");

await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(products.Id, "p1.xml", xml1);
    await txn.PutDocumentAsync(products.Id, "p2.xml", xml2);

    // Commit, or dispose without committing to discard
    await txn.CommitAsync();
}
```

## Error Handling

```csharp
try
{
    await db.CreateContainerAsync("existing");
}
catch (DocumentExistsException ex)
{
    Console.WriteLine(ex.Message);   // "Container 'existing' already exists."
}

try
{
    // With indexing enabled; without it, RebuildIndexesAsync throws InvalidOperationException
    await db.RebuildIndexesAsync("nonexistent");
}
catch (ContainerNotFoundException ex)
{
    Console.WriteLine(ex.Message);
}
```

`OpenContainerAsync` and `DeleteContainerAsync` report a missing container through their return values (`null` / `false`) rather than an exception.

## Best Practices

1. **Meaningful names** - Use descriptive container names
2. **Group related documents** - Keep related data together
3. **Consider query patterns** - A query runs against one container; documents queried together should be in the same container
4. **Use transactions** - For multi-document operations
5. **Declare indexes at creation** - A container's index set is fixed when it is created

## Next Steps

| Documentation | API Reference | Advanced Topics |
|---------------|---------------|-----------------|
| **[Document API](documents.md)**<br>Document operations | **[Index API](indexes.md)**<br>Container indexes | **[Transaction API](transactions.md)**<br>Transactional access |
