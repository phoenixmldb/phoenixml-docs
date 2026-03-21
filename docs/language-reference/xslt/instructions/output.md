---
title: Output Instructions
description: "xsl:value-of, xsl:text, xsl:comment, xsl:processing-instruction, xsl:sequence, xsl:message"
sort: 1
---

# Output Instructions

These instructions control what your stylesheet produces — text, typed values, comments, processing instructions, and diagnostic messages. If templates are the structure of your transformation, output instructions are the bricks.

## Contents

- [xsl:value-of](#xslvalue-of)
- [xsl:text](#xsltext)
- [xsl:sequence](#xslsequence)
- [xsl:comment](#xslcomment)
- [xsl:processing-instruction](#xslprocessing-instruction)
- [xsl:message](#xslmessage)

---

## xsl:value-of

Creates a text node from the string value of an expression. This is the workhorse instruction for producing text output.

### Basic Usage

```xml
<xsl:template match="product">
  <p>
    <xsl:value-of select="name"/>: $<xsl:value-of select="price"/>
  </p>
</xsl:template>
```

Given `<product><name>Widget Pro</name><price>29.99</price></product>`, this produces:

```html
<p>Widget Pro: $29.99</p>
```

**C# parallel:** This is like Razor's `@Model.Name` — it evaluates an expression and inserts the string value into the output.

### The separator Attribute

When `select` evaluates to a sequence of multiple items, `separator` controls how they are joined. The default separator is a single space in XSLT 2.0+ (it was undefined in XSLT 1.0, which only took the first item).

```xml
<!-- Input: multiple <tag> children -->
<product>
  <tag>electronics</tag>
  <tag>sale</tag>
  <tag>new</tag>
</product>

<!-- Join with comma-space -->
<xsl:value-of select="tag" separator=", "/>
<!-- Output: electronics, sale, new -->

<!-- Join with pipe -->
<xsl:value-of select="tag" separator=" | "/>
<!-- Output: electronics | sale | new -->

<!-- No separator — concatenate directly -->
<xsl:value-of select="('A','B','C')" separator=""/>
<!-- Output: ABC -->
```

**C# parallel:** `string.Join(", ", tags)`

### Content Instead of select

You can put a sequence constructor inside `xsl:value-of` instead of using `select`. The output of the constructor is atomized and converted to a string:

```xml
<xsl:value-of>
  <xsl:text>Order #</xsl:text>
  <xsl:value-of select="@id"/>
  <xsl:text> placed on </xsl:text>
  <xsl:value-of select="format-date(@date, '[MNn] [D], [Y]')"/>
</xsl:value-of>
```

This is rarely needed — string concatenation in the `select` attribute or literal text is usually cleaner.

### value-of vs. sequence

This is a critical distinction:

| | `xsl:value-of` | `xsl:sequence` |
|---|---|---|
| **Returns** | Always a text node (string) | The original typed value |
| **Sequences** | Joins items with separator | Returns the sequence as-is |
| **Nodes** | Extracts string value | Returns the node itself |
| **Use in functions** | Rarely correct | Almost always what you want |

```xml
<!-- value-of stringifies everything -->
<xsl:value-of select="42"/>          <!-- text node "42" -->
<xsl:value-of select="(1, 2, 3)"/>   <!-- text node "1 2 3" -->

<!-- sequence preserves types -->
<xsl:sequence select="42"/>           <!-- xs:integer 42 -->
<xsl:sequence select="(1, 2, 3)"/>    <!-- sequence of three integers -->
```

**Rule of thumb:** Use `xsl:value-of` when you are producing text for output. Use `xsl:sequence` when you are returning values from functions or building sequences for further processing.

---

## xsl:text

Produces a text node with exact whitespace control. While you can write literal text directly in a template, `xsl:text` gives you precise control over what whitespace appears in the output.

### Why xsl:text Exists

In XSLT, whitespace between instructions is significant — it ends up in the output. Consider:

```xml
<xsl:template match="product">
  <span>
    <xsl:value-of select="name"/>
    -
    <xsl:value-of select="@sku"/>
  </span>
</xsl:template>
```

This produces `<span>\n    Widget Pro\n    -\n    WP-001\n  </span>` with newlines and indentation — usually not what you want. Using `xsl:text` lets you control the output exactly:

```xml
<xsl:template match="product">
  <span>
    <xsl:value-of select="name"/>
    <xsl:text> - </xsl:text>
    <xsl:value-of select="@sku"/>
  </span>
</xsl:template>
```

Now the output is `<span>Widget Pro - WP-001</span>` (plus the whitespace around the `span` tags, but the content between the text nodes is controlled).

For fully clean output, wrap everything:

```xml
<xsl:template match="product">
  <span><xsl:value-of select="name"/><xsl:text> - </xsl:text><xsl:value-of select="@sku"/></span>
</xsl:template>
<!-- Output: <span>Widget Pro - WP-001</span> -->
```

**C# parallel:** Think of `xsl:text` like a `@:` line in Razor — it explicitly marks content as text output rather than code.

### disable-output-escaping

The `disable-output-escaping` attribute (abbreviated `doe` in some discussions) tells the serializer not to escape special characters:

```xml
<!-- Normal behavior -->
<xsl:text>&lt;br/&gt;</xsl:text>
<!-- Output: &lt;br/&gt; (escaped, appears as literal text in browser) -->

<!-- With disable-output-escaping -->
<xsl:text disable-output-escaping="yes">&lt;br/&gt;</xsl:text>
<!-- Output: <br/> (raw markup injected into output) -->
```

**Warning:** `disable-output-escaping` is widely considered an anti-pattern. It breaks the tree model — you are injecting raw characters into what should be a well-formed node tree. It does not work in all serialization scenarios and is not supported by all processors. If you need to produce raw markup, consider using `xsl:output method="html"` or building proper nodes with `xsl:element`.

**C# parallel:** `Html.Raw()` in Razor — same capability, same "use with caution" advice.

### Outputting Special Characters

`xsl:text` is the standard way to output characters that would be awkward as literal text:

```xml
<!-- Newline -->
<xsl:text>&#10;</xsl:text>

<!-- Tab -->
<xsl:text>&#9;</xsl:text>

<!-- Non-breaking space -->
<xsl:text>&#160;</xsl:text>

<!-- Combining them -->
<xsl:text>Name&#9;Price&#9;Stock&#10;</xsl:text>
```

---

## xsl:sequence

Returns a value — any value — without converting it to a string. This is the most important output instruction for XSLT 2.0+ and is essential for writing functions.

### Basic Usage

```xml
<xsl:sequence select="42"/>                     <!-- returns integer 42 -->
<xsl:sequence select="'hello'"/>                <!-- returns string "hello" -->
<xsl:sequence select="true()"/>                 <!-- returns boolean true -->
<xsl:sequence select="(1, 2, 3)"/>              <!-- returns sequence of 3 integers -->
<xsl:sequence select="//product"/>              <!-- returns sequence of product nodes -->
```

### Why xsl:sequence Matters for Functions

When you write an `xsl:function`, the return value is the sequence constructed by the function body. If you use `xsl:value-of`, you always get a text node — even if you wanted a number or a boolean:

```xml
<!-- WRONG: returns a text node "42", not the integer 42 -->
<xsl:function name="my:answer" as="xs:integer">
  <xsl:value-of select="42"/>
</xsl:function>

<!-- RIGHT: returns the integer 42 -->
<xsl:function name="my:answer" as="xs:integer">
  <xsl:sequence select="42"/>
</xsl:function>
```

**C# parallel:** `xsl:sequence` is like a `return` statement. `xsl:value-of` is like `return value.ToString()` — it works, but you lose the type.

### Returning Nodes

`xsl:sequence` returns a reference to existing nodes, while `xsl:copy-of` creates deep copies. This matters for identity comparisons and performance:

```xml
<!-- Returns a reference to the original node -->
<xsl:sequence select="//product[@id='WP-001']"/>

<!-- Returns a deep copy (new node, different identity) -->
<xsl:copy-of select="//product[@id='WP-001']"/>
```

### Building Sequences

You can build sequences incrementally:

```xml
<xsl:function name="my:price-range" as="xs:decimal+">
  <xsl:param name="products" as="element(product)*"/>
  <xsl:sequence select="min($products/price)"/>
  <xsl:sequence select="max($products/price)"/>
</xsl:function>

<!-- Usage: -->
<!-- my:price-range(//product) returns (9.99, 299.99) -->
```

### In Template Bodies

Inside a template, `xsl:sequence` can return nodes for further processing:

```xml
<xsl:variable name="active-products" as="element(product)*">
  <xsl:sequence select="//product[@status='active']"/>
</xsl:variable>

<!-- The variable holds references to the original nodes -->
<xsl:for-each select="$active-products">
  <!-- context node is the original product element, with all its relationships intact -->
  <xsl:value-of select="ancestor::category/name"/>
</xsl:for-each>
```

---

## xsl:comment

Generates an XML or HTML comment in the output.

```xml
<xsl:comment>Generated by ProductCatalog.xslt on <xsl:value-of select="current-dateTime()"/></xsl:comment>
```

Output:

```xml
<!-- Generated by ProductCatalog.xslt on 2026-03-19T14:30:00 -->
```

### Dynamic Comments

The content is a sequence constructor, so you can use any XSLT instruction inside:

```xml
<xsl:comment>
  <xsl:text>Product count: </xsl:text>
  <xsl:value-of select="count(//product)"/>
  <xsl:text> | Categories: </xsl:text>
  <xsl:value-of select="count(//category)"/>
</xsl:comment>
<!-- Output: <!-- Product count: 42 | Categories: 5 --> -->
```

### Practical Uses

- **Debug markers:** Inject comments to trace which template produced which output
- **Build metadata:** Stamp generation time, source file, or version info
- **Conditional comments for IE:** (historical, but still found in legacy code)

```xml
<!-- Debug: mark template boundaries -->
<xsl:template match="product">
  <xsl:comment>BEGIN product <xsl:value-of select="@id"/></xsl:comment>
  <div class="product">
    <xsl:apply-templates/>
  </div>
  <xsl:comment>END product <xsl:value-of select="@id"/></xsl:comment>
</xsl:template>
```

**C# parallel:** `<!-- -->` in Razor, or `@* *@` for Razor comments (which don't appear in output).

**Note:** The XSLT processor will automatically prevent `--` from appearing inside the comment content (it would break well-formedness). If your content contains `--`, a space is inserted to produce `- -`.

---

## xsl:processing-instruction

Generates a processing instruction in the output.

```xml
<xsl:processing-instruction name="xml-stylesheet">
  <xsl:text>type="text/css" href="catalog.css"</xsl:text>
</xsl:processing-instruction>
```

Output:

```xml
<?xml-stylesheet type="text/css" href="catalog.css"?>
```

### Dynamic PI Names

The `name` attribute can be an attribute value template:

```xml
<xsl:processing-instruction name="{$pi-name}">
  <xsl:value-of select="$pi-content"/>
</xsl:processing-instruction>
```

### Practical Uses

Processing instructions are relatively uncommon in modern XML, but you may encounter them for:

- **Stylesheet associations:** `<?xml-stylesheet?>` in XML documents
- **Application-specific directives:** Some systems use PIs for page breaks, soft hyphens, or other rendering hints
- **PHP-style template markers:** If you are generating PHP output from XSLT

```xml
<!-- Generate a PHP include -->
<xsl:processing-instruction name="php">
  <xsl:text>include 'header.php';</xsl:text>
</xsl:processing-instruction>
<!-- Output: <?php include 'header.php';?> -->
```

**Note:** You cannot generate the XML declaration (`<?xml version="1.0"?>`) with `xsl:processing-instruction` — use `xsl:output` for that.

---

## xsl:message

Sends a message to the XSLT processor's message output — typically the console or a log. This is your primary debugging tool.

### Basic Diagnostic Output

```xml
<xsl:template match="product">
  <xsl:message>Processing product: <xsl:value-of select="@id"/> - <xsl:value-of select="name"/></xsl:message>
  <!-- ... normal template body ... -->
</xsl:template>
```

The message appears on stderr (or the processor's message handler) but does not appear in the transformation output. This is exactly like `Console.Error.WriteLine()` or `Debug.WriteLine()` in C#.

### The terminate Attribute

Setting `terminate="yes"` turns the message into a fatal error — the transformation stops immediately:

```xml
<xsl:template match="product[not(@id)]">
  <xsl:message terminate="yes">
    FATAL: Product element at line <xsl:value-of select="saxon:line-number(.)"/>
    is missing required @id attribute.
  </xsl:message>
</xsl:template>
```

**C# parallel:** `throw new InvalidOperationException("...")` — `terminate="yes"` is an exception you cannot catch (in XSLT 2.0). In XSLT 3.0, it raises a recoverable error that `xsl:try`/`xsl:catch` can handle.

### The select Attribute

Instead of using content, you can use `select` for simple messages:

```xml
<xsl:message select="'Entering catalog template'"/>
<xsl:message select="concat('Product count: ', count(product))"/>
```

### The error-code Attribute (XSLT 3.0)

You can specify an error code for programmatic error handling:

```xml
<xsl:message terminate="yes" error-code="Q{http://example.com/errors}MISSING-ID">
  Product is missing required @id attribute.
</xsl:message>
```

This error code can be caught by `xsl:catch`:

```xml
<xsl:try>
  <xsl:apply-templates select="//product"/>
  <xsl:catch errors="Q{http://example.com/errors}MISSING-ID">
    <xsl:message>Skipping product with missing ID</xsl:message>
  </xsl:catch>
</xsl:try>
```

### Debugging Patterns

Use `xsl:message` liberally during development:

```xml
<!-- Trace template entry/exit -->
<xsl:template match="product">
  <xsl:message select="concat('[ENTER] product template, id=', @id)"/>
  <div class="product">
    <xsl:apply-templates/>
  </div>
  <xsl:message select="concat('[EXIT] product template, id=', @id)"/>
</xsl:template>

<!-- Dump variable values -->
<xsl:variable name="total" select="sum(//product/price)"/>
<xsl:message select="concat('Total price: ', $total)"/>

<!-- Conditional debug (controlled by a parameter) -->
<xsl:param name="debug" select="false()" static="yes"/>

<xsl:template match="product">
  <xsl:if test="$debug" use-when="$debug">
    <xsl:message select="concat('DEBUG: product ', @id)"/>
  </xsl:if>
  <!-- ... -->
</xsl:template>
```

**C# parallel:**

| XSLT | C# |
|------|-----|
| `xsl:message` | `Debug.WriteLine()` or `Console.Error.WriteLine()` |
| `xsl:message terminate="yes"` | `throw new Exception()` |
| `xsl:message` with `error-code` | `throw new CustomException()` |

---

## Putting It All Together

Here is a realistic template that uses several output instructions together to produce an HTML product card:

```xml
<xsl:template match="product">
  <xsl:comment>Product: <xsl:value-of select="@id"/></xsl:comment>
  <div class="product-card">
    <h3><xsl:value-of select="name"/></h3>
    <p class="price">
      <xsl:text>$</xsl:text>
      <xsl:value-of select="format-number(price, '#,##0.00')"/>
    </p>
    <xsl:if test="tag">
      <p class="tags">
        <xsl:value-of select="tag" separator=" | "/>
      </p>
    </xsl:if>
  </div>
</xsl:template>
```

Given:

```xml
<product id="WP-001">
  <name>Widget Pro</name>
  <price>29.99</price>
  <tag>electronics</tag>
  <tag>sale</tag>
</product>
```

Output:

```html
<!-- Product: WP-001 -->
<div class="product-card">
  <h3>Widget Pro</h3>
  <p class="price">$29.99</p>
  <p class="tags">electronics | sale</p>
</div>
```
