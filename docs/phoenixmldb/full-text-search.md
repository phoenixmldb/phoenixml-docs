---
title: Full-Text Search
description: The Lucene-backed full-text index — write path, query-time staleness guarantee, and operation
sort: 6
---

# Full-Text Search

PhoenixmlDb's full-text index is a Lucene index stored inside LMDB — nothing is ever written to the filesystem outside your database's `.mdb` files. Writing a document to a container with a full-text index does not tokenize anything inline: it appends one entry to a durable queue, and a background worker applies queued entries to the Lucene index in batches. A search always merges the Lucene index with a direct evaluation of whatever is still queued, so **the answer is exact whether or not the worker has caught up** — never stale, only possibly a little slower while a large queue drains.

This page covers the index itself: its write path, its query-time staleness guarantee, and how to run it. It does not cover XQuery's `contains text` clause, the `phx:search` native surface, or pluggable analyzers/thesauri — see [What this page does not cover](#what-this-page-does-not-cover) for exactly why, and when to expect them.

## Declaring a full-text index

Full-text indexing, like every index type, is declared on `ContainerOptions.Indexes` when a container is created — see [Indexing](indexing.md) for the other index types:

```csharp
var docs = await db.CreateContainerAsync("docs", opts =>
    opts.Indexes.AddFullTextIndex());
```

`AddFullTextIndex` takes an optional path pattern and optional `FullTextIndexOptions`:

```csharp
opts.Indexes.AddFullTextIndex("//product/description", new FullTextIndexOptions
{
    Language = "en",
    Stemming = true,
    CaseSensitive = false,
});
```

> **Warning:** No path pattern means every element. `AddFullTextIndex()` with no pattern indexes every element in every document, not the document as a whole. A document as small as `<doc><body>text</body></doc>` contributes **two** full-text entries — one for `<doc>`, one for `<body>` — because both elements match "no pattern." Account for this if you are counting entries or hits by hand.

Indexing is opt-in **per process**: declaring `AddFullTextIndex` on a container configures what should be indexed, but nothing actually maintains any index — full-text or otherwise — until the process calls:

```csharp
var manager = db.EnableIndexing();
```

Without it, `ContainerOptions.Indexes` is declarative-only and every query scans. `EnableIndexing` returns the `IndexManager` used for everything else on this page: draining the queue, searching, and inspecting what is pending.

## Writes enqueue; nothing is tokenized inline

```csharp
using var db = DocumentDatabase.Open(dbPath);
var manager = db.EnableIndexing();

var docs = await db.CreateContainerAsync("docs", opts => opts.Indexes.AddFullTextIndex());
await docs.PutDocumentAsync("a.xml", "<doc><body>the walrus and the carpenter</body></doc>");
await docs.PutDocumentAsync("b.xml", "<doc><body>a quiet afternoon</body></doc>");

manager.PendingFullTextDocuments(docs.Id).Count   // 2 — both writes queued, neither indexed yet
```

