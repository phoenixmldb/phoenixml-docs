---
title: Troubleshooting
description: Common issues and solutions for storage, queries, transactions, and clusters
sort: 16
---

# Troubleshooting

Common issues and their solutions when working with PhoenixmlDb.

## Storage Issues

### "Map full" Error

**Symptom:** a write throws `PhoenixmlDbStorageException` with the message "Database map size exceeded", naming the current `MapSize` and the bytes used.

**Cause:** the data reached the configured `LmdbStorageOptions.MapSize`. The map is a fixed reservation set when the database is opened; the engine never grows it at runtime.

**Solution:** dispose the database and reopen it with a larger `MapSize`:

```csharp
using PhoenixmlDb.Storage;
using PhoenixmlDb.Storage.Lmdb;

using var db = new DocumentDatabase("./data", new LmdbStorageOptions
{
    MapSize = 200L * 1024 * 1024 * 1024  // 200 GiB
});
```

The default is 50 GiB in a 64-bit process and 1 GiB in a 32-bit one. `MapSize` reserves address space, not disk; the data file grows only as data is written. `db.GetStorageUsage()` reports `UsedBytes`, `MapSize` and `PercentUsed`, and the `phoenixmldb.storage.map.usage` and `phoenixmldb.storage.map.limit` metrics track the same figures (see [Logging and Telemetry](logging.md#storage-metrics)).

### "MapSize is ... bytes" on open

**Symptom:** `LmdbMapSizeTooSmallException` when opening an existing database.

**Cause:** the configured `MapSize` is at or below the size the existing data already uses, so every write would fail.

**Solution:** open with a `MapSize` above the `UsedBytes` the exception reports.

### Database already open

**Symptom:** `LmdbEnvironmentAlreadyOpenException` from the `DocumentDatabase` constructor.

**Cause:** something in the same process already has that directory open, possibly under a different-looking path (relative vs absolute, a trailing separator, a symlink).

**Solution:** share one `DocumentDatabase` per directory per process, or dispose the existing one before opening another.

### "Max readers reached"

**Symptom:** LMDB's `MDB_READERS_FULL`.

**Cause:** more concurrent LMDB read transactions than `LmdbStorageOptions.MaxReaders` (default 126).

**Solution:** raise `MaxReaders` when opening the database:

```csharp
using var db = new DocumentDatabase("./data", new LmdbStorageOptions
{
    MaxReaders = 256
});
```

`IReadTransaction` itself holds no LMDB reader; reader slots are used by individual operations while they run.

### Database Corruption

**Symptom:** errors on startup, data inconsistency

**Cause:** disk failure, or a database used in ways LMDB does not support (for example two environments over one directory in one process, which `DocumentDatabase` now refuses)

**Solution:** there is no built-in integrity checker. Restore from a backup taken with `BackupAsync`; the database must not be open while it is restored:

```csharp
// Taking backups (consistent while the database is in use)
await db.BackupAsync("/backups/data-2026-10-04.mdb");

// Restoring, with no DocumentDatabase open on ./data
await DocumentDatabase.RestoreAsync("./data", "/backups/data-2026-10-04.mdb", overwrite: true);
```

`LmdbStorageOptions.RestoreFromPath` and `RestoreFromDirectory` restore automatically on open when the database is missing.

### Read-only mode fails to open

**Symptom:** `LightningException: Permission denied` from the `DocumentDatabase` constructor when `LmdbStorageOptions.ReadOnly = true`.

**Cause:** a `DocumentDatabase` cannot currently be opened read-only at all: opening it writes the well-known namespace table, which needs a write transaction.

**Solution:** open the database read-write. There is no supported read-only mode today.

### "MDB_BAD_VALSIZE" on long namespace URIs

**Symptom:** `LightningException: MDB_BAD_VALSIZE: Unsupported size of
key/DB name/data` when interning a namespace URI longer than ~500 bytes.

**Cause:** Older versions used the URI bytes directly as the LMDB key,
which is capped at 511 bytes. Resolved in current builds — the reverse
namespace map now keys on a SHA-256 hash of the URI.

**Solution:** Upgrade to the current PhoenixmlDb release. Existing
databases are migrated automatically on first open with the new build.

## Query Issues

### Slow Queries

**Symptom:** Queries take longer than expected

**Diagnosis:** most XQuery against a container scans every document in it. Indexes speed up only specific readers; check [What uses each index today](indexing.md#what-uses-each-index-today). Confirm indexing is enabled (`db.EnableIndexing()`) and the container isn't stale:

```csharp
IReadOnlyList<string> stale = db.ContainersWithStaleIndexes();
```

**Solutions:**
1. Rebuild stale containers with `RebuildIndexesAsync`
2. For attribute lookups, declare a value index on the attribute path and query in the shape it supports (`/a/b[@attr = $v]`)
3. Keep unrelated documents in separate containers
4. Use `QueryMetadataAsync` with a metadata index for metadata filters instead of `phx:metadata()` in a scan

See [Performance Tuning](performance-tuning.md).

### Query Parse Errors

**Symptom:** `PhoenixmlDb.XQuery.Functions.XQueryException` with `ErrorCode` `XPST0003`, thrown before any document is read

**Common causes:**
- Unterminated string literals or comments
- Invalid XPath syntax
- Mismatched brackets

**A related mistake that is not a parse error:**
```xquery
(: Compares name with a child element called test — usually not what was meant :)
for $x in //item where name = test return $x

(: Compares with the string 'test' :)
for $x in //item where name = 'test' return $x
```

### Type Errors

**Symptom:** a dynamic error such as `XPTY0004` propagating while the results are enumerated

**Solution:**
```xquery
(: Wrong - comparing xs:decimal to xs:string raises XPTY0004 :)
//product[xs:decimal(price) > '100']

(: Correct - compare numbers :)
//product[xs:decimal(price) > 100]
```

On untyped data, `price > '100'` raises nothing: it compares as strings, so `'9' > '100'` is true. Cast or compare against a number when you mean a numeric comparison.

## Transaction Issues

### Write Blocked

**Symptom:** `BeginWriteAsync`, `CreateContainerAsync`, `DeleteContainerAsync` or `RebuildIndexesAsync` never returns

**Cause:** another write transaction on the same database is still open, or the calling code itself holds one. The write lock allows one write transaction at a time and is not reentrant, so a call that needs it while the same caller holds a write transaction waits forever. `EnableIndexing()` can need it too.

**Solution:**
- Commit, roll back or dispose every write transaction promptly (`await using`)
- Don't call `CreateContainerAsync`, `DeleteContainerAsync`, `RebuildIndexesAsync`, `EnableIndexing()` or a second `BeginWriteAsync` while holding a write transaction
- Pass a timeout so a stuck writer surfaces as an exception:

```csharp
await using var txn = await db.BeginWriteAsync(TimeSpan.FromSeconds(10));
```

### Transaction Timeout

**Symptom:** `TransactionTimeoutException` ("Timed out waiting for write lock")

**Cause:** `BeginWriteAsync(timeout)` could not get the write lock in time because another write transaction held it.

**Solution:** find and shorten the long-running write transaction, or pass a longer timeout. Once a transaction has begun there is no timeout on its duration.

### Commit Fails With DocumentNotFoundException

**Symptom:** `CommitAsync` throws `DocumentNotFoundException`, and nothing the transaction buffered was written

**Cause:** a buffered metadata write names a document that no longer exists at commit; another writer deleted it after the call was buffered. Direct container writes don't wait for an open write transaction.

**Solution:** start a new transaction. A failed commit ends the transaction and can't be retried.

### Reads Don't See Buffered Writes

**Symptom:** inside a write transaction, `GetDocumentAsync` returns the old document

**Cause:** writes are buffered until `CommitAsync`; reads through the transaction see committed state. See [Transactions](transactions.md#write-transactions).

## Connection Issues

The .NET client (`PhoenixmlClient`) talks gRPC, so connection and authentication failures surface as `Grpc.Core.RpcException`; check its `StatusCode`.

### Cannot Connect to Server

**Symptom:** `RpcException` with `StatusCode.Unavailable`

**Checklist:**
1. The server is running: its `/health` endpoint answers (see [Server Mode](deployment/server-mode.md#health-endpoints))
2. The address includes the scheme and the right port (`http://` for the plaintext port, which is bound on loopback; `https://` for the TLS port)
3. A firewall allows the connection
4. The TLS certificate is valid for the address

### Authentication Failed

**Symptom:** `RpcException` with `StatusCode.Unauthenticated` (gRPC) or `401` (REST)

**Checklist:**
1. The gRPC server expects `authorization: Bearer <key>` metadata; the REST server expects the key in the `X-Api-Key` header
2. The key exists in the server's configuration, is enabled and has not expired
3. `StatusCode.PermissionDenied` instead means the key lacks the scope for the call, or, in a cluster, that the call reached the Raft port

See [Server Mode: Client connection](deployment/server-mode.md#client-connection) for supplying the key.

### TLS Errors

**Symptom:** SSL/TLS handshake failed

**Solution:** TLS is configured through the gRPC channel credentials in `PhoenixmlClientOptions.Credentials`; the server's certificate comes from Kestrel's certificate settings. See [Server Mode: TLS](deployment/server-mode.md#tls).

## Cluster Issues

See [Cluster Mode](deployment/cluster-mode.md) for how replication works and what it does not do yet.

### No Leader Elected / Node Won't Join

**Symptom:** nodes stay followers or candidates, or one node never takes part

**Checklist:**
1. `Raft:ClusterSecret` is identical on every node; a wrong secret gets `Unauthenticated`
2. Every node has a Raft certificate (`CertificatePath`) and the peer addresses use `https://`
3. The Raft port (`Raft:ListenPort`) is reachable between nodes
4. The node is in every other node's `Peers` list. Membership is fixed at startup: a node can't be added to a running cluster
5. The cluster has a majority up: three nodes tolerate one failure

### Writes Refused on a Follower

**Symptom:** a write sent to a follower is refused with the leader's id

**Cause:** writes are not forwarded. Send writes to the leader.

### Replication Lag

**Symptom:** a follower returns stale data

**Diagnosis:** the `phoenixmldb.raft.apply_lag` metric, or `RaftNode.GetHealth()` (`CommitIndex`, `AppliedIndex`, `ApplyLag`). Reads are served from the local node and are not linearizable, so some staleness is expected.

**Solutions:**
1. Check network connectivity and bandwidth between nodes
2. Reduce write load
3. A follower far enough behind to need a snapshot install needs operator help

## Performance Issues

### High Memory Usage

**Causes and solutions:**
1. **Large write transactions** — every buffered operation is held in memory until `CommitAsync`; use smaller batches
2. **Fetching whole large documents** — `GetContentAsync` and `GetContentStreamAsync` both serialize the whole document; query for the parts you need
3. **Cross-document queries** — `order by`, `group by` and collection-wide aggregates evaluate over every document in the container at once

### High CPU Usage

**Causes and solutions:**
1. **Full scans** — see [Slow Queries](#slow-queries)
2. **Index maintenance** — every declared index is maintained on every write; a name, path or structural index isn't read by XQuery

### High Disk I/O

**Causes and solutions:**
1. **One commit per document** — batch with `PutDocumentsAsync` or one write transaction
2. **Frequent syncs** — `NoSync` removes them, at the cost of durability; use it only for data you can regenerate

## Logging and Diagnostics

### Enable Debug Logging

```csharp
using Microsoft.Extensions.Logging;
using PhoenixmlDb.Storage;
using PhoenixmlDb.Storage.Lmdb;

using var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
});

using var db = new DocumentDatabase("./data", new LmdbStorageOptions
{
    LoggerFactory = loggerFactory
});
```

Without a logger factory, warnings and errors go to `System.Diagnostics.Trace`. Categories and event ids are listed in [Logging and Telemetry](logging.md).

### Query Metrics

Queries are timed by the `db.client.operation.duration` histogram (`db.operation.name` = `query`, per container) and traced as `query {container}` spans. See [Logging and Telemetry](logging.md#metrics-and-traces).

### Database Statistics

```csharp
DatabaseStatistics stats = db.Statistics;
Console.WriteLine($"Containers: {stats.ContainerCount}");
Console.WriteLine($"Documents: {stats.TotalDocumentCount}");

StorageUsage usage = db.GetStorageUsage();
Console.WriteLine($"Map: {usage.UsedBytes / 1024 / 1024} MB used of {usage.MapSize / 1024 / 1024} MB");

var health = db.GetHealth(); // StorageHealth; never throws
```

## Getting Help

If you can't resolve an issue:

1. Check the [documentation](index.md)
2. Search [GitHub Issues](https://github.com/endpointsystems/phoenixml/issues)
3. Create a new issue with:
   - PhoenixmlDb version
   - .NET version
   - Operating system
   - Minimal reproduction code
   - Full error message and stack trace
