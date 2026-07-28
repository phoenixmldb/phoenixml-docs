---
title: Extensibility
description: "Extending XSLT with custom functions, packages, extension instructions, and .NET integration"
sort: 5
---

# Extensibility

XSLT stylesheets rarely run in isolation. Real transforms need domain-specific logic, access to external data, and integration with the host application. The extensibility model provides several mechanisms for this: user-defined functions, packages, language-level extension functions and instructions, and import/include hierarchies. On the .NET side, PhoenixmlDb exposes a transform-hosting API. Load a stylesheet, pass in parameters, run the transform, and read back the results, including secondary result documents.

> For C# developers: this pattern resembles ASP.NET Core middleware, Razor tag
> helpers, and plugin architectures built on `IServiceCollection`. Each one
> extends a framework's built-in capabilities with application-specific
> behavior.

## Contents

- [Why Extensibility Matters](#why-extensibility-matters)

- [xsl:function — User-Defined Functions](#xslfunction--user-defined-functions)

- [Packages — Reusable Stylesheet Libraries](#packages--reusable-stylesheet-libraries)

- [Extension Functions from .NET](#extension-functions-from-net)

- [Extension Instructions and xsl:fallback](#extension-instructions-and-xslfallback)

- [Import and Include](#import-and-include)

- [Practical Patterns](#practical-patterns)

- [Integration Examples](#integration-examples)

---

## Why Extensibility Matters

Consider a real XSLT transform for generating invoices. You need to:

- **Format currency** according to the customer's locale

- **Calculate tax** based on jurisdiction-specific rules that change quarterly

- **Look up** the current exchange rate from an API

- **Generate** a unique invoice number from a database sequence

- **Send** the rendered invoice to a print queue or email service

Standard XSLT handles the XML transform itself. Extensibility handles everything else: the parts where the stylesheet connects to the outside world.

**C# parallel:**
```csharp
// ASP.NET Core: the framework handles HTTP, you extend with middleware and services
builder.Services.AddScoped<IInvoiceFormatter, LocaleAwareFormatter>();
builder.Services.AddScoped<ITaxCalculator, JurisdictionTaxCalculator>();
builder.Services.AddHttpClient<IExchangeRateService, OpenExchangeRateService>();
```

---

## xsl:function — User-Defined Functions

This section provides a brief recap. For comprehensive coverage, see [User-Defined Functions](instructions/functions.md).

`xsl:function` defines custom functions callable from any XPath expression:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:app="http://example.com/app"
                 version="3.0">

  <xsl:function name="app:format-price" as="xs:string">
    <xsl:param name="amount" as="xs:decimal"/>
    <xsl:param name="currency" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$currency = 'USD'">
        <xsl:value-of select="concat('$', format-number($amount, '#,##0.00'))"/>
      </xsl:when>
      <xsl:when test="$currency = 'EUR'">
        <xsl:value-of select="concat(format-number($amount, '#.##0,00'), ' EUR')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat(format-number($amount, '#,##0.00'), ' ', $currency)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Use it in any XPath expression -->
  <xsl:template match="order">
    <div class="total">
      <xsl:value-of select="app:format-price(total, @currency)"/>
    </div>
  </xsl:template>

</xsl:stylesheet>
```

Functions can be recursive, accept other functions as arguments (higher-order functions), and return any XPath type — strings, numbers, nodes, maps, arrays, or sequences.

When a stylesheet function shares its name and arity with an extension function, the `override-extension-function` attribute on `xsl:function` controls which one wins. Set it to `yes` to let the stylesheet function take precedence over the extension function, or to `no` to keep the extension function's version. The value must agree with the `override` attribute when both are present on the same `xsl:function`. (As noted below, PhoenixmlDb has no way to register a C#-backed extension function today. In practice this attribute matters for extension functions from other sources, such as a different processor, not for host-registered .NET callbacks.)

---

## Packages — Reusable Stylesheet Libraries

This section provides a brief recap. For comprehensive coverage, see [Packages](instructions/packages.md).

XSLT 3.0 packages bundle stylesheets into reusable libraries with controlled visibility.

> For C# developers: an XSLT package resembles a NuGet package. Both bundle
> reusable code and both expose a controlled surface to consumers.

### Defining a Package

```xml
<xsl:package name="http://example.com/formatting" version="2.0"
             xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
             xmlns:fmt="http://example.com/formatting"
             version="3.0">

  <!-- Public: consumers can call this -->
  <xsl:expose component="function" names="fmt:format-date" visibility="public"/>
  <xsl:expose component="function" names="fmt:format-currency" visibility="public"/>

  <!-- Private: internal helper, not accessible to consumers -->
  <xsl:expose component="function" names="fmt:*-helper" visibility="private"/>

  <!-- Abstract: consumers MUST override this -->
  <xsl:expose component="function" names="fmt:get-locale" visibility="abstract"/>

  <xsl:function name="fmt:format-date" as="xs:string">
    <xsl:param name="date" as="xs:date"/>
    <xsl:value-of select="format-date($date, '[MNn] [D], [Y]')"/>
  </xsl:function>

  <xsl:function name="fmt:format-currency" as="xs:string" visibility="public">
    <xsl:param name="amount" as="xs:decimal"/>
    <xsl:value-of select="concat('$', format-number($amount, '#,##0.00'))"/>
  </xsl:function>

</xsl:package>
```

### Using a Package

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:use-package name="http://example.com/formatting" version="2.0">
    <!-- Override the abstract function -->
    <xsl:override>
      <xsl:function name="fmt:get-locale" as="xs:string"
                    xmlns:fmt="http://example.com/formatting">
        <xsl:sequence select="'en-US'"/>
      </xsl:function>
    </xsl:override>
  </xsl:use-package>

</xsl:stylesheet>
```

**Visibility controls:**

| XSLT Visibility | C# Equivalent | Meaning |
|-----------------|---------------|---------|
| `public` | `public` | Accessible to consumers |
| `private` | `private` / `internal` | Hidden from consumers |
| `final` | `sealed` / non-`virtual` | Public but cannot be overridden |
| `abstract` | `abstract` | Must be overridden by consumer |

---

## Extension Functions from .NET

> **No custom C# extension functions today.** In XQuery, you subclass `XQueryFunction` and register it with `FunctionLibrary.Register`, and it becomes callable from XQuery. The XSLT engine has no equivalent. It exposes **no public API for registering a C#-backed function** that a stylesheet can call from XPath. `XsltTransformer` builds its function library internally, from the standard function library plus the stylesheet's own `xsl:function` declarations. It never accepts a caller-supplied library.
>
> Connecting XSLT to the outside world today happens at the language level. Use `xsl:function`, extension instructions (declared via `extension-element-prefixes`), or packages — not a C# delegate handed to the engine. The .NET integration surface below covers what IS available: loading a stylesheet, passing in parameters, running the transform, and reading back results.

### Setting Stylesheet Parameters from C#

The simplest form of .NET integration — pass values into the stylesheet:

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheet, baseUri);

// Set parameters that the stylesheet declares with xsl:param
transformer.SetParameter("api-key", apiKey);
transformer.SetParameter("base-url", "https://api.example.com");
transformer.SetParameter("report-date", DateTime.Now.ToString("yyyy-MM-dd"));
transformer.SetParameter("environment", "production");
transformer.SetParameter("user-name", currentUser.DisplayName);

var result = await transformer.TransformAsync(inputXml);
```

The stylesheet declares matching parameters:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:param name="api-key" as="xs:string"/>
  <xsl:param name="base-url" as="xs:string" select="'https://localhost'"/>
  <xsl:param name="report-date" as="xs:date" select="current-date()"/>
  <xsl:param name="environment" as="xs:string" select="'development'"/>
  <xsl:param name="user-name" as="xs:string" select="'anonymous'"/>

  <xsl:template match="/">
    <report generated-by="{$user-name}"
            date="{format-date($report-date, '[Y]-[M01]-[D01]')}"
            env="{$environment}">
      <xsl:apply-templates/>
    </report>
  </xsl:template>

</xsl:stylesheet>
```

**C# parallel:**
```csharp
// Parameters are like constructor arguments or configuration values
public class ReportGenerator
{
    private readonly string _apiKey;
    private readonly string _baseUrl;
    private readonly string _environment;

    public ReportGenerator(IConfiguration config)
    {
        _apiKey = config["ApiKey"];
        _baseUrl = config["BaseUrl"];
        _environment = config["Environment"] ?? "development";
    }
}
```

### What You Can (and Can't) Do From the Stylesheet Side

Pure computation — formatting, lookups against data already in scope, string and number manipulation — belongs in `xsl:function`. There is no host-registered C# callback to put it in instead:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:ext="http://example.com/ext"
                 version="3.0">

  <xsl:function name="ext:format-phone" as="xs:string">
    <xsl:param name="phone" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="string-length($phone) = 10">
        <xsl:sequence select="concat('(', substring($phone, 1, 3), ') ',
                                      substring($phone, 4, 3), '-',
                                      substring($phone, 7, 4))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$phone"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="phone">
    <formatted-phone>
      <xsl:value-of select="ext:format-phone(.)"/>
    </formatted-phone>
  </xsl:template>

</xsl:stylesheet>
```

Some things need a side effect the stylesheet cannot itself perform. Examples include an outbound HTTP call to a live exchange-rate API, a write to an application logger, or a database lookup by key. None of those are **reachable from XSLT today**. There is no supported way to plug a C# delegate into the function library XPath resolves against. If your transform needs that kind of data, the honest options are:

- **Fetch it before the transform runs.** Pass the result in as a stylesheet parameter with `SetParameter` (see above).
- **Fetch it as XML, then pass it in as an additional source document.** Use a node-typed parameter, or a `document()` URI.
- **Do the enrichment as a post-processing step in C#**, after `TransformAsync` returns, using the primary result and `SecondaryResultDocuments`.

There is no public API today for registering a C#-backed extension function that XSLT can call mid-transform.

### Handling Secondary Result Documents

XSLT's `xsl:result-document` produces multiple output files from a single transform. The .NET API captures all of them:

```xml
<!-- Stylesheet that produces multiple files -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:template match="/">
    <!-- Primary output: index.html -->
    <html>
      <body>
        <h1>Product Catalog</h1>
        <ul>
          <xsl:for-each select="//product">
            <li><a href="{@id}.html"><xsl:value-of select="name"/></a></li>
          </xsl:for-each>
        </ul>
      </body>
    </html>

    <!-- Secondary outputs: one page per product -->
    <xsl:for-each select="//product">
      <xsl:result-document href="{@id}.html" method="html" html-version="5">
        <html>
          <body>
            <h1><xsl:value-of select="name"/></h1>
            <p class="price"><xsl:value-of select="format-number(price, '$#,##0.00')"/></p>
            <div class="description"><xsl:value-of select="description"/></div>
          </body>
        </html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
```

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheet, baseUri);
var primaryResult = await transformer.TransformAsync(inputXml);

// Write primary result
string outputDir = "/output/catalog";
Directory.CreateDirectory(outputDir);
await File.WriteAllTextAsync(Path.Combine(outputDir, "index.html"), primaryResult);

// Write all secondary result documents
foreach (var (href, content) in transformer.SecondaryResultDocuments)
{
    string filePath = Path.Combine(outputDir, href);
    Directory.CreateDirectory(Path.GetDirectoryName(filePath)!);
    await File.WriteAllTextAsync(filePath, content);
}

Console.WriteLine($"Generated {1 + transformer.SecondaryResultDocuments.Count} files");
```

---

## Extension Instructions and xsl:fallback

### Extension Instructions

Extension elements allow processors to support custom XSLT instructions beyond the standard set. You declare extension namespaces with `extension-element-prefixes`:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:sql="http://example.com/sql-extension"
                 extension-element-prefixes="sql"
                 version="3.0">

  <xsl:template match="report">
    <sql:query connection="main" var="rows">
      SELECT name, total FROM orders WHERE date = current_date
    </sql:query>

    <table>
      <xsl:for-each select="$rows/row">
        <tr>
          <td><xsl:value-of select="name"/></td>
          <td><xsl:value-of select="total"/></td>
        </tr>
      </xsl:for-each>
    </table>
  </xsl:template>

</xsl:stylesheet>
```

### xsl:fallback — Graceful Degradation

When an extension element is not available (because the stylesheet runs on a different processor), `xsl:fallback` provides a safe alternative:

```xml
<xsl:template match="data">
  <sql:query connection="main" var="rows">
    SELECT * FROM products
    <xsl:fallback>
      <!-- If sql:query isn't supported, use static data instead -->
      <xsl:message>SQL extension not available. Using static data.</xsl:message>
      <xsl:apply-templates select="document('static-products.xml')//product"/>
    </xsl:fallback>
  </sql:query>
</xsl:template>
```

This pattern lets you write stylesheets that work across processors — using advanced features where available and degrading gracefully elsewhere.

**C# parallel:**
```csharp
// Similar to optional dependency injection with fallbacks
public class ProductService
{
    private readonly ISqlExtension? _sql;
    private readonly IStaticDataProvider _fallback;

    public IEnumerable<Product> GetProducts()
    {
        if (_sql != null)
            return _sql.Query<Product>("SELECT * FROM products");
        else
            return _fallback.LoadProducts("static-products.xml");
    }
}
```

### use-when — Compile-Time Conditional Inclusion

For compile-time decisions about which code to include:

```xml
<!-- Only include debug templates when running in development -->
<xsl:template match="*" mode="debug"
              use-when="system-property('xsl:product-name') = 'PhoenixmlDb'">
  <div class="debug">
    <pre><xsl:copy-of select="."/></pre>
  </div>
</xsl:template>
```

---

## Import and Include

### xsl:import — Lower Precedence

Imported templates and functions have lower precedence than those in the importing stylesheet. This lets you define defaults that the importer can override:

```xml
<!-- base-styles.xsl — provides default formatting -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:template match="heading">
    <h2><xsl:value-of select="."/></h2>
  </xsl:template>

  <xsl:template match="paragraph">
    <p><xsl:value-of select="."/></p>
  </xsl:template>

</xsl:stylesheet>
```

```xml
<!-- custom-styles.xsl — overrides specific templates -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:import href="base-styles.xsl"/>

  <!-- Override: headings get a class attribute -->
  <xsl:template match="heading">
    <h2 class="custom-heading"><xsl:value-of select="."/></h2>
  </xsl:template>

  <!-- paragraph template is inherited from base-styles.xsl -->

</xsl:stylesheet>
```

You can call the overridden (imported) template with `xsl:next-match` or `xsl:apply-imports`:

```xml
<xsl:template match="heading">
  <div class="heading-wrapper">
    <!-- Delegate to the imported template for the actual rendering -->
    <xsl:next-match/>
  </div>
</xsl:template>
```

**C# parallel:**
```csharp
// Like virtual method override with base call
public class CustomRenderer : BaseRenderer
{
    public override string RenderHeading(string text)
    {
        // Wrap the base implementation
        return $"<div class='heading-wrapper'>{base.RenderHeading(text)}</div>";
    }
}
```

### xsl:include — Same Precedence

The processor treats an included stylesheet as if its content appears directly in the including stylesheet. There is no precedence difference:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <!-- Pull in shared templates at the same precedence level -->
  <xsl:include href="common-templates.xsl"/>
  <xsl:include href="utility-functions.xsl"/>

  <xsl:template match="/">
    <!-- Can use templates and functions from included files -->
    <xsl:apply-templates/>
  </xsl:template>

</xsl:stylesheet>
```

### Building Stylesheet Hierarchies

Larger projects use a layered architecture:

```
stylesheets/
  base/
    typography.xsl        (: base text formatting :)
    layout.xsl            (: page structure :)
    utilities.xsl         (: helper functions :)
  themes/
    corporate.xsl         (: imports base, overrides with corporate styles :)
    marketing.xsl         (: imports base, overrides with marketing styles :)
  transforms/
    invoice.xsl           (: includes corporate theme + invoice-specific logic :)
    report.xsl            (: includes corporate theme + report-specific logic :)
    email-template.xsl    (: includes marketing theme + email layout :)
```

```xml
<!-- transforms/invoice.xsl -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <!-- Import the corporate theme (which imports base) -->
  <xsl:import href="../themes/corporate.xsl"/>

  <!-- Include invoice-specific utilities at same precedence -->
  <xsl:include href="../base/utilities.xsl"/>

  <!-- Invoice-specific templates (highest precedence) -->
  <xsl:template match="invoice">
    <!-- ... -->
  </xsl:template>

</xsl:stylesheet>
```

**Import vs Include — when to use each:**

| Aspect | `xsl:import` | `xsl:include` |
|--------|-------------|---------------|
| Precedence | Lower than importing stylesheet | Same as including stylesheet |
| Can override | Yes — importer's templates win | No — name conflicts are errors |
| Use case | Base/default templates you want to customize | Shared utilities you want at the same level |
| C# parallel | Inheriting from a base class | `partial` classes or `global using static` |

---

## Practical Patterns

### Custom Output Formatting Functions

Build a library of formatting functions for consistent output:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:fmt="http://example.com/format"
                 version="3.0">

  <xsl:function name="fmt:date-human" as="xs:string">
    <xsl:param name="date" as="xs:date"/>
    <xsl:value-of select="format-date($date, '[MNn] [D], [Y]')"/>
  </xsl:function>

  <xsl:function name="fmt:date-iso" as="xs:string">
    <xsl:param name="date" as="xs:date"/>
    <xsl:value-of select="format-date($date, '[Y]-[M01]-[D01]')"/>
  </xsl:function>

  <xsl:function name="fmt:bytes" as="xs:string">
    <xsl:param name="bytes" as="xs:integer"/>
    <xsl:choose>
      <xsl:when test="$bytes ge 1073741824">
        <xsl:value-of select="concat(format-number($bytes div 1073741824, '#,##0.0'), ' GB')"/>
      </xsl:when>
      <xsl:when test="$bytes ge 1048576">
        <xsl:value-of select="concat(format-number($bytes div 1048576, '#,##0.0'), ' MB')"/>
      </xsl:when>
      <xsl:when test="$bytes ge 1024">
        <xsl:value-of select="concat(format-number($bytes div 1024, '#,##0.0'), ' KB')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($bytes, ' bytes')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="fmt:pluralize" as="xs:string">
    <xsl:param name="count" as="xs:integer"/>
    <xsl:param name="singular" as="xs:string"/>
    <xsl:param name="plural" as="xs:string"/>
    <xsl:value-of select="concat($count, ' ', if ($count = 1) then $singular else $plural)"/>
  </xsl:function>

</xsl:stylesheet>
```

### Conditional Processing Based on Environment

Use parameters to vary behavior between development and production:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:param name="environment" as="xs:string" select="'development'"/>
  <xsl:param name="debug" as="xs:boolean" select="false()"/>
  <xsl:param name="cdn-url" as="xs:string" select="''"/>

  <xsl:template match="/">
    <html>
      <head>
        <!-- Use CDN in production, local files in development -->
        <xsl:choose>
          <xsl:when test="$environment = 'production'">
            <link rel="stylesheet" href="{$cdn-url}/styles.min.css"/>
            <script src="{$cdn-url}/app.min.js"/>
          </xsl:when>
          <xsl:otherwise>
            <link rel="stylesheet" href="/css/styles.css"/>
            <script src="/js/app.js"/>
          </xsl:otherwise>
        </xsl:choose>
      </head>
      <body>
        <xsl:apply-templates/>

        <!-- Debug panel only in development -->
        <xsl:if test="$debug">
          <div id="debug-panel" style="background: #ffffcc; padding: 1em;">
            <h3>Debug Info</h3>
            <p>Environment: <xsl:value-of select="$environment"/></p>
            <p>Node count: <xsl:value-of select="count(//*)"/></p>
            <p>Transform time: <xsl:value-of select="current-dateTime()"/></p>
          </div>
        </xsl:if>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
```

```csharp
// C# — set environment-specific parameters
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheet, baseUri);

if (env.IsProduction())
{
    transformer.SetParameter("environment", "production");
    transformer.SetParameter("debug", false);
    transformer.SetParameter("cdn-url", "https://cdn.example.com/v3");
}
else
{
    transformer.SetParameter("environment", "development");
    transformer.SetParameter("debug", true);
}

var html = await transformer.TransformAsync(inputXml);
```

### Multi-Pass Transforms

Feed the output of one transform into another:

```csharp
var transformer = new XsltTransformer();

// Pass 1: Normalize the data
await transformer.LoadStylesheetAsync(normalizeStylesheet, baseUri);
var normalized = await transformer.TransformAsync(rawInput);

// Pass 2: Enrich with computed fields
await transformer.LoadStylesheetAsync(enrichStylesheet, baseUri);
transformer.SetParameter("enrichment-date", DateTime.Now.ToString("yyyy-MM-dd"));
var enriched = await transformer.TransformAsync(normalized);

// Pass 3: Render final output
await transformer.LoadStylesheetAsync(renderStylesheet, baseUri);
transformer.SetParameter("output-format", "html");
var finalOutput = await transformer.TransformAsync(enriched);

await File.WriteAllTextAsync("output/report.html", finalOutput);
```

### Data Access — Fetch First, Then Transform

Because there is no host-registered extension function, a stylesheet cannot reach out to a database or API mid-transform. Fetch the data in C# BEFORE calling `TransformAsync`, serialize it as XML, and pass it as a string parameter. The stylesheet then parses it with the standard `parse-xml()` function:

```csharp
using PhoenixmlDb.Xslt;

// 1. Fetch the data the stylesheet needs, in C#, before transforming
var customers = new StringBuilder("<customers>");
using (var conn = new SqlConnection(connectionString))
{
    conn.Open();
    using var cmd = new SqlCommand("SELECT Id, Name, Email FROM Customers", conn);
    using var reader = cmd.ExecuteReader();
    while (reader.Read())
    {
        customers.Append(
            $"<customer id='{SecurityElement.Escape(reader.GetString(0))}' " +
            $"name='{SecurityElement.Escape(reader.GetString(1))}' " +
            $"email='{SecurityElement.Escape(reader.GetString(2))}'/>");
    }
}
customers.Append("</customers>");

// 2. Pass the fetched XML in as a stylesheet parameter
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheet, baseUri);
transformer.SetParameter("customers-xml", customers.ToString());

var html = await transformer.TransformAsync(orderXml);
```

The stylesheet parses the parameter with the standard `parse-xml()` function and looks up by key:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:param name="customers-xml" as="xs:string" select="'&lt;customers/&gt;'"/>
  <xsl:variable name="customers" select="parse-xml($customers-xml)/customers"/>

  <xsl:template match="order">
    <xsl:variable name="customer" select="$customers/customer[@id = current()/@customer-id]"/>
    <div class="order">
      <h2>Order #<xsl:value-of select="@id"/></h2>
      <p>Customer: <xsl:value-of select="$customer/@name"/></p>
      <p>Email: <xsl:value-of select="$customer/@email"/></p>
      <xsl:apply-templates select="items"/>
    </div>
  </xsl:template>

</xsl:stylesheet>
```

This keeps the same separation of concerns extension functions would give you: the stylesheet stays declarative, and the data access lives in C#. It just doesn't rely on an API the engine does not have.

---

## Integration Examples

### ASP.NET Core — XSLT Transforms as Middleware

Use XSLT to transform XML API responses into HTML:

```csharp
public class XsltMiddleware
{
    private readonly RequestDelegate _next;
    private readonly string _stylesheetPath;

    public XsltMiddleware(RequestDelegate next, string stylesheetPath)
    {
        _next = next;
        _stylesheetPath = stylesheetPath;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Only transform if the client accepts HTML and the response is XML
        if (!context.Request.Headers.Accept.ToString().Contains("text/html"))
        {
            await _next(context);
            return;
        }

        // Capture the response
        var originalBody = context.Response.Body;
        using var buffer = new MemoryStream();
        context.Response.Body = buffer;

        await _next(context);

        buffer.Seek(0, SeekOrigin.Begin);
        var xmlContent = await new StreamReader(buffer).ReadToEndAsync();

        if (context.Response.ContentType?.Contains("xml") == true)
        {
            // Transform XML to HTML
            var transformer = new XsltTransformer();
            await transformer.LoadStylesheetAsync(
                await File.ReadAllTextAsync(_stylesheetPath),
                new Uri(_stylesheetPath).AbsoluteUri);
            transformer.SetParameter("request-path", context.Request.Path.Value ?? "/");
            transformer.SetParameter("timestamp", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));

            var html = await transformer.TransformAsync(xmlContent);

            context.Response.Body = originalBody;
            context.Response.ContentType = "text/html; charset=utf-8";
            await context.Response.WriteAsync(html);
        }
        else
        {
            buffer.Seek(0, SeekOrigin.Begin);
            context.Response.Body = originalBody;
            await buffer.CopyToAsync(originalBody);
        }
    }
}

// Registration in Program.cs
app.UseMiddleware<XsltMiddleware>("stylesheets/api-to-html.xsl");
```

### CLI Tools — Batch Transforms

Build a command-line tool that applies XSLT transforms, similar to PhoenixmlDb's `xslt` CLI:

```csharp
public class XsltCli
{
    public static async Task<int> Main(string[] args)
    {
        string stylesheetPath = args[0];
        string inputPath = args[1];
        string outputPath = args.Length > 2 ? args[2] : "-"; // "-" means stdout

        var transformer = new XsltTransformer();
        var stylesheet = await File.ReadAllTextAsync(stylesheetPath);
        await transformer.LoadStylesheetAsync(stylesheet, new Uri(stylesheetPath).AbsoluteUri);

        // Pass environment variables as parameters
        transformer.SetParameter("build-date", DateTime.Now.ToString("yyyy-MM-dd"));
        transformer.SetParameter("hostname", Environment.MachineName);

        // Set any NAME=VALUE arguments as parameters
        foreach (var arg in args.Skip(3))
        {
            var parts = arg.Split('=', 2);
            if (parts.Length == 2)
                transformer.SetParameter(parts[0], parts[1]);
        }

        var input = await File.ReadAllTextAsync(inputPath);
        var result = await transformer.TransformAsync(input);

        if (outputPath == "-")
            Console.Write(result);
        else
            await File.WriteAllTextAsync(outputPath, result);

        // Handle multi-file output
        foreach (var (href, content) in transformer.SecondaryResultDocuments)
        {
            string dir = Path.GetDirectoryName(outputPath) ?? ".";
            string filePath = Path.Combine(dir, href);
            Directory.CreateDirectory(Path.GetDirectoryName(filePath)!);
            await File.WriteAllTextAsync(filePath, content);
            Console.Error.WriteLine($"  Created: {filePath}");
        }

        return 0;
    }
}
```

Usage:

```bash
# Basic transform
dotnet run -- stylesheet.xsl input.xml output.html

# With parameters
dotnet run -- invoice.xsl order.xml invoice.html customer-name="Acme Corp" currency=EUR

# Multi-file output (catalog with per-product pages)
dotnet run -- catalog.xsl products.xml output/index.html
#   Created: output/product-001.html
#   Created: output/product-002.html
#   Created: output/product-003.html
```

### CI/CD — Generating Documentation and Reports

Use XSLT in build pipelines to generate documentation, configuration files, or test reports:

```csharp
// Build step: generate API documentation from XML doc comments
public class DocGenerationTask
{
    public async Task GenerateApiDocsAsync(string projectDir, string outputDir)
    {
        // 1. Collect all XML doc comment files
        var xmlDocs = Directory.GetFiles(projectDir, "*.xml", SearchOption.AllDirectories)
            .Where(f => Path.GetDirectoryName(f)?.Contains("bin") == true);

        // 2. Merge into a single XML document
        var merged = new XElement("documentation",
            xmlDocs.Select(f => XElement.Load(f)));

        // 3. Transform to HTML documentation
        var transformer = new XsltTransformer();
        await transformer.LoadStylesheetAsync(
            await File.ReadAllTextAsync("build/api-docs.xsl"),
            "file:///build/api-docs.xsl");

        transformer.SetParameter("project-name", "MyProject");
        transformer.SetParameter("version", GetVersionFromCsproj());
        transformer.SetParameter("build-date", DateTime.Now.ToString("yyyy-MM-dd"));

        var html = await transformer.TransformAsync(merged.ToString());

        Directory.CreateDirectory(outputDir);
        await File.WriteAllTextAsync(Path.Combine(outputDir, "api.html"), html);

        // Write per-namespace pages from secondary results
        foreach (var (href, content) in transformer.SecondaryResultDocuments)
        {
            await File.WriteAllTextAsync(Path.Combine(outputDir, href), content);
        }
    }
}
```

```yaml
# GitHub Actions workflow step
- name: Generate API Documentation
  run: dotnet run --project tools/DocGen -- src/ docs/api/
```

The stylesheet handles the formatting logic. It transforms raw XML doc comments into navigable, styled HTML pages. The .NET code handles file I/O, parameter passing, and build integration.
