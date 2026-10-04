---
title: Quick Start
description: Your first PhoenixmlDb query in 5 minutes
sort: 2
---

# Quick Start

This guide provides hands-on examples to get you productive with PhoenixmlDb quickly.

## Creating a Database

A database is a directory containing all your containers, documents, and indexes:

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Storage;
using PhoenixmlDb.Storage.Lmdb;

// Create (or open) a database in the specified directory
using var db = new DocumentDatabase("./data/myapp");

// Or with custom storage options
var options = new LmdbStorageOptions
{
    MapSize = 10L * 1024 * 1024 * 1024, // 10 GB
    MaxReaders = 126
};
using var db2 = new DocumentDatabase("./data/otherapp", options);
```

`DocumentDatabase.Open(path, options)` is equivalent to the constructor. A given directory can
be open only once per process; opening it a second time throws
`LmdbEnvironmentAlreadyOpenException`.

> **Note:** Always dispose the database when done. `DocumentDatabase` implements both
> `IDisposable` and `IAsyncDisposable`, so `using` or `await using` ensures proper cleanup.

## Working with Containers

Containers organize your documents into logical groups. Container operations are asynchronous:

```csharp
// Create a container
var customers = await db.CreateContainerAsync("customers");

// Create with options
var orders = await db.CreateContainerAsync("orders", opts =>
{
    opts.ValidationMode = ValidationMode.WellFormed;
    opts.PreserveWhitespace = false;
});

// Get an existing container (null if it does not exist)
var existing = await db.OpenContainerAsync("customers");

// Open if it exists, create it otherwise
var products = await db.OpenOrCreateContainerAsync("products");

// List all containers
await foreach (var info in db.ListContainersAsync())
{
    Console.WriteLine($"{info.Name}: {info.DocumentCount} documents");
}

// Delete a container (and all its documents)
await db.DeleteContainerAsync("temp");
```

## Storing Documents

### XML Documents

```csharp
var container = await db.OpenOrCreateContainerAsync("products");

// Store from string
await container.PutDocumentAsync("product1.xml", """
    <product>
        <name>Widget</name>
        <price>19.99</price>
    </product>
    """);

// Store from file
await container.PutDocumentAsync("product2.xml", File.ReadAllText("product.xml"));

// Store from stream (the caller keeps ownership of the stream)
using (var stream = File.OpenRead("large-product.xml"))
{
    await container.PutDocumentAsync("product3.xml", stream);
}

// Attach metadata to a stored document
await container.SetMetadataAsync("product1.xml", "author", "john.doe");
await container.SetMetadataAsync("product1.xml", "version", "1.0");
```

Putting a document under an existing name replaces it (`DocumentOptions.Overwrite` defaults
to `true`).

### JSON Documents

```csharp
var container = await db.OpenOrCreateContainerAsync("api-data");

// Content starting with '{' or '[' is detected as JSON
await container.PutDocumentAsync("user1.json", """
    {
        "id": 1,
        "name": "Alice",
        "email": "alice@example.com",
        "roles": ["admin", "user"]
    }
    """);

// Or state the content type explicitly
await container.PutDocumentAsync("user2.json", """{ "id": 2, "name": "Bob" }""",
    new DocumentOptions { ContentType = ContentType.Json });
```

JSON is converted to XML on the way in, using the XQuery 3.1 `fn:json-to-xml` representation
(elements such as `map`, `array`, `string` and `number` in the
`http://www.w3.org/2005/xpath-functions` namespace). It is queried, and returned by
`GetContentAsync()`, in that XML form.

## Retrieving Documents

```csharp
var container = await db.OpenOrCreateContainerAsync("products");

// Get a document (null if it does not exist)
var doc = await container.GetDocumentAsync("product1.xml");
if (doc is not null)
{
    string xml = await doc.GetContentAsync();
    Console.WriteLine($"{doc.Name} ({doc.SizeBytes} bytes): {xml}");
}

// Check if a document exists
if (await container.DocumentExistsAsync("product1.xml"))
{
    // ...
}

// Get document metadata
var author = await container.GetMetadataAsync("product1.xml", "author");
Console.WriteLine($"Author: {author}");

// List documents
await foreach (var info in container.ListDocumentsAsync())
{
    Console.WriteLine(info.Name);
}

// List with prefix filter
await foreach (var info in container.ListDocumentsAsync("product"))
{
    Console.WriteLine(info.Name);
}
```

## Querying with XQuery

Queries run against a container with `IContainer.QueryAsync`. Inside the query,
`fn:collection()` spans every document in that container. Each result item is returned
serialized as a string.

### Basic Queries

```csharp
var books = await db.OpenOrCreateContainerAsync("books");

// Simple path query
await foreach (var title in books.QueryAsync("collection()//title/text()"))
{
    Console.WriteLine(title);
}

// Query with FLWOR expression
var query = """
    for $book in collection()//book
    where xs:integer($book/year) > 2020
    order by $book/title
    return $book/title/text()
    """;

await foreach (var result in books.QueryAsync(query))
{
    Console.WriteLine(result);
}
```

### Parameterized Queries

Pass variables in a dictionary and declare them as external variables in the query:

