---
title: Core Concepts
description: Containers, documents, the XDM, and shredded node storage
sort: 1
---

# Core Concepts

Understanding the fundamental concepts of PhoenixmlDb will help you design efficient applications and write optimal queries.

## Architecture Overview

PhoenixmlDb is built on a layered architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                     │
│         (Your C# Application / gRPC Clients)            │
├─────────────────────────────────────────────────────────┤
│                      Query Layer                         │
│   XQuery Engine │ XSLT Processor │ LINQ Provider        │
├─────────────────────────────────────────────────────────┤
│                    Indexing Layer                        │
│   Path │ Value │ Full-Text │ Structural Indexes         │
├─────────────────────────────────────────────────────────┤
│                  Data Model Layer                        │
│              XQuery Data Model (XDM)                     │
├─────────────────────────────────────────────────────────┤
│                    Storage Layer                         │
│                 LMDB Key-Value Store                     │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### Database

The top-level container that manages all data. A database maps to a directory on disk containing LMDB data files.

```csharp
using var db = new XmlDatabase("./mydata");
```

### Containers

Logical groupings of related documents within a database. Similar to tables in relational databases or collections in document databases.

```csharp
var orders = db.CreateContainer("orders");
var customers = db.CreateContainer("customers");
```

### Documents

Individual XML or JSON documents stored within containers. Each document has a unique name within its container.

```csharp
container.PutDocument("order-001.xml", xmlContent);
```

### Nodes

The atomic units of the XQuery Data Model. Documents are decomposed into nodes for efficient storage and querying.

## Shredded Node Storage

PhoenixmlDb stores XML and JSON documents using a technique called **node shredding**: each XDM node (element, attribute, text node, comment, etc.) is serialized into its own LMDB key-value entry rather than storing the document as a serialized string. This design enables:

- **Fine-grained access** — queries can retrieve individual nodes without deserializing entire documents
- **Partial updates** — XQuery Update expressions (e.g., `replace value of node`) modify only the affected node entries, not the whole document
- **Efficient indexing** — index entries point directly to node-level keys, so the engine fetches only matching nodes

## The Identifier Hierarchy

Every object in PhoenixmlDb is identified by a strongly-typed integer value:

| Type | .NET type | Scope |
|------|-----------|-------|
| `ContainerId` | `uint` | Unique within a database |
| `DocumentId` | `ulong` | Unique within a container |
| `NodeId` | `ulong` | Unique within a document |

A node is fully addressed by the triple `(ContainerId, DocumentId, NodeId)`. LMDB keys are constructed from this triple, giving O(log n) lookup for any node in the database.

## Document Reassembly

When a document is retrieved in full, PhoenixmlDb performs a **tree traversal** over the structural index:

1. Resolve the `DocumentId` from the document name.
2. Fetch the document root node.
3. Walk the parent-child index recursively to emit child nodes in document order.
4. Serialize the resulting node sequence back to XML or JSON.

For query results that return only a subtree, the engine stops traversal at the requested root, so only the required nodes are read from LMDB.

## Namespace Interning

Namespace URIs are **interned**: each unique URI is stored once and assigned a `NamespaceId` (`uint`). Node entries reference the `NamespaceId` rather than the full URI string. This keeps node records compact and makes namespace-aware comparisons a fast integer equality check rather than a string comparison.

## Data Flow

```
XML Document → Parser → XDM Nodes → Storage
                           ↓
                       Indexing
                           ↓
Query → Parser → AST → Optimizer → Executor → Results
```
