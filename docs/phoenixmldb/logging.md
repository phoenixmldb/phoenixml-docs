---
title: Logging
description: Supplying a logger to the embedded database, what is logged without one, the log categories, and the stable event ids
sort: 12
---

# Logging

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
