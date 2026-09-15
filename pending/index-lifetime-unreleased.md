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

> **Still current as of 2026-09-15.** The namespace-consolidation design (`c05d3fb`) supersedes
> `ft-prefix-binding-unreleased.md` in this directory but does **not** touch anything here —
> index lifetime and namespace binding are independent.

## The anchor — settled

**PhoeniXML DB 1.0.0-preview.1.** `<Version>1.0.0-preview.1</Version>`, engine
`src/Directory.Build.props:26`. Unreleased: nothing has ever been published, and there are no
`v*` tags. The release path exists — pushing a `v*` tag publishes via NuGet Trusted Publishing,
and `release.sh --engine` packs Storage, Indexing, Json and Client. See the engine's
`RELEASING.md`.

**Until it ships, the honest pre-release form is "the engine at or after commit `ebc80c7`, built
from source."** Use `ebc80c7`, not `63b3b23` — the first ownership commit alone still had the
concurrent-disposal holes.

**When the preview ships is Lucas's decision.**

> **Correction to an earlier version of this file.** It claimed the database has no version to
> anchor to, and that this was a gap in rule 10. **Both were wrong.** The version exists; I had
> checked three package ids (`phoenixmldb`, `phoenixmldb.server`, `phoenixmldb.indexing`) and
> generalised from them, when the engine's ids are `PhoenixmlDb.Storage`, `.Indexing`, `.Json`,
> `.Client` and others. The conclusion *"nothing is published"* happens to be correct — db-engine
> confirmed it — but it was reached from one relevant data point presented as a survey. Rule 10
> has no gap.

## These are not changes — they are the behaviour of the first release

**No build has ever shipped, so there is no "before" for a reader to be on.** That settles how
all ten facts get written:

- **No "changed in" markers.** Nothing changed from a reader's point of view.
- **No migration notes.** Nobody is migrating from a version that never existed.
- The correct sentences are simply **published together with the release.**

In particular, item 2 below is **not a transition.** *"A second call would build independent
state"* never described a shipped build. It is a sentence about a pre-release engine that should
be replaced, not annotated.

## Behaviour that changed

1. **`DocumentDatabase` owns the `IndexManager`** that `EnableIndexing()` attaches. Disposing the
   database (`Dispose` or `DisposeAsync`) disposes the manager. **Callers no longer dispose it
   themselves.**

2. **`EnableIndexing()` is idempotent.** A second call returns the **same** `IndexManager`.
   → The current sentence in `indexing.md` — *"Call it once per `DocumentDatabase`; a second
   call would build independent state rather than reuse the first."* — describes a pre-release
   engine that no reader has. **Replace it; do not annotate it as a change.**

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
