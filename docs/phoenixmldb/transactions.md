---
title: Transactions
description: ACID transactions with MVCC via LMDB
sort: 7
---

# Transactions

PhoenixmlDb stores everything in LMDB, which gives each write atomic, durable commits and lets readers run alongside a writer (MVCC). On top of that, `DocumentDatabase` offers an explicit write transaction that groups several writes into one atomic commit.

## What is atomic

| Operation | Atomic unit |
|-----------|-------------|
| `IContainer.PutDocumentAsync`, `DeleteDocumentAsync`, `SetMetadataAsync` | That one call, in its own LMDB write transaction |
| `IContainer.PutDocumentsAsync` | Each chunk of up to 1,000 documents; a failure part-way leaves earlier chunks committed |
| `IWriteTransaction` | Every operation buffered in it, applied in one LMDB write transaction at `CommitAsync` |

LMDB admits one writer at a time, so writes are serialized; readers are not blocked by them and never see a partly applied commit.

## Transaction Types

### Read Transactions

`BeginRead()` returns an `IReadTransaction`:

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Storage;

using var db = new DocumentDatabase("./data");
var products = await db.OpenOrCreateContainerAsync("products");

using (var txn = db.BeginRead())
{
    IDocument? doc = await txn.GetDocumentAsync(products.Id, "p1.xml");

    await foreach (var item in txn.QueryAsync(products.Id, "//product[price > 100]"))
    {
        Console.WriteLine(item);
    }

    await foreach (var info in txn.ListDocumentsAsync(products.Id))
    {
        Console.WriteLine(info.Name);
    }
}
```

**Characteristics:**
- **No snapshot across calls.** `IReadTransaction` holds no LMDB read transaction. Each call reads the latest committed state on its own, so two calls on the same read transaction can see different data if a write commits between them.
- Each individual call reads a consistent committed state.
- Holds no locks and no LMDB reader slot; disposing it only marks it inactive.
- The same reads are available directly on `IContainer` (`GetDocumentAsync`, `QueryAsync`, `ListDocumentsAsync`).

### Write Transactions

`BeginWriteAsync()` returns an `IWriteTransaction`. Writes are buffered and applied together at `CommitAsync`:

```csharp
var inventory = await db.OpenOrCreateContainerAsync("inventory");

await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(inventory.Id, "item-001.xml", newXml);
    await txn.DeleteDocumentAsync(inventory.Id, "old-item.xml");
    await txn.SetMetadataAsync(inventory.Id, "item-001.xml", "status", "restocked");

    // Apply every buffered operation atomically
    await txn.CommitAsync();
}
// Disposed without CommitAsync: the buffered operations are discarded
```

**Characteristics:**
- **One write transaction at a time per database.** `BeginWriteAsync` waits for the database's write lock; a second caller waits until the first commits, rolls back or is disposed. `BeginWriteAsync(TimeSpan timeout)` throws `TransactionTimeoutException` if the lock isn't free in time.
- **Nothing is written until `CommitAsync`.** Commit opens one LMDB write transaction, applies the buffered operations in order, and commits once. If any operation fails, the whole transaction is aborted and the database is unchanged.
- **A failed commit ends the transaction.** It releases the lock and can't be retried; start a new transaction.
- **Reads through a write transaction see committed state**, not the transaction's own buffered writes. `GetDocumentAsync` for a document put earlier in the same transaction returns what was committed before, if anything.
- The existence checks do account for buffered work: `SetMetadataAsync` accepts a document put earlier in the same transaction, and refuses one deleted earlier in it with `DocumentNotFoundException`. `PutDocumentAsync` with `DocumentOptions { Overwrite = false }` throws `DocumentExistsException` if the document will exist.
- `RollbackAsync()` discards the buffered operations explicitly.
- Not thread-safe: use one instance from one thread at a time.
- Direct `IContainer` writes do not wait for an open `IWriteTransaction`. They commit independently, and the transaction applies its operations against whatever is committed when it reaches `CommitAsync`. If a document it sets metadata on has been deleted by then, the commit throws `DocumentNotFoundException` and nothing it buffered is written.

## MVCC (Multi-Version Concurrency Control)

LMDB keeps the previous version of a page until no reader needs it, so a read that starts while a write is in progress sees the last committed state:

```
Time →

