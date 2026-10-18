---
title: PhoenixmlDb
description: Modern embedded XML/JSON document database for .NET
sort: 2
---

# PhoenixmlDb

PhoenixmlDb is a modern, cross-platform embedded XML/JSON document database for .NET. A spiritual successor to Oracle Berkeley DB XML, it provides native document storage queried with XQuery 4.0. XSLT 3.0/4.0 transforms are available through the REST server.

## Core Features

- **XML and JSON storage** in the XQuery Data Model (XDM); JSON is stored in its `fn:json-to-xml` form
- **Full XQuery 3.1/4.0 and XSLT 3.0/4.0** — custom engines, no Saxon dependency
- **ACID transactions** with MVCC via LMDB
- **Rich indexing** — path, value, full-text, structural, name, and metadata (opt-in via `EnableIndexing()`)
- **Document metadata** — namespaced, typed name/value pairs on every document
- **Embeddable to distributed** — single-process to multi-node cluster

## Documentation

- **[Core Concepts](core-concepts.md)** — Containers, documents, the XDM, shredded storage
- **[Documents & Storage](documents-and-storage.md)** — Storing and retrieving XML and JSON
- **[JSON Support](json-support/index.md)** — JSON storage, queries, and indexing
- **[Indexing](indexing.md)** — All index types and optimization strategies
- **[Transactions](transactions.md)** — ACID guarantees, MVCC, and transaction patterns
- **[Reads During Writes](reads-during-writes.md)** — One committed version per read; read transactions; limits on readers and running queries
- **[Resource Access](resource-access.md)** — What queries and stylesheets may read beyond the stored documents
- **[XQuery Library Modules](xquery-modules.md)** — Importing library modules from files and http(s) URLs
- **[Dates and Times](dates-and-times.md)** — UTC everywhere; accepted date-time forms, API key expiry, date value indexes
- **[Deployment](deployment/index.md)** — Embedded, server, and cluster modes
- **[API Reference](api-reference/index.md)** — Interfaces, classes, and patterns
