---
title: Troubleshooting
description: Common issues and solutions for storage, queries, transactions, and clusters
sort: 15
---

# Troubleshooting

Common issues and their solutions when working with PhoenixmlDb.

## Storage Issues

### "Map full" Error

**Symptom:** `MDB_MAP_FULL: Environment mapsize limit reached`

**Cause:** Database size exceeded configured MapSize.

**Solution:**
```csharp
// Increase MapSize
db.Resize(currentMapSize * 2);

// Or set larger initial size
var options = new DatabaseOptions
{
    MapSize = 20L * 1024 * 1024 * 1024  // 20 GB
};
```

### "Max readers reached"

**Symptom:** `MDB_READERS_FULL: Environment maxreaders limit reached`

**Cause:** Too many concurrent read transactions.

**Solution:**
```csharp
// Increase max readers
var options = new DatabaseOptions
{
    MaxReaders = 256
};

// Or ensure transactions are being disposed
using (var txn = db.BeginTransaction(readOnly: true))
{
    // Always dispose transactions
}
```

### Database Corruption

**Symptom:** Errors on startup, data inconsistency

**Cause:** Unclean shutdown, disk failure

**Solution:**
```bash
# Check database integrity
phoenixmldb-admin check ./data

# If corruption detected, restore from backup
phoenixmldb-admin restore ./data --from backup.tar
```

## Query Issues

### Slow Queries

**Symptom:** Queries take longer than expected

**Diagnosis:**
```csharp
var plan = db.Explain(query);
Console.WriteLine(plan);
// Check if indexes are being used
```

**Solutions:**
1. Add appropriate indexes
2. Rewrite query to filter early
3. Limit result size
4. Use parameters instead of string concatenation

### Query Parse Errors

**Symptom:** `XQueryParseException`

**Common causes:**
- Missing quotes around strings
- Invalid XPath syntax
- Mismatched brackets
- Reserved word used as variable

**Example fixes:**
```xquery
(: Wrong :)
for $x in //item where name = test return $x

(: Correct - quote the string :)
for $x in //item where name = 'test' return $x

(: Wrong :)
for $for in //item return $for

(: Correct - don't use reserved words :)
for $item in //item return $item
```

### Type Errors

**Symptom:** `XPTY0004: Type error`

**Solution:**
```xquery
(: Wrong - comparing string to number :)
//product[price > '100']

(: Correct - use number :)
//product[xs:decimal(price) > 100]
```

## Transaction Issues

### Deadlock

**Symptom:** Transaction hangs or times out

**Cause:** Multiple transactions waiting on each other

**Solution:**
```csharp
// Use retry pattern
public T ExecuteWithRetry<T>(Func<ITransaction, T> operation)
{
    for (int i = 0; i < 3; i++)
    {
        try
        {
            using var txn = db.BeginTransaction();
            var result = operation(txn);
            txn.Commit();
            return result;
        }
        catch (TransactionConflictException)
        {
            Thread.Sleep(100 * (i + 1));
        }
    }
    throw new Exception("Max retries exceeded");
}
```

### Transaction Timeout

**Symptom:** `TransactionTimeoutException`

**Solution:**
```csharp
// Increase timeout
var options = new TransactionOptions
{
    Timeout = TimeSpan.FromMinutes(5)
};

// Or break into smaller transactions
```

### Write Blocked

**Symptom:** Write operations hang

**Cause:** Long-running read transaction blocking writes

**Solution:**
- Ensure read transactions are disposed promptly
- Use shorter transactions
- Don't hold transactions across async operations

## Connection Issues

### Cannot Connect to Server

**Symptom:** `ConnectionRefusedException`

**Checklist:**
1. Server is running: `phoenixmldb-server status`
2. Port is correct
3. Firewall allows connection
4. TLS certificate is valid

### Authentication Failed

**Symptom:** `AuthenticationException`

**Checklist:**
1. Username and password correct
2. User exists in server config
3. API key is valid (if using)

### TLS Errors

**Symptom:** SSL/TLS handshake failed

**Solutions:**
```csharp
// Trust self-signed certificate
var options = new ClientOptions
{
    TlsSkipVerify = true  // Only for development
};

// Or specify certificate
var options = new ClientOptions
{
    TlsCaCertificate = "/path/to/ca.crt"
};
```

## Cluster Issues

### Split Brain

**Symptom:** Multiple nodes claim to be leader

**Cause:** Network partition with nodes unable to communicate

**Solution:**
1. Restore network connectivity
2. If persistent, restart minority partition
3. Check firewall rules between nodes

### Node Won't Join

**Symptom:** New node cannot join cluster

**Checklist:**
1. Cluster ID matches
2. Network connectivity to peers
3. Raft ports open
4. Configuration correct

### Replication Lag

**Symptom:** Followers behind leader

**Diagnosis:**
```bash
phoenixmldb-cluster status
# Shows replication status for each node
```

**Solutions:**
1. Check network bandwidth
2. Reduce write load
3. Increase snapshot frequency

## Performance Issues

### High Memory Usage

**Causes and solutions:**
1. **Large transactions** — Use smaller batches
2. **Unclosed transactions** — Ensure disposal
3. **Large documents in memory** — Use streaming
4. **Many readers** — Reduce max readers

### High CPU Usage

**Causes and solutions:**
1. **Complex queries** — Optimize or add indexes
2. **Full scans** — Add path/value indexes
3. **XPath compilation** — Use prepared queries

### High Disk I/O

**Causes and solutions:**
1. **Frequent syncs** — Consider NoMetaSync
2. **Large writes** — Batch in transactions
3. **No SSD** — Upgrade to SSD storage

## Logging and Diagnostics

### Enable Debug Logging

```csharp
var options = new DatabaseOptions
{
    Logger = LoggerFactory.Create(builder =>
    {
        builder.AddConsole();
        builder.SetMinimumLevel(LogLevel.Debug);
    }).CreateLogger<XmlDatabase>()
};
```

### Query Metrics

```csharp
var options = new QueryOptions
{
    CollectMetrics = true
};

var result = db.Query(xquery, options);
Console.WriteLine($"Parse: {result.Metrics.ParseTime}");
Console.WriteLine($"Execute: {result.Metrics.ExecuteTime}");
Console.WriteLine($"Rows scanned: {result.Metrics.RowsScanned}");
```

### Database Statistics

```csharp
var stats = db.GetStatistics();
Console.WriteLine($"Containers: {stats.ContainerCount}");
Console.WriteLine($"Documents: {stats.DocumentCount}");
Console.WriteLine($"Size: {stats.UsedBytes / 1024 / 1024} MB");
Console.WriteLine($"Readers: {stats.ActiveReaders}");
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
