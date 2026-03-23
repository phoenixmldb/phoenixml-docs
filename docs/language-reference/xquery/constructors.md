---
title: Constructors
description: Building new XML elements, attributes, and documents in XQuery
sort: 3
---

# Constructors

XQuery doesn't just query XML — it builds it. Constructors let you create new elements, attributes, documents, and other nodes from scratch or from query results. This is where XQuery goes beyond XPath.

## Contents

- [Direct Constructors](#direct-constructors)
- [Computed Constructors](#computed-constructors)
- [Document Constructors](#document-constructors)
- [Namespaces in Constructors](#namespaces-in-constructors)
- [Common Patterns](#common-patterns)

---

## Direct Constructors

Direct constructors look like XML literals with embedded expressions in curly braces `{}`:

### Elements

```xquery
<product id="NEW-001">
  <name>New Widget</name>
  <price>19.99</price>
</product>
```

This creates an XML element literally — no query needed.

### Nested Elements and Dynamic Content

Direct constructors can contain static and dynamic content freely mixed, including nested elements with embedded expressions:

```xquery
<root>
  <item name="test">{current-dateTime()}</item>
  <nested><child>text</child></nested>
</root>
```

This produces exactly the XML you see, with `{current-dateTime()}` replaced by the current timestamp. The power of direct constructors is that the query output mirrors the structure of the XML you are building.

### Embedded Expressions

Curly braces `{}` embed XPath/XQuery expressions:

```xquery
<product id="{ $id }">
  <name>{ $name }</name>
  <price>{ $price * (1 - $discount) }</price>
  <generated>{ current-dateTime() }</generated>
</product>
```

**C# parallel:** This is like XML literals in VB.NET, or building `XElement` in C#:
```csharp
new XElement("product",
    new XAttribute("id", id),
    new XElement("name", name),
    new XElement("price", price * (1 - discount)),
    new XElement("generated", DateTime.Now)
)
```

The XQuery version is more readable because the output shape matches the XML structure.

### Embedding Query Results

Expressions can return sequences of nodes:

```xquery
<catalog>{
  for $p in doc("products.xml")//product
  where $p/price < 50
  order by $p/name
  return <item>{ $p/name/text() } — ${ $p/price/text() }</item>
}</catalog>
```

**Output:**
```xml
<catalog>
  <item>USB-C Hub — $45.00</item>
  <item>Wireless Mouse — $29.99</item>
</catalog>
```

### Attribute Value Templates

Attributes use `{}` for dynamic values:

```xquery
<a href="/products/{ $product/@id }.html"
   class="product { if ($product/@featured) then 'featured' else '' }">
  { $product/name/text() }
</a>
```

### Mixed Content

Text and elements can be freely mixed:

```xquery
<p>
  Found { count(//error) } errors in
  <strong>{ $filename }</strong>
  processed at { current-time() }.
</p>
```

---

## Computed Constructors

When the element or attribute **name** is dynamic, use computed constructors:

### element

```xquery
element { "h" || $level } { $heading-text }
(: Creates <h1>..., <h2>..., etc. based on $level :)

element { $tag-name } {
  attribute { "class" } { "dynamic" },
  text { "Hello" }
}
```

### attribute

```xquery
element div {
  attribute class { "container" },
  attribute id { concat("section-", $num) },
  $content
}
```

### text, comment, processing-instruction

```xquery
text { "plain text content" }
comment { "This is a generated comment" }
processing-instruction xml-stylesheet { 'type="text/css" href="style.css"' }
```

### When to Use Computed vs Direct

| Scenario | Use |
|----------|-----|
| Known element name | Direct: `<product>...</product>` |
| Dynamic element name | Computed: `element { $name } { ... }` |
| Dynamic attribute name | Computed: `attribute { $name } { $value }` |
| Most cases | Direct — more readable |

---

## Document Constructors

Create a complete document node:

```xquery
document {
  processing-instruction xml-stylesheet { 'type="text/xsl" href="style.xsl"' },
  <root>
    <item>Content</item>
  </root>
}
```

---

## Namespaces in Constructors

### Declaring Namespaces

In direct constructors, use standard XML namespace declarations:

```xquery
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>{ $title }</title></head>
  <body>{ $content }</body>
</html>
```

In the XQuery prolog:

```xquery
declare namespace atom = "http://www.w3.org/2005/Atom";

<atom:feed>
  <atom:title>{ $feed-title }</atom:title>
  <atom:entry>
    <atom:title>{ $entry-title }</atom:title>
  </atom:entry>
</atom:feed>
```

### Computed Namespaces

```xquery
element { QName("http://www.w3.org/2005/Atom", "feed") } {
  namespace atom { "http://www.w3.org/2005/Atom" },
  element { QName("http://www.w3.org/2005/Atom", "title") } { $title }
}
```

---

## String Constructors

XQuery 3.1 introduces string constructors using backtick syntax. These are useful when building strings that contain characters that would otherwise need escaping (curly braces, quotes, etc.):

```xquery
(: Basic string constructor :)
let $name := "World"
return ``[Hello, `{$name}`! This is a {literal brace}.]``
(: Result: "Hello, World! This is a {literal brace}." :)
```

Inside a string constructor (delimited by `` ``[ `` and `` ]`` ``), only expressions wrapped in `` `{ `` and `` }` `` are evaluated. Everything else is literal text, including curly braces.

```xquery
(: Generating JSON-like strings :)
let $id := 42
let $label := "Widget"
return ``[{"id": `{$id}`, "label": "`{$label}`"}]``
(: Result: '{"id": 42, "label": "Widget"}' :)
```

String constructors are particularly useful for generating code, templates, or any output where the text itself contains XQuery's special characters.

---

## Common Patterns

### XML to XML Transformation

Convert between XML formats — similar to XSLT but in a query style:

```xquery
(: Convert a product catalog to an RSS feed :)
<rss version="2.0">
  <channel>
    <title>Product Updates</title>
    <link>https://example.com</link>
    {
      for $product in //product
      return <item>
        <title>{ $product/name/text() }</title>
        <description>{ $product/description/text() }</description>
        <guid>{ string($product/@id) }</guid>
      </item>
    }
  </channel>
</rss>
```

### XML to JSON-ready Structures

Build maps and arrays for JSON output:

```xquery
array {
  for $p in //product
  return map {
    "id": string($p/@id),
    "name": string($p/name),
    "price": number($p/price),
    "tags": array { $p/tags/tag ! string(.) }
  }
}
```

Serialize with `serialize($result, map { "method": "json", "indent": true() })`.

### Aggregation with Construction

Build summary documents:

```xquery
<report generated="{ current-dateTime() }">
  <summary>
    <total-products>{ count(//product) }</total-products>
    <average-price>{ format-number(avg(//product/price), '#.00') }</average-price>
    <categories>{ count(distinct-values(//product/@category)) }</categories>
  </summary>
  {
    for $cat in distinct-values(//product/@category)
    let $products := //product[@category = $cat]
    order by $cat
    return <category name="{ $cat }" count="{ count($products) }"
                     avg-price="{ format-number(avg($products/price), '#.00') }"/>
  }
</report>
```

### Conditional Construction

Build elements conditionally:

```xquery
<product>
  <name>{ $name }</name>
  { if ($description) then <description>{ $description }</description> else () }
  { if ($price > 100) then <badge>premium</badge> else () }
  {
    for $tag in $tags
    return <tag>{ $tag }</tag>
  }
</product>
```

The empty sequence `()` produces no output — this is how you conditionally include elements. Cleaner than wrapping everything in `if/else` blocks.

### Copy-Modify Pattern

Take an existing node and modify parts of it:

```xquery
copy $order := //order[@id = "12345"]
modify (
  replace value of node $order/status with "shipped",
  insert node <shipped-date>{ current-date() }</shipped-date> as last into $order
)
return $order
```

This is XQuery Update Facility syntax — it creates a modified copy without changing the original. Useful for data transformations where most of the structure stays the same.
