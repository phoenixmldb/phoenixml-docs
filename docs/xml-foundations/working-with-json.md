---
title: Working with JSON
description: Parsing, querying, transforming, and outputting JSON with XPath, XSLT, and XQuery
sort: 5
---

# Working with JSON

One of the biggest misconceptions about XML technologies is that they can't work with JSON. In fact, XPath 3.1, XSLT 3.0, and XQuery 3.1 all have **native JSON support** — you can parse JSON, query it, transform it, and output it, all within the same tools you use for XML.

This means you can:
- Parse a JSON API response and transform it into HTML
- Combine JSON and XML data sources in a single query
- Convert between JSON and XML formats
- Use XSLT to produce JSON API responses from XML data
- Query JSON with the full power of XPath

If you're a .NET developer who works primarily with JSON, this is the bridge between what you know and what XML tools offer.

## Contents

- [Parsing JSON](#parsing-json)
- [Querying JSON with XPath](#querying-json-with-xpath)
- [JSON in XSLT](#json-in-xslt)
- [JSON in XQuery](#json-in-xquery)
- [Round-Trip: JSON to JSON](#round-trip-json-to-json)
- [Mixed Workflows: JSON + XML](#mixed-workflows-json--xml)
- [JSON Output Patterns](#json-output-patterns)

---

## Parsing JSON

### json-doc()

Loads and parses a JSON file into XDM maps and arrays:

```xpath
json-doc('config.json')
```

Given this JSON file:
```json
{
  "name": "PhoenixmlDb",
  "version": "1.0.0",
  "features": ["xquery", "xslt", "xpath"],
  "settings": {
    "debug": false,
    "maxConnections": 100
  }
}
```

`json-doc('config.json')` returns an XDM map — the same data structure you'd get from `JsonSerializer.Deserialize<Dictionary<string, object>>()` in C#, but queryable with XPath.

### parse-json()

Parses a JSON string (useful when JSON comes from an API call, parameter, or embedded in XML):

```xpath
parse-json('{"name": "Alice", "age": 30}')
```

**C# equivalent:** `JsonDocument.Parse(jsonString)`

### What JSON Becomes in XDM

| JSON | XDM Type | C# Equivalent |
|------|----------|---------------|
| `{ }` object | `map(*)` | `Dictionary<string, object>` |
| `[ ]` array | `array(*)` | `List<object>` |
| `"string"` | `xs:string` | `string` |
| `123` | `xs:integer` | `long` |
| `3.14` | `xs:double` | `double` |
| `true` / `false` | `xs:boolean` | `bool` |
| `null` | Empty sequence `()` | `null` |

---

## Querying JSON with XPath

Once JSON is parsed into maps and arrays, you query it with the `?` lookup operator:

### Object Access

```xpath
let $config := json-doc('config.json')
return (
  $config?name,                    (: "PhoenixmlDb" :)
  $config?version,                 (: "1.0.0" :)
  $config?settings?debug,          (: false :)
  $config?settings?maxConnections  (: 100 :)
)
```

**C# equivalent:**
```csharp
var config = JsonDocument.Parse(json);
config.RootElement.GetProperty("name").GetString();
config.RootElement.GetProperty("settings").GetProperty("debug").GetBoolean();
```

The XPath version is more concise — `$config?settings?debug` vs. the verbose `GetProperty` chain.

### Array Access

```xpath
let $config := json-doc('config.json')
return (
  $config?features?1,        (: "xquery" — 1-based indexing :)
  $config?features?*,        (: all features as a sequence :)
  array:size($config?features) (: 3 :)
)
```

### Filtering JSON Arrays

Given a JSON API response:
```json
{
  "users": [
    { "name": "Alice", "role": "admin", "active": true },
    { "name": "Bob", "role": "user", "active": true },
    { "name": "Charlie", "role": "user", "active": false }
  ]
}
```

```xpath
let $data := parse-json($json-string)
let $users := $data?users?*         (: sequence of all user maps :)

(: Active users :)
return $users[.?active = true()]

(: Admin users :)
return $users[.?role = 'admin']

(: User names as a comma-separated string :)
return string-join($users ! .?name, ', ')
(: "Alice, Bob, Charlie" :)
```

**C# equivalent:**
```csharp
var users = JsonSerializer.Deserialize<List<User>>(json);
users.Where(u => u.Active).ToList();
users.Where(u => u.Role == "admin").ToList();
string.Join(", ", users.Select(u => u.Name));
```

### Nested Queries

```xpath
let $orders := json-doc('orders.json')?orders?*
for $order in $orders
where $order?total > 100
order by $order?total descending
return map {
  'id': $order?id,
  'customer': $order?customer?name,
  'total': $order?total
}
```

This is full FLWOR query power applied to JSON data — something that `System.Text.Json` alone can't do without writing procedural code.

---

## JSON in XSLT

### Reading JSON Input

An XSLT stylesheet can process JSON input by loading it with `json-doc()`:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
  <xsl:output method="html" html-version="5" indent="yes"/>

  <xsl:param name="data-file" select="'data.json'"/>
  <xsl:variable name="data" select="json-doc($data-file)"/>

  <xsl:template match="/">
    <html>
      <body>
        <h1>Users</h1>
        <table>
          <tr><th>Name</th><th>Role</th></tr>
          <xsl:for-each select="$data?users?*">
            <tr>
              <td><xsl:value-of select=".?name"/></td>
              <td><xsl:value-of select=".?role"/></td>
            </tr>
          </xsl:for-each>
        </table>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
```

**This transforms a JSON file into an HTML table** — using XSLT's template system and formatting capabilities, but reading from JSON instead of XML.

### Producing JSON Output

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
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
        },
        'count': count(product),
        'generated': string(current-dateTime())
      }
    "/>
  </xsl:template>
</xsl:stylesheet>
```

**Output:**
```json
{
  "products": [
    { "id": "P001", "name": "Wireless Mouse", "price": 29.99, "category": "electronics" },
    { "id": "P002", "name": "Mechanical Keyboard", "price": 89.99, "category": "electronics" }
  ],
  "count": 2,
  "generated": "2026-03-19T14:30:00"
}
```

### Combining JSON and XML Sources

```xml
<xsl:variable name="config" select="json-doc('config.json')"/>
<xsl:variable name="catalog" select="doc('catalog.xml')"/>

<xsl:template match="/">
  <html>
    <head><title><xsl:value-of select="$config?site?title"/></title></head>
    <body>
      <xsl:for-each select="$catalog//product">
        <div class="product">
          <h2><xsl:value-of select="name"/></h2>
          <xsl:if test="$config?features?showPrices">
            <p>$<xsl:value-of select="price"/></p>
          </xsl:if>
        </div>
      </xsl:for-each>
    </body>
  </html>
</xsl:template>
```

Configuration in JSON, data in XML, output in HTML — all in one stylesheet.

---

## JSON in XQuery

XQuery provides even more natural JSON handling:

### Querying JSON APIs

```xquery
let $response := json-doc('https://api.example.com/products')
for $product in $response?data?*
where $product?price < 50
order by $product?name
return <li>{ $product?name } — ${ $product?price }</li>
```

### Converting JSON to XML

```xquery
let $users := json-doc('users.json')?*
return <users>{
  for $user in $users
  return <user id="{ $user?id }">
    <name>{ $user?name }</name>
    <email>{ $user?email }</email>
    <roles>{
      for $role in $user?roles?*
      return <role>{ $role }</role>
    }</roles>
  </user>
}</users>
```

### Converting XML to JSON

```xquery
let $catalog := doc('catalog.xml')
return array {
  for $p in $catalog//product
  return map {
    'id': string($p/@id),
    'name': string($p/name),
    'price': number($p/price),
    'tags': array { $p/tags/tag ! string(.) }
  }
}
```

---

## Round-Trip: JSON to JSON

You can read JSON, process it with XPath/XQuery, and output JSON — never touching XML:

```xquery
(: Read JSON, filter, reshape, output JSON :)
let $input := json-doc('orders.json')
let $orders := $input?orders?*

return map {
  'summary': map {
    'totalOrders': count($orders),
    'totalRevenue': sum($orders ! .?total),
    'averageOrder': avg($orders ! .?total)
  },
  'topCustomers': array {
    let $by-customer := map:group-by($orders, function($o) { $o?customerId })
    for $id in map:keys($by-customer)
    let $customer-orders := $by-customer($id)
    let $total := sum($customer-orders ! .?total)
    order by $total descending
    return map {
      'customerId': $id,
      'orderCount': count($customer-orders),
      'totalSpent': $total
    }
  }
}
```

Serialize with `method="json"` and you get a JSON-to-JSON transformation pipeline — no XML involved at all. The XQuery/XPath engine is acting as a general-purpose data transformation tool.

**C# equivalent:** This would require deserializing to objects, LINQ queries, then re-serializing. The XQuery version is more concise and declarative.

---

## Mixed Workflows: JSON + XML

Real-world data integration often combines formats. These tools handle that naturally:

### Enriching XML with JSON Config

```xquery
let $products := doc('products.xml')//product
let $pricing := json-doc('pricing.json')

for $p in $products
let $price-info := $pricing?prices?*[.?sku = string($p/@sku)]
return <product id="{ $p/@id }">
  { $p/name }
  <price currency="{ $price-info?currency }">{ $price-info?amount }</price>
  <discount>{ $price-info?discount }</discount>
</product>
```

### Generating JSON from XML + JSON Sources

```xquery
let $catalog := doc('catalog.xml')
let $reviews := json-doc('reviews.json')

return array {
  for $p in $catalog//product
  let $product-reviews := $reviews?*[.?productId = string($p/@id)]
  return map {
    'product': string($p/name),
    'price': number($p/price),
    'avgRating': if (exists($product-reviews))
                 then avg($product-reviews ! .?rating)
                 else null,
    'reviewCount': count($product-reviews)
  }
}
```

---

## JSON Output Patterns

### Pattern 1: Simple Object

```xpath
map { 'status': 'ok', 'count': count(//item) }
```

### Pattern 2: Array of Objects

```xpath
array { //item ! map { 'name': string(./name), 'value': string(./price) } }
```

### Pattern 3: Nested Structure

```xpath
map {
  'metadata': map { 'generated': string(current-dateTime()), 'version': '1.0' },
  'data': array { ... }
}
```

### Pattern 4: Preserving JSON Null

XPath's empty sequence `()` serializes as JSON `null`:

```xpath
map {
  'name': 'Alice',
  'email': if ($user/email) then string($user/email) else ()
}
(: Output: { "name": "Alice", "email": null } :)
```

### Serialization Control

```xpath
serialize($map, map {
  'method': 'json',
  'indent': true(),
  'allow-duplicate-names': false()
})
```

---

## The Takeaway for .NET Developers

If your reaction is "wait, I can use XPath to query JSON?" — yes. The XPath 3.1 data model (maps + arrays) maps 1:1 to JSON's data model. This means:

- **You don't need to choose** between JSON and XML tools. Use both.
- **XPath is a universal query language** — it works on XML trees AND JSON data structures.
- **XSLT is a universal transform language** — it can read JSON and produce JSON, not just XML-to-HTML.
- **Format conversion is natural** — JSON ↔ XML ↔ HTML ↔ CSV ↔ text, all in one toolchain.

The "XML vs JSON" debate becomes moot when your tools handle both natively.
