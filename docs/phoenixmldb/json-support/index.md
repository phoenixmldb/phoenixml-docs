---
title: JSON Support
description: Store, query, and index JSON documents with PhoenixmlDb
sort: 3
---

# JSON Support

PhoenixmlDb stores JSON documents through its XML storage path. When `PutDocumentAsync` receives JSON, the document is converted to the XML representation defined for `fn:json-to-xml`, shredded into XDM nodes, and stored like any XML document — with the same transactions, metadata, indexing and XQuery access.

## How JSON Storage Works

1. `PutDocumentAsync` treats content as JSON when its first non-whitespace character is `{` or `[`, or when `DocumentOptions.ContentType` is `ContentType.Json`.
2. The JSON is converted to XML in the `http://www.w3.org/2005/xpath-functions` namespace: objects become `map`, arrays `array`, and scalars `string`, `number`, `boolean` or `null` elements, with each object member's name in a `key` attribute.
3. The XML is shredded into XDM nodes and written to LMDB in one write transaction. If indexing is enabled, the container's declared indexes are updated in the same transaction.
4. Queries run against the XML representation; `xml-to-json()` turns it back into JSON text.

## Storing and Retrieving JSON

```csharp
var container = await db.OpenOrCreateContainerAsync("api-data");

// Store — detected as JSON, converted to XML, shredded, indexed
await container.PutDocumentAsync("user.json", """
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

// Retrieve as JSON text, via XQuery
await foreach (var json in container.QueryAsync(
    "xml-to-json(/fn:map)", variables: null, documentNameFilter: n => n == "user.json"))
    Console.WriteLine(json);   // {"id":1,"name":"Alice",...}

// Retrieve the stored XML representation
var doc = await container.GetDocumentAsync("user.json");
string xml = await doc!.GetContentAsync();
Console.WriteLine(doc.ContentType);   // Json
```

The original JSON text is not kept: `GetContentAsync` returns the XML representation, and `xml-to-json()` produces compact JSON with members in their original order.

## JSON-to-XML Mapping

| JSON | XML (namespace `http://www.w3.org/2005/xpath-functions`) |
|------|-----|
| Object `{}` | `<map>`, one child per member |
| Array `[]` | `<array>`, one child per item |
| String | `<string>` |
| Number | `<number>`, with the number's text as written |
| Boolean | `<boolean>true</boolean>` / `<boolean>false</boolean>` |
| Null | `<null/>` |
| Object member name | `key` attribute on the member's element |

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
<map xmlns="http://www.w3.org/2005/xpath-functions">
    <string key="name">Widget</string>
    <number key="price">29.99</number>
    <array key="tags">
        <string>sale</string>
        <string>featured</string>
    </array>
    <boolean key="inStock">true</boolean>
    <null key="metadata"/>
</map>
```

## Querying JSON with XQuery

The `fn` prefix is predeclared for this namespace, so paths use `fn:` element names and select members by `@key`:

```xquery
(: Access a top-level field :)
/fn:map/fn:string[@key='name']/string()

(: Navigate nested objects :)
/fn:map/fn:map[@key='profile']/fn:string[@key='city']/string()

(: Filter documents :)
/fn:map[fn:boolean[@key='active'] = 'true']
       [fn:map[@key='profile']/fn:number[@key='age'] > 25]
  /fn:string[@key='name']/string()

(: Check array membership :)
/fn:map[fn:array[@key='tags']/fn:string = 'featured']
```

A query runs per document unless it aggregates across the container; see [JSON Queries](json-queries.md).

## Native JsonDocumentStore (Convenience Layer)

The `PhoenixmlDb.Json` assembly also contains `JsonDocumentStore`, an in-memory store of `System.Text.Json.Nodes.JsonNode` documents with a simple JSONPath-style `Query`. It is **not backed by LMDB** and is not connected to `DocumentDatabase`: data is lost when the process exits, there are no transactions, and the class does no locking.

Use it for scratch data or tests. Use `PutDocumentAsync` on a container for anything that needs persistence, transactions, metadata or indexing.

## In This Section

- **[JSON Storage](json-storage.md)** — How JSON is stored, the XML mapping, and storage options
- **[JSON Queries](json-queries.md)** — XQuery patterns for querying JSON documents
- **[JSON Indexing](json-indexing.md)** — How JSON documents get full indexing through the XML storage path
