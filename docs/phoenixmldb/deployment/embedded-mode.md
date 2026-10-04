---
title: Embedded Mode
description: Run PhoenixmlDb as an in-process library — no separate server needed
sort: 1
---

# Embedded Mode

Embedded mode runs PhoenixmlDb directly within your application process: no separate server, no
network hop. It suits a single application that owns its data.

## Overview

```
┌─────────────────────────────────────┐
│         Your Application            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │       PhoenixmlDb           │   │
│  │  ┌─────────┐  ┌─────────┐   │   │
│  │  │ Query   │  │ Storage │   │   │
│  │  │ Engine  │  │  (LMDB) │   │   │
│  │  └─────────┘  └─────────┘   │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
            │
            ▼
    ┌───────────────┐
    │  Data Files   │
    │  (data.mdb)   │
    └───────────────┘
```

## Installation

The embedded database is the `PhoenixmlDb.Storage` package (with `PhoenixmlDb.Indexing` for index
maintenance and `PhoenixmlDb.Json` for JSON support). These packages are **not yet published on
NuGet**. Only `PhoenixmlDb.Core`, `PhoenixmlDb.XQuery` and `PhoenixmlDb.Xslt` are published.

## Basic Usage

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Storage;

// Open or create database
await using var db = new DocumentDatabase("./data");

// Create container
var products = await db.CreateContainerAsync("products");

// Store document
await products.PutDocumentAsync("p1.xml", "<product><name>Widget</name></product>");

// Query
await foreach (var item in products.QueryAsync("collection()//name/text()"))
{
    Console.WriteLine(item);
}
```

A query runs against one container; inside it, `collection()` is every document in that
container.

## Configuration

Storage settings are an `LmdbStorageOptions` record, passed to the constructor:

```csharp
var options = new LmdbStorageOptions
{
    MapSize = 1L * 1024 * 1024 * 1024,  // 1 GiB
    MaxReaders = 126
};

await using var db = new DocumentDatabase("./data", options);
```

| Option | Default | Meaning |
|--------|---------|---------|
| `MapSize` | 50 GiB (64-bit), 1 GiB (32-bit) | Fixed virtual address reservation for the memory map, set at open. `data.mdb` grows sparsely up to it. When it is exhausted, writes throw `PhoenixmlDbStorageException`; the map never grows at runtime. |
| `MaxReaders` | 126 | Maximum concurrent readers. |
| `MaxDatabases` | 64 | Maximum LMDB named databases. Must cover the ones the engine opens. |
| `NoSync` | `false` | Skip filesystem syncs: faster, but data may be lost on a system crash. |
| `WriteMap` | `false` | Use LMDB's `MDB_WRITEMAP` mode. |
| `CreateIfMissing` | `true` | When `false`, a missing directory throws `DirectoryNotFoundException` instead of being created. |
| `RestoreFromPath`, `RestoreFromDirectory`, `RestoreFromStream`, `RestoreOverwrite` | none | Restore from a backup on open; see [Restore](#restore). |
| `LoggerFactory` | none | `ILoggerFactory` to log through. Without one, warnings and errors go to `System.Diagnostics.Trace`. |

Invalid options (for example a `MapSize` of zero) make the constructor throw an
`ArgumentException` that names every problem.

### Resource access

`DocumentDatabase.ResourceAccessPolicy` defaults to `ResourceAccessPolicy.DenyAll`: queries and
stylesheets read stored documents only, with no local files or network requests. Allow specific
directories and HTTP origins with `ResourceAccessPolicy.Create(...)`. See
[Resource Access](../resource-access.md).

### Indexing

`ContainerOptions.Indexes` is only a declaration until index maintenance is attached:

```csharp
using PhoenixmlDb.Indexing;

db.EnableIndexing();  // the database owns the returned IndexManager and disposes it
```

## Lifecycle Management

### Application Startup

```csharp
builder.Services.AddSingleton(sp =>
{
    var configuration = sp.GetRequiredService<IConfiguration>();
    var path = configuration["Database:Path"] ?? "./data";
    var options = new LmdbStorageOptions
    {
        MapSize = configuration.GetValue<long>("Database:MapSize", LmdbStorageOptions.Default.MapSize)
    };
    return new DocumentDatabase(path, options);
});
```

The DI container disposes the singleton when the host shuts down.

### Application Shutdown

```csharp
// Flush pending writes to disk
await db.FlushAsync();

