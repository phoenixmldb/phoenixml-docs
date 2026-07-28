---
title: Map Functions
description: XPath map operations — key-value data structures like Dictionary in .NET
sort: 7
---

# Map Functions

Maps are the XPath key-value data structure. XPath 3.1 introduced maps.

> For C# developers: an XPath map resembles `Dictionary<TKey, TValue>` or a JSON object. `map:merge` resembles combining several dictionaries, with later entries winning on a key conflict. `map:build` resembles `ToDictionary`. `map:get` resembles `dict["key"]` or `dict.GetValueOrDefault("key")`. `map:contains` resembles `ContainsKey`. `map:size` resembles `Count`. `map:keys` resembles `Keys`. `map:put` resembles `SetItem` on an immutable dictionary. `map:remove` resembles `Remove` on an immutable dictionary. `map:for-each` resembles `Select` over key-value pairs. `map:filter` resembles `Where` followed by `ToDictionary`. `map:group-by` resembles `GroupBy` followed by `ToDictionary`.

All map functions are in the `map:` namespace.

## Contents

- [Construction](#construction)
- [Access](#access)
- [Modification](#modification)
- [Iteration](#iteration)

---

## Construction

### Map Literals

You can create a map with literal syntax:

```xpath
map { "name": "Alice", "age": 30 }
map { 1: "one", 2: "two", 3: "three" }
map { }   (: empty map :)
```

```csharp
new Dictionary<string, object> { ["name"] = "Alice", ["age"] = 30 }
```

---

### map:merge()

Merges several maps into one. Later entries override earlier ones for duplicate keys.

**Signature:** `map:merge($maps as map(*)*) as map(*)`

```xpath
map:merge((
  map { "a": 1, "b": 2 },
  map { "b": 3, "c": 4 }
))
=> map { "a": 1, "b": 3, "c": 4 }
```

---

### map:entry()

Creates a single-entry map.

**Signature:** `map:entry($key as xs:anyAtomicType, $value as item()*) as map(*)`

```xpath
map:entry("name", "Alice")   => map { "name": "Alice" }
```

---

### map:pair()

Creates a map from a key-value pair. New in XPath 4.0.

---

### map:of-pairs()

Creates a map from a sequence of key-value pair maps. New in XPath 4.0.

---

### map:build()

Builds a map from a sequence, using a key function and a value function. New in XPath 4.0.

**Signature:** `map:build($seq as item()*, $key as function(item()) as xs:anyAtomicType, $value as function(item()) as item()*) as map(*)`

```xpath
map:build(//book,
  function($b) { $b/@isbn },
  function($b) { $b/title/string() })
=> map { "978-0-123...": "Effective C#", "978-0-987...": "XML in a Nutshell" }
```

---

## Access

### map:get()

Returns the value associated with a key.

**Signature:** `map:get($map as map(*), $key as xs:anyAtomicType) as item()*`

```xpath
map:get(map { "name": "Alice", "age": 30 }, "name")   => "Alice"
map:get(map { "name": "Alice" }, "email")              => ()  (: missing key :)
```

**Shorthand:** The `?` lookup operator:
```xpath
$person?name       => same as map:get($person, "name")
$person?age        => same as map:get($person, "age")
```

---

### map:contains()

Tests whether a map contains a key.

**Signature:** `map:contains($map as map(*), $key as xs:anyAtomicType) as xs:boolean`

```xpath
map:contains(map { "name": "Alice" }, "name")    => true
map:contains(map { "name": "Alice" }, "email")   => false
```

---

### map:size()

Returns the number of entries.

**Signature:** `map:size($map as map(*)) as xs:integer`

```xpath
map:size(map { "a": 1, "b": 2 })   => 2
map:size(map { })                    => 0
```

---

### map:keys()

Returns all keys in the map.

**Signature:** `map:keys($map as map(*)) as xs:anyAtomicType*`

```xpath
map:keys(map { "name": "Alice", "age": 30 })   => ("name", "age")
```

---

### map:empty()

Returns an empty map. New in XPath 4.0.

---

## Modification

Maps are immutable. These functions return new maps.

### map:put()

Returns a new map with an added or updated entry.

**Signature:** `map:put($map as map(*), $key as xs:anyAtomicType, $value as item()*) as map(*)`

```xpath
map:put(map { "a": 1 }, "b", 2)        => map { "a": 1, "b": 2 }
map:put(map { "a": 1 }, "a", 99)       => map { "a": 99 }  (: update :)
```

---

### map:remove()

Returns a new map without the specified key.

**Signature:** `map:remove($map as map(*), $key as xs:anyAtomicType) as map(*)`

```xpath
map:remove(map { "a": 1, "b": 2 }, "a")   => map { "b": 2 }
```

---

### map:replace()

Replaces a value by applying a function to the existing value. New in XPath 4.0.

---

## Iteration

### map:for-each()

Applies a function to each key-value pair and returns the results as a sequence.

**Signature:** `map:for-each($map as map(*), $fn as function(xs:anyAtomicType, item()*) as item()*) as item()*`

```xpath
map:for-each(
  map { "name": "Alice", "age": 30 },
  function($k, $v) { $k || "=" || $v }
)
=> ("name=Alice", "age=30")
```

---

### map:filter()

Returns a map that contains only the entries where the predicate is true. New in XPath 4.0.

**Signature:** `map:filter($map as map(*), $fn as function(xs:anyAtomicType, item()*) as xs:boolean) as map(*)`

```xpath
map:filter(
  map { "name": "Alice", "age": 30, "city": "NYC" },
  function($k, $v) { $k != "age" }
)
=> map { "name": "Alice", "city": "NYC" }
```

---

### map:entries()

Returns the entries of a map as a sequence of single-entry maps. New in XPath 4.0.

---

### map:group-by()

Groups a sequence into a map, using a key function. New in XPath 4.0.

**Signature:** `map:group-by($seq as item()*, $key as function(item()) as xs:anyAtomicType) as map(*)`

```xpath
map:group-by(//book, function($b) { $b/@category })
=> map {
     "programming": (book1, book2),
     "data": (book3)
   }
```

This XPath 4.0 addition turns a common multi-step operation into a single function call.

---

### map:keys-where()

Returns keys where a predicate on the value is true. New in XPath 4.0.
