---
title: Queries API
description: XQuery execution, parameters, results, and error handling
sort: 4
---

# Query API

Queries run against one container through `IContainer.QueryAsync` (or `IReadTransaction.QueryAsync`, which takes the container's `ContainerId`). The engine is the PhoenixmlDb XQuery 4.0 engine.

```csharp
IAsyncEnumerable<object> QueryAsync(
    string query,
    IReadOnlyDictionary<string, object>? variables = null,
    CancellationToken cancellationToken = default);

IAsyncEnumerable<object> QueryAsync(
    string query,
    IReadOnlyDictionary<string, object>? variables,
    Predicate<string>? documentNameFilter,
    CancellationToken cancellationToken = default);
```

## Basic Queries

### Execute Query

```csharp
var products = await db.OpenOrCreateContainerAsync("products");

await foreach (var name in products.QueryAsync("//product/name/text()"))
{
    Console.WriteLine(name);
}
```

### How a query is evaluated

A query is classified when it is compiled:

- **Row-wise queries** — a per-document filter, map or projection such as `//product[price > 100]/name` — run once per document in the container, with that document as the context item, so path expressions need no `doc()` or `collection()` prefix. Results from all documents are concatenated in document-name order.
- **Cross-document queries** — global aggregation (`sum`, `avg`, `min`, `max`), `count(collection())`, `distinct-values` across documents, or a FLWOR `order by` / `group by` — run once, with `fn:collection()` spanning every document in the container.

```csharp
// One result: cross-document
await foreach (var n in products.QueryAsync("count(collection())"))
    Console.WriteLine(n);   // "3"

// One result per document: row-wise
await foreach (var n in products.QueryAsync("count(/product)"))
    Console.WriteLine(n);   // "1", "1", "1"
```

Because a row-wise query runs per document, an expression that does not depend on the context document — `doc('p1.xml')/product/name`, say — returns its result once for every document in the container.

`fn:collection()` with no argument is the container. `fn:doc()` and `fn:collection()` with a URI name a single document in the same container, by its bare name (`doc('p1.xml')`); there is no way to reach another container from a query.

### Query a Single Value

There is no typed single-value helper. Take the first result and convert it yourself:

```csharp
string? total = null;
await foreach (var r in orders.QueryAsync("sum(collection()//order/total)"))
{
    total = (string)r;
    break;
}

decimal value = decimal.Parse(total!, CultureInfo.InvariantCulture);
```

## Parameterized Queries

### Basic Parameters

Values in `variables` are bound as external variables. Declare each one in the query prolog:

```csharp
var variables = new Dictionary<string, object> { ["maxPrice"] = 100.0 };

await foreach (var name in products.QueryAsync("""
    declare variable $maxPrice external;
    /product[price < $maxPrice]/name/string()
    """, variables))
{
    Console.WriteLine(name);
}
```

### Multiple Parameters

```csharp
var variables = new Dictionary<string, object>
{
    ["category"] = "Electronics",
    ["minPrice"] = 50m,
    ["maxPrice"] = 500m
};

await foreach (var item in products.QueryAsync("""
    declare variable $category external;
    declare variable $minPrice external;
    declare variable $maxPrice external;
    /product[category = $category and price >= $minPrice and price <= $maxPrice]
    """, variables))
{
    Console.WriteLine(item);
}
```

### Parameter Types

Pass ordinary .NET values (`string`, `int`, `long`, `decimal`, `double`, `bool`). Variable names are matched in no namespace. When a declaration carries a type (`declare variable $n as xs:integer external;`) and the supplied value is a `string`, the string is cast to the declared type; a value that does not match the declared type raises a type error. A declared external variable that is not supplied, and has no default, raises `XPDY0002`.

## Query Results

`QueryAsync` returns `IAsyncEnumerable<object>`. Every item is a `string`: nodes are serialized as markup, and atomic values as their lexical form, using the adaptive output method.

```csharp
await foreach (var item in products.QueryAsync("/product[price > 100]"))
{
    string xml = (string)item;   // <product id="2"><name>Gadget</name>...</product>
}
```

For typed access to XDM nodes and values, use the XQuery engine directly (`PhoenixmlDb.XQuery`); the container surface is string-based.

### Filtering documents

The four-argument overload restricts the query to documents whose name passes `documentNameFilter`. The filter applies to `fn:collection()` and `fn:doc()` as well as to the per-document loop:

```csharp
await foreach (var item in products.QueryAsync(
    "count(collection())", variables: null,
    documentNameFilter: name => name.StartsWith("2024/", StringComparison.Ordinal)))
{
    Console.WriteLine(item);
}
```

## XQuery Update

The embedded query surface does not apply XQuery Update Facility expressions to stored documents: an updating query against a container changes nothing. Modify documents with `PutDocumentAsync` (which replaces the whole document) and `DeleteDocumentAsync`, directly or inside a write transaction.

## In Transactions

`IReadTransaction.QueryAsync` and the inherited method on `IWriteTransaction` take the container's id:

```csharp
using (var read = db.BeginRead())
{
    await foreach (var item in read.QueryAsync(products.Id, "count(collection())"))
        Console.WriteLine(item);
}
```

A transaction's query sees committed data. It does not see writes buffered in an uncommitted `IWriteTransaction`, including the transaction's own, and it is not a snapshot shared across calls: each query reads the committed state at the time it runs. See [Transaction API](transactions.md).

## Static Namespaces

Prefixes bound in `ContainerOptions.DefaultNamespaces` are available to every query on the container, in addition to the predeclared prefixes (`fn`, `xs`, `map`, `array`, `math`, `phx`, ...):

```csharp
var orders = await db.CreateContainerAsync("orders",
    opts => opts.DefaultNamespaces["o"] = "urn:orders");

await foreach (var id in orders.QueryAsync("/o:order/o:id/string()"))
    Console.WriteLine(id);
```

## Cancellation

Pass a `CancellationToken` to `QueryAsync` (or with `WithCancellation`) to stop a long-running query; cancellation surfaces as `OperationCanceledException`. There is no built-in query timeout or result limit; apply your own with a token from `CancellationTokenSource.CancelAfter`.

## Error Handling

```csharp
try
{
    await foreach (var item in products.QueryAsync(xquery))
        Console.WriteLine(item);
}
catch (PhoenixmlDb.XQuery.Functions.XQueryException ex)
{
    // Compilation failed: raised before any document is read
    Console.WriteLine($"Static error: {ex.ErrorCode}");
    Console.WriteLine($"Message: {ex.Message}");
}
catch (PhoenixmlDb.XQuery.Execution.XQueryRuntimeException ex)
{
    // Dynamic error during evaluation
    Console.WriteLine($"Runtime error: {ex.ErrorCode}");
    Console.WriteLine($"Message: {ex.Message}");
}
```

Errors surface when the sequence is enumerated, not when `QueryAsync` is called. A stored document that cannot be loaded for a query is skipped rather than failing the query.

### Common Error Codes

| Code | Description |
|------|-------------|
| `XPST0003` | Static error (syntax) |
| `XPST0008` | Undefined variable |
| `XPST0017` | Unknown function |
| `XPTY0004` | Type error |
| `XPDY0002` | External variable not bound |
| `FOAR0001` | Division by zero |
| `FORG0001` | Invalid value for cast |

## Best Practices

1. **Use parameters** - Never concatenate user input into queries; bind it through `variables`
2. **Know which shape you wrote** - Aggregate over `collection()` for one answer; a bare path expression answers per document
3. **Limit results** - Use `[position() <= $limit]` inside a cross-document query, or stop enumerating early
4. **Declare indexes** - Index frequently filtered paths (see [Index API](indexes.md))
5. **Handle errors** - Catch both the static and the runtime exception types

## Next Steps

| Language Reference | Performance | Transactions |
|-------------------|-------------|--------------|
| **[XQuery Guide](../../language-reference/xquery/index.md)**<br>XQuery language reference | **[Index API](indexes.md)**<br>Optimize queries with indexes | **[Transaction API](transactions.md)**<br>Transactional queries |
