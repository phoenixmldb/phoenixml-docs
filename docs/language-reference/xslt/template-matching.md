---
title: Template Matching
description: How XSLT template rules match nodes and produce output — the declarative paradigm shift
sort: 2
---

# Template Matching

Template matching is the core concept that makes XSLT different from every other transformation language you've used. Instead of writing code that walks a tree, you write rules that fire when patterns match. The XSLT engine handles the traversal.

## The Mental Model

Think of XSLT templates like C# pattern matching in a `switch` expression — except the engine automatically applies them as it walks the document tree:

```csharp
// C# — you control the traversal
foreach (var node in document.Descendants())
{
    var html = node switch
    {
        { Name: "heading" } h => $"<h{h.Attribute("level")}>{h.Value}</h...>",
        { Name: "paragraph" } => $"<p>{node.Value}</p>",
        { Name: "code-block" } => $"<pre><code>{node.Value}</code></pre>",
        _ => node.Value
    };
    output.Append(html);
}
```

```xml
<!-- XSLT — the engine controls the traversal -->
<xsl:template match="heading">
  <xsl:element name="h{@level}"><xsl:apply-templates/></xsl:element>
</xsl:template>

<xsl:template match="paragraph">
  <p><xsl:apply-templates/></p>
</xsl:template>

<xsl:template match="code-block">
  <pre><code><xsl:value-of select="."/></code></pre>
</xsl:template>
```

The XSLT version is more concise, but the real advantage is composability — each template is independent, and `xsl:apply-templates` delegates to whatever templates match the children.

## How Template Matching Works

### The apply-templates Loop

When you write `<xsl:apply-templates/>`, the engine:

1. Takes the children of the current node
2. For each child, finds the best-matching template
3. Executes that template with the child as the new context node
4. Concatenates all the outputs

This is recursive — each template can call `xsl:apply-templates` again, processing its own children.

```xml
<xsl:template match="catalog">
  <div class="catalog">
    <xsl:apply-templates/>   <!-- processes each child of catalog -->
  </div>
</xsl:template>

<xsl:template match="product">
  <div class="product">
    <xsl:apply-templates/>   <!-- processes each child of product -->
  </div>
</xsl:template>

<xsl:template match="name">
  <h2><xsl:apply-templates/></h2>  <!-- processes text content -->
</xsl:template>

<xsl:template match="price">
  <span class="price">$<xsl:apply-templates/></span>
</xsl:template>
```

Given `<catalog><product><name>Widget</name><price>9.99</price></product></catalog>`, the engine automatically produces:

```html
<div class="catalog">
  <div class="product">
    <h2>Widget</h2>
    <span class="price">$9.99</span>
  </div>
</div>
```

No loops. No tree walking code. Each template handles exactly one concern.

### Selecting Which Children to Process

`xsl:apply-templates` can take a `select` attribute to process only specific children:

```xml
<xsl:template match="product">
  <div class="product">
    <xsl:apply-templates select="name"/>        <!-- only the name -->
    <xsl:apply-templates select="price"/>       <!-- then the price -->
    <!-- description is intentionally skipped -->
  </div>
</xsl:template>
```

This controls both which children are processed and in what order.

## Match Patterns

The `match` attribute uses XPath patterns (a subset of full XPath expressions):

### Element Matching

```xml
<xsl:template match="product">          <!-- any product element -->
<xsl:template match="catalog/product">  <!-- product that is child of catalog -->
<xsl:template match="//product">        <!-- product anywhere in the document -->
<xsl:template match="*">                <!-- any element -->
```

### Attribute Matching

```xml
<xsl:template match="@id">              <!-- any id attribute -->
<xsl:template match="@*">               <!-- any attribute -->
<xsl:template match="product/@id">      <!-- id attribute on product -->
```

### Predicate Matching

```xml
<xsl:template match="product[@category='electronics']">
  <!-- only electronics products -->
</xsl:template>

<xsl:template match="product[price > 50]">
  <!-- only expensive products -->
</xsl:template>

<xsl:template match="item[1]">
  <!-- only the first item -->
</xsl:template>
```

### Text and Other Node Types

