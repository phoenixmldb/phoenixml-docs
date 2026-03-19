---
title: User-Defined Functions
description: "xsl:function — defining reusable functions callable from XPath expressions"
sort: 9
---

# User-Defined Functions

`xsl:function` lets you define custom functions that you can call from any XPath expression — in `select`, `test`, `match`, AVTs, sort keys, and predicates. Unlike templates, which process nodes and produce output, functions take arguments and return values. They are the XSLT equivalent of static utility methods.

## Contents

- [xsl:function](#xslfunction)
- [Function Parameters](#function-parameters)
- [Returning Values](#returning-values)
- [Calling Functions](#calling-functions)
- [Recursive Functions](#recursive-functions)
- [Higher-Order Functions](#higher-order-functions)
- [Function Visibility in Packages](#function-visibility-in-packages)
- [Caching and Side Effects](#caching-and-side-effects)
- [Practical Examples](#practical-examples)

---

## xsl:function

A function is a top-level declaration (child of `xsl:stylesheet`) with a namespaced name, optional parameters, and a body that produces a return value.

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:my="http://example.com/functions"
                version="3.0">

  <xsl:function name="my:format-price" as="xs:string">
    <xsl:param name="amount" as="xs:decimal"/>
    <xsl:param name="currency" as="xs:string"/>
    <xsl:sequence select="concat($currency, ' ', format-number($amount, '#,##0.00'))"/>
  </xsl:function>

</xsl:stylesheet>
```

### Key Attributes

| Attribute | Description |
|-----------|-------------|
| `name` | Required. Must be a prefixed QName (e.g., `my:format-price`). The prefix prevents collisions with built-in XPath functions. |
| `as` | Return type. Optional but strongly recommended. Examples: `xs:string`, `xs:integer`, `element(product)*`, `map(*)` |
| `visibility` | Package visibility: `public`, `private`, `final`, `abstract`. Default is `public`. |
| `override-extension-function` | `yes` or `no`. Whether this function overrides an extension function with the same name. Default `yes`. |
| `cache` | `yes` or `no`. Enables memoization (XSLT 3.0). |
| `new-each-time` | `yes`, `no`, or `maybe`. Controls side-effect assumptions. |

### Naming Rules

Function names **must** use a namespace prefix. This is a hard requirement — unprefixed function names are reserved for the built-in XPath function library:

```xml
<!-- CORRECT: prefixed name -->
<xsl:function name="my:discount">...</xsl:function>

<!-- ERROR: unprefixed name — conflicts with built-in function namespace -->
<xsl:function name="discount">...</xsl:function>
```

Choose a namespace URI for your project's functions and declare it on the stylesheet:

```xml
<xsl:stylesheet xmlns:fn="http://example.com/catalog/functions" ...>
  <xsl:function name="fn:is-premium" as="xs:boolean">
    <xsl:param name="product" as="element(product)"/>
    <xsl:sequence select="$product/price > 100"/>
  </xsl:function>
</xsl:stylesheet>
```

**C# parallel:** The namespace requirement is like C# namespaces — you must qualify your types to avoid collisions with `System.*`.

---

## Function Parameters

Parameters are declared with `xsl:param` inside the function body, in the order they will be passed by the caller. Unlike template parameters, function parameters are always positional and cannot have defaults.

```xml
<xsl:function name="my:tax" as="xs:decimal">
  <xsl:param name="price" as="xs:decimal"/>
  <xsl:param name="rate" as="xs:decimal"/>
  <xsl:sequence select="$price * $rate"/>
</xsl:function>

<!-- Called as: my:tax(29.99, 0.08) -->
```

### Arity (Parameter Count)

XSLT allows function overloading by arity — you can define multiple functions with the same name but different numbers of parameters:

```xml
<!-- One-argument version: uses default tax rate -->
<xsl:function name="my:tax" as="xs:decimal">
  <xsl:param name="price" as="xs:decimal"/>
  <xsl:sequence select="$price * 0.08"/>
</xsl:function>

<!-- Two-argument version: custom tax rate -->
<xsl:function name="my:tax" as="xs:decimal">
  <xsl:param name="price" as="xs:decimal"/>
  <xsl:param name="rate" as="xs:decimal"/>
  <xsl:sequence select="$price * $rate"/>
</xsl:function>
```

Now `my:tax(29.99)` calls the one-argument version and `my:tax(29.99, 0.10)` calls the two-argument version.

**C# parallel:** Method overloading:

```csharp
static decimal Tax(decimal price) => price * 0.08m;
static decimal Tax(decimal price, decimal rate) => price * rate;
```

### Typing Parameters

Always declare types with `as`. Without it, the parameter accepts any value, which makes errors harder to diagnose:

```xml
<!-- Typed: error if called with wrong type -->
<xsl:function name="my:format-date" as="xs:string">
  <xsl:param name="date" as="xs:date"/>
  <xsl:sequence select="format-date($date, '[MNn] [D], [Y]')"/>
</xsl:function>

<!-- Untyped: accepts anything, may fail unpredictably -->
<xsl:function name="my:format-date">
  <xsl:param name="date"/>
  <xsl:sequence select="format-date($date, '[MNn] [D], [Y]')"/>
</xsl:function>
```

---

## Returning Values

Functions return whatever their body produces. Use `xsl:sequence` to return typed values:

```xml
<!-- Return a string -->
<xsl:function name="my:full-name" as="xs:string">
  <xsl:param name="person" as="element(person)"/>
  <xsl:sequence select="concat($person/first-name, ' ', $person/last-name)"/>
</xsl:function>

<!-- Return a boolean -->
<xsl:function name="my:is-in-stock" as="xs:boolean">
  <xsl:param name="product" as="element(product)"/>
  <xsl:sequence select="$product/stock > 0"/>
</xsl:function>

<!-- Return a sequence of nodes -->
<xsl:function name="my:active-products" as="element(product)*">
  <xsl:param name="catalog" as="element(catalog)"/>
  <xsl:sequence select="$catalog/product[@status = 'active']"/>
</xsl:function>

<!-- Return a map -->
<xsl:function name="my:product-summary" as="map(xs:string, item()*)">
  <xsl:param name="products" as="element(product)*"/>
  <xsl:sequence select="map {
    'count': count($products),
    'total': sum($products/price),
    'avg': avg($products/price)
  }"/>
</xsl:function>
```

### Do Not Use xsl:value-of in Functions

This is a common mistake. `xsl:value-of` creates a text node, not a typed value. If your function declares `as="xs:integer"`, returning via `xsl:value-of` will fail because a text node is not an integer:

```xml
<!-- WRONG: returns a text node, not an integer -->
<xsl:function name="my:double" as="xs:integer">
  <xsl:param name="n" as="xs:integer"/>
  <xsl:value-of select="$n * 2"/>
</xsl:function>

<!-- RIGHT: returns the integer value -->
<xsl:function name="my:double" as="xs:integer">
  <xsl:param name="n" as="xs:integer"/>
  <xsl:sequence select="$n * 2"/>
</xsl:function>
```

**C# parallel:** `xsl:sequence` is `return value;`. `xsl:value-of` is `return value.ToString();` — it loses the type.

### Multi-Step Return Values

When the return value requires multiple instructions to construct, the function body is a sequence constructor — all items produced by the body form the return value:

```xml
<xsl:function name="my:price-label" as="xs:string">
  <xsl:param name="product" as="element(product)"/>
  <xsl:choose>
    <xsl:when test="$product/@on-sale = 'true'">
      <xsl:sequence select="concat('SALE: $', format-number($product/price * 0.8, '#,##0.00'))"/>
    </xsl:when>
    <xsl:when test="$product/price > 100">
      <xsl:sequence select="concat('$', format-number($product/price, '#,##0.00'), ' (Premium)')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:sequence select="concat('$', format-number($product/price, '#,##0.00'))"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:function>
```

---

## Calling Functions

Functions are called from XPath expressions, which means they can appear anywhere an expression is allowed:

```xml
<!-- In a select expression -->
<xsl:value-of select="my:format-price(price, 'USD')"/>

<!-- In a predicate -->
<xsl:for-each select="product[my:is-in-stock(.)]">

<!-- In a sort key -->
<xsl:sort select="my:sort-rank(.)"/>

<!-- In an AVT -->
<span class="{my:status-class(@status)}">

<!-- In an xsl:if test -->
<xsl:if test="my:is-premium(.)">
  <span class="badge">Premium</span>
</xsl:if>

<!-- In another function -->
<xsl:function name="my:total-with-tax" as="xs:decimal">
  <xsl:param name="price" as="xs:decimal"/>
  <xsl:sequence select="$price + my:tax($price)"/>
</xsl:function>

<!-- In a variable -->
<xsl:variable name="summary" select="my:product-summary(//product)"/>
```

### Context Node in Functions

Unlike templates, functions do **not** have a context node. Inside a function body, `.` (dot) is not meaningful unless you explicitly pass a node as a parameter:

```xml
<!-- WRONG: what is "." inside the function? -->
<xsl:function name="my:bad-example" as="xs:string">
  <xsl:sequence select="./name"/>  <!-- Error or meaningless -->
</xsl:function>

<!-- RIGHT: pass the node explicitly -->
<xsl:function name="my:product-name" as="xs:string">
  <xsl:param name="product" as="element(product)"/>
  <xsl:sequence select="$product/name"/>
</xsl:function>
```

**C# parallel:** Functions are like static methods — they have no `this` reference. You must pass everything they need as arguments.

---

## Recursive Functions

Since XSLT variables are immutable, recursion replaces loops for algorithms that need accumulating state. Functions can call themselves.

### Simple Recursion

```xml
<xsl:function name="my:factorial" as="xs:integer">
  <xsl:param name="n" as="xs:integer"/>
  <xsl:sequence select="if ($n le 1) then 1 else $n * my:factorial($n - 1)"/>
</xsl:function>

<!-- my:factorial(5) returns 120 -->
```

### Building Strings with Recursion

```xml
<!-- Repeat a string N times -->
<xsl:function name="my:repeat" as="xs:string">
  <xsl:param name="str" as="xs:string"/>
  <xsl:param name="count" as="xs:integer"/>
  <xsl:sequence select="if ($count le 0) then ''
                         else concat($str, my:repeat($str, $count - 1))"/>
</xsl:function>

<!-- my:repeat('*', 5) returns '*****' -->
<!-- my:repeat('ab', 3) returns 'ababab' -->
```

### Tree Traversal

```xml
<!-- Compute the depth of a node in the tree -->
<xsl:function name="my:depth" as="xs:integer">
  <xsl:param name="node" as="node()"/>
  <xsl:sequence select="if ($node/parent::*) then 1 + my:depth($node/parent::*)
                         else 0"/>
</xsl:function>
```

### Tail Recursion Optimization

Many XSLT processors optimize tail-recursive functions (where the recursive call is the last operation). Write your recursive functions in tail-recursive form when possible:

```xml
<!-- Tail-recursive factorial -->
<xsl:function name="my:factorial" as="xs:integer">
  <xsl:param name="n" as="xs:integer"/>
  <xsl:sequence select="my:factorial-helper($n, 1)"/>
</xsl:function>

<xsl:function name="my:factorial-helper" as="xs:integer">
  <xsl:param name="n" as="xs:integer"/>
  <xsl:param name="acc" as="xs:integer"/>
  <xsl:sequence select="if ($n le 1) then $acc
                         else my:factorial-helper($n - 1, $n * $acc)"/>
</xsl:function>
```

**C# parallel:** This is like writing a loop as a recursive method — common in functional C# or when using LINQ's `Aggregate`:

```csharp
static int Factorial(int n) => Factorial(n, 1);
static int Factorial(int n, int acc) => n <= 1 ? acc : Factorial(n - 1, n * acc);
```

---

## Higher-Order Functions

XSLT 3.0 supports higher-order functions — you can pass functions as arguments to other functions. This enables powerful abstractions like map, filter, and reduce over sequences.

### Function Items

A named function can be referenced as a value using the `function-name#arity` syntax:

```xml
<!-- Get a reference to the built-in contains() function (arity 2) -->
<xsl:variable name="fn" select="contains#2"/>

<!-- Get a reference to a user-defined function -->
<xsl:variable name="formatter" select="my:format-price#2"/>
```

### Passing Functions as Arguments

```xml
<!-- A generic "apply to each" function -->
<xsl:function name="my:map-items" as="xs:string*">
  <xsl:param name="items" as="item()*"/>
  <xsl:param name="fn" as="function(item()) as xs:string"/>
  <xsl:sequence select="for $item in $items return $fn($item)"/>
</xsl:function>

<!-- Formatter functions -->
<xsl:function name="my:as-currency" as="xs:string">
  <xsl:param name="item" as="item()"/>
  <xsl:sequence select="concat('$', format-number(number($item), '#,##0.00'))"/>
</xsl:function>

<xsl:function name="my:as-percentage" as="xs:string">
  <xsl:param name="item" as="item()"/>
  <xsl:sequence select="concat(format-number(number($item) * 100, '#,##0.0'), '%')"/>
</xsl:function>

<!-- Usage -->
<xsl:variable name="formatted-prices"
              select="my:map-items(//product/price, my:as-currency#1)"/>
```

### Anonymous Functions (Inline Functions)

XSLT 3.0 also supports anonymous functions (lambda expressions) using the XPath `function()` syntax:

```xml
<!-- Sort products by a custom key using an anonymous function -->
<xsl:variable name="price-extractor" select="function($p) { $p/price }"/>

<!-- Filter with an anonymous predicate -->
<xsl:variable name="expensive" select="
  for-each(//product, function($p) {
    if ($p/price > 100) then $p else ()
  })"/>
```

**C# parallel:** Higher-order functions map directly to C#'s `Func<T>` and lambda expressions:

```csharp
// Function reference
Func<decimal, string> formatter = FormatPrice;

// Lambda
var expensive = products.Where(p => p.Price > 100);

// Passing functions
var formatted = products.Select(p => FormatPrice(p.Price));
```

---

## Function Visibility in Packages

When using XSLT packages (modular stylesheet libraries), you control which functions are visible to importing stylesheets with the `visibility` attribute:

| Visibility | Description |
|------------|-------------|
| `public` | Callable by any stylesheet that uses this package. Default. |
| `private` | Only callable within the defining package. Not visible to importers. |
| `final` | Public, but cannot be overridden by the using stylesheet. |
| `abstract` | Must be overridden by the using stylesheet. Has no body. |

```xml
<!-- In the package -->
<xsl:package name="http://example.com/utils" version="1.0">

  <!-- Available everywhere -->
  <xsl:function name="util:format-date" as="xs:string" visibility="public">
    <xsl:param name="date" as="xs:date"/>
    <xsl:sequence select="format-date($date, '[MNn] [D], [Y]')"/>
  </xsl:function>

  <!-- Internal helper — not visible outside the package -->
  <xsl:function name="util:pad-zero" as="xs:string" visibility="private">
    <xsl:param name="n" as="xs:integer"/>
    <xsl:sequence select="if ($n lt 10) then concat('0', $n) else string($n)"/>
  </xsl:function>

  <!-- Public but cannot be overridden -->
  <xsl:function name="util:version" as="xs:string" visibility="final">
    <xsl:sequence select="'2.1.0'"/>
  </xsl:function>

  <!-- Must be implemented by the using stylesheet -->
  <xsl:function name="util:site-url" as="xs:string" visibility="abstract"/>

</xsl:package>
```

**C# parallel:**

| XSLT Visibility | C# Equivalent |
|------------------|---------------|
| `public` | `public virtual` |
| `private` | `private` |
| `final` | `public sealed` (or non-virtual) |
| `abstract` | `public abstract` |

---

## Caching and Side Effects

### The cache Attribute

XSLT 3.0 introduces the `cache` attribute for memoization. When `cache="yes"`, the processor stores the result of each unique combination of arguments and returns the cached result on subsequent calls with the same arguments:

```xml
<xsl:function name="my:expensive-lookup" as="xs:string" cache="yes">
  <xsl:param name="code" as="xs:string"/>
  <xsl:sequence select="doc('lookup-table.xml')//entry[@code = $code]/@description"/>
</xsl:function>
```

If `my:expensive-lookup('A001')` is called 1000 times (once per product in the catalog), the document lookup happens only once. Subsequent calls return the cached result.

**C# parallel:** `ConcurrentDictionary` as a memoization cache:

```csharp
private static readonly ConcurrentDictionary<string, string> _cache = new();

static string ExpensiveLookup(string code) =>
    _cache.GetOrAdd(code, c => LookupTable.Entries[c].Description);
```

### The new-each-time Attribute

This attribute tells the processor whether the function might have side effects or depend on context that changes between calls:

| Value | Meaning |
|-------|---------|
| `yes` | The function may return different results for the same arguments (has side effects or depends on external state). The processor must call it every time. |
| `no` | The function is pure — same arguments always produce the same result. The processor may optimize calls away or reorder them. |
| `maybe` | Default. The processor makes no assumptions. |

```xml
<!-- Pure function — safe to cache and reorder -->
<xsl:function name="my:tax" as="xs:decimal" new-each-time="no">
  <xsl:param name="amount" as="xs:decimal"/>
  <xsl:sequence select="$amount * 0.08"/>
</xsl:function>

<!-- Impure function — depends on current date -->
<xsl:function name="my:is-expired" as="xs:boolean" new-each-time="yes">
  <xsl:param name="date" as="xs:date"/>
  <xsl:sequence select="$date lt current-date()"/>
</xsl:function>
```

**Tip:** If your function only depends on its parameters (no global variables, no `doc()`, no `current-date()`), set `new-each-time="no"` and consider `cache="yes"`. This gives the processor maximum freedom to optimize.

---

## Practical Examples

### Slug Generator

```xml
<xsl:function name="my:slugify" as="xs:string">
  <xsl:param name="text" as="xs:string"/>
  <xsl:variable name="lower" select="lower-case($text)"/>
  <xsl:variable name="cleaned" select="replace($lower, '[^a-z0-9\s-]', '')"/>
  <xsl:variable name="dashed" select="replace(normalize-space($cleaned), '\s+', '-')"/>
  <xsl:sequence select="$dashed"/>
</xsl:function>

<!-- Usage: my:slugify('Widget Pro 2000!') returns 'widget-pro-2000' -->
```

### Safe Division

```xml
<xsl:function name="my:safe-divide" as="xs:decimal">
  <xsl:param name="numerator" as="xs:decimal"/>
  <xsl:param name="denominator" as="xs:decimal"/>
  <xsl:param name="default" as="xs:decimal"/>
  <xsl:sequence select="if ($denominator = 0) then $default
                         else $numerator div $denominator"/>
</xsl:function>

<!-- Usage: my:safe-divide($total, $count, 0) -->
```

### CSS Class Builder

```xml
<xsl:function name="my:classes" as="xs:string">
  <xsl:param name="pairs" as="map(xs:string, xs:boolean)"/>
  <xsl:sequence select="string-join(
    map:keys($pairs)[map:get($pairs, .)],
    ' '
  )"/>
</xsl:function>

<!-- Usage -->
<div class="{my:classes(map {
  'product': true(),
  'on-sale': @on-sale = 'true',
  'featured': @featured = 'true',
  'out-of-stock': stock = 0
})}">
```

### Recursive Path Builder

```xml
<!-- Build a breadcrumb path string from a node's ancestry -->
<xsl:function name="my:breadcrumb" as="xs:string">
  <xsl:param name="node" as="element()"/>
  <xsl:variable name="ancestors" select="$node/ancestor-or-self::*[not(self::root)]"/>
  <xsl:sequence select="string-join($ancestors/name, ' > ')"/>
</xsl:function>

<!-- Given: <root><category name="..."><subcategory><product>
     Returns: "category > subcategory > product" -->
```

### Function Composition with Higher-Order Functions

```xml
<!-- Compose two functions into one -->
<xsl:function name="my:compose" as="function(item()) as item()">
  <xsl:param name="f" as="function(item()) as item()"/>
  <xsl:param name="g" as="function(item()) as item()"/>
  <xsl:sequence select="function($x) { $f($g($x)) }"/>
</xsl:function>

<!-- Usage: create a "format then uppercase" function -->
<xsl:variable name="shout-price"
              select="my:compose(upper-case#1, my:as-currency#1)"/>
<!-- $shout-price(29.99) returns "$29.99" uppercased to "$29.99" -->
```

**C# parallel summary:**

| XSLT | C# |
|------|-----|
| `xsl:function name="my:f"` | `static T F(...)` |
| `xsl:param name="x" as="xs:integer"` | `int x` parameter |
| `xsl:sequence select="..."` | `return ...;` |
| `my:f#2` (function reference) | `Func<int, int, string> f = F;` |
| `function($x) { ... }` (anonymous) | `x => ...` (lambda) |
| `cache="yes"` | Memoization with `ConcurrentDictionary` |
| `visibility="private"` | `private static` |
