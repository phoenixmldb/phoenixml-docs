---
title: "Dynamic Evaluation"
description: "xsl:evaluate — runtime XPath evaluation from string expressions"
sort: 17
---

# Dynamic Evaluation

`xsl:evaluate` (XSLT 3.0) compiles and executes an XPath expression provided as a string at runtime. This is the XSLT equivalent of runtime expression compilation in dynamic languages — powerful, occasionally necessary, and something you should use judiciously.

## Contents

- [When You Need Dynamic Evaluation](#when-you-need-dynamic-evaluation)
- [xsl:evaluate — Syntax and Attributes](#xslevaluate--syntax-and-attributes)
- [Binding Variables with xsl:with-param](#binding-variables-with-xslwith-param)
- [Namespace Resolution](#namespace-resolution)
- [Security Considerations](#security-considerations)
- [Use Cases](#use-cases)
- [When Not to Use xsl:evaluate](#when-not-to-use-xslevaluate)

---

## When You Need Dynamic Evaluation

Most XSLT stylesheets use static XPath expressions — expressions written directly in the stylesheet and known at compile time. But some situations require expressions that are not known until runtime:

- **Configurable transforms:** A configuration file specifies which fields to sort by, which elements to extract, or which conditions to apply.
- **Data-driven templates:** An XML schema or metadata file describes the structure, and the stylesheet uses it to generate XPath expressions dynamically.
- **User-defined formulas:** A spreadsheet or report definition contains user-written expressions.
- **Generic tools:** A stylesheet that processes arbitrary XML based on runtime parameters.

**C# parallel:** The need for dynamic evaluation arises in C# too:

```csharp
// Roslyn scripting — compile and run C# at runtime
var result = await CSharpScript.EvaluateAsync<int>("1 + 2 * 3");

// Dynamic LINQ — build queries from strings
var filtered = dataSource.Where("Price > @0", 100);

// Expression trees — runtime query construction
Expression<Func<Product, bool>> predicate = BuildFilter(userInput);
var results = products.Where(predicate.Compile());
```

---

## xsl:evaluate — Syntax and Attributes

### Basic Usage

```xml
<!-- Evaluate a simple expression -->
<xsl:variable name="result" select="xsl:evaluate('1 + 2 * 3')"/>
<!-- result: 7 -->

<!-- Evaluate an expression stored in a variable -->
<xsl:variable name="expr" select="'price * quantity'"/>
<xsl:value-of select="xsl:evaluate($expr)"/>
```

### As an Instruction

`xsl:evaluate` can also be used as an instruction element rather than a function:

```xml
<xsl:evaluate xpath="$sort-expression" context-item="."/>
```

### Attributes

| Attribute | Description | Default |
|-----------|-------------|---------|
| `xpath` | The XPath expression to evaluate (as a string) | Required |
| `as` | Expected return type (like `as` on `xsl:variable`) | `item()*` |
| `context-item` | The context node for the expression (`.`) | Current context |
| `namespace-context` | Element whose in-scope namespaces are used | Stylesheet element |
| `schema-aware` | Whether to use schema type information | `no` |
| `with-param` | Variable bindings (child elements) | None |
| `base-uri` | Base URI for resolving relative URIs | Static base URI |

### Simple Examples

```xml
<!-- Dynamic field access -->
<xsl:param name="field-name" select="'price'"/>
<xsl:value-of select="xsl:evaluate($field-name)"/>
<!-- If context is a product element, returns the value of its price child -->

<!-- Dynamic predicate -->
<xsl:param name="filter" select="'@status = ''active'''"/>
<xsl:for-each select="//product[xsl:evaluate($filter)]">
  <xsl:value-of select="name"/>
</xsl:for-each>

<!-- Dynamic sort key -->
<xsl:param name="sort-by" select="'price'"/>
<xsl:for-each select="//product">
  <xsl:sort select="xsl:evaluate($sort-by)" data-type="number"/>
  <li><xsl:value-of select="name"/></li>
</xsl:for-each>
```

### Specifying Return Type

Use the `as` attribute to constrain the result type:

```xml
<!-- Expect a number -->
<xsl:evaluate xpath="$expression" as="xs:decimal"/>

<!-- Expect a sequence of nodes -->
<xsl:evaluate xpath="$node-selector" as="node()*"/>

<!-- Expect a boolean -->
<xsl:evaluate xpath="$condition" as="xs:boolean"/>
```

If the evaluated expression returns a value that does not match the `as` type, a type error is raised.

---

## Binding Variables with xsl:with-param

Dynamic expressions often need access to values from the surrounding context. Use `xsl:with-param` to bind variables that the expression can reference:

```xml
<xsl:evaluate xpath="$expression">
  <xsl:with-param name="threshold" select="100"/>
  <xsl:with-param name="category" select="$current-category"/>
</xsl:evaluate>
```

The expression can reference these as `$threshold` and `$category`:

```xml
<!-- If $expression is "price > $threshold and @category = $category" -->
<!-- The variables $threshold and $category are available inside the expression -->
```

### Complete Example: Configurable Filtering

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <!-- Configuration passed as parameters -->
  <xsl:param name="filter-expression" select="'price &lt; $max-price'"/>
  <xsl:param name="max-price" select="100"/>
  <xsl:param name="sort-field" select="'name'"/>
  <xsl:param name="sort-order" select="'ascending'"/>

  <xsl:template match="catalog">
    <filtered-catalog>
      <xsl:variable name="filtered" as="element(product)*">
        <xsl:for-each select="product">
          <xsl:variable name="passes-filter" as="xs:boolean">
            <xsl:evaluate xpath="$filter-expression" context-item=".">
              <xsl:with-param name="max-price" select="$max-price"/>
            </xsl:evaluate>
          </xsl:variable>
          <xsl:if test="$passes-filter">
            <xsl:sequence select="."/>
          </xsl:if>
        </xsl:for-each>
      </xsl:variable>

      <xsl:for-each select="$filtered">
        <xsl:sort select="xsl:evaluate($sort-field)" order="{$sort-order}"/>
        <xsl:copy-of select="."/>
      </xsl:for-each>
    </filtered-catalog>
  </xsl:template>

</xsl:stylesheet>
```

---

## Namespace Resolution

When the dynamic expression uses namespace prefixes, the processor needs to know which namespaces are in scope. The `namespace-context` attribute specifies an element whose in-scope namespaces are used for resolving prefixes in the expression.

### Using namespace-context

```xml
<!-- The expression uses the "fn" prefix — we need to tell the evaluator
     which namespace it maps to -->
<xsl:variable name="ns-context" as="element()">
  <dummy xmlns:fn="http://www.w3.org/2005/xpath-functions"
         xmlns:math="http://www.w3.org/2005/xpath-functions/math"/>
</xsl:variable>

<xsl:evaluate xpath="'math:sqrt(fn:sum(//price))'"
              namespace-context="$ns-context"/>
```

If no `namespace-context` is provided, the namespaces from the `xsl:evaluate` element itself are used.

### Practical Pattern: Expressions from a Configuration File

```xml
<!-- config.xml -->
<report-config>
  <column name="Total Revenue" xpath="format-number(sum(//order/@total), '#,##0.00')"
          xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
  <column name="Average Order" xpath="format-number(avg(//order/@total), '#,##0.00')"/>
  <column name="Largest Order" xpath="max(//order/@total)"/>
</report-config>
```

```xml
<xsl:template match="/">
  <xsl:variable name="config" select="doc('config.xml')/report-config"/>
  <xsl:variable name="data" select="doc('orders.xml')"/>

  <table>
    <thead>
      <tr>
        <xsl:for-each select="$config/column">
          <th><xsl:value-of select="@name"/></th>
        </xsl:for-each>
      </tr>
    </thead>
    <tbody>
      <tr>
        <xsl:for-each select="$config/column">
          <td>
            <xsl:evaluate xpath="string(@xpath)"
                          context-item="$data"
                          namespace-context="."/>
          </td>
        </xsl:for-each>
      </tr>
    </tbody>
  </table>
</xsl:template>
```

The `namespace-context="."` ensures that any namespace declarations on the `<column>` elements are available to the evaluated expression.

---

## Security Considerations

`xsl:evaluate` executes arbitrary XPath expressions at runtime. This raises security concerns when the expression comes from untrusted input.

### What an Attacker Can Do

XPath by itself cannot modify the file system or execute system commands. However, an attacker-controlled expression could:

- **Read sensitive data:** `doc('/etc/passwd')` or `doc('file:///C:/secrets/config.xml')`
- **Cause denial of service:** Expressions with exponential complexity, like deeply nested `for` loops
- **Access other documents:** `collection()`, `doc()`, `unparsed-text()` can reach files on the server
- **Exfiltrate data:** If the output goes to the user, sensitive data from other documents could be exposed

### Mitigation Strategies

1. **Never evaluate user-provided expressions directly.** Instead, offer a controlled set of options:

```xml
<!-- DANGEROUS: evaluating user input directly -->
<xsl:evaluate xpath="$user-input"/>

<!-- SAFER: mapping user choices to known expressions -->
<xsl:variable name="allowed-sorts" select="map {
  'name': 'name',
  'price': 'price',
  'date': '@created-date',
  'rating': 'avg(review/@score)'
}"/>

<xsl:variable name="sort-expr"
              select="($allowed-sorts($user-sort-choice), 'name')[1]"/>
<xsl:for-each select="//product">
  <xsl:sort select="xsl:evaluate($sort-expr)"/>
  <!-- ... -->
</xsl:for-each>
```

2. **Disable xsl:evaluate in the processor configuration.** Most XSLT processors allow you to disable `xsl:evaluate` entirely. If your transformation does not need it, turn it off.

3. **Restrict document access.** Configure the processor's URI resolver to limit which documents can be loaded.

4. **Validate expressions before evaluation.** If you must accept dynamic expressions, validate them against an allowlist of functions and axes.

**C# parallel:** The same concerns apply to runtime code compilation and dynamic LINQ:

```csharp
// DANGEROUS: executing arbitrary code
var result = await CSharpScript.EvaluateAsync(userInput);

// SAFER: constrain what the script can access
var options = ScriptOptions.Default
    .WithReferences(typeof(Math).Assembly)
    .WithImports("System.Math");
var result = await CSharpScript.EvaluateAsync<double>(userInput, options);
```

---

## Use Cases

### Configurable Sort Keys

A report definition specifies which columns to sort by:

```xml
<!-- report-definition.xml -->
<report>
  <sort-keys>
    <sort-key xpath="@department" order="ascending"/>
    <sort-key xpath="salary" order="descending" data-type="number"/>
  </sort-keys>
</report>
```

```xml
<xsl:variable name="sort-config"
              select="doc('report-definition.xml')//sort-key"/>

<xsl:template match="employees">
  <table>
    <!-- Dynamic multi-key sort using xsl:evaluate -->
    <xsl:for-each select="employee">
      <!-- Apply first sort key -->
      <xsl:sort select="xsl:evaluate(string($sort-config[1]/@xpath))"
                order="{$sort-config[1]/@order}"
                data-type="{($sort-config[1]/@data-type, 'text')[1]}"/>
      <!-- Apply second sort key -->
      <xsl:sort select="xsl:evaluate(string($sort-config[2]/@xpath))"
                order="{$sort-config[2]/@order}"
                data-type="{($sort-config[2]/@data-type, 'text')[1]}"/>

      <tr>
        <td><xsl:value-of select="name"/></td>
        <td><xsl:value-of select="@department"/></td>
        <td><xsl:value-of select="salary"/></td>
      </tr>
    </xsl:for-each>
  </table>
</xsl:template>
```

### Expression Evaluation in a Spreadsheet

```xml
<!-- spreadsheet.xml -->
<spreadsheet>
  <cell id="A1" value="100"/>
  <cell id="A2" value="200"/>
  <cell id="A3" formula="$A1 + $A2"/>
  <cell id="A4" formula="$A3 * 0.1"/>
</spreadsheet>
```

```xml
<xsl:template match="spreadsheet">
  <results>
    <xsl:for-each select="cell">
      <xsl:choose>
        <xsl:when test="@formula">
          <cell id="{@id}">
            <xsl:evaluate xpath="@formula">
              <!-- Bind cell references as variables -->
              <xsl:for-each select="../cell[@value]">
                <xsl:with-param name="{@id}" select="number(@value)"/>
              </xsl:for-each>
            </xsl:evaluate>
          </cell>
        </xsl:when>
        <xsl:otherwise>
          <cell id="{@id}"><xsl:value-of select="@value"/></cell>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </results>
</xsl:template>
```

### Data-Driven Column Extraction

A metadata file describes which fields to extract from a data file:

```xml
<!-- fields.xml -->
<fields>
  <field label="Customer Name" xpath="customer/name"/>
  <field label="Order Total" xpath="format-number(total, '$#,##0.00')"/>
  <field label="Status" xpath="if (@status = 'C') then 'Complete' else 'Pending'"/>
</fields>
```

```xml
<xsl:variable name="fields" select="doc('fields.xml')//field"/>

<xsl:template match="orders">
  <table>
    <thead>
      <tr>
        <xsl:for-each select="$fields">
          <th><xsl:value-of select="@label"/></th>
        </xsl:for-each>
      </tr>
    </thead>
    <tbody>
      <xsl:for-each select="order">
        <xsl:variable name="current-order" select="."/>
        <tr>
          <xsl:for-each select="$fields">
            <td>
              <xsl:evaluate xpath="string(@xpath)" context-item="$current-order"/>
            </td>
          </xsl:for-each>
        </tr>
      </xsl:for-each>
    </tbody>
  </table>
</xsl:template>
```

---

## When Not to Use xsl:evaluate

`xsl:evaluate` should be a tool of last resort. Before reaching for it, consider these alternatives:

### Static XPath Covers Most Cases

If the expression is known at stylesheet-authoring time, write it directly:

```xml
<!-- Do NOT do this -->
<xsl:variable name="expr" select="'price * quantity'"/>
<xsl:value-of select="xsl:evaluate($expr)"/>

<!-- Do this instead -->
<xsl:value-of select="price * quantity"/>
```

### Use Higher-Order Functions

If you need to pass behavior as a parameter, XSLT 3.0 supports higher-order functions:

```xml
<!-- Instead of passing a string expression for sorting... -->
<xsl:variable name="sort-fn" select="function($item) { $item/price }"/>

<xsl:for-each select="//product">
  <xsl:sort select="$sort-fn(.)"/>
  <!-- ... -->
</xsl:for-each>
```

### Use Template Matching

If different data shapes need different processing, template matching is more maintainable than dynamic evaluation:

```xml
<!-- Instead of evaluating a dynamic expression per type... -->
<xsl:template match="product[@type='physical']">
  <xsl:value-of select="weight * shipping-rate"/>
</xsl:template>

<xsl:template match="product[@type='digital']">
  <xsl:value-of select="0"/>
</xsl:template>
```

### Performance Implications

`xsl:evaluate` compiles the expression at runtime, which is slower than pre-compiled static expressions. In a loop processing thousands of items, this overhead can be significant. If possible, evaluate the expression once and store the result in a variable.

**C# parallel:** This is the same trade-off as `Reflection.Invoke()` vs. direct method calls, or runtime script compilation vs. compiled code. The dynamic version is flexible but slower.