`PendingFullTextDocuments` is a diagnostic: the set of documents the Lucene index does not (yet, or any longer) correctly reflect. Right after two writes to an empty container with nobody draining the queue, both are pending. This is by design — analyzing and posting text into Lucene per document write would put full-text indexing back on the write path it was moved off of (see [Write-path cost](#write-path-cost-measured), below).

## Search is exact whether or not the worker has caught up

`IndexManager.SearchFullText` is the entry point for full-text search. It never returns a stale answer:

```csharp
var before = manager.SearchFullText(docs.Id, "walrus");
// before.Count == 1 — found even though nothing has been indexed into Lucene yet

var drained = await manager.DrainFullTextQueueAsync(db);
// drained == 2

var after = manager.SearchFullText(docs.Id, "walrus");
// after.Count == 1, after[0].Document == before[0].Document — the same answer
```

The mechanism: `PendingFullTextDocuments` names exactly the documents Lucene cannot be trusted for. A search reads that set, asks Lucene for hits and **discards any that belong to a pending document**, then evaluates every pending document directly against its current stored content using the same node selection the drain worker itself indexes. The two result sets are merged and ranked together. An updated or deleted document is reflected immediately for the same reason — its new state is either evaluated directly (update) or absent entirely (delete), regardless of what the not-yet-refreshed Lucene index still holds for it.

One consequence worth knowing: a multi-word query is matched as a contiguous phrase at the exact token-position gaps the query itself analyzes to — not "these words appear somewhere in some order" — on **both** the Lucene branch and the direct-evaluation branch, so the two branches never disagree about a phrase query just because the worker has or hasn't run. This is stricter than XQuery's own `contains text` phrase matching; see [What this page does not cover](#what-this-page-does-not-cover), below, and design 07 §7.6 if you plan to build `contains text` acceleration on top of this index.

## Draining the queue

Two ways to drain, matching two deployment shapes.

**Manual, one batch at a time** — call this yourself, e.g. after a bulk load, or on your own schedule:

```csharp
int indexed = await manager.DrainFullTextQueueAsync(db);   // up to 500 documents, one LMDB write tx
```

**A background loop**, for a long-lived embedded process that wants documents to become searchable on their own:

```csharp
await using var indexing = manager.StartFullTextIndexing(db);
// ... the process runs; newly written documents become searchable within
// FullTextIndexingOptions.IdleDelay (500ms by default) of being queued ...
// disposing stops the loop and waits for it to actually stop
```

**Nothing starts this loop for you.** An embedded caller opts in explicitly by calling `StartFullTextIndexing`; PhoenixmlDb never starts a background thread behind an embedder's back. The gRPC server is the one caller that opts in on your behalf — it hosts the same loop as a `BackgroundService` for the life of the process, so a document written through the server becomes full-text searchable without any operator action.

Disposing the handle `StartFullTextIndexing` returns cancels the loop and awaits it, so disposal never returns before the loop has genuinely stopped — but it cannot interrupt a batch already in flight, only the wait between batches, so shutdown can take up to roughly the configured `FullTextIndexingOptions.Budget` (2 seconds by default) plus however long the in-flight batch's Lucene commit takes.

## Rebuilding

A container's full-text index (like its other indexes) can become **stale**: written to while indexing was not enabled, or last touched by an engine version that predates it. A stale container's full-text index has no entries for whatever was written during that gap — and critically, those documents were **never queued either**, so nothing short of a rebuild can find them. Every other index-backed read path handles this by degrading to a scan; `SearchFullText` refuses instead — **it throws `InvalidOperationException` rather than return an answer that looks complete and is not**:

```csharp
db.ContainersWithStaleIndexes()          // ["docs"] — this container needs a rebuild

manager.SearchFullText(docs.Id, "walrus")   // throws InvalidOperationException — refuses to
                                             // silently miss documents written while indexing was off

var result = await db.RebuildIndexesAsync("docs");
// result.DocumentsIndexed, .EntriesRemoved, .EntriesWritten

manager.SearchFullText(docs.Id, "walrus").Count   // 1 — works again immediately, no exception,
                                                   // and no drain needed for this to be true

await manager.DrainFullTextQueueAsync(db);        // moves the work into the Lucene index itself
manager.SearchFullText(docs.Id, "walrus").Count   // 1 — same answer, now served from the index
```

A rebuild clears the container's previous Lucene entries and its full-text queue, then walks every document and re-enqueues it exactly as a live write would, and clears the stale flag as part of the same commit — so `SearchFullText` stops throwing the moment `RebuildIndexesAsync` returns. **You do not need a drain for that.** What the rebuild leaves behind is fresh queue entries, not a fresh Lucene index — but every one of those entries is now pending, and the `SearchFullText` guarantee above already covers a pending document: it is evaluated directly against its current stored content, so the answer is exact whether or not the worker has caught up. A drain afterward moves that work from direct evaluation into the index; it does not change what `SearchFullText` can answer, only how it answers it.

## Where the index lives

The Lucene index is stored entirely inside your LMDB environment, through a custom `Directory` that maps each Lucene file to an LMDB value keyed by container and file name. After writing documents to a full-text-indexed container and draining the queue, the on-disk footprint is unchanged from any other PhoenixmlDb database — `data.mdb` and `lock.mdb`, and nothing else. There is no `segments_N`, no `.cfs`, no separate Lucene directory to back up, replicate, or lose track of: it replicates and restores exactly as the rest of your database does.

## Write-path cost (measured)

Moving tokenization off the write path was the point of this design. Measured on the branch that introduced it (10 paired runs, one LMDB environment per configuration, queue drained to quiescence between timed regions): plain writes averaged 84.5 docs/s (median 76.6); writes to a full-text-indexed container averaged 78.8 docs/s (median 78.0). The paired-ratio 95% confidence interval is **[0.838, 1.083]** — the point estimate is parity with an unindexed container, but this sample cannot rule out a real write-path penalty of up to about 10% at 95% confidence. Compare the old inline indexer this replaced, which measured 100 → 45 docs/s (2.2×, 55% slower) on the same kind of workload — the difference in kind, even allowing for the new design's own uncertainty, is the headline result.

The benchmark harness is committed at `benchmarks/PhoenixmlDb.Benchmarks.FullTextWrite/` in the engine repository if you want to reproduce or extend this measurement.

## What this page does not cover

Several things a full-text search page would normally cover are deliberately **not here**, because they belong to later phases of the design that introduced this index (`docs/design/07-query-extensibility-and-full-text.md` in the engine repository):

- **XQuery's `contains text` does not use this index.** It evaluates by scanning — correct, just not accelerated. (Before `PhoenixmlDb.XQuery` 1.8.0 it did not run at all: it threw a `NullReferenceException` at query-compile time, [`phoenixmldb-xquery#15`](https://github.com/phoenixmldb/phoenixmldb-xquery/issues/15). The engine now pins 1.8.0. See [XQuery Full-Text](../language-reference/xquery/full-text.md).) Accelerating it is a later phase with a documented prerequisite: this index matches phrases more strictly than `contains text` itself does, so using it as a candidate source naively would silently drop matches the evaluator would otherwise confirm.

### Why the two disagree about a phrase

Both are exact. **They differ in whether stop-word removal closes the gap**, and that is the whole
of it:

| | matches on |
|---|---|
| `contains text` | adjacency over the **stop-word-compacted** token stream |
| this index | a slop-0 phrase query over **absolute** token positions, so a removed stop word leaves a gap |

Measured on `PhoenixmlDb.XQuery` 1.8.0, with `<p>the walrus and the carpenter</p>`:

```xquery
. contains text 'walrus carpenter'   (: true  — "and the" are removed, so the terms are adjacent :)
. contains text 'carpenter walrus'   (: false — order still matters :)
```

Order is respected and adjacency is required; it is the *analyzed* stream that adjacency is
measured over. A gap of ordinary words does **not** match: `<p>aa xx yy bb</p>` does not satisfy
`contains text 'aa bb'`, while `<p>aa and the bb</p>` does.

> **The consequence for you:** `IndexManager.SearchFullText` can **miss** a document that
> `contains text` matches, whenever the phrase spans removed stop words. The two are not
> interchangeable, and the index is the stricter of the two.

Which words are treated as stop words is engine configuration and is not documented here yet.
- **`phx:search` does not exist yet.** A native, non-portable search surface is planned as a later phase.
- **Analysis, resource providers and scoring are not pluggable yet.** Language, stemming and case-sensitivity are configurable per index (`FullTextIndexOptions`), but the analyzer itself, stop-word/thesaurus resources, and the scorer are fixed.
- **`FullTextIndexOptions.StopWords` is accepted but has no effect.** You can set it; nothing reads it — no error, no behavior change. This is a real, pre-existing gap (the mapping from the container-facing options to the engine's internal analysis options simply does not carry `StopWords` across), not something this page is glossing over.

## Next Steps

| Concepts | Reference |
|----------|-----------|
| **[Indexing](indexing.md)**<br>The other index types | **[Indexes API](api-reference/indexes.md)**<br>Full index configuration reference |
