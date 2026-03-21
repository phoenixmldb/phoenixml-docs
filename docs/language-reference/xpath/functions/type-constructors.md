---
title: Type Constructors
description: XPath type casting and XSD type constructor functions
sort: 12
---

# Type Constructors

Type constructor functions cast values between XPath's type system (based on XML Schema Definition types). They're in the `xs:` namespace and work like explicit casts in C#.

## Why Type Constructors Exist

XPath's type system is richer than JSON's. While JSON has only strings, numbers, booleans, and null, XPath distinguishes between integers, decimals, doubles, dates, times, durations, URIs, and more. Type constructors make these conversions explicit.

```xpath
xs:integer("42")                => 42 (as an integer, not a string)
xs:date("2026-03-19")          => a typed date value
xs:double("3.14")              => 3.14 (as a double, not a decimal)
```

**C# equivalent:** Explicit casts like `(int)value`, `int.Parse("42")`, or `Convert.ToInt32("42")`.

---

## Numeric Types

### xs:integer()

```xpath
xs:integer("42")       => 42
xs:integer(3.14)       => 3     (: truncates toward zero :)
xs:integer("abc")      => ERROR (: not a valid integer :)
```

**C# equivalent:** `Convert.ToInt64("42")` or `(long)3.14`

---

### xs:decimal()

Arbitrary-precision decimal — like C#'s `decimal`.

```xpath
xs:decimal("3.14159")  => 3.14159
xs:decimal(42)         => 42.0
```

---

### xs:double()

IEEE 754 double-precision — like C#'s `double`.

```xpath
xs:double("3.14")      => 3.14
xs:double("INF")       => positive infinity
xs:double("-INF")      => negative infinity
xs:double("NaN")       => NaN
```

---

### xs:float()

IEEE 754 single-precision — like C#'s `float`.

```xpath
xs:float("3.14")       => 3.14 (single precision)
```

---

### Sub-integer Types

For schema compatibility:

| Function | Range | C# Equivalent |
|----------|-------|---------------|
| `xs:int()` | -2³¹ to 2³¹-1 | `int` |
| `xs:long()` | -2⁶³ to 2⁶³-1 | `long` |
| `xs:short()` | -32768 to 32767 | `short` |
| `xs:byte()` | -128 to 127 | `sbyte` |
| `xs:unsignedLong()` | 0 to 2⁶⁴-1 | `ulong` |
| `xs:unsignedInt()` | 0 to 2³²-1 | `uint` |
| `xs:unsignedShort()` | 0 to 65535 | `ushort` |
| `xs:unsignedByte()` | 0 to 255 | `byte` |
| `xs:positiveInteger()` | 1 to ∞ | (no C# equivalent) |
| `xs:nonNegativeInteger()` | 0 to ∞ | (no C# equivalent) |
| `xs:negativeInteger()` | -∞ to -1 | (no C# equivalent) |
| `xs:nonPositiveInteger()` | -∞ to 0 | (no C# equivalent) |

---

## String Types

### xs:string()

Converts any value to a string.

```xpath
xs:string(42)          => "42"
xs:string(true())      => "true"
```

---

### xs:normalizedString()

A string with no carriage returns, line feeds, or tabs.

### xs:token()

A normalized string with no leading/trailing spaces and no internal runs of spaces.

---

## Date and Time Types

### xs:date()

```xpath
xs:date("2026-03-19")              => a typed date
xs:date("2026-03-19-05:00")       => a date with timezone
```

**C# equivalent:** `DateOnly.Parse("2026-03-19")`

---

### xs:time()

```xpath
xs:time("14:30:00")               => a typed time
xs:time("14:30:00-05:00")         => time with timezone
```

---

### xs:dateTime()

```xpath
xs:dateTime("2026-03-19T14:30:00")         => a typed dateTime
xs:dateTime("2026-03-19T14:30:00-05:00")   => with timezone
```

**C# equivalent:** `DateTime.Parse("2026-03-19T14:30:00")` or `DateTimeOffset.Parse(...)`

---

### xs:duration()

```xpath
xs:duration("P1Y2M3DT4H5M6S")   => 1 year, 2 months, 3 days, 4 hours, 5 minutes, 6 seconds
```

---

### xs:dayTimeDuration()

Duration without year/month components.

```xpath
xs:dayTimeDuration("P5DT3H")    => 5 days, 3 hours
xs:dayTimeDuration("PT30M")     => 30 minutes
```

**C# equivalent:** `TimeSpan.FromDays(5).Add(TimeSpan.FromHours(3))`

---

### xs:yearMonthDuration()

Duration without day/time components.

```xpath
xs:yearMonthDuration("P1Y6M")   => 1 year, 6 months
```

---

### Gregorian Types

For partial date values (useful in schema validation):

```xpath
xs:gYear("2026")               => just a year
xs:gYearMonth("2026-03")       => year and month
xs:gMonth("--03")              => just a month
xs:gMonthDay("--03-19")        => month and day
xs:gDay("---19")               => just a day
```

---

## Other Types

### xs:boolean()

```xpath
xs:boolean("true")    => true
xs:boolean("1")       => true
xs:boolean("false")   => false
xs:boolean("0")       => false
```

---

### xs:anyURI()

```xpath
xs:anyURI("https://example.com")   => a typed URI
```

---

### xs:hexBinary() / xs:base64Binary()

```xpath
xs:hexBinary("48656C6C6F")            => binary data
xs:base64Binary("SGVsbG8=")           => binary data
```

---

### xs:QName()

Creates a qualified name.

```xpath
xs:QName("xs:integer")   => a QName in the xs namespace
```

---

## Type Inspection

### type()

Returns the type of a value as a string. New in XPath 4.0.

```xpath
type(42)                   => "xs:integer"
type("hello")              => "xs:string"
type(true())               => "xs:boolean"
type(xs:date("2026-03-19")) => "xs:date"
```

**C# equivalent:** `value.GetType().Name`

This is invaluable for debugging — when an XPath expression produces unexpected results, `type()` tells you what type you're actually working with.
