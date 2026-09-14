# Pending: index lifetime and ownership (UNRELEASED)

**Not published.** This file lives outside `docs/`, which is the only tree `build.sh` reads
(`-s "$DOCS_DIR"`), so nothing here reaches phoenixml.dev.

**Status: the engine changes are committed and UNRELEASED.** Engine commits `63b3b23`,
`0651374`, `ebc80c7` on engine `main`. **No engine build carries them yet.**

Per `CONTRIBUTING-STE.md` rule 10, these must not be written into `docs/` as current shipped
behaviour. They go in when there is a version to name. Recorded here because they were reported
once, in detail, by the session that made them, and would otherwise exist only in a chat
transcript.

Source: db-engine, 2026-09-14.

## Open question before any of this is published

**The database is not distributed as a NuGet package** — `phoenixmldb`, `phoenixmldb.server`
and `phoenixmldb.indexing` all return *not published*. So rule 10's "name the version" has no
package version to name here.

Whoever publishes these must first establish **what the anchor is**: an engine release tag, a
container image tag, a date, or a commit. Writing "in a future release" would be the exact
failure rule 10 exists to prevent.

## Behaviour that changed

1. **`DocumentDatabase` owns the `IndexManager`** that `EnableIndexing()` attaches. Disposing the
   database (`Dispose` or `DisposeAsync`) disposes the manager. **Callers no longer dispose it
   themselves.**

2. **`EnableIndexing()` is idempotent.** A second call returns the **same** `IndexManager`.
   → This makes the current sentence in `indexing.md` wrong once released: *"Call it once per
   `DocumentDatabase`; a second call would build independent state rather than reuse the
   first."* That sentence is **correct today** and becomes wrong on the release.

3. **`EnableIndexing()` throws:**
   - `InvalidOperationException` — a different, non-`IndexManager` `IIndexMaintenance` is already
     attached
   - `ObjectDisposedException` — the database is disposed

4. **The `IndexMaintenance` setter throws** when it would replace an already-attached instance
   with a different one, or with null. **There is no supported way to detach indexing.** That is
   deliberate: writes made while detached would silently skip index maintenance.

5. **Disposing the database stops every background drain loop** started with
   `IndexManager.StartFullTextIndexing`, even if the caller never disposed the handle. The handle
   stays valid; disposing it afterwards is a harmless no-op. `await using` on the handle is still
   correct, just **no longer required for correctness**.

6. **`StartFullTextIndexing(db)` throws** if `db` is not the database this manager is attached to.

7. **Synchronous `Dispose()` waits for an in-flight drain batch**, bounded by that loop's
   `FullTextIndexingOptions.Budget` (2 s default). `DisposeAsync()` awaits the same thing.

8. **Calling synchronous `db.Dispose()` from inside a drain callback** such as `OnDrainFailed`
   throws `InvalidOperationException` **instead of deadlocking**. The refusal is **best-effort**:
   handing disposal to other work and blocking on it
   (`DisposeAsync().AsTask().GetAwaiter().GetResult()`) can still deadlock.
   **Guidance to document:** from a callback, use fire-and-forget `DisposeAsync()`, or do not
   dispose there at all.

9. **The first drain batch runs on the thread pool**, not synchronously inside
   `StartFullTextIndexing`. **Nothing should imply the queue has drained** once that method
   returns.

10. **At process exit, disposal waits at most the longest loop Budget plus 5 s** (~7 s at
    defaults), then leaves the LMDB environment for the OS to reclaim. Safe: an aborted batch
    leaves committed data consistent and the queue intact.

## Unchanged — keep stating

- Indexing is **opt-in per process** via `EnableIndexing()`.
- Embedded callers **start the drain loop explicitly**; the gRPC server runs it by default.
- **Search stays exact while the worker lags.**

## Pages to revisit when this ships

| page | what |
|---|---|
| `docs/phoenixmldb/indexing.md` | the `EnableIndexing()` paragraph (item 2) |
| `docs/phoenixmldb/full-text-search.md` | drain-loop passages, and *"Nothing starts this loop for you"* around `:96` |
| `docs/phoenixmldb/api-reference/indexes.md` | lifetime descriptions |
