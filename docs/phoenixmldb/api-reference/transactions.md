---
title: Transactions API
description: Transaction lifecycle, commit/rollback, error handling, and patterns
sort: 5
---

# Transaction API

Write transactions group several document and metadata changes into one atomic commit. Transactions are started from `DocumentDatabase` and implement `IReadTransaction` / `IWriteTransaction` (`PhoenixmlDb.Core`).

## Creating Transactions

### Read Transaction

```csharp
using (var read = db.BeginRead())
{
    IDocument? doc = await read.GetDocumentAsync(products.Id, "p1.xml");

    await foreach (var item in read.QueryAsync(products.Id, "count(collection())"))
        Console.WriteLine(item);

    await foreach (DocumentInfo info in read.ListDocumentsAsync(products.Id))
        Console.WriteLine(info.Name);
}
```

`BeginRead` is synchronous and holds no lock or resources. Each call on a read transaction reads the committed state at the moment it runs; the transaction does not pin one snapshot across calls, so a commit made between two calls is visible to the second.

### Write Transaction

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(products.Id, "p1.xml", xml1);
    await txn.PutDocumentAsync(products.Id, "p2.xml", xml2);
    await txn.DeleteDocumentAsync(products.Id, "p3.xml");

    await txn.CommitAsync();  // Commit all changes
}
// If CommitAsync() is not called, nothing is written
```

Each mutating call buffers an operation; nothing touches storage until `CommitAsync`. Commit applies every buffered operation inside one LMDB write transaction and commits once, so the transaction is atomic: concurrent readers never see part of it, and if any operation fails nothing is written.

### With a Timeout

```csharp
await using (var txn = await db.BeginWriteAsync(TimeSpan.FromSeconds(30)))
{
    // Operations...
    await txn.CommitAsync();
}
```

The timeout bounds only how long `BeginWriteAsync` waits for the database's write lock. If it is not acquired in time, `BeginWriteAsync` throws `TransactionTimeoutException`. There is no limit on how long a transaction may stay open once begun.

## Transaction Operations

### IWriteTransaction Interface

```csharp
public interface IWriteTransaction : IReadTransaction
{
    ValueTask PutDocumentAsync(ContainerId container, string name, string content,
        DocumentOptions? options = null, CancellationToken cancellationToken = default);
    ValueTask<bool> DeleteDocumentAsync(ContainerId container, string name,
        CancellationToken cancellationToken = default);

    ValueTask SetMetadataAsync(ContainerId container, string documentName, string name, string value,
        CancellationToken cancellationToken = default);
    ValueTask SetMetadataAsync<T>(ContainerId container, string documentName,
        MetadataProperty<T> descriptor, T value, CancellationToken cancellationToken = default);
    ValueTask SetMetadataAsync(ContainerId container, string documentName, XdmQName name, XdmValue value,
        CancellationToken cancellationToken = default);

    ValueTask CommitAsync(CancellationToken cancellationToken = default);
    ValueTask RollbackAsync(CancellationToken cancellationToken = default);
}
```

`IReadTransaction` contributes `TransactionId`, `IsActive`, `GetDocumentAsync`, `QueryAsync` and `ListDocumentsAsync`, all taking a `ContainerId`. `WriteTransactionMetadataExtensions` (`PhoenixmlDb.Storage`) adds multi-value metadata and metadata deletes to `IWriteTransaction`.

### Containers in a Transaction

Transactions address containers by `ContainerId`. Open the container first and pass its `Id`:

```csharp
var products = await db.OpenOrCreateContainerAsync("products");
var orders = await db.OpenOrCreateContainerAsync("orders");

await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(products.Id, "p1.xml", productXml);
    await txn.PutDocumentAsync(orders.Id, "o1.xml", orderXml);
    await txn.CommitAsync();
}
```

### Reading Inside a Write Transaction

`GetDocumentAsync`, `QueryAsync` and `ListDocumentsAsync` on a write transaction read committed data. They do not see the transaction's own buffered operations:

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(products.Id, "new.xml", "<product/>");

    var seen = await txn.GetDocumentAsync(products.Id, "new.xml");   // null until committed

    await txn.CommitAsync();
}
```

Metadata writes and deletes do account for earlier buffered operations: `SetMetadataAsync` on a document put earlier in the same transaction succeeds, and on one deleted earlier in it throws `DocumentNotFoundException`.

### Metadata in a Transaction

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(products.Id, "p9.xml", productXml);
    await txn.SetMetadataAsync(products.Id, "p9.xml", "status", "new");
    await txn.CommitAsync();
}
```

## Commit and Rollback

### Explicit Commit

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(container.Id, "doc.xml", content);

    await txn.CommitAsync();
}
```

After a commit, further operations — including a second `CommitAsync` — throw `InvalidOperationException`.

### Explicit Rollback

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(container.Id, "doc.xml", content);

    // Something went wrong: discard the buffered operations
    await txn.RollbackAsync();
}
```

`RollbackAsync` on a committed transaction throws `InvalidOperationException`.

### Automatic Rollback

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await txn.PutDocumentAsync(container.Id, "doc.xml", content);

    // No CommitAsync() called
}
// Buffered operations are discarded on dispose
```

