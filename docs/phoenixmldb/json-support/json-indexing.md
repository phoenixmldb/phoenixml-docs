---
title: JSON Indexing
description: How JSON documents get full indexing through the XML storage path
sort: 3
---

# JSON Indexing

JSON documents stored via `PutJsonDocument()` get the full PhoenixmlDb indexing suite automatically — no separate JSON indexing infrastructure is needed. This page explains why, what gets indexed, and how to configure indexes for JSON workloads.

## The Core Insight

When you call `PutJsonDocument()`, the document goes through two steps before hitting LMDB:

1. **Conversion** — The JSON is converted to XML using the standard mapping (`{}` → `<map>`, `[]` → `<array>`, and so on).
2. **Shredding** — The XML is broken into individual XDM nodes (elements, attributes, text nodes) and stored in the node table.

From that point on, the document is indistinguishable from a natively stored XML document. The `IndexOrchestrator` walks the node tree and feeds every node into the full indexing pipeline — path index, value index, full-text index, structural index, and metadata index — exactly as it does for XML documents.

The consequence is significant: JSON gets enterprise-grade indexing for the cost of a ~5-10% write overhead on the conversion step. Query performance once indexed is identical to XML.

## What Gets Indexed

All six index types apply to JSON documents once stored:

### Name Index

Tracks every element name that appears in the document. For a JSON object with fields `email`, `price`, and `tags`, the name index records `map`, `email`, `price`, `tags`, and `_` (for array items). This powers fast existence checks and wildcard queries.

### Path Index

Records the full XPath path to each node. The path `/map/profile/city` is indexed the same way whether the document originated as JSON or XML. You use these paths directly in index definitions and XQuery predicates.

### Value Index

Typed range index over element text content. For a JSON number field like `"age": 30`, the mapped element is `<profile><age type="number">30</age></profile>`. A value index on `/map/profile/age` with `ValueType.Integer` enables fast range queries like `age > 25` without a full collection scan.

### Structural Index

Records parent-child and sibling relationships between nodes. This powers structural XPath axes (`child::`, `descendant::`, `following-sibling::`) efficiently and is built for free alongside the other indexes.

### Full-Text Index

Tokenizes text content for keyword search. A full-text index on `/map/description` enables `contains($doc/description, 'wireless')` to resolve via the index rather than scanning every document.

### Metadata Index

Document-level metadata (source, version, timestamps, custom fields) stored with `DocumentMetadata` is indexed separately and queryable via `doc-metadata()`.

## Configuring Indexes for JSON

Index definitions use XPath paths against the XML-mapped structure. The mapping is deterministic: every JSON field name becomes a child element of its parent `<map>`, and array items become `<_>` children.

### Path Index

```csharp
// Exact-match lookup on a string field
container.CreateIndex(new PathIndex("user-email-idx", "/map/email"));

// Nested object field
container.CreateIndex(new PathIndex("city-idx", "/map/profile/city"));

// Array element membership
container.CreateIndex(new PathIndex("tags-idx", "/map/tags/_"));
```

### Value Index

```csharp
// Integer range queries
container.CreateIndex(new ValueIndex("age-idx", "/map/profile/age", ValueType.Integer));

// Decimal range queries
container.CreateIndex(new ValueIndex("price-idx", "/map/price", ValueType.Decimal));

// DateTime range queries
container.CreateIndex(new ValueIndex("created-idx", "/map/createdAt", ValueType.DateTime));
```

### Full-Text Index

```csharp
// Full-text search over a text field
container.CreateIndex(new FullTextIndex("description-idx", "/map/description"));

// Full-text search over a nested field
container.CreateIndex(new FullTextIndex("bio-idx", "/map/profile/bio"));
```

## JSON-to-XML Mapping Reference

Use this table to construct XPath paths for index definitions:

| JSON construct | XML representation | Example XPath |
|---|---|---|
| Object `{}` | `<map>` with child elements | `/map` |
| Object field `"name": "Alice"` | `<name>Alice</name>` | `/map/name` |
| Nested object `"profile": {}` | `<profile>` inside `<map>` | `/map/profile` |
| Array `"tags": []` | `<tags>` containing `<_>` items | `/map/tags` |
| Array item (string) | `<_>value</_>` | `/map/tags/_` |
| Number `"price": 29.99` | `<price type="number">29.99</price>` | `/map/price` |
| Boolean `"active": true` | `<active type="boolean">true</active>` | `/map/active` |
| Null `"deletedAt": null` | `<deletedAt type="null"/>` | `/map/deletedAt` |

**Example — full document to mapped paths:**

```json
{
    "id": "u1",
    "name": "Alice",
    "profile": { "age": 30, "city": "Portland" },
    "roles": ["admin", "editor"],
    "active": true
}
```

Produces these indexable paths:

- `/map/id` — string, exact match
- `/map/name` — string, exact match or full-text
- `/map/profile/age` — integer, range queries
- `/map/profile/city` — string, exact match
- `/map/roles/_` — string, array membership
- `/map/active` — boolean, `= 'true'` comparisons

## Performance

| Concern | Detail |
|---------|--------|
| Write overhead | ~5-10% on `PutJsonDocument()` for conversion and shredding |
| Query performance | Identical to XML once indexed |
| Index build time | Same as XML — one pass over the node tree |
| Storage overhead | Slightly larger than raw JSON due to XML node structure |

For query-heavy workloads, the conversion cost on write is negligible compared to the query speedup from indexing. A full-collection scan that takes seconds becomes a sub-millisecond index lookup after a path or value index is created.

To minimize write overhead, set `PreserveOriginal = false` in `JsonStorageOptions` (saves storing the raw JSON blob alongside the XML) and `StoreArraysCompact = true` for documents with many arrays:

```csharp
container.PutJsonDocument("doc.json", json, new JsonStorageOptions
{
    PreserveOriginal = false,
    StoreArraysCompact = true
});
```

## Native JsonDocumentStore (Convenience Layer)

PhoenixmlDb also ships a `JsonDocumentStore` class for lightweight in-memory JSON work. It provides JSONPath-style queries and path-value indexes, but:

- **Not persisted** — all data lives in memory and is lost on process restart
- **No LMDB** — no memory-mapped storage, no ACID transactions
- **Volatile indexes** — indexes are rebuilt in memory and not durable

`JsonDocumentStore` is useful for scratch data, intermediate pipeline results, or tests where you want JSON convenience without database setup. For any production data that needs durability, transactions, or query performance at scale, use `PutJsonDocument()` with a container.

## Next Steps

| Storage | Queries | Containers |
|---------|---------|------------|
| **[JSON Storage](json-storage.md)**<br>Storage options and validation | **[JSON Queries](json-queries.md)**<br>XQuery patterns for JSON | **[Containers](../api-reference/containers.md)**<br>Container configuration |
