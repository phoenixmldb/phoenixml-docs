---
title: Metadata
description: Unlimited namespace-key-value metadata on every document
sort: 4
---

# Metadata

Every document in PhoenixmlDb can carry unlimited metadata — arbitrary key-value pairs stored alongside the document content. Metadata is stored in a dedicated LMDB database, indexed for fast lookups, and participates in ACID transactions.

The metadata model uses a **namespace-key-value** pattern inspired by Oracle Berkeley DB XML. The namespace dimension allows the same key name under different namespaces — critical for enterprise integrations where multiple systems attach metadata to the same document.

## Storing Metadata

### Simple Key-Value

```csharp
// Set metadata with a flat key
await container.SetMetadataAsync("invoice.xml", "status", "pending");
await container.SetMetadataAsync("invoice.xml", "priority", "high");

// Retrieve
var status = await container.GetMetadataAsync("invoice.xml", "status");
// "pending"
```

### Namespaced Keys

When multiple systems need to attach metadata to the same document, use namespaced keys to avoid collisions:

```csharp
// BizTalk context properties
await container.SetMetadataAsync("message.xml", "biztalk", "status", "received");
await container.SetMetadataAsync("message.xml", "biztalk", "port", "ReceivePort1");

// Custom application metadata
await container.SetMetadataAsync("message.xml", "app", "status", "processed");
await container.SetMetadataAsync("message.xml", "app", "processor", "OrderService");

// Both "status" keys coexist — different namespaces
var btStatus = await container.GetMetadataAsync("message.xml", "biztalk", "status");
// "received"

var appStatus = await container.GetMetadataAsync("message.xml", "app", "status");
// "processed"
```

### How It Works

Namespaced keys are stored as `"namespace:key"` strings in LMDB. The colon is the separator. This means:

- `SetMetadataAsync("doc", "source", "type", "api")` stores key `"source:type"` with value `"api"`
- `SetMetadataAsync("doc", "status", "active")` stores key `"status"` with value `"active"` (flat key, no namespace)
- Both forms coexist on the same document

## Retrieving Metadata

### Single Key

```csharp
// Flat key
var value = await container.GetMetadataAsync("doc.xml", "status");

// Namespaced key
var value = await container.GetMetadataAsync("doc.xml", "source", "type");
```

### All Metadata

```csharp
var allMeta = await container.GetAllMetadataAsync("doc.xml");
// Returns: { "status": "active", "source:type": "api", "source:path": "/data/imports" }
```

### Filter by Namespace

```csharp
var sourceMeta = await container.GetMetadataByNamespaceAsync("doc.xml", "source");
// Returns only keys starting with "source:":
// { "source:type": "api", "source:path": "/data/imports" }
```

## Querying by Metadata

Find documents that have a specific metadata value:

```csharp
// Find all documents with status = "pending"
await foreach (var doc in container.QueryMetadataAsync("status", "pending"))
{
    Console.WriteLine(doc.Name);
}

// Find documents in a namespace
await foreach (var doc in container.QueryMetadataAsync("biztalk:status", "received"))
{
    Console.WriteLine(doc.Name);
}
```

## Metadata in Transactions

Metadata operations participate in ACID transactions:

```csharp
await using var txn = await db.BeginWriteAsync();

// Store document and set metadata atomically
await txn.PutDocumentAsync(containerId, "order.xml", orderXml);
await txn.SetMetadataAsync(containerId, "order.xml", "workflow", "status", "new");
await txn.SetMetadataAsync(containerId, "order.xml", "workflow", "step", "validation");

await txn.CommitAsync();
// Both document and metadata are committed together — or neither is
```

## Metadata Indexing

Metadata keys can be indexed for fast lookups:

```csharp
var container = await db.OpenOrCreateContainerAsync("orders", opts =>
{
    opts.Indexes
        .AddMetadataIndex("status", XdmValueType.XdmString)
        .AddMetadataIndex("biztalk:status", XdmValueType.XdmString)
        .AddMetadataIndex("workflow:step", XdmValueType.XdmString);
});
```

Indexed metadata queries use the B+ tree index instead of scanning all documents.

## Accessing Metadata in XQuery

The `dbxml:metadata()` function retrieves metadata from within XQuery expressions:

```xquery
(: Get metadata for the current document :)
dbxml:metadata('status')

(: Get namespaced metadata :)
dbxml:metadata('biztalk:status')

(: Filter documents by metadata :)
for $doc in collection('orders')
where dbxml:metadata($doc, 'workflow:status') = 'pending'
return $doc
```

## Use Cases

### Enterprise Integration (BizTalk Migration)

BizTalk message context properties map directly to namespaced metadata:

```csharp
// Store BizTalk context properties as metadata
await container.SetMetadataAsync("msg.xml", "BTS", "MessageType", messageType);
await container.SetMetadataAsync("msg.xml", "BTS", "ReceivePortName", portName);
await container.SetMetadataAsync("msg.xml", "BTS", "InboundTransportType", "FILE");
await container.SetMetadataAsync("msg.xml", "APP", "CorrelationId", correlationId);
```

### Document Workflow

Track document lifecycle without modifying the document content:

```csharp
await container.SetMetadataAsync("report.xml", "workflow", "status", "draft");
await container.SetMetadataAsync("report.xml", "workflow", "author", "alice");
await container.SetMetadataAsync("report.xml", "workflow", "created", DateTime.UtcNow);

// Later...
await container.SetMetadataAsync("report.xml", "workflow", "status", "reviewed");
await container.SetMetadataAsync("report.xml", "workflow", "reviewer", "bob");
```

### Content Classification

Attach tags and categories without schema changes:

```csharp
await container.SetMetadataAsync("article.xml", "taxonomy", "category", "technology");
await container.SetMetadataAsync("article.xml", "taxonomy", "tags", "xml,database,dotnet");
await container.SetMetadataAsync("article.xml", "audit", "imported-from", "legacy-cms");
await container.SetMetadataAsync("article.xml", "audit", "import-date", DateTime.UtcNow);
```

## Best Practices

1. **Use namespaces** for metadata from different systems or concerns
2. **Index frequently queried keys** — unindexed metadata queries scan all documents
3. **Keep values small** — metadata is serialized as JSON bytes in LMDB
4. **Use transactions** for multi-key updates that must be atomic
5. **Prefer string keys** — the colon convention is simple and readable

## Next Steps

| Storage | Querying | Extensions |
|---------|----------|------------|
| **[Documents & Storage](documents-and-storage.md)**<br>Document operations | **[Indexing](indexing.md)**<br>Index optimization | **[Database Extensions](database-extensions.md)**<br>dbxml:metadata() function |
