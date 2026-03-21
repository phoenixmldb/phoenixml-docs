---
title: "Maps, Arrays, and Records"
description: "xsl:map, xsl:array, xsl:record, xsl:for-each-member — structured data in XSLT 3.0/4.0"
sort: 14
---

# Maps, Arrays, and Records

XSLT 3.0 introduced maps and arrays as first-class data types, bringing key-value pairs and ordered collections into a language that previously only had XML nodes and atomic values. XSLT 4.0 adds records and `xsl:for-each-member`. If you come from C#, think of maps as `Dictionary<string, object>`, arrays as `List<object>`, and records as anonymous types or C# records.

## Contents

- [xsl:map and xsl:map-entry](#xslmap-and-xslmap-entry)
- [xsl:array and xsl:array-member](#xslarray-and-xslarray-member)
- [xsl:for-each-member (XSLT 4.0)](#xslfor-each-member-xslt-40)
- [xsl:record (XSLT 4.0)](#xslrecord-xslt-40)
- [JSON Output Patterns](#json-output-patterns)
- [Use Cases](#use-cases)

---

## xsl:map and xsl:map-entry

A map is an unordered collection of key-value pairs. Keys are atomic values (strings, numbers, dates); values can be anything — strings, numbers, nodes, sequences, other maps, or arrays.

**C# parallel:** `Dictionary<string, object>` or an anonymous object `new { Name = "Alice", Age = 30 }`.

### XPath Literal vs. xsl:map

You can construct maps in pure XPath using the `map{}` literal syntax:

```xml
<!-- XPath map literal — keys and values are expressions -->
<xsl:variable name="colors" select="map {
  'error': 'red',
  'warning': 'orange',
  'info': 'blue'
}"/>
```

The `xsl:map` instruction does the same thing, but allows dynamic construction — the entries can be computed with XSLT instructions:

```xml
<!-- xsl:map — dynamic construction -->
<xsl:variable name="colors" as="map(xs:string, xs:string)">
  <xsl:map>
    <xsl:map-entry key="'error'" select="'red'"/>
    <xsl:map-entry key="'warning'" select="'orange'"/>
    <xsl:map-entry key="'info'" select="'blue'"/>
  </xsl:map>
</xsl:variable>
```

### When to Use xsl:map Over XPath Literals

Use `xsl:map` when you need to:

- Build entries conditionally
- Generate entries from iteration
- Include complex computed values

```xml
<!-- Building a map from XML data -->
<xsl:variable name="config" as="map(*)">
  <xsl:map>
    <!-- Static entries -->
    <xsl:map-entry key="'version'" select="'2.1'"/>

    <!-- Conditional entry -->
    <xsl:if test="$debug-mode">
      <xsl:map-entry key="'debug'" select="true()"/>
    </xsl:if>

    <!-- Entries from iteration -->
    <xsl:for-each select="//setting">
      <xsl:map-entry key="string(@name)" select="string(.)"/>
    </xsl:for-each>
  </xsl:map>
</xsl:variable>
```

**C# parallel:**

```csharp
var config = new Dictionary<string, object>
{
    ["version"] = "2.1"
};

if (debugMode)
    config["debug"] = true;

foreach (var setting in settings)
    config[setting.Name] = setting.Value;
```

### Accessing Map Values

Use the XPath `?` lookup operator or the `map:get()` function:

```xml
<!-- Lookup operator (preferred — concise) -->
<xsl:value-of select="$colors?error"/>          <!-- "red" -->

<!-- map:get function (equivalent) -->
<xsl:value-of select="map:get($colors, 'error')"/> <!-- "red" -->

<!-- Dynamic key lookup -->
<xsl:variable name="level" select="@level"/>
<span style="color: {$colors($level)}">
  <xsl:value-of select="@message"/>
</span>

<!-- Check if key exists -->
<xsl:if test="map:contains($config, 'debug')">
  <p>Debug mode is active.</p>
</xsl:if>
```

### Useful Map Functions

| Function | Description | C# Equivalent |
|----------|-------------|---------------|
| `map:get($m, $key)` | Get value by key | `dict[key]` |
| `map:contains($m, $key)` | Check if key exists | `dict.ContainsKey(key)` |
| `map:keys($m)` | All keys as a sequence | `dict.Keys` |
| `map:size($m)` | Number of entries | `dict.Count` |
| `map:put($m, $key, $val)` | New map with added/replaced entry | Immutable — returns new dict |
| `map:remove($m, $key)` | New map without the key | Immutable — returns new dict |
| `map:merge($maps)` | Merge multiple maps | Multiple `dict.Add()` calls |
| `map:for-each($m, $fn)` | Apply function to each entry | `dict.Select(kv => fn(kv))` |
| `map:find($m, $key)` | Deep search for key in nested maps | No direct equivalent |

### Nested Maps

Maps can contain other maps, building hierarchical data structures:

```xml
<xsl:variable name="api-response" as="map(*)">
  <xsl:map>
    <xsl:map-entry key="'status'" select="200"/>
    <xsl:map-entry key="'data'">
      <xsl:map>
        <xsl:map-entry key="'user'">
          <xsl:map>
            <xsl:map-entry key="'id'" select="$user-id"/>
            <xsl:map-entry key="'name'" select="$user-name"/>
            <xsl:map-entry key="'email'" select="$user-email"/>
          </xsl:map>
        </xsl:map-entry>
      </xsl:map>
    </xsl:map-entry>
  </xsl:map>
</xsl:variable>

<!-- Access nested values with chained ? -->
<xsl:value-of select="$api-response?data?user?name"/>
```

---

## xsl:array and xsl:array-member

An array is an ordered collection of values. Unlike sequences, arrays can contain other arrays and maps as individual members, and members can themselves be sequences.

**C# parallel:** `List<object>` or `object[]`.

### XPath Literal vs. xsl:array

XPath provides square-bracket syntax for array literals:

```xml
<!-- XPath array literal -->
<xsl:variable name="primes" select="[2, 3, 5, 7, 11, 13]"/>

<!-- Nested arrays -->
<xsl:variable name="matrix" select="[[1, 2, 3], [4, 5, 6], [7, 8, 9]]"/>
```

The `xsl:array` instruction allows dynamic construction:

```xml
<!-- xsl:array — dynamic construction -->
<xsl:variable name="product-names" as="array(xs:string)">
  <xsl:array>
    <xsl:for-each select="//product">
      <xsl:array-member select="string(name)"/>
    </xsl:for-each>
  </xsl:array>
</xsl:variable>
```

### Arrays vs. Sequences

This distinction trips up many newcomers. Both hold ordered collections, but they behave differently:

| | Sequence | Array |
|---|---|---|
| **Nesting** | Sequences flatten automatically: `(1, (2, 3))` = `(1, 2, 3)` | Arrays preserve nesting: `[[1], [2, 3]]` has 2 members |
| **Members** | Atomic values and nodes only | Any XDM value, including arrays, maps, and sequences |
| **Empty** | `()` is the empty sequence | `[]` is an empty array (an array with zero members) |
| **Usage** | Default for most XPath operations | Required for JSON arrays and structured data |

**C# parallel:** Sequences are like flattened `IEnumerable<T>`, while arrays are like `List<object>` that can contain nested lists.

### Accessing Array Members

```xml
<!-- By position (1-based) -->
<xsl:value-of select="$primes(3)"/>     <!-- 5 -->

<!-- Using the ? lookup operator -->
<xsl:value-of select="$primes?3"/>      <!-- 5 -->

<!-- All members as a sequence (the * wildcard) -->
<xsl:value-of select="$primes?*" separator=", "/> <!-- 2, 3, 5, 7, 11, 13 -->
```

### Useful Array Functions

| Function | Description | C# Equivalent |
|----------|-------------|---------------|
| `array:size($a)` | Number of members | `list.Count` |
| `array:get($a, $pos)` | Get member by position | `list[pos - 1]` |
| `array:put($a, $pos, $val)` | New array with replaced member | Immutable update |
| `array:append($a, $val)` | New array with added member | `list.Add(val)` (but immutable) |
| `array:subarray($a, $start, $len)` | Slice the array | `list.GetRange(start, len)` |
| `array:remove($a, $pos)` | New array without the member | `list.RemoveAt(pos)` (but immutable) |
| `array:head($a)` | First member | `list[0]` |
| `array:tail($a)` | All members except the first | `list.Skip(1)` |
| `array:join($arrays)` | Concatenate arrays | `list1.Concat(list2)` |
| `array:flatten($a)` | Flatten nested arrays to a sequence | `list.SelectMany(x => x)` |
| `array:for-each($a, $fn)` | Apply function to each member | `list.Select(fn)` |
| `array:filter($a, $fn)` | Keep members matching predicate | `list.Where(fn)` |

### Building an Array from XML

```xml
<!-- Convert product elements to an array of maps -->
<xsl:variable name="products-array" as="array(map(*))">
  <xsl:array>
    <xsl:for-each select="//product">
      <xsl:array-member>
        <xsl:map>
          <xsl:map-entry key="'name'" select="string(name)"/>
          <xsl:map-entry key="'price'" select="number(price)"/>
          <xsl:map-entry key="'category'" select="string(@category)"/>
        </xsl:map>
      </xsl:array-member>
    </xsl:for-each>
  </xsl:array>
</xsl:variable>

<!-- Access: second product's name -->
<xsl:value-of select="$products-array(2)?name"/>
```

---

## xsl:for-each-member (XSLT 4.0)

`xsl:for-each-member` iterates over the members of an array, binding each member to a variable. This is the array counterpart to `xsl:for-each` (which iterates over sequences).

**C# parallel:** `foreach (var item in array) { ... }`

### Basic Usage

```xml
<xsl:variable name="tags" select="['xslt', 'xml', 'transformation']"/>

<ul>
  <xsl:for-each-member select="$tags" as="member">
    <li><xsl:value-of select="$member"/></li>
  </xsl:for-each-member>
</ul>
```

Output:

```html
<ul>
  <li>xslt</li>
  <li>xml</li>
  <li>transformation</li>
</ul>
```

### Why Not Just Use xsl:for-each?

When array members are themselves sequences or complex values, `xsl:for-each` with `array:flatten()` would lose the member boundaries. `xsl:for-each-member` preserves each member as a distinct unit:

```xml
<!-- An array where each member is a sequence of names -->
<xsl:variable name="teams" select="[('Alice', 'Bob'), ('Carol', 'Dave', 'Eve')]"/>

<!-- for-each-member preserves the grouping -->
<xsl:for-each-member select="$teams" as="team">
  <div class="team">
    <xsl:for-each select="$team">
      <span><xsl:value-of select="."/></span>
    </xsl:for-each>
  </div>
</xsl:for-each-member>
```

Output:

```html
<div class="team">
  <span>Alice</span>
  <span>Bob</span>
</div>
<div class="team">
  <span>Carol</span>
  <span>Dave</span>
  <span>Eve</span>
</div>
```

### Iterating Over Maps in an Array

A common pattern when working with JSON-like data:

```xml
<xsl:variable name="users" select="[
  map { 'name': 'Alice', 'role': 'admin' },
  map { 'name': 'Bob', 'role': 'editor' },
  map { 'name': 'Carol', 'role': 'viewer' }
]"/>

<table>
  <thead><tr><th>Name</th><th>Role</th></tr></thead>
  <tbody>
    <xsl:for-each-member select="$users" as="user">
      <tr>
        <td><xsl:value-of select="$user?name"/></td>
        <td><xsl:value-of select="$user?role"/></td>
      </tr>
    </xsl:for-each-member>
  </tbody>
</table>
```

---

## xsl:record (XSLT 4.0)

`xsl:record` constructs a map with named entries, similar to a C# anonymous type or record. It is syntactic sugar for `xsl:map` with `xsl:map-entry`, but with a cleaner, more readable syntax.

**C# parallel:** Anonymous types `new { Name = "Alice", Age = 30 }` or records `record User(string Name, int Age)`.

### Basic Usage

```xml
<xsl:variable name="user" as="map(*)">
  <xsl:record>
    <name><xsl:value-of select="@name"/></name>
    <age select="xs:integer(@age)"/>
    <email><xsl:value-of select="email"/></email>
  </xsl:record>
</xsl:variable>

<!-- Access like a map -->
<xsl:value-of select="$user?name"/>
```

Each child element of `xsl:record` becomes a map entry where:

- The element name becomes the string key
- The element's content (or `select` attribute) becomes the value

### Comparison: xsl:record vs. xsl:map

The following are equivalent:

```xml
<!-- Using xsl:record (cleaner) -->
<xsl:record>
  <name>Alice</name>
  <age select="30"/>
  <active select="true()"/>
</xsl:record>

<!-- Using xsl:map (more verbose) -->
<xsl:map>
  <xsl:map-entry key="'name'" select="'Alice'"/>
  <xsl:map-entry key="'age'" select="30"/>
  <xsl:map-entry key="'active'" select="true()"/>
</xsl:map>
```

Use `xsl:record` when all keys are fixed, known string names. Use `xsl:map` when keys are dynamic or non-string.

### Building Records from XML

```xml
<xsl:template match="employee">
  <xsl:variable name="emp" as="map(*)">
    <xsl:record>
      <id select="string(@id)"/>
      <fullName>
        <xsl:value-of select="concat(firstName, ' ', lastName)"/>
      </fullName>
      <department select="string(@dept)"/>
      <salary select="xs:decimal(salary)"/>
      <isManager select="@role = 'manager'"/>
    </xsl:record>
  </xsl:variable>

  <!-- Use the record -->
  <div class="employee-card">
    <h3><xsl:value-of select="$emp?fullName"/></h3>
    <p>Department: <xsl:value-of select="$emp?department"/></p>
    <xsl:if test="$emp?isManager">
      <span class="badge">Manager</span>
    </xsl:if>
  </div>
</xsl:template>
```

---

## JSON Output Patterns

Maps and arrays are the bridge between XML and JSON in XSLT 3.0+. When you serialize a map or array with `method="json"`, it produces JSON output directly.

### XML to JSON Conversion

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:output method="json" indent="yes"/>

  <xsl:template match="/">
    <!-- The template result is a map — serialized as JSON -->
    <xsl:map>
      <xsl:map-entry key="'catalog'">
        <xsl:array>
          <xsl:for-each select="//product">
            <xsl:array-member>
              <xsl:map>
                <xsl:map-entry key="'name'" select="string(name)"/>
                <xsl:map-entry key="'price'" select="number(price)"/>
                <xsl:map-entry key="'category'" select="string(@category)"/>
                <xsl:map-entry key="'inStock'" select="stock > 0"/>
                <xsl:if test="description">
                  <xsl:map-entry key="'description'" select="string(description)"/>
                </xsl:if>
              </xsl:map>
            </xsl:array-member>
          </xsl:for-each>
        </xsl:array>
      </xsl:map-entry>
    </xsl:map>
  </xsl:template>

</xsl:stylesheet>
```

Output:

```json
{
  "catalog": [
    {
      "name": "Laptop",
      "price": 999.99,
      "category": "electronics",
      "inStock": true,
      "description": "High-performance laptop"
    },
    {
      "name": "T-Shirt",
      "price": 19.99,
      "category": "clothing",
      "inStock": true
    }
  ]
}
```

**C# parallel:**

```csharp
var catalog = new {
    catalog = products.Select(p => new {
        name = p.Name,
        price = p.Price,
        category = p.Category,
        inStock = p.Stock > 0,
        description = p.Description  // null omitted by some serializers
    })
};
string json = JsonSerializer.Serialize(catalog);
```

### API Response Construction

A common pattern for building REST API responses:

```xml
<xsl:template name="api-response">
  <xsl:param name="status" as="xs:integer"/>
  <xsl:param name="data" as="item()*"/>
  <xsl:param name="message" as="xs:string" select="''"/>

  <xsl:map>
    <xsl:map-entry key="'status'" select="$status"/>
    <xsl:map-entry key="'success'" select="$status ge 200 and $status lt 300"/>
    <xsl:if test="$message != ''">
      <xsl:map-entry key="'message'" select="$message"/>
    </xsl:if>
    <xsl:map-entry key="'data'" select="$data"/>
    <xsl:map-entry key="'timestamp'" select="string(current-dateTime())"/>
  </xsl:map>
</xsl:template>
```

### Reading JSON Input

XSLT 3.0 can also read JSON into maps and arrays using `json-doc()` or `parse-json()`:

```xml
<!-- Load a JSON configuration file -->
<xsl:variable name="config" select="json-doc('config.json')"/>

<!-- Access values -->
<xsl:value-of select="$config?database?host"/>
<xsl:value-of select="$config?database?port"/>

<!-- Iterate over array members -->
<xsl:for-each select="$config?allowedOrigins?*">
  <origin><xsl:value-of select="."/></origin>
</xsl:for-each>
```

---

## Use Cases

### Building Configuration from XML

```xml
<xsl:variable name="app-config" as="map(*)">
  <xsl:map>
    <xsl:for-each select="configuration/appSettings/add">
      <xsl:map-entry key="string(@key)" select="string(@value)"/>
    </xsl:for-each>
  </xsl:map>
</xsl:variable>

<!-- Usage -->
<connection-string>
  <xsl:value-of select="$app-config?connectionString"/>
</connection-string>
```

### Lookup Tables

Maps make excellent lookup tables, replacing verbose `xsl:choose` chains:

```xml
<!-- Instead of a 50-line xsl:choose -->
<xsl:variable name="country-names" select="map {
  'US': 'United States',
  'GB': 'United Kingdom',
  'DE': 'Germany',
  'FR': 'France',
  'JP': 'Japan'
}"/>

<!-- Fast O(1) lookup -->
<xsl:value-of select="$country-names(@country-code)"/>
```

**C# parallel:**

```csharp
var countryNames = new Dictionary<string, string>
{
    ["US"] = "United States",
    ["GB"] = "United Kingdom",
    ["DE"] = "Germany",
    ["FR"] = "France",
    ["JP"] = "Japan"
};

var name = countryNames[countryCode];
```

### Data Transformation Pipeline

Combine maps and arrays to transform XML into structured data for further processing:

```xml
<!-- Step 1: Transform XML to structured data -->
<xsl:variable name="order-data" as="map(*)">
  <xsl:map>
    <xsl:map-entry key="'orderId'" select="string(@id)"/>
    <xsl:map-entry key="'items'">
      <xsl:array>
        <xsl:for-each select="item">
          <xsl:array-member>
            <xsl:map>
              <xsl:map-entry key="'sku'" select="string(@sku)"/>
              <xsl:map-entry key="'quantity'" select="xs:integer(@qty)"/>
              <xsl:map-entry key="'unitPrice'" select="xs:decimal(@price)"/>
              <xsl:map-entry key="'lineTotal'"
                             select="xs:decimal(@qty) * xs:decimal(@price)"/>
            </xsl:map>
          </xsl:array-member>
        </xsl:for-each>
      </xsl:array>
    </xsl:map-entry>
    <xsl:map-entry key="'total'"
                   select="sum(item/(xs:decimal(@qty) * xs:decimal(@price)))"/>
  </xsl:map>
</xsl:variable>

<!-- Step 2: Use the structured data -->
<invoice>
  <order-id><xsl:value-of select="$order-data?orderId"/></order-id>
  <total><xsl:value-of select="format-number($order-data?total, '$#,##0.00')"/></total>
</invoice>
```
