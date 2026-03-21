---
title: Operators
description: XQuery comparison, arithmetic, sequence, and navigation operators
sort: 5
---

# Operators

XQuery inherits most of its operators from XPath and adds several of its own. This page covers all the operators you'll use in XQuery, with particular attention to the ones that have no C# equivalent.

## Contents

- [Arithmetic Operators](#arithmetic-operators)
- [Comparison Operators](#comparison-operators)
- [Node Comparison](#node-comparison)
- [Logical Operators](#logical-operators)
- [Sequence Operators](#sequence-operators)
- [Range Operator](#range-operator)
- [String Concatenation](#string-concatenation)
- [Simple Map Operator](#simple-map-operator)
- [Arrow Operators](#arrow-operators)
- [Lookup Operator](#lookup-operator)
- [Otherwise Operator](#otherwise-operator)
- [Operator Precedence](#operator-precedence)

---

## Arithmetic Operators

XQuery uses the same arithmetic operators as XPath:

| Operator | Meaning | Example | Result |
|----------|---------|---------|--------|
| `+` | Addition | `5 + 3` | `8` |
| `-` | Subtraction | `5 - 3` | `2` |
| `*` | Multiplication | `5 * 3` | `15` |
| `div` | Decimal division | `7 div 2` | `3.5` |
| `idiv` | Integer division | `7 idiv 2` | `3` |
| `mod` | Modulo (remainder) | `7 mod 2` | `1` |
| `-` (unary) | Negation | `-$x` | negated value |

**C# parallel:** `+`, `-`, `*`, `/` (integer or decimal depending on operands), `%`

Note: XQuery uses `div` instead of `/` for division because `/` is already the path separator. This catches every C# developer at least once.

```xquery
(: Tax calculation :)
let $subtotal := 149.99
let $tax-rate := 0.08
let $tax := round($subtotal * $tax-rate, 2)
let $total := $subtotal + $tax
return map {
  "subtotal": $subtotal,
  "tax": $tax,
  "total": $total
}
```

### Type Rules

Arithmetic follows XQuery's type promotion rules:

- `integer + integer` produces `integer`
- `integer + decimal` produces `decimal`
- `decimal + double` produces `double`
- Any arithmetic with `double` produces `double`

```xquery
5 + 3          (: xs:integer  → 8 :)
5 + 3.0        (: xs:decimal  → 8.0 :)
5 + 3.0e0      (: xs:double   → 8.0E0 :)
```

---

## Comparison Operators

XQuery has two sets of comparison operators, and understanding the difference is critical.

### General Comparison

General comparison operators compare sequences. If **any** item in the left sequence matches **any** item in the right sequence, the result is true.

| Operator | Meaning |
|----------|---------|
| `=` | Equal (existential) |
| `!=` | Not equal (existential) |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

```xquery
(: Returns true if ANY tag equals "sale" :)
$product/tag = "sale"

(: This is often what you want in XQuery — it checks all child elements :)
//book[author = "Knuth"]
```

**Warning:** `!=` does not mean "no item equals." It means "at least one item does not equal":

```xquery
let $tags := ("red", "blue", "green")
return $tags != "red"
(: true! Because "blue" != "red" and "green" != "red" :)
```

### Value Comparison

Value comparison operators compare single values. They raise an error if either side is a sequence of more than one item.

| Operator | Meaning |
|----------|---------|
| `eq` | Equal |
| `ne` | Not equal |
| `lt` | Less than |
| `gt` | Greater than |
| `le` | Less than or equal |
| `ge` | Greater than or equal |

```xquery
(: Strict single-value comparison :)
$order/@status eq "shipped"
count($items) gt 10
$price le 99.99
```

**When to use which:**

| Scenario | Use |
|----------|-----|
| Comparing an attribute/element to a value | General `=` (handles empty gracefully) |
| Comparing two known single values | Value `eq` (catches bugs with multi-value sequences) |
| Inside a `where` clause with computed values | Value `eq` (more precise) |
| XPath predicates on child elements | General `=` (existential match across children) |

**C# parallel:** C# has only one set: `==`, `!=`, `<`, `>`, `<=`, `>=`. The general/value distinction is unique to XQuery/XPath.

---

## Node Comparison

These operators compare XML nodes by identity or document position. They have no direct C# equivalent.

| Operator | Meaning | Example |
|----------|---------|---------|
| `is` | Same node identity | `$a is $b` |
| `<<` | Before in document order | `$a << $b` |
| `>>` | After in document order | `$a >> $b` |

### Node Identity (`is`)

Two node references point to the **same** node (not just equal content):

```xquery
let $first := (//product)[1]
let $same := (//product)[1]
let $different := (//product)[2]

return (
  $first is $same,      (: true — same node :)
  $first is $different   (: false — different node :)
)
```

This is like C#'s `Object.ReferenceEquals`:
```csharp
Object.ReferenceEquals(firstNode, sameNode)  // true
Object.ReferenceEquals(firstNode, differentNode)  // false
```

### Document Order (`<<` and `>>`)

Tests whether one node appears before or after another in the document:

```xquery
let $intro := //chapter[@id = "intro"]
let $conclusion := //chapter[@id = "conclusion"]
return $intro << $conclusion
(: true if intro comes before conclusion in the document :)
```

**Practical use:** Ensuring correct ordering in cross-references:

```xquery
for $ref in //cross-ref
let $target := //*[@id = $ref/@target]
return <ref forward="{ $ref >> $target }">
  { $ref/@target/string() }
</ref>
```

---

## Logical Operators

| Operator | Meaning | C# Equivalent |
|----------|---------|---------------|
| `and` | Logical AND | `&&` |
| `or` | Logical OR | `\|\|` |
| `not(...)` | Logical NOT (function) | `!` |

```xquery
for $product in //product
where $product/price > 10 and $product/price < 100
  and ($product/@category = "electronics" or $product/@category = "tools")
  and not($product/@discontinued = "true")
return $product/name
```

Note: `not` is a function, not an operator. You write `not($expr)`, not `not $expr`.

---

## Sequence Operators

These operators work on sequences of nodes, performing set operations. They always return results in document order with duplicates removed.

| Operator | Meaning | C# Parallel |
|----------|---------|-------------|
| `union` or `\|` | All nodes from both sequences | `Union()` |
| `intersect` | Nodes in both sequences | `Intersect()` |
| `except` | Nodes in first but not second | `Except()` |

```xquery
(: All products that are either featured OR on sale :)
//product[@featured = "true"] union //product[@on-sale = "true"]

(: Products that are both featured AND on sale :)
//product[@featured = "true"] intersect //product[@on-sale = "true"]

(: Featured products that are NOT discontinued :)
//product[@featured = "true"] except //product[@discontinued = "true"]
```

### Practical Example: Navigation Menu

```xquery
(: Show all pages, but highlight the ones in the current section :)
let $all-pages := //sitemap/page
let $current-section := //sitemap/section[@id = $current-section-id]/page
let $other-pages := $all-pages except $current-section

return <nav>
  <h3>Current Section</h3>
  <ul>{ for $p in $current-section return <li class="current">{ $p/@title/string() }</li> }</ul>
  <h3>Other Pages</h3>
  <ul>{ for $p in $other-pages return <li>{ $p/@title/string() }</li> }</ul>
</nav>
```

**Important:** These operators work on **nodes**, not atomic values. For set operations on atomic values, use `distinct-values()` and sequence comparisons.

---

## Range Operator

The `to` operator generates a sequence of consecutive integers:

```xquery
1 to 5           (: (1, 2, 3, 4, 5) :)
3 to 7           (: (3, 4, 5, 6, 7) :)
$start to $end   (: dynamic range :)
```

**C# parallel:** `Enumerable.Range(start, count)`:
```csharp
Enumerable.Range(1, 5)  // {1, 2, 3, 4, 5}
```

### Common Uses

**Pagination:**

```xquery
let $page := 2
let $size := 10
let $positions := (($page - 1) * $size + 1) to ($page * $size)

for $product at $pos in //products/product
where $pos = $positions
return $product
```

**Generating repeated structures:**

```xquery
<table>{
  for $row in 1 to 10
  return <tr>{
    for $col in 1 to 5
    return <td>R{ $row }C{ $col }</td>
  }</tr>
}</table>
```

**Reverse range:** If `start > end`, the result is empty:

```xquery
5 to 1   (: empty sequence :)

(: To count down, use reverse() :)
reverse(1 to 5)  (: (5, 4, 3, 2, 1) :)
```

---

## String Concatenation

*XQuery 3.1+*

The `||` operator concatenates strings:

```xquery
"Hello" || " " || "World"     (: "Hello World" :)
$first-name || " " || $last-name
"Item #" || $position || ": " || $name
```

**C# parallel:** `+` or string interpolation:
```csharp
firstName + " " + lastName
$"Item #{position}: {name}"
```

Before 3.1, you had to use `concat()`:

```xquery
concat("Hello", " ", "World")
concat($first-name, " ", $last-name)
```

The `||` operator atomizes its operands and converts them to strings automatically. This means you can concatenate non-string values without explicit casting:

```xquery
"Price: $" || $product/price || " (qty: " || $item/@qty || ")"
(: Works even though price and qty might be untyped :)
```

---

## Simple Map Operator

*XQuery 3.1+*

The `!` operator applies an expression to each item in a sequence. It's XQuery's version of `Select()` / `map()`:

```xquery
(1, 2, 3, 4, 5) ! (. * 2)
(: Result: (2, 4, 6, 8, 10) :)
```

Inside the right-hand expression, `.` (the context item) refers to the current item.

**C# parallel:** `Select()`:
```csharp
new[] { 1, 2, 3, 4, 5 }.Select(x => x * 2)
```

### Practical Uses

**Transform values:**

```xquery
//product/name ! upper-case(.)
(: All product names in uppercase :)

//order/total ! format-number(., "#,##0.00")
(: All order totals formatted :)
```

**Extract and transform:**

```xquery
//employee ! map {
  "name": ./name/string(),
  "department": ./@dept/string(),
  "salary": xs:decimal(./salary)
}
```

**Chaining:**

```xquery
(1 to 10) ! (. * .) ! (. + 1)
(: Squares each number, then adds 1: (2, 5, 10, 17, 26, 37, 50, 65, 82, 101) :)
```

### Map Operator vs Path Expressions

The `!` operator is similar to `/` but more general:

```xquery
$doc/catalog/product/name    (: navigates child axes — nodes only :)
$doc/catalog/product/name ! upper-case(.)  (: applies a function to each result :)

(: ! works with any expression, not just axis steps :)
("hello", "world") ! string-length(.)   (: (5, 5) :)
```

---

## Arrow Operators

### Fat Arrow (`=>`)

*XQuery 3.1+*

The `=>` operator pipes a value into a function as its first argument. It enables left-to-right chaining instead of nested function calls:

```xquery
(: Without arrow — nested, read inside-out :)
upper-case(normalize-space(substring($text, 1, 50)))

(: With arrow — left-to-right pipeline :)
$text => substring(1, 50) => normalize-space() => upper-case()
```

**C# parallel:** LINQ method chaining or the pipe proposal:
```csharp
text.Substring(0, 50).Trim().ToUpper()
```

The left-hand value becomes the **first** argument of the function. Additional arguments follow:

```xquery
"hello world" => substring(1, 5)
(: equivalent to: substring("hello world", 1, 5) :)
(: Result: "hello" :)
```

### Practical Example: Data Cleaning Pipeline

```xquery
declare function local:clean-text($text as xs:string) as xs:string {
  $text
    => normalize-space()
    => replace("&amp;", "and")
    => replace("\s+", " ")
    => lower-case()
};
```

### Thin Arrow (`->`)

*XQuery 4.0*

The `->` (thin arrow) operator is similar to `=>` but calls the function as a **method on the item**. The key difference: `->` passes the left-hand side as the context item (`.`), while `=>` passes it as the first argument.

```xquery
(: Thin arrow — treats function as a method :)
"  Hello World  " -> normalize-space() -> upper-case()

(: Works with user-defined functions :)
$order -> local:calculate-total() -> local:apply-discount(0.1)
```

The thin arrow is especially useful for chaining operations on maps and arrays:

```xquery
let $data := map { "name": "Alice", "scores": [85, 92, 78] }
return $data -> map:get("scores") -> array:size()
(: Result: 3 :)
```

---

## Lookup Operator

*XQuery 3.1+*

The `?` operator accesses values in maps and arrays. It replaces verbose function calls with concise syntax.

### Map Lookup

```xquery
let $config := map {
  "host": "localhost",
  "port": 8080,
  "debug": true()
}

return (
  $config?host,       (: "localhost" :)
  $config?port,       (: 8080 :)
  $config?debug       (: true :)
)
```

**C# parallel:** Dictionary or object property access:
```csharp
config["host"]    // Dictionary
config.Host       // Object property
```

### Array Lookup

Arrays use 1-based integer positions:

```xquery
let $colors := ["red", "green", "blue"]
return (
  $colors?1,       (: "red" :)
  $colors?2,       (: "green" :)
  $colors?3        (: "blue" :)
)
```

**C# parallel:** `colors[0]`, `colors[1]`, `colors[2]` (note: C# is 0-based, XQuery is 1-based).

### Wildcard Lookup (`?*`)

Returns all values from a map or all items from an array:

```xquery
let $prices := map { "widget": 9.99, "gadget": 29.99, "tool": 14.50 }
return sum($prices?*)
(: Result: 54.48 — sum of all values :)

let $matrix := [[1, 2], [3, 4], [5, 6]]
return $matrix?*
(: Result: [1, 2], [3, 4], [5, 6] — all arrays from the outer array :)
```

### Chained Lookups

Navigate nested structures:

```xquery
let $data := map {
  "users": [
    map { "name": "Alice", "role": "admin" },
    map { "name": "Bob", "role": "editor" }
  ]
}

return (
  $data?users,          (: the array of user maps :)
  $data?users?1,        (: map { "name": "Alice", "role": "admin" } :)
  $data?users?1?name,   (: "Alice" :)
  $data?users?*?name    (: ("Alice", "Bob") — all names :)
)
```

### Variable Key Lookup

Use parentheses for dynamic keys:

```xquery
let $field := "name"
return $user?($field)
(: Same as $user?name when $field = "name" :)
```

---

## Otherwise Operator

*XQuery 4.0*

The `otherwise` operator returns the right-hand side when the left-hand side is the empty sequence:

```xquery
$user/email otherwise "no-email@example.com"
```

This is covered in detail on the [Conditionals and Error Handling](conditionals.md#otherwise-operator) page. Here it is listed for completeness in the operator reference.

**C# parallel:** `??` (null-coalescing):
```csharp
user.Email ?? "no-email@example.com"
```

---

## Operator Precedence

From highest (binds tightest) to lowest:

| Precedence | Operators | Description |
|------------|-----------|-------------|
| 1 | `?` | Lookup |
| 2 | `/`, `//` | Path steps |
| 3 | `!` | Simple map |
| 4 | `[]` | Predicate |
| 5 | Unary `-`, `+` | Unary arithmetic |
| 6 | `cast as`, `castable as` | Type casting |
| 7 | `treat as` | Type assertion |
| 8 | `instance of` | Type testing |
| 9 | `intersect`, `except` | Sequence intersection/difference |
| 10 | `union`, `\|` | Sequence union |
| 11 | `=>`, `->` | Arrow operators |
| 12 | `*`, `div`, `idiv`, `mod` | Multiplicative |
| 13 | `+`, `-` | Additive |
| 14 | `\|\|` | String concatenation |
| 15 | `to` | Range |
| 16 | `otherwise` | Fallback |
| 17 | `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `=`, `!=`, `<`, `<=`, `>`, `>=`, `is`, `<<`, `>>` | Comparison |
| 18 | `and` | Logical AND |
| 19 | `or` | Logical OR |

When in doubt, use parentheses. They cost nothing and prevent subtle bugs:

```xquery
(: Ambiguous — does 'otherwise' or 'gt' bind tighter? :)
$count otherwise 0 gt 5

(: Clear :)
($count otherwise 0) gt 5
```
