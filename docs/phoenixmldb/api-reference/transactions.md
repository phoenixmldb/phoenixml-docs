---
title: Transactions API
description: Transaction lifecycle, commit/rollback, error handling, and patterns
sort: 5
---

# Transaction API

The Transaction API provides ACID-compliant transactions for consistent data operations.

## Creating Transactions

### Read-Only Transaction

```csharp
using (var txn = db.BeginTransaction(readOnly: true))
{
    // Snapshot isolation - sees consistent view
    var products = txn.Query("collection('products')//product");
    var orders = txn.Query("collection('orders')//order");

    // Process results
}
// Automatically completes on dispose
```

### Read-Write Transaction

```csharp
using (var txn = db.BeginTransaction())
{
    var container = txn.GetContainer("products");

    container.PutDocument("p1.xml", xml1);
    container.PutDocument("p2.xml", xml2);
    container.DeleteDocument("p3.xml");

    txn.Commit();  // Commit all changes
}
// If Commit() not called, changes are rolled back
```

### With Options

```csharp
var options = new TransactionOptions
{
    ReadOnly = false,
    Timeout = TimeSpan.FromSeconds(30),
    IsolationLevel = IsolationLevel.Snapshot
};

using (var txn = db.BeginTransaction(options))
{
    // Operations...
    txn.Commit();
}
```

## TransactionOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ReadOnly` | `bool` | `false` | Read-only transaction |
| `Timeout` | `TimeSpan` | 60s | Maximum duration |
| `IsolationLevel` | `IsolationLevel` | `Snapshot` | Isolation level |

## Transaction Operations

### ITransaction Interface

```csharp
interface ITransaction : IDisposable
{
    bool IsReadOnly { get; }
    TransactionState State { get; }

    IContainer GetContainer(string name);
    IQueryResult Query(string xquery);
    IQueryResult Query(string xquery, QueryParameters parameters);
    T QuerySingle<T>(string xquery);
    void Execute(string xqueryUpdate);

    void Commit();
    void Abort();
}
```

### Get Container

```csharp
using (var txn = db.BeginTransaction())
{
    var products = txn.GetContainer("products");
    var orders = txn.GetContainer("orders");

    // Operations on containers are part of transaction
}
```

### Query in Transaction

```csharp
using (var txn = db.BeginTransaction(readOnly: true))
{
    var result = txn.Query("""
        for $p in collection('products')//product
        where $p/price > $minPrice
        return $p
        """,
        new QueryParameters { ["minPrice"] = 100 });

    foreach (var product in result)
    {
        Console.WriteLine(product);
    }
}
```

### Update in Transaction

```csharp
using (var txn = db.BeginTransaction())
{
    txn.Execute("""
        for $p in collection('products')//product
        where $p/category = 'discontinued'
        return delete node $p
        """);

    txn.Commit();
}
```

## Commit and Rollback

### Explicit Commit

```csharp
using (var txn = db.BeginTransaction())
{
    // Make changes
    txn.GetContainer("data").PutDocument("doc.xml", content);

    // Explicitly commit
    txn.Commit();

    // Transaction state is now Committed
    Console.WriteLine(txn.State); // Committed
}
```

### Explicit Rollback

```csharp
using (var txn = db.BeginTransaction())
{
    txn.GetContainer("data").PutDocument("doc.xml", content);

    // Something went wrong, rollback
    txn.Abort();

    // Transaction state is now Aborted
    Console.WriteLine(txn.State); // Aborted
}
```

### Automatic Rollback

```csharp
using (var txn = db.BeginTransaction())
{
    txn.GetContainer("data").PutDocument("doc.xml", content);

    // No Commit() called
}
// Changes automatically rolled back on dispose
```

## Transaction States

```csharp
enum TransactionState
{
    Active,     // Transaction in progress
    Committed,  // Successfully committed
    Aborted,    // Rolled back
    Disposed    // Disposed (implies aborted if not committed)
}
```

## Error Handling

```csharp
try
{
    using (var txn = db.BeginTransaction())
    {
        // Operations...
        txn.Commit();
    }
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
    // Transaction was aborted
    Console.WriteLine($"Aborted: {ex.Message}");
}
catch (InvalidOperationException ex)
{
    // e.g., Write operation in read-only transaction
    Console.WriteLine($"Invalid operation: {ex.Message}");
}
```

## Patterns

### Unit of Work

```csharp
public void TransferFunds(string from, string to, decimal amount)
{
    using var txn = db.BeginTransaction();

    var accounts = txn.GetContainer("accounts");

    // Check balance
    var fromBalance = txn.QuerySingle<decimal>(
        $"doc('accounts/{from}.xml')/account/balance");

    if (fromBalance < amount)
        throw new InsufficientFundsException();

    // Update balances
    txn.Execute($"""
        replace value of node doc('accounts/{from}.xml')/account/balance
        with {fromBalance - amount}
        """);

    var toBalance = txn.QuerySingle<decimal>(
        $"doc('accounts/{to}.xml')/account/balance");

    txn.Execute($"""
        replace value of node doc('accounts/{to}.xml')/account/balance
        with {toBalance + amount}
        """);

    txn.Commit();
}
```

### Retry on Conflict

```csharp
public T ExecuteWithRetry<T>(Func<ITransaction, T> operation, int maxRetries = 3)
{
    for (int attempt = 1; attempt <= maxRetries; attempt++)
    {
        try
        {
            using var txn = db.BeginTransaction();
            var result = operation(txn);
            txn.Commit();
            return result;
        }
        catch (TransactionConflictException) when (attempt < maxRetries)
        {
            Thread.Sleep(100 * attempt);  // Exponential backoff
        }
    }
    throw new TransactionFailedException("Max retries exceeded");
}

// Usage
var result = ExecuteWithRetry(txn =>
{
    // Operations that might conflict
    return txn.QuerySingle<int>("count(//product)");
});
```

### Optimistic Locking

```csharp
public void UpdateWithVersion(string docName, string newContent)
{
    using var txn = db.BeginTransaction();

    // Get current version
    var currentVersion = txn.QuerySingle<int>(
        $"doc('data/{docName}')/document/@version");

    // Update with version check
    txn.Execute($"""
        let $doc := doc('data/{docName}')/document
        return
            if ($doc/@version = {currentVersion}) then (
                replace node $doc with {newContent},
                replace value of node $doc/@version with {currentVersion + 1}
            ) else
                error(xs:QName('local:conflict'), 'Version conflict')
        """);

    txn.Commit();
}
```

## Nested Operations

```csharp
using (var txn = db.BeginTransaction())
{
    ProcessOrders(txn);
    UpdateInventory(txn);
    SendNotifications(txn);

    txn.Commit();  // All or nothing
}

void ProcessOrders(ITransaction txn)
{
    var orders = txn.GetContainer("orders");
    // Process orders within transaction context
}
```

## Best Practices

1. **Keep transactions short** - Minimize time between begin and commit
2. **Use read-only when possible** - Better concurrency
3. **Don't hold transactions** - Across async/await or user input
4. **Handle conflicts** - Implement retry logic
5. **Always dispose** - Use `using` statements
6. **Batch related operations** - Single transaction for related changes

## Next Steps

| Concepts | Execution | Configuration |
|----------|-----------|---------------|
| **[Transactions](../transactions.md)**<br>Transaction concepts | **[Query API](queries.md)**<br>Query execution | **[Configuration](../configuration.md)**<br>Transaction settings |
