---
title: Type System
description: XQuery types, sequence types, records, enums, union types, and type testing
sort: 6
---

# Type System

XQuery has a rich, formally specified type system built on XML Schema. If you're coming from C#, many concepts will be familiar — atomic types, function types, records — but the details differ in important ways. The biggest difference: everything in XQuery is a **sequence**, and the type system reflects that.

## Contents

- [Atomic Types](#atomic-types)
- [Sequence Types](#sequence-types)
- [Function Types](#function-types)
- [Record Types](#record-types)
- [Enum Types](#enum-types)
- [Union Types](#union-types)
- [Type Testing and Casting](#type-testing-and-casting)
- [Type Promotion](#type-promotion)

---

## Atomic Types

Atomic types are the building blocks. They're derived from XML Schema and prefixed with `xs:`.

### Commonly Used Types

| XQuery Type | C# Equivalent | Example |
|-------------|---------------|---------|
| `xs:string` | `string` | `"hello"` |
| `xs:integer` | `long` | `42` |
| `xs:decimal` | `decimal` | `3.14` |
| `xs:double` | `double` | `3.14e0` |
| `xs:boolean` | `bool` | `true()`, `false()` |
| `xs:date` | `DateTime` (date only) | `xs:date("2026-03-19")` |
| `xs:dateTime` | `DateTime` | `xs:dateTime("2026-03-19T14:30:00")` |
| `xs:time` | `TimeSpan` | `xs:time("14:30:00")` |
| `xs:duration` | `TimeSpan` | `xs:duration("P1Y2M3D")` |
| `xs:float` | `float` | `1.5e0` |
| `xs:anyURI` | `Uri` | `xs:anyURI("https://example.com")` |
| `xs:QName` | — | `xs:QName("xsl:template")` |
| `xs:base64Binary` | `byte[]` | Base64-encoded binary |
| `xs:hexBinary` | `byte[]` | Hex-encoded binary |

### Date and Time Types in Detail

Dates trip up many developers. XQuery follows ISO 8601 strictly:

```xquery
(: Date — year, month, day :)
xs:date("2026-03-19")

(: DateTime — date plus time :)
xs:dateTime("2026-03-19T14:30:00")

(: DateTime with timezone :)
xs:dateTime("2026-03-19T14:30:00-05:00")

(: Current date/time functions :)
current-date()      (: today as xs:date :)
current-dateTime()  (: now as xs:dateTime :)
current-time()      (: current time as xs:time :)
```

**C# parallel:**
```csharp
// Date string
DateTime.Now.ToString("yyyy-MM-dd")            // "2026-03-19"

// DateTime string
DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss")   // "2026-03-19T14:30:00"

// Timezone-aware
DateTimeOffset.Now.ToString("yyyy-MM-ddTHH:mm:sszzz") // with offset
```

### Numeric Type Hierarchy

XQuery's numeric types form a hierarchy. This matters for arithmetic:

```
xs:double
  ↑ (promotes from)
xs:float
  ↑ (promotes from)
xs:decimal
  ↑ (subtype)
xs:integer
  ↑ (subtypes)
xs:long, xs:int, xs:short, xs:byte, xs:nonNegativeInteger, etc.
```

In practice, you'll mostly use `xs:integer`, `xs:decimal`, and `xs:double`:

```xquery
(: Integer literal :)
42

(: Decimal literal — has a dot :)
3.14

(: Double literal — has an exponent :)
3.14e0

(: Explicit construction :)
xs:integer("42")
xs:decimal("3.14")
xs:double("3.14")
```

### Untyped Data

When you read XML without a schema, text content is `xs:untypedAtomic`. XQuery automatically converts untyped values during comparisons and arithmetic, but explicit casting is safer:

```xquery
(: $book/price is xs:untypedAtomic from unvalidated XML :)
let $price := $book/price

(: Implicit conversion — works but fragile :)
$price > 30

(: Explicit casting — clearer, fails fast on bad data :)
xs:decimal($price) > 30
```

**C# parallel:** Like the difference between `dynamic` and strongly-typed properties:
```csharp
// Implicit (like untyped XQuery)
dynamic price = element.Value;  // risky

// Explicit (like xs:decimal cast)
decimal price = (decimal)element;  // clear
```

---

## Sequence Types

Every value in XQuery is a sequence. Sequence types describe what's in the sequence and how many items are allowed.

### Occurrence Indicators

| Indicator | Meaning | C# Parallel |
|-----------|---------|-------------|
| (none) | Exactly one | `T` (non-nullable) |
| `?` | Zero or one | `T?` (nullable) |
| `*` | Zero or more | `IEnumerable<T>` |
| `+` | One or more | `IEnumerable<T>` (non-empty) |

```xquery
declare function local:example(
  $required as xs:string,           (: exactly one string :)
  $optional as xs:string?,          (: zero or one string :)
  $multiple as xs:string*,          (: any number of strings :)
  $at-least-one as xs:string+       (: one or more strings :)
) as xs:string* {                   (: returns zero or more strings :)
  ...
};
```

**C# parallel:**
```csharp
IEnumerable<string> Example(
    string required,                // non-null
    string? optional,               // nullable
    IEnumerable<string> multiple,   // any count
    IEnumerable<string> atLeastOne  // non-empty (by convention)
) { ... }
```

### Item Type Specifiers

Beyond atomic types, you can specify node types and other item types:

```xquery
(: Node types :)
node()                  (: any node :)
element()               (: any element :)
element(product)        (: element named "product" :)
attribute()             (: any attribute :)
attribute(id)           (: attribute named "id" :)
text()                  (: text node :)
comment()               (: comment node :)
document-node()         (: document node :)
processing-instruction()(: processing instruction :)

(: General item types :)
item()                  (: any item — node or atomic :)
map(*)                  (: any map :)
array(*)                (: any array :)
function(*)             (: any function :)
```

### Practical Examples

```xquery
(: Accept any XML elements, return a map :)
declare function local:summarize($nodes as element()*) as map(*) {
  map {
    "count": count($nodes),
    "names": array { distinct-values($nodes ! local-name(.)) }
  }
};

(: Accept a document, return elements :)
declare function local:extract-data(
  $doc as document-node()
) as element(record)* {
  $doc//record
};
```

---

## Function Types

Functions are first-class values in XQuery. You can declare the type of a function parameter or variable:

```xquery
(: A function that takes an integer and returns a boolean :)
function(xs:integer) as xs:boolean

(: A function that takes two strings and returns a string :)
function(xs:string, xs:string) as xs:string

(: Any function :)
function(*)
```

### Using Function Types

```xquery
(: Higher-order function: filter with a custom predicate :)
declare function local:filter(
  $items as item()*,
  $predicate as function(item()) as xs:boolean
) as item()* {
  for $item in $items
  where $predicate($item)
  return $item
};

(: Usage :)
local:filter(
  //product,
  function($p) { xs:decimal($p/price) > 50 }
)
```

**C# parallel:**
```csharp
IEnumerable<T> Filter<T>(IEnumerable<T> items, Func<T, bool> predicate)
    => items.Where(predicate);

Filter(products, p => p.Price > 50);
```

### Storing Functions in Variables

```xquery
let $transforms := map {
  "upper": upper-case#1,
  "lower": lower-case#1,
  "trim":  normalize-space#1
}
let $fn := $transforms?upper
return $fn("hello")
(: Result: "HELLO" :)
```

The `#1` syntax creates a named function reference. The number indicates the arity (number of arguments).

---

## Record Types

*XQuery 4.0*

Record types define the shape of a map with named, typed fields. They're XQuery's answer to C# records and TypeScript interfaces.

```xquery
declare function local:create-user(
  $name as xs:string,
  $email as xs:string,
  $age as xs:integer
) as record(name as xs:string, email as xs:string, age as xs:integer) {
  map { "name": $name, "email": $email, "age": $age }
};
```

**C# parallel:**
```csharp
public record User(string Name, string Email, int Age);

User CreateUser(string name, string email, int age)
    => new User(name, email, age);
```

### Optional Fields

Use `?` to mark fields as optional:

```xquery
declare function local:parse-address(
  $node as element(address)
) as record(
  street as xs:string,
  city as xs:string,
  state as xs:string,
  zip as xs:string,
  apartment as xs:string?    (: optional :)
) {
  map {
    "street": string($node/street),
    "city": string($node/city),
    "state": string($node/state),
    "zip": string($node/zip),
    "apartment": string($node/apartment)[. ne ""]
  }
};
```

### Extensible Records

Use `*` to allow additional fields beyond those declared:

```xquery
(: Accepts a map with at least "id" and "name", but may have more :)
declare function local:display(
  $item as record(id as xs:string, name as xs:string, *)
) as element(div) {
  <div id="{ $item?id }">{ $item?name }</div>
};

(: This works — extra fields are allowed :)
local:display(map {
  "id": "42",
  "name": "Widget",
  "price": 9.99,
  "category": "tools"
})
```

### Practical Example: API Response Types

```xquery
(: Define response shapes :)
declare function local:success(
  $data as item()*
) as record(status as xs:string, data as item()*) {
  map { "status": "ok", "data": $data }
};

declare function local:error-response(
  $code as xs:integer,
  $message as xs:string
) as record(status as xs:string, error as record(code as xs:integer, message as xs:string)) {
  map {
    "status": "error",
    "error": map { "code": $code, "message": $message }
  }
};

(: Usage :)
let $result := try {
  let $data := collection("products")//product[@id = $id]
  return if (exists($data)) then
    local:success($data)
  else
    local:error-response(404, "Product not found")
} catch * {
  local:error-response(500, $err:description)
}
return serialize($result, map { "method": "json", "indent": true() })
```

---

## Enum Types

*XQuery 4.0*

Enum types restrict a value to a fixed set of string options. They catch invalid values at type-checking time.

```xquery
declare function local:set-priority(
  $task as element(task),
  $priority as enum("low", "medium", "high", "critical")
) as element(task) {
  copy $t := $task
  modify replace value of node $t/@priority with $priority
  return $t
};

(: Valid :)
local:set-priority($task, "high")

(: Type error — "urgent" is not in the enum :)
local:set-priority($task, "urgent")
```

**C# parallel:**
```csharp
public enum Priority { Low, Medium, High, Critical }

Task SetPriority(Task task, Priority priority) { ... }
```

### Using Enums in Sequence Types

```xquery
declare function local:filter-by-status(
  $orders as element(order)*,
  $status as enum("pending", "approved", "shipped", "delivered")+
) as element(order)* {
  $orders[$status = @status]
};

(: Filter for multiple statuses :)
local:filter-by-status(//order, ("pending", "approved"))
```

### Enum in Record Types

```xquery
declare function local:create-ticket(
  $title as xs:string,
  $priority as enum("low", "medium", "high"),
  $type as enum("bug", "feature", "task")
) as record(
  title as xs:string,
  priority as enum("low", "medium", "high"),
  type as enum("bug", "feature", "task"),
  created as xs:dateTime
) {
  map {
    "title": $title,
    "priority": $priority,
    "type": $type,
    "created": current-dateTime()
  }
};
```

---

## Union Types

*XQuery 4.0*

Union types allow a value to be one of several types. This is useful for functions that accept different input formats.

```xquery
(: Accept either a string or a date :)
declare function local:format-date(
  $input as union(xs:string, xs:date, xs:dateTime)
) as xs:string {
  let $date := typeswitch ($input)
    case xs:date return $input
    case xs:dateTime return xs:date($input)
    case xs:string return xs:date($input)
    default return error((), "Unexpected type")
  return format-date($date, "[MNn] [D], [Y]")
};

(: All of these work :)
local:format-date(xs:date("2026-03-19"))
local:format-date(xs:dateTime("2026-03-19T10:30:00"))
local:format-date("2026-03-19")
```

**C# parallel:** C# doesn't have union types natively, but you can approximate them with method overloading or the `OneOf` library:
```csharp
// Overloaded methods
string FormatDate(DateTime date) => date.ToString("MMMM d, yyyy");
string FormatDate(string dateStr) => FormatDate(DateTime.Parse(dateStr));
```

### Practical Example: Flexible Input

```xquery
(: A function that accepts IDs as strings or integers :)
declare function local:find-product(
  $id as union(xs:string, xs:integer)
) as element(product)? {
  let $str-id := string($id)
  return collection("products")//product[@id = $str-id]
};

(: Both work :)
local:find-product("PRD-001")
local:find-product(42)
```

### Union vs Sequence of item()

Don't confuse union types with `item()`. A union type is restrictive — it limits which types are accepted. `item()` accepts anything:

```xquery
(: Too permissive — accepts nodes, functions, maps, anything :)
declare function local:loose($x as item()) as xs:string { ... };

(: Precise — only these three types :)
declare function local:strict($x as union(xs:string, xs:integer, xs:decimal)) as xs:string { ... };
```

---

## Type Testing and Casting

XQuery provides four type-related expressions for testing, asserting, and converting types.

### instance of

Tests whether a value matches a type. Returns `xs:boolean`.

```xquery
42 instance of xs:integer                (: true :)
42 instance of xs:string                 (: false :)
(1, 2, 3) instance of xs:integer+       (: true :)
() instance of xs:integer?              (: true — empty matches ? :)
<product/> instance of element()         (: true :)
```

**C# parallel:** `is`:
```csharp
42 is int      // true
42 is string   // false
```

### Practical Use: Defensive Programming

```xquery
declare function local:process($input as item()*) as item()* {
  if ($input instance of element()+) then
    (: Process as XML elements :)
    for $e in $input return local:transform-element($e)
  else if ($input instance of map(*)) then
    (: Process as a map :)
    local:transform-map($input)
  else if ($input instance of xs:string+) then
    (: Process as strings :)
    $input ! upper-case(.)
  else
    error((), "Unsupported input type")
};
```

### castable as

Tests whether a value **can** be cast to a type. Returns `xs:boolean`. Does not perform the cast.

```xquery
"42" castable as xs:integer        (: true :)
"hello" castable as xs:integer     (: false :)
"2026-03-19" castable as xs:date   (: true :)
"not-a-date" castable as xs:date   (: false :)
```

**C# parallel:** `TryParse` pattern:
```csharp
int.TryParse("42", out _)               // true
int.TryParse("hello", out _)            // false
DateTime.TryParse("2026-03-19", out _)  // true
```

**Common pattern: safe conversion:**

```xquery
let $price := if ($value castable as xs:decimal) then
  xs:decimal($value)
else
  0.0
```

### cast as

Converts a value to a different type. Raises an error if the conversion fails.

```xquery
"42" cast as xs:integer          (: 42 :)
"3.14" cast as xs:decimal        (: 3.14 :)
"2026-03-19" cast as xs:date     (: xs:date value :)
42 cast as xs:string             (: "42" :)
```

**C# parallel:** Explicit casts:
```csharp
(int)"42"          // InvalidCast — C# can't do this
int.Parse("42")    // 42 — closer equivalent
(decimal)42        // 42m
```

### treat as

Asserts that a value is a certain type **without converting it**. If the value doesn't match, it raises a type error. This is a compile-time/static-type hint, not a runtime conversion.

```xquery
$value treat as xs:integer
```

`treat as` is useful when the static type checker can't infer the type, but you know it at development time:

```xquery
(: The XQuery engine might not know that $data/age is always an integer :)
let $age := ($data/age) treat as xs:integer
return $age + 1
```

**C# parallel:** Somewhat like a direct cast `(int)value` — it asserts the type without conversion:
```csharp
int age = (int)data.Age;  // throws InvalidCastException if wrong type
```

### Summary Table

| Expression | Purpose | On Failure |
|------------|---------|------------|
| `instance of` | Test if value matches type | Returns `false` |
| `castable as` | Test if value can be converted | Returns `false` |
| `cast as` | Convert value to type | Raises error |
| `treat as` | Assert value is type (no conversion) | Raises error |

---

## Type Promotion

XQuery automatically promotes (widens) certain types during operations. Understanding this prevents surprises.

### Numeric Promotion

```
xs:integer → xs:decimal → xs:float → xs:double
```

When you mix numeric types in arithmetic, the narrower type promotes:

```xquery
42 + 3.14        (: integer + decimal → decimal: 45.14 :)
42 + 3.14e0      (: integer + double → double: 4.514E1 :)
```

### String/URI Promotion

```
xs:anyURI → xs:string
```

URIs can be used wherever strings are expected:

```xquery
let $uri := xs:anyURI("https://example.com")
return contains($uri, "example")   (: true — URI promoted to string :)
```

### Subtype Substitution

A subtype can always be used where a supertype is expected:

```xquery
(: xs:integer is a subtype of xs:decimal :)
declare function local:add-tax($amount as xs:decimal) as xs:decimal {
  $amount * 1.08
};

local:add-tax(100)   (: passing xs:integer where xs:decimal expected — OK :)
```

### No Implicit Node-to-Atomic Promotion

Unlike some operations, general function calls do **not** automatically extract text from nodes:

```xquery
(: This works — comparison atomizes automatically :)
//product/price > 50

(: This might fail — string function expects xs:string?, gets element :)
declare function local:greet($name as xs:string) as xs:string {
  "Hello, " || $name
};
local:greet(//user/name)  (: type error if //user/name returns an element :)
local:greet(string(//user/name))  (: correct — explicit conversion :)
```

Be explicit about conversions from nodes to atomic values using `string()`, `data()`, or `xs:decimal()`. This is one of the most common sources of type errors for developers new to XQuery.
