---
title: Configuration
description: Storage options, query resource access, index settings and logging
sort: 9
---

# Configuration

This guide covers PhoenixmlDb configuration options for storage, query resource access and indexing.

## Database Options

### Basic Configuration

Storage options are an `LmdbStorageOptions` record passed to the `DocumentDatabase` constructor.
LMDB fixes them when the environment opens, so they cannot be changed on an open database; reopen
it with new options instead.

```csharp
using PhoenixmlDb.Storage;
using PhoenixmlDb.Storage.Lmdb;

var options = new LmdbStorageOptions
{
    MapSize = 10L * 1024 * 1024 * 1024,  // 10 GiB
    MaxReaders = 126
};

await using var db = new DocumentDatabase("./data", options);
```

Omitting the options uses `LmdbStorageOptions.Default`. The constructor validates the options and
throws one `ArgumentException` naming every problem (a non-positive `MapSize` or `MaxReaders`, or a
`MaxDatabases` below the 16 named databases the engine opens). The options a database was opened
with are available as `db.StorageOptions`.

### All Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `MapSize` | `long` | 50 GiB (64-bit process), 1 GiB (32-bit) | Virtual address space reserved for the memory map, and so the maximum database size. `data.mdb` grows only as data is written |
| `MaxDatabases` | `int` | 64 | Maximum LMDB named databases in the environment. Containers are not named databases |
| `MaxReaders` | `int` | 126 | Maximum concurrent read transactions |
| `NoSync` | `bool` | `false` | Don't sync to disk on commit (faster; data may be lost on a system crash) |
| `WriteMap` | `bool` | `false` | Use a writable memory map (`MDB_WRITEMAP`) |
| `ReadOnly` | `bool` | `false` | Open read-only |
| `CreateIfMissing` | `bool` | `true` | Create the directory if it does not exist; when `false`, a missing directory throws `DirectoryNotFoundException` |
| `RestoreFromPath` | `string?` | `null` | Backup file to restore from when the database is missing or empty |
| `RestoreFromDirectory` | `string?` | `null` | Directory of `*.mdb` backups; the last by file name is restored |
| `RestoreFromStream` | `Func<CancellationToken, Task<Stream>>?` | `null` | Factory for a stream to restore from |
| `RestoreOverwrite` | `bool` | `false` | Restore even when a database already exists |
| `LoggerFactory` | `ILoggerFactory?` | `null` | Logger factory the database logs through (see [Logging](logging.md)) |

The engine never grows the map at runtime. When it is full, writes throw
`PhoenixmlDbStorageException`. Reopening an existing, writable database with a `MapSize` at or below
the space its data already uses throws `LmdbMapSizeTooSmallException`.

## Servers

The servers read their settings from `appsettings.json`, environment variables
(`PhoenixmlDb__Storage__MapSizeMb`) and the command line. See the
[Server Configuration reference](deployment/server-configuration.md).

## Logging

Pass a logger factory with `LmdbStorageOptions.LoggerFactory`. The categories and stable event ids
are on the [Logging](logging.md) page.

## Query Resource Access

Queries can read only the stored documents by default: no local files, no network, no external
entities. To allow more, build a `ResourceAccessPolicy` and assign it to the database. It is read
at the start of each query.

```csharp
using PhoenixmlDb.Storage.Security;

var access = new ResourceAccessOptions();
access.AllowedFileRoots.Add("/srv/reference-data");       // absolute, existing directory
access.AllowedHttpOrigins.Add("https://data.example.com"); // scheme://host[:port], no path

db.ResourceAccessPolicy = ResourceAccessPolicy.Create(access);
```

`ResourceAccessPolicy.Unrestricted` restores unrestricted access. See
[Resource Access](resource-access.md).

## Index Settings

There is no separate "default indexes" setting — indexes are declared directly on `ContainerOptions.Indexes` at container-creation time, and that declaration is the only place they're configured. There is also no per-container `IndexOnStore` toggle: whether *any* indexing happens is controlled once per open database by calling `db.EnableIndexing()` (see [Indexing](indexing.md)), not per container.

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

## Server Configuration

See the [Server Configuration reference](deployment/server-configuration.md) for storage,
full-text indexing and validation settings, and [Server Mode](deployment/server-mode.md) for
authentication and endpoints.

## Cluster Configuration

Clustering is configured under `PhoenixmlDb:Raft` on each server. See
[Cluster Mode](deployment/cluster-mode.md) for the settings and the security they require.

