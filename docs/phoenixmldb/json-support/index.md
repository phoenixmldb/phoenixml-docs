---
title: JSON Support
description: Store, query, and index JSON documents with PhoenixmlDb
sort: 3
---

# JSON Support

PhoenixmlDb provides first-class JSON document storage and querying through a well-defined XML-backed path. When you call `PutJsonDocument()`, the document is converted to XML, shredded into XDM nodes, and stored with full ACID transaction support — giving every JSON document access to the complete indexing and query infrastructure at no extra cost.

## How JSON Storage Works

The primary storage path for JSON in PhoenixmlDb is **XML-backed**:

1. Your JSON document is converted to an XML representation using a standard mapping (`{}` becomes `<map>`, arrays become `<array>`, and so on).
2. The XML is shredded into individual XDM nodes and written to LMDB under ACID semantics.
3. The `IndexOrchestrator` walks the node tree and feeds every element, attribute, and text node into the full indexing suite — identically to a native XML document.
4. Queries run against the indexed XML; results can be returned as JSON using `xml-to-json()` or XQuery 3.1 map/array constructors.

This means JSON documents get path indexes, value indexes, full-text indexes, structural indexes, and metadata indexes for free, with query performance identical to XML once indexed.

## Storing and Retrieving JSON

```csharp
var container = db.GetContainer("api-data");

// Store — converts to XML, shreds, indexes
container.PutJsonDocument("user.json", """
    {
        "id": 1,
        "name": "Alice",
        "email": "alice@example.com",
        "roles": ["admin", "user"],
        "profile": {
            "age": 30,
            "city": "New York"
        },
        "active": true
    }
    """);

// Retrieve as JSON string (reconstructed from XML, or from preserved original)
string json = container.GetJsonDocument("user.json");

// Retrieve as XML (the internal representation)
string xml = container.GetDocument("user.json");
```

## JSON-to-XML Mapping

PhoenixmlDb uses a deterministic JSON-to-XML mapping:

| JSON | XML |
|------|-----|
| Object `{}` | `<map>` with child elements |
| Array `[]` | `<array>` with `<_>` items |
| String | Element with text content |
| Number | Element with `type="number"` |
| Boolean | Element with `type="boolean"` |
| Null | Empty element with `type="null"` |

**Example:**

```json
{
    "name": "Widget",
    "price": 29.99,
    "tags": ["sale", "featured"],
    "inStock": true,
    "metadata": null
}
```

becomes:

```xml
<map>
    <name>Widget</name>
    <price type="number">29.99</price>
    <tags>
        <_ >sale</_>
        <_>featured</_>
    </tags>
    <inStock type="boolean">true</inStock>
    <metadata type="null"/>
</map>
```

XPath paths against this structure are what you use in index definitions and XQuery expressions.

## Querying JSON with XQuery

Because JSON is stored as XML, you query it with standard XPath/XQuery expressions against the mapped structure:

```xquery
(: Access a top-level field :)
doc('users/user.json')/map/name/text()

(: Navigate nested objects :)
//map/profile/city/text()

(: Filter a collection :)
for $user in collection('users')/map
where $user/active = 'true'
  and $user/profile/age > 25
return $user/name/text()

(: Check array membership :)
for $product in collection('products')/map
where $product/tags/_ = 'featured'
return $product
```

## Native JsonDocumentStore (Convenience Layer)

PhoenixmlDb also ships a `JsonDocumentStore` for lightweight in-memory JSON work. It supports JSONPath queries and path-value indexes but is **not backed by LMDB** — all data and indexes are volatile and are lost on process restart. It has no ACID transaction support.

Use `JsonDocumentStore` for scratch data, intermediate processing, or tests. Use `PutJsonDocument()` with a container for any data that needs persistence, transactions, or production-grade indexing.

## In This Section

- **[JSON Storage](json-storage.md)** — How JSON is stored, the XML mapping, and storage options
- **[JSON Queries](json-queries.md)** — XQuery patterns for querying JSON documents
- **[JSON Indexing](json-indexing.md)** — How JSON documents get full indexing through the XML storage path
