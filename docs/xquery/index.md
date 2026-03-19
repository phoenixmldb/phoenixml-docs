---
title: XQuery
description: Query and construct XML with XQuery — SQL for hierarchical data
sort: 4
---

# XQuery

XQuery is a full programming language for querying and constructing XML. Where XPath selects nodes from a document, XQuery can build entirely new documents from multiple sources — think of it as SQL for hierarchical data.

If XPath is `SELECT column FROM table WHERE condition`, XQuery is the full SQL with `JOIN`, subqueries, and `INSERT INTO`.

## What's Here

- **[FLWOR Expressions](flwor.md)** — The core of XQuery: For, Let, Where, Order by, Return. Like LINQ query syntax but for XML.
- **[Advanced FLWOR](flwor-advanced.md)** — Window clauses, count, group by, while, otherwise — advanced FLWOR patterns.
- **[Constructors](constructors.md)** — Building new XML elements, attributes, and documents from query results.
- **[Conditionals and Error Handling](conditionals.md)** — if/then/else, switch, typeswitch, try/catch, and the otherwise operator.
- **[Operators](operators.md)** — Comparison, arithmetic, sequence, and navigation operators.
- **[Type System](types.md)** — XQuery types, sequence types, records, enums, union types, and type testing.
- **[Update Facility](update-facility.md)** — XQuery Update — insert, delete, replace, rename, and transform expressions.
- **[Functions and Modules](functions-modules.md)** — Writing reusable XQuery functions and organizing code into modules.
- **[XQuery vs XSLT](xquery-vs-xslt.md)** — When to use which. They overlap significantly — here's how to choose.
- **[Full-Text Search](full-text.md)** — Linguistic search with stemming, wildcards, proximity, and scoring.
- **[Prolog and Declarations](prolog.md)** — Module declarations, namespace imports, options, and configuration.
- **[Extensibility](extensibility.md)** — Custom functions, modules, external functions, and .NET integration.

## The LINQ Parallel

XQuery's FLWOR expression maps almost directly to LINQ query syntax:

**XQuery:**
```xquery
for $book in /catalog/book
where $book/price > 30
order by $book/title
return <result>{ $book/title, $book/price }</result>
```

**LINQ:**
```csharp
from book in catalog.Elements("book")
where (decimal)book.Element("price") > 30
orderby (string)book.Element("title")
select new XElement("result", book.Element("title"), book.Element("price"))
```

The XQuery version is more concise, handles namespaces natively, and runs on any XQuery processor — not just .NET.
