---
title: Node Construction
description: "xsl:element, xsl:attribute, xsl:namespace, xsl:document — building nodes with dynamic names"
sort: 7
---

# Node Construction

Most of the time you write literal result elements directly in your stylesheet — `<div>`, `<span>`, `<product>`. But when the element or attribute name is not known until runtime, you need dynamic node construction. XSLT provides four instructions for this, plus a powerful shorthand called attribute value templates (AVTs) that you will use constantly.

## Contents

- [Attribute Value Templates (AVTs)](#attribute-value-templates-avts)
- [Text Value Templates](#text-value-templates)
- [xsl:element](#xslelement)
- [xsl:attribute](#xslattribute)
- [xsl:namespace](#xslnamespace)
- [xsl:document](#xsldocument)
- [When to Use Dynamic Construction vs. Literal Elements](#when-to-use-dynamic-construction-vs-literal-elements)

---

## Attribute Value Templates (AVTs)

Before covering the dynamic construction instructions, you need to understand AVTs — they are the single most-used feature for putting computed values into output attributes.

An AVT is any attribute on a literal result element (or on certain XSLT instruction attributes) that contains `{expression}` placeholders. The processor evaluates the XPath expression and substitutes the string result.

```xml
<a href="/products/{@id}">
  <xsl:value-of select="name"/>
</a>
```

Given `<product id="WP-001"><name>Widget Pro</name></product>`, this produces:

```html
<a href="/products/WP-001">Widget Pro</a>
```

**C# parallel:** This is exactly string interpolation — `$"/products/{product.Id}"`.

### Multiple Expressions in One Attribute

You can mix literal text and multiple expressions:

```xml
<img src="/images/{@category}/{@id}.png"
     alt="{name} - {price}"
     class="product {if (@on-sale = 'true') then 'sale' else 'regular'}"/>
```

### Escaping Curly Braces

To produce a literal `{` or `}` in an AVT, double it:

```xml
<!-- Producing CSS or JavaScript that contains braces -->
<style>
  .product-{@id} {{ color: red; }}
</style>
```

Output:

```html
<style>
  .product-WP-001 { color: red; }
</style>
```

### Where AVTs Work

AVTs are available on:

- **Literal result element attributes** — `<div class="{$class}">` (the most common use)
- **Certain XSLT instruction attributes** — marked in the spec as "attribute value template." For example, `xsl:element/@name`, `xsl:attribute/@name`, `xsl:result-document/@href`, `xsl:sort/@order`
- **Not** on `select`, `test`, or `match` attributes — those are already XPath expressions

### Common AVT Patterns

```xml
<!-- Conditional CSS class -->
<tr class="{if (position() mod 2 = 0) then 'even' else 'odd'}">
  <td><xsl:value-of select="name"/></td>
</tr>

<!-- Data attributes from XML values -->
<div data-id="{@id}" data-category="{@category}">
  <xsl:apply-templates/>
</div>

<!-- URL construction -->
<link rel="stylesheet" href="{$base-url}/css/{$theme}.css"/>

<!-- Computed id for anchor links -->
<section id="{translate(lower-case(name), ' ', '-')}">
  <h2><xsl:value-of select="name"/></h2>
</section>
```

---

## Text Value Templates

XSLT 3.0 extends the AVT concept to text content with `expand-text="yes"`. When enabled, `{expression}` works inside text nodes too — not just in attributes.

```xml
<xsl:template match="product" expand-text="yes">
  <div class="product">
    <h3>{name}</h3>
    <p class="price">${format-number(price, '#,##0.00')}</p>
    <p class="sku">SKU: {@id}</p>
  </div>
</xsl:template>
```

This is equivalent to writing `<xsl:value-of select="name"/>` everywhere, but far more readable. You can enable it on any element — `xsl:stylesheet`, `xsl:template`, or any literal result element — and it applies to all descendant text nodes.

### Enabling Globally

Most stylesheets enable it on the root element:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="3.0"
                expand-text="yes">
  <!-- All templates can now use {expression} in text -->
</xsl:stylesheet>
```

**C# parallel:** `expand-text="yes"` turns your entire stylesheet into something that feels like Razor or C# string interpolation — `$"Product: {name}, Price: ${price:N2}"`.

### Escaping in Text Value Templates

Just like AVTs, double the braces to produce literal `{` and `}`:

```xml
<xsl:template match="product" expand-text="yes">
  <script>
    const product = {{ "id": "{@id}", "name": "{name}" }};
  </script>
</xsl:template>
```

Output:

```html
<script>
  const product = { "id": "WP-001", "name": "Widget Pro" };
</script>
```

---

## xsl:element

Creates an element whose name is computed at runtime. Use this when you cannot write the element name as a literal in your stylesheet.

```xml
<xsl:element name="{$element-name}">
  <!-- content -->
</xsl:element>
```

### Basic Usage

```xml
<!-- Convert a "field" element into an element whose name comes from the @name attribute -->
<xsl:template match="field">
  <xsl:element name="{@name}">
    <xsl:value-of select="."/>
  </xsl:element>
</xsl:template>
```

Given:

```xml
<record>
  <field name="firstName">Alice</field>
  <field name="lastName">Smith</field>
  <field name="email">alice@example.com</field>
</record>
```

Output:

```xml
<firstName>Alice</firstName>
<lastName>Smith</lastName>
<email>alice@example.com</email>
```

**C# parallel:** `new XElement(fieldName, value)` — the `XElement` constructor takes the element name as a string parameter.

### Namespace Handling

The `namespace` attribute specifies the namespace URI for the constructed element:

```xml
<!-- Create element in a specific namespace -->
<xsl:element name="atom:feed" namespace="http://www.w3.org/2005/Atom">
  <xsl:element name="atom:title" namespace="http://www.w3.org/2005/Atom">
    <xsl:value-of select="$site-title"/>
  </xsl:element>
</xsl:element>
```

Output:

```xml
<atom:feed xmlns:atom="http://www.w3.org/2005/Atom">
  <atom:title>My Product Catalog</atom:title>
</atom:feed>
```

If you omit `namespace`, the element inherits the namespace from the prefix used in the `name` attribute (resolved against in-scope namespace declarations). If there is no prefix, the element is in the default namespace of the stylesheet at that point.

### The use-attribute-sets Attribute

`xsl:element` can apply named attribute sets — predefined groups of attributes:

```xml
<xsl:attribute-set name="table-defaults">
  <xsl:attribute name="class">data-table</xsl:attribute>
  <xsl:attribute name="cellpadding">4</xsl:attribute>
  <xsl:attribute name="border">1</xsl:attribute>
</xsl:attribute-set>

<xsl:template match="data">
  <xsl:element name="table" use-attribute-sets="table-defaults">
    <xsl:apply-templates/>
  </xsl:element>
</xsl:template>
```

Output:

```html
<table class="data-table" cellpadding="4" border="1">
  <!-- content -->
</table>
```

Attribute sets work on literal result elements too: `<table xsl:use-attribute-sets="table-defaults">`.

### Practical Example: Generic XML-to-HTML Table

```xml
<!-- Turn any XML structure into an HTML table -->
<xsl:template match="*[*]" mode="auto-table">
  <table>
    <thead>
      <tr>
        <xsl:for-each select="*[1]/*">
          <th><xsl:value-of select="local-name()"/></th>
        </xsl:for-each>
      </tr>
    </thead>
    <tbody>
      <xsl:for-each select="*">
        <tr>
          <xsl:for-each select="*">
            <xsl:element name="{if (position() = 1) then 'th' else 'td'}">
              <xsl:value-of select="."/>
            </xsl:element>
          </xsl:for-each>
        </tr>
      </xsl:for-each>
    </tbody>
  </table>
</xsl:template>
```

Here `xsl:element` chooses between `<th>` and `<td>` based on position — something you cannot do with a literal element.

---

## xsl:attribute

Creates an attribute on the parent element, with a name that can be computed at runtime.

```xml
<xsl:attribute name="class">product-card</xsl:attribute>
```

### Why Not Just Use AVTs?

For static attribute names, AVTs are always cleaner:

```xml
<!-- Preferred: AVT -->
<div class="product {$extra-class}">...</div>

<!-- Equivalent but verbose: xsl:attribute -->
<div>
  <xsl:attribute name="class">product <xsl:value-of select="$extra-class"/></xsl:attribute>
  ...
</div>
```

Use `xsl:attribute` when:

1. **The attribute name is dynamic:** `<xsl:attribute name="{$attr-name}">...</xsl:attribute>`
2. **The attribute value requires complex construction** with multiple instructions
3. **You are conditionally adding an attribute:**

```xml
<input type="checkbox">
  <xsl:if test="@selected = 'true'">
    <xsl:attribute name="checked">checked</xsl:attribute>
  </xsl:if>
</input>
```

### Dynamic Attribute Names

```xml
<!-- Convert XML attributes to data-* attributes -->
<xsl:template match="product">
  <div>
    <xsl:for-each select="@*">
      <xsl:attribute name="data-{local-name()}">
        <xsl:value-of select="."/>
      </xsl:attribute>
    </xsl:for-each>
    <xsl:apply-templates/>
  </div>
</xsl:template>
```

Given `<product id="WP-001" category="electronics" status="active">`, output:

```html
<div data-id="WP-001" data-category="electronics" data-status="active">
  <!-- content -->
</div>
```

**C# parallel:** `new XAttribute(attrName, value)` or setting a property dynamically with reflection.

### The separator Attribute

When the content of `xsl:attribute` produces a sequence, the `separator` attribute controls how items are joined. This is useful for multi-value attributes like CSS classes:

```xml
<div>
  <xsl:attribute name="class" separator=" ">
    <xsl:text>product-card</xsl:text>
    <xsl:if test="@on-sale = 'true'">
      <xsl:text>on-sale</xsl:text>
    </xsl:if>
    <xsl:if test="@featured = 'true'">
      <xsl:text>featured</xsl:text>
    </xsl:if>
    <xsl:if test="stock = 0">
      <xsl:text>out-of-stock</xsl:text>
    </xsl:if>
  </xsl:attribute>
  <xsl:apply-templates/>
</div>
```

A product that is on sale and featured produces:

```html
<div class="product-card on-sale featured">...</div>
```

Without `separator`, the default is to concatenate everything with no delimiter. The `separator` attribute is particularly helpful because it automatically handles the case where some conditional items are absent — no extra spaces or dangling separators.

**C# parallel:** `string.Join(" ", classList.Where(c => c != null))` — building a CSS class list from conditional parts.

### Placement Rules

`xsl:attribute` must appear before any child nodes in the parent element. This fails:

```xml
<!-- ERROR: attribute after child content -->
<div>
  <p>Some content</p>
  <xsl:attribute name="class">container</xsl:attribute>  <!-- too late! -->
</div>
```

The attribute instruction must come first:

```xml
<div>
  <xsl:attribute name="class">container</xsl:attribute>
  <p>Some content</p>
</div>
```

---

## xsl:namespace

Creates a namespace declaration on the parent element. This is rarely needed because namespace declarations are usually handled automatically — when you create an element in a namespace, the serializer adds the necessary `xmlns` declarations. But occasionally you need explicit control.

### When You Need xsl:namespace

The primary use case is when the output document must contain namespace declarations that are not used by any element or attribute in that document. This happens with:

- **Schema-instance declarations** (`xsi:schemaLocation`)
- **Namespace-aware content** embedded in attribute values (like XPath expressions in Schematron)
- **XSLT stylesheets that generate other XSLT stylesheets**

```xml
<xsl:template match="/">
  <root>
    <xsl:namespace name="xsi" select="'http://www.w3.org/2001/XMLSchema-instance'"/>
    <xsl:attribute name="xsi:schemaLocation"
                   namespace="http://www.w3.org/2001/XMLSchema-instance">
      http://example.com/schema catalog.xsd
    </xsl:attribute>
    <xsl:apply-templates/>
  </root>
</xsl:template>
```

Output:

```xml
<root xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://example.com/schema catalog.xsd">
  <!-- content -->
</root>
```

### Dynamic Namespace Prefix

The `name` attribute specifies the prefix; the `select` attribute (or content) specifies the URI:

```xml
<!-- Add a namespace with a dynamic prefix -->
<xsl:namespace name="{$prefix}" select="$namespace-uri"/>
```

Use an empty `name` to set the default namespace:

```xml
<!-- Set the default namespace -->
<xsl:namespace name="" select="'http://www.w3.org/1999/xhtml'"/>
```

**C# parallel:** `new XAttribute(XNamespace.Xmlns + "xsi", "http://www.w3.org/2001/XMLSchema-instance")` — manually adding namespace declarations to an `XElement`.

---

## xsl:document

Creates a new document node (the root of a tree). This is primarily useful for constructing temporary trees that you want to process further — for example, building an intermediate XML structure and then transforming it.

```xml
<xsl:variable name="temp-doc" as="document-node()">
  <xsl:document>
    <products>
      <xsl:for-each select="//product[@status = 'active']">
        <xsl:sort select="name"/>
        <product>
          <name><xsl:value-of select="name"/></name>
          <price><xsl:value-of select="price"/></price>
        </product>
      </xsl:for-each>
    </products>
  </xsl:document>
</xsl:variable>

<!-- Now process the temporary document -->
<xsl:apply-templates select="$temp-doc/products/product"/>
```

### When to Use xsl:document

In practice, `xsl:document` is uncommon because a variable with content already creates a document node:

```xml
<!-- These are nearly equivalent -->
<xsl:variable name="temp">
  <products>...</products>
</xsl:variable>

<xsl:variable name="temp" as="document-node()">
  <xsl:document>
    <products>...</products>
  </xsl:document>
</xsl:variable>
```

The explicit `xsl:document` form is useful when:

1. **You need a document node inside a function** that returns `document-node()`:

```xml
<xsl:function name="my:build-lookup" as="document-node()">
  <xsl:param name="items" as="element()*"/>
  <xsl:document>
    <lookup>
      <xsl:for-each select="$items">
        <entry key="{@id}" value="{name}"/>
      </xsl:for-each>
    </lookup>
  </xsl:document>
</xsl:function>
```

2. **You need validation** — `xsl:document` supports the `validation` and `type` attributes for schema validation of the constructed tree.

3. **You are building a multi-pass transformation** where the first pass constructs an intermediate document and the second pass transforms it to final output.

**C# parallel:** `new XDocument(new XElement("products", ...))` — constructing an in-memory XML document for further processing.

### Multi-Pass Transformation Example

```xml
<xsl:template match="/">
  <!-- Pass 1: Build normalized intermediate document -->
  <xsl:variable name="normalized" as="document-node()">
    <xsl:document>
      <catalog>
        <xsl:for-each select="//product">
          <xsl:sort select="@category"/>
          <xsl:sort select="name"/>
          <item category="{@category}"
                name="{name}"
                price="{price}"
                in-stock="{stock > 0}"/>
        </xsl:for-each>
      </catalog>
    </xsl:document>
  </xsl:variable>

  <!-- Pass 2: Render the normalized document as HTML -->
  <html>
    <body>
      <xsl:for-each-group select="$normalized/catalog/item" group-by="@category">
        <section>
          <h2><xsl:value-of select="current-grouping-key()"/></h2>
          <ul>
            <xsl:for-each select="current-group()">
              <li class="{if (@in-stock = 'true') then 'available' else 'sold-out'}">
                <xsl:value-of select="@name"/> — $<xsl:value-of select="@price"/>
              </li>
            </xsl:for-each>
          </ul>
        </section>
      </xsl:for-each-group>
    </body>
  </html>
</xsl:template>
```

---

## When to Use Dynamic Construction vs. Literal Elements

Use **literal result elements** (the default) whenever the element name is known at stylesheet-authoring time:

```xml
<!-- Preferred: literal result element -->
<div class="product">
  <h3><xsl:value-of select="name"/></h3>
</div>
```

Use **xsl:element / xsl:attribute** when:

| Scenario | Example |
|----------|---------|
| Element name is data-driven | `<xsl:element name="{@node-type}">` |
| Attribute name is data-driven | `<xsl:attribute name="data-{local-name()}">` |
| Element name depends on a condition | `<xsl:element name="{if ($level = 1) then 'h1' else 'h2'}">` |
| You need programmatic namespace control | `<xsl:element name="ns:{$local}" namespace="{$uri}">` |
| Generating XSLT from XSLT | Element names collide with the XSLT namespace |
| Building a generic/reflective transform | Processing arbitrary XML structures |

### Decision Flowchart

1. **Is the element/attribute name fixed?** Use a literal result element with AVTs for attribute values.
2. **Is the name computed from data?** Use `xsl:element` or `xsl:attribute`.
3. **Is the name one of a small, known set?** Consider `xsl:choose` with literal elements — it is more readable than `xsl:element` when there are only two or three alternatives.

```xml
<!-- For a small set of known names, choose + literal is clearer -->
<xsl:choose>
  <xsl:when test="@level = '1'"><h1><xsl:apply-templates/></h1></xsl:when>
  <xsl:when test="@level = '2'"><h2><xsl:apply-templates/></h2></xsl:when>
  <xsl:when test="@level = '3'"><h3><xsl:apply-templates/></h3></xsl:when>
  <xsl:otherwise><p><xsl:apply-templates/></p></xsl:otherwise>
</xsl:choose>

<!-- For an open-ended set, xsl:element is necessary -->
<xsl:element name="h{@level}">
  <xsl:apply-templates/>
</xsl:element>
```

**C# parallel summary:**

| XSLT | C# (LINQ to XML) | C# (String Interpolation) |
|------|-------------------|---------------------------|
| `<div class="{@id}">` (AVT) | `new XElement("div", new XAttribute("class", id))` | `$"<div class=\"{id}\">"` |
| `<xsl:element name="{$n}">` | `new XElement(n, ...)` | `$"<{n}>...</{n}>"` |
| `<xsl:attribute name="{$a}">` | `new XAttribute(a, value)` | `$"{a}=\"{value}\""` |
| `expand-text` / TVTs | N/A | `$"Name: {product.Name}, Price: {product.Price:C}"` |
