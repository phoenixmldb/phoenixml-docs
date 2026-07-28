---
title: XPath
description: XPath query language for XML — the LINQ of the XML world
sort: 2
---

# XPath

XPath is a query language for selecting nodes in XML documents. The XML world has used XPath to query document trees since 1999.

> For .NET developers: XPath resembles LINQ for XML. Both let a developer query a tree of data with a compact, declarative syntax.

XPath is not a standalone tool. XSLT uses XPath for matching and selecting nodes. XQuery uses XPath as its navigation syntax. XPath is also available directly in .NET through `XPathNavigator` and through PhoenixmlDb.

## What's Here

- **[Path Expressions](path-expressions.md)** — The core of XPath: navigating the document tree with `/`, `//`, predicates, and axes. This is where most of your day-to-day work happens.
- **[Functions](functions/index.md)** — Comprehensive reference for XPath 4.0's 240+ built-in functions, organized by category: string, numeric, date/time, sequence, map, array, math, higher-order, and more.
- **[Operators and Comparisons](operators.md)** — Arithmetic, comparison, logical operators, and the difference between value and general comparisons.
- **[Data Types](data-types.md)** — How XPath's type system works, type casting, and interaction with schema types.

## XPath by Example

Given this XML:

```xml
<catalog>
  <book isbn="978-0-123456-78-9" category="programming">
    <title>Effective C#</title>
    <author>Bill Wagner</author>
    <price currency="USD">39.99</price>
    <published>2017-03-15</published>
  </book>
  <book isbn="978-0-987654-32-1" category="data">
    <title>XML in a Nutshell</title>
    <author>Elliotte Harold</author>
    <price currency="USD">49.99</price>
    <published>2004-09-01</published>
  </book>
</catalog>
```

| Task | XPath | LINQ Equivalent |
|------|-------|-----------------|
| All books | `/catalog/book` | `doc.Root.Elements("book")` |
| Book titles | `/catalog/book/title` | `.Elements("book").Elements("title")` |
| Books over $40 | `/catalog/book[price > 40]` | `.Where(b => (decimal)b.Element("price") > 40)` |
| First book | `/catalog/book[1]` | `.Elements("book").First()` |
| Book by ISBN | `/catalog/book[@isbn='978-0-123456-78-9']` | `.Where(b => b.Attribute("isbn")?.Value == "...")` |
| All prices anywhere | `//price` | `.Descendants("price")` |
| Programming books | `/catalog/book[@category='programming']` | `.Where(b => b.Attribute("category")?.Value == "programming")` |

XPath expressions are more concise than the equivalent LINQ code. XPath also works with any XML tool, not only .NET.
