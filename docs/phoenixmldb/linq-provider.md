---
title: LINQ Provider
description: Query PhoenixmlDb with LINQ — XML navigation, fluent API, and type mapping
sort: 12
---

# LINQ Provider

PhoenixmlDb provides a comprehensive LINQ provider that enables querying XML documents using familiar C# syntax. The LINQ queries are translated directly to XQuery AST for optimal performance.

## Overview

The LINQ provider offers two approaches:

1. **Direct AST Generation** (Recommended) — Generates XQuery AST directly for better optimization
2. **String-based Translation** (Legacy) — Generates XQuery strings

## Getting Started

### Basic Usage

```csharp
using PhoenixmlDb.Linq;
using PhoenixmlDb.Query.Execution;

// Create query engine and provider
var queryEngine = new QueryEngine(indexConfig);
var containerId = await database.OpenContainerAsync("books");

// Create a queryable source
var books = XmlQuery.FromContainer(containerId, queryEngine);

// Execute LINQ queries
var results = await books
    .Where(e => e.LocalName == "book")
    .OrderBy(e => e.Element("title").Value())
    .ToListAsync();
```

### Async Operations

All queries support async execution:

```csharp
// Async enumeration
await foreach (var book in books.Where(e => e.LocalName == "book"))
{
    Console.WriteLine(book.StringValue);
}

// Async methods
var firstBook = await books.FirstAsync();
var count = await books.CountAsync();
var exists = await books.AnyAsync(e => e.LocalName == "bestseller");
```

## Supported LINQ Operations

### Filtering

```csharp
// Where clause
var fiction = books.Where(e => e.Element("genre").Value() == "Fiction");

// Multiple conditions
var recent = books.Where(e =>
    e.Element("year").Value() == "2024" &&
    e.Element("price").Value() < "50");
```

### Projection

```csharp
// Select specific data
var titles = books.Select(e => e.Element("title").Value());

// Project to anonymous types
var summary = books.Select(e => new {
    Title = e.Element("title").Value(),
    Author = e.Element("author").Value()
});
```

### Ordering

```csharp
// Single key ordering
var byTitle = books.OrderBy(e => e.Element("title").Value());

// Descending order
var byDateDesc = books.OrderByDescending(e => e.Element("date").Value());

// Multiple keys
var sorted = books
    .OrderBy(e => e.Element("author").Value())
    .ThenByDescending(e => e.Element("year").Value());
```

### Aggregation

```csharp
// Count
var totalBooks = await books.CountAsync();
var fictionCount = await books.CountAsync(e => e.Element("genre").Value() == "Fiction");

// Any/All
var hasExpensive = await books.AnyAsync(e => e.Element("price").Value() > "100");
var allInStock = await books.AllAsync(e => e.Element("stock").Value() != "0");

// First/Single
var firstBook = await books.FirstAsync();
var singleBestseller = await books.SingleAsync(e => e.Element("bestseller").Value() == "true");
```

### Pagination

```csharp
// Take and Skip
var firstTen = await books.Take(10).ToListAsync();
var page2 = await books.Skip(10).Take(10).ToListAsync();
```

### Distinct

```csharp
var uniqueAuthors = await books
    .Select(e => e.Element("author").Value())
    .Distinct()
    .ToListAsync();
```

## XML Navigation Extensions

The LINQ provider includes extension methods for XML navigation:

### Child Elements

```csharp
// Single child element
var title = book.Element("title");

// All child elements
var children = book.Elements();

// Named child elements
var chapters = book.Elements("chapter");
```

### Attributes

```csharp
// Single attribute
var id = book.Attribute("id");

// All attributes
var attrs = book.Attributes();

// Named attributes
var isbnAttrs = book.Attributes("isbn");
```

### Descendant Navigation

```csharp
// All descendants
var allElements = book.Descendants();

// Named descendants
var allParagraphs = book.Descendants("p");
```

### Ancestor Navigation

```csharp
// All ancestors
var parents = element.Ancestors();

// Named ancestors
var chapters = paragraph.Ancestors("chapter");
```

### Getting Values

```csharp
// String value of element
var text = element.Value();

// Attribute value
var attrValue = attr.Value();
```

## Fluent Query API

For complex queries, use the fluent API:

```csharp
using PhoenixmlDb.Linq;

var query = FluentXmlQuery
    .From(containerId, queryEngine)
    .Where(e => e.Element("genre").Value() == "Fiction")
    .Let("totalPrice", e => e.Element("price").Value())
    .OrderBy(e => e.Element("title").Value())
    .Select(e => new {
        Title = e.Element("title").Value(),
        Price = e.Element("price").Value()
    });

var results = await query.ExecuteAsync();
```

### Fluent Query Features

