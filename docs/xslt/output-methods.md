---
title: Output Methods
description: Producing HTML, XML, JSON, CSV, and text from XSLT transforms
sort: 4
---

# Output Methods

One of XSLT's greatest strengths is producing multiple output formats from the same source data. The `xsl:output` declaration controls how the transformation result is serialized.

## Contents

- [HTML Output](#html-output)
- [XML Output](#xml-output)
- [Text Output](#text-output)
- [JSON Output](#json-output)
- [Adaptive Output](#adaptive-output)
- [Multiple Outputs in One Stylesheet](#multiple-outputs-in-one-stylesheet)
- [Serialization Parameters](#serialization-parameters)

---

## HTML Output

The most common output for web-facing transforms:

```xml
<xsl:output method="html" html-version="5" indent="yes" encoding="UTF-8"/>
```

**What HTML mode does:**
- Outputs `<!DOCTYPE html>` for HTML5
- Self-closes void elements correctly (`<br>`, `<img>`, `<meta>`, not `<br/>`)
- Does not escape `<script>` and `<style>` content
- Includes `<meta charset="UTF-8">` when requested
- Writes boolean attributes correctly (`<input disabled>` not `<input disabled="disabled">`)

```xml
<xsl:template match="/">
  <html>
    <head>
      <meta charset="UTF-8"/>
      <title><xsl:value-of select="//title"/></title>
    </head>
    <body>
      <xsl:apply-templates/>
    </body>
  </html>
</xsl:template>
```

**Output:**
```html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>My Page</title>
</head>
<body>...</body>
</html>
```

### XHTML Output

For XML-compatible HTML:

```xml
<xsl:output method="xhtml" indent="yes" encoding="UTF-8"/>
```

Produces well-formed XML that is also valid HTML — `<br/>`, `<meta ... />`, etc.

---

## XML Output

The default output method. Produces well-formed XML.

```xml
<xsl:output method="xml" indent="yes" encoding="UTF-8" omit-xml-declaration="no"/>
```

**Use cases:**
- Transforming one XML format to another (e.g., data conversion between standards)
- Generating SVG, MathML, RSS/Atom feeds
- Producing intermediate XML for further processing

**Example — converting a product catalog to an Atom feed:**

```xml
<xsl:output method="xml" indent="yes"/>

<xsl:template match="catalog">
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>Product Updates</title>
    <link href="https://example.com/products"/>
    <updated><xsl:value-of select="current-dateTime()"/></updated>
    <xsl:apply-templates select="product"/>
  </feed>
</xsl:template>

<xsl:template match="product">
  <entry xmlns="http://www.w3.org/2005/Atom">
    <title><xsl:value-of select="name"/></title>
    <id>urn:product:<xsl:value-of select="@id"/></id>
    <summary><xsl:value-of select="description"/></summary>
  </entry>
</xsl:template>
```

---

## Text Output

Produces plain text with no markup:

```xml
<xsl:output method="text" encoding="UTF-8"/>
```

**What text mode does:**
- No XML/HTML escaping — `<` is output as `<`, not `&lt;`
- No XML declaration
- Only text nodes are output (element tags are suppressed)
- Whitespace from the stylesheet is preserved (be careful!)

### Example: Generating a CSV File

```xml
<xsl:output method="text" encoding="UTF-8"/>

<xsl:template match="/">
  <xsl:text>ID,Name,Price,Category&#10;</xsl:text>
  <xsl:for-each select="//product">
    <xsl:value-of select="@id"/>
    <xsl:text>,</xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>,</xsl:text>
    <xsl:value-of select="price"/>
    <xsl:text>,</xsl:text>
    <xsl:value-of select="@category"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:for-each>
</xsl:template>
```

**Output:**
```csv
ID,Name,Price,Category
P001,Wireless Mouse,29.99,electronics
P002,Mechanical Keyboard,89.99,electronics
P003,USB-C Hub,45.00,accessories
```

### Example: Generating a Markdown File

```xml
<xsl:output method="text"/>

<xsl:template match="catalog">
  <xsl:text># Product Catalog&#10;&#10;</xsl:text>
  <xsl:apply-templates select="product"/>
</xsl:template>

<xsl:template match="product">
  <xsl:text>## </xsl:text>
  <xsl:value-of select="name"/>
  <xsl:text>&#10;&#10;</xsl:text>
  <xsl:text>**Price:** $</xsl:text>
  <xsl:value-of select="price"/>
  <xsl:text>&#10;&#10;</xsl:text>
  <xsl:value-of select="description"/>
  <xsl:text>&#10;&#10;</xsl:text>
</xsl:template>
```

### Example: Generating SQL

```xml
<xsl:output method="text"/>

<xsl:template match="/">
  <xsl:for-each select="//product">
    <xsl:text>INSERT INTO products (id, name, price, category) VALUES (</xsl:text>
    <xsl:value-of select="concat('''', @id, ''', ')"/>
    <xsl:value-of select="concat('''', name, ''', ')"/>
    <xsl:value-of select="concat(price, ', ')"/>
    <xsl:value-of select="concat('''', @category, '''')"/>
    <xsl:text>);&#10;</xsl:text>
  </xsl:for-each>
</xsl:template>
```

---

## JSON Output

XSLT 3.0 can produce JSON directly. The approach uses XPath maps and arrays:

```xml
<xsl:output method="json" indent="yes"/>

<xsl:template match="catalog">
  <xsl:sequence select="
    map {
      'products': array {
        for $p in product
        return map {
          'id': string($p/@id),
          'name': string($p/name),
          'price': number($p/price),
          'category': string($p/@category)
        }
      }
    }
  "/>
</xsl:template>
```

**Output:**
```json
{
  "products": [
    {
      "id": "P001",
      "name": "Wireless Mouse",
      "price": 29.99,
      "category": "electronics"
    },
    ...
  ]
}
```

**C# comparison:** This is like building a `Dictionary<string, object>` and calling `JsonSerializer.Serialize()` — but the data selection and structure are expressed in XPath.

**Key insight for JSON developers:** You're already comfortable with JSON. XSLT 3.0 lets you use XPath to query XML and output JSON — bridging the two formats. This is one of the most compelling use cases for .NET developers doing data integration.

---

## Adaptive Output

XSLT 3.0's adaptive output method automatically chooses the serialization based on the result type:

```xml
<xsl:output method="adaptive"/>
```

- If the result is a document node → serialized as XML
- If the result is a map or array → serialized as JSON
- If the result is an atomic value → serialized as text

Useful for functions and transforms that may return different types.

---

## Multiple Outputs in One Stylesheet

Using `xsl:result-document`, a single stylesheet can produce multiple files with different formats:

```xml
<xsl:template match="catalog">
  <!-- Main HTML page -->
  <html>
    <body><xsl:apply-templates select="product"/></body>
  </html>

  <!-- JSON API response -->
  <xsl:result-document href="api/products.json" method="json" indent="yes">
    <xsl:sequence select="array { for $p in product return map { ... } }"/>
  </xsl:result-document>

  <!-- CSV export -->
  <xsl:result-document href="export/products.csv" method="text">
    <xsl:text>id,name,price&#10;</xsl:text>
    <xsl:for-each select="product">
      <xsl:value-of select="string-join((@id, name, price), ',')"/>
      <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
  </xsl:result-document>

  <!-- Sitemap -->
  <xsl:result-document href="sitemap.xml" method="xml" indent="yes">
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <xsl:for-each select="product">
        <url><loc>https://example.com/products/<xsl:value-of select="@id"/></loc></url>
      </xsl:for-each>
    </urlset>
  </xsl:result-document>
</xsl:template>
```

**One XSLT, four output files in three formats.** This is the kind of thing that takes significant code in C# but is natural in XSLT.

---

## Serialization Parameters

The full set of `xsl:output` attributes:

| Attribute | Values | Default | Description |
|-----------|--------|---------|-------------|
| `method` | `html`, `xml`, `xhtml`, `text`, `json`, `adaptive` | `xml` | Output format |
| `html-version` | `5` | | HTML version (use `5` for HTML5) |
| `indent` | `yes`, `no` | `no` | Pretty-print the output |
| `encoding` | `UTF-8`, `ISO-8859-1`, etc. | `UTF-8` | Character encoding |
| `omit-xml-declaration` | `yes`, `no` | `no` (xml), `yes` (html) | Include `<?xml?>` |
| `standalone` | `yes`, `no`, `omit` | `omit` | XML standalone declaration |
| `doctype-system` | URI | | System DOCTYPE identifier |
| `doctype-public` | String | | Public DOCTYPE identifier |
| `cdata-section-elements` | Space-separated names | | Elements to output as CDATA |
| `media-type` | MIME type | | Output MIME type hint |
| `include-content-type` | `yes`, `no` | `yes` (html) | Include `<meta>` content type |
| `item-separator` | String | | Separator between sequence items (text mode) |

### Named Output Definitions

You can define multiple named outputs and reference them from `xsl:result-document`:

```xml
<xsl:output name="html-output" method="html" html-version="5" indent="yes"/>
<xsl:output name="json-output" method="json" indent="yes"/>

<xsl:result-document href="page.html" format="html-output">
  ...
</xsl:result-document>

<xsl:result-document href="data.json" format="json-output">
  ...
</xsl:result-document>
```
