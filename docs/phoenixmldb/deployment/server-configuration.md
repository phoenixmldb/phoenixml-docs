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

## REST server resource limits

These sections apply to the **REST server** (except `RegexMatchTimeoutMs`, which applies to both).

### Queries: `PhoenixmlDb:Query`

| Setting | Default | Notes |
|---|---|---|
| `DefaultTimeoutSeconds` | `30` | Used when neither the request nor the container sets a timeout. |
| `MaxTimeoutSeconds` | `300` | Upper bound on any query timeout. |
| `MaxResults` | `10000` | A request's `MaxResults` is clamped to this. |
| `DefaultPageSize` | `100` | Also used for document listings (previously 50). |
| `MaxPageSize` | `1000` | |
| `EnableCaching` | `false` | Compiled-plan caching isn't available yet; `true` stops startup. |
| `CacheSize` | `100` | Stored compiled-query handles. An evicted or unknown handle returns `404`. |
| `RegexMatchTimeoutMs` | `2000` | 1 to 2147483646. Bounds regular-expression evaluation in **both** servers: a regex that runs past it returns `504` (REST) or `DeadlineExceeded` (gRPC). |

**Query timeout.** The limit applied is the first that is set of the request's `TimeoutSeconds`,
the container's `QueryTimeoutSeconds` and `DefaultTimeoutSeconds`, then capped at
`MaxTimeoutSeconds`. It's checked between evaluation steps. When it's reached the server returns
`504 QUERY_TIMEOUT`, and the response's `limitSource` says which limit applied.

**Results.** `MaxResults` below 1 or `Skip` below 0 returns `400`. `HasMore` reports whether more
results exist, and `TotalCount` is the number of items returned.

### Documents: `PhoenixmlDb:Documents`

| Setting | Default | Over the limit |
|---|---|---|
| `MaxDocumentSize` | 10 MB | `413`, naming whether the server or the container limit applied |
| `MaxRequestBodySize` | 50 MB | `413` (the HTTP request limit) |
| `MaxMetadataSize` | 64 KB | `400` |
| `MaxTags` | `50` | `400` |
| `MaxTagLength` | `128` | `400` |

A write that doesn't grow a document's metadata is allowed even if the document is already over a
limit that has since been lowered.

### Transformations: `PhoenixmlDb:Transform`

| Setting | Default | Notes |
|---|---|---|
| `MaxExecutionTimeSeconds` | `60` | Over it returns `504`. |
| `MaxConcurrentTransforms` | `16` | When reached, new transforms get `503`. |
| `MaxAbandonedTransforms` | `4` | Transforms still running after their time limit; when reached, new transforms get `503`. |
| `MaxStylesheets` | `1000` | Registering beyond it returns `409`. |
| `AllowedOutputMethods` | `xml`, `html`, `xhtml`, `text`, `json` | A stylesheet whose `xsl:output` method isn't listed returns `400`, at registration and when it runs. A configured list replaces the default. |
| `CacheStylesheets` | `true` | |
| `StylesheetCacheSize` | `50` | |

The response content type follows the stylesheet's output method: `method="text"` returns
`text/plain`.

### New containers: `PhoenixmlDb:Containers:Defaults`

| Setting | Default | Notes |
|---|---|---|
| `VersioningEnabled` | `false` | |
| `MaxVersions` | `20` | At least 1. |
| `ValidateOnWrite` | `false` | |
| `DefaultSchemaId` | | The schema's Id, or its Name when the name is unique. |
| `AllowJson` | `true` | |
| `DefaultNamespaces` | | Applied to new containers only. A prefix the XQuery compiler refuses, such as `fn`, stops startup. |

A container's own settings override these. In the API, the container fields `VersioningEnabled`,
`ValidateOnWrite`, `AllowJson`, `MaxDocumentSize`, `QueryTimeoutSeconds` and `MaxVersions` are
nullable: `null` means "use the server default". A `PUT` merges settings, so a field left out keeps
its stored value; a field can't be reset to the server default through `PUT`. `DefaultNamespaces`
are fixed when the container is created, and changing them on a `PUT` returns `400`. Containers
created before this release keep their stored 10 MB document limit and 30 s query limit until you
`PUT` new settings.

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
warning naming the replacement, so upgrading changes nothing for them:

| Ignored | Replacement |
|---|---|
| `XrxServer:Database:Path`, `MaxSizeMb`, `MaxReaders`, `CreateIfMissing` | `PhoenixmlDb:Storage:DataPath`, `MapSizeMb`, `MaxReaders`, `CreateIfMissing` |
| `XrxServer:Query:*` | `PhoenixmlDb:Query:*` |
| `XrxServer:DocumentLimits:*` | `PhoenixmlDb:Documents:*` |
| `XrxServer:Transform:*` | `PhoenixmlDb:Transform:*` |
| `XrxServer:DefaultContainer:*` | `PhoenixmlDb:Containers:Defaults:*` |
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

## Startup events

| Event id | Meaning |
|---|---|
| 3001 | `EffectiveConfiguration`: the settings in use (see above) |
| 3002 | a legacy key was used, or an ignored key was set |
| 3003 | the regular-expression time bound couldn't be applied |
| 3004 | a transformation was abandoned at its time limit |
| 3005 | versioning is off but a version limit is configured |
| 3006 | `RegexMatchTimeoutMs` is higher than a time limit it should fit inside |

Client errors (`4xx`) are logged at Information. Deliberate refusals, such as a schema type that
isn't supported for validation, return `501`.

## Embedded applications

An embedded application configures storage in code, with `LmdbStorageOptions` (for example
`MapSize`, `MaxReaders`, `MaxDatabases` and `CreateIfMissing`). `DocumentDatabase` validates them,
and an invalid value throws `ArgumentException`.
