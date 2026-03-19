---
title: Control Flow
description: "xsl:if, xsl:choose, xsl:switch, xsl:where-populated, xsl:on-empty"
sort: 2
---

# Control Flow

XSLT provides conditional instructions that determine what output to produce based on runtime conditions. If you come from C#, you will find familiar concepts here — `if`, `switch`, and some patterns that have no direct C# equivalent but solve real problems elegantly.

## Contents

- [xsl:if](#xslif)
- [xsl:choose / xsl:when / xsl:otherwise](#xslchoose)
- [xsl:switch (XSLT 4.0)](#xslswitch-xslt-40)
- [xsl:where-populated](#xslwhere-populated)
- [xsl:on-empty and xsl:on-non-empty](#xslon-empty-and-xslon-non-empty)
- [Common Patterns](#common-patterns)

---

## xsl:if

Simple conditional — if the test expression is true, execute the body. There is no `else` branch.

```xml
<xsl:if test="price > 100">
  <span class="premium-badge">Premium</span>
</xsl:if>
```

**C# parallel:** `if (price > 100) { ... }` — except there is no `else`. For if/else, use `xsl:choose`.

### Effective Boolean Value

The `test` attribute evaluates its XPath expression and converts the result to a boolean using the "effective boolean value" (EBV) rules. Understanding EBV is essential for writing correct conditions:

| Expression Result | Boolean Value | Example |
|---|---|---|
| Empty sequence `()` | `false` | `test="product"` is false when there are no `product` children |
| Non-empty sequence | `true` | `test="product"` is true when at least one `product` child exists |
| Empty string `""` | `false` | `test="@category"` is false when the attribute is empty |
| Non-empty string | `true` | `test="@category"` is true when the attribute has a value |
| Number `0` or `NaN` | `false` | `test="count(item)"` is false when there are no items |
| Any other number | `true` | `test="count(item)"` is true when items exist |
| Boolean `false()` | `false` | Explicit false |
| Boolean `true()` | `true` | Explicit true |

This means you can write very concise existence checks:

```xml
<!-- Check if element exists (has children named "description") -->
<xsl:if test="description">
  <p><xsl:value-of select="description"/></p>
</xsl:if>

<!-- Check if attribute exists and is non-empty -->
<xsl:if test="@discount">
  <span class="discount"><xsl:value-of select="@discount"/>% off</span>
</xsl:if>

<!-- Check if a string value is present -->
<xsl:if test="normalize-space(notes)">
  <div class="notes"><xsl:value-of select="notes"/></div>
</xsl:if>
```

**C# parallel:** This is similar to C#'s truthiness in pattern matching, but more pervasive. In XSLT, the node-existence test `test="description"` is the equivalent of C#'s null check `if (description != null)`.

### Common Conditions

```xml
<!-- Equality -->
<xsl:if test="@status = 'active'">...</xsl:if>

<!-- Numeric comparison -->
<xsl:if test="price >= 50 and price &lt; 100">...</xsl:if>

<!-- Note: < must be escaped as &lt; in XML attributes -->
<!-- Alternative using not(): -->
<xsl:if test="not(price >= 100) and price >= 50">...</xsl:if>

<!-- Existence check -->
<xsl:if test="@id">...</xsl:if>

<!-- Position-based (inside for-each) -->
<xsl:if test="position() != last()">
  <xsl:text>, </xsl:text>
</xsl:if>

<!-- Multiple conditions -->
<xsl:if test="@category = 'electronics' and price > 50">...</xsl:if>
<xsl:if test="@status = 'sale' or @status = 'clearance'">...</xsl:if>
```

**Gotcha:** You cannot write `<xsl:if test="price < 100">` because `<` is not valid inside an XML attribute. Use `&lt;` or reverse the comparison: `test="not(price >= 100)"` or `test="100 > price"`.

---

## xsl:choose

Multi-branch conditional — the XSLT equivalent of `if / else if / else` or `switch`. This is your go-to when you need more than a simple `xsl:if`.

```xml
<xsl:choose>
  <xsl:when test="price > 100">
    <span class="tier">Premium</span>
  </xsl:when>
  <xsl:when test="price > 50">
    <span class="tier">Standard</span>
  </xsl:when>
  <xsl:when test="price > 0">
    <span class="tier">Budget</span>
  </xsl:when>
  <xsl:otherwise>
    <span class="tier">Free</span>
  </xsl:otherwise>
</xsl:choose>
```

**C# parallel:**
```csharp
var tier = price switch
{
    > 100 => "Premium",
    > 50  => "Standard",
    > 0   => "Budget",
    _     => "Free"
};
```

### Structure Rules

- `xsl:choose` must contain one or more `xsl:when` elements
- `xsl:otherwise` is optional and must be last
- The first `xsl:when` whose `test` is true wins — subsequent branches are skipped (just like `else if`)
- If no `xsl:when` matches and there is no `xsl:otherwise`, nothing is produced

### Pattern: Value Mapping

```xml
<!-- Map status codes to display labels -->
<xsl:choose>
  <xsl:when test="@status = 'A'">Active</xsl:when>
  <xsl:when test="@status = 'D'">Discontinued</xsl:when>
  <xsl:when test="@status = 'P'">Pending Review</xsl:when>
  <xsl:otherwise>Unknown (<xsl:value-of select="@status"/>)</xsl:otherwise>
</xsl:choose>
```

### Pattern: Type-Based Processing

```xml
<!-- Render different content types -->
<xsl:choose>
  <xsl:when test="self::image">
    <img src="{@src}" alt="{@alt}"/>
  </xsl:when>
  <xsl:when test="self::video">
    <video src="{@src}" controls="controls"/>
  </xsl:when>
  <xsl:when test="self::text">
    <p><xsl:value-of select="."/></p>
  </xsl:when>
</xsl:choose>
```

Note: For type-based processing, template matching (`xsl:template match="image"`, etc.) is usually a better fit. Reserve `xsl:choose` for conditions that depend on values rather than element names.

---

## xsl:switch (XSLT 4.0)

XSLT 4.0 introduces `xsl:switch` — a cleaner syntax for value-based branching. It evaluates a single `select` expression and matches the result against multiple cases.

```xml
<xsl:switch select="@category">
  <xsl:when test="'electronics'">
    <span class="icon">&#x1F4BB;</span>
  </xsl:when>
  <xsl:when test="'clothing'">
    <span class="icon">&#x1F455;</span>
  </xsl:when>
  <xsl:when test="'books'">
    <span class="icon">&#x1F4DA;</span>
  </xsl:when>
  <xsl:otherwise>
    <span class="icon">&#x1F4E6;</span>
  </xsl:otherwise>
</xsl:switch>
```

The key difference from `xsl:choose`:

| | `xsl:choose` | `xsl:switch` |
|---|---|---|
| **Evaluated** | Each `xsl:when/@test` independently | `xsl:switch/@select` once, then compared to each `xsl:when/@test` |
| **Comparison** | Each test is a full boolean expression | Each test is a value compared with `=` to the switch expression |
| **Best for** | Complex conditions, range checks | Simple value matching |

**C# parallel:** `xsl:switch` maps directly to C#'s `switch` statement or switch expression:

```csharp
var icon = category switch
{
    "electronics" => "\U0001F4BB",
    "clothing"    => "\U0001F455",
    "books"       => "\U0001F4DA",
    _             => "\U0001F4E6"
};
```

### Multiple Values per Case

Each `xsl:when` can match multiple values if the test expression returns a sequence:

```xml
<xsl:switch select="@status">
  <xsl:when test="('active', 'enabled')">
    <span class="badge-green">Available</span>
  </xsl:when>
  <xsl:when test="('discontinued', 'disabled')">
    <span class="badge-red">Unavailable</span>
  </xsl:when>
  <xsl:otherwise>
    <span class="badge-gray">Unknown</span>
  </xsl:otherwise>
</xsl:switch>
```

This is equivalent to C#'s multi-case pattern:

```csharp
switch (status)
{
    case "active":
    case "enabled":
        // ...
        break;
}
```

---

## xsl:where-populated

Conditionally produces its content only if the content is non-empty. This solves the "conditional wrapper" problem — you want to output a container element only if there is something to put in it.

### The Problem

Consider this common situation: you want to output a `<ul>` of tags, but only if there are tags:

```xml
<!-- Without where-populated: you have to check twice -->
<xsl:if test="tag">
  <ul class="tags">
    <xsl:for-each select="tag">
      <li><xsl:value-of select="."/></li>
    </xsl:for-each>
  </ul>
</xsl:if>
```

The condition in `xsl:if` duplicates the logic of the `xsl:for-each`. If the selection logic is complex, this duplication becomes a maintenance problem.

### The Solution

```xml
<xsl:where-populated>
  <ul class="tags">
    <xsl:for-each select="tag">
      <li><xsl:value-of select="."/></li>
    </xsl:for-each>
  </ul>
</xsl:where-populated>
```

`xsl:where-populated` evaluates its content. If the content produces any output (nodes or text), it is emitted. If the content produces nothing, the entire block — including the `<ul>` wrapper — is suppressed.

### Practical Example

```xml
<xsl:template match="product">
  <div class="product">
    <h3><xsl:value-of select="name"/></h3>

    <!-- Only show specs table if there are specs -->
    <xsl:where-populated>
      <table class="specs">
        <xsl:for-each select="spec">
          <tr>
            <td><xsl:value-of select="@name"/></td>
            <td><xsl:value-of select="."/></td>
          </tr>
        </xsl:for-each>
      </table>
    </xsl:where-populated>

    <!-- Only show related products section if any exist -->
    <xsl:where-populated>
      <section class="related">
        <h4>Related Products</h4>
        <xsl:apply-templates select="//product[@id = current()/related/@ref]"/>
      </section>
    </xsl:where-populated>
  </div>
</xsl:template>
```

**C# parallel:** There is no direct C# equivalent. The closest pattern is a Razor helper that checks for content:

```csharp
@if (items.Any())
{
    <ul>
        @foreach (var item in items) { <li>@item</li> }
    </ul>
}
```

`xsl:where-populated` avoids the need to write the check separately.

---

## xsl:on-empty and xsl:on-non-empty

These instructions provide fallback or conditional content based on whether the preceding sibling instructions produced any output.

### xsl:on-empty

Produces output only if nothing else in the same sequence constructor produced output. Think of it as a "default" or "fallback."

```xml
<xsl:template match="product">
  <p class="description">
    <xsl:value-of select="description"/>
    <xsl:on-empty>No description available.</xsl:on-empty>
  </p>
</xsl:template>
```

If the `description` element is empty or missing, the output is:

```html
<p class="description">No description available.</p>
```

### xsl:on-non-empty

The inverse — produces output only if preceding instructions did produce output. Useful for adding decorative wrappers or separators:

```xml
<xsl:template match="product">
  <div class="product">
    <h3><xsl:value-of select="name"/></h3>
    <xsl:apply-templates select="tag"/>
    <xsl:on-non-empty>
      <hr/>
    </xsl:on-non-empty>
    <xsl:apply-templates select="review"/>
  </div>
</xsl:template>
```

Here, the `<hr/>` only appears if there were tags. If the product has no tags, no `<hr/>` is produced.

### Combined Example

```xml
<xsl:template match="product">
  <div class="product-card">
    <h3><xsl:value-of select="name"/></h3>

    <div class="tags">
      <xsl:for-each select="tag">
        <span class="tag"><xsl:value-of select="."/></span>
      </xsl:for-each>
      <xsl:on-empty>
        <span class="no-tags">Uncategorized</span>
      </xsl:on-empty>
    </div>
  </div>
</xsl:template>
```

**C# parallel:** The null-coalescing operator `??` or the `DefaultIfEmpty()` LINQ method:

```csharp
var displayTags = product.Tags.Any()
    ? product.Tags
    : new[] { "Uncategorized" };
```

### Placement Rules

- `xsl:on-empty` and `xsl:on-non-empty` must be the last instructions in their parent sequence constructor
- They evaluate whether everything before them in the same parent produced output
- They can appear inside `xsl:where-populated` for layered conditional logic

---

## Common Patterns

### Combining Conditions with and / or

```xml
<!-- Product is on sale AND in stock -->
<xsl:if test="@on-sale = 'true' and stock > 0">
  <span class="available-sale">On Sale — In Stock!</span>
</xsl:if>

<!-- Product is either new or featured -->
<xsl:if test="@new = 'true' or @featured = 'true'">
  <span class="highlight">Recommended</span>
</xsl:if>
```

### Nested choose

When you need multi-dimensional branching:

```xml
<xsl:choose>
  <xsl:when test="@category = 'electronics'">
    <xsl:choose>
      <xsl:when test="price > 500">High-end Electronics</xsl:when>
      <xsl:when test="price > 100">Mid-range Electronics</xsl:when>
      <xsl:otherwise>Budget Electronics</xsl:otherwise>
    </xsl:choose>
  </xsl:when>
  <xsl:when test="@category = 'clothing'">
    <!-- ... -->
  </xsl:when>
</xsl:choose>
```

**Tip:** Deeply nested `xsl:choose` is a code smell. Consider extracting inner conditions into separate templates or functions.

### Null-Checking with xsl:if

A common pattern is checking whether a value exists before using it:

```xml
<xsl:template match="product">
  <div class="product">
    <h3><xsl:value-of select="name"/></h3>

    <!-- Only show price if it exists -->
    <xsl:if test="price">
      <p class="price">$<xsl:value-of select="price"/></p>
    </xsl:if>

    <!-- Only show image if src attribute is present and non-empty -->
    <xsl:if test="normalize-space(image/@src)">
      <img src="{image/@src}" alt="{name}"/>
    </xsl:if>

    <!-- Only show discount if it's a positive number -->
    <xsl:if test="number(@discount) > 0">
      <span class="discount"><xsl:value-of select="@discount"/>% off</span>
    </xsl:if>
  </div>
</xsl:template>
```

**C# parallel:** Null-conditional operators `?.` and null-coalescing `??`:

```csharp
// C# null checks
if (product.Price != null)
    html += $"<p class='price'>${product.Price}</p>";

if (!string.IsNullOrWhiteSpace(product.Image?.Src))
    html += $"<img src='{product.Image.Src}'/>";
```

### Separator Pattern (Comma-Separated Lists)

```xml
<xsl:for-each select="tag">
  <xsl:if test="position() > 1">
    <xsl:text>, </xsl:text>
  </xsl:if>
  <xsl:value-of select="."/>
</xsl:for-each>
<!-- Output: electronics, sale, new -->
```

Or more simply, use `xsl:value-of` with `separator`:

```xml
<xsl:value-of select="tag" separator=", "/>
```
