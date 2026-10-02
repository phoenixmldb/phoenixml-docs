---
title: Configuration
description: Database options, environment variables, logging, and connection strings
sort: 9
---

# Configuration

This guide covers PhoenixmlDb configuration options for storage, performance, and behavior.

## Database Options

### Basic Configuration

```csharp
var options = new DatabaseOptions
{
    MapSize = 10L * 1024 * 1024 * 1024,  // 10 GB
    MaxContainers = 100,
    MaxReaders = 126
};

using var db = new XmlDatabase("./data", options);
```

### All Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `MapSize` | `long` | 1 GB | Maximum database size |
| `MaxContainers` | `int` | 50 | Maximum containers (databases) |
| `MaxReaders` | `int` | 126 | Maximum concurrent readers |
| `NoSync` | `bool` | `false` | Don't sync on commit |
| `NoMetaSync` | `bool` | `false` | Don't sync metadata |
| `ReadOnly` | `bool` | `false` | Open read-only |
| `WriteMap` | `bool` | `false` | Use writable memory map |
| `NoLock` | `bool` | `false` | Don't use file locking |

## Servers

The servers read their settings from `appsettings.json`, environment variables
(`PhoenixmlDb__Storage__MapSizeMb`) and the command line. See the
[Server Configuration reference](deployment/server-configuration.md).

## Logging

### Configure Logging

```csharp
var options = new DatabaseOptions
{
    Logger = LoggerFactory.Create(builder =>
    {
        builder.AddConsole();
        builder.SetMinimumLevel(LogLevel.Information);
    }).CreateLogger<XmlDatabase>()
};
```

### Log Categories

| Category | Description |
|----------|-------------|
| `PhoenixmlDb.Storage` | Storage operations |
| `PhoenixmlDb.Query` | Query execution |
| `PhoenixmlDb.Index` | Index operations |
| `PhoenixmlDb.Transaction` | Transaction lifecycle |

## Query Settings

```csharp
var queryOptions = new QueryOptions
{
    Timeout = TimeSpan.FromSeconds(30),
    MaxResults = 10000,
    EnableOptimizer = true,
    EnableParallelExecution = false,
    DefaultCollation = "http://www.w3.org/2005/xpath-functions/collation/caseblind"
};

var results = db.Query(xquery, parameters, queryOptions);
```

## Index Settings

There is no separate "default indexes" setting — indexes are declared directly on `ContainerOptions.Indexes` at container-creation time, and that declaration is the only place they're configured. There is also no per-container `IndexOnStore` toggle: whether *any* indexing happens is controlled once per process by calling `db.EnableIndexing()` (see [Indexing](indexing.md)), not per container.

```csharp
var container = await db.CreateContainerAsync("products", opts =>
{
    opts.Indexes
        .AddPathIndex("/@id")
        .AddPathIndex("/*/name");
});
```

### Full-Text Defaults

Full-text options are passed directly to `AddFullTextIndex`, not assembled separately and attached afterward:

```csharp
opts.Indexes.AddFullTextIndex("//description", new FullTextIndexOptions
{
    Language = "en",
    Stemming = true,
    CaseSensitive = false,
    // StopWords is accepted but currently has no effect — see Full-Text Search.
});
```

## Connection Strings

```csharp
// Simple path
var db = new XmlDatabase("./data");

// With options in string
var db = new XmlDatabase("./data;MapSize=10GB;ReadOnly=true");

// Parse connection string
var connStr = new ConnectionString("Path=./data;MapSize=10GB");
var db = new XmlDatabase(connStr);
```

### Connection String Parameters

| Parameter | Example | Description |
|-----------|---------|-------------|
| `Path` | `./data` | Database directory |
| `MapSize` | `10GB` | Maximum size |
| `ReadOnly` | `true` | Read-only mode |
| `NoSync` | `true` | Disable sync |

## Runtime Configuration

### Modify Settings

```csharp
// Some settings can be changed at runtime
db.SetOption("QueryTimeout", TimeSpan.FromSeconds(60));
db.SetOption("MaxResults", 50000);
```

### Get Current Settings

```csharp
var mapSize = db.GetOption<long>("MapSize");
var maxReaders = db.GetOption<int>("MaxReaders");
```

## Server Configuration

See the [Server Configuration reference](deployment/server-configuration.md) for storage,
full-text indexing and validation settings, and [Server Mode](deployment/server-mode.md) for
authentication and endpoints.

## Cluster Configuration

Clustering is configured under `PhoenixmlDb:Raft` on each server. See
[Cluster Mode](deployment/cluster-mode.md) for the settings and the security they require.

