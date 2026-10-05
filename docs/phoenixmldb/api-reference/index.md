---
title: API Reference
description: PhoenixmlDb .NET API — interfaces, classes, and usage patterns
sort: 11
---

# API Reference

This section documents the embedded PhoenixmlDb API: the `DocumentDatabase` entry point in `PhoenixmlDb.Storage`, and the interfaces it implements from `PhoenixmlDb.Core` (`IDocumentDatabase`, `IContainer`, `IDocument`, `IReadTransaction`, `IWriteTransaction`).

> **Packages.** `PhoenixmlDb.Core`, `PhoenixmlDb.XQuery` and `PhoenixmlDb.Xslt` are published on NuGet. The database packages (`PhoenixmlDb.Storage`, `PhoenixmlDb.Indexing`, `PhoenixmlDb.Json` and the rest) are not yet published on NuGet.

Every operation is asynchronous. Names used on this page:

```csharp
using PhoenixmlDb.Core;          // IContainer, IDocument, ContainerOptions, DocumentOptions, exceptions
using PhoenixmlDb.Storage;       // DocumentDatabase
using PhoenixmlDb.Storage.Lmdb;  // LmdbStorageOptions
```

## Core Classes

### DocumentDatabase

The main entry point. `DocumentDatabase` is `sealed`, implements `IDocumentDatabase`, and is both `IDisposable` and `IAsyncDisposable`.

```csharp
// Create/open database
public DocumentDatabase(string path, LmdbStorageOptions? options = null);
public static DocumentDatabase Open(string path, LmdbStorageOptions? options = null);

// Properties
string Path { get; }
LmdbStorageOptions StorageOptions { get; }
DatabaseStatistics Statistics { get; }
ResourceAccessPolicy ResourceAccessPolicy { get; set; }   // see ../resource-access.md

// Container operations
ValueTask<IContainer> CreateContainerAsync(string name,
    Action<ContainerOptions>? configure = null, CancellationToken cancellationToken = default);
ValueTask<IContainer?> OpenContainerAsync(string name, CancellationToken cancellationToken = default);
ValueTask<IContainer> OpenOrCreateContainerAsync(string name,
    Action<ContainerOptions>? configure = null, CancellationToken cancellationToken = default);
ValueTask<bool> DeleteContainerAsync(string name, CancellationToken cancellationToken = default);
IAsyncEnumerable<ContainerInfo> ListContainersAsync(CancellationToken cancellationToken = default);

// Transactions
IReadTransaction BeginRead();
ValueTask<IWriteTransaction> BeginWriteAsync(CancellationToken cancellationToken = default);
ValueTask<IWriteTransaction> BeginWriteAsync(TimeSpan timeout, CancellationToken cancellationToken = default);

// Documents by id (scoped to a container)
ValueTask<IDocument?> GetDocumentByIdAsync(ContainerId containerId, DocumentId documentId,
    CancellationToken cancellationToken = default);
ValueTask<bool> DeleteDocumentByIdAsync(ContainerId containerId, DocumentId documentId,
    CancellationToken cancellationToken = default);
ValueTask<bool> UpdateDocumentByIdAsync(ContainerId containerId, DocumentId documentId, string content,
    CancellationToken cancellationToken = default);

// Indexes (see indexes.md)
ValueTask<IndexRebuildResult> RebuildIndexesAsync(string containerName, CancellationToken cancellationToken = default);
IReadOnlyList<string> ContainersWithStaleIndexes();
ValueTask<IReadOnlyDictionary<string, IndexRebuildResult>> RebuildStaleIndexesAsync(
    CancellationToken cancellationToken = default);

// Storage management
ValueTask FlushAsync(CancellationToken cancellationToken = default);
Task BackupAsync(string destinationPath, bool compact = true, CancellationToken cancellationToken = default);
Task BackupToStreamAsync(Stream destination, bool compact = true, CancellationToken cancellationToken = default);
static Task RestoreAsync(string databasePath, string backupPath, bool overwrite = false);
static Task RestoreFromStreamAsync(string databasePath, Stream source, bool overwrite = false,
    CancellationToken ct = default);
static IReadOnlyList<BackupInfo> ListBackups(string backupDirectory);
StorageUsage GetStorageUsage();
StorageHealth GetHealth();

// Lifecycle
void Dispose();
ValueTask DisposeAsync();
```

`GetDocumentByIdAsync` returns `null` when the id does not exist or belongs to a different container. By-id lookup scans the database; prefer the by-name methods on `IContainer` when you have the name.

Opening a path that is already open in the same process (by any `DocumentDatabase`, including through an equivalent spelling of the path) throws `LmdbEnvironmentAlreadyOpenException`. Dispose the existing instance first.

