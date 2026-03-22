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
using PhoenixmlDb;

// Create database in specified directory
using var db = new XmlDatabase("./data/myapp");

// Or with custom options
var options = new DatabaseOptions
{
    MapSize = 10L * 1024 * 1024 * 1024, // 10 GB
    MaxContainers = 100,
    MaxReaders = 126
};
using var db2 = new XmlDatabase("./data/myapp", options);
```

> **Note:** Always dispose the database when done. Using the `using` statement ensures proper cleanup.

## Working with Containers

Containers organize your documents into logical groups:

```csharp
// Create a container
var customers = db.CreateContainer("customers");

// Create with options
var orders = db.CreateContainer("orders", new ContainerOptions
{
    ValidationMode = ValidationMode.WellFormed,
    PreserveWhitespace = false
});

// Get existing container
var existing = db.GetContainer("customers");

// List all containers
foreach (var name in db.ListContainers())
{
    Console.WriteLine(name);
}

// Delete a container (and all its documents)
db.DeleteContainer("temp");
```

## Storing Documents

### XML Documents

```csharp
var container = db.GetContainer("products");

// Store from string
container.PutDocument("product1.xml", """
    <product>
        <name>Widget</name>
        <price>19.99</price>
    </product>
    """);

// Store from file
container.PutDocument("product2.xml", File.ReadAllText("product.xml"));

// Store from stream
using var stream = File.OpenRead("large-product.xml");
container.PutDocument("product3.xml", stream);

// Store with metadata
container.PutDocument("product4.xml", xmlContent, new DocumentMetadata
{
    ["author"] = "john.doe",
    ["created"] = DateTime.UtcNow.ToString("O"),
    ["version"] = "1.0"
});
```

### JSON Documents

```csharp
var container = db.GetContainer("api-data");

// Store JSON document
container.PutJsonDocument("user1.json", """
    {
        "id": 1,
        "name": "Alice",
        "email": "alice@example.com",
        "roles": ["admin", "user"]
    }
    """);

// JSON is automatically converted to XML internally
// but can be queried and retrieved as JSON
```

## Retrieving Documents

```csharp
var container = db.GetContainer("products");

// Get document as string
string xml = container.GetDocument("product1.xml");

// Check if document exists
if (container.DocumentExists("product1.xml"))
{
    // ...
}

// Get document metadata
var metadata = container.GetMetadata("product1.xml");
Console.WriteLine($"Author: {metadata["author"]}");

// List documents
foreach (var docName in container.ListDocuments())
{
    Console.WriteLine(docName);
}

// List with prefix filter
foreach (var docName in container.ListDocuments(prefix: "product"))
{
    Console.WriteLine(docName);
}
```

## Querying with XQuery

### Basic Queries

```csharp
// Simple path query
var titles = db.Query("collection('books')//title/text()");

// Query with FLWOR expression
var results = db.Query("""
    for $book in collection('books')//book
    where $book/year > 2020
    order by $book/title
    return $book/title/text()
    """);

// Iterate results
foreach (var result in results)
{
    Console.WriteLine(result);
}
```

### Parameterized Queries

```csharp
// Bind parameters to avoid injection
var results = db.Query("""
    for $p in collection('products')//product
    where $p/price <= $maxPrice
      and $p/category = $category
    return $p
    """,
    new QueryParameters
    {
        ["maxPrice"] = 100.0,
        ["category"] = "Electronics"
    });
```

### Aggregate Queries

```csharp
// Count
var count = db.QuerySingle<int>("count(collection('orders')//order)");

// Sum
var total = db.QuerySingle<decimal>("""
    sum(collection('orders')//order/total)
    """);

// Average
var avgPrice = db.QuerySingle<decimal>("""
    avg(collection('products')//product/price)
    """);
```

## Using Transactions

```csharp
// Read-only transaction (snapshot isolation)
using (var txn = db.BeginTransaction(readOnly: true))
{
    var results = txn.Query("collection('data')//item");
    // Results reflect consistent snapshot
}

// Read-write transaction
using (var txn = db.BeginTransaction())
{
    var container = txn.GetContainer("inventory");

    // Multiple operations in single transaction
    container.PutDocument("item1.xml", newXml1);
    container.PutDocument("item2.xml", newXml2);
    container.DeleteDocument("old-item.xml");

    // Commit all changes atomically
    txn.Commit();
}
// If Commit() not called, transaction is rolled back on dispose
```

## Creating Indexes

```csharp
var container = db.GetContainer("products");

// Path index for fast element lookup
container.CreateIndex(new PathIndex("price-idx", "/product/price"));

// Value index for range queries
container.CreateIndex(new ValueIndex("price-val-idx", "/product/price",
    ValueType.Decimal));

// Full-text index for search
container.CreateIndex(new FullTextIndex("desc-ft-idx", "/product/description"));

// Composite index
container.CreateIndex(new PathIndex("cat-name-idx",
    "/product/category", "/product/name"));
```

## Complete Example

```csharp
using PhoenixmlDb;

// Setup
using var db = new XmlDatabase("./bookstore");
var books = db.CreateContainer("books");

// Create indexes for better query performance
books.CreateIndex(new ValueIndex("year-idx", "/book/year", ValueType.Integer));
books.CreateIndex(new FullTextIndex("title-idx", "/book/title"));

// Add sample data
books.PutDocument("book1.xml", """
    <book isbn="978-0-13-468599-1">
        <title>The Pragmatic Programmer</title>
        <author>David Thomas</author>
        <author>Andrew Hunt</author>
        <year>2019</year>
        <price>49.99</price>
    </book>
    """);

books.PutDocument("book2.xml", """
    <book isbn="978-0-596-51774-8">
        <title>JavaScript: The Good Parts</title>
        <author>Douglas Crockford</author>
        <year>2008</year>
        <price>29.99</price>
    </book>
    """);

// Query: Find books by year range
var recentBooks = db.Query("""
    for $b in collection('books')//book
    where $b/year >= 2015
    order by $b/year descending
    return <result>
        <title>{$b/title/text()}</title>
        <year>{$b/year/text()}</year>
    </result>
    """);

Console.WriteLine("Recent books:");
foreach (var book in recentBooks)
{
    Console.WriteLine(book);
}

// Full-text search
var searchResults = db.Query("""
    for $b in collection('books')//book
    where contains($b/title, 'Pragmatic')
    return $b/title/text()
    """);

Console.WriteLine("\nSearch results:");
foreach (var title in searchResults)
{
    Console.WriteLine(title);
}
```

## Next Steps

| Build an App | Understand Architecture | Master XQuery |
|---|---|---|
| **[First Application](first-application.md)**<br>Build a complete application with PhoenixmlDb. | **[Core Concepts](../concepts/core-concepts.md)**<br>Understand the architecture and design principles. | **[XQuery Guide](../xquery/xquery-guide.md)**<br>Master XQuery for powerful document queries. |
