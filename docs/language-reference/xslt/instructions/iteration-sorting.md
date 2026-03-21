---
title: Iteration and Sorting
description: "xsl:for-each, xsl:sort, xsl:perform-sort, xsl:iterate with break and next-iteration"
sort: 4
---

# Iteration and Sorting

XSLT provides several ways to process sequences of items. The choice between them depends on whether you need ordering, running state, or just simple iteration.

## Contents

- [xsl:for-each](#xslfor-each)
- [xsl:sort](#xslsort)
- [xsl:perform-sort](#xslperform-sort)
- [xsl:iterate](#xsliterate)
- [Choosing the Right Approach](#choosing-the-right-approach)

---

## xsl:for-each

Iterates over a sequence, executing the body once for each item. The current item becomes the context node inside the body.

### Basic Usage

```xml
<xsl:template match="catalog">
  <ul>
    <xsl:for-each select="product">
      <li>
        <xsl:value-of select="name"/> — $<xsl:value-of select="price"/>
      </li>
    </xsl:for-each>
  </ul>
</xsl:template>
```

**C# parallel:** `foreach (var product in catalog.Products) { ... }`

### Context Change

This is the most important thing to understand about `xsl:for-each`: **it changes the context node**. Inside the loop, `.` refers to the current item, not the node that was the context before the loop.

```xml
<xsl:template match="catalog">
  <!-- Here, . is the catalog element -->
  <h1><xsl:value-of select="@name"/></h1>  <!-- catalog's @name -->

  <xsl:for-each select="product">
    <!-- Here, . is a product element -->
    <p><xsl:value-of select="@name"/></p>    <!-- product's @name -->
  </xsl:for-each>
</xsl:template>
```

If you need the outer context inside the loop, save it in a variable before entering:

```xml
<xsl:template match="catalog">
  <xsl:variable name="catalog-name" select="@name"/>

  <xsl:for-each select="product">
    <!-- Use $catalog-name to access the outer context -->
    <p><xsl:value-of select="$catalog-name"/>: <xsl:value-of select="name"/></p>
  </xsl:for-each>
</xsl:template>
```

### position() and last()

Inside `xsl:for-each`, the `position()` and `last()` functions reflect the current iteration:

```xml
<xsl:for-each select="product">
  <tr class="{if (position() mod 2 = 0) then 'even' else 'odd'}">
    <td><xsl:value-of select="position()"/>.</td>
    <td><xsl:value-of select="name"/></td>
    <td>
      <xsl:if test="position() = last()">
        <strong>(Last item)</strong>
      </xsl:if>
    </td>
  </tr>
</xsl:for-each>
```

**C# parallel:**

```csharp
var products = catalog.Products.ToList();
for (int i = 0; i < products.Count; i++)
{
    var isEven = i % 2 == 1; // position() is 1-based
    var isLast = i == products.Count - 1;
    // ...
}
```

### Iterating Over Non-Node Sequences

`xsl:for-each` works on any sequence, not just nodes:

```xml
<!-- Iterate over a sequence of integers -->
<xsl:for-each select="1 to 10">
  <span><xsl:value-of select="."/></span>
</xsl:for-each>

<!-- Iterate over tokenized string -->
<xsl:for-each select="tokenize(@categories, ',')">
  <span class="tag"><xsl:value-of select="."/></span>
</xsl:for-each>

<!-- Iterate over map entries -->
<xsl:variable name="colors" select="map { 'error': 'red', 'warning': 'orange', 'info': 'blue' }"/>
<xsl:for-each select="map:keys($colors)">
  <div style="color: {map:get($colors, .)}"><xsl:value-of select="."/></div>
</xsl:for-each>
```

---

## xsl:sort

Controls the order in which items are processed. `xsl:sort` appears as a child of `xsl:for-each` or `xsl:apply-templates`, before any other content.

### Basic Sorting

```xml
<!-- Sort products by name alphabetically -->
<xsl:for-each select="product">
  <xsl:sort select="name"/>
  <li><xsl:value-of select="name"/></li>
</xsl:for-each>

<!-- Sort by price, highest first -->
<xsl:for-each select="product">
  <xsl:sort select="price" data-type="number" order="descending"/>
  <li><xsl:value-of select="name"/> — $<xsl:value-of select="price"/></li>
</xsl:for-each>
```

**C# parallel:** `products.OrderBy(p => p.Name)` and `products.OrderByDescending(p => p.Price)`

### Sort Attributes

| Attribute | Values | Default | Description |
|-----------|--------|---------|-------------|
| `select` | XPath expression | `.` (string value of context) | The sort key |
| `order` | `ascending`, `descending` | `ascending` | Sort direction |
| `data-type` | `text`, `number` | `text` | How to compare values |
| `collation` | URI | Default collation | Locale-aware string comparison |
| `stable` | `yes`, `no` | `yes` | Preserve original order of equal items |
| `lang` | Language code | System default | Language for string sorting |
| `case-order` | `upper-first`, `lower-first` | Collation-dependent | Whether uppercase sorts before lowercase |

### The data-type Gotcha

This is a common mistake. Without `data-type="number"`, prices sort as strings:

```xml
<!-- WRONG: string sort puts "9.99" after "29.99" because "9" > "2" -->
<xsl:sort select="price"/>
<!-- Result: 109.99, 29.99, 9.99 (alphabetical!) -->

<!-- RIGHT: numeric sort -->
<xsl:sort select="price" data-type="number"/>
<!-- Result: 9.99, 29.99, 109.99 -->
```

**C# parallel:** This is like sorting strings vs. sorting parsed numbers:

```csharp
// Wrong (string sort): "109.99", "29.99", "9.99"
items.OrderBy(x => x.Price.ToString());

// Right (numeric sort): 9.99, 29.99, 109.99
items.OrderBy(x => x.Price);
```

### Multiple Sort Keys

Add multiple `xsl:sort` children for multi-level sorting. They are applied in order — the first is the primary key, the second is the tiebreaker, etc.

```xml
<!-- Sort by category, then by price within each category -->
<xsl:for-each select="product">
  <xsl:sort select="@category"/>
  <xsl:sort select="price" data-type="number"/>
  <li>
    [<xsl:value-of select="@category"/>]
    <xsl:value-of select="name"/> — $<xsl:value-of select="price"/>
  </li>
</xsl:for-each>
```

**C# parallel:** `products.OrderBy(p => p.Category).ThenBy(p => p.Price)`

### Sorting with apply-templates

`xsl:sort` also works inside `xsl:apply-templates`:

```xml
<xsl:apply-templates select="product">
  <xsl:sort select="name"/>
</xsl:apply-templates>
```

This applies templates to the products in alphabetical order by name, regardless of their document order.

### Collation-Aware Sorting

For locale-sensitive sorting (accented characters, language-specific rules):

```xml
<xsl:for-each select="product">
  <xsl:sort select="name" collation="http://www.w3.org/2013/collation/UCA?lang=de"/>
  <li><xsl:value-of select="name"/></li>
</xsl:for-each>
```

**C# parallel:** `products.OrderBy(p => p.Name, StringComparer.Create(new CultureInfo("de-DE"), false))`

---

## xsl:perform-sort

Sorts a sequence and returns the sorted result — without iterating over it. This is useful when you need a sorted sequence as input to a function or variable, rather than for immediate output.

```xml
<!-- Sort products by price and store the sorted sequence -->
<xsl:variable name="by-price" as="element(product)*">
  <xsl:perform-sort select="//product">
    <xsl:sort select="price" data-type="number"/>
  </xsl:perform-sort>
</xsl:variable>

<!-- Now use the sorted sequence -->
<p>Cheapest: <xsl:value-of select="$by-price[1]/name"/></p>
<p>Most expensive: <xsl:value-of select="$by-price[last()]/name"/></p>
```

### Using with Functions

```xml
<xsl:function name="my:top-products" as="element(product)*">
  <xsl:param name="products" as="element(product)*"/>
  <xsl:param name="count" as="xs:integer"/>

  <xsl:variable name="sorted" as="element(product)*">
    <xsl:perform-sort select="$products">
      <xsl:sort select="price" data-type="number" order="descending"/>
    </xsl:perform-sort>
  </xsl:variable>

  <xsl:sequence select="subsequence($sorted, 1, $count)"/>
</xsl:function>

<!-- Usage: top 5 most expensive products -->
<xsl:for-each select="my:top-products(//product, 5)">
  <li><xsl:value-of select="name"/> — $<xsl:value-of select="price"/></li>
</xsl:for-each>
```

**C# parallel:** `xsl:perform-sort` is like LINQ's `.OrderBy()` returning an `IOrderedEnumerable` that you can pass to other methods:

```csharp
var sorted = products.OrderByDescending(p => p.Price).ToList();
var topFive = sorted.Take(5);
```

---

## xsl:iterate

`xsl:iterate` (XSLT 3.0) is the functional alternative to `xsl:for-each` when you need **running state** — a value that accumulates across iterations. It replaces the common imperative pattern of a `foreach` loop with a mutable variable.

### The Problem xsl:iterate Solves

In C#, you might write:

```csharp
decimal runningTotal = 0;
foreach (var product in products)
{
    runningTotal += product.Price;
    Console.WriteLine($"{product.Name}: ${product.Price} (Running total: ${runningTotal})");
}
```

In XSLT, `xsl:for-each` cannot do this because variables are immutable — there is no way to update a counter between iterations.

### Basic Structure

```xml
<xsl:iterate select="//product">
  <!-- Parameters are the "mutable state" — re-bound on each iteration -->
  <xsl:param name="running-total" as="xs:decimal" select="0"/>
  <xsl:param name="item-number" as="xs:integer" select="0"/>

  <!-- Body: process the current item, using the parameters -->
  <tr>
    <td><xsl:value-of select="$item-number + 1"/></td>
    <td><xsl:value-of select="name"/></td>
    <td>$<xsl:value-of select="format-number(price, '#,##0.00')"/></td>
    <td>$<xsl:value-of select="format-number($running-total + price, '#,##0.00')"/></td>
  </tr>

  <!-- Pass updated values to the next iteration -->
  <xsl:next-iteration>
    <xsl:with-param name="running-total" select="$running-total + price"/>
    <xsl:with-param name="item-number" select="$item-number + 1"/>
  </xsl:next-iteration>
</xsl:iterate>
```

**C# parallel:** `Enumerable.Aggregate()`:

```csharp
products.Aggregate(
    (total: 0m, num: 0),
    (state, product) => {
        var newTotal = state.total + product.Price;
        Console.WriteLine($"{state.num + 1}. {product.Name}: ${product.Price} (Total: ${newTotal})");
        return (newTotal, state.num + 1);
    }
);
```

### xsl:on-completion

Code inside `xsl:on-completion` runs after the last item is processed. The parameters hold their final values:

```xml
<xsl:iterate select="//product">
  <xsl:param name="total" as="xs:decimal" select="0"/>
  <xsl:param name="count" as="xs:integer" select="0"/>

  <tr>
    <td><xsl:value-of select="name"/></td>
    <td>$<xsl:value-of select="price"/></td>
  </tr>

  <xsl:next-iteration>
    <xsl:with-param name="total" select="$total + price"/>
    <xsl:with-param name="count" select="$count + 1"/>
  </xsl:next-iteration>

  <xsl:on-completion>
    <tr class="summary">
      <td>Total (<xsl:value-of select="$count"/> items)</td>
      <td>$<xsl:value-of select="format-number($total, '#,##0.00')"/></td>
    </tr>
  </xsl:on-completion>
</xsl:iterate>
```

### xsl:break

Terminates the iteration early. This is the XSLT equivalent of C#'s `break` statement:

```xml
<!-- Find the first product over $100 and stop -->
<xsl:iterate select="//product">
  <xsl:sort select="price" data-type="number"/>

  <xsl:choose>
    <xsl:when test="price > 100">
      <p>First product over $100: <xsl:value-of select="name"/></p>
      <xsl:break/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:next-iteration/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:iterate>
```

`xsl:break` can also carry parameter values to `xsl:on-completion`:

```xml
<xsl:iterate select="//product">
  <xsl:param name="processed" as="xs:integer" select="0"/>

  <xsl:if test="$processed ge 10">
    <xsl:break>
      <xsl:with-param name="processed" select="$processed"/>
    </xsl:break>
  </xsl:if>

  <!-- Process the item -->
  <li><xsl:value-of select="name"/></li>

  <xsl:next-iteration>
    <xsl:with-param name="processed" select="$processed + 1"/>
  </xsl:next-iteration>

  <xsl:on-completion>
    <p>Processed <xsl:value-of select="$processed"/> products.</p>
  </xsl:on-completion>
</xsl:iterate>
```

### Practical Example: Paginated Output

```xml
<!-- Output products in pages of 10 -->
<xsl:iterate select="//product">
  <xsl:param name="page-number" as="xs:integer" select="1"/>
  <xsl:param name="item-on-page" as="xs:integer" select="0"/>

  <!-- Start a new page div when needed -->
  <xsl:if test="$item-on-page = 0">
    <xsl:if test="$page-number > 1">
      <!-- Close previous page -->
      <xsl:text disable-output-escaping="yes">&lt;/div&gt;</xsl:text>
    </xsl:if>
    <xsl:text disable-output-escaping="yes">&lt;div class="page"&gt;</xsl:text>
    <h2>Page <xsl:value-of select="$page-number"/></h2>
  </xsl:if>

  <div class="product">
    <xsl:value-of select="name"/>
  </div>

  <xsl:next-iteration>
    <xsl:with-param name="item-on-page"
                    select="if ($item-on-page = 9) then 0 else $item-on-page + 1"/>
    <xsl:with-param name="page-number"
                    select="if ($item-on-page = 9) then $page-number + 1 else $page-number"/>
  </xsl:next-iteration>

  <xsl:on-completion>
    <xsl:text disable-output-escaping="yes">&lt;/div&gt;</xsl:text>
  </xsl:on-completion>
</xsl:iterate>
```

Note: The paginated output example above uses `disable-output-escaping` as a pragmatic workaround. A cleaner approach would be to build the page structure using `xsl:for-each-group` with positional grouping — see the [Grouping](grouping.md) page.

---

## Choosing the Right Approach

| Scenario | Use | Why |
|----------|-----|-----|
| Simple iteration, each item independent | `xsl:for-each` | Simplest, no state needed |
| Processing different node types polymorphically | `xsl:apply-templates` | Pattern matching is more extensible |
| Need a running total or counter | `xsl:iterate` | Parameters carry state between iterations |
| Need to stop early | `xsl:iterate` with `xsl:break` | `for-each` processes all items |
| Need sorted output | `xsl:for-each` + `xsl:sort` | Simple and direct |
| Need a sorted sequence for further processing | `xsl:perform-sort` | Returns sorted sequence without iterating |
| Processing nodes that might have override templates | `xsl:apply-templates` | Allows template specialization |

### for-each vs. apply-templates

This is a common design question. The short answer:

- **`xsl:for-each`** — when you control the rendering inline and the processing logic is local to one template
- **`xsl:apply-templates`** — when you want polymorphic dispatch (different templates for different node types) or when other stylesheets might override the processing

```xml
<!-- for-each: self-contained, simple -->
<xsl:template match="catalog">
  <ul>
    <xsl:for-each select="product">
      <li><xsl:value-of select="name"/></li>
    </xsl:for-each>
  </ul>
</xsl:template>

<!-- apply-templates: extensible, polymorphic -->
<xsl:template match="catalog">
  <ul>
    <xsl:apply-templates select="product"/>
  </ul>
</xsl:template>

<xsl:template match="product">
  <li><xsl:value-of select="name"/></li>
</xsl:template>

<!-- A different stylesheet could override just the product template -->
<xsl:template match="product[@featured='true']">
  <li class="featured"><strong><xsl:value-of select="name"/></strong></li>
</xsl:template>
```

**C# parallel:** `for-each` is like writing logic inline. `apply-templates` is like calling a virtual method — derived classes (imported stylesheets) can override the behavior.
