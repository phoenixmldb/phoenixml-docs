---
title: String Analysis
description: "xsl:analyze-string — regex-based string processing in XSLT"
sort: 11
---

# String Analysis

`xsl:analyze-string` applies a regular expression to a string and processes the matched and unmatched portions separately. It is the XSLT equivalent of iterating over regex matches — you get fine-grained control over how each match is transformed into output.

## Contents

- [xsl:analyze-string](#xslanalyze-string)
- [xsl:matching-substring](#xslmatching-substring)
- [xsl:non-matching-substring](#xslnon-matching-substring)
- [Capture Groups](#capture-groups)
- [Regex Flags](#regex-flags)
- [Comparison with replace()](#comparison-with-replace)
- [Common Patterns](#common-patterns)

---

## xsl:analyze-string

The instruction takes a string and a regular expression. It splits the string into alternating matching and non-matching segments, then processes each segment with the corresponding child instruction.

```xml
<xsl:analyze-string select="$input" regex="pattern">
  <xsl:matching-substring>
    <!-- what to do with matched portions -->
  </xsl:matching-substring>
  <xsl:non-matching-substring>
    <!-- what to do with unmatched portions -->
  </xsl:non-matching-substring>
</xsl:analyze-string>
```

### Attributes

| Attribute | Description |
|-----------|-------------|
| `select` | XPath expression that evaluates to the string to analyze |
| `regex` | The regular expression pattern (uses XPath/XML Schema regex syntax) |
| `flags` | Optional regex flags: `i`, `m`, `s`, `x` |

### Basic Example

Detect and linkify email addresses in text:

```xml
<xsl:template match="description">
  <p>
    <xsl:analyze-string select="." regex="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{{2,}}">
      <xsl:matching-substring>
        <a href="mailto:{.}"><xsl:value-of select="."/></a>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </p>
</xsl:template>
```

Given `<description>Contact us at support@example.com or sales@example.com for details.</description>`, output:

```html
<p>Contact us at <a href="mailto:support@example.com">support@example.com</a>
or <a href="mailto:sales@example.com">sales@example.com</a> for details.</p>
```

**Important:** Inside the `regex` attribute, curly braces must be doubled (`{{` and `}}`) because the attribute is an AVT. A single `{` would be interpreted as the start of an XPath expression.

**C# parallel:**

```csharp
var result = Regex.Replace(input, @"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
    match => $"<a href=\"mailto:{match.Value}\">{match.Value}</a>");
```

---

## xsl:matching-substring

Processes each portion of the string that matches the regex. Inside this element:

- **`.` (dot)** refers to the matched substring (as a string, not a node)
- **`regex-group(N)`** returns the Nth capture group

```xml
<xsl:analyze-string select="'Price: $29.99, Discount: $5.00'" regex="\$(\d+\.\d{{2}})">
  <xsl:matching-substring>
    <span class="price"><xsl:value-of select="."/></span>
  </xsl:matching-substring>
  <xsl:non-matching-substring>
    <xsl:value-of select="."/>
  </xsl:non-matching-substring>
</xsl:analyze-string>
```

Output:

```html
Price: <span class="price">$29.99</span>, Discount: <span class="price">$5.00</span>
```

---

## xsl:non-matching-substring

Processes each portion of the string between matches. If omitted, non-matching text is discarded.

```xml
<!-- Extract only the numbers, ignoring everything else -->
<xsl:analyze-string select="'Order #12345, Items: 3, Total: $99.50'" regex="\d+\.?\d*">
  <xsl:matching-substring>
    <number><xsl:value-of select="."/></number>
  </xsl:matching-substring>
  <!-- non-matching-substring omitted: non-numeric text is dropped -->
</xsl:analyze-string>
```

Output:

```xml
<number>12345</number>
<number>3</number>
<number>99.50</number>
```

### Both Are Optional

You can include either, both, or neither (though neither would be pointless). The order does not matter — `xsl:matching-substring` and `xsl:non-matching-substring` can appear in any order as children of `xsl:analyze-string`.

---

## Capture Groups

Parentheses in the regex define capture groups. The `regex-group(N)` function returns the string matched by the Nth group. Group 0 is the entire match (same as `.`).

### Example: Parsing a Date String

```xml
<xsl:analyze-string select="'2026-03-19'" regex="(\d{{4}})-(\d{{2}})-(\d{{2}})">
  <xsl:matching-substring>
    <date>
      <year><xsl:value-of select="regex-group(1)"/></year>
      <month><xsl:value-of select="regex-group(2)"/></month>
      <day><xsl:value-of select="regex-group(3)"/></day>
    </date>
  </xsl:matching-substring>
</xsl:analyze-string>
```

Output:

```xml
<date>
  <year>2026</year>
  <month>03</month>
  <day>19</day>
</date>
```

### Example: Parsing Key-Value Pairs

```xml
<xsl:variable name="input" select="'name=Widget;category=electronics;price=29.99'"/>

<xsl:analyze-string select="$input" regex="([^=;]+)=([^;]+)">
  <xsl:matching-substring>
    <field name="{regex-group(1)}">
      <xsl:value-of select="regex-group(2)"/>
    </field>
  </xsl:matching-substring>
</xsl:analyze-string>
```

Output:

```xml
<field name="name">Widget</field>
<field name="category">electronics</field>
<field name="price">29.99</field>
```

### Nested Groups

Groups are numbered by the position of their opening parenthesis, left to right:

```xml
<!-- regex: ((https?)://([^/]+))(/.*)? -->
<!-- Group 1: full authority (https://example.com) -->
<!-- Group 2: scheme (https) -->
<!-- Group 3: host (example.com) -->
<!-- Group 4: path (/products/123) -->

<xsl:analyze-string select="$url" regex="((https?)://([^/]+))(/.*)?">
  <xsl:matching-substring>
    <url>
      <scheme><xsl:value-of select="regex-group(2)"/></scheme>
      <host><xsl:value-of select="regex-group(3)"/></host>
      <path><xsl:value-of select="regex-group(4)"/></path>
    </url>
  </xsl:matching-substring>
</xsl:analyze-string>
```

**C# parallel:** `regex-group(N)` is equivalent to `match.Groups[N].Value`:

```csharp
var match = Regex.Match(url, @"((https?)://([^/]+))(/.*)?");
var scheme = match.Groups[2].Value;  // "https"
var host = match.Groups[3].Value;    // "example.com"
var path = match.Groups[4].Value;    // "/products/123"
```

---

## Regex Flags

The `flags` attribute accepts a string of flag characters that modify regex behavior. These are the same flags used by the XPath `matches()`, `replace()`, and `tokenize()` functions:

| Flag | Name | Description |
|------|------|-------------|
| `i` | Case-insensitive | `a` matches both `a` and `A` |
| `m` | Multi-line | `^` and `$` match start/end of each line, not just the string |
| `s` | Dot-all | `.` matches newline characters (by default it does not) |
| `x` | Extended | Whitespace in the regex is ignored (for readability); use `\s` for literal whitespace |

### Examples

```xml
<!-- Case-insensitive matching -->
<xsl:analyze-string select="$text" regex="error|warning|info" flags="i">
  <xsl:matching-substring>
    <span class="{lower-case(.)}"><xsl:value-of select="."/></span>
  </xsl:matching-substring>
  <xsl:non-matching-substring>
    <xsl:value-of select="."/>
  </xsl:non-matching-substring>
</xsl:analyze-string>
<!-- Matches "Error", "WARNING", "Info", etc. -->

<!-- Extended mode for readable complex patterns -->
<xsl:analyze-string select="$text" flags="x"
    regex="(\d{{1,3}}) \.(\d{{1,3}}) \.(\d{{1,3}}) \.(\d{{1,3}})">
  <xsl:matching-substring>
    <ip><xsl:value-of select="."/></ip>
  </xsl:matching-substring>
</xsl:analyze-string>
```

### Regex Syntax Notes

XSLT uses XML Schema regular expressions (with XPath extensions), not Perl-compatible regexes. Key differences from C#'s `System.Text.RegularExpressions`:

| Feature | C# (.NET Regex) | XSLT/XPath Regex |
|---------|-----------------|-------------------|
| Anchors | `^`, `$` | `^`, `$` (only with `m` flag; regex always matches full segments) |
| Lazy quantifiers | `*?`, `+?` | `*?`, `+?` (supported) |
| Backreferences | `\1`, `\2` | Not supported in match/replace (only in `regex-group()` for `analyze-string`) |
| Lookahead/lookbehind | `(?=...)`, `(?<=...)` | Not supported |
| Named groups | `(?<name>...)` | Not supported |
| Character class subtraction | Not standard | `[a-z-[aeiou]]` (vowels removed from a-z) |

The lack of lookahead/lookbehind means some complex patterns require different approaches in XSLT — often by using `xsl:analyze-string` with simpler patterns and handling the logic in the matching/non-matching substring bodies.

---

## Comparison with replace()

XPath provides a `replace()` function for simple regex substitutions. When should you use each?

### replace()

Best for simple text-to-text substitutions where the output is a plain string:

```xml
<!-- Simple substitution -->
<xsl:value-of select="replace($text, '\bfoo\b', 'bar')"/>

<!-- Using capture groups in replacement -->
<xsl:value-of select="replace($phone, '(\d{3})(\d{3})(\d{4})', '($1) $2-$3')"/>

<!-- Remove all non-alphanumeric characters -->
<xsl:value-of select="replace($text, '[^a-zA-Z0-9\s]', '')"/>
```

### xsl:analyze-string

Use when:

1. **You need to produce markup** (elements, attributes) from the matches — `replace()` can only produce strings
2. **Different matches need different treatment** — the matching-substring body can use `xsl:choose` or other conditionals
3. **You need multiple capture groups** processed independently
4. **The non-matching portions also need transformation**

```xml
<!-- replace() CANNOT do this — it can only produce strings, not elements -->
<xsl:analyze-string select="$text" regex="https?://\S+">
  <xsl:matching-substring>
    <a href="{.}"><xsl:value-of select="."/></a>
  </xsl:matching-substring>
  <xsl:non-matching-substring>
    <xsl:value-of select="."/>
  </xsl:non-matching-substring>
</xsl:analyze-string>
```

### Decision Guide

| Need | Use |
|------|-----|
| Replace text with text | `replace()` |
| Remove characters | `replace($text, 'pattern', '')` |
| Wrap matches in elements | `xsl:analyze-string` |
| Extract structured data from strings | `xsl:analyze-string` |
| Simple find-and-replace | `replace()` |
| Different handling for matched vs. unmatched | `xsl:analyze-string` |

---

## Common Patterns

### Syntax Highlighting

Highlight keywords in a code snippet:

```xml
<xsl:template match="code[@language='sql']">
  <pre class="code sql">
    <xsl:analyze-string select="."
        regex="(SELECT|FROM|WHERE|JOIN|ON|AND|OR|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|ORDER\s+BY|GROUP\s+BY|HAVING|LIMIT|OFFSET|AS|IN|NOT|NULL|IS|LIKE|BETWEEN|EXISTS|DISTINCT|SET|INTO|VALUES)"
        flags="i">
      <xsl:matching-substring>
        <span class="keyword"><xsl:value-of select="upper-case(.)"/></span>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <!-- Highlight strings within non-keyword text -->
        <xsl:analyze-string select="." regex="'[^']*'">
          <xsl:matching-substring>
            <span class="string"><xsl:value-of select="."/></span>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:value-of select="."/>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </pre>
</xsl:template>
```

This nests two `xsl:analyze-string` calls — first to highlight keywords, then to highlight string literals in the remaining text.

### Link Detection in Text

Convert URLs and email addresses in plain text to clickable links:

```xml
<xsl:function name="my:linkify" as="node()*">
  <xsl:param name="text" as="xs:string"/>

  <xsl:analyze-string select="$text"
      regex="(https?://[^\s&lt;&gt;&quot;]+)|([\w.+-]+@[\w.-]+\.\w{{2,}})">
    <xsl:matching-substring>
      <xsl:choose>
        <xsl:when test="regex-group(1)">
          <a href="{.}" target="_blank"><xsl:value-of select="."/></a>
        </xsl:when>
        <xsl:when test="regex-group(2)">
          <a href="mailto:{.}"><xsl:value-of select="."/></a>
        </xsl:when>
      </xsl:choose>
    </xsl:matching-substring>
    <xsl:non-matching-substring>
      <xsl:value-of select="."/>
    </xsl:non-matching-substring>
  </xsl:analyze-string>
</xsl:function>

<!-- Usage -->
<xsl:template match="comment">
  <p class="comment">
    <xsl:sequence select="my:linkify(string(.))"/>
  </p>
</xsl:template>
```

### Data Extraction from Formatted Strings

Parse a price string like "$1,234.56" into a number:

```xml
<xsl:function name="my:parse-price" as="xs:decimal">
  <xsl:param name="price-string" as="xs:string"/>
  <xsl:variable name="cleaned" select="replace($price-string, '[$,\s]', '')"/>
  <xsl:sequence select="xs:decimal($cleaned)"/>
</xsl:function>

<!-- For more complex parsing, use analyze-string -->
<xsl:function name="my:parse-money" as="map(xs:string, item())">
  <xsl:param name="text" as="xs:string"/>
  <xsl:variable name="result" as="map(xs:string, item())*">
    <xsl:analyze-string select="$text" regex="([A-Z]{{3}}|\$|€|£)\s*([0-9,]+\.?\d*)">
      <xsl:matching-substring>
        <xsl:sequence select="map {
          'currency': regex-group(1),
          'amount': xs:decimal(replace(regex-group(2), ',', ''))
        }"/>
      </xsl:matching-substring>
    </xsl:analyze-string>
  </xsl:variable>
  <xsl:sequence select="$result[1]"/>
</xsl:function>
```

### Markdown-Like Formatting

Convert simple markup conventions in plain text:

```xml
<xsl:function name="my:simple-format" as="node()*">
  <xsl:param name="text" as="xs:string"/>

  <!-- Bold: **text** -->
  <xsl:analyze-string select="$text" regex="\*\*([^*]+)\*\*">
    <xsl:matching-substring>
      <strong><xsl:value-of select="regex-group(1)"/></strong>
    </xsl:matching-substring>
    <xsl:non-matching-substring>
      <!-- Italic: *text* -->
      <xsl:analyze-string select="." regex="\*([^*]+)\*">
        <xsl:matching-substring>
          <em><xsl:value-of select="regex-group(1)"/></em>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <!-- Code: `text` -->
          <xsl:analyze-string select="." regex="`([^`]+)`">
            <xsl:matching-substring>
              <code><xsl:value-of select="regex-group(1)"/></code>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
              <xsl:value-of select="."/>
            </xsl:non-matching-substring>
          </xsl:analyze-string>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:non-matching-substring>
  </xsl:analyze-string>
</xsl:function>
```

### CSV Line Parser

Parse a single CSV line into fields, handling quoted fields:

```xml
<xsl:function name="my:parse-csv-line" as="xs:string*">
  <xsl:param name="line" as="xs:string"/>
  <xsl:analyze-string select="$line" regex='("([^"]*(?:""[^"]*)*)"|([^,]*))(?:,|$)'>
    <xsl:matching-substring>
      <xsl:choose>
        <xsl:when test="regex-group(2)">
          <!-- Quoted field: unescape doubled quotes -->
          <xsl:sequence select="replace(regex-group(2), '&quot;&quot;', '&quot;')"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- Unquoted field -->
          <xsl:sequence select="regex-group(3)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:matching-substring>
  </xsl:analyze-string>
</xsl:function>
```

**C# parallel summary:**

| XSLT | C# |
|------|-----|
| `xsl:analyze-string` | `Regex.Matches()` + loop, or `MatchEvaluator` |
| `xsl:matching-substring` | Code inside the match loop |
| `xsl:non-matching-substring` | Text between matches |
| `regex-group(N)` | `match.Groups[N].Value` |
| `replace($s, $pat, $rep)` | `Regex.Replace(s, pat, rep)` |
| `flags="i"` | `RegexOptions.IgnoreCase` |
| `flags="s"` | `RegexOptions.Singleline` |
| `flags="m"` | `RegexOptions.Multiline` |
| `flags="x"` | `RegexOptions.IgnorePatternWhitespace` |
