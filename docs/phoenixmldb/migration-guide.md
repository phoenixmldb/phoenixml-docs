---
title: Migration Guide
description: Migrate from Berkeley DB XML, eXist-db, MarkLogic, MongoDB, or SQL
sort: 15
---

# Migration Guide

This guide maps concepts from other XML databases and document stores onto the PhoenixmlDb
embedded API, and shows how to load data exported with the source system's own tools.

> **Availability.** The embedded database package (`PhoenixmlDb.Storage`) is not yet published on
> NuGet.

The C# samples assume these namespaces and an open database:

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Storage;

await using var db = new DocumentDatabase("./data");
```

Two differences matter for every migration:

- **A query runs against one container.** You query through `IContainer.QueryAsync`; inside the
  query, `collection()` is every document in that container. `collection('name')` with an argument
  resolves a single *document* called `name`, not a container, and `doc()` will not reach into
  another container.
- **The API is asynchronous.** Container and document operations return `ValueTask`, and query
  results are an `IAsyncEnumerable<object>`.

## From Berkeley DB XML

### Conceptual Mapping

| Berkeley DB XML | PhoenixmlDb |
|-----------------|-------------|
| Environment / XmlManager | `DocumentDatabase` |
| XmlContainer | `IContainer` |
| XmlDocument | `IDocument` |
| XmlQueryContext variables | `IReadOnlyDictionary<string, object>` passed to `QueryAsync` |
| XmlResults | `IAsyncEnumerable<object>` returned by `QueryAsync` |
| XmlTransaction | `IWriteTransaction` from `BeginWriteAsync` |

### Code Migration

**Berkeley DB XML:**
```c++
XmlManager mgr;
XmlContainer container = mgr.openContainer("products.dbxml");
XmlDocument doc = mgr.createDocument();
doc.setContent("<product><name>Widget</name></product>");
container.putDocument(doc, context);

XmlQueryContext qc = mgr.createQueryContext();
XmlResults results = mgr.query("collection('products')//name", qc);
```

**PhoenixmlDb:**
```csharp
var container = await db.CreateContainerAsync("products");
await container.PutDocumentAsync("p1.xml", "<product><name>Widget</name></product>");

await foreach (var item in container.QueryAsync("collection()//name"))
{
    Console.WriteLine(item);
}
```

### Index Migration

Indexes are declared when the container is created. Documents written before an index is
declared are not indexed retroactively. Index maintenance runs only once the
`PhoenixmlDb.Indexing` package is attached with `db.EnableIndexing()`; without it,
`ContainerOptions.Indexes` is declarative only.

```csharp
using PhoenixmlDb.Indexing;

db.EnableIndexing();

// Berkeley DB XML index specification: "node-element-equality-string" on name
// Nearest PhoenixmlDb equivalent: a path index plus a typed value index
var container = await db.CreateContainerAsync("products", options =>
{
    options.Indexes
        .AddPathIndex("//product/name")
        .AddValueIndex("//product/name", XdmValueType.XdmString);
});
```

### Data Migration

```csharp
// Export from Berkeley DB XML (using their tools)
// Import to PhoenixmlDb:
var container = await db.OpenOrCreateContainerAsync("products");

foreach (var file in Directory.GetFiles("./export", "*.xml"))
{
    var name = Path.GetFileName(file);
    var content = await File.ReadAllTextAsync(file);
    await container.PutDocumentAsync(name, content);
}
```

## From eXist-db

### Conceptual Mapping

| eXist-db | PhoenixmlDb |
|----------|-------------|
| Database | `DocumentDatabase` |
| Collection | Container (flat; use path-style document names such as `orders/2024/o1.xml` and `ListDocumentsAsync(prefix)` in place of sub-collections) |
| Resource | Document |
| XQuery | XQuery |

### Code Migration

**eXist-db (Java):**
```java
Collection collection = DatabaseManager.getCollection("xmldb:exist:///db/products");
XMLResource resource = (XMLResource) collection.createResource("p1.xml", "XMLResource");
resource.setContent("<product/>");
collection.storeResource(resource);

XQueryService service = (XQueryService) collection.getService("XQueryService", "1.0");
ResourceSet result = service.query("//product");
```

**PhoenixmlDb:**
```csharp
var container = await db.CreateContainerAsync("products");
await container.PutDocumentAsync("p1.xml", "<product/>");

