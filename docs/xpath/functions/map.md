---
title: Map Functions
description: XPath map operations — key-value data structures like Dictionary in .NET
sort: 7
---

# Map Functions

Maps are XPath's key-value data structure, introduced in XPath 3.1. If you work with `Dictionary<TKey, TValue>` in C# or JSON objects, maps are the XPath equivalent.

All map functions are in the `map:` namespace.

## Contents

- [Construction](#construction)
- [Access](#access)
- [Modification](#modification)
- [Iteration](#iteration)

---

## Construction

### Map Literals

Maps can be created with literal syntax:

```xpath
map { "name": "Alice", "age": 30 }
map { 1: "one", 2: "two", 3: "three" }
map { }   (: empty map :)
```

**C# equivalent:**
```csharp
new Dictionary<string, object> { ["name"] = "Alice", ["age"] = 30 }
```

---

### map:merge()

Merges multiple maps into one. Later entries override earlier ones for duplicate keys.

**Signature:** `map:merge($maps as map(*)*) as map(*)`

```xpath
map:merge((
  map { "a": 1, "b": 2 },
  map { "b": 3, "c": 4 }
))
=> map { "a": 1, "b": 3, "c": 4 }
```

**C# equivalent:** Multiple `.Union()` or `ToDictionary` calls with conflict resolution.

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

Builds a map from a sequence using key and value functions. New in XPath 4.0.

**Signature:** `map:build($seq as item()*, $key as function(item()) as xs:anyAtomicType, $value as function(item()) as item()*) as map(*)`

```xpath
map:build(//book,
  function($b) { $b/@isbn },
  function($b) { $b/title/string() })
=> map { "978-0-123...": "Effective C#", "978-0-987...": "XML in a Nutshell" }
```

**C# equivalent:** `books.ToDictionary(b => b.Isbn, b => b.Title)`

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

**C# equivalent:** `dict["name"]` or `dict.GetValueOrDefault("name")`

---

### map:contains()

Tests whether a map contains a key.

**Signature:** `map:contains($map as map(*), $key as xs:anyAtomicType) as xs:boolean`

```xpath
map:contains(map { "name": "Alice" }, "name")    => true
map:contains(map { "name": "Alice" }, "email")   => false
```

**C# equivalent:** `dict.ContainsKey("name")`

---

### map:size()

Returns the number of entries.

**Signature:** `map:size($map as map(*)) as xs:integer`

```xpath
map:size(map { "a": 1, "b": 2 })   => 2
map:size(map { })                    => 0
```

**C# equivalent:** `dict.Count`

---

### map:keys()

Returns all keys in the map.

**Signature:** `map:keys($map as map(*)) as xs:anyAtomicType*`

```xpath
map:keys(map { "name": "Alice", "age": 30 })   => ("name", "age")
```

**C# equivalent:** `dict.Keys`

---

### map:empty()

Returns an empty map. New in XPath 4.0.

---

## Modification

Maps are immutable — these functions return new maps.

### map:put()

Returns a new map with an added or updated entry.

**Signature:** `map:put($map as map(*), $key as xs:anyAtomicType, $value as item()*) as map(*)`

```xpath
map:put(map { "a": 1 }, "b", 2)        => map { "a": 1, "b": 2 }
map:put(map { "a": 1 }, "a", 99)       => map { "a": 99 }  (: update :)
```

**C# equivalent:** With immutable dictionaries: `dict.SetItem("b", 2)`

---

### map:remove()

Returns a new map without the specified key.

**Signature:** `map:remove($map as map(*), $key as xs:anyAtomicType) as map(*)`

```xpath
map:remove(map { "a": 1, "b": 2 }, "a")   => map { "b": 2 }
```

**C# equivalent:** `dict.Remove("a")` (immutable version)

---

### map:replace()

Replaces a value by applying a function to the existing value. New in XPath 4.0.

---

## Iteration

### map:for-each()

Applies a function to each key-value pair, returning a sequence.

**Signature:** `map:for-each($map as map(*), $fn as function(xs:anyAtomicType, item()*) as item()*) as item()*`

```xpath
map:for-each(
  map { "name": "Alice", "age": 30 },
  function($k, $v) { $k || "=" || $v }
)
=> ("name=Alice", "age=30")
```

**C# equivalent:** `dict.Select(kv => $"{kv.Key}={kv.Value}")`

---

### map:filter()

Returns a map containing only entries where the predicate is true. New in XPath 4.0.

**Signature:** `map:filter($map as map(*), $fn as function(xs:anyAtomicType, item()*) as xs:boolean) as map(*)`

```xpath
map:filter(
  map { "name": "Alice", "age": 30, "city": "NYC" },
  function($k, $v) { $k != "age" }
)
=> map { "name": "Alice", "city": "NYC" }
```

**C# equivalent:** `dict.Where(kv => kv.Key != "age").ToDictionary()`

---

### map:entries()

Returns the entries of a map as a sequence of single-entry maps. New in XPath 4.0.

---

### map:group-by()

Groups a sequence into a map using a key function. New in XPath 4.0.

**Signature:** `map:group-by($seq as item()*, $key as function(item()) as xs:anyAtomicType) as map(*)`

```xpath
map:group-by(//book, function($b) { $b/@category })
=> map {
     "programming": (book1, book2),
     "data": (book3)
   }
```

**C# equivalent:** `books.GroupBy(b => b.Category).ToDictionary(g => g.Key, g => g.ToList())`

This is one of the most powerful XPath 4.0 additions — it turns a common multi-step operation into a single function call.

---

### map:keys-where()

Returns keys where a predicate on the value is true. New in XPath 4.0.
