---
title: LINQ Provider
description: Query PhoenixmlDb with LINQ — XML navigation, fluent API, and type mapping
sort: 13
---

# LINQ Provider

`PhoenixmlDb.Linq` translates LINQ queries into an XQuery AST and runs them against a single
container, so the same query path that runs hand-written XQuery runs the LINQ query. A query
roots to one container.

> **Availability.** `PhoenixmlDb.Linq` and the database packages it builds on
> (`PhoenixmlDb.Storage` and the rest) are not yet published on NuGet. Only `PhoenixmlDb.Core`,
> `PhoenixmlDb.XQuery` and `PhoenixmlDb.Xslt` are.

## Overview

There are two entry points. Both use the same translator and the same operators.

1. **Container-rooted** (`container.AsQueryable()`) — the translated AST is serialized to XQuery
   source and run through `IContainer.QueryAsync`, the same public API any caller uses.
2. **Engine-rooted** (`XmlQuery.FromContainer(containerId, queryEngine)`) — the AST is handed
   directly to a `PhoenixmlDb.XQuery.Execution.QueryEngine` for a container id. This is the only
   path on which `Compile` and `Explain` work.

Each row of a query is the root element of one document in the container (the query's source is
`collection()/*`).

## Getting Started

### Basic Usage

Rows map onto a class with a parameterless constructor and settable properties:

```csharp
using PhoenixmlDb.Linq;
using PhoenixmlDb.Storage;

public sealed class Book
{
    public string Title { get; set; } = "";
    public string Author { get; set; } = "";
    public string Genre { get; set; } = "";
    public decimal Price { get; set; }
    public int Year { get; set; }
}

await using var db = new DocumentDatabase("./data");
var books = await db.OpenOrCreateContainerAsync("books");

await books.PutDocumentAsync("b1.xml",
    "<book><title>XQuery Guide</title><author>Jane Doe</author>" +
    "<genre>Fiction</genre><price>45.00</price><year>2024</year></book>");

var cheap = await books.AsQueryable<Book>()
    .Where(b => b.Price < 50m)
    .OrderBy(b => b.Title)
    .ToListAsync();
```

In a query, a property access becomes a child-element step named after the property in **lower
case**: `b.Price` is `price`. A property called `ReleaseDate` therefore addresses
`<releasedate>`, not `<releaseDate>`; use the untyped form (below) for mixed-case element names.

When results are materialized, each writable property is filled from the child element or
attribute whose local name matches the property name, ignoring case.