await foreach (var item in container.QueryAsync("collection()//product"))
{
    Console.WriteLine(item);
}
```

## From MarkLogic

### Conceptual Mapping

| MarkLogic | PhoenixmlDb |
|-----------|-------------|
| Database | `DocumentDatabase` |
| Collection | Container, or document metadata for tag-style grouping |
| Document | Document |
| Range Index | Value index (`AddValueIndex`) |
| Element Index | Name or path index (`AddNameIndex`, `AddPathIndex`) |

### Code Migration

**MarkLogic (XQuery):**
```xquery
xdmp:document-insert("/products/p1.xml", <product/>,
    (), "products")

for $p in fn:collection("products")//product
return $p
```

**PhoenixmlDb:**
```csharp
var container = await db.OpenOrCreateContainerAsync("products");
await container.PutDocumentAsync("products/p1.xml", "<product/>");

await foreach (var item in container.QueryAsync("collection()//product"))
{
    Console.WriteLine(item);
}
```

## From MongoDB

### Conceptual Mapping

| MongoDB | PhoenixmlDb |
|---------|-------------|
| Database | `DocumentDatabase` |
| Collection | Container |
| Document (BSON) | Document (XML/JSON) |
| Find query | XQuery/XPath |

### Data Migration

`PutDocumentAsync` detects JSON content. A JSON document is stored in the XQuery 3.1
`fn:json-to-xml` representation: elements named `map`, `array`, `string`, `number`, `boolean`
and `null` in the `http://www.w3.org/2005/xpath-functions` namespace, with object members
identified by a `key` attribute.

```csharp
// Export from MongoDB as JSON
// Import to PhoenixmlDb:
var container = await db.CreateContainerAsync("products");

foreach (var doc in mongoCollection.Find(_ => true).ToEnumerable())
{
    var json = doc.ToJson();
    await container.PutDocumentAsync($"{doc["_id"]}.json", json,
        new DocumentOptions { ContentType = ContentType.Json });
}
```

### Query Migration

**MongoDB:**
```javascript
db.products.find({ category: "Electronics", price: { $lt: 100 } })
```

**PhoenixmlDb:**
```xquery
declare namespace j = "http://www.w3.org/2005/xpath-functions";

for $p in collection()/j:map
where $p/j:string[@key = 'category'] = 'Electronics'
  and xs:decimal($p/j:number[@key = 'price']) < 100
return $p
```

## From SQL/Relational

### Data Export

```sql
-- Export as XML
SELECT * FROM Products
FOR XML PATH('product'), ROOT('products')
```

### Import to PhoenixmlDb

```csharp
var container = await db.OpenOrCreateContainerAsync("products");

// Store entire export
await container.PutDocumentAsync("products.xml", exportedXml);

// Or individual documents
foreach (DataRow row in table.Rows)
{
    var xml = $"""
        <product id="{row["Id"]}">
            <name>{row["Name"]}</name>
            <price>{row["Price"]}</price>
        </product>
        """;
    await container.PutDocumentAsync($"p{row["Id"]}.xml", xml);
}
```

Values interpolated into XML this way must be escaped (for example with
`System.Security.SecurityElement.Escape`) if they can contain `<`, `&` or quotes.

### Query Migration

**SQL:**
```sql
SELECT Name, Price FROM Products
WHERE Category = 'Electronics'
ORDER BY Price DESC
```

**XQuery:**
```xquery
for $p in collection()//product
where $p/category = 'Electronics'
order by xs:decimal($p/price) descending
return <result>
    <name>{$p/name/text()}</name>
    <price>{$p/price/text()}</price>
</result>
```

## Migration Checklist

### Planning

- [ ] Document current schema/structure
- [ ] Map concepts to PhoenixmlDb
- [ ] Identify required indexes
- [ ] Plan downtime window
- [ ] Create rollback plan

### Execution

- [ ] Set up PhoenixmlDb environment
- [ ] Create containers, with their indexes
- [ ] Export source data
- [ ] Transform if needed
- [ ] Import data
- [ ] Verify data integrity
- [ ] Update application code
- [ ] Test thoroughly

### Validation

- [ ] Document count matches
- [ ] Sample queries return correct results
- [ ] Performance acceptable
- [ ] All features working

## Best Practices

1. **Test in staging** — Always test migration first
2. **Validate data** — Compare counts and samples
3. **Plan indexes** — Declare them when you create the container, before importing; documents
   already stored are not indexed retroactively
4. **Batch imports** — Group writes in one transaction (`BeginWriteAsync`, `PutDocumentAsync`,
   `CommitAsync`) or use `IContainer.PutDocumentsAsync`
5. **Keep backups** — Of both source and destination (`DocumentDatabase.BackupAsync`)
6. **Monitor performance** — After migration
