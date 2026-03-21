---
title: Keys and Cross-References
description: "xsl:key — indexing documents for fast lookup with key() function"
sort: 10
---

# Keys and Cross-References

`xsl:key` defines an index over a document — a precomputed lookup structure that the `key()` function uses for fast retrieval. If you have ever added an index to a database column to speed up queries, you already understand the concept. Keys turn O(n) linear scans into O(1) hash lookups.

## Contents

- [xsl:key](#xslkey)
- [The key() Function](#the-key-function)
- [How Keys Work](#how-keys-work)
- [Composite Keys](#composite-keys)
- [Cross-Document Lookups](#cross-document-lookups)
- [Common Patterns](#common-patterns)
- [Performance](#performance)

---

## xsl:key

A key is a top-level declaration that defines three things: a name, which nodes to index, and what value to index them by.

```xml
<xsl:key name="products-by-id" match="product" use="@id"/>
```

This says: "For every `product` element, index it by its `@id` attribute. Call this index `products-by-id`."

### Attributes

| Attribute | Description |
|-----------|-------------|
| `name` | The name you use to look up values with the `key()` function |
| `match` | A pattern that selects which nodes to index (like `xsl:template match`) |
| `use` | An XPath expression evaluated for each matched node — produces the key value(s) |
| `composite` | `yes` or `no` (XSLT 3.0). When `yes`, `use` is a sequence of values that together form a compound key |
| `collation` | URI of a collation for string comparison |

### Basic Examples

```xml
<!-- Index products by ID -->
<xsl:key name="products-by-id" match="product" use="@id"/>

<!-- Index products by category -->
<xsl:key name="products-by-category" match="product" use="@category"/>

<!-- Index employees by department -->
<xsl:key name="staff-by-dept" match="employee" use="department"/>

<!-- Index elements by their name (for generic processing) -->
<xsl:key name="elements-by-name" match="*" use="local-name()"/>
```

---

## The key() Function

`key()` retrieves nodes from an index. It takes two or three arguments:

```
key(key-name, key-value)
key(key-name, key-value, document)
```

### Basic Lookup

```xml
<xsl:key name="products-by-id" match="product" use="@id"/>

<!-- Look up a single product -->
<xsl:value-of select="key('products-by-id', 'WP-001')/name"/>
<!-- Returns: Widget Pro -->

<!-- Look up with a dynamic value -->
<xsl:variable name="referenced-product"
              select="key('products-by-id', @product-ref)"/>
```

### Multiple Values

You can pass a sequence of key values. The function returns all nodes matching any of the values:

```xml
<!-- Look up multiple products at once -->
<xsl:variable name="featured"
              select="key('products-by-id', ('WP-001', 'WP-002', 'WP-005'))"/>

<!-- Look up products in a list of categories -->
<xsl:variable name="selected-categories" select="('electronics', 'books')"/>
<xsl:for-each select="key('products-by-category', $selected-categories)">
  <li><xsl:value-of select="name"/></li>
</xsl:for-each>
```

### Using key() in Templates

A typical use is resolving references — one element references another by ID:

```xml
<!-- Source data with references -->
<catalog>
  <product id="WP-001">
    <name>Widget Pro</name>
    <price>29.99</price>
  </product>
  <product id="WP-002">
    <name>Gadget Plus</name>
    <price>49.99</price>
  </product>

  <order id="ORD-100">
    <line-item product-ref="WP-001" quantity="3"/>
    <line-item product-ref="WP-002" quantity="1"/>
  </order>
</catalog>
```

```xml
<xsl:key name="products-by-id" match="product" use="@id"/>

<xsl:template match="order">
  <div class="order">
    <h2>Order <xsl:value-of select="@id"/></h2>
    <table>
      <thead>
        <tr><th>Product</th><th>Price</th><th>Qty</th><th>Subtotal</th></tr>
      </thead>
      <tbody>
        <xsl:for-each select="line-item">
          <xsl:variable name="product" select="key('products-by-id', @product-ref)"/>
          <tr>
            <td><xsl:value-of select="$product/name"/></td>
            <td>$<xsl:value-of select="format-number($product/price, '#,##0.00')"/></td>
            <td><xsl:value-of select="@quantity"/></td>
            <td>$<xsl:value-of select="format-number($product/price * @quantity, '#,##0.00')"/></td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </div>
</xsl:template>
```

**C# parallel:**

```csharp
// Build a lookup
var productsById = catalog.Products.ToDictionary(p => p.Id);

// Resolve a reference
var product = productsById[lineItem.ProductRef];
```

---

## How Keys Work

When you first call `key()` for a given key name and document, the XSLT processor builds an in-memory index:

1. It scans the document for all nodes matching the `match` pattern
2. For each matched node, it evaluates the `use` expression to get the key value(s)
3. It stores a mapping from each key value to the matching node(s) in a hash table

Subsequent `key()` calls with the same key name and document reuse this index — the lookup is a hash table get, not a document scan.

### Key Lookup vs. Predicate Filtering

Consider finding all products in the "electronics" category:

```xml
<!-- Without keys: linear scan every time -->
<xsl:for-each select="//product[@category = 'electronics']">
  <!-- The processor must check every product element -->
</xsl:for-each>

<!-- With keys: hash lookup -->
<xsl:key name="products-by-category" match="product" use="@category"/>
<xsl:for-each select="key('products-by-category', 'electronics')">
  <!-- The processor jumps directly to the matching products -->
</xsl:for-each>
```

For a single lookup, the difference is negligible. But if you perform the same category lookup hundreds of times (once per order line, for example), the key version is dramatically faster.

**C# parallel:**

| XSLT | C# | Complexity |
|------|-----|-----------|
| `//product[@category = $cat]` | `products.Where(p => p.Category == cat)` | O(n) per call |
| `key('by-category', $cat)` | `productsByCategory[cat]` (`Dictionary`/`ILookup`) | O(1) per call after O(n) setup |

### When the Index is Built

The index is built lazily — on the first call to `key()` for that key name and document. It is built once per (key-name, document) pair and cached for the duration of the transformation.

### Multiple Nodes Per Key Value

A key value can map to multiple nodes. This is the `ILookup<TKey, TValue>` case:

```xml
<xsl:key name="products-by-category" match="product" use="@category"/>

<!-- Returns ALL products in the electronics category -->
<xsl:variable name="electronics" select="key('products-by-category', 'electronics')"/>
<!-- $electronics is a sequence of 0 or more product elements -->
```

### Multiple Key Values Per Node

A single node can have multiple key values — when the `use` expression returns a sequence:

```xml
<!-- A product can have multiple tags -->
<product id="WP-001">
  <name>Widget Pro</name>
  <tag>electronics</tag>
  <tag>sale</tag>
  <tag>popular</tag>
</product>

<!-- Index products by their tags -->
<xsl:key name="products-by-tag" match="product" use="tag"/>

<!-- key('products-by-tag', 'sale') returns WP-001 -->
<!-- key('products-by-tag', 'electronics') also returns WP-001 -->
```

**C# parallel:** `ILookup<string, Product>` — one product appears under multiple keys:

```csharp
var productsByTag = products
    .SelectMany(p => p.Tags.Select(t => (Tag: t, Product: p)))
    .ToLookup(x => x.Tag, x => x.Product);
```

---

## Composite Keys

XSLT 3.0 introduces composite keys with `composite="yes"`. A composite key uses multiple values together as a single compound key — like a multi-column index in a database.

```xml
<!-- Index by both category AND status -->
<xsl:key name="products-by-cat-status"
         match="product"
         use="@category, @status"
         composite="yes"/>

<!-- Look up active electronics -->
<xsl:variable name="active-electronics"
              select="key('products-by-cat-status', ('electronics', 'active'))"/>
```

Without `composite="yes"`, passing two values to `use` would create two separate key entries per node. With `composite="yes"`, the two values are treated as a single compound key.

### Before XSLT 3.0: Concatenated Keys

In XSLT 2.0, you simulate composite keys by concatenating the values:

```xml
<xsl:key name="products-by-cat-status"
         match="product"
         use="concat(@category, '|', @status)"/>

<!-- Look up -->
<xsl:variable name="active-electronics"
              select="key('products-by-cat-status', 'electronics|active')"/>
```

This works but is fragile — if a value contains the separator character, you get incorrect results. Composite keys are the cleaner XSLT 3.0 solution.

**C# parallel:** Composite keys are like `Dictionary<(string Category, string Status), List<Product>>` — a tuple key:

```csharp
var lookup = products
    .ToLookup(p => (p.Category, p.Status));

var activeElectronics = lookup[("electronics", "active")];
```

---

## Cross-Document Lookups

The third argument to `key()` specifies which document to search. By default, `key()` searches the document containing the context node. You can search a different document by passing a node from that document:

```xml
<!-- External lookup table -->
<xsl:variable name="codes-doc" select="doc('status-codes.xml')"/>

<xsl:key name="status-label" match="status" use="@code"/>

<!-- Look up a status code in the external document -->
<xsl:template match="product">
  <xsl:variable name="status-text"
                select="key('status-label', @status, $codes-doc)"/>
  <span class="status"><xsl:value-of select="$status-text"/></span>
</xsl:template>
```

Where `status-codes.xml` contains:

```xml
<codes>
  <status code="A" label="Active"/>
  <status code="D" label="Discontinued"/>
  <status code="P" label="Pending Review"/>
</codes>
```

### Joining Two Documents

A common pattern is joining data from two XML documents — like a SQL join:

```xml
<!-- orders.xml (the source document) -->
<orders>
  <order id="ORD-100">
    <line product-ref="WP-001" qty="2"/>
    <line product-ref="WP-003" qty="1"/>
  </order>
</orders>

<!-- products.xml (the lookup document) -->
<catalog>
  <product id="WP-001"><name>Widget Pro</name><price>29.99</price></product>
  <product id="WP-003"><name>Gizmo X</name><price>79.99</price></product>
</catalog>
```

```xml
<xsl:variable name="product-catalog" select="doc('products.xml')"/>
<xsl:key name="prod-by-id" match="product" use="@id"/>

<xsl:template match="order">
  <div class="order">
    <h2>Order <xsl:value-of select="@id"/></h2>
    <xsl:for-each select="line">
      <xsl:variable name="prod"
                    select="key('prod-by-id', @product-ref, $product-catalog)"/>
      <p>
        <xsl:value-of select="$prod/name"/>
        — <xsl:value-of select="@qty"/> x
        $<xsl:value-of select="format-number($prod/price, '#,##0.00')"/>
        = $<xsl:value-of select="format-number($prod/price * @qty, '#,##0.00')"/>
      </p>
    </xsl:for-each>
  </div>
</xsl:template>
```

**C# parallel:** This is a classic hash join:

```csharp
var productsById = products.ToDictionary(p => p.Id);

var orderDetails = order.Lines.Select(line => new {
    Product = productsById[line.ProductRef],
    Quantity = line.Qty
});
```

---

## Common Patterns

### Lookup Tables

Replace verbose `xsl:choose` blocks with data-driven lookups:

```xml
<!-- Instead of this: -->
<xsl:choose>
  <xsl:when test="@country = 'US'">United States</xsl:when>
  <xsl:when test="@country = 'GB'">United Kingdom</xsl:when>
  <xsl:when test="@country = 'DE'">Germany</xsl:when>
  <!-- ... 200 more countries ... -->
</xsl:choose>

<!-- Use a lookup table: -->
<xsl:variable name="countries-doc" select="doc('countries.xml')"/>
<xsl:key name="country-by-code" match="country" use="@code"/>

<xsl:value-of select="key('country-by-code', @country, $countries-doc)/@name"/>
```

### Deduplication

Use keys to find unique values — nodes with the same key value are grouped together, and you can select just the first:

```xml
<xsl:key name="products-by-category" match="product" use="@category"/>

<!-- Get distinct categories -->
<xsl:for-each select="//product[generate-id() =
                       generate-id(key('products-by-category', @category)[1])]">
  <li><xsl:value-of select="@category"/></li>
</xsl:for-each>
```

This is the classic "Muenchian method" from XSLT 1.0. In XSLT 2.0+, use `xsl:for-each-group` instead — it is simpler and more readable:

```xml
<!-- Preferred in XSLT 2.0+: -->
<xsl:for-each-group select="//product" group-by="@category">
  <li><xsl:value-of select="current-grouping-key()"/></li>
</xsl:for-each-group>
```

### Parent-Child Joins

Index child elements by their parent's ID to navigate relationships:

```xml
<xsl:key name="children-by-parent" match="category" use="@parent-id"/>

<!-- Given: <category id="C1" parent-id="ROOT"/>
            <category id="C2" parent-id="C1"/>
            <category id="C3" parent-id="C1"/> -->

<!-- Find all children of category C1 -->
<xsl:variable name="children" select="key('children-by-parent', 'C1')"/>
```

### Existence Check

Keys provide an efficient way to test whether a value exists in a set:

```xml
<xsl:key name="valid-codes" match="code" use="."/>
<xsl:variable name="codes-doc" select="doc('valid-codes.xml')"/>

<!-- Check if a product's status code is valid -->
<xsl:if test="key('valid-codes', @status, $codes-doc)">
  <!-- Status code is valid -->
</xsl:if>

<xsl:if test="not(key('valid-codes', @status, $codes-doc))">
  <xsl:message>WARNING: Unknown status code '<xsl:value-of select="@status"/>'</xsl:message>
</xsl:if>
```

**C# parallel:** `HashSet<string>.Contains(value)` — O(1) membership test.

---

## Performance

### When to Use Keys

| Scenario | Use Keys? | Why |
|----------|-----------|-----|
| Single lookup by ID | Maybe | Predicate `[@id = $val]` is fine for one-time use |
| Repeated lookups by same field | **Yes** | Index built once, used many times |
| Joining two documents | **Yes** | Avoids N x M nested loops |
| Lookup table (code-to-label) | **Yes** | Classic use case |
| One-time filtering | No | Predicate is simpler and equally fast |

### Index Building Cost

Building a key index has a one-time cost proportional to the number of matched nodes. For a document with 10,000 products, the first `key()` call triggers a scan of all 10,000 products. Subsequent calls are near-instant.

If you define a key but never call `key()` for it, the index is never built — there is no wasted effort.

### Memory

Key indexes consume memory proportional to the number of entries. For large documents, this is usually worthwhile — the memory cost of the index is small compared to the document itself. But if you define many keys with broad match patterns (`match="*"`), the combined memory cost can be significant.

### Comparison with Predicates

```xml
<!-- Predicate: O(n) per call — scans all products each time -->
<xsl:for-each select="order/line">
  <xsl:value-of select="//product[@id = current()/@product-ref]/name"/>
</xsl:for-each>
<!-- For 1000 lines and 10000 products: 1000 * 10000 = 10,000,000 comparisons -->

<!-- Key: O(1) per call after O(n) setup -->
<xsl:key name="product-by-id" match="product" use="@id"/>
<xsl:for-each select="order/line">
  <xsl:value-of select="key('product-by-id', @product-ref)/name"/>
</xsl:for-each>
<!-- For 1000 lines: 10000 setup + 1000 lookups ≈ 11,000 operations -->
```

The key version is nearly 1000x faster for this workload.

**C# parallel summary:**

| XSLT | C# |
|------|-----|
| `xsl:key name="k" match="product" use="@id"` | `products.ToDictionary(p => p.Id)` |
| `key('k', $value)` | `dict[value]` |
| `key('k', $value, $doc)` | `otherDict[value]` (from different collection) |
| Key with multiple values per node | `ToLookup()` with `SelectMany` |
| Composite key | `ToDictionary` with tuple key |
| Predicate `[@id = $val]` | `products.Where(p => p.Id == val)` (linear scan) |
