---
title: Server Configuration
description: Every PhoenixmlDb server setting — storage, full-text indexing, schema validation — with defaults, startup validation, legacy keys and the startup summary
sort: 3
---

# Server Configuration

Both servers, the gRPC server and the REST server, read standard .NET configuration:
`appsettings.json`, `appsettings.<Environment>.json`, environment variables and command-line
arguments, later sources winning. As environment variables, write `__` between levels:
`PhoenixmlDb:Storage:DataPath` becomes `PhoenixmlDb__Storage__DataPath`.

**Settings are validated at startup.** A bad value stops the server, and the error names the key.

Other sections are documented with their features:
[Authentication](server-mode.md#authentication) (`Auth`, `PhoenixmlDb:Auth`),
[Resource Access](../resource-access.md) (`PhoenixmlDb:ResourceAccess`),
[gRPC endpoints](server-mode.md#grpc-server) (`PhoenixmlDb:Endpoints`) and
[Cluster Mode](cluster-mode.md) (`PhoenixmlDb:Raft`).

## Storage

`PhoenixmlDb:Storage` applies to **both** servers.

| Setting | Default | Notes |
|---|---|---|
| `DataPath` | `{ContentRoot}/data` | A relative path resolves against the content root. |
| `MapSizeMb` | the engine default, 50 GiB on 64-bit | The storage map size in MB. If an existing store already holds that much data or more, the server refuses to start: a smaller map would make it read-only. |
| `MaxReaders` | `126` | Concurrent read transactions. At least 1. |
| `CreateIfMissing` | `true` | When `false`, a missing data directory stops startup and nothing is created. |

```json
{
  "PhoenixmlDb": {
    "Storage": { "DataPath": "/var/lib/phoenixml", "MapSizeMb": 102400 }
  }
}
```

## Full-text indexing

`PhoenixmlDb:Indexing:FullText` applies to the **gRPC server** only. It tunes the background worker
that applies queued full-text entries (see [Full-Text Search](../full-text-search.md)). The REST
server runs no background full-text worker, so it ignores this section with a warning.

| Setting | Rule |
|---|---|
| `BatchSize` | at least 1 |
| `BudgetMs` | at least 1 |
| `IdleDelayMs` | at least 0 |

## Schema validation

`PhoenixmlDb:Validation` applies to the **REST server**.

| Setting | Default | Notes |
|---|---|---|
| `BasePath` | `./schemas` | A blank value fails startup. |
| `BundlePath` | `./bundles` | A blank value fails startup. |
| `AllowHttpResolution` | | |
| `CacheExpirationMinutes` | `60` | How long compiled schemas stay cached. At least 1. |
| `MaxCacheSize` | | Has no effect; a startup warning says so. |

## Legacy keys

Settings that moved are still accepted for **one release**. Each old key used logs a startup warning
(event id 3002) naming the old key and its replacement; values are never logged. If both the old and
the new key are set, the new key wins.

| Old key | Server | New key |
|---|---|---|
| `PhoenixmlDb:DataPath` | gRPC | `PhoenixmlDb:Storage:DataPath` |
| `Phoenixml:DataPath` | REST | `PhoenixmlDb:Storage:DataPath` |
| `Phoenixml:MaxVersionsPerDocument` | REST | `PhoenixmlDb:Containers:Defaults:MaxVersions` (the per-document version cap, default 20) |
| `Validation:*` | REST | `PhoenixmlDb:Validation:*` |

An old relative data path still resolves against the working directory, as it always did.

**Ignored keys.** `XrxServer:*` keys were never read by any release. They are now ignored with a
warning telling you which new key to set, so upgrading changes nothing for them.
`Validation:EnableXsd11` and `Validation:DefaultSchematronBinding` were never implemented and are
ignored with a warning.

## Startup summary

Each server logs one Information event at startup (event id 3001, `EffectiveConfiguration`) listing
every key that is **set**, one per line, as `key = value (source)`. Defaults aren't listed. The
source is `file:<name>`, `environment`, `command line`, `in-memory` or `legacy:<old key>`.

Secrets are shown as `***`: API keys and their hashes, the JWT secret, the cluster secret and
certificate passwords. The deprecated `Auth:ApiKey:Keys` dictionary is shown only as a count. The
summary is logged even when startup then fails validation, so it's the first place to look when a
server won't start.

## Embedded applications

An embedded application configures storage in code, with `LmdbStorageOptions` (for example
`MapSize`, `MaxReaders`, `MaxDatabases` and `CreateIfMissing`). `DocumentDatabase` validates them,
and an invalid value throws `ArgumentException`.