```xml
<xsl:template match="text()">           <!-- text nodes -->
<xsl:template match="comment()">        <!-- XML comments -->
<xsl:template match="processing-instruction()"> <!-- PIs -->
```

## Template Priority

When multiple templates match the same node, XSLT uses priority rules:

### Specificity (Automatic)

More specific patterns have higher priority:

| Pattern | Priority |
|---------|----------|
| `product[@category='electronics']` | 0.5 (predicate) |
| `catalog/product` | 0.25 (parent/child) |
| `product` | 0 (element name) |
| `*` | -0.5 (wildcard) |

The most specific match wins — similar to CSS specificity.

### Explicit Priority

You can override with the `priority` attribute:

```xml
<xsl:template match="product" priority="1">
  <!-- this wins over any default-priority product template -->
</xsl:template>
```

### Import Precedence

Templates from imported stylesheets have lower precedence than templates in the importing stylesheet:

```xml
<xsl:import href="base-templates.xslt"/>
<!-- templates here override imported ones with the same match pattern -->
```

This is how you build theme overrides — import a base theme, then override specific templates.

## Built-in Template Rules

XSLT has default templates that fire when no explicit template matches. They implement a simple "pass-through" behavior:

```xml
<!-- Built-in: for document and element nodes, process children -->
<xsl:template match="/ | *">
  <xsl:apply-templates/>
</xsl:template>

<!-- Built-in: for text and attributes, output the value -->
<xsl:template match="text() | @*">
  <xsl:value-of select="."/>
</xsl:template>
```

This means: **if you don't write any templates at all, XSLT outputs all the text content of the document.** The built-in rules walk the entire tree and output every text node. Understanding this prevents the common confusion of "why am I getting all this text in my output?"

To suppress unwanted text, add an empty template:

```xml
<xsl:template match="text()"/>  <!-- suppress all text not explicitly handled -->
```

## Modes

Modes let you process the same nodes differently in different contexts. Think of them as "method overloads" for templates:

```xml
<!-- Default mode: full rendering -->
<xsl:template match="product">
  <div class="product">
    <h2><xsl:value-of select="name"/></h2>
    <p><xsl:value-of select="description"/></p>
    <span class="price">$<xsl:value-of select="price"/></span>
  </div>
</xsl:template>

<!-- TOC mode: just the name as a link -->
<xsl:template match="product" mode="toc">
  <li><a href="#{@id}"><xsl:value-of select="name"/></a></li>
</xsl:template>

<!-- Summary mode: name and price only -->
<xsl:template match="product" mode="summary">
  <tr>
    <td><xsl:value-of select="name"/></td>
    <td>$<xsl:value-of select="price"/></td>
  </tr>
</xsl:template>
```

Use them with:

```xml
<!-- Table of contents -->
<ul><xsl:apply-templates select="//product" mode="toc"/></ul>

<!-- Full listing -->
<xsl:apply-templates select="//product"/>

<!-- Summary table -->
<table><xsl:apply-templates select="//product" mode="summary"/></table>
```

**C# parallel:** This is like having different `Render()` methods on a view model — `RenderFull()`, `RenderSummary()`, `RenderTocEntry()` — selected by the caller.

## Named Templates

Templates can also be called by name, like functions:

```xml
<xsl:template name="page-header">
  <header>
    <h1><xsl:value-of select="$site-title"/></h1>
    <nav><xsl:apply-templates select="$manifest/site" mode="nav"/></nav>
  </header>
</xsl:template>

<!-- Call it: -->
<xsl:call-template name="page-header"/>
```

Named templates are useful for reusable page fragments that don't map to specific XML elements.

## Parameters

Templates can accept parameters:

```xml
<xsl:template match="product">
  <xsl:param name="show-description" select="true()"/>
  <div class="product">
    <h2><xsl:value-of select="name"/></h2>
    <xsl:if test="$show-description">
      <p><xsl:value-of select="description"/></p>
    </xsl:if>
  </div>
</xsl:template>

<!-- Pass parameter: -->
<xsl:apply-templates select="//product">
  <xsl:with-param name="show-description" select="false()"/>
</xsl:apply-templates>
```

**C# parallel:** Method parameters — `RenderProduct(showDescription: false)`.
