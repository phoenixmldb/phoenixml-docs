---
title: Transactions
description: ACID transactions with MVCC via LMDB
sort: 6
---

# Transactions

PhoenixmlDb provides full ACID transaction support with MVCC (Multi-Version Concurrency Control) for high-performance concurrent access.

## ACID Properties

| Property | Description |
|----------|-------------|
| **Atomicity** | All operations in a transaction succeed or all fail |
| **Consistency** | Database remains in a valid state after each transaction |
| **Isolation** | Concurrent transactions don't interfere with each other |
| **Durability** | Committed transactions survive system failures |

## Transaction Types

### Read-Only Transactions

Read-only transactions provide a consistent snapshot view of the database:

```csharp
using (var txn = db.BeginTransaction(readOnly: true))
{
    // All reads see a consistent snapshot
    var products = txn.Query("collection('products')//product");
    var orders = txn.Query("collection('orders')//order");

    // Snapshot remains stable even if other transactions commit
    foreach (var product in products)
    {
        // Process with guaranteed consistency
    }
}
// No commit needed - read-only transaction auto-completes
```

**Characteristics:**
- Multiple concurrent read transactions allowed
- No locks on data
- Sees data as of transaction start time
- Cannot modify data

### Read-Write Transactions

Read-write transactions can modify data:

```csharp
using (var txn = db.BeginTransaction())
{
    var container = txn.GetContainer("inventory");

    // Read current state
    var item = txn.QuerySingle<string>(
        "doc('inventory/item-001.xml')/item/quantity/text()");

    // Modify
    container.PutDocument("item-001.xml", newXml);
    container.DeleteDocument("old-item.xml");

    // Commit all changes atomically
    txn.Commit();
}
// If Commit() not called, transaction is rolled back
```

**Characteristics:**
- Only one write transaction at a time
- Readers don't block writers, writers don't block readers
- Changes are isolated until commit
- Automatic rollback if not committed

## MVCC (Multi-Version Concurrency Control)

PhoenixmlDb uses MVCC to allow concurrent access without locking:

```
Time →

Writer Transaction:
    Begin ──────────────────────── Commit
           │  Put(A')  Put(B')  │
           │                    │
           ▼                    ▼

Reader 1:  Begin ─────────────────────────── End
           Sees: A, B (original versions)

Reader 2:                         Begin ──── End
                                  Sees: A', B' (committed versions)
```

### Snapshot Isolation

Each transaction sees a consistent snapshot:

```csharp
// Transaction 1 starts
using var txn1 = db.BeginTransaction(readOnly: true);

// Transaction 2 modifies data
using (var txn2 = db.BeginTransaction())
{
    txn2.GetContainer("data").PutDocument("doc.xml", "<new>data</new>");
    txn2.Commit();
}

// Transaction 1 still sees old data (snapshot isolation)
var doc = txn1.Query("doc('data/doc.xml')").First();
// Returns original content, not "<new>data</new>"
```

## Transaction Patterns

### Unit of Work Pattern

```csharp
public class OrderService
{
    private readonly XmlDatabase _db;

    public void PlaceOrder(Order order)
    {
        using var txn = _db.BeginTransaction();

        try
        {
            // 1. Validate inventory
            foreach (var item in order.Items)
            {
                var available = txn.QuerySingle<int>($"""
                    doc('inventory/{item.ProductId}.xml')
                    /product/quantity/number()
                    """);

                if (available < item.Quantity)
                    throw new InsufficientInventoryException(item.ProductId);
            }

            // 2. Create order document
            txn.GetContainer("orders").PutDocument(
                $"order-{order.Id}.xml",
                SerializeOrder(order));

            // 3. Update inventory
            foreach (var item in order.Items)
            {
                txn.Execute($"""
                    let $product := doc('inventory/{item.ProductId}.xml')/product
                    let $newQty := $product/quantity - {item.Quantity}
                    return replace value of node $product/quantity with $newQty
                    """);
            }

            // 4. Commit all changes
            txn.Commit();
        }
        catch
        {
            // Automatic rollback on exception
            throw;
        }
    }
}
```

