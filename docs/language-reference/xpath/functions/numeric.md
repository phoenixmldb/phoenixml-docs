---
title: Numeric Functions
description: XPath numeric functions — arithmetic, rounding, aggregation
sort: 2
---

# Numeric Functions

XPath's numeric functions cover rounding, absolute values, and aggregate operations over sequences.

> For C# developers: these functions map directly to `System.Math` and to LINQ aggregate methods. `round` maps to `Math.Round`, though XPath rounds half up while C# rounds half to even by default. `round-half-to-even` is C#'s default rounding mode. `floor` maps to `Math.Floor`. `ceiling` maps to `Math.Ceiling`. `abs` maps to `Math.Abs`. `sum` maps to `items.Sum()`. `avg` maps to `items.Average()`. `min` and `max` map to `items.Min()` and `items.Max()`, but also work with dates and strings, unlike C#'s versions, which require `IComparable`. `count` maps to `items.Count()` or `.Length`. `is-NaN` maps to `double.IsNaN`.

## Contents

- [Rounding and Truncation](#rounding-and-truncation)
- [Absolute Value](#absolute-value)
- [Aggregation](#aggregation)
- [Numeric Testing](#numeric-testing)

---

## Rounding and Truncation

### round()

Rounds a number to the nearest integer, or to a specified number of decimal places.

**Signature:** `round($value as xs:numeric?) as xs:numeric?`
**Signature (XPath 3.1+):** `round($value as xs:numeric?, $precision as xs:integer) as xs:numeric?`

```xpath
round(3.7)        => 4
round(3.3)        => 3
round(3.5)        => 4        (: rounds half up :)
round(-3.5)       => -3       (: rounds half toward positive infinity :)
round(3.14159, 2) => 3.14
round(1234, -2)   => 1200     (: negative precision rounds to tens, hundreds, etc. :)
```

| Value | XPath `round()` | C# `Math.Round()` |
|-------|------------------|--------------------|
| 2.5 | 3 | 2 (banker's rounding) |
| 3.5 | 4 | 4 (banker's rounding) |
| -2.5 | -2 | -2 |

To get XPath-style rounding in C#, use `Math.Round(value, MidpointRounding.AwayFromZero)`.

---

### round-half-to-even()

Rounds using banker's rounding: round half to the nearest even number. This minimizes cumulative rounding bias.

**Signature:** `round-half-to-even($value as xs:numeric?, $precision as xs:integer?) as xs:numeric?`

```xpath
round-half-to-even(2.5)      => 2       (: rounds to even :)
round-half-to-even(3.5)      => 4       (: rounds to even :)
round-half-to-even(2.45, 1)  => 2.4
round-half-to-even(2.55, 1)  => 2.6
```

**When to use:** Use this function for financial calculations, where rounding bias accumulates over many operations.

---

### floor()

Rounds down to the nearest integer, toward negative infinity.

**Signature:** `floor($value as xs:numeric?) as xs:numeric?`

```xpath
floor(3.7)    => 3
floor(3.2)    => 3
floor(-3.2)   => -4      (: toward negative infinity, not toward zero! :)
floor(-3.7)   => -4
```

---

### ceiling()

Rounds up to the nearest integer, toward positive infinity.

**Signature:** `ceiling($value as xs:numeric?) as xs:numeric?`

```xpath
ceiling(3.2)   => 4
ceiling(3.7)   => 4
ceiling(-3.2)  => -3     (: toward positive infinity :)
ceiling(-3.7)  => -3
```

**Practical example** — calculating pages needed:
```xpath
ceiling(count(//item) div 10)   (: number of pages with 10 items per page :)
```

---

## Absolute Value

### abs()

Returns the absolute value of a number.

**Signature:** `abs($value as xs:numeric?) as xs:numeric?`

```xpath
abs(-5)     => 5
abs(5)      => 5
abs(-3.14)  => 3.14
abs(0)      => 0
```

**Practical example** — finding the magnitude of a difference:
```xpath
abs(//actual - //expected)   (: deviation regardless of direction :)
```

---

## Aggregation

These functions operate on sequences.

### sum()

Returns the sum of a sequence of numbers.

**Signature:** `sum($values as xs:anyAtomicType*, $zero as xs:anyAtomicType?) as xs:anyAtomicType`

```xpath
sum((1, 2, 3, 4, 5))           => 15
sum(//item/price)               => total of all prices
sum(//order/@amount)            => total of all order amounts
sum(())                         => 0        (: empty sequence :)
sum((), 0.00)                   => 0.00     (: with explicit zero value :)
```

Given this XML:
```xml
<order>
  <item><price>9.99</price><qty>2</qty></item>
  <item><price>24.50</price><qty>1</qty></item>
  <item><price>4.99</price><qty>3</qty></item>
</order>
```

```xpath
sum(/order/item/price)     => 39.48
```

**Note:** To sum products (price × quantity), use a `for` expression: `sum(for $i in //item return $i/price * $i/qty)`.

---

### avg()

Returns the average of a sequence of numbers.

**Signature:** `avg($values as xs:anyAtomicType*) as xs:anyAtomicType?`

```xpath
avg((1, 2, 3, 4, 5))     => 3
avg(//item/price)          => average price
avg(())                    => ()    (: empty sequence returns empty :)
```

---

### min()

Returns the minimum value in a sequence.

**Signature:** `min($values as xs:anyAtomicType*, $collation as xs:string?) as xs:anyAtomicType?`

```xpath
min((3, 1, 4, 1, 5))                      => 1
min(//item/price)                           => lowest price
min(//order/@date)                          => earliest date (works with xs:date!)
min(("banana", "apple", "cherry"))         => "apple" (: string comparison :)
```

---

### max()

Returns the maximum value in a sequence.

**Signature:** `max($values as xs:anyAtomicType*, $collation as xs:string?) as xs:anyAtomicType?`

```xpath
max((3, 1, 4, 1, 5))        => 5
max(//item/price)             => highest price
max(//order/@date)            => most recent date
```

---

### count()

Returns the number of items in a sequence.

**Signature:** `count($values as item()*) as xs:integer`

```xpath
count((1, 2, 3))              => 3
count(//book)                  => number of book elements
count(//book[@category='data']) => number of data books
count(())                      => 0
```

**Practical example** — a condition based on count:
```xpath
if (count(//error) > 0) then "Errors found" else "All clear"
```

---

## Numeric Testing

### is-NaN()

Tests whether a value is NaN (Not a Number). New in XPath 4.0.

**Signature:** `is-NaN($value as xs:anyAtomicType) as xs:boolean`

```xpath
is-NaN(xs:double('NaN'))       => true
is-NaN(42)                     => false
is-NaN(0 div 0.0e0)            => true
```

**Why this exists:** The expression `$x = $x` returns `false` when `$x` is `NaN`, under IEEE 754 behavior. This result is counterintuitive. `is-NaN()` is the explicit test.
