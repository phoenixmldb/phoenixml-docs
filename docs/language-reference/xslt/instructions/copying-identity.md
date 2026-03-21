---
title: Copying and Identity Transform
description: "xsl:copy, xsl:copy-of, and the identity transform pattern"
sort: 6
---

# Copying and Identity Transform

Copying is one of the most common XSLT operations. Whether you are passing through most of a document unchanged, selectively modifying a few elements, or restructuring content, the copy instructions and the identity transform pattern are your primary tools.

## Contents

- [xsl:copy](#xslcopy)
- [xsl:copy-of](#xslcopy-of)
- [The Identity Transform](#the-identity-transform)
- [on-no-match Behaviors](#on-no-match-behaviors)
- [Practical Patterns](#practical-patterns)

---

## xsl:copy

Creates a shallow copy of the current node — the node itself, but **not** its children, attributes, or namespaces (unless you explicitly process them).

### Basic Usage

```xml
<xsl:template match="product">
  <xsl:copy>
    <!-- Inside here, we are "inside" the copied <product> element -->
    <!-- But it has no attributes or children yet — we must add them -->
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>
```

`xsl:copy` copies:
- **Element nodes:** Creates the element with the same name and namespace, but no attributes or children
- **Attribute nodes:** Creates the attribute with the same name, namespace, and value
- **Text nodes:** Creates a text node with the same content
- **Comment nodes:** Creates a comment with the same content
- **Processing instruction nodes:** Creates a PI with the same target and content
- **Document nodes:** Creates a new document node

### copy-namespaces Attribute

By default, `xsl:copy` copies all in-scope namespace declarations. You can suppress this:

```xml
<xsl:copy copy-namespaces="no">
  <xsl:apply-templates select="@* | node()"/>
</xsl:copy>
```

This is useful when you want to clean up namespace declarations that are no longer needed.

---

## xsl:copy-of

Creates a deep copy of a node — the node, all its attributes, children, descendants, and namespace declarations. No further processing is done on the copied content.

```xml
<!-- Deep copy a single element with all its content -->
<xsl:copy-of select="product"/>

<!-- Deep copy all products -->
<xsl:copy-of select="//product"/>

<!-- Deep copy a variable's content -->
<xsl:copy-of select="$saved-fragment"/>
```

### copy-of vs. copy

| | `xsl:copy` | `xsl:copy-of` |
|---|---|---|
| **Depth** | Shallow (node only) | Deep (entire subtree) |
| **Processing** | You control what goes inside | None — exact replica |
| **Use case** | Modify-and-copy | Pass-through |
| **Attributes** | Must be explicitly included | Automatically included |

```xml
<!-- xsl:copy: shallow, you must fill it -->
<xsl:template match="product">
  <xsl:copy>
    <xsl:copy-of select="@*"/>          <!-- copy all attributes -->
    <xsl:apply-templates select="node()"/>  <!-- process children -->
  </xsl:copy>
</xsl:template>

<!-- xsl:copy-of: deep, exact replica -->
<xsl:copy-of select="product"/>
```

### copy-of vs. sequence

`xsl:copy-of` creates a new, independent copy of the nodes. `xsl:sequence` returns a reference to the original nodes:

```xml
<!-- copy-of: new nodes, no connection to source -->
<xsl:variable name="snapshot">
  <xsl:copy-of select="//product"/>
</xsl:variable>
<!-- Nodes in $snapshot have no parent in the source tree -->

<!-- sequence: references to original nodes -->
<xsl:variable name="refs" as="element(product)*">
  <xsl:sequence select="//product"/>
</xsl:variable>
<!-- Nodes in $refs ARE the original nodes — ancestor::catalog still works -->
```

**C# parallel:**

| XSLT | C# |
|------|-----|
| `xsl:copy-of` | Deep clone: `node.DeepClone()` or `with { }` on a record (new object) |
| `xsl:sequence` | Reference: `var x = obj;` (same object) |

---

## The Identity Transform

The identity transform copies an entire document unchanged. It is the foundation for the "modify-and-copy" pattern — the most common XSLT design pattern.

### XSLT 1.0 Version (Verbose)

```xml
<!-- Copy everything by default -->
<xsl:template match="@* | node()">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
  </xsl:copy>
</xsl:template>
```

This single template handles every node type:
1. **`@*`** matches any attribute — `xsl:copy` copies it
2. **`node()`** matches elements, text, comments, and PIs — `xsl:copy` creates a shallow copy, then `xsl:apply-templates` recursively processes children and attributes

The result: a bit-for-bit copy of the entire input document. On its own, this is useless. The power comes from adding override templates that handle specific nodes differently while everything else passes through unchanged.

### XSLT 3.0 Version (Concise)

XSLT 3.0 lets you declare the identity transform behavior on a mode, eliminating the need for the explicit template:

```xml
<xsl:mode on-no-match="shallow-copy"/>
```

This single declaration says: "For any node that does not match an explicit template, do a shallow copy and process its children." It replaces the entire identity template.

Your stylesheet then only contains templates for the nodes you want to change:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <xsl:mode on-no-match="shallow-copy"/>

  <!-- Only this template is needed — everything else passes through -->
  <xsl:template match="price">
    <price currency="USD"><xsl:value-of select=". * 1.1"/></price>
  </xsl:template>
</xsl:stylesheet>
```

**C# parallel:** This is the visitor pattern. In C#:

```csharp
class PriceAdjuster : XmlVisitor
{
    // Override only what you need to change
    public override XElement VisitElement(XElement element)
    {
        if (element.Name == "price")
            return new XElement("price",
                new XAttribute("currency", "USD"),
                (decimal)element * 1.1m);

        // Default: visit children (identity behavior)
        return base.VisitElement(element);
    }
}
```

---

## on-no-match Behaviors

The `on-no-match` attribute on `xsl:mode` controls what happens to nodes that do not match any explicit template. XSLT 3.0 defines six behaviors:

| Value | Behavior | Use Case |
|-------|----------|----------|
| `shallow-copy` | Copy the node, process children | Identity transform (most common) |
| `deep-copy` | Copy the node and all descendants without processing | Pass-through with no modification possible |
| `text-only-copy` | Output only text content (XSLT 1.0 built-in behavior) | Default if `on-no-match` is not specified |
| `shallow-skip` | Skip the node, but process its children | Strip wrappers, keep content |
| `deep-skip` | Skip the node and all descendants | Suppress unmatched content entirely |
| `fail` | Raise an error | Ensure every node type is explicitly handled |

### shallow-copy (Identity)

```xml
<xsl:mode on-no-match="shallow-copy"/>
```

This is the default for modify-and-copy stylesheets. Every unmatched node is copied; only your explicit templates alter the output.

### deep-copy

```xml
<xsl:mode on-no-match="deep-copy"/>
```

Like `shallow-copy`, but unmatched nodes are deep-copied without processing their children. This means templates cannot fire on descendants of unmatched nodes. Rarely used.

### text-only-copy

```xml
<xsl:mode on-no-match="text-only-copy"/>
```

This is the XSLT 1.0 / 2.0 default behavior (the built-in template rules). Unmatched elements are skipped but their children are processed, so text content bubbles up. This is why an XSLT stylesheet with no templates outputs all the text from the document.

### shallow-skip

```xml
<xsl:mode on-no-match="shallow-skip"/>
```

Unmatched nodes are dropped from the output, but their children are still processed. Use this when you want to strip all wrapper elements and only keep content that your templates explicitly handle.

```xml
<!-- Strip all formatting elements, keep only the text they wrap -->
<xsl:mode on-no-match="shallow-skip"/>

<xsl:template match="p | li | td">
  <xsl:copy>
    <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>
<!-- Result: <b>, <i>, <span>, etc. are stripped; their text content remains -->
```

### deep-skip

```xml
<xsl:mode on-no-match="deep-skip"/>
```

Unmatched nodes and all their descendants are completely suppressed. Only nodes that match an explicit template appear in the output.

### fail

```xml
<xsl:mode on-no-match="fail"/>
```

Raises an error if any node does not match a template. Use this during development to ensure complete coverage — every element type in your input must have a matching template.

---

## Practical Patterns

All of the following patterns assume you have the identity transform in place (either the XSLT 1.0 template or `<xsl:mode on-no-match="shallow-copy"/>`).

### Modifying Attribute Values

Change a specific attribute while preserving everything else:

```xml
<xsl:mode on-no-match="shallow-copy"/>

<!-- Update all prices by 10% -->
<xsl:template match="product/price/text()">
  <xsl:value-of select=". * 1.1"/>
</xsl:template>
```

Or modify an attribute:

```xml
<!-- Change status from "draft" to "published" -->
<xsl:template match="product/@status[. = 'draft']">
  <xsl:attribute name="status">published</xsl:attribute>
</xsl:template>
```

### Adding Attributes

```xml
<!-- Add a "processed" timestamp to every product -->
<xsl:template match="product">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:attribute name="processed"><xsl:value-of select="current-dateTime()"/></xsl:attribute>
    <xsl:apply-templates select="node()"/>
  </xsl:copy>
</xsl:template>
```

**Note:** The order matters — attributes must be added before any child nodes. `xsl:attribute` after a child element is an error.

### Removing Attributes

```xml
<!-- Remove the "internal-notes" attribute from all elements -->
<xsl:template match="@internal-notes"/>

<!-- Remove all "debug-*" attributes -->
<xsl:template match="@*[starts-with(local-name(), 'debug-')]"/>
```

An empty template matches the node and produces nothing — effectively deleting it from the output.

### Renaming Elements

```xml
<!-- Rename <item> to <product> -->
<xsl:template match="item">
  <product>
    <xsl:apply-templates select="@* | node()"/>
  </product>
</xsl:template>

<!-- Rename <desc> to <description> -->
<xsl:template match="desc">
  <description>
    <xsl:apply-templates select="@* | node()"/>
  </description>
</xsl:template>
```

### Filtering Elements (Suppressing Nodes)

```xml
<!-- Remove all <internal-notes> elements -->
<xsl:template match="internal-notes"/>

<!-- Remove products that are discontinued -->
<xsl:template match="product[@status = 'discontinued']"/>

<!-- Remove empty elements -->
<xsl:template match="*[not(node()) and not(@*)]"/>
```

### Adding New Child Elements

```xml
<!-- Add a calculated <total> element to each order-item -->
<xsl:template match="order-item">
  <xsl:copy>
    <xsl:apply-templates select="@* | node()"/>
    <!-- Add new element after existing children -->
    <total><xsl:value-of select="price * quantity"/></total>
  </xsl:copy>
</xsl:template>
```

### Wrapping Elements

```xml
<!-- Wrap each <product> in a <div> -->
<xsl:template match="product">
  <div class="product-wrapper">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </div>
</xsl:template>
```

### Unwrapping Elements

```xml
<!-- Remove the <wrapper> element but keep its content -->
<xsl:template match="wrapper">
  <xsl:apply-templates select="node()"/>
</xsl:template>
```

### Restructuring (Moving Elements)

```xml
<!-- Move <price> from being a child of <details> to a direct child of <product> -->
<xsl:template match="product">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <!-- Pull price out of details -->
    <xsl:apply-templates select="details/price"/>
    <xsl:apply-templates select="node()"/>
  </xsl:copy>
</xsl:template>

<!-- Suppress price in its original location (it was already output above) -->
<xsl:template match="details/price"/>
```

### Conditional Modification

```xml
<!-- Only modify products in the "electronics" category -->
<xsl:template match="product[@category = 'electronics']/price/text()">
  <xsl:value-of select=". * 0.9"/>  <!-- 10% discount on electronics -->
</xsl:template>

<!-- All other products pass through unchanged (identity transform handles them) -->
```

### Complete Example: Document Migration

Here is a realistic stylesheet that migrates a product catalog from an old schema to a new one:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <xsl:mode on-no-match="shallow-copy"/>

  <!-- Rename root element -->
  <xsl:template match="product-list">
    <catalog version="2.0">
      <xsl:apply-templates select="@* | node()"/>
    </catalog>
  </xsl:template>

  <!-- Rename item to product, add required ID if missing -->
  <xsl:template match="item">
    <product>
      <xsl:if test="not(@id)">
        <xsl:attribute name="id" select="generate-id()"/>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </product>
  </xsl:template>

  <!-- Rename desc to description -->
  <xsl:template match="item/desc">
    <description><xsl:apply-templates/></description>
  </xsl:template>

  <!-- Convert price from string to structured element -->
  <xsl:template match="item/cost">
    <price currency="{(@currency, 'USD')[1]}">
      <xsl:value-of select="format-number(number(.), '#0.00')"/>
    </price>
  </xsl:template>

  <!-- Remove deprecated elements -->
  <xsl:template match="legacy-code | internal-ref"/>

  <!-- Remove deprecated attributes -->
  <xsl:template match="@old-system-id"/>
</xsl:stylesheet>
```

**C# parallel:** The entire identity-transform-with-overrides pattern is the **visitor pattern**. In C#, you would write:

```csharp
// C# visitor pattern equivalent
class SchemaMigrationVisitor : XmlVisitor
{
    protected override XElement Visit(XElement element) => element.Name.LocalName switch
    {
        "product-list" => new XElement("catalog", new XAttribute("version", "2.0"),
                              element.Attributes().Select(Visit),
                              element.Elements().Select(Visit)),
        "item"         => new XElement("product", /* ... */),
        "desc"         => new XElement("description", element.Value),
        "legacy-code"  => null, // suppress
        _              => base.Visit(element)  // identity (pass through)
    };
}
```

Or using C# 9+ record expressions for immutable modification:

```csharp
// Record-style immutable modification (conceptually similar)
var updated = original with { Price = original.Price * 1.1m };
```

The XSLT approach is more concise for XML-to-XML transformations because the identity transform handles the boilerplate of copying every node you did not explicitly change.
