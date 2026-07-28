---
title: Operators and Comparisons
description: XPath arithmetic, comparison, and logical operators with important semantic differences from C#
sort: 3
---

# Operators and Comparisons

XPath's operators look familiar: `+`, `-`, `=`, `<`, `and`, `or`. Several of them have different semantics than their C# counterparts. Understanding these differences prevents bugs that are hard to diagnose.

> For C# developers: XPath's arithmetic operators, type promotion, and `and`/`or` short-circuiting all match C#. The `||` string operator resembles C# string interpolation or `string.Concat()`. The `to` operator resembles `Enumerable.Range`. `union` resembles `Union()`, and `intersect`/`except` resemble `Intersect()`/`Except()`, but all three preserve document order. `some`/`every` resemble `Any()`/`All()`. The `!` operator resembles `Select()`. The `=>` operator resembles method chaining. `let` resembles a local variable declaration. XPath's `if` always requires both `then` and `else`, unlike the C# ternary `? :`.

## Contents

- [Arithmetic Operators](#arithmetic-operators)
- [Comparison Operators](#comparison-operators)
- [Logical Operators](#logical-operators)
- [String Operators](#string-operators)
- [Sequence Operators](#sequence-operators)
- [Conditional Expressions](#conditional-expressions)

---

## Arithmetic Operators

The following table lists the XPath arithmetic operators.

| Operator | XPath | C# | Example |
|----------|-------|----|---------|
| Addition | `+` | `+` | `5 + 3` → `8` |
| Subtraction | `-` | `-` | `5 - 3` → `2` |
| Multiplication | `*` | `*` | `5 * 3` → `15` |
| Division | `div` | `/` | `10 div 3` → `3.333...` |
| Integer division | `idiv` | `/` (int) | `10 idiv 3` → `3` |
| Modulus | `mod` | `%` | `10 mod 3` → `1` |
| Unary minus | `-` | `-` | `-5` → `-5` |

**Key difference:** XPath uses `div` instead of `/` for division because `/` is already used for path navigation.

```xpath
//item/price * //item/quantity              (: multiply price by quantity :)
sum(//item/price) div count(//item)         (: average price :)
count(//book) mod 10                        (: remainder for pagination :)
```

### Type Promotion

XPath automatically promotes numeric types during arithmetic:

```xpath
5 + 3.0        => 8.0    (: integer + decimal = decimal :)
5 + 3.0e0      => 8.0e0  (: integer + double = double :)
```

This promotion happens automatically during arithmetic.

---

## Comparison Operators

This is where XPath differs most from C#. XPath has **two kinds** of comparison operators.

### Value Comparisons (Strict)

Compare exactly two atomic values. Raise an error if either operand is a sequence of more than one item.

| Operator | Meaning | C# Equivalent |
|----------|---------|---------------|
| `eq` | Equal | `==` |
| `ne` | Not equal | `!=` |
| `lt` | Less than | `<` |
| `le` | Less or equal | `<=` |
| `gt` | Greater than | `>` |
| `ge` | Greater or equal | `>=` |

```xpath
5 eq 5              => true
"hello" eq "hello"  => true
5 lt 10             => true
(1, 2) eq 1         => ERROR: left operand has more than one item
```

**Use value comparisons when:** both sides are single values and the comparison needs strict, predictable behavior.

### General Comparisons (Flexible)

Compare sequences by checking if **any pair** of items satisfies the comparison. These are the `=`, `!=`, `<`, `>`, `<=`, `>=` operators.

| Operator | Meaning | Semantics |
|----------|---------|-----------|
| `=` | Exists a match | `some $a in LHS, $b in RHS satisfies $a eq $b` |
| `!=` | Exists a non-match | `some $a in LHS, $b in RHS satisfies $a ne $b` |
| `<` | Exists a less-than | `some $a in LHS, $b in RHS satisfies $a lt $b` |
| `>` | Exists a greater-than | `some $a in LHS, $b in RHS satisfies $a gt $b` |

```xpath
(1, 2, 3) = 2         => true   (: 2 is in the sequence :)
(1, 2, 3) = (2, 4)    => true   (: 2 is in both :)
(1, 2, 3) != 2         => true   (: 1 != 2, so there exists a non-match :)
```

**The `!=` trap:** In C#, `x != y` means x is not equal to y. In XPath, `(1, 2) != 2` returns `true` because one pair, `1 != 2`, does not match. This behavior surprises many developers.

```xpath
(: These are NOT equivalent! :)
(1, 2, 3) != 2          => true  (: because 1 != 2 :)
not((1, 2, 3) = 2)      => false (: because 2 = 2 :)
```

**Rule of thumb:** Use `eq`, `ne`, `lt`, etc. when comparing single values. Use `=`, `!=`, `<`, etc. when filtering against sequences or node sets.

### Comparison Type Coercion

XPath automatically converts types during comparison:

```xpath
"42" = 42               => true  (: string compared to integer — string is cast :)
@price > 30             => true  (: attribute value (string) cast to number :)
```

This is convenient but can hide bugs. If `@price` contains "N/A", the comparison will raise a runtime error.

---

## Logical Operators

### and / or

```xpath
//book[price > 20 and price < 50]       (: price between 20 and 50 :)
//book[@category='data' or @category='programming']
```

**Short-circuit evaluation:** XPath's `and` and `or` operators short-circuit.

```xpath
exists(//config) and //config/@debug = 'true'
(: if no config element exists, second part is not evaluated :)
```

### not()

`not()` is a function, not an operator:

```xpath
//book[not(@out-of-print)]              (: books without the attribute :)
//item[not(price > 100 or qty < 1)]     (: items that are affordable and in stock :)
```

### Effective Boolean Value

XPath automatically converts values to boolean in conditional contexts:

| Value | Boolean |
|-------|---------|
| `true()` | `true` |
| `false()` | `false` |
| `""` (empty string) | `false` |
| `"anything"` (non-empty string) | `true` |
| `0`, `0.0`, `NaN` | `false` |
| Any other number | `true` |
| Empty sequence `()` | `false` |
| Non-empty sequence | `true` (if first item is a node) |

As a result, the following two expressions are equivalent:

```xpath
if (//error) then "Problems found" else "All clear"
(: instead of: if (count(//error) > 0) :)
```

---

## String Operators

### String Concatenation: `||`

XPath 3.1 introduced the `||` operator for string concatenation:

```xpath
"hello" || " " || "world"           => "hello world"
//first-name || " " || //last-name  => "John Smith"
"Count: " || count(//item)          => "Count: 5"
```

**Note:** XPath 2.0 uses `concat("hello", " ", "world")` instead.

---

## Sequence Operators

### Range: `to`

Creates a sequence of consecutive integers:

```xpath
1 to 5           => (1, 2, 3, 4, 5)
3 to 7           => (3, 4, 5, 6, 7)
```

### Comma: `,`

Constructs sequences:

```xpath
(1, 2, 3)                    => sequence of three integers
("a", "b", "c")              => sequence of three strings
(//book, //article)           => all books and articles combined
```

### Union: `|` or `union`

Combines node sequences in document order, removing duplicates:

```xpath
//title | //author            => all title and author elements
//h1 union //h2 union //h3   => all heading elements
```

### Intersect and Except

```xpath
$set1 intersect $set2    (: nodes in both sets :)
$set1 except $set2       (: nodes in set1 but not set2 :)
```

---

## Conditional Expressions

### if-then-else

```xpath
if (//price > 100) then "expensive" else "affordable"

if (count(//item) > 0)
then sum(//item/price) div count(//item)
else 0
```

In C#:
```csharp
price > 100 ? "expensive" : "affordable"
```

**Note:** XPath's `if` always requires both a `then` branch and an `else` branch. XPath has no standalone `if` without `else`.

### Quantified Expressions

```xpath
some $x in (1, 2, 3) satisfies $x > 2     => true
every $x in (1, 2, 3) satisfies $x > 0    => true
every $x in (1, 2, 3) satisfies $x > 2    => false
```

### Simple Map: `!`

Applies an expression to each item in a sequence:

```xpath
(1, 2, 3) ! (. * 2)           => (2, 4, 6)
//book ! title                 => all title children of books
("hello", "world") ! upper-case(.)  => ("HELLO", "WORLD")
```

The `!` operator is more concise than `for-each()` for simple mappings.

### Arrow Operator: `=>`

Pipes a value into a function (XPath 3.1+):

```xpath
"hello world" => upper-case()              => "HELLO WORLD"
"  hello  " => normalize-space() => upper-case()  => "HELLO"
(1, 2, 3, 4, 5) => sum()                  => 15
```

In C#, the equivalent is method chaining:
```csharp
"hello world".ToUpper()
```

The arrow operator makes chains of function calls read left to right instead of inside out.

### Let Expressions

Bind a value to a variable:

```xpath
let $total := sum(//price),
    $count := count(//price)
return $total div $count
```

In C#:
```csharp
var total = prices.Sum();
var count = prices.Count();
return total / count;
```
