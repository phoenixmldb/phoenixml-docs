---
title: Functions
description: Comprehensive reference for XPath 4.0's 240+ built-in functions
sort: 2
---

# XPath Functions

XPath 4.0 provides over 240 built-in functions organized across several namespaces. These functions are available everywhere XPath is used — in standalone expressions, inside XSLT stylesheets, and within XQuery programs.

## How to Read This Reference

Each function is documented with:

- **Signature** — the function name, parameters, and return type
- **Description** — what the function does
- **Examples** — XPath expressions with expected results, using realistic XML when relevant
- **C# equivalent** — the closest .NET equivalent, so you can map to what you already know
- **Notes** — edge cases, version history (XPath 3.1 vs 4.0), and common pitfalls

Functions are in the `fn:` namespace by default — you don't need to prefix them. The `math:`, `map:`, and `array:` namespaces require prefixes.

## Function Categories

| Category | Count | Description |
|----------|-------|-------------|
| [String](string.md) | ~40 | Text manipulation, searching, regex, Unicode |
| [Numeric](numeric.md) | ~15 | Arithmetic, rounding, aggregation |
| [Date and Time](date-time.md) | ~28 | Date/time construction, extraction, formatting, timezone handling |
| [Sequence](sequence.md) | ~50 | Collection operations — filtering, ordering, set operations, scanning |
| [Boolean](boolean.md) | 4 | Boolean construction and logic |
| [Node](node.md) | ~20 | Node properties, names, namespaces, document access |
| [Map](map.md) | ~20 | Key-value map operations (XPath 3.1+) |
| [Array](array.md) | ~31 | Ordered array operations (XPath 3.1+) |
| [Math](math.md) | ~15 | Trigonometry, logarithms, exponents |
| [Higher-Order](higher-order.md) | ~15 | Functions that take functions — map, filter, fold, sort |
| [Formatting](formatting.md) | ~10 | Number, date, and serialization formatting |
| [Type Constructors](type-constructors.md) | ~30 | Casting between XSD types |

## A Note on Extensibility

XPath's function library is fixed — you cannot define custom functions in XPath alone. This is by design: XPath is a query language embedded in host languages that provide extensibility.

- In **XSLT**, use `xsl:function` to define custom functions callable from any XPath expression in your stylesheet
- In **XQuery**, use `declare function` to define functions callable from XPath expressions within your queries
- In **.NET**, the PhoenixmlDb engine supports registering extension functions from C# code

See the [XSLT](/xslt/index.md) and [XQuery](/xquery/index.md) sections for details on writing custom functions. The built-in functions documented here are available in all three contexts.

## Quick Examples

Before diving into categories, here are some common tasks and the functions that solve them:

```xpath
(: String manipulation :)
upper-case("hello")                           => "HELLO"
replace("2026-03-19", "-", "/")               => "2026/03/19"
tokenize("a,b,c", ",")                        => ("a", "b", "c")

(: Numeric :)
sum(//item/price)                              => total of all prices
round(3.14159, 2)                             => 3.14
format-integer(1234567, "#,###")              => "1,234,567"

(: Date/time :)
current-date()                                => 2026-03-19
year-from-date(xs:date("2026-03-19"))         => 2026
format-date(current-date(), "[MNn] [D], [Y]") => "March 19, 2026"

(: Sequences :)
distinct-values(("a", "b", "a", "c"))         => ("a", "b", "c")
sort(("banana", "apple", "cherry"))           => ("apple", "banana", "cherry")
filter(1 to 10, function($n) { $n mod 2 = 0 }) => (2, 4, 6, 8, 10)

(: Maps — like Dictionary<string, object> :)
map { "name": "Alice", "age": 30 }?name       => "Alice"
map:keys(map { "a": 1, "b": 2 })              => ("a", "b")

(: Arrays — like List<object> :)
[1, 2, 3]?2                                   => 2
array:join(([1, 2], [3, 4]))                  => [1, 2, 3, 4]
```
