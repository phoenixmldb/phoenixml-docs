---
title: Migration Guide
description: Migrate from Berkeley DB XML, eXist-db, MarkLogic, MongoDB, or SQL
sort: 14
---

# Migration Guide

This guide helps you migrate to PhoenixmlDb from other XML databases or document stores.

## From Berkeley DB XML

PhoenixmlDb is designed as a modern replacement for Oracle Berkeley DB XML.

### Conceptual Mapping

| Berkeley DB XML | PhoenixmlDb |
|-----------------|-------------|
| Environment | XmlDatabase |
| Container | Container |
| Document | Document |
| XmlManager | XmlDatabase |
| XmlQueryContext | QueryParameters |
| XmlResults | IQueryResult |

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
using var db = new XmlDatabase("./data");
var container = db.CreateContainer("products");
container.PutDocument("p1.xml", "<product><name>Widget</name></product>");

var results = db.Query("collection('products')//name");
```

### Index Migration

```csharp
// Berkeley DB XML index specification: "node-element-equality-string"
// PhoenixmlDb equivalent:
container.CreateIndex(new PathIndex("name-idx", "/product/name"));
container.CreateIndex(new ValueIndex("name-val-idx", "/product/name", ValueType.String));
```

### Data Migration

```csharp
// Export from Berkeley DB XML (using their tools)
// Import to PhoenixmlDb:
foreach (var file in Directory.GetFiles("./export", "*.xml"))
{
    var name = Path.GetFileName(file);
    var content = File.ReadAllText(file);
    container.PutDocument(name, content);
}
```

## From eXist-db

### Conceptual Mapping

| eXist-db | PhoenixmlDb |
|----------|-------------|
| Database | XmlDatabase |
| Collection | Container |
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
using var db = new XmlDatabase("./data");
var container = db.CreateContainer("products");
container.PutDocument("p1.xml", "<product/>");

var results = db.Query("collection('products')//product");
```

## From MarkLogic

### Conceptual Mapping

| MarkLogic | PhoenixmlDb |
|-----------|-------------|
| Database | XmlDatabase |
| Collection | Container (via metadata) |
| Document | Document |
| Range Index | Value Index |
| Element Index | Path Index |

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
container.PutDocument("products/p1.xml", "<product/>");

var results = db.Query("collection('products')//product");
```

## From MongoDB

### Conceptual Mapping

| MongoDB | PhoenixmlDb |
|---------|-------------|
| Database | XmlDatabase |
| Collection | Container |
| Document (BSON) | Document (XML/JSON) |
| Find query | XQuery/XPath |

### Data Migration

```csharp
// Export from MongoDB as JSON
// Import to PhoenixmlDb:
var container = db.CreateContainer("products");

foreach (var doc in mongoCollection.Find(_ => true))
{
    var json = doc.ToJson();
    container.PutJsonDocument($"{doc["_id"]}.json", json);
}
```

### Query Migration

**MongoDB:**
```javascript
db.products.find({ category: "Electronics", price: { $lt: 100 } })
```

**PhoenixmlDb:**
```xquery
for $p in collection('products')/map
where $p/category = 'Electronics' and $p/price < 100
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
// Store entire export
container.PutDocument("products.xml", exportedXml);

// Or individual documents
foreach (var row in table.Rows)
{
    var xml = $"""
        <product id="{row["Id"]}">
            <name>{row["Name"]}</name>
            <price>{row["Price"]}</price>
        </product>
        """;
    container.PutDocument($"p{row["Id"]}.xml", xml);
}
```

### Query Migration

**SQL:**
```sql
SELECT Name, Price FROM Products
WHERE Category = 'Electronics'
ORDER BY Price DESC
```

**XQuery:**
```xquery
for $p in collection('products')//product
where $p/category = 'Electronics'
order by $p/price descending
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
- [ ] Create containers
- [ ] Export source data
- [ ] Transform if needed
- [ ] Import data
- [ ] Create indexes
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
3. **Plan indexes** — Create before importing large datasets
4. **Batch imports** — Use transactions for bulk loading
5. **Keep backups** — Of both source and destination
6. **Monitor performance** — After migration
