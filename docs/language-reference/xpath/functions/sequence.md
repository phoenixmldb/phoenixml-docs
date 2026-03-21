---
title: Sequence Functions
description: XPath sequence operations — filtering, ordering, set operations, scanning
sort: 4
---

# Sequence Functions

Sequences are XPath's fundamental collection type — like `IEnumerable<T>` in .NET. These functions are the XPath equivalent of LINQ methods. If you're comfortable with LINQ, you'll find most of these intuitive.

## Contents

- [Testing and Cardinality](#testing-and-cardinality)
- [Access and Slicing](#access-and-slicing)
- [Ordering](#ordering)
- [Set Operations](#set-operations)
- [Comparison](#comparison)
- [Manipulation](#manipulation)
- [Scanning and Accumulation](#scanning-and-accumulation)

---

## Testing and Cardinality

### empty()

Tests whether a sequence is empty.

**Signature:** `empty($seq as item()*) as xs:boolean`

```xpath
empty(())                => true
empty((1, 2, 3))         => false
empty(//book)            => true if no books exist
```

**C# equivalent:** `!items.Any()`

---

### exists()

Tests whether a sequence is non-empty. The inverse of `empty()`.

**Signature:** `exists($seq as item()*) as xs:boolean`

```xpath
exists((1, 2, 3))        => true
exists(())                => false
exists(//error)           => true if any error elements exist
```

**C# equivalent:** `items.Any()`

---

### count()

Returns the number of items. (Also listed under [Numeric Functions](numeric.md#count).)

```xpath
count(//book)            => number of book elements
count(1 to 100)          => 100
```

---

### zero-or-one()

Asserts that a sequence has at most one item. Throws an error if it has more.

**Signature:** `zero-or-one($seq as item()*) as item()?`

```xpath
zero-or-one(())           => ()
zero-or-one("hello")      => "hello"
zero-or-one((1, 2))       => ERROR: sequence has more than one item
```

**C# equivalent:** `items.SingleOrDefault()`

---

### exactly-one()

Asserts that a sequence has exactly one item.

**Signature:** `exactly-one($seq as item()*) as item()`

```xpath
exactly-one("hello")      => "hello"
exactly-one(())            => ERROR: empty sequence
exactly-one((1, 2))        => ERROR: sequence has more than one item
```

**C# equivalent:** `items.Single()`

---

### one-or-more()

Asserts that a sequence has at least one item.

**Signature:** `one-or-more($seq as item()*) as item()+`

```xpath
one-or-more((1, 2, 3))    => (1, 2, 3)
one-or-more(())            => ERROR: empty sequence
```

**C# equivalent:** Roughly `items.Any() ? items : throw`

---

## Access and Slicing

### head()

Returns the first item of a sequence.

**Signature:** `head($seq as item()*) as item()?`

```xpath
head((1, 2, 3))      => 1
head(())              => ()
head(//book)          => first book element
```

**C# equivalent:** `items.FirstOrDefault()`

---

### tail()

Returns all items except the first.

**Signature:** `tail($seq as item()*) as item()*`

```xpath
tail((1, 2, 3))      => (2, 3)
tail(("a"))           => ()
tail(())              => ()
```

**C# equivalent:** `items.Skip(1)`

---

### foot()

Returns the last item. New in XPath 4.0.

**Signature:** `foot($seq as item()*) as item()?`

```xpath
foot((1, 2, 3))      => 3
foot(())              => ()
```

**C# equivalent:** `items.LastOrDefault()`

---

### trunk()

Returns all items except the last. New in XPath 4.0.

**Signature:** `trunk($seq as item()*) as item()*`

```xpath
trunk((1, 2, 3))     => (1, 2)
trunk(("a"))          => ()
```

**C# equivalent:** `items.SkipLast(1)`

---

### subsequence()

Returns a contiguous slice of the sequence.

**Signature:** `subsequence($seq as item()*, $start as xs:double, $length as xs:double?) as item()*`

```xpath
subsequence((10, 20, 30, 40, 50), 2, 3)   => (20, 30, 40)
subsequence((10, 20, 30, 40, 50), 3)       => (30, 40, 50)
```

**C# equivalent:** `items.Skip(1).Take(3)` — remember XPath is 1-based.

---

### items-at()

Returns items at specified positions. New in XPath 4.0.

**Signature:** `items-at($seq as item()*, $positions as xs:integer*) as item()*`

```xpath
items-at(("a", "b", "c", "d", "e"), (1, 3, 5))   => ("a", "c", "e")
```

**C# equivalent:** `positions.Select(i => items.ElementAt(i - 1))`

---

### slice()

Advanced slicing with start, stop, and step. New in XPath 4.0.

**Signature:** `slice($seq as item()*, $start as xs:integer?, $stop as xs:integer?, $step as xs:integer?) as item()*`

```xpath
slice(1 to 10, 2, 8, 2)   => (2, 4, 6, 8)   (: start=2, stop=8, step=2 :)
slice(1 to 10, (), (), -1) => (10, 9, 8, 7, 6, 5, 4, 3, 2, 1)  (: reverse :)
```

**C# equivalent:** Python-style slicing. No direct C# equivalent — you'd use LINQ `Where` with index math.

---

## Ordering

### reverse()

Reverses the order of a sequence.

**Signature:** `reverse($seq as item()*) as item()*`

```xpath
reverse((1, 2, 3))             => (3, 2, 1)
reverse(("c", "b", "a"))      => ("a", "b", "c")
```

**C# equivalent:** `items.Reverse()`

---

### sort()

Sorts a sequence. Can take a custom sort key function.

**Signature:** `sort($seq as item()*, $collation as xs:string?, $key as function(item()) as xs:anyAtomicType*) as item()*`

```xpath
sort(("banana", "apple", "cherry"))
=> ("apple", "banana", "cherry")

sort((3, 1, 4, 1, 5))
=> (1, 1, 3, 4, 5)

(: Sort books by price :)
sort(//book, (), function($b) { $b/price })
```

**C# equivalent:** `items.OrderBy(x => x)` or `items.OrderBy(x => x.Price)`

---

### sort-by()

Sorts by a key expression. Simpler than `sort()` for common cases. New in XPath 4.0.

**Signature:** `sort-by($seq as item()*, $key as function(item()) as xs:anyAtomicType*) as item()*`

```xpath
sort-by(//book, function($b) { $b/price })   (: books cheapest first :)
```

**C# equivalent:** `books.OrderBy(b => b.Price)`

---

## Set Operations

### distinct-values()

Returns unique atomic values from a sequence.

**Signature:** `distinct-values($seq as xs:anyAtomicType*, $collation as xs:string?) as xs:anyAtomicType*`

```xpath
distinct-values((1, 2, 2, 3, 3, 3))           => (1, 2, 3)
distinct-values(("a", "b", "a", "c"))          => ("a", "b", "c")
distinct-values(//book/@category)               => unique categories
```

**C# equivalent:** `items.Distinct()`

---

### index-of()

Returns the positions where a value appears.

**Signature:** `index-of($seq as xs:anyAtomicType*, $search as xs:anyAtomicType, $collation as xs:string?) as xs:integer*`

```xpath
index-of(("a", "b", "c", "b"), "b")   => (2, 4)
index-of((10, 20, 30), 20)             => 2
index-of((10, 20, 30), 99)             => ()
```

**C# equivalent:** `items.Select((item, i) => (item, i)).Where(x => x.item == search).Select(x => x.i + 1)`

---

### index-where()

Returns positions where a predicate is true. New in XPath 4.0.

**Signature:** `index-where($seq as item()*, $predicate as function(item()) as xs:boolean) as xs:integer*`

```xpath
index-where((3, 1, 4, 1, 5), function($n) { $n > 3 })
=> (3, 5)   (: positions of 4 and 5 :)
```

**C# equivalent:** `items.Select((item, i) => (item, i)).Where(x => predicate(x.item)).Select(x => x.i + 1)`

---

### duplicate-values()

Returns values that appear more than once. New in XPath 4.0.

**Signature:** `duplicate-values($seq as xs:anyAtomicType*) as xs:anyAtomicType*`

```xpath
duplicate-values((1, 2, 2, 3, 3, 4))   => (2, 3)
```

**C# equivalent:** `items.GroupBy(x => x).Where(g => g.Count() > 1).Select(g => g.Key)`

---

## Comparison

### deep-equal()

Compares two items or sequences for deep equality — including structure for nodes.

**Signature:** `deep-equal($a as item()*, $b as item()*, $collation as xs:string?) as xs:boolean`

```xpath
deep-equal((1, 2, 3), (1, 2, 3))        => true
deep-equal((1, 2, 3), (1, 2))           => false
deep-equal(//book[1], //book[1])         => true  (: same node, always equal :)
```

**C# equivalent:** `Enumerable.SequenceEqual(a, b)` for sequences, or structural comparison for objects.

---

### all-equal()

Tests whether all items in a sequence are equal. New in XPath 4.0.

**Signature:** `all-equal($seq as xs:anyAtomicType*) as xs:boolean`

```xpath
all-equal((5, 5, 5))         => true
all-equal((5, 5, 6))         => false
all-equal(())                 => true   (: vacuously true :)
all-equal(("a"))              => true
```

**C# equivalent:** `items.Distinct().Count() <= 1`

---

### all-different()

Tests whether all items in a sequence are unique. New in XPath 4.0.

**Signature:** `all-different($seq as xs:anyAtomicType*) as xs:boolean`

```xpath
all-different((1, 2, 3))     => true
all-different((1, 2, 2))     => false
```

**C# equivalent:** `items.Distinct().Count() == items.Count()`

---

## Manipulation

### insert-before()

Inserts items into a sequence at a given position.

**Signature:** `insert-before($seq as item()*, $pos as xs:integer, $items as item()*) as item()*`

```xpath
insert-before(("a", "b", "c"), 2, "X")   => ("a", "X", "b", "c")
```

**C# equivalent:** `list.Insert(1, "X")` (but XPath sequences are immutable — a new sequence is returned)

---

### remove()

Removes the item at a given position.

**Signature:** `remove($seq as item()*, $pos as xs:integer) as item()*`

```xpath
remove(("a", "b", "c"), 2)   => ("a", "c")
```

**C# equivalent:** `list.RemoveAt(1)` (again, XPath returns a new sequence)

---

### replicate()

Repeats a sequence a given number of times. New in XPath 4.0.

**Signature:** `replicate($seq as item()*, $count as xs:integer) as item()*`

```xpath
replicate(("a", "b"), 3)   => ("a", "b", "a", "b", "a", "b")
replicate("x", 5)           => ("x", "x", "x", "x", "x")
```

**C# equivalent:** `Enumerable.Repeat(items, 3).SelectMany(x => x)`

---

## Scanning and Accumulation

These higher-level sequence operations are new in XPath 4.0 and parallel functional programming patterns.

### scan-left()

Produces a running accumulation from left to right — like a fold that returns all intermediate results.

**Signature:** `scan-left($seq as item()*, $initial as item()*, $fn as function(item()*, item()) as item()*) as item()**`

```xpath
scan-left((1, 2, 3, 4), 0, function($acc, $n) { $acc + $n })
=> (0, 1, 3, 6, 10)   (: running sum :)
```

**C# equivalent:** `items.Aggregate()` doesn't return intermediates, but you could build it with a `Select` that maintains state:
```csharp
items.Select((x, i) => items.Take(i + 1).Sum())
```

---

### scan-right()

Like `scan-left`, but accumulates from right to left.

**Signature:** `scan-right($seq as item()*, $initial as item()*, $fn as function(item(), item()*) as item()*) as item()**`

```xpath
scan-right((1, 2, 3, 4), 0, function($n, $acc) { $acc + $n })
=> (10, 9, 7, 4, 0)
```

---

### partition()

Splits a sequence into groups based on a predicate that signals group boundaries. New in XPath 4.0.

**Signature:** `partition($seq as item()*, $fn as function(item(), item()?) as xs:boolean) as array(item()*)`

```xpath
(: Split at each value greater than the previous :)
partition((1, 2, 3, 1, 2, 1),
  function($cur, $prev) { $prev and $cur < $prev })
=> [[1, 2, 3], [1, 2], [1]]
```

---

### iterate-while()

Repeatedly applies a function while a condition holds. New in XPath 4.0.

**Signature:** `iterate-while($initial as item()*, $condition as function(item()*) as xs:boolean, $action as function(item()*) as item()*) as item()*`

```xpath
(: Double until > 100 :)
iterate-while(1,
  function($n) { $n <= 100 },
  function($n) { $n * 2 })
=> 128
```

**C# equivalent:**
```csharp
var n = 1;
while (n <= 100) n *= 2;
// n == 128
```

---

### transitive-closure()

Computes the transitive closure of a function — applying it repeatedly and collecting all results until no new items are produced. New in XPath 4.0.

**Signature:** `transitive-closure($initial as item()*, $fn as function(item()) as item()*) as item()*`

```xpath
(: Find all ancestors of a node :)
transitive-closure($node, function($n) { $n/.. })
```

**Use case:** Graph traversal, hierarchy walking, dependency resolution.
