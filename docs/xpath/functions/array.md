---
title: Array Functions
description: XPath ordered array operations — like List<T> in .NET
sort: 8
---

# Array Functions

Arrays are ordered, indexable collections introduced in XPath 3.1. Unlike sequences (which are flat), arrays can be nested — an array can contain other arrays. Think of them as `List<object>` in C# or JSON arrays.

All array functions are in the `array:` namespace.

## Sequences vs Arrays

| Feature | Sequence | Array |
|---------|----------|-------|
| Nesting | Flat — `(1, (2, 3))` becomes `(1, 2, 3)` | Nestable — `[[1, 2], [3, 4]]` |
| Indexing | By position with `[N]` predicate | With `?N` lookup |
| Mutation | No in-place mutation | No in-place mutation |
| Use case | Query results, node selections | Structured data, JSON interop |

## Contents

- [Construction](#construction)
- [Access](#access)
- [Modification](#modification)
- [Transformation](#transformation)
- [Searching](#searching)

---

## Construction

### Array Literals

```xpath
[1, 2, 3]                    (: array of integers :)
["a", "b", "c"]              (: array of strings :)
[[1, 2], [3, 4]]             (: nested arrays :)
[]                            (: empty array :)
```

---

### array:build()

Builds an array from a sequence using a function. New in XPath 4.0.

**Signature:** `array:build($seq as item()*, $fn as function(item()) as item()*) as array(*)`

```xpath
array:build(1 to 5, function($n) { $n * $n })
=> [1, 4, 9, 16, 25]
```

**C# equivalent:** `Enumerable.Range(1, 5).Select(n => n * n).ToList()`

---

### array:join()

Concatenates multiple arrays into one.

**Signature:** `array:join($arrays as array(*)*) as array(*)`

```xpath
array:join(([1, 2], [3, 4], [5]))   => [1, 2, 3, 4, 5]
```

**C# equivalent:** `lists.SelectMany(x => x).ToList()`

---

## Access

### array:size()

Returns the number of members.

```xpath
array:size([10, 20, 30])   => 3
array:size([])              => 0
```

**C# equivalent:** `list.Count`

---

### array:get()

Returns the member at a position (1-based).

```xpath
array:get(["a", "b", "c"], 2)   => "b"
```

**Shorthand:** `$arr?2` — the lookup operator works on arrays with integer keys.

**C# equivalent:** `list[1]` (0-based in C#)

---

### array:head() / array:tail() / array:foot() / array:trunk()

Same semantics as their sequence counterparts:

```xpath
array:head([1, 2, 3])    => 1
array:tail([1, 2, 3])    => [2, 3]
array:foot([1, 2, 3])    => 3         (: XPath 4.0 :)
array:trunk([1, 2, 3])   => [1, 2]    (: XPath 4.0 :)
```

---

### array:subarray()

Extracts a contiguous slice.

```xpath
array:subarray([10, 20, 30, 40, 50], 2, 3)   => [20, 30, 40]
```

---

### array:slice()

Advanced slicing with start, stop, step. New in XPath 4.0.

```xpath
array:slice([1, 2, 3, 4, 5, 6, 7, 8], 2, 7, 2)   => [2, 4, 6]
```

---

## Modification

Arrays are immutable — these return new arrays.

### array:put()

Returns a new array with the value at a position replaced.

```xpath
array:put(["a", "b", "c"], 2, "X")   => ["a", "X", "c"]
```

**C# equivalent:** `list[1] = "X"` (but immutable)

---

### array:append()

Appends a member to the end.

```xpath
array:append([1, 2], 3)   => [1, 2, 3]
```

**C# equivalent:** `list.Add(3)` (immutable version)

---

### array:insert-before()

Inserts a member at a position.

```xpath
array:insert-before([1, 2, 3], 2, 99)   => [1, 99, 2, 3]
```

---

### array:remove()

Removes the member at a position.

```xpath
array:remove([1, 2, 3], 2)   => [1, 3]
```

---

### array:reverse()

```xpath
array:reverse([1, 2, 3])   => [3, 2, 1]
```

---

## Transformation

### array:for-each()

Applies a function to each member.

```xpath
array:for-each([1, 2, 3], function($n) { $n * 2 })
=> [2, 4, 6]
```

**C# equivalent:** `list.Select(n => n * 2).ToList()`

---

### array:filter()

Keeps members where the predicate is true.

```xpath
array:filter([1, 2, 3, 4, 5], function($n) { $n mod 2 = 0 })
=> [2, 4]
```

**C# equivalent:** `list.Where(n => n % 2 == 0).ToList()`

---

### array:fold-left() / array:fold-right()

Reduces an array to a single value.

```xpath
array:fold-left([1, 2, 3, 4], 0, function($acc, $n) { $acc + $n })
=> 10
```

**C# equivalent:** `list.Aggregate(0, (acc, n) => acc + n)`

---

### array:for-each-pair()

Applies a function to pairs of members from two arrays.

```xpath
array:for-each-pair([1, 2, 3], [10, 20, 30],
  function($a, $b) { $a + $b })
=> [11, 22, 33]
```

**C# equivalent:** `a.Zip(b, (x, y) => x + y).ToList()`

---

### array:sort() / array:sort-by()

```xpath
array:sort(["banana", "apple", "cherry"])
=> ["apple", "banana", "cherry"]

array:sort-by($books, function($b) { $b?price })
```

---

### array:flatten()

Recursively flattens nested arrays into a sequence.

```xpath
array:flatten([[1, 2], [3, [4, 5]]])   => (1, 2, 3, 4, 5)
```

**C# equivalent:** `list.SelectMany(x => x is IEnumerable e ? e.Cast<object>() : new[] { x })`

---

## Searching

### array:index-of()

Returns positions where a value appears. New in XPath 4.0.

```xpath
array:index-of(["a", "b", "c", "b"], "b")   => (2, 4)
```

---

### array:index-where()

Returns positions where a predicate is true. New in XPath 4.0.

```xpath
array:index-where([3, 1, 4, 1, 5], function($n) { $n > 3 })
=> (3, 5)
```

---

## Conversion

### array:members()

Converts an array to a sequence of its members (each wrapped in a single-item array). New in XPath 4.0.

### array:items()

Converts an array to a flat sequence. New in XPath 4.0.

```xpath
array:items([1, 2, 3])   => (1, 2, 3)
```

### array:of-members()

Creates an array from a sequence of single-item arrays. New in XPath 4.0.
