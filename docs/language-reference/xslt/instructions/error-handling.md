---
title: Error Handling
description: "xsl:try/catch, xsl:assert, xsl:fallback — handling errors and asserting conditions"
sort: 12
---

# Error Handling

XSLT 3.0 adds structured error handling to the language. Before 3.0, a runtime error typically terminated the transformation — your only tool was `xsl:message terminate="yes"` to fail intentionally. Now you can catch errors, recover gracefully, and write assertions that validate your data during transformation.

## Contents

- [xsl:try / xsl:catch](#xsltry--xslcatch)
- [Error Variables](#error-variables)
- [Selective Error Catching](#selective-error-catching)
- [xsl:assert](#xslassert)
- [xsl:fallback](#xslfallback)
- [xsl:message with terminate](#xslmessage-with-terminate)
- [Error Recovery Patterns](#error-recovery-patterns)

---

## xsl:try / xsl:catch

`xsl:try` wraps code that might fail. If a dynamic error occurs inside the `xsl:try` body, execution jumps to the `xsl:catch` block instead of terminating the transformation.

### Basic Structure

```xml
<xsl:try>
  <!-- code that might fail -->
  <xsl:catch>
    <!-- recovery code -->
  </xsl:catch>
</xsl:try>
```

### Example: Handling Type Conversion Errors

```xml
<xsl:template match="product">
  <div class="product">
    <h3><xsl:value-of select="name"/></h3>
    <xsl:try>
      <p class="price">$<xsl:value-of select="format-number(number(price), '#,##0.00')"/></p>
      <xsl:catch>
        <p class="price error">Price unavailable</p>
      </xsl:catch>
    </xsl:try>
  </div>
</xsl:template>
```

If `price` contains "TBD" instead of a number, the `number()` conversion fails. Instead of crashing the entire transformation, the catch block produces a fallback message.

**C# parallel:**

```csharp
try
{
    html += $"<p class='price'>${price:N2}</p>";
}
catch (FormatException)
{
    html += "<p class='price error'>Price unavailable</p>";
}
```

### What Can Be Caught

`xsl:try`/`xsl:catch` handles **dynamic errors** — errors that occur during execution:

- Type conversion failures (`xs:integer("abc")`)
- Division by zero
- Invalid function arguments
- Document loading errors (`doc('missing.xml')`)
- `xsl:message terminate="yes"` (the termination becomes a catchable error in XSLT 3.0)
- Errors raised by `error()` function
- Schema validation failures

It does **not** catch:

- Static errors (syntax errors, undeclared variables) — these are compile-time errors
- Type errors from `as` declarations — these are checked before `try` can intervene

### Return Value

`xsl:try` is a sequence constructor — it produces either the result of the try body (if successful) or the result of the catch body (if an error occurred). You can use it anywhere a sequence constructor is allowed, including in variable declarations:

```xml
<xsl:variable name="parsed-date" as="xs:string">
  <xsl:try>
    <xsl:sequence select="format-date(xs:date(@date), '[MNn] [D], [Y]')"/>
    <xsl:catch>
      <xsl:sequence select="string(@date)"/>  <!-- fall back to raw string -->
    </xsl:catch>
  </xsl:try>
</xsl:variable>
```

---

## Error Variables

Inside `xsl:catch`, several variables in the `err` namespace provide information about the error that occurred. You must declare the namespace to use them:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:err="http://www.w3.org/2005/xqt-errors"
                version="3.0">
```

### Available Variables

| Variable | Type | Description |
|----------|------|-------------|
| `$err:code` | `xs:QName` | Error code (e.g., `err:FOAR0002` for division by zero) |
| `$err:description` | `xs:string?` | Human-readable error message |
| `$err:value` | `item()*` | Additional error data (if provided by the error raiser) |
| `$err:module` | `xs:string?` | URI of the stylesheet module where the error occurred |
| `$err:line-number` | `xs:integer?` | Line number where the error occurred |
| `$err:column-number` | `xs:integer?` | Column number where the error occurred |

### Example: Detailed Error Logging

```xml
<xsl:template match="product" xmlns:err="http://www.w3.org/2005/xqt-errors">
  <xsl:try>
    <div class="product">
      <h3><xsl:value-of select="name"/></h3>
      <p>$<xsl:value-of select="format-number(xs:decimal(price), '#,##0.00')"/></p>
      <p>Added: <xsl:value-of select="format-date(xs:date(@added), '[MNn] [D], [Y]')"/></p>
    </div>
    <xsl:catch>
      <div class="product error">
        <h3><xsl:value-of select="name"/></h3>
        <p class="error-message">
          Error processing this product:
          <xsl:value-of select="$err:description"/>
        </p>
        <xsl:message>
          ERROR in product <xsl:value-of select="@id"/>:
          Code: <xsl:value-of select="$err:code"/>
          Description: <xsl:value-of select="$err:description"/>
          Module: <xsl:value-of select="$err:module"/>
          Line: <xsl:value-of select="$err:line-number"/>
        </xsl:message>
      </div>
    </xsl:catch>
  </xsl:try>
</xsl:template>
```

**C# parallel:** The error variables map to exception properties:

```csharp
try { /* ... */ }
catch (Exception ex)
{
    // $err:code       -> ex.GetType().Name or ex.HResult
    // $err:description -> ex.Message
    // $err:value      -> ex.Data
    // $err:module     -> ex.Source
    // $err:line-number -> ex.StackTrace (parsed)
}
```

---

## Selective Error Catching

The `errors` attribute on `xsl:catch` lets you specify which errors to catch. Errors not listed propagate up and terminate the transformation (or are caught by an outer `xsl:try`).

### Catching Specific Error Codes

```xml
<xsl:try>
  <xsl:sequence select="xs:decimal(price)"/>
  <xsl:catch errors="err:FORG0001">
    <!-- Only catch "invalid value for cast" errors -->
    <xsl:sequence select="0"/>
  </xsl:catch>
</xsl:try>
```

### Catching Multiple Error Codes

List multiple error codes separated by spaces:

```xml
<xsl:catch errors="err:FORG0001 err:FOAR0002 err:FODT0002">
  <!-- Handle any of these three error types -->
</xsl:catch>
```

### Catching All Errors in a Namespace

Use a wildcard `*` for the local name:

```xml
<xsl:catch errors="err:*">
  <!-- Catch any standard XPath/XSLT error -->
</xsl:catch>
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `err:FORG0001` | Invalid value for cast/constructor |
| `err:FOAR0002` | Division by zero |
| `err:FODC0002` | Error loading document (doc() / document()) |
| `err:FODT0002` | Overflow/underflow in date/time operation |
| `err:FOTY0012` | Argument to fn:data() is a function item |
| `err:XPTY0004` | Type error (value does not match expected type) |
| `err:XTMM9000` | xsl:message with terminate="yes" |

### Nested Try/Catch

You can nest `xsl:try` blocks for layered error handling:

```xml
<xsl:try>
  <!-- Outer try: catches document loading errors -->
  <xsl:variable name="lookup" select="doc('lookup.xml')"/>

  <xsl:for-each select="//product">
    <xsl:try>
      <!-- Inner try: catches per-product errors -->
      <div class="product">
        <xsl:apply-templates select="."/>
      </div>
      <xsl:catch>
        <div class="product error">
          <p>Error processing <xsl:value-of select="name"/>: <xsl:value-of select="$err:description"/></p>
        </div>
      </xsl:catch>
    </xsl:try>
  </xsl:for-each>

  <xsl:catch errors="err:FODC0002">
    <p class="system-error">Lookup table could not be loaded. Please try again later.</p>
  </xsl:catch>
</xsl:try>
```

**C# parallel:** Nested try/catch with specific exception types:

```csharp
try
{
    var lookup = LoadDocument("lookup.xml");

    foreach (var product in products)
    {
        try
        {
            RenderProduct(product, lookup);
        }
        catch (FormatException ex)
        {
            RenderErrorCard(product, ex.Message);
        }
    }
}
catch (FileNotFoundException)
{
    RenderSystemError("Lookup table could not be loaded.");
}
```

---

## xsl:assert

`xsl:assert` tests a condition and raises an error if the condition is false. It is a declarative way to validate assumptions about your data during transformation.

### Basic Usage

```xml
<xsl:template match="product">
  <xsl:assert test="@id" error-code="Q{http://example.com/err}MISSING-ID">
    Product element must have an @id attribute.
  </xsl:assert>

  <xsl:assert test="price castable as xs:decimal" error-code="Q{http://example.com/err}BAD-PRICE">
    Product <xsl:value-of select="@id"/>: price must be a valid decimal number,
    got '<xsl:value-of select="price"/>'.
  </xsl:assert>

  <!-- If we get here, both assertions passed -->
  <div class="product" data-id="{@id}">
    <xsl:apply-templates/>
  </div>
</xsl:template>
```

### Attributes

| Attribute | Description |
|-----------|-------------|
| `test` | XPath expression that must evaluate to true. If false, the assertion fails and an error is raised. |
| `error-code` | Optional QName for the error code (catchable by `xsl:catch`). Default is `err:XTMM9001`. |
| `select` | Optional expression whose value is attached to the error as `$err:value` in the catch block. |

### The select Attribute

The `select` attribute provides structured data about the assertion failure, accessible as `$err:value` in a catch block:

```xml
<xsl:assert test="price > 0"
            error-code="Q{http://example.com/err}INVALID-PRICE"
            select="map { 'product-id': string(@id), 'price': string(price) }">
  Price must be positive.
</xsl:assert>
```

In a catch block:

```xml
<xsl:catch errors="Q{http://example.com/err}INVALID-PRICE">
  <xsl:variable name="info" select="$err:value"/>
  <p>Product <xsl:value-of select="$info?product-id"/> has invalid price:
     <xsl:value-of select="$info?price"/></p>
</xsl:catch>
```

### Use in Validation Scenarios

`xsl:assert` is powerful for building validation into your transformation:

```xml
<xsl:template match="order">
  <!-- Validate the order before processing -->
  <xsl:assert test="line-item">
    Order <xsl:value-of select="@id"/> has no line items.
  </xsl:assert>

  <xsl:assert test="every $li in line-item satisfies $li/@quantity > 0">
    Order <xsl:value-of select="@id"/> contains line items with invalid quantities.
  </xsl:assert>

  <xsl:assert test="customer-ref and key('customers-by-id', customer-ref)">
    Order <xsl:value-of select="@id"/> references unknown customer
    '<xsl:value-of select="customer-ref"/>'.
  </xsl:assert>

  <!-- Process the validated order -->
  <xsl:apply-templates/>
</xsl:template>
```

**C# parallel:** `Debug.Assert()` or guard clauses:

```csharp
Debug.Assert(order.LineItems.Any(), $"Order {order.Id} has no line items.");

// Or with guard clauses:
if (!order.LineItems.Any())
    throw new ValidationException($"Order {order.Id} has no line items.");
```

The key difference: `xsl:assert` errors can be caught by `xsl:try`/`xsl:catch`, making them recoverable. `Debug.Assert` in C# is typically only active in debug builds.

---

## xsl:fallback

`xsl:fallback` provides a graceful degradation mechanism when a stylesheet uses instructions that the processor does not support. This is primarily useful for forwards compatibility — writing stylesheets that use newer features while still working on older processors.

### Basic Usage

```xml
<xsl:some-future-instruction>
  <!-- This instruction might not exist in the current processor -->
  <xsl:fallback>
    <!-- This runs if the processor does not recognize the parent instruction -->
    <xsl:message>Note: some-future-instruction is not supported. Using fallback.</xsl:message>
    <!-- Alternative implementation -->
  </xsl:fallback>
</xsl:some-future-instruction>
```

### Forwards Compatibility Example

Suppose you want to use a hypothetical XSLT 4.0 instruction but need the stylesheet to work on XSLT 3.0 processors:

```xml
<xsl:stylesheet version="4.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="product">
    <!-- Try to use a 4.0 feature -->
    <xsl:switch select="@status">
      <xsl:when test="'active'">
        <span class="badge-green">Active</span>
      </xsl:when>
      <xsl:when test="'discontinued'">
        <span class="badge-red">Discontinued</span>
      </xsl:when>
      <xsl:fallback>
        <!-- If xsl:switch is not supported, fall back to xsl:choose -->
        <xsl:choose>
          <xsl:when test="@status = 'active'">
            <span class="badge-green">Active</span>
          </xsl:when>
          <xsl:when test="@status = 'discontinued'">
            <span class="badge-red">Discontinued</span>
          </xsl:when>
        </xsl:choose>
      </xsl:fallback>
    </xsl:switch>
  </xsl:template>
</xsl:stylesheet>
```

When a 4.0 processor runs this, it executes `xsl:switch` normally. When a 3.0 processor encounters the unrecognized `xsl:switch`, it sees the stylesheet declares `version="4.0"` (a forwards-compatible version), finds the `xsl:fallback` child, and executes that instead.

### How Forwards Compatibility Works

- If the stylesheet declares a version higher than the processor supports (e.g., `version="4.0"` on a 3.0 processor), the processor enters **forwards-compatible mode**
- In this mode, unrecognized instructions are not immediately an error — the processor looks for `xsl:fallback` children
- If `xsl:fallback` is found, it is executed in place of the unrecognized instruction
- If no `xsl:fallback` is found, a runtime error is raised (which can be caught by `xsl:try`/`xsl:catch`)

### Multiple Fallbacks

You can provide multiple `xsl:fallback` elements — all of them execute if the parent is unsupported:

```xml
<xsl:hypothetical-instruction>
  <xsl:fallback>
    <xsl:message>Using fallback for hypothetical-instruction</xsl:message>
  </xsl:fallback>
  <xsl:fallback>
    <!-- Alternative implementation -->
    <xsl:apply-templates/>
  </xsl:fallback>
</xsl:hypothetical-instruction>
```

**C# parallel:** `xsl:fallback` is conceptually similar to `#if` preprocessor directives or feature detection:

```csharp
#if NET8_0_OR_GREATER
    // Use new API
    var result = SomeNewApi();
#else
    // Fallback for older frameworks
    var result = LegacyApproach();
#endif
```

---

## xsl:message with terminate

Before XSLT 3.0's `xsl:try`/`xsl:catch`, the only way to signal an error was `xsl:message terminate="yes"`. This is still useful and widely used:

### As a Guard Clause

```xml
<xsl:template match="product">
  <xsl:if test="not(@id)">
    <xsl:message terminate="yes">
      FATAL: Product element at position <xsl:value-of select="position()"/>
      is missing required @id attribute.
    </xsl:message>
  </xsl:if>

  <!-- Normal processing continues if the check passed -->
  <div class="product" data-id="{@id}">
    <xsl:apply-templates/>
  </div>
</xsl:template>
```

### With Error Codes (XSLT 3.0)

In XSLT 3.0, `xsl:message terminate="yes"` raises a catchable error. You can assign an error code:

```xml
<xsl:message terminate="yes"
             error-code="Q{http://example.com/err}MISSING-REQUIRED-FIELD">
  Required field '<xsl:value-of select="$field-name"/>' is missing in
  <xsl:value-of select="local-name()"/> element.
</xsl:message>
```

This error can be caught:

```xml
<xsl:try>
  <xsl:apply-templates select="//product"/>
  <xsl:catch errors="Q{http://example.com/err}MISSING-REQUIRED-FIELD">
    <p class="error">Some products have missing data. <xsl:value-of select="$err:description"/></p>
  </xsl:catch>
</xsl:try>
```

### terminate="yes" vs. xsl:assert

| | `xsl:message terminate="yes"` | `xsl:assert` |
|---|---|---|
| **Syntax** | Requires wrapping in `xsl:if` for conditional use | Has a built-in `test` attribute |
| **Message** | Content of the message element | Content of the assert element |
| **Error code** | Via `error-code` attribute | Via `error-code` attribute |
| **Error value** | Not directly supported | Via `select` attribute |
| **Readability** | Two instructions (`xsl:if` + `xsl:message`) | Single instruction |
| **Pre-3.0** | Available since XSLT 1.0 | XSLT 3.0 only |

For validation checks, prefer `xsl:assert` — it is more concise and communicates intent more clearly. Use `xsl:message terminate="yes"` when you need the message to carry complex content or when targeting XSLT 1.0/2.0 compatibility.

---

## Error Recovery Patterns

### Fail-Safe Processing

Process each item independently, catching errors per item so one bad record does not stop the entire transformation:

```xml
<xsl:template match="catalog">
  <html>
    <body>
      <h1>Product Catalog</h1>
      <xsl:for-each select="product">
        <xsl:try>
          <xsl:apply-templates select="."/>
          <xsl:catch>
            <div class="product error-card">
              <h3><xsl:value-of select="(name, @id, 'Unknown')[1]"/></h3>
              <p class="error">This product could not be displayed:
                <xsl:value-of select="$err:description"/></p>
            </div>
          </xsl:catch>
        </xsl:try>
      </xsl:for-each>
    </body>
  </html>
</xsl:template>
```

**C# parallel:** This is the "continue on error" pattern:

```csharp
foreach (var product in products)
{
    try
    {
        RenderProduct(product);
    }
    catch (Exception ex)
    {
        RenderErrorCard(product, ex.Message);
    }
}
```

### Safe Document Loading

Gracefully handle missing or invalid external documents:

```xml
<xsl:function name="my:safe-doc" as="document-node()?">
  <xsl:param name="uri" as="xs:string"/>
  <xsl:try>
    <xsl:sequence select="doc($uri)"/>
    <xsl:catch errors="err:FODC0002">
      <xsl:message>WARNING: Could not load document '<xsl:value-of select="$uri"/>'</xsl:message>
      <xsl:sequence select="()"/>  <!-- return empty sequence -->
    </xsl:catch>
  </xsl:try>
</xsl:function>

<!-- Usage -->
<xsl:variable name="lookup" select="my:safe-doc('lookup-table.xml')"/>
<xsl:if test="$lookup">
  <!-- Document loaded successfully, use it -->
</xsl:if>
```

### Validation with Error Collection

Validate all records and collect errors before deciding how to proceed:

```xml
<xsl:template match="catalog">
  <!-- Collect validation errors -->
  <xsl:variable name="errors" as="element(error)*">
    <xsl:for-each select="product">
      <xsl:if test="not(@id)">
        <error product="{position()}" field="id">Missing @id attribute</error>
      </xsl:if>
      <xsl:if test="not(price castable as xs:decimal)">
        <error product="{@id}" field="price">
          Invalid price: '<xsl:value-of select="price"/>'
        </error>
      </xsl:if>
      <xsl:if test="not(name)">
        <error product="{@id}" field="name">Missing name element</error>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$errors">
      <!-- Show validation report -->
      <html>
        <body>
          <h1>Validation Errors</h1>
          <p><xsl:value-of select="count($errors)"/> error(s) found.</p>
          <table>
            <thead>
              <tr><th>Product</th><th>Field</th><th>Error</th></tr>
            </thead>
            <tbody>
              <xsl:for-each select="$errors">
                <tr>
                  <td><xsl:value-of select="@product"/></td>
                  <td><xsl:value-of select="@field"/></td>
                  <td><xsl:value-of select="."/></td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </body>
      </html>
    </xsl:when>
    <xsl:otherwise>
      <!-- All valid — proceed with normal output -->
      <xsl:apply-templates select="product"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
```

### Default Values with Try/Catch

Use try/catch to provide default values when data is malformed:

```xml
<xsl:function name="my:safe-decimal" as="xs:decimal">
  <xsl:param name="value" as="xs:string"/>
  <xsl:param name="default" as="xs:decimal"/>
  <xsl:try>
    <xsl:sequence select="xs:decimal($value)"/>
    <xsl:catch>
      <xsl:sequence select="$default"/>
    </xsl:catch>
  </xsl:try>
</xsl:function>

<xsl:function name="my:safe-date" as="xs:string">
  <xsl:param name="value" as="xs:string"/>
  <xsl:try>
    <xsl:sequence select="format-date(xs:date($value), '[MNn] [D], [Y]')"/>
    <xsl:catch>
      <xsl:sequence select="$value"/>  <!-- return raw string if unparseable -->
    </xsl:catch>
  </xsl:try>
</xsl:function>

<!-- Usage -->
<xsl:variable name="price" select="my:safe-decimal(price, 0)"/>
<xsl:variable name="display-date" select="my:safe-date(@date)"/>
```

**C# parallel:** `TryParse` pattern:

```csharp
static decimal SafeDecimal(string value, decimal defaultValue) =>
    decimal.TryParse(value, out var result) ? result : defaultValue;
```

### Assertion + Try/Catch for Controlled Validation

Combine assertions with try/catch for a "validate, then process" pattern:

```xml
<xsl:template match="order">
  <xsl:try>
    <!-- Assertions act as preconditions -->
    <xsl:assert test="@id">Order must have an ID.</xsl:assert>
    <xsl:assert test="line-item">Order must have at least one line item.</xsl:assert>
    <xsl:assert test="every $li in line-item satisfies
                       key('products-by-id', $li/@product-ref)">
      All product references must be valid.
    </xsl:assert>

    <!-- If all assertions pass, process normally -->
    <div class="order">
      <xsl:apply-templates/>
    </div>

    <xsl:catch>
      <div class="order rejected">
        <p>Order <xsl:value-of select="@id"/> rejected: <xsl:value-of select="$err:description"/></p>
      </div>
    </xsl:catch>
  </xsl:try>
</xsl:template>
```

**C# parallel summary:**

| XSLT | C# |
|------|-----|
| `xsl:try` / `xsl:catch` | `try` / `catch` |
| `$err:code` | `ex.GetType()` or `ex.HResult` |
| `$err:description` | `ex.Message` |
| `$err:value` | `ex.Data` or custom exception properties |
| `errors="err:FORG0001"` | `catch (FormatException)` |
| `xsl:assert test="..."` | `Debug.Assert(...)` or guard clause with `throw` |
| `xsl:fallback` | `#if` preprocessor / feature detection |
| `xsl:message terminate="yes"` | `throw new Exception(...)` |
| Nested `xsl:try` | Nested `try`/`catch` blocks |
