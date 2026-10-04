---
title: Logging and Telemetry
description: Supplying a logger, the log categories and stable event ids, and the metrics, traces and health the engine publishes
sort: 12
---

# Logging and Telemetry

The database logs through `Microsoft.Extensions.Logging`. Both servers route these events into
the host's logging, so they reach the console, structured logs and any other configured provider.
An embedded application supplies its own logger factory.

## Supplying a logger (embedded)

Set `LmdbStorageOptions.LoggerFactory` when you open the database:

```csharp
using Microsoft.Extensions.Logging;

using var loggerFactory = LoggerFactory.Create(b => b.AddConsole().SetMinimumLevel(LogLevel.Information));

var options = LmdbStorageOptions.Default with { LoggerFactory = loggerFactory };
using var db = new DocumentDatabase("./data", options);
```

- The database never disposes the factory; it stays yours.
- `DocumentDatabase.LoggerFactory` is never null.
- Logging can't throw into the database: a provider that throws doesn't affect it.
- Calling `AddProvider` on the database's factory does nothing, and never changes your own factory.
- The factory isn't part of the options' equality or `ToString`.

## Without a logger

When no factory is supplied, Information events are dropped, and Warning and above are written to
`System.Diagnostics.Trace`. That includes `BackupFailed` (1008), which is logged whether or not an
`OnBackupFailed` callback is set, and the cluster warnings 2012 and 2015–2017.

The process-exit errors (1002–1006) are always written to `Trace`, even when a factory is supplied,
because the host's logging may already be shut down when the process exits.

## Categories

| Category | Covers |
|---|---|
| `PhoenixmlDb.Storage` | opening and closing the database, process-exit disposal, backups |
| `PhoenixmlDb.Indexing` | the full-text indexing worker |
| `PhoenixmlDb.Cluster.Raft` | cluster replication (previously `PhoenixmlDb.Cluster.Raft.RaftNode`) |

## Event ids

Event ids, names and levels are **stable once released**; message text may change. Filter and
alert on the id or name, not the message.

### Storage (1000–1099)

| Id | Name | Level |
|---|---|---|
| 1000 | DatabaseOpened | Information |
| 1001 | DatabaseClosed | Information |
| 1002 | ProcessExitDisposalWaitAbandoned | Error |
| 1003 | ProcessExitDisposalThreadNotStarted | Error |
| 1004 | ProcessExitIndexShutdownFailed | Error |
| 1005 | ProcessExitIndexShutdownTimedOut | Error |
| 1006 | ProcessExitDisposalFailed | Error |
| 1007 | IndexConfigurationUnreadable | Warning |
| 1008 | BackupFailed | Error |
| 1009 | BackupCompleted | Information |

### Indexing (1100–1199)

| Id | Name | Level |
|---|---|---|
| 1100 | FullTextBatchFailed | Error |
| 1101 | FullTextDocumentDropped | Error |
| 1102 | CallerCallbackThrew | Error |

### Cluster (2000–2099)

| Id | Name | Level |
|---|---|---|
| 2000 | NodeStarting | Information |
| 2001 | NodeStarted | Information |
| 2002 | NodeStopped | Information |
| 2003 | BecameFollower | Information |
| 2004 | BecameCandidate | Information |
| 2005 | BecameLeader | Information |
| 2006 | LeadershipTransferStarted | Information |
| 2007 | TimeoutNowReceived | Information |
| 2008 | TimeoutNowElection | Information |
| 2009 | SteppedDown | Information |
| 2010 | PeerRequestFailed | Warning |
| 2011 | ReplicationFanOutFaulted | Warning |
| 2012 | ApplyMetadataNameSkipped | Warning |
| 2013 | SnapshotCreated | Information |
| 2014 | SnapshotRestored | Information |
| 2015 | DeleteMetadataMalformedEntrySkipped | Warning |
| 2016 | DeleteMetadataNamesEmpty | Warning |
| 2017 | DeleteMetadataDocumentNotFound | Warning |
| 2090 | StaleTimeoutNowIgnored | Debug |
| 2091 | RequestVoteReceived | Debug |
| 2092 | VoteGranted | Debug |
| 2093 | AppendEntriesReceived | Debug |
| 2094 | ElectionStarted | Debug |

`PeerRequestFailed` (2010) names the request (`RequestVote`, `AppendEntries` or `TimeoutNow`) and
the peer. A node that is shutting down doesn't report its own shutdown as a peer failure.

### Server (3000–3099)

