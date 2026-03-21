---
title: Data Types
description: XPath's type system — atomic types, sequences, type casting, and schema interaction
sort: 4
---

# Data Types

XPath has a richer type system than JSON or most dynamically-typed languages. Understanding it prevents subtle bugs in comparisons, function calls, and XSLT template matching.

## Contents

- [The Type Hierarchy](#the-type-hierarchy)
- [Atomic Types in Practice](#atomic-types-in-practice)
- [Type Casting](#type-casting)
- [Sequence Types](#sequence-types)
- [Type Testing](#type-testing)
- [Common Type Pitfalls](#common-type-pitfalls)

---

## The Type Hierarchy

Every value in XPath is an **item** in a **sequence**. Items are either **nodes** (from the XML tree) or **atomic values** (strings, numbers, dates, etc.).

```
item()
├── node()
│   ├── document-node()
│   ├── element()
│   ├── attribute()
│   ├── text()
│   ├── comment()
│   ├── processing-instruction()
│   └── namespace-node()
├── xs:anyAtomicType
│   ├── xs:string
│   ├── xs:boolean
│   ├── xs:decimal
│   │   └── xs:integer
│   │       ├── xs:long
│   │       │   └── xs:int
│   │       │       └── xs:short
│   │       │           └── xs:byte
│   │       └── xs:nonNegativeInteger
│   │           └── xs:positiveInteger
│   ├── xs:double
│   ├── xs:float
│   ├── xs:date
│   ├── xs:dateTime
│   ├── xs:time
│   ├── xs:duration
│   │   ├── xs:dayTimeDuration
│   │   └── xs:yearMonthDuration
│   ├── xs:anyURI
│   ├── xs:QName
│   ├── xs:hexBinary
│   ├── xs:base64Binary
│   └── xs:untypedAtomic
├── function(*)
├── map(*)
└── array(*)
```

**C# parallel:** This is like the .NET type hierarchy (`object` → `ValueType` → `int`, `string`, `DateTime`, etc.), but with date/time types as first-class citizens rather than library types.

---

## Atomic Types in Practice

### Numeric Types

XPath has four numeric types with automatic promotion:

| Type | Range | Precision | C# Equivalent |
|------|-------|-----------|---------------|
| `xs:integer` | Arbitrary | Exact | `BigInteger` (unbounded) |
| `xs:decimal` | Arbitrary | Exact | `decimal` |
| `xs:float` | ±3.4 × 10³⁸ | ~7 digits | `float` |
| `xs:double` | ±1.7 × 10³⁰⁸ | ~15 digits | `double` |

**Promotion rules** (automatic, like C#):
```
integer → decimal → float → double
```

```xpath
5 + 3           => 8          (: integer + integer = integer :)
5 + 3.0         => 8.0        (: integer + decimal = decimal :)
5 + 3.0e0       => 8.0e0      (: integer + double = double :)
```

**The `xs:untypedAtomic` gotcha:** When you read a value from an XML element or attribute without a schema, it's `xs:untypedAtomic` — not `xs:string`. XPath automatically casts `untypedAtomic` to the required type in comparisons and arithmetic:

```xpath
<price>39.99</price>

(: //price is xs:untypedAtomic, automatically cast to xs:double for comparison :)
//price > 30   => true
```

This is convenient but means type errors surface at runtime, not compile time.

### String Type

Strings in XPath are sequences of Unicode characters. They're immutable, like C# strings.

```xpath
"hello"                        (: string literal :)
'hello'                        (: also valid — single or double quotes :)
""                             (: empty string :)
```

**String vs untypedAtomic:** An element's text content is `xs:untypedAtomic`, not `xs:string`. In most contexts this doesn't matter because they convert automatically. But `xs:string` values compare using collation, while `xs:untypedAtomic` values promote to the type of the other operand.

### Boolean Type

XPath booleans behave like C# booleans, but XPath has [effective boolean value](functions/boolean.md) rules that automatically convert other types:

```xpath
boolean("hello")   => true    (: non-empty string :)
boolean("")        => false   (: empty string :)
boolean(42)        => true    (: non-zero :)
boolean(0)         => false   (: zero :)
```

### Date and Time Types

These are first-class types — not strings:

```xpath
xs:date("2026-03-19")                    (: date :)
xs:time("14:30:00")                      (: time :)
xs:dateTime("2026-03-19T14:30:00")       (: date + time :)
xs:duration("P1Y2M3D")                   (: duration :)
xs:dayTimeDuration("PT5H30M")            (: days/hours/minutes/seconds :)
xs:yearMonthDuration("P1Y6M")            (: years/months :)
```

**Date arithmetic works natively:**
```xpath
xs:date("2026-03-19") + xs:dayTimeDuration("P7D")
=> 2026-03-26          (: add 7 days :)

xs:date("2026-12-31") - xs:date("2026-01-01")
=> P365D               (: difference as duration :)

xs:date("2026-03-19") > xs:date("2025-12-25")
=> true                (: date comparison :)
```

In C#, you'd need `DateTime.AddDays(7)`, `date2 - date1`, etc. XPath uses standard operators.

---

## Type Casting

### Explicit Casting with Constructor Functions

```xpath
xs:integer("42")           => 42
xs:date("2026-03-19")     => typed date
xs:double(42)              => 42.0e0
xs:string(42)              => "42"
```

See [Type Constructors](functions/type-constructors.md) for the full list.

### The `cast as` Expression

An alternative syntax for type casting:

```xpath
"42" cast as xs:integer       => 42
42 cast as xs:string          => "42"
"true" cast as xs:boolean     => true
```

### The `castable as` Test

Tests whether a cast would succeed without actually performing it:

```xpath
"42" castable as xs:integer     => true
"abc" castable as xs:integer    => false
"2026-03-19" castable as xs:date => true
```

**C# equivalent:** `int.TryParse("42", out _)`

**Practical pattern — safe type conversion:**
```xpath
if ("42" castable as xs:integer)
then xs:integer("42")
else 0
```

### The `treat as` Assertion

Asserts a type at compile time without converting. Raises an error if the type doesn't match at runtime:

```xpath
$value treat as xs:integer    (: assert $value is an integer :)
```

**C# equivalent:** `(int)value` — a cast that throws `InvalidCastException` on failure.

### The `instance of` Test

Tests whether a value is of a given type:

```xpath
42 instance of xs:integer         => true
42 instance of xs:string          => false
"hello" instance of xs:string     => true
(1, 2, 3) instance of xs:integer+ => true  (: sequence of one or more integers :)
```

**C# equivalent:** `value is int`

---

## Sequence Types

Sequence types describe the structure of sequences. They're used in function signatures, variable declarations, and type tests.

### Occurrence Indicators

| Indicator | Meaning | C# Equivalent |
|-----------|---------|---------------|
| (none) | Exactly one | `T` |
| `?` | Zero or one | `T?` or `Nullable<T>` |
| `*` | Zero or more | `IEnumerable<T>` |
| `+` | One or more | (no direct equivalent — non-empty enumerable) |

```xpath
xs:integer             (: exactly one integer :)
xs:integer?            (: zero or one integer :)
xs:integer*            (: zero or more integers :)
xs:integer+            (: one or more integers :)
item()*                (: any sequence of any items :)
node()                 (: exactly one node :)
element(book)          (: exactly one element named "book" :)
```

### Function Types

Functions are first-class values with typed signatures:

```xpath
function(xs:integer) as xs:integer         (: function taking and returning an integer :)
function(xs:string, xs:string) as xs:boolean (: predicate on two strings :)
function(*) as item()*                      (: any function :)
```

**C# equivalent:** `Func<int, int>`, `Func<string, string, bool>`

### Map and Array Types

```xpath
map(xs:string, xs:integer)     (: map from strings to integers :)
map(*)                          (: any map :)
array(xs:string)               (: array of strings :)
array(*)                        (: any array :)
```

**C# equivalent:** `Dictionary<string, int>`, `List<string>`

---

## Type Testing

### `instance of`

Runtime type check:

```xpath
let $value := //price/text()
return
  if ($value instance of xs:decimal) then "decimal"
  else if ($value instance of xs:string) then "string"
  else "unknown"
```

### `type()` (XPath 4.0)

Returns the type name as a string:

```xpath
type(42)                   => "xs:integer"
type("hello")              => "xs:string"
type(xs:date("2026-03-19")) => "xs:date"
type(//price)              => type of the price node's value
```

**C# equivalent:** `value.GetType().Name`

---

## Common Type Pitfalls

### 1. Untyped Attribute Comparisons

```xpath
(: @price is xs:untypedAtomic, not a number :)
//item[@price > 10]          (: works — untypedAtomic auto-casts to double :)
//item[@price > "10"]        (: WRONG — string comparison! "9" > "10" is true :)
```

**Rule:** When comparing with a number literal, XPath casts the untyped value to a number. When comparing with a string literal, it does string comparison. Be explicit about which you want.

### 2. Empty Sequence vs Empty String

```xpath
() = ""                      (: false — empty sequence is not empty string :)
string(())                   => ""   (: but converting empty sequence gives empty string :)
//nonexistent = ""           (: false — no nodes, not empty text :)
//nonexistent/text() = ""   (: false for the same reason :)
```

### 3. Numeric String Comparison

```xpath
"9" > "10"                   => true   (: string comparison — "9" sorts after "1" :)
9 > 10                       => false  (: numeric comparison :)
xs:integer("9") > xs:integer("10")  => false  (: explicit numeric :)
```

**Rule:** If you want numeric comparison, make sure at least one operand is a number.

### 4. Date String Comparison

```xpath
"2026-03-19" > "2025-12-25"  => true   (: works by accident — ISO format sorts correctly :)
xs:date("2026-03-19") > xs:date("2025-12-25")  => true  (: correct — typed date comparison :)
```

ISO 8601 date strings happen to sort correctly as strings, but this is coincidental. Always use typed dates for reliable comparison, especially with non-ISO formats.

### 5. Division Returns Decimal, Not Integer

```xpath
10 div 3     => 3.333...   (: not 3! :)
10 idiv 3    => 3           (: use idiv for integer division :)
```

**C# difference:** In C#, `10 / 3` returns `3` (integer division when both operands are integers). XPath's `div` always returns a decimal/double result.
