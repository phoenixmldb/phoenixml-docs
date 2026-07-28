---
title: XQuery
description: Query and construct XML with XQuery — SQL for hierarchical data
sort: 4
---

# XQuery

XQuery is a full programming language for querying and constructing XML. XPath selects nodes from a document. XQuery builds entirely new documents from multiple sources.

> For C# developers: XQuery resembles SQL for hierarchical data. If XPath is `SELECT column FROM table WHERE condition`, XQuery is the full SQL with `JOIN`, subqueries, and `INSERT INTO`.

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

## Key Features

### Direct Element Constructors

XQuery builds XML inline using XML-literal syntax with embedded expressions in curly braces `{}`. The query output looks like the XML it produces:

```xquery
<root>
  <item name="test">{current-dateTime()}</item>
  <nested><child>text</child></nested>
</root>
```

See **[Constructors](constructors.md)** for full details on direct and computed constructors.

### String Constructors

XQuery 3.1+ supports string constructors using backtick syntax for creating strings that contain curly braces or other characters that are awkward to escape:

```xquery
``[This string contains {$variable} interpolation and literal { braces }]``
```

The content between `` ``[ `` and `` ]`` `` is treated as a string template. Expressions inside `{` `}` are evaluated and interpolated. To include a literal curly brace, double it: `{{` or `}}`.

### Annotations

Function and variable declarations can carry annotations that control visibility and behavior:

```xquery
(: Public function — accessible to importers :)
declare %public function local:format($x) { ... };

(: Private function — internal to this module :)
declare %private function local:helper($x) { ... };

(: Annotations can also carry application-specific metadata :)
declare %rest:path("/api/users") %rest:GET
function local:get-users() { ... };
```

Annotations are declared with `%name` or `%name("value")` before the `function` or `variable` keyword. The built-in annotations `%public` and `%private` control visibility in library modules.

## The FLWOR Expression

XQuery's FLWOR expression selects, filters, sorts, and returns data in one pipeline:

```xquery
for $book in /catalog/book
where $book/price > 30
order by $book/title
return <result>{ $book/title, $book/price }</result>
```

The FLWOR version handles namespaces natively and runs on any XQuery processor.

> For C# developers: FLWOR maps almost directly to LINQ query syntax.

```csharp
from book in catalog.Elements("book")
where (decimal)book.Element("price") > 30
orderby (string)book.Element("title")
select new XElement("result", book.Element("title"), book.Element("price"))
```
