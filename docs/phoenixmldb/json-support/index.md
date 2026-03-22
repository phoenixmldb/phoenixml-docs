---
title: JSON Support
description: Store, query, and index JSON documents with PhoenixmlDb
sort: 3
---

# JSON Support

PhoenixmlDb provides full JSON document storage and querying. JSON documents stored through the container API are converted to XML internally, giving them access to the complete indexing and query infrastructure.

This means you can:
- Store JSON documents and query them with XQuery
- Get full indexing (path, value, full-text, structural) on JSON data — for free
- Mix JSON and XML documents in the same container
- Use XQuery 3.1 maps and arrays for native JSON handling

## In This Section

- **[JSON Storage](json-storage.md)** — How JSON is stored, the XML mapping, and storage options
- **[JSON Queries](json-queries.md)** — XQuery patterns for querying JSON documents
- **[JSON Indexing](json-indexing.md)** — How JSON documents get indexed and query optimization
