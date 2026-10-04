---
title: JSON Indexing
description: How JSON documents get full indexing through the XML storage path
sort: 3
---

# JSON Indexing

JSON documents stored with `PutDocumentAsync` are indexed by the same machinery as XML documents — there is no separate JSON indexing infrastructure. This page explains what that means, and where the XML representation limits what an index declaration can address.

## The Core Insight

When `PutDocumentAsync` stores a JSON document, it goes through two steps before reaching LMDB:

1. **Conversion** — The JSON is converted to its `fn:json-to-xml` representation: elements named `map`, `array`, `string`, `number`, `boolean` and `null` in the `http://www.w3.org/2005/xpath-functions` namespace, with each object member's name in a `key` attribute.
2. **Shredding** — The XML is broken into XDM nodes and stored in the node table.

From that point on the document is handled like a natively stored XML document. When indexing is enabled (`db.EnableIndexing()`), the indexer walks the node tree inside the same write transaction and applies the container's declared indexes, exactly as for XML.

## What Gets Indexed

Indexes are declared on `ContainerOptions.Indexes` when the container is created (see [Index API](../api-reference/indexes.md)). For a JSON document:

### Name Index

Records element names. In a JSON document these are the six mapping names (`map`, `array`, `string`, `number`, `boolean`, `null`); JSON member names are attribute *values* (`key="email"`), not element names, so they are not in the name index.

### Path and Value Indexes

Path patterns match the chain of element names from the root, using `/`, `//`, `@` and `*`; they have no predicates. A pattern can therefore address JSON structure by position — `/map/number` is every number member of a top-level object — but it cannot select a member by its key. `/map/email` matches nothing, because no element is named `email`.

```csharp
var orders = await db.CreateContainerAsync("orders", opts =>
{
    // Every number directly inside the top-level object (all numeric members)
    opts.Indexes.AddValueIndex("/map/number", XdmValueType.XdmDouble);
});
```

Declare path and value indexes on JSON containers only where the structural position alone identifies the values you query.

### Structural Index

Records parent-child and sibling relationships between nodes and accelerates axis navigation. It is enabled by default and applies to JSON documents unchanged.

### Full-Text Index

`AddFullTextIndex()` with no path pattern indexes the text of every element, which includes every JSON string value. A pattern such as `"//string"` restricts it to string values. Full-text search is through `IndexManager.SearchFullText`; see [Full-Text Search](../full-text-search.md).

```csharp
var articles = await db.CreateContainerAsync("articles", opts =>
    opts.Indexes.AddFullTextIndex("//string"));

var manager = db.EnableIndexing();
// ... store documents ...
var hits = manager.SearchFullText(articles.Id, "wireless");
```

### Metadata Index

Document metadata is independent of content and works the same for JSON and XML documents; `AddMetadataIndex` and `QueryMetadataAsync` apply unchanged. See [Metadata](../metadata.md).

## JSON-to-XML Mapping Reference

Use this table to construct query paths. Index patterns can use only the element names; the `[@key=...]` predicates are for queries.

| JSON construct | XML representation | Query path |
|---|---|---|
| Top-level object `{}` | `<map>` | `/fn:map` |
| Member `"name": "Alice"` | `<string key="name">Alice</string>` | `/fn:map/fn:string[@key='name']` |
| Nested object `"profile": {}` | `<map key="profile">` | `/fn:map/fn:map[@key='profile']` |
| Array `"tags": []` | `<array key="tags">` | `/fn:map/fn:array[@key='tags']` |
| Array item (string) | `<string>value</string>` | `/fn:map/fn:array[@key='tags']/fn:string` |
| Number `"price": 29.99` | `<number key="price">29.99</number>` | `/fn:map/fn:number[@key='price']` |
| Boolean `"active": true` | `<boolean key="active">true</boolean>` | `/fn:map/fn:boolean[@key='active']` |
| Null `"deletedAt": null` | `<null key="deletedAt"/>` | `/fn:map/fn:null[@key='deletedAt']` |

**Example — a document and its query paths:**

```json
{
    "id": "u1",
    "name": "Alice",
    "profile": { "age": 30, "city": "Portland" },
    "roles": ["admin", "editor"],
    "active": true
}
```

- `/fn:map/fn:string[@key='id']` — string
- `/fn:map/fn:string[@key='name']` — string
- `/fn:map/fn:map[@key='profile']/fn:number[@key='age']` — number
- `/fn:map/fn:map[@key='profile']/fn:string[@key='city']` — string
- `/fn:map/fn:array[@key='roles']/fn:string` — array items
- `/fn:map/fn:boolean[@key='active']` — boolean, compare with `= 'true'`

## Native JsonDocumentStore (Convenience Layer)

The `PhoenixmlDb.Json` assembly also contains `JsonDocumentStore`, an in-memory store with JSONPath-style queries and a per-document path index (`JsonStoreOptions.AutoIndex`), and a separate `JsonIndexer` class with in-memory path-value and full-text indexes. Neither is connected to `DocumentDatabase`:

- **Not persisted** — all data lives in memory and is lost when the process exits
- **No LMDB** — no memory-mapped storage, no transactions
- **Volatile indexes** — indexes exist only in memory

`JsonDocumentStore` is useful for scratch data, intermediate pipeline results, or tests. For data that needs durability, transactions or database indexes, use `PutDocumentAsync` on a container.

## Next Steps

| Storage | Queries | Containers |
|---------|---------|------------|
| **[JSON Storage](json-storage.md)**<br>Storage options and validation | **[JSON Queries](json-queries.md)**<br>XQuery patterns for JSON | **[Containers](../api-reference/containers.md)**<br>Container configuration |
