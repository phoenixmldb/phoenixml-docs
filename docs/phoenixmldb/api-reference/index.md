---
title: API Reference
description: PhoenixmlDb .NET API — interfaces, classes, and usage patterns
sort: 11
---

# API Reference

This section provides detailed API documentation for PhoenixmlDb's core classes and interfaces.

## Core Classes

### XmlDatabase

The main entry point for working with PhoenixmlDb.

```csharp
// Create/open database
using var db = new XmlDatabase(path);
using var db = new XmlDatabase(path, options);

// Container operations
IContainer CreateContainer(string name);
IContainer CreateContainer(string name, ContainerOptions options);
IContainer GetContainer(string name);
IContainer OpenOrCreateContainer(string name);
void DeleteContainer(string name);
IEnumerable<string> ListContainers();

// Query operations
IQueryResult Query(string xquery);
IQueryResult Query(string xquery, QueryParameters parameters);
T QuerySingle<T>(string xquery);
void Execute(string xqueryUpdate);

// Transaction operations
ITransaction BeginTransaction();
ITransaction BeginTransaction(bool readOnly);
ITransaction BeginTransaction(TransactionOptions options);

// Lifecycle
void Flush();
void Dispose();
```

### DatabaseOptions

```csharp
var options = new DatabaseOptions
{
    MapSize = 10L * 1024 * 1024 * 1024,  // 10 GB max database size
    MaxContainers = 100,                   // Maximum containers
    MaxReaders = 126,                      // Maximum concurrent readers
    NoSync = false,                        // Sync on commit
    NoMetaSync = false,                    // Sync metadata on commit
    ReadOnly = false                       // Open read-only
};
```

## API Topics

### [Container API](containers.md)
Create, configure, and manage document containers.

### [Document API](documents.md)
Store, retrieve, and delete XML/JSON documents.

### [Query API](queries.md)
Execute XQuery queries and process results.

### [Index API](indexes.md)
Create and manage indexes for query optimization.

### [Transaction API](transactions.md)
ACID transactions and concurrent access control.

## Quick Reference

### Common Operations

```csharp
// Open database
using var db = new XmlDatabase("./data");

// Create container
var products = db.CreateContainer("products");

// Store document
products.PutDocument("p1.xml", "<product><name>Widget</name></product>");

// Query
var names = db.Query("collection('products')//name/text()");
foreach (var name in names) Console.WriteLine(name);

// Transaction
using (var txn = db.BeginTransaction())
{
    txn.GetContainer("products").PutDocument("p2.xml", xml);
    txn.Commit();
}

// Create index
products.CreateIndex(new PathIndex("name-idx", "/product/name"));
```

### Error Handling

```csharp
try
{
    db.Query(xquery);
}
catch (XQueryException ex)
{
    // Query syntax or runtime error
    Console.WriteLine($"XQuery error: {ex.ErrorCode} - {ex.Message}");
}
catch (DocumentNotFoundException ex)
{
    // Document doesn't exist
    Console.WriteLine($"Document not found: {ex.DocumentName}");
}
catch (ContainerNotFoundException ex)
{
    // Container doesn't exist
    Console.WriteLine($"Container not found: {ex.ContainerName}");
}
catch (TransactionException ex)
{
    // Transaction error
    Console.WriteLine($"Transaction failed: {ex.Message}");
}
```

## Interfaces

### IContainer

```csharp
interface IContainer
{
    string Name { get; }
    ContainerOptions Options { get; }

    // Documents
    void PutDocument(string name, string content);
    void PutDocument(string name, Stream content);
    string GetDocument(string name);
    bool DocumentExists(string name);
    void DeleteDocument(string name);
    IEnumerable<string> ListDocuments(string prefix = null);

    // JSON
    void PutJsonDocument(string name, string json);
    string GetJsonDocument(string name);

    // Metadata
    DocumentMetadata GetMetadata(string name);
    void SetMetadata(string name, DocumentMetadata metadata);

    // Indexes
    void CreateIndex(IndexDefinition index);
    void DropIndex(string name);
    IEnumerable<IndexInfo> ListIndexes();
}
```

### ITransaction

```csharp
interface ITransaction : IDisposable
{
    bool IsReadOnly { get; }
    TransactionState State { get; }

    IContainer GetContainer(string name);
    IQueryResult Query(string xquery);
    void Execute(string xqueryUpdate);

    void Commit();
    void Abort();
}
```

### IQueryResult

```csharp
interface IQueryResult : IEnumerable<string>
{
    int Count { get; }
    bool IsEmpty { get; }

    string First();
    string FirstOrDefault();
    T First<T>();
    IEnumerable<T> As<T>();
}
```

## Thread Safety

| Operation | Thread Safe |
|-----------|-------------|
| Read queries | Yes (concurrent reads allowed) |
| Write operations | No (single writer at a time) |
| Create/delete container | No |
| Read-only transactions | Yes (multiple concurrent) |
| Read-write transactions | No (serialized) |

## Performance Guidelines

1. **Reuse XmlDatabase instance** - Don't create/dispose frequently
2. **Use read-only transactions** - When only reading
3. **Batch writes** - Group multiple writes in one transaction
4. **Create indexes** - For frequently queried paths
5. **Use parameters** - Avoid query string concatenation

## Next Steps

| Management | Operations | Execution |
|------------|------------|-----------|
| **[API Containers](containers.md)**<br>Container management | **[API Documents](documents.md)**<br>Document operations | **[API Queries](queries.md)**<br>Query execution |
