---
title: Conditionals and Error Handling
description: if/then/else, switch, typeswitch, try/catch, and the otherwise operator
sort: 4
---

# Conditionals and Error Handling

XQuery's conditionals are all **expressions** — they return values. There are no statements. This is the biggest mental shift for C# developers: every `if`, every `switch`, every `try/catch` produces a result that can be assigned, returned, or embedded inside XML.

## Contents

- [if/then/else](#ifthenelse)
- [Braced if](#braced-if)
- [switch Expression](#switch-expression)
- [typeswitch Expression](#typeswitch-expression)
- [try/catch](#trycatch)
- [otherwise Operator](#otherwise-operator)

---

## if/then/else

The fundamental conditional. Always an expression, always returns a value.

```xquery
let $status := if ($order/total > 1000) then "premium" else "standard"
return <order class="{ $status }">{ $order/total/text() }</order>
```

**C# parallel:** The ternary operator:
```csharp
var status = order.Total > 1000 ? "premium" : "standard";
```

### The else Is Required

In standard XQuery (3.1 and earlier), `else` is mandatory. If you don't want to return anything, use the empty sequence `()`:

```xquery
if ($product/stock > 0) then
  <available>{ $product/name/text() }</available>
else
  ()
```

The empty sequence `()` is XQuery's equivalent of "nothing" — it produces no output. This is especially useful inside XML constructors:

```xquery
<product>
  <name>{ $product/name/text() }</name>
  <price>{ $product/price/text() }</price>
  { if ($product/@featured = "true") then <badge>Featured</badge> else () }
  { if ($product/stock < 5) then <warning>Low stock</warning> else () }
</product>
```

### Nested if

```xquery
let $tier :=
  if ($total > 10000) then "platinum"
  else if ($total > 5000) then "gold"
  else if ($total > 1000) then "silver"
  else "bronze"
return <customer tier="{ $tier }">{ $name }</customer>
```

**C# parallel:**
```csharp
var tier = total > 10000 ? "platinum"
         : total > 5000  ? "gold"
         : total > 1000  ? "silver"
         : "bronze";
```

Nested `if` works but gets unwieldy fast. For multiple branches, prefer `switch`.

### if as an Expression Everywhere

Because `if` is an expression, you can use it anywhere a value is expected:

```xquery
(: In a function argument :)
concat("Status: ", if ($active) then "Active" else "Inactive")

(: In an attribute value :)
<div class="product { if ($featured) then 'highlight' else '' }">

(: In arithmetic :)
let $total := $subtotal * (if ($member) then 0.9 else 1.0)

(: As a FLWOR return :)
for $item in //items/item
return if ($item/@type = "header") then
  <h2>{ $item/text() }</h2>
else
  <p>{ $item/text() }</p>
```

---

## Braced if

*XQuery 4.0*

XQuery 4.0 adds a shorthand `if` without `else`. The result is the empty sequence when the condition is false:

```xquery
(: XQuery 4.0 braced if — no else needed :)
<product>
  <name>{ $product/name/text() }</name>
  { if ($product/@featured = "true") { <badge>Featured</badge> } }
  { if ($product/stock < 5) { <warning>Low stock</warning> } }
</product>
```

This is equivalent to `if (...) then ... else ()` but more concise. The braces `{}` replace `then`, and the absence of `else` implicitly returns `()`.

**C# parallel:** There's no exact equivalent, but it's similar in spirit to conditional output in Razor views:
```csharp
@if (product.IsFeatured) { <badge>Featured</badge> }
```

### When to Use Braced if

Use braced `if` when you're conditionally including optional content and the `else ()` adds nothing but noise. Use the full `if/then/else` when both branches produce meaningful output.

---

## switch Expression

The `switch` expression matches a value against multiple cases. Unlike C#'s `switch` statement (pre-C# 8), XQuery's `switch` is an expression and has no fall-through.

```xquery
let $status-label := switch ($order/@status)
  case "pending"   return "Awaiting Review"
  case "approved"  return "Approved for Processing"
  case "shipped"   return "In Transit"
  case "delivered"  return "Delivered"
  default          return "Unknown Status"
return <span class="status">{ $status-label }</span>
```

**C# parallel:** Switch expression (C# 8+):
```csharp
var statusLabel = order.Status switch
{
    "pending"   => "Awaiting Review",
    "approved"  => "Approved for Processing",
    "shipped"   => "In Transit",
    "delivered" => "Delivered",
    _           => "Unknown Status"
};
```

### Multiple Values per Case

```xquery
switch ($file/@extension)
  case "jpg" case "jpeg" case "png" case "gif" case "webp"
    return "image"
  case "mp4" case "avi" case "mkv" case "mov"
    return "video"
  case "pdf" case "docx" case "txt" case "md"
    return "document"
  default
    return "other"
```

### Switch with Complex Return Values

Since each branch is an expression, you can return constructed XML:

```xquery
switch ($response/@code)
  case "200" return
    <success>
      <message>Request successful</message>
      <data>{ $response/body/* }</data>
    </success>
  case "404" return
    <error>
      <message>Resource not found: { $response/@url/string() }</message>
    </error>
  case "500" return
    <error>
      <message>Server error</message>
      <detail>{ $response/body/text() }</detail>
    </error>
  default return
    <error>
      <message>Unexpected response code: { $response/@code/string() }</message>
    </error>
```

### default Is Required

Every `switch` must have a `default` branch. If you genuinely have no default action, return the empty sequence:

```xquery
switch ($value)
  case "yes" return true()
  case "no" return false()
  default return ()
```

---

## typeswitch Expression

`typeswitch` matches on the **type** of a value rather than its content. This is essential for processing mixed-content XML, handling polymorphic data, and working with items whose type isn't known at compile time.

```xquery
typeswitch ($node)
  case element(product) return
    <div class="product">{ $node/name/text() }</div>
  case element(category) return
    <h2>{ $node/@name/string() }</h2>
  case element(review) return
    <blockquote>{ $node/text/text() }</blockquote>
  case text() return
    <span>{ $node }</span>
  default return
    <div>Unknown: { local-name($node) }</div>
```

**C# parallel:** Pattern matching with `switch`:
```csharp
var result = node switch
{
    XElement e when e.Name == "product" => RenderProduct(e),
    XElement e when e.Name == "category" => RenderCategory(e),
    XElement e when e.Name == "review" => RenderReview(e),
    XText t => $"<span>{t.Value}</span>",
    _ => $"<div>Unknown: {(node as XElement)?.Name}</div>"
};
```

### Binding the Matched Value

Use `$variable` after the type to bind the matched value with the correct type:

```xquery
typeswitch ($input)
  case $s as xs:string return
    concat("String value: ", $s)
  case $n as xs:integer return
    concat("Integer value: ", string($n * 2))
  case $d as xs:date return
    concat("Date value: ", format-date($d, "[MNn] [D], [Y]"))
  case $e as element() return
    concat("Element: ", local-name($e))
  default $other return
    concat("Other: ", string($other))
```

The binding is important because inside each `case` branch, the variable has the specific type. You get proper type-checking and access to type-specific operations.

### Practical Example: Recursive Mixed-Content Renderer

```xquery
declare function local:render($nodes as node()*) as node()* {
  for $node in $nodes
  return typeswitch ($node)
    case element(bold) return
      <strong>{ local:render($node/node()) }</strong>
    case element(italic) return
      <em>{ local:render($node/node()) }</em>
    case element(link) return
      <a href="{ $node/@url }">{ local:render($node/node()) }</a>
    case element(code) return
      <code>{ $node/text() }</code>
    case element(paragraph) return
      <p>{ local:render($node/node()) }</p>
    case element(list) return
      <ul>{
        for $item in $node/item
        return <li>{ local:render($item/node()) }</li>
      }</ul>
    case text() return $node
    case comment() return ()  (: strip comments :)
    default return local:render($node/node())
};

local:render(//document/body/*)
```

This pattern is similar to what XSLT does with template matching, but expressed as an explicit recursive function. Use `typeswitch` when you need this kind of polymorphic dispatch in XQuery.

### Matching Multiple Types

```xquery
typeswitch ($value)
  case xs:integer | xs:decimal | xs:double return
    <number>{ $value }</number>
  case xs:date | xs:dateTime return
    <temporal>{ $value }</temporal>
  case xs:string return
    <text>{ $value }</text>
  default return
    <other>{ string($value) }</other>
```

---

## try/catch

XQuery's `try/catch` handles dynamic errors. Like everything else in XQuery, it's an expression.

```xquery
let $result := try {
  xs:integer("not-a-number")
} catch * {
  -1  (: fallback value on any error :)
}
return $result
(: Result: -1 :)
```

**C# parallel:**
```csharp
int result;
try { result = int.Parse("not-a-number"); }
catch { result = -1; }
```

### Error Variables

Inside a `catch` block, three variables are available:

| Variable | Type | Description |
|----------|------|-------------|
| `$err:code` | `xs:QName` | The error code (e.g., `err:FORG0001`) |
| `$err:description` | `xs:string?` | Human-readable error message |
| `$err:value` | `item()*` | Additional error context (may be empty) |

You must declare the error namespace:

```xquery
declare namespace err = "http://www.w3.org/2005/xqt-errors";

try {
  doc("missing-file.xml")//data
} catch * {
  <error>
    <code>{ $err:code }</code>
    <message>{ $err:description }</message>
  </error>
}
```

### Catching Specific Errors

Catch by error code to handle different errors differently:

```xquery
declare namespace err = "http://www.w3.org/2005/xqt-errors";

try {
  let $data := doc($filename)
  return $data//record
}
catch err:FODC0002 {
  (: Document not found :)
  <error type="not-found">File not found: { $filename }</error>
}
catch err:FODC0006 {
  (: Invalid URI :)
  <error type="invalid-uri">Invalid file path: { $filename }</error>
}
catch * {
  (: Catch-all for anything else :)
  <error type="unknown">{ $err:description }</error>
}
```

**C# parallel:**
```csharp
try {
    var doc = XDocument.Load(filename);
    return doc.Descendants("record");
}
catch (FileNotFoundException) {
    return new XElement("error", $"File not found: {filename}");
}
catch (UriFormatException) {
    return new XElement("error", $"Invalid file path: {filename}");
}
catch (Exception ex) {
    return new XElement("error", ex.Message);
}
```

### Practical Example: Safe Data Conversion

```xquery
declare function local:safe-decimal($value as xs:string?) as xs:decimal? {
  if (empty($value) or $value = "") then ()
  else try { xs:decimal($value) } catch * { () }
};

declare function local:safe-date($value as xs:string?) as xs:date? {
  if (empty($value) or $value = "") then ()
  else try { xs:date($value) } catch * { () }
};

(: Use in a pipeline :)
for $row in //data/row
let $amount := local:safe-decimal($row/amount)
let $date := local:safe-date($row/date)
where exists($amount) and exists($date)
return <valid-record amount="{ $amount }" date="{ $date }"/>
```

**C# parallel:** `decimal.TryParse` and `DateTime.TryParse`:
```csharp
static decimal? SafeDecimal(string value) =>
    decimal.TryParse(value, out var d) ? d : null;

static DateTime? SafeDate(string value) =>
    DateTime.TryParse(value, out var dt) ? dt : null;
```

### Raising Errors

Use `error()` to throw errors:

```xquery
declare function local:validate-age($age as xs:integer) as xs:integer {
  if ($age < 0 or $age > 150) then
    error(
      QName("http://example.com/errors", "INVALID-AGE"),
      concat("Age must be 0-150, got: ", $age),
      $age
    )
  else
    $age
};

(: Caller can catch it :)
try {
  local:validate-age(-5)
} catch Q{http://example.com/errors}INVALID-AGE {
  <validation-error>{ $err:description }</validation-error>
}
```

---

## otherwise Operator

*XQuery 4.0*

The `otherwise` operator returns a fallback value when an expression evaluates to the empty sequence. It's XQuery's null-coalescing operator.

```xquery
$user/nickname otherwise $user/name otherwise "Anonymous"
```

**C# parallel:** The `??` operator:
```csharp
user.Nickname ?? user.Name ?? "Anonymous"
```

### How It Works

`otherwise` checks for the empty sequence — not for `null`, `false`, `0`, or `""`. Only `()` triggers the fallback:

```xquery
(: These return the left side — they're not empty :)
"" otherwise "fallback"       (: returns "" — empty string is not empty sequence :)
0 otherwise 42                (: returns 0 — zero is not empty sequence :)
false() otherwise true()      (: returns false — false is not empty sequence :)

(: This returns the fallback — () is the empty sequence :)
() otherwise "fallback"       (: returns "fallback" :)
```

This is different from C#'s `??`, which checks for `null`. In XQuery, everything is about sequences.

### Practical Examples

**Safe attribute access:**

```xquery
(: Get the display name, with fallbacks :)
let $display :=
  $user/@display-name/string() otherwise
  concat($user/first-name, " ", $user/last-name) otherwise
  $user/@username/string() otherwise
  "Unknown User"
return <span class="user-name">{ $display }</span>
```

**Configuration with defaults:**

```xquery
let $page-size := xs:integer($config/page-size/text()) otherwise 25
let $sort-order := $config/sort-order/text() otherwise "ascending"
let $locale := $config/@locale/string() otherwise "en-US"
return map {
  "page-size": $page-size,
  "sort-order": $sort-order,
  "locale": $locale
}
```

**Chained lookups:**

```xquery
(: Try multiple data sources :)
let $product :=
  collection("primary-catalog")//product[@sku = $sku] otherwise
  collection("archive-catalog")//product[@sku = $sku] otherwise
  <product><name>Product not found</name><sku>{ $sku }</sku></product>
return $product
```

### otherwise vs if/else

Use `otherwise` when testing for empty sequences. Use `if/then/else` for boolean conditions:

```xquery
(: otherwise — is the sequence empty? :)
$node/optional-child otherwise <default/>

(: if/then/else — is a condition true? :)
if ($node/@status = "active") then $node else ()
```

### otherwise in FLWOR vs the otherwise Operator

Note that the `otherwise` clause at the end of a FLWOR (covered in [Advanced FLWOR](flwor-advanced.md)) and the `otherwise` operator are related but different:

```xquery
(: FLWOR otherwise — fallback for the entire FLWOR result :)
for $x in //items/item
where $x/price > 100
return $x
otherwise <none/>

(: Operator otherwise — inline null coalescing :)
let $name := $user/nickname otherwise $user/name
```

The FLWOR `otherwise` clause is syntactic sugar for wrapping the entire FLWOR in `(flwor-expr) otherwise fallback`.
