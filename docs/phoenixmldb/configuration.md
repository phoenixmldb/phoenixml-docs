---
title: Configuration
description: Database options, environment variables, logging, and connection strings
sort: 8
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

## Environment Variables

```bash
# Override default map size
export PHOENIXMLDB_MAP_SIZE=10737418240

# Set maximum readers
export PHOENIXMLDB_MAX_READERS=256

# Enable debug logging
export PHOENIXMLDB_LOG_LEVEL=Debug
```

## Configuration File

Create `phoenixmldb.json` in the database directory:

```json
{
    "storage": {
        "mapSize": "10GB",
        "maxContainers": 100,
        "maxReaders": 126,
        "syncMode": "normal"
    },
    "query": {
        "defaultTimeout": "30s",
        "maxResults": 10000,
        "enableOptimizer": true
    },
    "indexing": {
        "autoIndex": true,
        "defaultIndexOptions": {
            "pathIndex": true,
            "valueIndex": false
        }
    },
    "logging": {
        "level": "Information",
        "file": "logs/phoenixmldb.log"
    }
}
```

### Load Configuration

```csharp
var config = PhoenixmlDbConfiguration.Load("./data/phoenixmldb.json");
using var db = new XmlDatabase("./data", config.ToOptions());
```

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

### Default Index Options

```csharp
var containerOptions = new ContainerOptions
{
    IndexOnStore = true,
    DefaultIndexes =
    [
        new PathIndex("id-idx", "/@id"),
        new PathIndex("name-idx", "/*/name")
    ]
};

var container = db.CreateContainer("products", containerOptions);
```

### Full-Text Defaults

```csharp
var ftOptions = new FullTextOptions
{
    Language = "en",
    Stemming = true,
    StopWords = true,
    MinTokenLength = 2
};

container.CreateIndex(new FullTextIndex("search", "//text()", ftOptions));
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

For server mode, additional settings are available:

```json
{
    "server": {
        "host": "0.0.0.0",
        "port": 5432,
        "maxConnections": 100,
        "authentication": {
            "enabled": true,
            "type": "basic"
        },
        "tls": {
            "enabled": true,
            "certificate": "/path/to/cert.pem",
            "key": "/path/to/key.pem"
        }
    }
}
```

## Cluster Configuration

For cluster mode:

```json
{
    "cluster": {
        "nodeId": "node-1",
        "peers": [
            "node-2:5433",
            "node-3:5433"
        ],
        "raft": {
            "electionTimeout": "150ms",
            "heartbeatInterval": "50ms"
        },
        "sharding": {
            "enabled": true,
            "shardCount": 16,
            "replicationFactor": 3
        }
    }
}
```