### Failed Commit

If any buffered operation fails during `CommitAsync` — content that does not parse, a document that another writer deleted before a metadata write is applied — the exception propagates, nothing from the transaction is written, and the transaction ends. It cannot be retried; begin a new one.

In every case — commit, failed commit, rollback or dispose — the write lock is released when the transaction ends.

## Concurrency

- **One write transaction at a time.** `BeginWriteAsync` waits for the database's write lock. Creating or deleting a container, `RebuildIndexesAsync` and `EnableIndexing` take the same lock, so do not call them while holding a write transaction on the same flow: the lock is not reentrant and the call waits forever.
- **Direct container writes are separate.** `IContainer.PutDocumentAsync`, `DeleteDocumentAsync` and the metadata setters each commit their own LMDB transaction and do not wait for an open `IWriteTransaction`. A transaction's buffered operations are applied against whatever is committed when `CommitAsync` runs.
- **Readers never block.** Reads and queries run concurrently with each other and with a writer, and see only committed data.
- **Not thread-safe.** Use an `IWriteTransaction` instance from one thread at a time.

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
    // The write lock was not acquired within the timeout
    Console.WriteLine($"Timeout: {ex.Message}");
}
catch (DocumentNotFoundException ex)
{
    // A metadata write targeted a document that does not exist
    Console.WriteLine($"Not found: {ex.DocumentName}");
}
catch (InvalidOperationException ex)
{
    // e.g. an operation on a transaction that already committed or rolled back
    Console.WriteLine($"Invalid operation: {ex.Message}");
}
```

`TransactionTimeoutException` derives from `TransactionException` (`PhoenixmlDb.Core`). There are no conflict exceptions: with a single writer, transactions do not conflict with each other.

## Patterns

### Unit of Work

Read what you need, compute, then write the new versions in one transaction:

```csharp
public async Task TransferAsync(IContainer accounts, string from, string to, decimal amount)
{
    await using var txn = await db.BeginWriteAsync();

    decimal fromBalance = await ReadBalanceAsync(txn, accounts.Id, from);
    if (fromBalance < amount)
        throw new InvalidOperationException("Insufficient funds");

    decimal toBalance = await ReadBalanceAsync(txn, accounts.Id, to);

    await txn.PutDocumentAsync(accounts.Id, from,
        $"<account><balance>{fromBalance - amount}</balance></account>");
    await txn.PutDocumentAsync(accounts.Id, to,
        $"<account><balance>{toBalance + amount}</balance></account>");

    await txn.CommitAsync();
}

static async Task<decimal> ReadBalanceAsync(IReadTransaction txn, ContainerId container, string name)
{
    var doc = await txn.GetDocumentAsync(container, name)
        ?? throw new DocumentNotFoundException(container, name);
    var xml = XDocument.Parse(await doc.GetContentAsync());
    return decimal.Parse(xml.Root!.Element("balance")!.Value, CultureInfo.InvariantCulture);
}
```

Holding the write transaction while reading keeps other `BeginWriteAsync` callers out, but not direct container writes; route every writer of these documents through `BeginWriteAsync` if the read-then-write must not interleave with them.

### Retry on Timeout

```csharp
public async Task<T> ExecuteWithRetryAsync<T>(Func<IWriteTransaction, Task<T>> operation, int maxRetries = 3)
{
    for (int attempt = 1; ; attempt++)
    {
        try
        {
            await using var txn = await db.BeginWriteAsync(TimeSpan.FromSeconds(5));
            var result = await operation(txn);
            await txn.CommitAsync();
            return result;
        }
        catch (TransactionTimeoutException) when (attempt < maxRetries)
        {
            await Task.Delay(100 * attempt);
        }
    }
}
```

## Nested Operations

```csharp
await using (var txn = await db.BeginWriteAsync())
{
    await ProcessOrdersAsync(txn);
    await UpdateInventoryAsync(txn);

    await txn.CommitAsync();  // All or nothing
}

async Task ProcessOrdersAsync(IWriteTransaction txn)
{
    // Buffer writes against txn; they commit with the caller's CommitAsync
}
```

There are no nested transactions or savepoints; pass the one `IWriteTransaction` to helpers.

## Best Practices

1. **Keep transactions short** - Every other `BeginWriteAsync` waits while one is open
2. **Always dispose** - Use `await using`; disposal releases the write lock
3. **Use a timeout** - `BeginWriteAsync(TimeSpan)` turns an indefinite wait into `TransactionTimeoutException`
4. **Don't re-enter the write lock** - No container create/delete, `RebuildIndexesAsync` or `EnableIndexing` while holding a write transaction
5. **Batch related operations** - Single transaction for related changes

## Next Steps

| Concepts | Execution | Configuration |
|----------|-----------|---------------|
| **[Transactions](../transactions.md)**<br>Transaction concepts | **[Query API](queries.md)**<br>Query execution | **[Configuration](../configuration.md)**<br>Transaction settings |