Backups are consistent while the database is in use. See [Backup and Recovery](../documents-and-storage.md#backup-and-recovery)
for guidance on which API to use; see
[Read-Only Mode](../documents-and-storage.md#read-only-mode) for the
constraints on `ReadOnly = true`.

### LmdbStorageOptions

`LmdbStorageOptions` (`PhoenixmlDb.Storage.Lmdb`) is an immutable record; set properties with an object initializer. Passing `null` uses `LmdbStorageOptions.Default`. The options are validated when the database opens, and invalid values throw `ArgumentException` naming every problem.

```csharp
var options = new LmdbStorageOptions
{
    MapSize = 10L * 1024 * 1024 * 1024,  // 10 GB address-space reservation
    MaxDatabases = 64,                     // Maximum named LMDB databases
    MaxReaders = 126,                      // Maximum concurrent readers
    NoSync = false,                        // Sync on commit
    WriteMap = false,                      // MDB_WRITEMAP
    ReadOnly = false,                      // Open read-only
    CreateIfMissing = true                 // Create the directory if absent
};

await using var db = new DocumentDatabase("./data", options);
```

| Property | Type | Default |
|----------|------|---------|
| `MapSize` | `long` | 50 GiB on a 64-bit process |
| `MaxDatabases` | `int` | `64` |
| `MaxReaders` | `int` | `126` |
| `NoSync` | `bool` | `false` |
| `WriteMap` | `bool` | `false` |
| `ReadOnly` | `bool` | `false` |
| `CreateIfMissing` | `bool` | `true` |
| `RestoreFromPath` | `string?` | `null` — backup file to restore from if the database does not exist |
| `RestoreFromDirectory` | `string?` | `null` — directory whose most recent backup is restored |
| `RestoreFromStream` | `Func<CancellationToken, Task<Stream>>?` | `null` |
| `RestoreOverwrite` | `bool` | `false` |
| `LoggerFactory` | `ILoggerFactory?` | `null` |

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

### [XSLT API](xslt-api.md)
XsltTransformer — stream-based transforms, result document handling, source/mode selection, and collection binding.

## Quick Reference

### Common Operations

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Indexing;
using PhoenixmlDb.Storage;

// Open database; indexes are maintained only after EnableIndexing()
await using var db = new DocumentDatabase("./data");
db.EnableIndexing();

// Create container, declaring a path index
var products = await db.CreateContainerAsync("products",
    opts => opts.Indexes.AddPathIndex("/product/name"));

// Store document
await products.PutDocumentAsync("p1.xml", "<product><name>Widget</name></product>");

// Query (results are serialized strings)
await foreach (var name in products.QueryAsync("//name/text()"))
    Console.WriteLine(name);

// Transaction
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(products.Id, "p2.xml", "<product><name>Gadget</name></product>");
    await txn.CommitAsync();
}
```

### Error Handling

```csharp
try
{
    await foreach (var item in products.QueryAsync(xquery))
        Console.WriteLine(item);
}
catch (PhoenixmlDb.XQuery.Functions.XQueryException ex)
{
    // Query failed to compile (for example XPST0003, a syntax error)
    Console.WriteLine($"XQuery error: {ex.ErrorCode} - {ex.Message}");
}
catch (PhoenixmlDb.XQuery.Execution.XQueryRuntimeException ex)
{
    // Dynamic error while evaluating
    Console.WriteLine($"XQuery runtime error: {ex.ErrorCode} - {ex.Message}");
}

try
{
    await products.SetMetadataAsync("missing.xml", "author", "jdoe");
}
catch (DocumentNotFoundException ex)
{
    // Document doesn't exist
    Console.WriteLine($"Document not found: {ex.DocumentName}");
}

try
{
    await using var txn = await db.BeginWriteAsync(TimeSpan.FromSeconds(5));
    // ...
    await txn.CommitAsync();
}
catch (TransactionTimeoutException ex)
{
    // The write lock was not acquired in time
    Console.WriteLine($"Transaction failed: {ex.Message}");
}
```

`PhoenixmlDb.Core` defines the database exception hierarchy, rooted at `XmlDbException`: `ContainerNotFoundException`, `DocumentNotFoundException`, `DocumentExistsException`, `DocumentParseException`, `TransactionException` and its subclass `TransactionTimeoutException`. Storage-layer failures derive from `PhoenixmlDbStorageException` (`PhoenixmlDb.Storage`). Query errors come from the XQuery engine package: compilation errors raise `PhoenixmlDb.XQuery.Functions.XQueryException`, dynamic errors raise `PhoenixmlDb.XQuery.Execution.XQueryRuntimeException`. Malformed document content surfaces as the parser's own exception (`System.Xml.XmlException`, `System.Text.Json.JsonException`).

## Interfaces

### IContainer

```csharp
public interface IContainer
{
    ContainerId Id { get; }
    string Name { get; }
    ContainerOptions Options { get; }

    // Documents
    ValueTask PutDocumentAsync(string name, string content, DocumentOptions? options = null,
        CancellationToken cancellationToken = default);
    ValueTask PutDocumentAsync(string name, Stream content, DocumentOptions? options = null,
        CancellationToken cancellationToken = default);
    ValueTask<int> PutDocumentsAsync(IEnumerable<DocumentInput> documents,
        CancellationToken cancellationToken = default);
    ValueTask<IDocument?> GetDocumentAsync(string name, CancellationToken cancellationToken = default);
    ValueTask<bool> DeleteDocumentAsync(string name, CancellationToken cancellationToken = default);
    ValueTask<bool> DocumentExistsAsync(string name, CancellationToken cancellationToken = default);
    IAsyncEnumerable<DocumentInfo> ListDocumentsAsync(CancellationToken cancellationToken = default);
    IAsyncEnumerable<DocumentInfo> ListDocumentsAsync(string prefix, CancellationToken cancellationToken = default);

    // Queries
    IAsyncEnumerable<object> QueryAsync(string query,
        IReadOnlyDictionary<string, object>? variables = null, CancellationToken cancellationToken = default);
    IAsyncEnumerable<object> QueryAsync(string query, IReadOnlyDictionary<string, object>? variables,
        Predicate<string>? documentNameFilter, CancellationToken cancellationToken = default);

    // Metadata (string, typed-descriptor and XdmQName overloads)
    ValueTask SetMetadataAsync(string documentName, string name, string value,
        CancellationToken cancellationToken = default);
    ValueTask<string?> GetMetadataAsync(string documentName, string name,
        CancellationToken cancellationToken = default);
    ValueTask<MetadataCollection> GetAllMetadataAsync(string documentName,
        CancellationToken cancellationToken = default);
    IAsyncEnumerable<DocumentInfo> QueryMetadataAsync(XdmQName name, XdmValue value,
        CancellationToken cancellationToken = default);
    // ... see documents.md for the full metadata surface
}
```

There are no index members on `IContainer`; indexes are declared through `ContainerOptions.Indexes` when the container is created (see [Index API](indexes.md)).

### IDocument

```csharp
public interface IDocument
{
    DocumentId Id { get; }
    string Name { get; }
    ContainerId Container { get; }
    DateTimeOffset Created { get; }
    DateTimeOffset Modified { get; }
    long SizeBytes { get; }
    ContentType ContentType { get; }

    ValueTask<string> GetContentAsync(CancellationToken cancellationToken = default);
    ValueTask<Stream> GetContentStreamAsync(CancellationToken cancellationToken = default);
    ValueTask<IXdmNode> GetRootNodeAsync(CancellationToken cancellationToken = default);
    ValueTask<XdmValue?> GetMetadataAsync(XdmQName name, CancellationToken cancellationToken = default);
    ValueTask<MetadataCollection> GetAllMetadataAsync(CancellationToken cancellationToken = default);
}
```

### IReadTransaction / IWriteTransaction

```csharp
public interface IReadTransaction : IDisposable, IAsyncDisposable
{
    long TransactionId { get; }
    bool IsActive { get; }

    ValueTask<IDocument?> GetDocumentAsync(ContainerId container, string name,
        CancellationToken cancellationToken = default);
    IAsyncEnumerable<object> QueryAsync(ContainerId container, string xquery,
        IReadOnlyDictionary<string, object>? variables = null, CancellationToken cancellationToken = default);
    IAsyncEnumerable<DocumentInfo> ListDocumentsAsync(ContainerId container,
        CancellationToken cancellationToken = default);
}

public interface IWriteTransaction : IReadTransaction
{
    ValueTask PutDocumentAsync(ContainerId container, string name, string content,
        DocumentOptions? options = null, CancellationToken cancellationToken = default);
    ValueTask<bool> DeleteDocumentAsync(ContainerId container, string name,
        CancellationToken cancellationToken = default);
    ValueTask SetMetadataAsync(ContainerId container, string documentName, string name, string value,
        CancellationToken cancellationToken = default);
    // plus typed-descriptor and XdmQName SetMetadataAsync overloads

    ValueTask CommitAsync(CancellationToken cancellationToken = default);
    ValueTask RollbackAsync(CancellationToken cancellationToken = default);
}
```

See [Transaction API](transactions.md) for their semantics.

## Thread Safety

| Operation | Behaviour |
|-----------|-----------|
| Reads and queries | Concurrent with each other and with a writer; they see committed data only |
| `BeginWriteAsync` | One write transaction at a time per database; others wait (or time out) |
| Create/delete container | Serialized on the database write lock |
| An `IWriteTransaction` instance | Not thread-safe; use it from one thread at a time |

## Performance Guidelines

1. **Reuse the `DocumentDatabase` instance** — open it once per process; a second open of the same path throws
2. **Batch writes** — `PutDocumentsAsync` commits up to 1,000 documents per LMDB transaction; an `IWriteTransaction` commits everything it buffered at once
3. **Declare indexes and call `EnableIndexing()`** — for frequently queried paths
4. **Use external variables** — bind values through `QueryAsync`'s `variables` instead of concatenating them into the query string

## Next Steps

| Management | Operations | Execution |
|------------|------------|-----------|
| **[API Containers](containers.md)**<br>Container management | **[API Documents](documents.md)**<br>Document operations | **[API Queries](queries.md)**<br>Query execution |