Without a class, `container.AsQueryable()` returns `XmlElement` rows and you navigate with the
[XML navigation extensions](#xml-navigation-extensions).

### Async Operations

The async terminals are extension methods on `IQueryable<T>` in `AsyncQueryableExtensions`:

```csharp
var query = books.AsQueryable<Book>();

// Async enumeration
await foreach (var book in query.Where(b => b.Genre == "Fiction").AsAsyncEnumerable())
{
    Console.WriteLine(book.Title);
}

// Async methods
var firstBook = await query.FirstAsync();
var count = await query.CountAsync();
var exists = await query.AnyAsync(b => b.Year == 2024);
```

Also available: `FirstOrDefaultAsync`, `SingleAsync`, `SingleOrDefaultAsync`, `LastAsync`,
`LastOrDefaultAsync`, `AllAsync`, `SumAsync`, `AverageAsync`, `MinAsync`, `MaxAsync`,
`ToArrayAsync`, `ToDictionaryAsync`, `ToLookupAsync` and `ForEachAsync`.

## Supported LINQ Operations

- Filtering: `Where`
- Projection: `Select` (including projection to new shapes), `SelectMany`
- Ordering: `OrderBy`, `OrderByDescending`, `ThenBy`, `ThenByDescending`
- Element selection: `First`, `FirstOrDefault`, `Single`, `SingleOrDefault`, `ElementAt`,
  `ElementAtOrDefault`
- Quantifiers and counts: `Count`, `Any`, `All`, `Contains`
- Paging: `Take`, `Skip`, `TakeWhile`, `SkipWhile`
- Set and sequence operators (within one container): `Distinct`, `DistinctBy`, `Union`,
  `Intersect`, `Except`, `Concat`, `Reverse`, `Order`, `OrderDescending`, `Last`,
  `LastOrDefault`, `DefaultIfEmpty`
- Aggregation: `Min`, `Max`, `Sum`, `Average`
- Grouping: `GroupBy`, including `GroupBy(...).Select(g => ...)` with `g.Key` and the group
  aggregates `g.Count()`, `g.Sum(sel)`, `g.Min(sel)`, `g.Max(sel)`, `g.Average(sel)` and `g.Any()`
- Join: `Join`, when both sources are the same container

### Filtering

```csharp
var query = books.AsQueryable<Book>();

// Where clause
var fiction = query.Where(b => b.Genre == "Fiction");

// Multiple conditions
var recent = query.Where(b => b.Year == 2024 && b.Price < 50m);
```

### Projection

```csharp
// Select specific data
var titles = query.Select(b => b.Title);

// Project to anonymous types
var summary = query.Select(b => new { b.Title, b.Author });
```

A `Select` that creates an anonymous type or an object initializer projects to an element
constructor: one child element per member, named after the member. The conditional operator
`cond ? a : b` maps to `if`/`then`/`else`, and `??` yields the left operand when it produces a
value, otherwise the right.

### Ordering

```csharp
// Single key ordering
var byTitle = query.OrderBy(b => b.Title);

// Descending order
var byYearDesc = query.OrderByDescending(b => b.Year);

// Multiple keys
var sorted = query
    .OrderBy(b => b.Author)
    .ThenByDescending(b => b.Year);
```

### Aggregation

```csharp
// Count
var totalBooks = await query.CountAsync();
var fictionCount = await query.CountAsync(b => b.Genre == "Fiction");

// Any/All
var hasExpensive = await query.AnyAsync(b => b.Price > 100m);
var allRecent = await query.AllAsync(b => b.Year >= 2000);

// First/Single
var firstBook = await query.FirstAsync();
var single = await query.SingleAsync(b => b.Title == "XQuery Guide");
```

### Pagination

```csharp
// Take and Skip
var firstTen = await query.Take(10).ToListAsync();
var page2 = await query.Skip(10).Take(10).ToListAsync();
```

### Distinct

```csharp
var uniqueAuthors = await query
    .Select(b => b.Author)
    .Distinct()
    .ToListAsync();
```

### Not supported

The provider refuses what it cannot translate rather than returning a wrong result. These throw
`NotSupportedException`, with the workaround in the message:

- Cross-container joins: the `Join` inner source must be the same container as the outer one.
- `GroupJoin` (`join ... into ...`).
- `Aggregate` and `Zip`. Materialize with `ToListAsync()` and apply them in memory.
- `Chunk`. Use `(await query.ToListAsync()).Chunk(size)`.
- `SequenceEqual`.
- `DefaultIfEmpty()` with no argument on a reference type. Pass an explicit default.
- `OfType`, `Cast`, and other operators not listed above.
- Any other CLR method or expression with no XQuery translation.

## XML Navigation Extensions

For `XmlElement` rows, `XmlExtensions` provides navigation methods that translate to XPath steps
inside a query:

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

`Value()` returns a `string`, so in an untyped query compare it with `==`, `!=` or the string
methods; C# has no `<` or `>` on strings. For numeric or date comparisons, use a typed row class.

```csharp
var fiction = books.AsQueryable()
    .Where(e => e.Element("genre").Value() == "Fiction")
    .OrderBy(e => e.Element("title").Value());
```

## Fluent Query API

`FluentQuery<T>` builds the FLWOR expression clause by clause. Create one with
`container.Fluent<T>()` (container-rooted) or `XmlQuery.Fluent<T>(containerId, queryEngine)`
(engine-rooted):

```csharp
using PhoenixmlDb.Linq;

var query = books.Fluent<Book>()
    .Where(b => b.Genre == "Fiction")
    .Let("price", b => b.Price)
    .OrderBy(b => b.Title)
    .Select(b => new { b.Title, b.Price });

var results = await query.ExecuteAsync();
```

### Fluent Query Features

```csharp
// Position tracking (an XQuery count clause)
var withPosition = books.Fluent<Book>()
    .WithPosition();

// Group by
var grouped = books.Fluent<Book>()
    .GroupBy(b => b.Author);

// The generated FLWOR expression
var ast = books.Fluent<Book>().Where(b => b.Price < 50m).ToAst();
Console.WriteLine(ast);
```

`FluentQuery<T>` also has `Select`, `SelectMany`, `OrderByDescending`, `Take`, `Skip`,
`Distinct`, and the terminals `ExecuteAsync`, `FirstAsync`, `FirstOrDefaultAsync`, `AnyAsync`,
`CountAsync` and `AsAsyncEnumerable`. `OrderBy` returns an `OrderedFluentQuery<T>` with
`ThenBy` and `ThenByDescending`. A `DirectXmlQueryable<T>` converts with `AsFluent()`.

## Query Debugging

### View XQuery AST

`GetAst()` works on either entry point:

```csharp
var query = books.AsQueryable<Book>().Where(b => b.Price < 50m);

var ast = query.GetAst();
Console.WriteLine(ast?.ToString());
```

### Explain and Compile

`Explain()` and `GetDirectProvider().Compile(...)` compile the query with a `QueryEngine`, so they
work only on an engine-rooted query (`XmlQuery.FromContainer` or `XmlQuery.Fluent`). On a
container-rooted query they throw `NotSupportedException`.

```csharp
var engineQuery = XmlQuery.FromContainer<Book>(containerId, queryEngine)
    .Where(b => b.Price < 50m);

var explanation = engineQuery.Explain();
Console.WriteLine($"AST: {explanation?.AstString}");
Console.WriteLine($"Plan: {explanation?.ExecutionPlan}");
Console.WriteLine($"Compiled: {explanation?.CompilationSucceeded}");

if (explanation is { CompilationSucceeded: false })
{
    foreach (var error in explanation.Errors)
    {
        Console.WriteLine($"Error: {error}");
    }
}
```

## Type Mapping

Element content in a stored document is untyped. When a comparison has a node path on one side,
the provider casts that side to the type implied by the C# comparison:

| C# comparand type | XQuery cast |
|-------------------|-------------|
| `decimal` | `xs:decimal` |
| `int`, `long`, `short`, `byte` | `xs:integer` |
| `double`, `float` | `xs:double` |
| `DateTime`, `DateTimeOffset` | `xs:dateTime` |
| `DateOnly` | `xs:date` |
| `bool` | `xs:boolean` |
| `string` | no cast; compared as the node's string value |

Nullable types use their underlying type. A `bool` property used on its own (for example
`Where(b => b.InStock)`) is read as `xs:boolean(string(path))`, so `<instock>false</instock>`
tests false.

## String Functions

String methods are translated to XQuery functions:

```csharp
var query = books.AsQueryable<Book>();

// Contains
query.Where(b => b.Title.Contains("Guide"));

// StartsWith
query.Where(b => b.Author.StartsWith("J"));

// EndsWith
query.Where(b => b.Title.EndsWith("Edition"));

// ToLower/ToUpper (and the Invariant forms)
query.Select(b => b.Title.ToLower());

// Substring
query.Select(b => b.Title.Substring(0, 10));

// Trim
query.Select(b => b.Title.Trim());
```

`Replace`, `Split`, `IndexOf` and the `Length` property are also translated, as are
`Math.Abs`, `Math.Floor`, `Math.Ceiling`, `Math.Round`, `Math.Pow`, and the `Year`, `Month`,
`Day`, `Hour`, `Minute` and `Second` components of `DateTime`.

## JSON Results

Rows can come back as JSON instead of CLR objects:

```csharp
List<string> rows = await books.AsQueryable<Book>()
    .Where(b => b.Genre == "Fiction")
    .ToJsonListAsync();            // one JSON object per row

string document = await books.AsQueryable<Book>()
    .ToJsonAsync(indented: true);  // the whole result set as one JSON array
```

The conversion reads the stored markup, not the materialized `Book`, so elements and attributes
the class does not declare are kept. Attributes and child elements both become properties,
repeated sibling elements become an array, and leaf text becomes a JSON number or boolean only
when that round-trips exactly (`<price>10</price>` becomes `10`; `"0123"` stays a string).

## Best Practices

### 1. Prefer the container-rooted entry point

```csharp
var query = books.AsQueryable<Book>();
```

It runs through `IContainer.QueryAsync`, the same path as hand-written XQuery. Use
`XmlQuery.FromContainer` when you need `Explain` or `Compile`.

### 2. Use Async Operations

```csharp
// Preferred: Async execution
var results = await query.ToListAsync();

// Avoid: synchronous enumeration blocks on the async query
var blocking = query.ToList();
```

### 3. Use Pagination

```csharp
// Good: Take/Skip become subsequence() in the query
var page = await query.Skip(100).Take(10).ToListAsync();

// Avoid: loading everything and paging in memory
var all = await query.ToListAsync();
var inMemoryPage = all.Skip(100).Take(10);
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

## Execution

1. **Deferred execution** — a query runs when it is enumerated or a terminal such as
   `ToListAsync` is awaited, not when it is built.
2. **Same query path** — a container-rooted LINQ query is executed by `IContainer.QueryAsync`,
   exactly like the equivalent hand-written XQuery.
