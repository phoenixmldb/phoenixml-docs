---
title: Grouping
description: "xsl:for-each-group — all four grouping modes with examples"
sort: 5
---

# Grouping

`xsl:for-each-group` is one of the most powerful XSLT instructions. It takes a flat sequence and organizes it into groups using one of four modes. Before XSLT 2.0, grouping required the "Muenchian method" — a clever but cryptic hack using keys. Now it is a first-class operation.

## Contents

- [group-by](#group-by)
- [group-adjacent](#group-adjacent)
- [group-starting-with](#group-starting-with)
- [group-ending-with](#group-ending-with)
- [Sorting Within Groups](#sorting-within-groups)
- [Nested Grouping](#nested-grouping)
- [Real-World Examples](#real-world-examples)

---

## The Four Grouping Modes

All four modes use the same instruction, `xsl:for-each-group`, with different attributes to select the mode. Inside the body, two functions are always available:

- **`current-group()`** — the sequence of all items in the current group
- **`current-grouping-key()`** — the key value for the current group (for `group-by` and `group-adjacent`)

---

## group-by

Groups items by a computed key. All items with the same key value are placed in the same group, regardless of their position in the sequence.

**C# parallel:** `items.GroupBy(x => x.Category)`

### Basic Example

Given this product catalog:

```xml
<catalog>
  <product category="electronics"><name>Laptop</name><price>999.99</price></product>
  <product category="clothing"><name>T-Shirt</name><price>19.99</price></product>
  <product category="electronics"><name>Phone</name><price>699.99</price></product>
  <product category="clothing"><name>Jacket</name><price>89.99</price></product>
  <product category="books"><name>XSLT Guide</name><price>49.99</price></product>
  <product category="electronics"><name>Tablet</name><price>449.99</price></product>
</catalog>
```

```xml
<xsl:for-each-group select="catalog/product" group-by="@category">
  <section>
    <h2><xsl:value-of select="current-grouping-key()"/></h2>
    <ul>
      <xsl:for-each select="current-group()">
        <li><xsl:value-of select="name"/> — $<xsl:value-of select="price"/></li>
      </xsl:for-each>
    </ul>
  </section>
</xsl:for-each-group>
```

Output:

```html
<section>
  <h2>electronics</h2>
  <ul>
    <li>Laptop — $999.99</li>
    <li>Phone — $699.99</li>
    <li>Tablet — $449.99</li>
  </ul>
</section>
<section>
  <h2>clothing</h2>
  <ul>
    <li>T-Shirt — $19.99</li>
    <li>Jacket — $89.99</li>
  </ul>
</section>
<section>
  <h2>books</h2>
  <ul>
    <li>XSLT Guide — $49.99</li>
  </ul>
</section>
```

### Group Order

The groups appear in the order of the first occurrence of each key in the input sequence. In the example above, "electronics" appears first because the first product is in that category.

### Composite Keys

Use `composite="yes"` (XSLT 3.0) to group by multiple values:

```xml
<xsl:for-each-group select="//product" group-by="@category" composite="yes">
  <!-- groups by category -->
</xsl:for-each-group>
```

For grouping by multiple independent keys, concatenate them:

```xml
<!-- Group by category AND status -->
<xsl:for-each-group select="//product"
                    group-by="concat(@category, '|', @status)">
  <xsl:variable name="parts" select="tokenize(current-grouping-key(), '\|')"/>
  <h3><xsl:value-of select="$parts[1]"/> — <xsl:value-of select="$parts[2]"/></h3>
  <!-- ... -->
</xsl:for-each-group>
```

Or more cleanly, use a composite grouping key with a sequence:

```xml
<xsl:for-each-group select="//product"
                    group-by="@category, @status" composite="yes">
  <!-- current-grouping-key() returns a sequence of two values -->
</xsl:for-each-group>
```

### Aggregate Functions on Groups

Since `current-group()` returns all items in the group, you can compute aggregates:

```xml
<xsl:for-each-group select="//product" group-by="@category">
  <tr>
    <td><xsl:value-of select="current-grouping-key()"/></td>
    <td><xsl:value-of select="count(current-group())"/></td>
    <td>$<xsl:value-of select="format-number(sum(current-group()/price), '#,##0.00')"/></td>
    <td>$<xsl:value-of select="format-number(avg(current-group()/price), '#,##0.00')"/></td>
    <td>$<xsl:value-of select="min(current-group()/price)"/>–$<xsl:value-of select="max(current-group()/price)"/></td>
  </tr>
</xsl:for-each-group>
```

**C# parallel:**

```csharp
var summary = products
    .GroupBy(p => p.Category)
    .Select(g => new {
        Category = g.Key,
        Count = g.Count(),
        Total = g.Sum(p => p.Price),
        Average = g.Average(p => p.Price),
        Min = g.Min(p => p.Price),
        Max = g.Max(p => p.Price)
    });
```

---

## group-adjacent

Groups consecutive items that have the same key. Items with the same key that are not adjacent form separate groups.

**C# parallel:** There is no built-in LINQ equivalent. The closest is `MoreLINQ.GroupAdjacent()` or manually implementing "chunk by" logic.

### When to Use group-adjacent

Use `group-adjacent` when the order matters and you want to group runs of consecutive items. Classic use cases:

- Converting flat data into nested structures
- Grouping consecutive paragraphs with the same style
- Collapsing adjacent duplicate values

### Example: Flat to Nested

Given a flat list where items should be grouped by their type:

```xml
<entries>
  <entry type="header">Introduction</entry>
  <entry type="body">First paragraph.</entry>
  <entry type="body">Second paragraph.</entry>
  <entry type="header">Methods</entry>
  <entry type="body">Third paragraph.</entry>
  <entry type="body">Fourth paragraph.</entry>
  <entry type="body">Fifth paragraph.</entry>
</entries>
```

```xml
<xsl:for-each-group select="entries/entry" group-adjacent="@type">
  <xsl:choose>
    <xsl:when test="current-grouping-key() = 'header'">
      <xsl:for-each select="current-group()">
        <h2><xsl:value-of select="."/></h2>
      </xsl:for-each>
    </xsl:when>
    <xsl:when test="current-grouping-key() = 'body'">
      <div class="section">
        <xsl:for-each select="current-group()">
          <p><xsl:value-of select="."/></p>
        </xsl:for-each>
      </div>
    </xsl:when>
  </xsl:choose>
</xsl:for-each-group>
```

Output:

```html
<h2>Introduction</h2>
<div class="section">
  <p>First paragraph.</p>
  <p>Second paragraph.</p>
</div>
<h2>Methods</h2>
<div class="section">
  <p>Third paragraph.</p>
  <p>Fourth paragraph.</p>
  <p>Fifth paragraph.</p>
</div>
```

### group-adjacent vs. group-by

| | `group-by` | `group-adjacent` |
|---|---|---|
| **Scope** | All items in the sequence | Only consecutive items |
| **Same key, non-adjacent** | Same group | Different groups |
| **Use case** | Categorization | Run-length grouping |

```xml
<!-- Given: A, A, B, B, A, A -->

<!-- group-by="." produces 2 groups: (A,A,A,A) and (B,B) -->
<!-- group-adjacent="." produces 3 groups: (A,A), (B,B), (A,A) -->
```

---

## group-starting-with

Starts a new group whenever an item matches a pattern. All items after the matching item (up to the next match) belong to the same group.

**C# parallel:** No direct equivalent. Closest is splitting a list at elements matching a predicate.

### When to Use group-starting-with

The classic use case is splitting flat HTML into sections based on headings:

```xml
<body>
  <h2>Introduction</h2>
  <p>Welcome to the guide.</p>
  <p>This covers XSLT grouping.</p>
  <h2>Getting Started</h2>
  <p>First, install the processor.</p>
  <h2>Advanced Topics</h2>
  <p>Nested grouping is powerful.</p>
  <p>Streaming is efficient.</p>
</body>
```

```xml
<xsl:for-each-group select="body/*" group-starting-with="h2">
  <section>
    <xsl:apply-templates select="current-group()"/>
  </section>
</xsl:for-each-group>
```

Output:

```html
<section>
  <h2>Introduction</h2>
  <p>Welcome to the guide.</p>
  <p>This covers XSLT grouping.</p>
</section>
<section>
  <h2>Getting Started</h2>
  <p>First, install the processor.</p>
</section>
<section>
  <h2>Advanced Topics</h2>
  <p>Nested grouping is powerful.</p>
  <p>Streaming is efficient.</p>
</section>
```

### Pattern vs. Expression

`group-starting-with` uses a **match pattern** (like `xsl:template match`), not a grouping key expression. It tests each item against the pattern — when it matches, a new group begins.

```xml
<!-- Start new group at any heading (h1 through h6) -->
<xsl:for-each-group select="body/*"
                    group-starting-with="h1 | h2 | h3 | h4 | h5 | h6">
  <section class="level-{local-name(current-group()[1])}">
    <xsl:apply-templates select="current-group()"/>
  </section>
</xsl:for-each-group>
```

### Handling Items Before the First Match

If the sequence starts with items that do not match the pattern, they form their own group. This "preamble" group has no starting match:

```xml
<body>
  <p>This comes before any heading.</p>
  <h2>First Section</h2>
  <p>Content.</p>
</body>
```

The first group contains just `<p>This comes before any heading.</p>` — it has no `h2`.

To handle this, check whether the first item in the group matches:

```xml
<xsl:for-each-group select="body/*" group-starting-with="h2">
  <xsl:choose>
    <xsl:when test="self::h2">
      <section>
        <xsl:apply-templates select="current-group()"/>
      </section>
    </xsl:when>
    <xsl:otherwise>
      <!-- Preamble content before the first heading -->
      <div class="preamble">
        <xsl:apply-templates select="current-group()"/>
      </div>
    </xsl:otherwise>
  </xsl:choose>
</xsl:for-each-group>
```

---

## group-ending-with

Ends the current group when an item matches a pattern. The matching item is the last item in its group.

**C# parallel:** No direct equivalent. It is the mirror image of `group-starting-with`.

### When to Use group-ending-with

Use when a marker indicates the end of a group rather than the start. Common use cases:

- Page breaks (the break marker ends a page)
- Sentence boundaries
- Record delimiters in flat files

### Example: Page Breaks

```xml
<document>
  <para>First paragraph.</para>
  <para>Second paragraph.</para>
  <page-break/>
  <para>Third paragraph (page 2).</para>
  <para>Fourth paragraph.</para>
  <para>Fifth paragraph.</para>
  <page-break/>
  <para>Sixth paragraph (page 3).</para>
</document>
```

```xml
<xsl:for-each-group select="document/*" group-ending-with="page-break">
  <div class="page" id="page-{position()}">
    <xsl:apply-templates select="current-group()[not(self::page-break)]"/>
  </div>
</xsl:for-each-group>
```

Output:

```html
<div class="page" id="page-1">
  <p>First paragraph.</p>
  <p>Second paragraph.</p>
</div>
<div class="page" id="page-2">
  <p>Third paragraph (page 2).</p>
  <p>Fourth paragraph.</p>
  <p>Fifth paragraph.</p>
</div>
<div class="page" id="page-3">
  <p>Sixth paragraph (page 3).</p>
</div>
```

Note that we filter out the `page-break` elements from the output using `[not(self::page-break)]`.

### Trailing Items

If the sequence ends without a match, the remaining items form a final group. In the example above, the paragraph after the last `page-break` forms its own page — no trailing `page-break` is needed.

---

## Sorting Within Groups

You can sort the groups themselves and sort items within each group independently.

### Sorting Groups

Add `xsl:sort` as a child of `xsl:for-each-group` to control the order of groups:

```xml
<!-- Sort categories alphabetically -->
<xsl:for-each-group select="//product" group-by="@category">
  <xsl:sort select="current-grouping-key()"/>
  <section>
    <h2><xsl:value-of select="current-grouping-key()"/></h2>
    <xsl:apply-templates select="current-group()"/>
  </section>
</xsl:for-each-group>
```

### Sorting Items Within Groups

Use a nested `xsl:for-each` with `xsl:sort` inside the group body:

```xml
<xsl:for-each-group select="//product" group-by="@category">
  <xsl:sort select="current-grouping-key()"/>

  <section>
    <h2><xsl:value-of select="current-grouping-key()"/></h2>
    <ul>
      <!-- Sort products within each category by price -->
      <xsl:for-each select="current-group()">
        <xsl:sort select="price" data-type="number"/>
        <li><xsl:value-of select="name"/> — $<xsl:value-of select="price"/></li>
      </xsl:for-each>
    </ul>
  </section>
</xsl:for-each-group>
```

### Sorting Groups by Aggregate

Sort groups by a computed value like count or total:

```xml
<!-- Show categories with the most products first -->
<xsl:for-each-group select="//product" group-by="@category">
  <xsl:sort select="count(current-group())" data-type="number" order="descending"/>

  <h2>
    <xsl:value-of select="current-grouping-key()"/>
    (<xsl:value-of select="count(current-group())"/> products)
  </h2>
  <xsl:apply-templates select="current-group()"/>
</xsl:for-each-group>
```

---

## Nested Grouping

You can nest `xsl:for-each-group` to create multi-level hierarchies.

### Example: Products by Category, Then by Price Range

```xml
<xsl:for-each-group select="//product" group-by="@category">
  <xsl:sort select="current-grouping-key()"/>

  <section class="category">
    <h2><xsl:value-of select="current-grouping-key()"/></h2>

    <!-- Nested grouping: within each category, group by price range -->
    <xsl:for-each-group select="current-group()"
                        group-by="if (price >= 100) then 'premium'
                                  else if (price >= 25) then 'standard'
                                  else 'budget'">
      <xsl:sort select="if (current-grouping-key() = 'premium') then 1
                         else if (current-grouping-key() = 'standard') then 2
                         else 3"
                data-type="number"/>

      <div class="price-tier">
        <h3><xsl:value-of select="current-grouping-key()"/></h3>
        <ul>
          <xsl:for-each select="current-group()">
            <xsl:sort select="price" data-type="number" order="descending"/>
            <li><xsl:value-of select="name"/> — $<xsl:value-of select="price"/></li>
          </xsl:for-each>
        </ul>
      </div>
    </xsl:for-each-group>
  </section>
</xsl:for-each-group>
```

**C# parallel:**

```csharp
var grouped = products
    .GroupBy(p => p.Category)
    .OrderBy(g => g.Key)
    .Select(catGroup => new {
        Category = catGroup.Key,
        Tiers = catGroup
            .GroupBy(p => p.Price >= 100 ? "premium" : p.Price >= 25 ? "standard" : "budget")
            .OrderBy(t => t.Key == "premium" ? 1 : t.Key == "standard" ? 2 : 3)
    });
```

---

## Real-World Examples

### Categorized Product Listing

A complete example that builds a categorized product page with navigation:

```xml
<xsl:template match="catalog">
  <!-- Build navigation -->
  <nav>
    <ul>
      <xsl:for-each-group select="product" group-by="@category">
        <xsl:sort select="current-grouping-key()"/>
        <li>
          <a href="#{translate(current-grouping-key(), ' ', '-')}">
            <xsl:value-of select="current-grouping-key()"/>
            (<xsl:value-of select="count(current-group())"/>)
          </a>
        </li>
      </xsl:for-each-group>
    </ul>
  </nav>

  <!-- Build content sections -->
  <xsl:for-each-group select="product" group-by="@category">
    <xsl:sort select="current-grouping-key()"/>
    <section id="{translate(current-grouping-key(), ' ', '-')}">
      <h2><xsl:value-of select="current-grouping-key()"/></h2>
      <table>
        <thead>
          <tr><th>Product</th><th>Price</th><th>In Stock</th></tr>
        </thead>
        <tbody>
          <xsl:for-each select="current-group()">
            <xsl:sort select="name"/>
            <tr>
              <td><xsl:value-of select="name"/></td>
              <td>$<xsl:value-of select="format-number(price, '#,##0.00')"/></td>
              <td><xsl:value-of select="stock"/></td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </section>
  </xsl:for-each-group>
</xsl:template>
```

### Converting Flat Data to Hierarchical XML

Transform a flat CSV-style structure into nested XML:

```xml
<!-- Input: flat rows with department and employee data -->
<employees>
  <employee department="Engineering" team="Backend"><name>Alice</name></employee>
  <employee department="Engineering" team="Frontend"><name>Bob</name></employee>
  <employee department="Marketing" team="Content"><name>Carol</name></employee>
  <employee department="Engineering" team="Backend"><name>Dave</name></employee>
  <employee department="Marketing" team="Content"><name>Eve</name></employee>
</employees>
```

```xml
<!-- Output: hierarchical structure -->
<xsl:template match="employees">
  <organization>
    <xsl:for-each-group select="employee" group-by="@department">
      <xsl:sort select="current-grouping-key()"/>
      <department name="{current-grouping-key()}">
        <xsl:for-each-group select="current-group()" group-by="@team">
          <xsl:sort select="current-grouping-key()"/>
          <team name="{current-grouping-key()}">
            <xsl:for-each select="current-group()">
              <xsl:sort select="name"/>
              <member><xsl:value-of select="name"/></member>
            </xsl:for-each>
          </team>
        </xsl:for-each-group>
      </department>
    </xsl:for-each-group>
  </organization>
</xsl:template>
```

Output:

```xml
<organization>
  <department name="Engineering">
    <team name="Backend">
      <member>Alice</member>
      <member>Dave</member>
    </team>
    <team name="Frontend">
      <member>Bob</member>
    </team>
  </department>
  <department name="Marketing">
    <team name="Content">
      <member>Carol</member>
      <member>Eve</member>
    </team>
  </department>
</organization>
```

### Splitting a Document into Chapters

Using `group-starting-with` to split a flat document into chapter files:

```xml
<xsl:template match="book">
  <xsl:for-each-group select="*" group-starting-with="chapter-title">
    <xsl:result-document href="chapter-{position()}.html">
      <html>
        <head>
          <title><xsl:value-of select="current-group()[self::chapter-title]"/></title>
        </head>
        <body>
          <xsl:apply-templates select="current-group()"/>

          <!-- Navigation links -->
          <nav>
            <xsl:if test="position() > 1">
              <a href="chapter-{position() - 1}.html">Previous</a>
            </xsl:if>
            <xsl:if test="position() != last()">
              <a href="chapter-{position() + 1}.html">Next</a>
            </xsl:if>
          </nav>
        </body>
      </html>
    </xsl:result-document>
  </xsl:for-each-group>
</xsl:template>
```
