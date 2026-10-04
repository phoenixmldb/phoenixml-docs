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
│     (Your C# Application / gRPC and REST clients)        │
├─────────────────────────────────────────────────────────┤
│                      Query Layer                         │
│   XQuery Engine │ LINQ Provider │ XSLT (EPS server)      │
├─────────────────────────────────────────────────────────┤
│               Indexing Layer (optional)                  │
│   Name │ Path │ Value │ Full-Text │ Metadata │ Structural │
├─────────────────────────────────────────────────────────┤
│                  Data Model Layer                        │
│              XQuery Data Model (XDM)                     │
├─────────────────────────────────────────────────────────┤
│                    Storage Layer                         │
│                 LMDB Key-Value Store                     │
└─────────────────────────────────────────────────────────┘
```

The indexing layer lives in `PhoenixmlDb.Indexing` and does nothing until you call
`db.EnableIndexing()` (see [Indexing](indexing.md)).

## Key Components

### Database

The top-level object that manages all data. A database maps to a directory on disk containing the
LMDB data files. The embedded entry point is `DocumentDatabase`:

```csharp
using PhoenixmlDb.Storage;

await using var db = new DocumentDatabase("./mydata");
```

A directory can be open in only one `DocumentDatabase` at a time per process; a second open of the
same path throws `LmdbEnvironmentAlreadyOpenException`.

### Containers

Logical groupings of related documents within a database. Similar to tables in relational databases or collections in document databases.

```csharp
var orders = await db.CreateContainerAsync("orders");
var customers = await db.OpenOrCreateContainerAsync("customers");
```

### Documents

Individual XML or JSON documents stored within containers. Each document has a unique name within its container.

```csharp
await container.PutDocumentAsync("order-001.xml", xmlContent);
```

### Nodes

The atomic units of the XQuery Data Model. Documents are decomposed into nodes for storage and querying.

## Shredded Node Storage

PhoenixmlDb stores XML and JSON documents using a technique called **node shredding**: each XDM node (element, attribute, text node, comment, processing instruction, document node) is serialized into its own LMDB key-value entry rather than storing the document as a serialized string. Each node record carries the IDs of its parent, attributes and children, so a document can be walked from its root node without parsing text. Index entries (when indexing is enabled) refer to node IDs.

Storing a document under an existing name replaces the whole document: the previous version's nodes and index entries are reclaimed in the same write transaction.

## The Identifier Hierarchy

Every object in PhoenixmlDb is identified by a strongly-typed integer value (all in `PhoenixmlDb.Core`):

| Type | .NET type | Allocated from |
|------|-----------|----------------|
| `ContainerId` | `uint` | A database-wide counter |
| `DocumentId` | `ulong` | A database-wide counter |
| `NodeId` | `ulong` | A database-wide counter; each document gets a contiguous range |
| `NamespaceId` | `uint` | A database-wide counter |

The value 0 (`None`) is never assigned. Document headers are keyed by container ID and document name; node entries are keyed by `NodeId` alone.

## Document Reassembly

When a document is retrieved in full (`IDocument.GetContentAsync`), PhoenixmlDb:

1. Looks up the document header by container and document name.
2. Loads the root node named in the header.
3. Follows the child and attribute IDs stored in each node record, in document order.
4. Serializes the resulting tree back to XML. JSON documents are stored as XML and come back as XML.

## Namespace Interning

Namespace URIs are **interned**: each unique URI is stored once and assigned a `NamespaceId` (`uint`). Node entries reference the `NamespaceId` rather than the full URI string. This keeps node records compact and makes namespace comparison an integer equality check rather than a string comparison.

## Data Flow

```
XML/JSON Document → Parser → XDM Nodes → Storage
                                  ↓
                     Indexing (when enabled)
                                  ↓
Query → Parser → AST → Optimizer → Executor → Results
```
