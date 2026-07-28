---
title: Your First Transform
description: Hands-on introduction to XSLT — transforming XML to HTML step by step
sort: 1
---

# Your First Transform

This tutorial transforms an XML document into HTML. It starts with the simplest possible stylesheet and builds up, explaining each concept as it appears.

## The Source Document

This example uses the following product catalog:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<catalog>
  <product id="P001" category="electronics">
    <name>Wireless Mouse</name>
    <price currency="USD">29.99</price>
    <description>Ergonomic wireless mouse with USB-C receiver.</description>
  </product>
  <product id="P002" category="electronics">
    <name>Mechanical Keyboard</name>
    <price currency="USD">89.99</price>
    <description>Cherry MX Blue switches, full-size layout.</description>
  </product>
  <product id="P003" category="accessories">
    <name>USB-C Hub</name>
    <price currency="USD">45.00</price>
    <description>7-port hub with HDMI and SD card reader.</description>
  </product>
</catalog>
```

## Step 1: The Minimal Stylesheet

Every XSLT stylesheet is an XML document. The following example shows the minimum required elements:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:output method="html" html-version="5" indent="yes"/>

  <xsl:template match="/">
    <html>
      <head><title>Product Catalog</title></head>
      <body>
        <h1>Product Catalog</h1>
        <p>We have <xsl:value-of select="count(//product)"/> products.</p>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
```

**What happens:**

1. `<xsl:stylesheet>` declares this is an XSLT stylesheet. The `xmlns:xsl` namespace is required.
2. `<xsl:output method="html">` tells the engine to produce HTML output (not XML).
3. `<xsl:template match="/">` is a **template rule** that matches the document root. When the engine encounters the root, it executes this template.
4. Everything inside the template that is not an `xsl:` element is a **literal result element**, copied directly to the output.
5. `<xsl:value-of select="count(//product)"/>` evaluates an XPath expression and inserts the result as text.

**Output:**
```html
<!DOCTYPE html>
<html>
  <head><title>Product Catalog</title></head>
  <body>
    <h1>Product Catalog</h1>
    <p>We have 3 products.</p>
  </body>
</html>
```

An XSLT stylesheet pairs a template with match patterns. The template holds
literal output. The match patterns select input nodes and fill embedded
XPath expressions with their values.

> For C# developers: a stylesheet resembles a Razor view. Both mix literal
> output with embedded expressions. XSLT's expressions are XPath, and its
> pattern matching runs automatically against the input tree. Later steps
> use `xsl:for-each`, which resembles a C# `foreach` loop, and `xsl:if`,
> which resembles a C# `if` with no `else` branch. Attribute value
> templates resemble C# string interpolation.

## Step 2: Iterating with xsl:for-each

The following example lists the products:

```xml
<xsl:template match="/">
  <html>
    <head><title>Product Catalog</title></head>
    <body>
      <h1>Products</h1>
      <ul>
        <xsl:for-each select="//product">
          <li>
            <xsl:value-of select="name"/> —
            $<xsl:value-of select="price"/>
          </li>
        </xsl:for-each>
      </ul>
    </body>
  </html>
</xsl:template>
```

`xsl:for-each` iterates over the nodes selected by the `select` expression. Inside the loop, `.` (the context node) is the current product.

**Output:**
```html
<ul>
  <li>Wireless Mouse — $29.99</li>
  <li>Mechanical Keyboard — $89.99</li>
  <li>USB-C Hub — $45.00</li>
</ul>
```

## Step 3: Conditionals with xsl:if

The following example marks products over $50:

```xml
<xsl:for-each select="//product">
  <li>
    <xsl:value-of select="name"/> — $<xsl:value-of select="price"/>
    <xsl:if test="price > 50">
      <span class="premium"> ★ Premium</span>
    </xsl:if>
  </li>
</xsl:for-each>
```

`xsl:if` is a simple conditional with no `else` branch. For if/else logic, use `xsl:choose` (covered in [Instructions Reference](instructions/index.md)).

## Step 4: Accessing Attributes

The following example uses the `id` and `category` attributes:

```xml
<xsl:for-each select="//product">
  <li id="{@id}" class="category-{@category}">
    <xsl:value-of select="name"/>
  </li>
</xsl:for-each>
```

The `{@id}` syntax is an **attribute value template**. It evaluates the XPath expression inside `{}` and inserts the result.

**Output:**
```html
<li id="P001" class="category-electronics">Wireless Mouse</li>
<li id="P002" class="category-electronics">Mechanical Keyboard</li>
<li id="P003" class="category-accessories">USB-C Hub</li>
```

## Step 5: Sorting

The following example sorts products by price, cheapest first:

```xml
<xsl:for-each select="//product">
  <xsl:sort select="price" data-type="number" order="ascending"/>
  <li><xsl:value-of select="name"/> — $<xsl:value-of select="price"/></li>
</xsl:for-each>
```

`xsl:sort` must be the first child of `xsl:for-each`. Include `data-type="number"` for numeric sorting. Without it, XSLT sorts values lexicographically, so "89.99" sorts after "9".

## Step 6: Template Matching

Everything above uses `xsl:for-each`, the imperative approach. **Template matching** defines rules that automatically fire for different node types.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <xsl:output method="html" html-version="5" indent="yes"/>

  <!-- Root template: HTML page structure -->
  <xsl:template match="/">
    <html>
      <head><title>Product Catalog</title></head>
      <body>
        <h1>Products</h1>
        <xsl:apply-templates select="catalog/product"/>
      </body>
    </html>
  </xsl:template>

  <!-- Product template: renders one product -->
  <xsl:template match="product">
    <div class="product" id="{@id}">
      <h2><xsl:value-of select="name"/></h2>
      <p class="price">$<xsl:value-of select="price"/></p>
      <p><xsl:value-of select="description"/></p>
    </div>
  </xsl:template>

</xsl:stylesheet>
```

**What changed:**

1. The root template calls `<xsl:apply-templates select="catalog/product"/>`. This tells the engine to find template rules that match each product element.
2. The `<xsl:template match="product">` rule fires for each product.
3. The engine handles the iteration. You do not write a loop.

**Why this matters:** With `xsl:for-each`, the root template knows about products. With template matching, each template is self-contained. You can add new element types by adding new templates. The existing templates do not change. This pattern applies the Open/Closed Principle.

## Running This in .NET

Using the PhoenixmlDb XSLT engine:

```csharp
using PhoenixmlDb.Xslt;

var stylesheet = File.ReadAllText("catalog.xslt");
var sourceXml = File.ReadAllText("catalog.xml");

var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheet, new Uri("catalog.xslt"));
var html = await transformer.TransformAsync(sourceXml);

Console.WriteLine(html);
```

Or using the Crucible CLI:

```bash
xslt catalog.xslt catalog.xml -o catalog.html
```

## Next Steps

This tutorial covered the basics: `xsl:value-of`, `xsl:for-each`, `xsl:if`, `xsl:sort`, attribute value templates, and template matching. The next pages cover the following topics:

- [Template Matching](template-matching.md) — the paradigm shift from imperative to declarative.
- [Instructions Reference](instructions/index.md) — the complete set of XSLT instructions.
- [Output Methods](output-methods.md) — producing HTML, XML, JSON, and text.