```csharp
// Position tracking
var withPosition = FluentXmlQuery
    .From(containerId, queryEngine)
    .WithPosition()
    .Select(x => new { Position = x.position, Item = x.item });

// Group by
var grouped = FluentXmlQuery
    .From(containerId, queryEngine)
    .GroupBy(e => e.Element("author").Value());

// Query explanation
var explanation = query.Explain();
Console.WriteLine(explanation.AstString);
Console.WriteLine(explanation.ExecutionPlan);
```

## Query Debugging

### View XQuery AST

```csharp
var query = books.Where(e => e.LocalName == "book");

// Get the AST
var ast = query.GetAst();
Console.WriteLine(ast?.ToString());

// Get full explanation
var explanation = query.Explain();
Console.WriteLine($"AST: {explanation?.AstString}");
Console.WriteLine($"Plan: {explanation?.ExecutionPlan}");
Console.WriteLine($"Compiled: {explanation?.CompilationSucceeded}");
```

### Provider Access

```csharp
// Access the underlying provider
var provider = books.GetDirectProvider();
if (provider != null)
{
    var compilationResult = provider.Compile(books.Expression);
    // Inspect compilation result
}
```

## Type Mapping

The LINQ provider automatically maps .NET types to XDM types:

| .NET Type | XDM Type |
|-----------|----------|
| `string` | `xs:string` |
| `int`, `long` | `xs:integer` |
| `decimal` | `xs:decimal` |
| `double`, `float` | `xs:double` |
| `bool` | `xs:boolean` |
| `DateTime` | `xs:dateTime` |
| `XmlElement` | `element()` |
| `XmlAttribute` | `attribute()` |

### Custom Type Mapping

```csharp
// Create entity mapping for POCOs
var mapping = new EntityMapping<Book>()
    .Property(b => b.Title, "title")
    .Property(b => b.Author, "author")
    .Property(b => b.Price, "price");
```

## String Functions

String methods are translated to XQuery functions:

```csharp
// Contains
books.Where(e => e.Element("title").Value().Contains("Guide"))

// StartsWith
books.Where(e => e.Element("author").Value().StartsWith("J"))

// EndsWith
books.Where(e => e.Element("title").Value().EndsWith("Edition"))

// ToLower/ToUpper
books.Select(e => e.Element("title").Value().ToLower())

// Substring
books.Select(e => e.Element("title").Value().Substring(0, 10))

// Trim
books.Select(e => e.Element("title").Value().Trim())
```

## Best Practices

### 1. Use Direct Provider

```csharp
// Recommended: Direct AST generation
var books = XmlQuery.FromContainer(containerId, queryEngine);

// Legacy: String-based translation
var books = XmlQuery.FromContainer(containerId, legacyExecutor);
```

### 2. Use Async Operations

```csharp
// Preferred: Async execution
var results = await books.ToListAsync();

// Avoid: Blocking calls on async code
var results = books.ToList(); // May block thread pool
```

### 3. Filter Early

```csharp
// Good: Filter before projection
var result = books
    .Where(e => e.Element("price").Value() < "50")
    .Select(e => e.Element("title").Value());

// Less efficient: Filter after projection
var result = books
    .Select(e => new { e, price = e.Element("price").Value() })
    .Where(x => x.price < "50");
```

### 4. Use Pagination

```csharp
// Good: Limit results
var page = await books.Skip(100).Take(10).ToListAsync();

// Avoid: Loading everything
var all = await books.ToListAsync();
var page = all.Skip(100).Take(10);
```

### 5. Inspect Query Plans

```csharp
// Check query efficiency
var explanation = query.Explain();
if (!explanation.CompilationSucceeded)
{
    foreach (var error in explanation.Errors)
    {
        Console.WriteLine($"Error: {error}");
    }
}
```

## LINQ to FLWOR Mapping

| LINQ | XQuery FLWOR |
|------|--------------|
| `Where(predicate)` | `where predicate` |
| `Select(selector)` | `return selector` |
| `SelectMany(collection)` | Nested `for` clause |
| `OrderBy(key)` | `order by key` |
| `OrderByDescending(key)` | `order by key descending` |
| `Take(n)` | `subsequence(..., 1, n)` |
| `Skip(n)` | `subsequence(..., n+1)` |
| `First()` | `[1]` |
| `Count()` | `count(...)` |
| `Any()` | `exists(...)` |
| `All(predicate)` | `empty(... where not(predicate))` |
| `Distinct()` | `distinct-values(...)` |

## Performance Considerations

1. **Index Usage** — The query optimizer will use available indexes when possible
2. **Streaming** — Large result sets are streamed rather than loaded into memory
3. **Lazy Evaluation** — Queries are only executed when results are enumerated
4. **AST Optimization** — Direct AST generation enables better query optimization
