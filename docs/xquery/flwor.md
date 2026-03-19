---
title: FLWOR Expressions
description: XQuery's For-Let-Where-Order-Return expressions — LINQ query syntax for XML
sort: 1
---

# FLWOR Expressions

FLWOR (pronounced "flower") is XQuery's core construct. It stands for **F**or, **L**et, **W**here, **O**rder by, **R**eturn — and maps almost directly to LINQ query syntax.

If you've written LINQ queries in C#, FLWOR will feel immediately familiar:

| LINQ | FLWOR |
|------|-------|
| `from` | `for` |
| `let` | `let` |
| `where` | `where` |
| `orderby` | `order by` |
| `select` | `return` |

## Basic Structure

```xquery
for $variable in expression
let $computed := expression
where condition
order by expression
return result-expression
```

All clauses except `return` are optional. The simplest FLWOR is just `for ... return`:

```xquery
for $x in (1, 2, 3)
return $x * 2
(: Result: 2, 4, 6 :)
```

## For Clause

Iterates over a sequence, binding each item to a variable:

```xquery
for $book in //catalog/book
return $book/title

(: LINQ equivalent: from book in catalog.Elements("book") select book.Element("title") :)
```

### Positional Variable

Track the position with `at`:

```xquery
for $book at $pos in //catalog/book
return concat($pos, ". ", $book/title)
(: Result: "1. Effective C#", "2. XML in a Nutshell" :)
```

**C# equivalent:** `books.Select((book, index) => $"{index + 1}. {book.Title}")`

### Multiple For Clauses

Like nested loops — produces a cross product:

```xquery
for $color in ("red", "blue")
for $size in ("S", "M", "L")
return concat($color, "-", $size)
(: Result: "red-S", "red-M", "red-L", "blue-S", "blue-M", "blue-L" :)
```

**C# equivalent:**
```csharp
from color in new[] { "red", "blue" }
from size in new[] { "S", "M", "L" }
select $"{color}-{size}"
```

## Let Clause

Binds a computed value to a variable. Unlike `for`, it doesn't iterate:

```xquery
for $book in //catalog/book
let $discount := $book/price * 0.1
let $sale-price := $book/price - $discount
return <sale>
  <title>{ $book/title/text() }</title>
  <original>{ $book/price/text() }</original>
  <discounted>{ $sale-price }</discounted>
</sale>
```

**C# equivalent:**
```csharp
from book in books
let discount = book.Price * 0.1m
let salePrice = book.Price - discount
select new { book.Title, Original = book.Price, Discounted = salePrice }
```

`let` is essential for avoiding repeated computation. Without it, you'd have to write the same expression multiple times.

## Where Clause

Filters items based on a condition:

```xquery
for $book in //catalog/book
where $book/price > 30
return $book/title
```

**C# equivalent:** `from book in books where book.Price > 30 select book.Title`

### Multiple Conditions

Use `and` / `or`:

```xquery
for $book in //catalog/book
where $book/price > 20 and $book/price < 50
where $book/@category = "programming"
return $book/title
```

Multiple `where` clauses are equivalent to combining with `and`.

## Order By Clause

Sorts results:

```xquery
for $book in //catalog/book
order by $book/price descending
return <item>{ $book/title/text() } — ${ $book/price/text() }</item>
```

**C# equivalent:** `from book in books orderby book.Price descending select ...`

### Multiple Sort Keys

```xquery
for $book in //catalog/book
order by $book/@category ascending, $book/price descending
return $book/title
```

### Collation

For locale-aware string sorting:

```xquery
for $name in //customer/name
order by $name collation "http://www.w3.org/2013/collation/UCA"
return $name
```

## Return Clause

Specifies the output for each iteration. Can return:

### Atomic Values

```xquery
for $book in //catalog/book
return string($book/title)
(: Returns a sequence of strings :)
```

### Constructed XML

```xquery
for $book in //catalog/book
return <li class="book">{ $book/title/text() }</li>
(: Returns a sequence of <li> elements :)
```

### Complex Structures

```xquery
for $category in distinct-values(//book/@category)
return <section>
  <h2>{ $category }</h2>
  <ul>{
    for $book in //book[@category = $category]
    order by $book/title
    return <li>{ $book/title/text() }</li>
  }</ul>
</section>
```

**C# equivalent:**
```csharp
from category in books.Select(b => b.Category).Distinct()
select new {
    Heading = category,
    Books = from book in books
            where book.Category == category
            orderby book.Title
            select book.Title
}
```

## XQuery 4.0 Additions

### Otherwise Clause

Provides a default value when the FLWOR produces an empty result:

```xquery
for $book in //catalog/book
where $book/price > 1000
return $book/title
otherwise <no-results>No books found over $1000</no-results>
```

**C# equivalent:** `result.DefaultIfEmpty(fallback)`

### Window Clause

Processes items in windows (groups of consecutive items):

```xquery
for tumbling window $w in (1, 2, 3, 4, 5, 6, 7, 8)
    start at $s when true()
    end at $e when $e - $s = 2
return <group>{ $w }</group>
(: Result: <group>1 2 3</group>, <group>4 5 6</group>, <group>7 8</group> :)
```

### Count Clause

Adds a counter variable:

```xquery
for $book in //catalog/book
count $n
return <item number="{ $n }">{ $book/title/text() }</item>
```

Similar to `at` in the `for` clause, but counts across all loop iterations including after `where` filtering.

### Group By Clause

Groups items by a key:

```xquery
for $book in //catalog/book
group by $cat := $book/@category
return <category name="{ $cat }">
  { for $b in $book return <title>{ $b/title/text() }</title> }
</category>
```

**C# equivalent:** `from book in books group book by book.Category into g select new { g.Key, Books = g }`

## Putting It All Together

A real-world example — generating an order summary from XML:

```xquery
let $orders := doc("orders.xml")//order
let $products := doc("products.xml")//product

for $order in $orders
let $items := for $item in $order/line-item
              let $product := $products[@id = $item/@product-id]
              return map {
                "name": string($product/name),
                "qty": xs:integer($item/@qty),
                "unit-price": xs:decimal($product/price),
                "total": xs:integer($item/@qty) * xs:decimal($product/price)
              }
let $order-total := sum($items ! .?total)
where $order-total > 100
order by $order-total descending
return <order-summary id="{ $order/@id }">
  <total>{ $order-total }</total>
  <item-count>{ count($items) }</item-count>
  <items>{
    for $item in $items
    order by $item?total descending
    return <item name="{ $item?name }" total="{ $item?total }"/>
  }</items>
</order-summary>
```

This query:
1. Joins two documents (orders and products)
2. Computes line item totals
3. Filters orders over $100
4. Sorts by total descending
5. Constructs a summary XML document

The equivalent C# code would be significantly more verbose, especially the cross-document join and XML construction.
