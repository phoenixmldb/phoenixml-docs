---
title: Embedded Mode
description: Run PhoenixmlDb as an in-process library — no separate server needed
sort: 1
---

# Embedded Mode

Embedded mode runs PhoenixmlDb directly within your application process, providing the simplest deployment option with the best performance for single-application scenarios.

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

```bash
dotnet add package PhoenixmlDb
```

## Basic Usage

```csharp
using PhoenixmlDb;

// Open or create database
using var db = new XmlDatabase("./data");

// Create container
var products = db.CreateContainer("products");

// Store document
products.PutDocument("p1.xml", "<product><name>Widget</name></product>");

// Query
var results = db.Query("collection('products')//name/text()");
```

## Configuration

```csharp
var options = new DatabaseOptions
{
    MapSize = 1L * 1024 * 1024 * 1024,  // 1 GB
    MaxContainers = 50,
    MaxReaders = 126
};

using var db = new XmlDatabase("./data", options);
```

## Lifecycle Management

### Application Startup

```csharp
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<XmlDatabase>(sp =>
        {
            var path = Configuration["Database:Path"];
            var options = new DatabaseOptions
            {
                MapSize = Configuration.GetValue<long>("Database:MapSize")
            };
            return new XmlDatabase(path, options);
        });
    }
}
```

### Application Shutdown

```csharp
public class Shutdown
{
    private readonly XmlDatabase _db;

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        // Flush pending writes
        _db.Flush();

        // Dispose (closes all handles)
        _db.Dispose();
    }
}
```

## Multi-Threading

### Thread Safety

| Operation | Thread Safe |
|-----------|-------------|
| Read queries | Yes |
| Write operations | Single writer |
| Read transactions | Multiple concurrent |
| Write transactions | Serialized |

### Recommended Pattern

```csharp
public class ProductRepository
{
    private readonly XmlDatabase _db;

    public ProductRepository(XmlDatabase db)
    {
        _db = db;
    }

    public IEnumerable<string> GetAllProducts()
    {
        // Read-only transaction allows concurrent access
        using var txn = _db.BeginTransaction(readOnly: true);
        return txn.Query("collection('products')//product").ToList();
    }

    public void AddProduct(string xml)
    {
        // Write transaction - serialized
        using var txn = _db.BeginTransaction();
        txn.GetContainer("products").PutDocument($"p-{Guid.NewGuid()}.xml", xml);
        txn.Commit();
    }
}
```

## Multiple Processes

> **Warning:** LMDB supports only one writer process at a time.

### Read-Only Access

Multiple processes can open the same database read-only:

```csharp
// Process 1 - read/write
using var db = new XmlDatabase("./shared-data");

// Process 2 - read-only
using var db = new XmlDatabase("./shared-data", new DatabaseOptions
{
    ReadOnly = true
});
```

### File Locking

By default, LMDB uses file locking. For single-process scenarios:

```csharp
var options = new DatabaseOptions
{
    NoLock = true  // Only if guaranteed single-process access
};
```

## Backup and Recovery

### Online Backup

```csharp
// Backup while application is running
db.Backup("./backup");
```

### Restore

```csharp
// Stop application
// Copy backup to data directory
// Restart application
Directory.Delete("./data", true);
Directory.Move("./backup", "./data");
```

## Desktop Applications

### WPF Example

```csharp
public partial class App : Application
{
    public static XmlDatabase Database { get; private set; }

    protected override void OnStartup(StartupEventArgs e)
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var dbPath = Path.Combine(appData, "MyApp", "data");
        Directory.CreateDirectory(dbPath);

        Database = new XmlDatabase(dbPath);
        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Database?.Dispose();
        base.OnExit(e);
    }
}
```

### Avalonia/MAUI Example

```csharp
public static class MauiProgram
{
    public static XmlDatabase Database { get; private set; }

    public static MauiApp CreateMauiApp()
    {
        var dbPath = Path.Combine(FileSystem.AppDataDirectory, "data");
        Database = new XmlDatabase(dbPath);

        var builder = MauiApp.CreateBuilder();
        builder.Services.AddSingleton(Database);

        return builder.Build();
    }
}
```

## ASP.NET Core

### Registration

```csharp
builder.Services.AddSingleton<XmlDatabase>(sp =>
{
    var env = sp.GetRequiredService<IWebHostEnvironment>();
    var path = Path.Combine(env.ContentRootPath, "data");
    return new XmlDatabase(path);
});
```

### Health Check

```csharp
builder.Services.AddHealthChecks()
    .AddCheck("database", () =>
    {
        try
        {
            var db = serviceProvider.GetRequiredService<XmlDatabase>();
            var count = db.QuerySingle<int>("count(collection('health')//*)");
            return HealthCheckResult.Healthy();
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(ex.Message);
        }
    });
```

## Best Practices

1. **Single instance** - Create one XmlDatabase per application
2. **Dispose properly** - Always dispose on shutdown
3. **Use transactions** - For consistent operations
4. **Prefer read-only** - When only reading
5. **Configure MapSize** - Based on expected data size
6. **Regular backups** - Implement backup strategy

## When to Upgrade

Consider Server or Cluster mode when:
- Multiple applications need access
- High availability is required
- Data exceeds single machine capacity
- Geographic distribution needed

## Next Steps

| Deployment | Configuration | Optimization |
|------------|---------------|--------------|
| **[Server Mode](server-mode.md)**<br>Multi-client access | **[Configuration](configuration.md)**<br>Advanced settings | **[Performance Tuning](performance-tuning.md)**<br>Optimization |