The server startup events 3001–3007 are listed in the
[Server Configuration reference](deployment/server-configuration.md#startup-events).

## Metrics and traces

The engine publishes metrics (`System.Diagnostics.Metrics`) and traces (`ActivitySource`) with no
OpenTelemetry dependency. Each area has one meter and one activity source:

| Name | Constant |
|---|---|
| `PhoenixmlDb.Storage` | `TelemetryNames.Storage` |
| `PhoenixmlDb.Indexing` | `TelemetryNames.Indexing` |
| `PhoenixmlDb.Cluster` | `TelemetryNames.Cluster` |

(`PhoenixmlDb.Storage.Diagnostics.TelemetryNames`.) Nothing is recorded when nothing is listening,
and a failing listener can't affect the database. Any `MeterListener`/`ActivityListener`,
`dotnet-counters` or `dotnet-trace` can read them, for example
`dotnet-counters monitor --counters PhoenixmlDb.Storage -p <pid>`.

### Storage metrics

| Metric | Type | Notes |
|---|---|---|
| `db.client.operation.duration` | histogram, seconds | Buckets 0.001–10 s. Tags: `db.system.name` = `phoenixmldb`, `db.operation.name` (`query`, `put`, `get`, `delete`), `db.collection.name` (the container), and `error.type` on failure. One series per container. |
| `phoenixmldb.storage.transactions` | counter | Tag `phoenixmldb.transaction.mode` (`read` or `write`); includes the engine's own transactions. |
| `phoenixmldb.storage.map.usage` | bytes | Tag `db.namespace` (the data directory's last path segment). A high-water mark: it doesn't shrink after deletes. |
| `phoenixmldb.storage.map.limit` | bytes | Tag `db.namespace`. |

### Indexing metrics

| Metric | Notes |
|---|---|
| `phoenixmldb.indexing.fulltext.documents` | Tag `phoenixmldb.outcome` (`indexed` or `dropped`; dropped includes a container whose full-text index was removed). Counted after the batch commits. |
| `phoenixmldb.indexing.fulltext.batch.failures` | |

### Cluster metrics

All tagged `phoenixmldb.raft.node.id`; a node that has shut down drops out of the gauges.

| Metric | Notes |
|---|---|
| `phoenixmldb.raft.state` | 0 follower, 1 candidate, 2 leader (3 is reserved for a faulted node) |
| `phoenixmldb.raft.term`, `.commit_index`, `.applied_index` | |
| `phoenixmldb.raft.apply_lag` | never negative |
| `phoenixmldb.raft.elections` | |
| `phoenixmldb.raft.peer.request.failures` | Tag `rpc.method` (`RequestVote`, `AppendEntries`, `TimeoutNow`). A node's own shutdown isn't counted. |
| `phoenixmldb.raft.apply.metadata_skipped` | |
| `phoenixmldb.raft.snapshots` | Tag `phoenixmldb.snapshot.operation` (`create` or `restore`) |

### Traces

| Span | Notes |
|---|---|
| `{operation} {container}`, e.g. `query orders` | Kind Client, with the `db.*` tags above. The query text is never a tag. A query span doesn't include the query's internal work. |
| `phoenixmldb.transaction` | Write transactions only, tagged `phoenixmldb.transaction.outcome` (`commit` or `abort`). |
| `raft propose`, `raft snapshot create`, `raft snapshot restore`, `fulltext drain` | |

## OpenTelemetry (embedded)

The optional `PhoenixmlDb.OpenTelemetry` package (1.0.0-preview.1, not yet published on NuGet)
registers the engine's sources and meters with OpenTelemetry, and adds a storage health check:

```csharp
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddPhoenixmlDbInstrumentation(o => o.RecordQueryText = false)   // first
        .AddOtlpExporter())                                             // then exporters
    .WithMetrics(metrics => metrics
        .AddPhoenixmlDbInstrumentation()
        .AddOtlpExporter());

services.AddHealthChecks().AddPhoenixmlDbStorage(sp => db, mapUsageDegradedPercent: 90);
```

- **Call `AddPhoenixmlDbInstrumentation` before adding any exporter.** With a simple exporter added
  first, the query text is lost; with a batching exporter it's a race.
- OTLP export needs the separate `OpenTelemetry.Exporter.OpenTelemetryProtocol` package.
- `AddPhoenixmlDbStorage` reports `database_unavailable` and `storage_map_nearly_full`; the threshold
  must be 1–100, and an overload resolves it from the service provider.

### Query text

Query text is recorded as `db.query.text` **only if you opt in** with `RecordQueryText = true`. It's
off by default.

**It is exported only when every tracer provider in the process that called
`AddPhoenixmlDbInstrumentation` has opted in.** While any provider that didn't opt in is alive, no
provider gets the query text; once that provider is disposed, the opted-in ones get it again.

**A listener that subscribes to the PhoenixmlDb sources without `AddPhoenixmlDbInstrumentation`**
(a raw `AddSource`, a wildcard source, or a bare `ActivityListener`) **is not counted, and it
receives the query text whenever another provider has opted in.** If query text must not reach a
listener, don't opt in anywhere in that process.

## Health (embedded)

`DocumentDatabase.GetHealth()` returns a `StorageHealth` (`IsOpen`, `ReadOnly`, `MapUsedBytes`,
`MapSizeBytes`, `MapUsedFraction`), and `RaftNode.GetHealth()` returns a `RaftHealth` (`State`,
`NodeId`, `LeaderId`, `Term`, `CommitIndex`, `AppliedIndex`, `ApplyLag`). Neither throws; a node that
has shut down reports Follower with no leader. The servers' health endpoints are described in
[Server Mode](deployment/server-mode.md#health-endpoints).