```csharp
var products = await db.OpenOrCreateContainerAsync("products");

var query = """
    declare variable $maxPrice external;
    declare variable $category external;
    for $p in collection()//product
    where xs:decimal($p/price) <= $maxPrice
      and $p/category = $category
    return $p
    """;

var variables = new Dictionary<string, object>
{
    ["maxPrice"] = 100.0m,
    ["category"] = "Electronics"
};

await foreach (var product in products.QueryAsync(query, variables))
{
    Console.WriteLine(product);
}
```

### Aggregate Queries

Aggregates over `collection()` are evaluated across the whole container and return a single
item:

```csharp
var orders = await db.OpenOrCreateContainerAsync("orders");

static async Task<string?> QuerySingleAsync(IContainer container, string query)
{
    await foreach (var item in container.QueryAsync(query))
        return item.ToString();
    return null;
}

// Count
var count = int.Parse(await QuerySingleAsync(orders, "count(collection()//order)") ?? "0");

// Sum
var total = decimal.Parse(
    await QuerySingleAsync(orders, "sum(collection()//order/xs:decimal(total))") ?? "0",
    CultureInfo.InvariantCulture);

// Average
var avgTotal = await QuerySingleAsync(orders, "avg(collection()//order/xs:decimal(total))");
```

(`CultureInfo` is in `System.Globalization`.)

## Using Transactions

```csharp
var inventory = await db.OpenOrCreateContainerAsync("inventory");

// Read transaction
using (var read = db.BeginRead())
{
    await foreach (var item in read.QueryAsync(inventory.Id, "collection()//item"))
    {
        Console.WriteLine(item);
    }
}

// Write transaction
await using (var txn = await db.BeginWriteAsync())
{
    // Multiple operations in a single transaction
    await txn.PutDocumentAsync(inventory.Id, "item1.xml", "<item id='1'/>");
    await txn.PutDocumentAsync(inventory.Id, "item2.xml", "<item id='2'/>");
    await txn.DeleteDocumentAsync(inventory.Id, "old-item.xml");

    // Commit all changes atomically
    await txn.CommitAsync();
}
// Write operations are buffered until CommitAsync(). If the transaction is disposed
// without committing (or RollbackAsync() is called), nothing is written.
```

## Creating Indexes

Indexes are declared on a container when it is created, through `ContainerOptions.Indexes`.
Index maintenance is opt-in: call `EnableIndexing()` (from the `PhoenixmlDb.Indexing` package)
on the database, otherwise the declarations are not maintained and queries are answered by
scanning.

```csharp
using PhoenixmlDb.Indexing;

db.EnableIndexing();

var products = await db.CreateContainerAsync("indexed-products", opts =>
{
    // Path index for fast element lookup
    opts.Indexes.AddPathIndex("/product/price");

    // Value index for comparisons and range queries
    opts.Indexes.AddValueIndex("/product/price", XdmValueType.XdmDecimal);

    // Full-text index
    opts.Indexes.AddFullTextIndex("/product/description");
});
```

## Complete Example

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Indexing;
using PhoenixmlDb.Storage;

// Setup
using var db = new DocumentDatabase("./bookstore");
db.EnableIndexing();

// Declare indexes when the container is created
var books = await db.OpenOrCreateContainerAsync("books", opts =>
{
    opts.Indexes.AddValueIndex("/book/year", XdmValueType.XdmInteger);
    opts.Indexes.AddFullTextIndex("/book/title");
});

// Add sample data
await books.PutDocumentAsync("book1.xml", """
    <book isbn="978-0-13-468599-1">
        <title>The Pragmatic Programmer</title>
        <author>David Thomas</author>
        <author>Andrew Hunt</author>
        <year>2019</year>
        <price>49.99</price>
    </book>
    """);

await books.PutDocumentAsync("book2.xml", """
    <book isbn="978-0-596-51774-8">
        <title>JavaScript: The Good Parts</title>
        <author>Douglas Crockford</author>
        <year>2008</year>
        <price>29.99</price>
    </book>
    """);

// Query: Find books by year range
var recentBooks = books.QueryAsync("""
    for $b in collection()//book
    where xs:integer($b/year) >= 2015
    order by xs:integer($b/year) descending
    return <result>
        <title>{$b/title/text()}</title>
        <year>{$b/year/text()}</year>
    </result>
    """);

Console.WriteLine("Recent books:");
await foreach (var book in recentBooks)
{
    Console.WriteLine(book);
}

// Substring search
var searchResults = books.QueryAsync("""
    for $b in collection()//book
    where contains($b/title, 'Pragmatic')
    return $b/title/text()
    """);

Console.WriteLine("\nSearch results:");
await foreach (var title in searchResults)
{
    Console.WriteLine(title);
}
```

## Next Steps

| Build an App | Understand Architecture | Master XQuery |
|---|---|---|
| **[First Application](first-application.md)**<br>Build a complete application with PhoenixmlDb. | **[Core Concepts](../phoenixmldb/core-concepts.md)**<br>Understand the architecture and design principles. | **[XQuery Guide](../language-reference/xquery/index.md)**<br>Master XQuery for powerful document queries. |
