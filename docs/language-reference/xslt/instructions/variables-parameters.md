---
title: Variables and Parameters
description: "xsl:variable, xsl:param, static parameters, tunnel parameters, with-param"
sort: 3
---

# Variables and Parameters

Variables and parameters in XSLT look similar to their C# counterparts but behave differently in one critical way: **XSLT variables are immutable**. Once set, a variable's value cannot be changed. This is functional programming — you build new values instead of mutating existing ones.

## Contents

- [xsl:variable](#xslvariable)
- [xsl:param](#xslparam)
- [xsl:with-param](#xslwith-param)
- [Static Parameters](#static-parameters)
- [Tunnel Parameters](#tunnel-parameters)
- [Variable Scope and Shadowing](#variable-scope-and-shadowing)
- [Working with Immutable Variables](#working-with-immutable-variables)

---

## xsl:variable

Declares a variable — a named, immutable value.

### Using select (Simple Values)

```xml
<xsl:variable name="tax-rate" select="0.08"/>
<xsl:variable name="product-name" select="name"/>
<xsl:variable name="total" select="price * (1 + $tax-rate)"/>
<xsl:variable name="all-products" select="//product"/>
```

The `select` attribute evaluates an XPath expression and binds the result to the variable name.

### Using Content (Constructing Nodes)

When you need to build a temporary tree (a document fragment), use the content form:

```xml
<xsl:variable name="product-card">
  <div class="card">
    <h3><xsl:value-of select="name"/></h3>
    <p>$<xsl:value-of select="price"/></p>
  </div>
</xsl:variable>

<!-- Use it later -->
<xsl:copy-of select="$product-card"/>
```

**Important:** When you use the content form without an `as` attribute, the variable holds a *temporary tree* (document node). You can read from it, but nodes in it are detached from the original document — they have no parent, no siblings, and no relationship to the source tree.

### The as Attribute (Typing)

The `as` attribute declares the expected type. This is optional but recommended for clarity and early error detection:

```xml
<xsl:variable name="price" as="xs:decimal" select="price"/>
<xsl:variable name="product-names" as="xs:string*" select="//product/name"/>
<xsl:variable name="active" as="xs:boolean" select="@status = 'active'"/>
<xsl:variable name="items" as="element(product)*" select="//product[@category = 'electronics']"/>
```

If the actual value does not match the declared type, the processor raises a type error — similar to a compile-time error in C#.

**C# parallel:**

| XSLT | C# |
|------|-----|
| `<xsl:variable name="x" select="42"/>` | `var x = 42;` |
| `<xsl:variable name="x" as="xs:integer" select="42"/>` | `int x = 42;` |
| Content form (temporary tree) | `var fragment = new XDocument(...)` |

### select vs. Content: When to Use Which

| Scenario | Use |
|----------|-----|
| Simple value (string, number, boolean) | `select` attribute |
| Node reference from source document | `select` attribute |
| Computed XPath expression | `select` attribute |
| Constructing new XML nodes | Content form |
| Multi-step construction with conditionals | Content form |

---

## xsl:param

Declares a parameter — a variable whose value can be supplied by the caller. Parameters appear in three places:

### Template Parameters

```xml
<xsl:template match="product">
  <xsl:param name="show-price" as="xs:boolean" select="true()"/>
  <xsl:param name="currency" as="xs:string" select="'USD'"/>

  <div class="product">
    <h3><xsl:value-of select="name"/></h3>
    <xsl:if test="$show-price">
      <p><xsl:value-of select="$currency"/>
         <xsl:text> </xsl:text>
         <xsl:value-of select="format-number(price, '#,##0.00')"/></p>
    </xsl:if>
  </div>
</xsl:template>
```

The `select` attribute provides a default value. If the caller does not pass the parameter, the default is used.

**C# parallel:** Method parameters with default values:

```csharp
void RenderProduct(Product p, bool showPrice = true, string currency = "USD") { ... }
```

### Required Parameters

Use `required="yes"` to force the caller to supply a value:

```xml
<xsl:template name="format-currency">
  <xsl:param name="amount" as="xs:decimal" required="yes"/>
  <xsl:param name="currency" as="xs:string" required="yes"/>

  <xsl:value-of select="concat($currency, ' ', format-number($amount, '#,##0.00'))"/>
</xsl:template>
```

If the caller omits a required parameter, the processor raises an error. This is equivalent to a C# method parameter without a default value.

### Stylesheet Parameters (Global)

Parameters declared as children of `xsl:stylesheet` are global — they can be set by the calling application:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <xsl:param name="output-format" as="xs:string" select="'html'"/>
  <xsl:param name="debug" as="xs:boolean" select="false()"/>
  <xsl:param name="base-url" as="xs:string" select="'https://example.com'"/>

  <!-- These can be set from C#: -->
  <!-- transformer.SetParameter("output-format", "pdf"); -->
  <!-- transformer.SetParameter("debug", true); -->
</xsl:stylesheet>
```

**C# parallel:** Stylesheet parameters are like dependency injection — the calling code provides configuration values that the stylesheet uses.

```csharp
// In C#, setting XSLT parameters:
var transformer = new XslCompiledTransform();
transformer.Load("catalog.xslt");
var args = new XsltArgumentList();
args.AddParam("output-format", "", "pdf");
args.AddParam("debug", "", true);
transformer.Transform(input, args, output);
```

---

## xsl:with-param

Passes a parameter value when calling a template or applying templates.

### With call-template

```xml
<xsl:call-template name="format-currency">
  <xsl:with-param name="amount" select="price"/>
  <xsl:with-param name="currency" select="'EUR'"/>
</xsl:call-template>
```

### With apply-templates

```xml
<xsl:apply-templates select="product">
  <xsl:with-param name="show-price" select="false()"/>
  <xsl:with-param name="currency" select="'GBP'"/>
</xsl:apply-templates>
```

### Content Form

Like `xsl:variable`, you can use content instead of `select`:

```xml
<xsl:apply-templates select="product">
  <xsl:with-param name="header">
    <h2>Featured Products</h2>
  </xsl:with-param>
</xsl:apply-templates>
```

**C# parallel:** Named arguments in method calls:

```csharp
RenderProduct(product, showPrice: false, currency: "GBP");
```

---

## Static Parameters

XSLT 3.0 introduces static parameters with `static="yes"`. These are evaluated at compile time, enabling conditional compilation.

```xml
<xsl:param name="debug" as="xs:boolean" select="false()" static="yes"/>
<xsl:param name="edition" as="xs:string" select="'standard'" static="yes"/>
```

### Compile-Time Conditional: use-when

Static parameters are primarily used with the `use-when` attribute, which conditionally includes or excludes declarations at compile time:

```xml
<xsl:param name="debug" as="xs:boolean" select="false()" static="yes"/>

<!-- This template only exists when debug is true -->
<xsl:template match="product" use-when="$debug">
  <xsl:message select="concat('Processing product: ', @id)"/>
  <xsl:next-match/>
</xsl:template>

<!-- Include verbose error checking only in debug mode -->
<xsl:template match="product[not(@id)]" use-when="$debug">
  <xsl:message terminate="yes">Product missing @id attribute!</xsl:message>
</xsl:template>
```

### Feature Toggles

```xml
<xsl:param name="enable-analytics" as="xs:boolean" select="false()" static="yes"/>
<xsl:param name="theme" as="xs:string" select="'light'" static="yes"/>

<xsl:template match="/">
  <html>
    <head>
      <!-- Conditionally include analytics script -->
      <script src="analytics.js" use-when="$enable-analytics"/>
    </head>
    <body class="{$theme}-theme">
      <xsl:apply-templates/>
    </body>
  </html>
</xsl:template>
```

**C# parallel:** `#if DEBUG` / `#if FEATURE_FLAG` preprocessor directives, or feature flags evaluated at startup:

```csharp
#if DEBUG
    Console.WriteLine($"Processing product: {product.Id}");
#endif
```

**Key difference:** Static parameters are resolved when the stylesheet is compiled, not when it runs. Changing a static parameter requires recompiling the stylesheet.

---

## Tunnel Parameters

Tunnel parameters solve a problem that every deep call chain creates: how do you pass a value through multiple layers of templates without adding the parameter to every intermediate template?

### The Problem

Without tunnel parameters, passing a value through a deep template chain requires every template in the chain to declare and forward the parameter:

```xml
<!-- Without tunneling: every template must explicitly forward the parameter -->
<xsl:template match="catalog">
  <xsl:param name="currency"/>
  <xsl:apply-templates select="category">
    <xsl:with-param name="currency" select="$currency"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="category">
  <xsl:param name="currency"/>  <!-- must declare even though it doesn't use it -->
  <xsl:apply-templates select="product">
    <xsl:with-param name="currency" select="$currency"/>  <!-- must forward -->
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="product">
  <xsl:param name="currency"/>  <!-- finally gets to use it -->
  <span><xsl:value-of select="concat($currency, ' ', price)"/></span>
</xsl:template>
```

### The Solution

With `tunnel="yes"`, intermediate templates do not need to know about the parameter:

```xml
<!-- With tunneling: only the sender and receiver mention it -->
<xsl:template match="catalog">
  <xsl:apply-templates select="category">
    <xsl:with-param name="currency" select="'EUR'" tunnel="yes"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="category">
  <!-- No mention of currency here — it tunnels through automatically -->
  <div class="category">
    <h2><xsl:value-of select="name"/></h2>
    <xsl:apply-templates select="product"/>
  </div>
</xsl:template>

<xsl:template match="product">
  <xsl:param name="currency" tunnel="yes"/>  <!-- receives the tunneled value -->
  <span><xsl:value-of select="concat($currency, ' ', price)"/></span>
</xsl:template>
```

The `currency` parameter passes invisibly through the `category` template.

### Rules

- The sender must specify `tunnel="yes"` on `xsl:with-param`
- The receiver must specify `tunnel="yes"` on `xsl:param`
- Intermediate templates do not need to declare or forward the parameter
- Tunnel parameters and regular parameters are separate — you can have a tunnel parameter and a regular parameter with the same name
- Tunnel parameters propagate through `xsl:apply-templates` and `xsl:call-template`

**C# parallel:** Tunnel parameters are conceptually similar to:

- **Ambient context / AsyncLocal:** Values that flow through the call stack without explicit passing (`AsyncLocal<T>`, `HttpContext.Current`)
- **Dependency injection:** Services injected deep in the call chain without intermediate classes knowing about them
- **React Context / Angular Services:** For web developers, tunnel parameters work like React's Context API

```csharp
// C# ambient context (similar concept)
public static class CurrencyContext
{
    private static readonly AsyncLocal<string> _currency = new();
    public static string Currency
    {
        get => _currency.Value ?? "USD";
        set => _currency.Value = value;
    }
}
```

---

## Variable Scope and Shadowing

### Scope

Variables are visible from their declaration to the end of their enclosing block:

```xml
<xsl:template match="product">
  <!-- $name is visible from here to the end of the template -->
  <xsl:variable name="name" select="name"/>

  <xsl:if test="@on-sale = 'true'">
    <!-- $discount is only visible inside this xsl:if -->
    <xsl:variable name="discount" select="@discount"/>
    <span>Sale: <xsl:value-of select="$discount"/>% off</span>
  </xsl:if>

  <!-- $discount is NOT visible here — it is out of scope -->
  <p><xsl:value-of select="$name"/></p>
</xsl:template>
```

**C# parallel:** Block scoping — variables declared inside `{ }` are not visible outside.

### Shadowing

You can declare a variable with the same name as an outer variable. The inner declaration shadows the outer one:

```xml
<xsl:variable name="label" select="'default'"/>

<xsl:for-each select="product">
  <!-- This shadows the outer $label -->
  <xsl:variable name="label" select="name"/>
  <span><xsl:value-of select="$label"/></span>  <!-- uses the inner $label -->
</xsl:for-each>

<!-- Back to the outer $label -->
<p><xsl:value-of select="$label"/></p>  <!-- "default" -->
```

**Note:** Shadowing is legal but can be confusing. Many XSLT processors emit warnings for shadowed variables.

### Top-Level vs. Local Variables

Variables declared as children of `xsl:stylesheet` are global:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <!-- Global variable — visible in all templates -->
  <xsl:variable name="site-title" select="'Product Catalog'"/>
  <xsl:variable name="product-count" select="count(//product)"/>

  <xsl:template match="/">
    <h1><xsl:value-of select="$site-title"/></h1>
    <p><xsl:value-of select="$product-count"/> products</p>
  </xsl:template>
</xsl:stylesheet>
```

Global variables are evaluated lazily — they are computed the first time they are referenced.

---

## Working with Immutable Variables

Coming from C#, the biggest adjustment is that you cannot reassign variables. There is no `$counter = $counter + 1`. Here are the patterns that replace mutable state.

### Pattern 1: Compute Everything in One Expression

Instead of building a value incrementally, compute it in a single XPath expression:

```xml
<!-- C# thinking (won't work in XSLT):
     var total = 0;
     foreach (var p in products) total += p.Price;
-->

<!-- XSLT: compute in one expression -->
<xsl:variable name="total" select="sum(//product/price)"/>
<xsl:variable name="avg" select="avg(//product/price)"/>
<xsl:variable name="expensive" select="//product[price > 100]"/>
```

### Pattern 2: Chained Variables

When you need multi-step computation, use a chain of variables where each builds on the previous:

```xml
<xsl:variable name="raw-price" select="price"/>
<xsl:variable name="discounted" select="$raw-price * (1 - @discount div 100)"/>
<xsl:variable name="with-tax" select="$discounted * 1.08"/>
<xsl:variable name="formatted" select="format-number($with-tax, '$#,##0.00')"/>

<span class="price"><xsl:value-of select="$formatted"/></span>
```

**C# parallel:** This is like a LINQ pipeline or a series of `let` clauses:

```csharp
var formatted = product.Price
    .Apply(p => p * (1 - product.Discount / 100m))
    .Apply(p => p * 1.08m)
    .Apply(p => p.ToString("$#,##0.00"));
```

### Pattern 3: xsl:iterate for Running Totals

When you genuinely need a running accumulator (like a `foreach` with mutable state), use `xsl:iterate`:

```xml
<!-- Running total of prices -->
<xsl:iterate select="//product">
  <xsl:param name="running-total" as="xs:decimal" select="0"/>

  <tr>
    <td><xsl:value-of select="name"/></td>
    <td><xsl:value-of select="price"/></td>
    <td><xsl:value-of select="$running-total + price"/></td>
  </tr>

  <xsl:next-iteration>
    <xsl:with-param name="running-total" select="$running-total + price"/>
  </xsl:next-iteration>
</xsl:iterate>
```

See [Iteration and Sorting](iteration-sorting.md) for full coverage of `xsl:iterate`.

### Pattern 4: Recursive Functions

For algorithms that need mutable state in C#, XSLT uses recursion:

```xml
<xsl:function name="my:factorial" as="xs:integer">
  <xsl:param name="n" as="xs:integer"/>
  <xsl:sequence select="if ($n le 1) then 1 else $n * my:factorial($n - 1)"/>
</xsl:function>
```

**C# parallel:** `const` and `readonly` — XSLT variables are conceptually `const`. You never reassign them; you create new ones.
