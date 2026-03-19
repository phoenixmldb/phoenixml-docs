---
title: Multiple Output Documents
description: "xsl:result-document and xsl:output — generating multiple files and controlling serialization"
sort: 8
---

# Multiple Output Documents

A single XSLT transformation can produce multiple output files. This is one of XSLT's most powerful capabilities — from a single source document and stylesheet, you can generate an index page, individual detail pages, a sitemap, and a JSON API response in one pass.

## Contents

- [xsl:output](#xsloutput)
- [xsl:result-document](#xslresult-document)
- [Named Output Definitions](#named-output-definitions)
- [Common Patterns](#common-patterns)
- [Secondary Output in the PhoenixmlDb API](#secondary-output-in-the-phoenixmldb-api)

---

## xsl:output

Controls how the result tree is serialized into bytes. This is a top-level declaration (child of `xsl:stylesheet`) that configures the serializer.

### Basic Usage

```xml
<xsl:output method="html" indent="yes" encoding="utf-8"
            html-version="5" include-content-type="no"/>
```

### Serialization Parameters

| Attribute | Values | Description |
|-----------|--------|-------------|
| `method` | `xml`, `html`, `xhtml`, `text`, `json`, `adaptive` | Output format |
| `indent` | `yes`, `no` | Pretty-print the output |
| `encoding` | `utf-8`, `utf-16`, `iso-8859-1`, etc. | Character encoding |
| `omit-xml-declaration` | `yes`, `no` | Suppress `<?xml?>` declaration |
| `standalone` | `yes`, `no`, `omit` | Standalone declaration |
| `doctype-system` | URI | DOCTYPE system identifier |
| `doctype-public` | public ID | DOCTYPE public identifier |
| `cdata-section-elements` | QNames | Elements whose text content is wrapped in CDATA |
| `media-type` | MIME type | Content-Type (e.g., `text/html`, `application/json`) |
| `html-version` | `5`, `4.01`, etc. | HTML version (XSLT 3.0) |
| `include-content-type` | `yes`, `no` | Include `<meta charset>` in HTML |
| `suppress-indentation` | QNames | Elements where indentation should be suppressed |
| `item-separator` | string | Separator between items in `adaptive` method |

### Output Methods

**XML** — the default. Produces well-formed XML with proper escaping:

```xml
<xsl:output method="xml" indent="yes" encoding="utf-8"/>
```

**HTML** — produces HTML-compatible output. Self-closing tags are not used for void elements, boolean attributes are minimized, and entity references follow HTML rules:

```xml
<xsl:output method="html" html-version="5" indent="yes"/>
```

Key differences from XML method:
- `<br/>` becomes `<br>` (no self-closing)
- `<script></script>` is preserved (not collapsed to `<script/>`)
- `checked="checked"` may be minimized to `checked`
- No XML declaration

**Text** — produces plain text. All markup is stripped; only text content appears:

```xml
<xsl:output method="text" encoding="utf-8"/>
```

Useful for generating CSV, plain text reports, source code, configuration files, or any non-XML format.

**JSON** — introduced in XSLT 3.0. Serializes XDM maps and arrays as JSON:

```xml
<xsl:output method="json" indent="yes"/>
```

The result tree must be a map or array (built with `xsl:map`/`xsl:array` or the XPath `map{}` / `[]` constructors).

**Adaptive** — chooses the method based on the result. If the result is a map or array, it uses JSON. If it is a document with an `html` root element, it uses HTML. Otherwise, it uses XML:

```xml
<xsl:output method="adaptive" indent="yes"/>
```

**C# parallel:** `xsl:output` is like configuring a `JsonSerializerOptions` or `XmlWriterSettings` object — you are not changing what data is produced, just how it is written to text.

```csharp
var settings = new XmlWriterSettings
{
    Indent = true,
    Encoding = Encoding.UTF8,
    OmitXmlDeclaration = true
};
```

---

## xsl:result-document

Creates a secondary output document. The primary result goes to the main output destination; each `xsl:result-document` writes to a separate destination identified by an `href`.

### Basic Usage

```xml
<xsl:template match="/">
  <!-- Primary output: index page -->
  <html>
    <body>
      <h1>Product Catalog</h1>
      <ul>
        <xsl:for-each select="catalog/product">
          <li><a href="products/{@id}.html"><xsl:value-of select="name"/></a></li>
        </xsl:for-each>
      </ul>
    </body>
  </html>

  <!-- Secondary outputs: one page per product -->
  <xsl:for-each select="catalog/product">
    <xsl:result-document href="products/{@id}.html">
      <html>
        <body>
          <h1><xsl:value-of select="name"/></h1>
          <p>Price: $<xsl:value-of select="format-number(price, '#,##0.00')"/></p>
          <p>Category: <xsl:value-of select="@category"/></p>
          <a href="../index.html">Back to catalog</a>
        </body>
      </html>
    </xsl:result-document>
  </xsl:for-each>
</xsl:template>
```

### The href Attribute

`href` is an AVT that specifies the destination URI. It is resolved relative to the base output URI:

```xml
<!-- Static path -->
<xsl:result-document href="sitemap.xml">...</xsl:result-document>

<!-- Dynamic path from data -->
<xsl:result-document href="output/{@category}/{@id}.html">...</xsl:result-document>

<!-- Computed path -->
<xsl:result-document href="{translate(lower-case(name), ' ', '-')}.html">...</xsl:result-document>
```

If `href` is omitted, the result document replaces the primary output. This is useful when a template needs to override the serialization settings for the main output.

### The format Attribute

References a named `xsl:output` declaration to control serialization for this specific result document:

```xml
<xsl:output name="html-output" method="html" html-version="5" indent="yes"/>
<xsl:output name="json-output" method="json" indent="yes"/>
<xsl:output name="xml-output" method="xml" indent="yes" encoding="utf-8"/>

<xsl:template match="/">
  <!-- Primary output uses the unnamed xsl:output -->
  <html>...</html>

  <!-- JSON output -->
  <xsl:result-document href="api/products.json" format="json-output">
    <xsl:map>
      <xsl:map-entry key="'products'">
        <xsl:array>
          <xsl:for-each select="catalog/product">
            <xsl:map>
              <xsl:map-entry key="'id'" select="string(@id)"/>
              <xsl:map-entry key="'name'" select="string(name)"/>
              <xsl:map-entry key="'price'" select="number(price)"/>
            </xsl:map>
          </xsl:for-each>
        </xsl:array>
      </xsl:map-entry>
    </xsl:map>
  </xsl:result-document>

  <!-- XML sitemap -->
  <xsl:result-document href="sitemap.xml" format="xml-output">
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <xsl:for-each select="catalog/product">
        <url>
          <loc>https://example.com/products/<xsl:value-of select="@id"/>.html</loc>
          <lastmod><xsl:value-of select="format-date(current-date(), '[Y]-[M01]-[D01]')"/></lastmod>
        </url>
      </xsl:for-each>
    </urlset>
  </xsl:result-document>
</xsl:template>
```

### Inline Serialization Overrides

Instead of referencing a named output, you can override individual serialization parameters directly on `xsl:result-document`:

```xml
<xsl:result-document href="data.xml" method="xml" indent="yes" encoding="utf-16">
  <export>...</export>
</xsl:result-document>
```

These override the settings from the referenced (or default) `xsl:output` declaration.

### Validation

`xsl:result-document` supports validation attributes for schema-aware processing:

```xml
<xsl:result-document href="output.xml" validation="strict">
  <!-- content is validated against the schema -->
</xsl:result-document>
```

---

## Named Output Definitions

You can define multiple named output formats and reference them by name. The unnamed `xsl:output` is the default for the primary result.

```xml
<!-- Default output (primary result) -->
<xsl:output method="html" html-version="5" indent="yes"/>

<!-- Named alternatives -->
<xsl:output name="fragment" method="html" html-version="5" indent="yes"
            omit-xml-declaration="yes"/>

<xsl:output name="csv" method="text" encoding="utf-8"/>

<xsl:output name="feed" method="xml" indent="yes" encoding="utf-8"
            media-type="application/atom+xml"/>
```

Multiple unnamed `xsl:output` declarations are merged — their attributes are combined, with later declarations winning on conflicts:

```xml
<!-- These are merged into one effective output declaration -->
<xsl:output method="html"/>
<xsl:output indent="yes"/>
<xsl:output encoding="utf-8"/>
<!-- Effective: method="html" indent="yes" encoding="utf-8" -->
```

This is useful when importing stylesheets — the importing stylesheet can override specific serialization parameters without redeclaring everything.

---

## Common Patterns

### One Page Per Item

The most common multi-output pattern — generate an index page and individual detail pages:

```xml
<xsl:template match="catalog">
  <!-- Index page (primary output) -->
  <html>
    <head><title>Product Catalog</title></head>
    <body>
      <h1>All Products</h1>
      <table>
        <thead>
          <tr><th>Product</th><th>Category</th><th>Price</th></tr>
        </thead>
        <tbody>
          <xsl:for-each select="product">
            <xsl:sort select="name"/>
            <tr>
              <td><a href="products/{@id}.html"><xsl:value-of select="name"/></a></td>
              <td><xsl:value-of select="@category"/></td>
              <td>$<xsl:value-of select="format-number(price, '#,##0.00')"/></td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </body>
  </html>

  <!-- Detail pages (secondary outputs) -->
  <xsl:for-each select="product">
    <xsl:result-document href="products/{@id}.html">
      <html>
        <head><title><xsl:value-of select="name"/></title></head>
        <body>
          <nav><a href="../index.html">Back to catalog</a></nav>
          <h1><xsl:value-of select="name"/></h1>
          <dl>
            <dt>Category</dt><dd><xsl:value-of select="@category"/></dd>
            <dt>Price</dt><dd>$<xsl:value-of select="format-number(price, '#,##0.00')"/></dd>
            <dt>Description</dt><dd><xsl:value-of select="description"/></dd>
          </dl>
        </body>
      </html>
    </xsl:result-document>
  </xsl:for-each>
</xsl:template>
```

### Multi-Format Output

Generate the same data in multiple formats — HTML for humans, JSON for APIs, XML for machine interchange:

```xml
<xsl:output method="html" html-version="5" indent="yes"/>
<xsl:output name="json" method="json" indent="yes"/>
<xsl:output name="xml-export" method="xml" indent="yes"/>

<xsl:template match="catalog">
  <!-- HTML (primary) -->
  <html>
    <body>
      <xsl:apply-templates select="product"/>
    </body>
  </html>

  <!-- JSON API -->
  <xsl:result-document href="api/catalog.json" format="json">
    <xsl:map>
      <xsl:map-entry key="'products'">
        <xsl:array>
          <xsl:for-each select="product">
            <xsl:map>
              <xsl:map-entry key="'id'" select="string(@id)"/>
              <xsl:map-entry key="'name'" select="string(name)"/>
              <xsl:map-entry key="'category'" select="string(@category)"/>
              <xsl:map-entry key="'price'" select="number(price)"/>
            </xsl:map>
          </xsl:for-each>
        </xsl:array>
      </xsl:map-entry>
    </xsl:map>
  </xsl:result-document>

  <!-- XML export -->
  <xsl:result-document href="export/catalog.xml" format="xml-export">
    <catalog exported="{format-dateTime(current-dateTime(), '[Y]-[M01]-[D01]T[H01]:[m01]:[s01]')}">
      <xsl:copy-of select="product"/>
    </catalog>
  </xsl:result-document>
</xsl:template>
```

### Category-Based Directory Structure

```xml
<xsl:template match="catalog">
  <xsl:for-each-group select="product" group-by="@category">
    <!-- Category index page -->
    <xsl:result-document href="{current-grouping-key()}/index.html">
      <html>
        <head><title><xsl:value-of select="current-grouping-key()"/></title></head>
        <body>
          <h1><xsl:value-of select="current-grouping-key()"/></h1>
          <ul>
            <xsl:for-each select="current-group()">
              <li><a href="{@id}.html"><xsl:value-of select="name"/></a></li>
            </xsl:for-each>
          </ul>
        </body>
      </html>
    </xsl:result-document>

    <!-- Individual product pages within category folder -->
    <xsl:for-each select="current-group()">
      <xsl:result-document href="{@category}/{@id}.html">
        <html>
          <head><title><xsl:value-of select="name"/></title></head>
          <body>
            <xsl:apply-templates select="."/>
          </body>
        </html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:for-each-group>
</xsl:template>
```

### Generating CSV with Text Method

```xml
<xsl:output name="csv" method="text" encoding="utf-8"/>

<xsl:template match="catalog">
  <!-- HTML primary output -->
  <html>...</html>

  <!-- CSV export -->
  <xsl:result-document href="export/products.csv" format="csv">
    <xsl:text>id,name,category,price&#10;</xsl:text>
    <xsl:for-each select="product">
      <xsl:value-of select="@id"/>
      <xsl:text>,</xsl:text>
      <!-- Quote fields that might contain commas -->
      <xsl:value-of select="concat('&quot;', replace(name, '&quot;', '&quot;&quot;'), '&quot;')"/>
      <xsl:text>,</xsl:text>
      <xsl:value-of select="@category"/>
      <xsl:text>,</xsl:text>
      <xsl:value-of select="price"/>
      <xsl:text>&#10;</xsl:text>
    </xsl:for-each>
  </xsl:result-document>
</xsl:template>
```

---

## Secondary Output in the PhoenixmlDb API

When running transformations through the PhoenixmlDb .NET API, secondary output documents are collected in a dictionary rather than written directly to the file system. This gives you programmatic access to all generated outputs.

```csharp
using PhoenixmlDb.Xslt;

var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheet, new Uri("catalog.xslt"));
var result = await transformer.TransformAsync(sourceXml);

// Primary result
string indexHtml = result.PrimaryResult;
File.WriteAllText("output/index.html", indexHtml);

// Secondary result documents (from xsl:result-document)
foreach (var (href, content) in result.SecondaryResultDocuments)
{
    var outputPath = Path.Combine("output", href);
    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    File.WriteAllText(outputPath, content);
}
```

This design lets you:

- **Write to any storage** — local files, blob storage, database, HTTP endpoints
- **Post-process** generated documents before writing them
- **Test** transformations by inspecting secondary outputs in memory
- **Filter** which documents to actually write

**C# parallel:** `xsl:result-document` is conceptually like calling `File.WriteAllText(path, content)` for each output file, except the XSLT engine collects them and hands them to you. The calling code decides where they actually go.

### Controlling the Base URI

The `href` values in `xsl:result-document` are resolved relative to the base output URI. In the PhoenixmlDb API, you can set this when calling the transform:

```csharp
var options = new TransformOptions
{
    BaseOutputUri = new Uri("file:///output/site/")
};

var result = await transformer.TransformAsync(sourceXml, options);

// result.SecondaryResultDocuments keys are now relative to /output/site/
// e.g., "products/WP-001.html", "api/catalog.json"
```