Writer (CommitAsync):
    Begin ──────────────────────── Commit
           │  Put(A')  Put(B')  │
           │                    │
           ▼                    ▼

Read 1:    Begin ─────────────────────────── End
           Sees: A, B (original versions)

Read 2:                           Begin ──── End
                                  Sees: A', B' (committed versions)
```

"Read" here is one read call, such as one `GetDocumentAsync`, not an `IReadTransaction` as a whole; see [Read Transactions](#read-transactions).

## Transaction Patterns

### Unit of Work Pattern

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Storage;

public class OrderService
{
    private readonly DocumentDatabase _db;
    private readonly IContainer _orders;
    private readonly IContainer _inventory;

    public OrderService(DocumentDatabase db, IContainer orders, IContainer inventory)
    {
        _db = db;
        _orders = orders;
        _inventory = inventory;
    }

    public async Task PlaceOrderAsync(Order order, IReadOnlyDictionary<string, string> updatedInventory)
    {
        await using var txn = await _db.BeginWriteAsync();

        // Create the order document
        await txn.PutDocumentAsync(_orders.Id, $"order-{order.Id}.xml", SerializeOrder(order));
        await txn.SetMetadataAsync(_orders.Id, $"order-{order.Id}.xml", "status", "placed");

        // Replace the affected inventory documents
        foreach (var (name, xml) in updatedInventory)
        {
            await txn.PutDocumentAsync(_inventory.Id, name, xml);
        }

        // All of it, or none of it
        await txn.CommitAsync();
    }
}
```

Reads inside the transaction see committed state only, and direct container writes aren't held off by it, so a check-then-write that must not race another writer is not something `IWriteTransaction` provides on its own.

### Batch Processing Pattern

For bulk loads that don't need all-or-nothing semantics, `PutDocumentsAsync` writes in chunks of up to 1,000 documents per LMDB commit:

```csharp
var imports = await db.OpenOrCreateContainerAsync("imports");

int written = await imports.PutDocumentsAsync(
    documents.Select(xml => new DocumentInput($"doc-{Guid.NewGuid()}.xml", xml)));
```

When a group of documents must commit together, buffer them in one write transaction instead:

```csharp
await using var txn = await db.BeginWriteAsync();
foreach (var xml in batch)
{
    await txn.PutDocumentAsync(imports.Id, $"doc-{Guid.NewGuid()}.xml", xml);
}
await txn.CommitAsync();
```

A write transaction holds every buffered document in memory until commit, and applies them all in one LMDB transaction.

## Transactions in a cluster

In [Cluster Mode](deployment/cluster-mode.md), every node holds the whole database. A write is
committed and applied through the Raft log on every node, so there are no cross-node
transactions to coordinate. Reads are served from the local node and aren't linearizable.

## Error Handling

```csharp
try
{
    await using var txn = await db.BeginWriteAsync(TimeSpan.FromSeconds(5));
    // Operations...
    await txn.CommitAsync();
}
catch (TransactionTimeoutException ex)
{
    // Another write transaction held the write lock for longer than the timeout
    Console.WriteLine($"Timeout: {ex.Message}");
}
catch (DocumentNotFoundException ex)
{
    // A metadata write named a document that won't exist (at buffer time or at commit)
    Console.WriteLine($"Missing: {ex.Message}");
}
catch (DocumentExistsException ex)
{
    // Put with Overwrite = false on a document that exists
    Console.WriteLine($"Exists: {ex.Message}");
}
```

There is no conflict detection between transactions and no automatic retry: writes are serialized by the write lock and by LMDB, so two write transactions never run their commits concurrently.

## Best Practices

1. **Keep write transactions short.** While one is open, every other `BeginWriteAsync`, `CreateContainerAsync`, `DeleteContainerAsync` and `RebuildIndexesAsync` waits for it.
2. **Don't wait on the write lock while holding it.** The write lock is not reentrant: calling `BeginWriteAsync`, `CreateContainerAsync`, `DeleteContainerAsync`, `RebuildIndexesAsync` or `EnableIndexing()` while holding a write transaction on the same database blocks forever.
3. **Batch writes** that belong together in one write transaction.
4. **Pass a timeout** to `BeginWriteAsync` where waiting indefinitely is unacceptable.
5. **Always dispose.** Use `await using`; disposing an uncommitted write transaction discards it and releases the write lock.
