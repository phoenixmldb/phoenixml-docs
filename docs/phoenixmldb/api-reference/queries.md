---
title: Queries API
description: XQuery execution, parameters, results, explain plans, and prepared queries
sort: 4
---

# Query API

The Query API provides methods for executing XQuery queries and processing results.

## Basic Queries

### Execute Query

```csharp
// Simple query
var results = db.Query("collection('products')//product/name/text()");

foreach (var name in results)
{
    Console.WriteLine(name);
}
```

### Query Single Value

```csharp
// Get single result
int count = db.QuerySingle<int>("count(collection('products')//product)");

decimal total = db.QuerySingle<decimal>("sum(collection('orders')//order/total)");

string name = db.QuerySingle<string>(
    "collection('products')//product[@id='123']/name/text()");
```

### Query with Default

```csharp
// Returns default(T) if no results
string name = db.QuerySingleOrDefault<string>(
    "collection('products')//product[@id='999']/name/text()");
// Returns null if not found

int count = db.QuerySingleOrDefault<int>("count(//nonexistent)");
// Returns 0
```

## Parameterized Queries

### Basic Parameters

```csharp
var results = db.Query("""
    for $p in collection('products')//product
    where $p/price < $maxPrice
    return $p/name/text()
    """,
    new QueryParameters
    {
        ["maxPrice"] = 100.0
    });
```

### Multiple Parameters

```csharp
var results = db.Query("""
    for $p in collection('products')//product
    where $p/category = $category
      and $p/price >= $minPrice
      and $p/price <= $maxPrice
    order by $p/name
    return $p
    """,
    new QueryParameters
    {
        ["category"] = "Electronics",
        ["minPrice"] = 50.0,
        ["maxPrice"] = 500.0
    });
```

### Parameter Types

```csharp
var parameters = new QueryParameters
{
    ["stringParam"] = "text",
    ["intParam"] = 42,
    ["decimalParam"] = 3.14m,
    ["boolParam"] = true,
    ["dateParam"] = DateTime.Now,
    ["listParam"] = new[] { "a", "b", "c" }
};
```

## Query Results

### IQueryResult

```csharp
IQueryResult results = db.Query(xquery);

// Properties
int count = results.Count;
bool isEmpty = results.IsEmpty;

// Iteration
foreach (string item in results)
{
    Console.WriteLine(item);
}

// Access methods
string first = results.First();
string firstOrDefault = results.FirstOrDefault();

// Typed conversion
IEnumerable<int> numbers = results.As<int>();
IEnumerable<decimal> prices = results.As<decimal>();
```

### Typed Results

```csharp
// Query returns integers
var counts = db.Query("(1, 2, 3, 4, 5)").As<int>();

// Query returns decimals
var prices = db.Query("//product/price").As<decimal>();

// Query returns dates
var dates = db.Query("//order/date").As<DateTime>();
```

## XQuery Update

### Execute Updates

```csharp
// Update documents (no return value)
db.Execute("""
    replace value of node doc('products/p1.xml')/product/price
    with 29.99
    """);

// Insert
db.Execute("""
    insert node <rating>5</rating>
    into doc('products/p1.xml')/product
    """);

// Delete
db.Execute("""
    delete node //product[@discontinued='true']
    """);
```

### Parameterized Updates

```csharp
db.Execute("""
    replace value of node doc('products/' || $docName)/product/price
    with $newPrice
    """,
    new QueryParameters
    {
        ["docName"] = "widget.xml",
        ["newPrice"] = 24.99
    });
```

## In Transactions

### Read Query

```csharp
using (var txn = db.BeginTransaction(readOnly: true))
{
    // Snapshot isolation - consistent view
    var products = txn.Query("collection('products')//product");
    var orders = txn.Query("collection('orders')//order");

    // Process with guaranteed consistency
}
```

### Update in Transaction

```csharp
using (var txn = db.BeginTransaction())
{
    // Check condition
    var exists = txn.QuerySingle<bool>(
        "exists(collection('products')//product[@id=$id])",
        new QueryParameters { ["id"] = "123" });

    if (!exists)
    {
        // Insert new product
        txn.GetContainer("products").PutDocument("p123.xml", productXml);
    }
    else
    {
        // Update existing
        txn.Execute("""
            replace value of node
            collection('products')//product[@id='123']/price
            with 29.99
            """);
    }

    txn.Commit();
}
```

## Query Options

```csharp
var options = new QueryOptions
{
    Timeout = TimeSpan.FromSeconds(30),
    MaxResults = 1000,
    DefaultContainer = "products"
};

var results = db.Query(xquery, parameters, options);
```

## Explain Plan

```csharp
var plan = db.Explain("""
    for $p in collection('products')//product
    where $p/price > 100
    order by $p/name
    return $p
    """);

Console.WriteLine(plan.ToString());
Console.WriteLine($"Estimated cost: {plan.EstimatedCost}");
Console.WriteLine($"Indexes used: {string.Join(", ", plan.IndexesUsed)}");
```

## Prepared Queries

```csharp
// Compile once, execute many times
var prepared = db.Prepare("""
    for $p in collection('products')//product
    where $p/category = $category
    return $p/name/text()
    """);

// Execute with different parameters
var electronics = prepared.Execute(new QueryParameters { ["category"] = "Electronics" });
var clothing = prepared.Execute(new QueryParameters { ["category"] = "Clothing" });

// Dispose when done
prepared.Dispose();
```

## Error Handling

```csharp
try
{
    var results = db.Query(xquery);
}
catch (XQueryParseException ex)
{
    // Syntax error
    Console.WriteLine($"Parse error at line {ex.Line}, column {ex.Column}");
    Console.WriteLine($"Message: {ex.Message}");
}
catch (XQueryRuntimeException ex)
{
    // Runtime error
    Console.WriteLine($"Runtime error: {ex.ErrorCode}");
    Console.WriteLine($"Message: {ex.Message}");
}
catch (QueryTimeoutException ex)
{
    Console.WriteLine("Query timed out");
}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `XPST0003` | Static error (syntax) |
| `XPST0008` | Undefined variable |
| `XPST0017` | Unknown function |
| `XPTY0004` | Type error |
| `FOAR0001` | Division by zero |
| `FORG0001` | Invalid value for cast |

## Best Practices

1. **Use parameters** - Never concatenate user input into queries
2. **Limit results** - Use `[position() <= $limit]` for large result sets
3. **Use prepared queries** - For frequently executed queries
4. **Check explain plans** - Verify index usage
5. **Handle errors** - Catch and handle query exceptions
6. **Use transactions** - For consistent multi-query operations

## Next Steps

| Language Reference | Performance | Transactions |
|-------------------|-------------|--------------|
| **[XQuery Guide](../../language-reference/xquery/index.md)**<br>XQuery language reference | **[Index API](indexes.md)**<br>Optimize queries with indexes | **[Transaction API](transactions.md)**<br>Transactional queries |
