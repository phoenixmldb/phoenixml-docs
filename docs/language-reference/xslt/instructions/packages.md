---
title: Packages
description: "xsl:use-package, xsl:accept, xsl:override, xsl:expose — reusable stylesheet libraries"
sort: 16
---

# Packages

XSLT 3.0 introduces packages — a system for bundling stylesheets into reusable, encapsulated libraries with controlled visibility. If you have worked with NuGet packages, C# assemblies, and access modifiers (`public`, `internal`, `sealed`), you already understand the motivation: ship reusable code with a clean public API while hiding implementation details.

## Contents

- [Why Packages?](#why-packages)
- [xsl:package — Declaring a Package](#xslpackage--declaring-a-package)
- [xsl:expose — Controlling Visibility](#xslexpose--controlling-visibility)
- [xsl:use-package — Importing a Package](#xsluse-package--importing-a-package)
- [xsl:accept — Adjusting Imported Visibility](#xslaccept--adjusting-imported-visibility)
- [xsl:override — Overriding Package Components](#xsloverride--overriding-package-components)
- [The Visibility System](#the-visibility-system)
- [Comparison with xsl:import and xsl:include](#comparison-with-xslimport-and-xslinclude)
- [Design Patterns](#design-patterns)

---

## Why Packages?

Before XSLT 3.0, stylesheet reuse relied on `xsl:import` and `xsl:include`. These work, but they have problems:

- **No encapsulation:** Every template, function, and variable in an imported stylesheet is visible to the importing stylesheet. Internal helpers leak into the public API.
- **Name collisions:** Two imported stylesheets that define the same template or function conflict unpredictably.
- **Fragile overriding:** Import precedence rules are subtle and easy to get wrong.
- **No versioning:** There is no way to specify which version of a library you depend on.

Packages solve all of these problems.

**C# parallel:**

| XSLT Concept | C# Equivalent |
|--------------|---------------|
| `xsl:package` | A NuGet package / class library assembly |
| `xsl:expose visibility="public"` | `public` access modifier |
| `xsl:expose visibility="private"` | `private` / `internal` access modifier |
| `xsl:expose visibility="final"` | `sealed` class / non-virtual method |
| `xsl:expose visibility="abstract"` | `abstract` method |
| `xsl:use-package` | `<PackageReference>` in .csproj |
| `xsl:override` | `override` keyword on virtual methods |
| `xsl:accept` | Controlling which types are visible via `using` / `global using` |

---

## xsl:package — Declaring a Package

A package is declared using `xsl:package` as the root element instead of `xsl:stylesheet`:

```xml
<xsl:package
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:html="http://example.com/html-utils"
    name="http://example.com/html-utils"
    package-version="2.1.0"
    version="3.0"
    declared-modes="yes">

  <!-- Package components: templates, functions, variables, modes -->

  <xsl:function name="html:escape" as="xs:string" visibility="public">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="replace(replace(replace($text, '&amp;', '&amp;amp;'),
                          '&lt;', '&amp;lt;'), '&gt;', '&amp;gt;')"/>
  </xsl:function>

  <xsl:function name="html:wrap-tag" as="xs:string" visibility="public">
    <xsl:param name="tag" as="xs:string"/>
    <xsl:param name="content" as="xs:string"/>
    <xsl:sequence select="concat('&lt;', $tag, '&gt;', html:escape($content), '&lt;/', $tag, '&gt;')"/>
  </xsl:function>

  <!-- Internal helper — not accessible outside the package -->
  <xsl:function name="html:internal-sanitize" as="xs:string" visibility="private">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="replace($text, '[^\p{L}\p{N}\s]', '')"/>
  </xsl:function>

</xsl:package>
```

### Key Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `name` | Unique package identifier (typically a URI) | `"http://example.com/html-utils"` |
| `package-version` | Semantic version of the package | `"2.1.0"` |
| `version` | XSLT version | `"3.0"` |
| `declared-modes` | If `yes`, only explicitly declared modes are public | `"yes"` |

### declared-modes

When `declared-modes="yes"`, modes must be explicitly declared with `xsl:mode` to be accessible. This prevents accidental mode leakage:

```xml
<xsl:package name="http://example.com/formatter"
             package-version="1.0.0" version="3.0"
             declared-modes="yes">

  <!-- This mode is accessible to users of the package -->
  <xsl:mode name="format" visibility="public"/>

  <!-- This mode is internal -->
  <xsl:mode name="internal-cleanup" visibility="private"/>

  <xsl:template match="*" mode="format">
    <!-- ... -->
  </xsl:template>

  <xsl:template match="*" mode="internal-cleanup">
    <!-- ... -->
  </xsl:template>

</xsl:package>
```

---

## xsl:expose — Controlling Visibility

`xsl:expose` sets the visibility of components declared within the package. It appears as a top-level element inside `xsl:package`.

### Setting Visibility on Individual Components

The simplest approach is to set `visibility` directly on each component:

```xml
<xsl:function name="my:public-function" visibility="public">...</xsl:function>
<xsl:function name="my:private-helper" visibility="private">...</xsl:function>
<xsl:template name="main-output" visibility="public">...</xsl:template>
<xsl:variable name="internal-config" visibility="private" select="42"/>
```

### Bulk Visibility with xsl:expose

For packages with many components, `xsl:expose` sets visibility by pattern:

```xml
<xsl:package name="http://example.com/utils" package-version="1.0.0" version="3.0">

  <!-- Make all functions public by default -->
  <xsl:expose component="function" names="*" visibility="public"/>

  <!-- But hide internal helpers -->
  <xsl:expose component="function" names="my:internal-*" visibility="private"/>

  <!-- Make all variables private by default -->
  <xsl:expose component="variable" names="*" visibility="private"/>

  <!-- Expose specific variables -->
  <xsl:expose component="variable" names="my:version my:config" visibility="public"/>

</xsl:package>
```

### xsl:expose Attributes

| Attribute | Description |
|-----------|-------------|
| `component` | Type of component: `template`, `function`, `variable`, `attribute-set`, `mode` |
| `names` | Space-separated list of component names, or `*` for all |
| `visibility` | `public`, `private`, `final`, `abstract`, `hidden` |

---

## xsl:use-package — Importing a Package

To use a package in your stylesheet, add `xsl:use-package` as a top-level declaration:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:html="http://example.com/html-utils"
                version="3.0">

  <xsl:use-package name="http://example.com/html-utils"
                   package-version="2.1"/>

  <xsl:template match="paragraph">
    <p><xsl:value-of select="html:escape(.)"/></p>
  </xsl:template>

</xsl:stylesheet>
```

### Version Selection

The `package-version` attribute supports version ranges:

```xml
<!-- Exact version -->
<xsl:use-package name="http://example.com/lib" package-version="2.1.0"/>

<!-- Minimum version -->
<xsl:use-package name="http://example.com/lib" package-version="2.0"/>

<!-- Version range -->
<xsl:use-package name="http://example.com/lib" package-version="2.*"/>
```

The processor selects the highest available version that matches the constraint.

### Package Catalog

How does the processor find the package file? Through a **package catalog** — a configuration that maps package names and versions to file locations. The catalog format is processor-specific. A typical catalog might look like:

```xml
<!-- Saxon-style package catalog -->
<catalog>
  <package name="http://example.com/html-utils"
           version="2.1.0"
           source-location="packages/html-utils-2.1.0.xsl"/>
  <package name="http://example.com/date-utils"
           version="1.0.0"
           source-location="packages/date-utils-1.0.0.xsl"/>
</catalog>
```

**C# parallel:** This is like NuGet package resolution — the package name and version constraint are resolved to a specific `.nupkg` file from configured sources.

---

## xsl:accept — Adjusting Imported Visibility

When you import a package, you may not need all of its public components. `xsl:accept` lets you narrow the visibility of imported components — you can hide components you do not use or rename them to avoid conflicts.

```xml
<xsl:use-package name="http://example.com/html-utils" package-version="2.1">
  <!-- Accept only the functions we need, hide the rest -->
  <xsl:accept component="function" names="html:escape" visibility="public"/>
  <xsl:accept component="function" names="*" visibility="hidden"/>
</xsl:use-package>
```

### Visibility Narrowing Rules

`xsl:accept` can only narrow visibility — it cannot make a private component public. The allowed transitions:

| Original | Can Be Changed To |
|----------|------------------|
| `public` | `public`, `private`, `hidden` |
| `final` | `final`, `private`, `hidden` |
| `abstract` | Cannot be hidden (must be overridden) |
| `private` | Cannot be changed (already invisible) |

### Why Use xsl:accept?

- **Avoid name collisions:** If two packages export functions with the same name, hide one.
- **Minimize API surface:** Only expose what your stylesheet actually uses.
- **Documentation:** Makes it clear which parts of the package your stylesheet depends on.

**C# parallel:** This is like choosing specific types to import with `using static` rather than importing an entire namespace, or using `[assembly: InternalsVisibleTo]` selectively.

---

## xsl:override — Overriding Package Components

When a package declares components as `public` (overridable) or `abstract` (must be overridden), the using stylesheet can provide replacement implementations:

```xml
<xsl:use-package name="http://example.com/report-generator" package-version="1.0">
  <xsl:override>
    <!-- Replace the package's header template with our own -->
    <xsl:template name="report-header">
      <header>
        <h1>Custom Report — <xsl:value-of select="$report-title"/></h1>
        <p>Generated: <xsl:value-of select="current-dateTime()"/></p>
      </header>
    </xsl:template>

    <!-- Replace a function -->
    <xsl:function name="rpt:format-date" as="xs:string">
      <xsl:param name="date" as="xs:date"/>
      <xsl:sequence select="format-date($date, '[D01]/[M01]/[Y0001]')"/>
    </xsl:function>
  </xsl:override>
</xsl:use-package>
```

### What Can Be Overridden?

| Component Visibility | Can Be Overridden? |
|---------------------|-------------------|
| `public` | Yes |
| `abstract` | Must be overridden |
| `final` | No — compile-time error if you try |
| `private` | No — not visible |
| `hidden` | No — not visible |

### Abstract Components

A package can declare abstract components that must be provided by the user:

```xml
<!-- In the package -->
<xsl:package name="http://example.com/report-generator"
             package-version="1.0.0" version="3.0">

  <!-- Abstract template — user MUST override this -->
  <xsl:template name="report-header" visibility="abstract"/>

  <!-- Abstract function — user MUST provide implementation -->
  <xsl:function name="rpt:format-currency" as="xs:string" visibility="abstract">
    <xsl:param name="amount" as="xs:decimal"/>
  </xsl:function>

  <!-- Concrete template that calls the abstract ones -->
  <xsl:template name="generate-report" visibility="final">
    <html>
      <body>
        <xsl:call-template name="report-header"/>
        <xsl:for-each select="//line-item">
          <p><xsl:value-of select="rpt:format-currency(@amount)"/></p>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>

</xsl:package>
```

**C# parallel:** This is exactly like abstract methods in a base class:

```csharp
public abstract class ReportGenerator
{
    protected abstract string FormatHeader();
    protected abstract string FormatCurrency(decimal amount);

    // Sealed method that calls the abstract ones
    public sealed string GenerateReport(IEnumerable<LineItem> items)
    {
        var sb = new StringBuilder();
        sb.Append(FormatHeader());
        foreach (var item in items)
            sb.AppendLine(FormatCurrency(item.Amount));
        return sb.ToString();
    }
}
```

---

## The Visibility System

XSLT 3.0 defines five visibility levels for package components:

| Visibility | Accessible Outside Package? | Can Be Overridden? | Description |
|-----------|---------------------------|-------------------|-------------|
| `public` | Yes | Yes | Full access, can be customized |
| `final` | Yes | No | Full access, cannot be changed |
| `abstract` | Yes (signature only) | Must be | No implementation — user must provide one |
| `private` | No | No | Internal to the package |
| `hidden` | No | No | Like private, but also hidden from `xsl:accept` |

### Choosing the Right Visibility

- **`public`** — Use for templates and functions that users might want to customize. This is the equivalent of a `virtual` method in C#.
- **`final`** — Use for components that form the package's core logic and must not be altered. This is the equivalent of a `sealed` method.
- **`abstract`** — Use for extension points where the package cannot provide a default implementation. This is the equivalent of an `abstract` method.
- **`private`** — Use for internal helpers that support the public API. This is the equivalent of `private` or `internal`.
- **`hidden`** — Like `private`, but even more restricted. Hidden components cannot be referenced by `xsl:accept` in the using stylesheet. Use this for implementation details that should be completely invisible.

### Default Visibility

If no visibility is specified, the default depends on the component type:

- Templates (named and match): `private` by default
- Functions: `private` by default
- Variables and parameters: `private` by default
- Modes: depends on `declared-modes` attribute

To make a useful package, you must explicitly mark components as `public`, `final`, or `abstract`.

---

## Comparison with xsl:import and xsl:include

| Feature | `xsl:import` / `xsl:include` | `xsl:use-package` |
|---------|-------------------------------|-------------------|
| **Encapsulation** | None — everything is visible | Full visibility control |
| **Name collisions** | Resolved by import precedence | Avoided by private/hidden |
| **Overriding** | Import precedence (fragile) | Explicit `xsl:override` (clear) |
| **Versioning** | None | `package-version` attribute |
| **Circular dependencies** | Allowed with `xsl:include`, problematic with `xsl:import` | Not allowed |
| **Compilation** | Each import is recompiled | Packages can be pre-compiled |
| **Best for** | Simple reuse within a project | Library distribution, team collaboration |

### Migration Path

You can migrate from `xsl:import` to packages incrementally:

```xml
<!-- Before: using xsl:import -->
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:import href="utils.xsl"/>
  <xsl:import href="formatting.xsl"/>
  <!-- ... -->
</xsl:stylesheet>

<!-- After: using packages -->
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:use-package name="http://mycompany.com/xslt/utils" package-version="1.0"/>
  <xsl:use-package name="http://mycompany.com/xslt/formatting" package-version="1.0"/>
  <!-- ... -->
</xsl:stylesheet>
```

The imported stylesheets become packages by changing `xsl:stylesheet` to `xsl:package` and adding visibility declarations.

---

## Design Patterns

### Theme Package (Base + Override)

A base package provides default rendering, and theme packages override the visual presentation:

```xml
<!-- Base package: report-base -->
<xsl:package name="http://example.com/report-base"
             package-version="1.0.0" version="3.0">

  <xsl:template name="page-header" visibility="public">
    <header><h1>Default Report</h1></header>
  </xsl:template>

  <xsl:template name="page-footer" visibility="public">
    <footer><p>Generated by Report Engine</p></footer>
  </xsl:template>

  <xsl:template name="render-table" visibility="final">
    <xsl:param name="data"/>
    <xsl:call-template name="page-header"/>
    <table>
      <xsl:apply-templates select="$data"/>
    </table>
    <xsl:call-template name="page-footer"/>
  </xsl:template>

</xsl:package>
```

```xml
<!-- Theme stylesheet: corporate branding -->
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:use-package name="http://example.com/report-base" package-version="1.0">
    <xsl:override>
      <xsl:template name="page-header">
        <header class="corporate">
          <img src="logo.png" alt="Company Logo"/>
          <h1>Corporate Report</h1>
        </header>
      </xsl:template>

      <xsl:template name="page-footer">
        <footer class="corporate">
          <p>Confidential — Internal Use Only</p>
          <p>Generated: <xsl:value-of select="format-dateTime(current-dateTime(),
                         '[D01] [MNn] [Y0001] at [H01]:[m01]')"/></p>
        </footer>
      </xsl:template>
    </xsl:override>
  </xsl:use-package>

</xsl:stylesheet>
```

### Utility Package

A collection of reusable functions with no templates:

```xml
<xsl:package name="http://example.com/string-utils"
             package-version="1.0.0" version="3.0"
             xmlns:str="http://example.com/string-utils">

  <xsl:expose component="function" names="*" visibility="final"/>

  <xsl:function name="str:title-case" as="xs:string">
    <xsl:param name="input" as="xs:string"/>
    <xsl:sequence select="string-join(
      for $word in tokenize($input, '\s+')
      return concat(upper-case(substring($word, 1, 1)),
                    lower-case(substring($word, 2))),
      ' ')"/>
  </xsl:function>

  <xsl:function name="str:truncate" as="xs:string">
    <xsl:param name="input" as="xs:string"/>
    <xsl:param name="max-length" as="xs:integer"/>
    <xsl:sequence select="if (string-length($input) le $max-length)
                          then $input
                          else concat(substring($input, 1, $max-length - 3), '...')"/>
  </xsl:function>

  <xsl:function name="str:slug" as="xs:string">
    <xsl:param name="input" as="xs:string"/>
    <xsl:sequence select="lower-case(replace(normalize-space($input), '\s+', '-'))"/>
  </xsl:function>

</xsl:package>
```

Usage:

```xml
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:str="http://example.com/string-utils">

  <xsl:use-package name="http://example.com/string-utils" package-version="1.0"/>

  <xsl:template match="article">
    <div id="{str:slug(title)}">
      <h2><xsl:value-of select="str:title-case(title)"/></h2>
      <p><xsl:value-of select="str:truncate(description, 200)"/></p>
    </div>
  </xsl:template>

</xsl:stylesheet>
```

### Component Library with Abstract Extension Points

A package that requires the user to provide specific implementations:

```xml
<xsl:package name="http://example.com/email-template"
             package-version="1.0.0" version="3.0"
             xmlns:email="http://example.com/email-template">

  <!-- User must provide these -->
  <xsl:variable name="email:company-name" as="xs:string" visibility="abstract"/>
  <xsl:variable name="email:primary-color" as="xs:string" visibility="abstract"/>
  <xsl:template name="email:custom-content" visibility="abstract"/>

  <!-- Package provides the structure -->
  <xsl:template name="email:render" visibility="final">
    <html>
      <head>
        <style>
          .header { background-color: <xsl:value-of select="$email:primary-color"/>; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1><xsl:value-of select="$email:company-name"/></h1>
        </div>
        <div class="content">
          <xsl:call-template name="email:custom-content"/>
        </div>
        <div class="footer">
          <p>Sent by <xsl:value-of select="$email:company-name"/></p>
        </div>
      </body>
    </html>
  </xsl:template>

</xsl:package>
```

```xml
<!-- User's stylesheet -->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:email="http://example.com/email-template">

  <xsl:use-package name="http://example.com/email-template" package-version="1.0">
    <xsl:override>
      <xsl:variable name="email:company-name" select="'Acme Corp'" visibility="public"/>
      <xsl:variable name="email:primary-color" select="'#2563eb'" visibility="public"/>

      <xsl:template name="email:custom-content">
        <h2>Your Order Confirmation</h2>
        <p>Thank you for your purchase.</p>
        <xsl:apply-templates select="//order-item"/>
      </xsl:template>
    </xsl:override>
  </xsl:use-package>

  <xsl:template match="/">
    <xsl:call-template name="email:render"/>
  </xsl:template>

</xsl:stylesheet>
```

**C# parallel:** This pattern mirrors dependency injection or the Template Method design pattern:

```csharp
public abstract class EmailTemplate
{
    protected abstract string CompanyName { get; }
    protected abstract string PrimaryColor { get; }
    protected abstract string RenderContent();

    public sealed string Render() =>
        $"""
        <html>
          <body>
            <div style="background:{PrimaryColor}"><h1>{CompanyName}</h1></div>
            <div>{RenderContent()}</div>
            <div><p>Sent by {CompanyName}</p></div>
          </body>
        </html>
        """;
}
```