### Retry Pattern

```csharp
public async Task<T> ExecuteWithRetry<T>(
    Func<ITransaction, T> operation,
    int maxRetries = 3)
{
    for (int attempt = 1; attempt <= maxRetries; attempt++)
    {
        try
        {
            using var txn = _db.BeginTransaction();
            var result = operation(txn);
            txn.Commit();
            return result;
        }
        catch (TransactionConflictException) when (attempt < maxRetries)
        {
            // Wait before retry
            await Task.Delay(TimeSpan.FromMilliseconds(100 * attempt));
        }
    }

    throw new TransactionFailedException("Max retries exceeded");
}

// Usage
var result = await ExecuteWithRetry(txn =>
{
    // Operations that might conflict
    return txn.Query("...");
});
```

### Batch Processing Pattern

```csharp
public void ImportDocuments(IEnumerable<string> documents)
{
    const int batchSize = 100;
    var batch = new List<string>();

    foreach (var doc in documents)
    {
        batch.Add(doc);

        if (batch.Count >= batchSize)
        {
            ProcessBatch(batch);
            batch.Clear();
        }
    }

    if (batch.Any())
    {
        ProcessBatch(batch);
    }
}

private void ProcessBatch(List<string> documents)
{
    using var txn = _db.BeginTransaction();
    var container = txn.GetContainer("imports");

    foreach (var doc in documents)
    {
        container.PutDocument($"doc-{Guid.NewGuid()}.xml", doc);
    }

    txn.Commit();
}
```

## Distributed Transactions

For cluster deployments, PhoenixmlDb supports distributed transactions with two-phase commit (2PC):

```csharp
// Distributed transaction across shards
using var txn = cluster.BeginDistributedTransaction();

// Operations may span multiple nodes
txn.Execute("insert node <item/> into doc('shard1/data.xml')/root");
txn.Execute("insert node <item/> into doc('shard2/data.xml')/root");

// Two-phase commit ensures atomicity across nodes
await txn.CommitAsync();
```

### 2PC Protocol

```
Phase 1 (Prepare):
    Coordinator → Participant 1: PREPARE
    Coordinator → Participant 2: PREPARE
    Participant 1 → Coordinator: VOTE_COMMIT
    Participant 2 → Coordinator: VOTE_COMMIT

Phase 2 (Commit):
    Coordinator → Participant 1: COMMIT
    Coordinator → Participant 2: COMMIT
    Participant 1 → Coordinator: ACK
    Participant 2 → Coordinator: ACK
```

## Transaction Options

```csharp
var options = new TransactionOptions
{
    Timeout = TimeSpan.FromSeconds(30),
    IsolationLevel = IsolationLevel.Snapshot,
    MaxRetries = 3
};

using var txn = db.BeginTransaction(options);
```

| Option | Description | Default |
|--------|-------------|---------|
| `Timeout` | Maximum transaction duration | 60 seconds |
| `IsolationLevel` | Snapshot or Serializable | Snapshot |
| `MaxRetries` | Auto-retry on conflict | 0 |

## Error Handling

```csharp
try
{
    using var txn = db.BeginTransaction();
    // Operations...
    txn.Commit();
}
catch (TransactionConflictException ex)
{
    // Another transaction modified the same data
    Console.WriteLine($"Conflict: {ex.Message}");
}
catch (TransactionTimeoutException ex)
{
    // Transaction exceeded timeout
    Console.WriteLine($"Timeout: {ex.Message}");
}
catch (TransactionAbortedException ex)
{
    // Transaction was aborted (e.g., by deadlock detection)
    Console.WriteLine($"Aborted: {ex.Message}");
}
```

## Best Practices

1. **Keep transactions short** — Long transactions block writers and consume resources
2. **Use read-only when possible** — Read-only transactions are cheaper and don't block
3. **Batch writes** — Group multiple writes in a single transaction
4. **Handle conflicts** — Implement retry logic for conflict-prone operations
5. **Don't hold transactions across async boundaries** — Complete transactions synchronously
6. **Always dispose** — Use `using` statements to ensure cleanup
