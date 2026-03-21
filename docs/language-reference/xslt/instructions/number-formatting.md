---
title: "Number Formatting"
description: "xsl:number, xsl:decimal-format, xsl:character-map — numbering and format customization"
sort: 18
---

# Number Formatting

XSLT provides three instructions for controlling how numbers and characters appear in the output: `xsl:number` for generating formatted counters and numbering schemes, `xsl:decimal-format` for customizing how `format-number()` renders decimal values, and `xsl:character-map` for post-serialization character substitutions.

## Contents

- [xsl:number](#xslnumber)
- [xsl:decimal-format](#xsldecimal-format)
- [xsl:character-map and xsl:output-character](#xslcharacter-map-and-xsloutput-character)

---

## xsl:number

`xsl:number` generates a formatted number, most commonly used for numbering items in the output — chapter numbers, list item numbers, footnote markers, and outline numbering.

**C# parallel:** There is no single C# equivalent. `xsl:number` combines counting logic (like LINQ's `IndexOf` or list position) with format strings (like `ToString("D3")` for zero-padding or custom Roman numeral formatters).

### Basic Usage

```xml
<!-- Number each product in document order -->
<xsl:template match="product">
  <div>
    <xsl:number/>. <xsl:value-of select="name"/>
  </div>
</xsl:template>
```

Output:

```
1. Laptop
2. Phone
3. Tablet
```

### How xsl:number Counts

`xsl:number` does not simply use `position()`. It counts nodes in the source document based on the `level`, `count`, and `from` attributes. This distinction matters: `position()` reflects processing order (which can be affected by sorting), while `xsl:number` reflects document structure.

### The level Attribute

The `level` attribute controls the counting scope:

#### level="single" (Default)

Counts siblings of the same type. This is the most common mode.

```xml
<!-- Number each item within its parent -->
<xsl:template match="item">
  <xsl:number level="single" count="item"/>
  <xsl:text>. </xsl:text>
  <xsl:value-of select="."/>
</xsl:template>
```

Given:

```xml
<list>
  <item>First</item>
  <item>Second</item>
  <item>Third</item>
</list>
```

Output: `1. First`, `2. Second`, `3. Third`

#### level="multiple"

Counts at multiple levels of the hierarchy, producing composite numbers like `1.1`, `1.2`, `2.1`. This is the key to outline numbering.

```xml
<xsl:template match="section/title">
  <xsl:number level="multiple" count="section" format="1.1"/>
  <xsl:text> </xsl:text>
  <xsl:value-of select="."/>
</xsl:template>
```

Given:

```xml
<document>
  <section>
    <title>Introduction</title>
    <section>
      <title>Background</title>
    </section>
    <section>
      <title>Scope</title>
    </section>
  </section>
  <section>
    <title>Methods</title>
    <section>
      <title>Data Collection</title>
    </section>
  </section>
</document>
```

Output:

```
1 Introduction
1.1 Background
1.2 Scope
2 Methods
2.1 Data Collection
```

#### level="any"

Counts all matching nodes in the document, regardless of hierarchy. Useful for footnotes or sequential numbering across sections.

```xml
<xsl:template match="footnote">
  <sup>
    <xsl:number level="any" count="footnote" format="1"/>
  </sup>
</xsl:template>
```

No matter how deeply nested footnotes are in sections, they get sequential numbers: 1, 2, 3, 4, ...

### The count and from Attributes

| Attribute | Description | Default |
|-----------|-------------|---------|
| `count` | Pattern matching nodes to count | Current node's type |
| `from` | Pattern marking where counting restarts | Document root |

```xml
<!-- Count items, restarting at each section -->
<xsl:template match="item">
  <xsl:number level="any" count="item" from="section"/>
  <xsl:text>. </xsl:text>
  <xsl:value-of select="."/>
</xsl:template>
```

In this example, each `section` resets the count. Items in the first section are numbered 1, 2, 3; items in the second section start over at 1.

### The format Attribute

The `format` attribute controls the output style. The first character (or characters) of the format string determines the numbering system:

| Format | Output | Description |
|--------|--------|-------------|
| `"1"` | 1, 2, 3, ... | Arabic numerals (default) |
| `"01"` | 01, 02, ..., 10, 11, ... | Zero-padded arabic |
| `"001"` | 001, 002, ..., 010, ... | Three-digit zero-padded |
| `"a"` | a, b, c, ..., z, aa, ab, ... | Lowercase alphabetic |
| `"A"` | A, B, C, ..., Z, AA, AB, ... | Uppercase alphabetic |
| `"i"` | i, ii, iii, iv, v, ... | Lowercase Roman numerals |
| `"I"` | I, II, III, IV, V, ... | Uppercase Roman numerals |
| `"w"` | one, two, three, ... | Words (lowercase) |
| `"W"` | ONE, TWO, THREE, ... | Words (uppercase) |
| `"Ww"` | One, Two, Three, ... | Words (title case) |

#### Multi-Level Format Strings

For `level="multiple"`, the format string includes separators:

```xml
<!-- Chapter.Section numbering -->
<xsl:number level="multiple" count="chapter|section" format="1.1"/>
<!-- Output: 1.1, 1.2, 2.1, etc. -->

<!-- Chapter.Section.Subsection with different styles -->
<xsl:number level="multiple" count="chapter|section|subsection" format="I.A.1"/>
<!-- Output: I.A.1, I.A.2, I.B.1, II.A.1, etc. -->

<!-- Legal document style -->
<xsl:number level="multiple" count="part|section|clause" format="1.1.a"/>
<!-- Output: 1.1.a, 1.1.b, 1.2.a, 2.1.a, etc. -->

<!-- Outline style with parentheses -->
<xsl:number level="multiple" count="section" format="I.A.1.a)"/>
<!-- Output: I.A.1.a), etc. -->
```

### The ordinal Attribute

The `ordinal` attribute produces ordinal suffixes (1st, 2nd, 3rd). Support varies by processor and language:

```xml
<xsl:number value="position()" format="1" ordinal="yes"/>
<!-- Output: 1st, 2nd, 3rd, 4th, ... -->
```

### The grouping-separator and grouping-size Attributes

For large numbers, add thousands separators:

```xml
<xsl:number value="$total-count" grouping-separator="," grouping-size="3"/>
<!-- Output: 1,234,567 -->
```

### Using value Instead of Counting

Instead of counting nodes, you can format a specific number:

```xml
<!-- Format a calculated value -->
<xsl:number value="count(//error)" format="1"/>

<!-- Format a number as Roman numerals -->
<xsl:number value="$chapter-number" format="I"/>

<!-- Format as words -->
<xsl:number value="$position" format="Ww"/>
<!-- Output: "One", "Two", "Three", ... -->
```

### Complete Example: Document with Multi-Level Numbering

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:output method="html" indent="yes"/>

  <xsl:template match="document">
    <html>
      <body>
        <!-- Table of Contents -->
        <nav>
          <h2>Table of Contents</h2>
          <xsl:apply-templates select=".//section" mode="toc"/>
        </nav>

        <!-- Content -->
        <xsl:apply-templates/>
      </body>
    </html>
  </xsl:template>

  <!-- TOC entry with multi-level numbering -->
  <xsl:template match="section" mode="toc">
    <p style="margin-left: {count(ancestor::section) * 20}px">
      <a href="#section-{generate-id()}">
        <xsl:number level="multiple" count="section" format="1.1"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="title"/>
      </a>
    </p>
  </xsl:template>

  <!-- Section content with numbered heading -->
  <xsl:template match="section">
    <xsl:variable name="depth" select="count(ancestor::section) + 1"/>
    <div class="section" id="section-{generate-id()}">
      <xsl:element name="h{min(($depth + 1, 6))}">
        <xsl:number level="multiple" count="section" format="1.1"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="title"/>
      </xsl:element>
      <xsl:apply-templates select="* except title"/>
    </div>
  </xsl:template>

  <xsl:template match="para">
    <p><xsl:apply-templates/></p>
  </xsl:template>

  <!-- Footnotes numbered across the entire document -->
  <xsl:template match="footnote">
    <xsl:variable name="num">
      <xsl:number level="any" count="footnote"/>
    </xsl:variable>
    <sup><a href="#fn-{$num}">[<xsl:value-of select="$num"/>]</a></sup>
  </xsl:template>

</xsl:stylesheet>
```

### Use Cases for xsl:number

| Use Case | Configuration |
|----------|--------------|
| Simple list numbering | `<xsl:number/>` (defaults) |
| Chapter numbering | `level="single" count="chapter" format="1"` |
| Section outline (1.1, 1.2) | `level="multiple" count="chapter\|section" format="1.1"` |
| Footnote numbering | `level="any" count="footnote"` |
| Appendix letters | `level="single" count="appendix" format="A"` |
| Roman numeral preface pages | `level="single" count="preface-page" format="i"` |
| Zero-padded item codes | `value="@id" format="001"` |
| Numbered within each chapter | `level="any" count="figure" from="chapter"` |

---

## xsl:decimal-format

`xsl:decimal-format` declares a named (or default) decimal format that controls how the `format-number()` function renders numeric values. This is a top-level declaration.

**C# parallel:** `CultureInfo.NumberFormat` or custom `NumberFormatInfo`:

```csharp
var nfi = new NumberFormatInfo
{
    NumberDecimalSeparator = ",",
    NumberGroupSeparator = ".",
    CurrencySymbol = "EUR"
};
var formatted = amount.ToString("#,##0.00", nfi);
```

### Default Format

Without any `xsl:decimal-format` declaration, `format-number()` uses US/English conventions:

```xml
<xsl:value-of select="format-number(1234567.89, '#,##0.00')"/>
<!-- Output: 1,234,567.89 -->
```

### Declaring a Named Format

```xml
<xsl:decimal-format name="european"
                    decimal-separator=","
                    grouping-separator="."/>

<xsl:decimal-format name="swiss"
                    decimal-separator="."
                    grouping-separator="'"/>
```

Using named formats:

```xml
<!-- US format (default) -->
<xsl:value-of select="format-number(1234567.89, '#,##0.00')"/>
<!-- Output: 1,234,567.89 -->

<!-- European format -->
<xsl:value-of select="format-number(1234567.89, '#.##0,00', 'european')"/>
<!-- Output: 1.234.567,89 -->

<!-- Swiss format -->
<xsl:value-of select="format-number(1234567.89, '#''##0.00', 'swiss')"/>
<!-- Output: 1'234'567.89 -->
```

### All Properties

| Property | Default | Description |
|----------|---------|-------------|
| `decimal-separator` | `.` | Character separating integer from fractional part |
| `grouping-separator` | `,` | Character separating digit groups (thousands) |
| `infinity` | `Infinity` | String representation of positive infinity |
| `minus-sign` | `-` | Character for negative numbers |
| `NaN` | `NaN` | String representation of Not-a-Number |
| `percent` | `%` | Percent sign character |
| `per-mille` | `\u2030` | Per-mille sign character |
| `zero-digit` | `0` | Character representing a mandatory digit |
| `digit` | `#` | Character representing an optional digit |
| `pattern-separator` | `;` | Separates positive and negative sub-patterns |
| `exponent-separator` | `e` | Character separating mantissa from exponent |

### Format Pattern Syntax

The `format-number()` pattern uses these symbols:

| Symbol | Meaning | Example |
|--------|---------|---------|
| `0` | Mandatory digit (shows zero if absent) | `format-number(5, '000')` = `005` |
| `#` | Optional digit (suppressed if zero) | `format-number(5, '###')` = `5` |
| `.` | Decimal point | `format-number(3.14, '#.00')` = `3.14` |
| `,` | Grouping separator | `format-number(1000, '#,##0')` = `1,000` |
| `%` | Multiply by 100 and show percent | `format-number(0.15, '#0%')` = `15%` |
| `E` | Scientific notation | `format-number(1500, '0.##E0')` = `1.5E3` |

### Positive and Negative Patterns

Use the pattern separator (`;`) to define separate formats for positive and negative numbers:

```xml
<xsl:value-of select="format-number(-42, '#,##0;(#,##0)')"/>
<!-- Output: (42) -->

<xsl:value-of select="format-number(42, '#,##0;(#,##0)')"/>
<!-- Output: 42 -->

<xsl:value-of select="format-number(-1500, '+#,##0;-#,##0')"/>
<!-- Output: -1,500 -->

<xsl:value-of select="format-number(1500, '+#,##0;-#,##0')"/>
<!-- Output: +1,500 -->
```

### Real-World Example: Multi-Locale Financial Report

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:decimal-format name="us"
                      decimal-separator="."
                      grouping-separator=","/>

  <xsl:decimal-format name="de"
                      decimal-separator=","
                      grouping-separator="."/>

  <xsl:decimal-format name="fr"
                      decimal-separator=","
                      grouping-separator=" "/>

  <xsl:param name="locale" select="'us'"/>

  <xsl:template match="financial-report">
    <table>
      <tr>
        <th>Item</th>
        <th>Amount</th>
      </tr>
      <xsl:for-each select="line-item">
        <tr>
          <td><xsl:value-of select="@name"/></td>
          <td>
            <xsl:choose>
              <xsl:when test="$locale = 'us'">
                $<xsl:value-of select="format-number(@amount, '#,##0.00', 'us')"/>
              </xsl:when>
              <xsl:when test="$locale = 'de'">
                <xsl:value-of select="format-number(@amount, '#.##0,00', 'de')"/> EUR
              </xsl:when>
              <xsl:when test="$locale = 'fr'">
                <xsl:value-of select="format-number(@amount, '# ##0,00', 'fr')"/> EUR
              </xsl:when>
            </xsl:choose>
          </td>
        </tr>
      </xsl:for-each>
    </table>
  </xsl:template>

</xsl:stylesheet>
```

Output for `$locale = 'de'` with amount 1234567.89:

```
1.234.567,89 EUR
```

---

## xsl:character-map and xsl:output-character

`xsl:character-map` defines a mapping from single characters to replacement strings that is applied during serialization. Unlike most XSLT processing (which operates on the data model), character maps operate on the serialized output bytes.

**C# parallel:** `string.Replace()` applied to the final output, or custom `TextWriter` that substitutes characters:

```csharp
// Character substitution during output
output = output
    .Replace("\u00A0", "&nbsp;")
    .Replace("\u2018", "&lsquo;")
    .Replace("\u2019", "&rsquo;");
```

### Why Character Maps?

The XML serializer normally escapes certain characters:

- `<` becomes `&lt;`
- `>` becomes `&gt;`
- `&` becomes `&amp;`

Sometimes you need to output characters that would otherwise be escaped, or you need to replace characters with multi-character strings. Character maps let you do this without resorting to `disable-output-escaping`.

### Declaring a Character Map

```xml
<xsl:character-map name="html-entities">
  <xsl:output-character character="&#x00A0;" string="&amp;nbsp;"/>
  <xsl:output-character character="&#x00A9;" string="&amp;copy;"/>
  <xsl:output-character character="&#x00AE;" string="&amp;reg;"/>
  <xsl:output-character character="&#x2122;" string="&amp;trade;"/>
</xsl:character-map>
```

### Activating a Character Map

Reference the character map from `xsl:output`:

```xml
<xsl:output method="html" use-character-maps="html-entities"/>
```

Now, whenever the serializer encounters the non-breaking space character (U+00A0) in the output, it writes the literal string `&nbsp;` instead.

### Use Case: Smart Quote Replacement

Replace Unicode smart quotes with HTML entities for compatibility:

```xml
<xsl:character-map name="smart-quotes">
  <xsl:output-character character="&#x2018;" string="&amp;lsquo;"/>  <!-- left single -->
  <xsl:output-character character="&#x2019;" string="&amp;rsquo;"/>  <!-- right single -->
  <xsl:output-character character="&#x201C;" string="&amp;ldquo;"/>  <!-- left double -->
  <xsl:output-character character="&#x201D;" string="&amp;rdquo;"/>  <!-- right double -->
  <xsl:output-character character="&#x2014;" string="&amp;mdash;"/>  <!-- em dash -->
  <xsl:output-character character="&#x2013;" string="&amp;ndash;"/>  <!-- en dash -->
</xsl:character-map>

<xsl:output method="html" use-character-maps="smart-quotes"/>
```

### Use Case: Outputting Raw Markup Characters

Sometimes you need to output characters that the XML serializer would escape. Use a placeholder character mapped to the raw string:

```xml
<xsl:character-map name="raw-markup">
  <!-- Map a private-use character to a literal < -->
  <xsl:output-character character="&#xE001;" string="&lt;"/>
  <xsl:output-character character="&#xE002;" string="&gt;"/>
</xsl:character-map>

<xsl:output method="xml" use-character-maps="raw-markup"/>
```

Then in your templates, use the placeholder characters:

```xml
<xsl:template match="code-sample">
  <!-- These private-use characters will become < and > in the output -->
  <xsl:value-of select="translate(., '&lt;&gt;', '&#xE001;&#xE002;')"/>
</xsl:template>
```

This approach is cleaner than `disable-output-escaping` because it works with any output method and does not break the XSLT data model.

### Composing Character Maps

A character map can reference other character maps with `use-character-maps`:

```xml
<xsl:character-map name="html-entities">
  <xsl:output-character character="&#x00A0;" string="&amp;nbsp;"/>
  <xsl:output-character character="&#x00A9;" string="&amp;copy;"/>
</xsl:character-map>

<xsl:character-map name="smart-quotes">
  <xsl:output-character character="&#x2018;" string="&amp;lsquo;"/>
  <xsl:output-character character="&#x2019;" string="&amp;rsquo;"/>
</xsl:character-map>

<!-- Combined map includes both -->
<xsl:character-map name="all-substitutions"
                   use-character-maps="html-entities smart-quotes">
  <!-- Additional mappings specific to this map -->
  <xsl:output-character character="&#x2122;" string="&amp;trade;"/>
</xsl:character-map>

<xsl:output method="html" use-character-maps="all-substitutions"/>
```

### Complete Example: HTML Output with Entity Preservation

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:character-map name="html-compat">
    <!-- Non-breaking space -->
    <xsl:output-character character="&#x00A0;" string="&amp;nbsp;"/>
    <!-- Typography -->
    <xsl:output-character character="&#x2018;" string="&amp;lsquo;"/>
    <xsl:output-character character="&#x2019;" string="&amp;rsquo;"/>
    <xsl:output-character character="&#x201C;" string="&amp;ldquo;"/>
    <xsl:output-character character="&#x201D;" string="&amp;rdquo;"/>
    <xsl:output-character character="&#x2014;" string="&amp;mdash;"/>
    <!-- Symbols -->
    <xsl:output-character character="&#x00A9;" string="&amp;copy;"/>
    <xsl:output-character character="&#x00AE;" string="&amp;reg;"/>
  </xsl:character-map>

  <xsl:output method="html" indent="yes" use-character-maps="html-compat"/>

  <xsl:template match="article">
    <html>
      <head><title><xsl:value-of select="title"/></title></head>
      <body>
        <h1><xsl:value-of select="title"/></h1>
        <!-- Content with smart quotes and special characters
             will be serialized using HTML entities -->
        <xsl:apply-templates select="body/*"/>
        <footer>
          <p>&#x00A9; 2025 &#x2014; All rights reserved.</p>
          <!-- Outputs: &copy; 2025 &mdash; All rights reserved. -->
        </footer>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="p">
    <p><xsl:apply-templates/></p>
  </xsl:template>

</xsl:stylesheet>
```
