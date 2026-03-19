---
title: Higher-Order Functions
description: XPath functions that take functions — map, filter, fold, and more
sort: 10
---

# Higher-Order Functions

Higher-order functions accept other functions as arguments. If you've used LINQ's `Select`, `Where`, `Aggregate`, and `OrderBy`, these are the XPath equivalents.

XPath 3.1 introduced inline function expressions (lambdas), making these practical:

```xpath
function($x) { $x * 2 }         (: anonymous function :)
```

This is the XPath equivalent of C#'s `x => x * 2`.

---

## Mapping and Filtering

### for-each()

Applies a function to each item in a sequence, returning the results. This is LINQ's `Select`.

**Signature:** `for-each($seq as item()*, $fn as function(item()) as item()*) as item()*`

```xpath
for-each((1, 2, 3), function($n) { $n * 2 })
=> (2, 4, 6)

for-each(//book/title, function($t) { upper-case($t) })
=> ("EFFECTIVE C#", "XML IN A NUTSHELL")
```

**C# equivalent:** `items.Select(n => n * 2)`

---

### filter()

Keeps items where the predicate function returns true. This is LINQ's `Where`.

**Signature:** `filter($seq as item()*, $fn as function(item()) as xs:boolean) as item()*`

```xpath
filter(1 to 10, function($n) { $n mod 2 = 0 })
=> (2, 4, 6, 8, 10)

filter(//book, function($b) { $b/price > 30 })
=> books over $30
```

**C# equivalent:** `items.Where(n => n % 2 == 0)`

---

### for-each-pair()

Applies a function to pairs of items from two sequences. This is LINQ's `Zip`.

**Signature:** `for-each-pair($seq1 as item()*, $seq2 as item()*, $fn as function(item(), item()) as item()*) as item()*`

```xpath
for-each-pair(
  (1, 2, 3),
  (10, 20, 30),
  function($a, $b) { $a + $b }
)
=> (11, 22, 33)

for-each-pair(
  //item/name,
  //item/price,
  function($n, $p) { $n || ": $" || $p }
)
=> ("Widget: $9.99", "Gadget: $24.50")
```

**C# equivalent:** `a.Zip(b, (x, y) => x + y)`

---

## Folding (Reducing)

### fold-left()

Reduces a sequence to a single value by applying a function from left to right. This is LINQ's `Aggregate`.

**Signature:** `fold-left($seq as item()*, $initial as item()*, $fn as function(item()*, item()) as item()*) as item()*`

```xpath
(: Sum :)
fold-left((1, 2, 3, 4), 0, function($acc, $n) { $acc + $n })
=> 10

(: String concatenation :)
fold-left(("a", "b", "c"), "", function($acc, $s) { $acc || $s })
=> "abc"

(: Build a comma-separated list :)
fold-left(//name, "",
  function($acc, $n) {
    if ($acc = "") then string($n)
    else $acc || ", " || string($n)
  })
=> "Alice, Bob, Charlie"
```

**C# equivalent:** `items.Aggregate(0, (acc, n) => acc + n)`

---

### fold-right()

Same as `fold-left`, but processes from right to left.

```xpath
fold-right(("a", "b", "c"), "", function($s, $acc) { $s || $acc })
=> "abc"
```

**When to use:** `fold-left` is more common. `fold-right` matters when the operation is not associative and order matters (e.g., building nested structures).

---

## Quantifiers

### some()

Tests whether at least one item satisfies a predicate. This is LINQ's `Any`.

**Signature:** `some($seq as item()*, $fn as function(item()) as xs:boolean) as xs:boolean`

```xpath
some((1, 2, 3), function($n) { $n > 2 })   => true
some((1, 2, 3), function($n) { $n > 5 })   => false
some(//book, function($b) { $b/price > 100 }) => true if any book costs over $100
```

**C# equivalent:** `items.Any(n => n > 2)`

**Note:** XPath also supports `some $x in (1, 2, 3) satisfies $x > 2` as an expression — the function form is more composable.

---

### every()

Tests whether all items satisfy a predicate. This is LINQ's `All`.

**Signature:** `every($seq as item()*, $fn as function(item()) as xs:boolean) as xs:boolean`

```xpath
every((2, 4, 6), function($n) { $n mod 2 = 0 })   => true
every((2, 3, 6), function($n) { $n mod 2 = 0 })   => false
```

**C# equivalent:** `items.All(n => n % 2 == 0)`

---

## Selection

### highest()

Returns items with the highest key value. New in XPath 4.0.

**Signature:** `highest($seq as item()*, $key as function(item()) as xs:anyAtomicType?) as item()*`

```xpath
highest(//book, function($b) { $b/price })
=> the most expensive book(s)
```

**C# equivalent:** `books.OrderByDescending(b => b.Price).First()` — but `highest()` returns all items tied for the maximum.

---

### lowest()

Returns items with the lowest key value. New in XPath 4.0.

```xpath
lowest(//book, function($b) { $b/price })
=> the cheapest book(s)
```

---

## Introspection

### function-name()

Returns the name of a named function.

```xpath
function-name(abs#1)   => fn:abs
```

---

### function-arity()

Returns the number of parameters a function accepts.

```xpath
function-arity(concat#3)   => 3
function-arity(abs#1)       => 1
```

---

### function-lookup()

Looks up a function by name and arity at runtime.

**Signature:** `function-lookup($name as xs:QName, $arity as xs:integer) as function(*)?`

```xpath
let $fn := function-lookup(xs:QName("fn:abs"), 1)
return $fn(-5)
=> 5
```

**C# equivalent:** Reflection — `typeof(Math).GetMethod("Abs", new[] { typeof(int) })`

---

### apply()

Calls a function with an array of arguments.

**Signature:** `apply($fn as function(*), $args as array(*)) as item()*`

```xpath
apply(concat#3, ["a", "b", "c"])   => "abc"
```

**C# equivalent:** `method.Invoke(null, args)`
