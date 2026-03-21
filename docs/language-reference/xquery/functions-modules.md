---
title: Functions and Modules
description: Writing reusable XQuery functions and organizing code into modules
sort: 8
---

# Functions and Modules

XQuery is a full programming language, not just a query syntax. You can define functions, organize them into modules, and build reusable libraries — much like writing class libraries in C#.

## Contents

- [User-Defined Functions](#user-defined-functions)
- [Function Features](#function-features)
- [Modules](#modules)
- [The XQuery Prolog](#the-xquery-prolog)
- [Common Patterns](#common-patterns)

---

## User-Defined Functions

### Basic Function Declaration

```xquery
declare function local:format-price($amount as xs:decimal) as xs:string {
  concat("$", format-number($amount, "#,##0.00"))
};

local:format-price(1234.5)
(: Result: "$1,234.50" :)
```

**C# equivalent:**
```csharp
static string FormatPrice(decimal amount) => $"${amount:#,##0.00}";
```

### Function Signatures

```xquery
declare function local:function-name(
  $param1 as type1,
  $param2 as type2
) as return-type {
  (: function body — an XQuery expression :)
};
```

- `local:` is the namespace prefix for local functions (not imported from a module)
- Parameter types are optional but recommended
- The return type is optional but recommended
- The body is a single expression (no statements — XQuery is functional)

### Multiple Parameters

```xquery
declare function local:price-with-tax(
  $amount as xs:decimal,
  $rate as xs:decimal
) as xs:decimal {
  round($amount * (1 + $rate), 2)
};

local:price-with-tax(99.99, 0.08)
(: Result: 107.99 :)
```

### Default Parameter Values

XQuery doesn't support default parameter values directly, but you can use function overloading:

```xquery
(: Two-argument version :)
declare function local:format-price(
  $amount as xs:decimal,
  $currency as xs:string
) as xs:string {
  switch ($currency)
    case "USD" return concat("$", format-number($amount, "#,##0.00"))
    case "EUR" return concat("€", format-number($amount, "#,##0.00"))
    default return concat(format-number($amount, "#,##0.00"), " ", $currency)
};

(: One-argument version defaults to USD :)
declare function local:format-price(
  $amount as xs:decimal
) as xs:string {
  local:format-price($amount, "USD")
};
```

---

## Function Features

### Recursive Functions

XQuery supports recursion naturally:

```xquery
declare function local:factorial($n as xs:integer) as xs:integer {
  if ($n <= 1) then 1
  else $n * local:factorial($n - 1)
};

local:factorial(5)
(: Result: 120 :)
```

**Practical recursion — flattening a hierarchy:**

```xquery
declare function local:flatten-tree($node as element()) as element()* {
  $node,
  for $child in $node/*
  return local:flatten-tree($child)
};
```

### Higher-Order Functions

Functions can take functions as parameters and return functions:

```xquery
declare function local:apply-to-all(
  $items as item()*,
  $fn as function(item()) as item()
) as item()* {
  for $item in $items
  return $fn($item)
};

local:apply-to-all((1, 2, 3), function($n) { $n * $n })
(: Result: 1, 4, 9 :)
```

**C# equivalent:**
```csharp
IEnumerable<T> ApplyToAll<T>(IEnumerable<T> items, Func<T, T> fn) =>
    items.Select(fn);
```

### Anonymous Functions (Lambdas)

```xquery
let $double := function($n) { $n * 2 }
let $add := function($a, $b) { $a + $b }
return ($double(5), $add(3, 4))
(: Result: 10, 7 :)
```

**C# equivalent:** `Func<int, int> double = n => n * 2;`

### Inline Functions with Closure

Anonymous functions capture variables from their enclosing scope:

```xquery
let $multiplier := 3
let $fn := function($n) { $n * $multiplier }
return $fn(5)
(: Result: 15 — $multiplier is captured :)
```

---

## Modules

Modules organize XQuery code into reusable libraries, like C# class libraries or namespaces.

### Library Modules

A library module declares a namespace and exports functions:

```xquery
(: file: pricing.xqm :)
module namespace pricing = "http://example.com/pricing";

declare function pricing:format-price($amount as xs:decimal) as xs:string {
  concat("$", format-number($amount, "#,##0.00"))
};

declare function pricing:with-tax(
  $amount as xs:decimal,
  $rate as xs:decimal
) as xs:decimal {
  round($amount * (1 + $rate), 2)
};

declare function pricing:discount(
  $amount as xs:decimal,
  $percent as xs:decimal
) as xs:decimal {
  round($amount * (1 - $percent div 100), 2)
};
```

### Importing Modules

Main queries import library modules:

```xquery
import module namespace pricing = "http://example.com/pricing"
  at "pricing.xqm";

for $product in //product
return <item>
  <name>{ $product/name/text() }</name>
  <price>{ pricing:format-price(xs:decimal($product/price)) }</price>
  <with-tax>{ pricing:with-tax(xs:decimal($product/price), 0.08) }</with-tax>
</item>
```

**C# parallel:**
```csharp
using Example.Pricing;
// Now use Pricing.FormatPrice(), Pricing.WithTax(), etc.
```

### Module Variables

Modules can also export variables:

```xquery
module namespace config = "http://example.com/config";

declare variable $config:tax-rate := 0.08;
declare variable $config:currency := "USD";
declare variable $config:date-format := "[MNn] [D], [Y]";
```

---

## The XQuery Prolog

Every XQuery file starts with an optional prolog that sets up the execution environment:

```xquery
xquery version "4.0";

(: Namespace declarations :)
declare namespace app = "http://example.com/app";
declare default element namespace "http://www.w3.org/1999/xhtml";

(: Module imports :)
import module namespace pricing = "http://example.com/pricing" at "pricing.xqm";

(: Variable declarations :)
declare variable $base-url := "/";
declare variable $site-title := "My Site";

(: Option declarations :)
declare option output:method "html";
declare option output:indent "yes";

(: Function declarations :)
declare function local:page-title($title as xs:string) as xs:string {
  concat($title, " — ", $site-title)
};

(: Main query body :)
<html>
  <head><title>{ local:page-title("Home") }</title></head>
  <body>{ ... }</body>
</html>
```

**Order matters:** version → namespaces → imports → variables → options → functions → body.

---

## Common Patterns

### Utility Library

```xquery
module namespace util = "http://example.com/util";

(: Safe string truncation :)
declare function util:truncate($s as xs:string, $max as xs:integer) as xs:string {
  if (string-length($s) > $max)
  then concat(substring($s, 1, $max - 3), "...")
  else $s
};

(: Null-safe default :)
declare function util:default($value as item()*, $fallback as item()*) as item()* {
  if (exists($value)) then $value else $fallback
};

(: Slugify a string :)
declare function util:slugify($s as xs:string) as xs:string {
  lower-case(replace(normalize-space($s), "[^a-zA-Z0-9]+", "-"))
};
```

### Data Access Layer

```xquery
module namespace db = "http://example.com/db";

declare function db:get-product($id as xs:string) as element(product)? {
  collection("products")//product[@id = $id]
};

declare function db:search-products($query as xs:string) as element(product)* {
  collection("products")//product[
    contains(lower-case(name), lower-case($query)) or
    contains(lower-case(description), lower-case($query))
  ]
};

declare function db:products-by-category($cat as xs:string) as element(product)* {
  collection("products")//product[@category = $cat]
};
```

### HTML Template Module

```xquery
module namespace tmpl = "http://example.com/templates";

declare function tmpl:page(
  $title as xs:string,
  $content as node()*
) as element(html) {
  <html>
    <head>
      <meta charset="UTF-8"/>
      <title>{ $title }</title>
      <link rel="stylesheet" href="/css/style.css"/>
    </head>
    <body>
      <header><h1>{ $title }</h1></header>
      <main>{ $content }</main>
      <footer><p>© 2026</p></footer>
    </body>
  </html>
};

declare function tmpl:product-card(
  $product as element(product)
) as element(div) {
  <div class="card">
    <h2>{ $product/name/text() }</h2>
    <p class="price">${ $product/price/text() }</p>
    <p>{ $product/description/text() }</p>
  </div>
};
```

Usage:

```xquery
import module namespace tmpl = "http://example.com/templates" at "templates.xqm";

tmpl:page("Products", (
  for $p in //product
  order by $p/name
  return tmpl:product-card($p)
))
```

This is remarkably similar to component-based web development — small, reusable templates composed into larger pages. The difference is that the "rendering engine" is XQuery, and the "data layer" is XML.