// Dispose (closes all handles)
await db.DisposeAsync();
```

`DocumentDatabase` also registers a process-exit handler that disposes it, with a bounded wait, if
the application exits without doing so.

## Multi-Threading

### Thread Safety

| Operation | Behaviour |
|-----------|-----------|
| Queries and read transactions (`BeginRead`) | Concurrent. A read transaction sees a snapshot taken when it began. |
| Write transactions (`BeginWriteAsync`) | One at a time per database. `BeginWriteAsync` waits for the write lock; the `BeginWriteAsync(TimeSpan timeout)` overload throws `TransactionTimeoutException` if it cannot get it in time. |
| Opening | One `DocumentDatabase` per directory per process. Opening a second one on the same path throws `LmdbEnvironmentAlreadyOpenException`. |

A write transaction buffers its operations and applies them in one LMDB transaction on
`CommitAsync`. Disposing it without committing discards them.

### Recommended Pattern

```csharp
public sealed class ProductRepository(DocumentDatabase db)
{
    public async Task<List<object>> GetAllProductsAsync(CancellationToken ct = default)
    {
        var products = await db.OpenContainerAsync("products", ct)
            ?? throw new InvalidOperationException("Container 'products' does not exist.");

        // Read transaction: a consistent snapshot, concurrent with other readers
        using var txn = db.BeginRead();
        var results = new List<object>();
        await foreach (var item in txn.QueryAsync(products.Id, "collection()//product", cancellationToken: ct))
        {
            results.Add(item);
        }
        return results;
    }

    public async Task AddProductAsync(string xml, CancellationToken ct = default)
    {
        var products = await db.OpenOrCreateContainerAsync("products", cancellationToken: ct);

        // Write transaction: serialized with other writers
        await using var txn = await db.BeginWriteAsync(ct);
        await txn.PutDocumentAsync(products.Id, $"p-{Guid.NewGuid()}.xml", xml, cancellationToken: ct);
        await txn.CommitAsync(ct);
    }
}
```

## Multiple Processes

Opening a database read-only is not currently supported: `LmdbStorageOptions.ReadOnly` exists,
but opening a `DocumentDatabase` with it set fails. To share one database between applications,
run it in [Server Mode](server-mode.md) and connect the applications as clients.

## Backup and Recovery

> **Warning: back up only when no writes are in progress.** A backup taken while the database is
> being written can contain torn, inconsistent data: in testing, 11 of 15 backups taken during writes
> were affected, and 0 of 15 with no writer (phoenixml #87). This applies to `BackupAsync`,
> `BackupToStreamAsync`, `BackupService`, the gRPC admin backup and cluster snapshots. Pause writes
> while a backup runs until #87 is fixed.

### Backup

```csharp
// Flushes, then copies data.mdb to the destination file (parent directories are created)
await db.BackupAsync("./backups/data-2026-10-04.mdb");

// Or write the backup to a stream, for example an upload
await using var stream = File.Create("./backups/latest.mdb");
await db.BackupToStreamAsync(stream);
```

The `compact` parameter is accepted but currently has no effect. `DocumentDatabase.ListBackups(directory)`
lists the `.mdb` files in a directory, newest first.

### Restore

Restore while the database is closed:

```csharp
// Stop using the database (dispose it) first
await DocumentDatabase.RestoreAsync("./data", "./backups/data-2026-10-04.mdb", overwrite: true);

await using var db = new DocumentDatabase("./data");
```

Without `overwrite: true`, `RestoreAsync` throws if `./data` already holds a database.
Alternatively, set `RestoreFromPath`, `RestoreFromDirectory` (the `.mdb` file in it whose name
sorts last) or `RestoreFromStream` in `LmdbStorageOptions`; the restore then happens on open when
the database is missing or empty, or always when `RestoreOverwrite` is `true`. Name backup files so
that they sort by date, as in the example above.

## Desktop Applications

### WPF Example

```csharp
public partial class App : Application
{
    public static DocumentDatabase? Database { get; private set; }

    protected override void OnStartup(StartupEventArgs e)
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var dbPath = Path.Combine(appData, "MyApp", "data");

        Database = new DocumentDatabase(dbPath);  // creates the directory if missing
        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Database?.Dispose();
        base.OnExit(e);
    }
}
```

## ASP.NET Core

### Registration

```csharp
builder.Services.AddSingleton(sp =>
{
    var env = sp.GetRequiredService<IWebHostEnvironment>();
    var path = Path.Combine(env.ContentRootPath, "data");
    return new DocumentDatabase(path);
});
```

### Health Check

`GetHealth()` never throws; it reports whether the database is open and how much of the map is in
use.

```csharp
public sealed class DocumentDatabaseHealthCheck(DocumentDatabase db) : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        var health = db.GetHealth();
        return Task.FromResult(health.IsOpen
            ? HealthCheckResult.Healthy($"Map {health.MapUsedFraction:P0} used")
            : HealthCheckResult.Unhealthy("Database is not open"));
    }
}

builder.Services.AddHealthChecks()
    .AddCheck<DocumentDatabaseHealthCheck>("database");
```

## Best Practices

1. **Single instance** - Create one `DocumentDatabase` per database directory per application
2. **Dispose properly** - Always dispose on shutdown
3. **Use transactions** - For consistent multi-document operations
4. **Use read transactions** - `BeginRead` for consistent multi-query reads
5. **Configure MapSize** - Based on expected data size; it cannot grow at runtime
6. **Regular backups** - Implement backup strategy

## When to Upgrade

Consider Server or Cluster mode when:
- Multiple applications need access
- High availability is required

## Next Steps

| Deployment | Configuration | Optimization |
|------------|---------------|--------------|
| **[Server Mode](server-mode.md)**<br>Multi-client access | **[Configuration](../configuration.md)**<br>Advanced settings | **[Performance Tuning](../performance-tuning.md)**<br>Optimization |
