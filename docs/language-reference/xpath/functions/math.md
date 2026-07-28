---
title: Math Functions
description: XPath math functions — trigonometry, logarithms, exponents, and constants
sort: 9
---

# Math Functions

The `math:` namespace provides mathematical functions beyond basic arithmetic.

All functions are in the `math:` namespace: `xmlns:math="http://www.w3.org/2005/xpath-functions/math"`.

> For .NET developers: the `math:` namespace maps directly to `System.Math`. `math:pi` maps to `Math.PI`. `math:e` maps to `Math.E`. `math:exp` maps to `Math.Exp`. `math:exp10` maps to `Math.Pow(10, x)`. `math:log` maps to `Math.Log`. `math:log10` maps to `Math.Log10`. `math:pow` maps to `Math.Pow`. `math:sqrt` maps to `Math.Sqrt`. `math:sin`, `math:cos`, and `math:tan` map to `Math.Sin`, `Math.Cos`, and `Math.Tan`. `math:asin`, `math:acos`, and `math:atan` map to `Math.Asin`, `Math.Acos`, and `Math.Atan`. `math:atan2` maps to `Math.Atan2`, with the same `(y, x)` parameter order.

---

## Constants

### math:pi()

Returns the value of π.

```xpath
math:pi()   => 3.141592653589793
```

---

### math:e()

Returns Euler's number. New in XPath 4.0.

```xpath
math:e()   => 2.718281828459045
```

---

## Exponential and Logarithmic

### math:exp()

Returns *e* raised to the given power.

```xpath
math:exp(1)    => 2.718281828459045  (: e^1 :)
math:exp(0)    => 1.0
math:exp(2)    => 7.38905609893065
```

---

### math:exp10()

Returns 10 raised to the given power.

```xpath
math:exp10(2)   => 100
math:exp10(3)   => 1000
math:exp10(0)   => 1
```

---

### math:log()

Returns the natural logarithm (base *e*).

```xpath
math:log(1)                => 0
math:log(math:e())         => 1
math:log(10)               => 2.302585...
```

---

### math:log10()

Returns the base-10 logarithm.

```xpath
math:log10(100)    => 2
math:log10(1000)   => 3
math:log10(1)      => 0
```

---

### math:pow()

Raises a number to a power.

```xpath
math:pow(2, 10)    => 1024
math:pow(3, 0)     => 1
math:pow(25, 0.5)  => 5  (: square root :)
```

---

### math:sqrt()

Returns the square root.

```xpath
math:sqrt(25)    => 5
math:sqrt(2)     => 1.4142135623730951
math:sqrt(0)     => 0
```

---

## Trigonometric

All angles are in radians.

### math:sin(), math:cos(), math:tan()

```xpath
math:sin(0)              => 0
math:sin(math:pi() div 2) => 1
math:cos(0)              => 1
math:cos(math:pi())      => -1
math:tan(0)              => 0
```

---

### math:asin(), math:acos(), math:atan()

These are the inverse trigonometric functions.

```xpath
math:asin(1)   => 1.5707963... (: π/2 :)
math:acos(1)   => 0
math:atan(1)   => 0.7853981... (: π/4 :)
```

---

### math:atan2()

This is the two-argument arctangent. It returns the angle in radians between the positive x-axis and the point (x, y).

```xpath
math:atan2(1, 1)    => 0.7853981... (: π/4 = 45° :)
math:atan2(0, -1)   => 3.1415926... (: π = 180° :)
```

**Note:** The parameter order is `atan2($y, $x)`.
