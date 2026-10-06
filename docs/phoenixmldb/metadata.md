---
title: Metadata
description: Namespaced, typed metadata on every document
sort: 4
---

# Metadata

Every document in PhoenixmlDb can carry metadata: named, typed values stored alongside the document content. Metadata is stored in its own LMDB database (`doc_metadata`), can be indexed, and participates in transactions.

The metadata model is **namespace-key-value**, inspired by Oracle Berkeley DB XML. Every metadata name is a qualified name (`XdmQName`): a namespace plus a local name. The namespace dimension allows the same local name under different namespaces, so several systems can attach metadata to one document without colliding.

## Storing Metadata

### Simple Key-Value

```csharp
// An unqualified name goes into the container's default metadata namespace
await container.SetMetadataAsync("invoice.xml", "status", "pending");
await container.SetMetadataAsync("invoice.xml", "priority", "high");

// Retrieve
string? status = await container.GetMetadataAsync("invoice.xml", "status");
// "pending"
```

The string overloads take and return strings. An unqualified name is placed in the container's `ContainerOptions.DefaultMetadataNamespace`, or in `https://schemas.phoenixml.dev/2026/app` (`Container.DefaultApplicationMetadataNamespace`) when the container declares none. Set `DefaultMetadataNamespace` explicitly for any application that shares a database with another.

The document must already exist; setting or reading metadata on a missing document throws `DocumentNotFoundException`.

### Namespaced Keys

When several systems attach metadata to the same document, give each its own namespace. `DocumentDatabase.MetadataName` builds the qualified name, and the `XdmQName` overloads take an `XdmValue`:

```csharp
using PhoenixmlDb.Xdm;

var btStatus = db.MetadataName(container, "urn:example:biztalk", "status");
var btPort = db.MetadataName(container, "urn:example:biztalk", "port");
var appStatus = db.MetadataName(container, "urn:example:app", "status");

await container.SetMetadataAsync("message.xml", btStatus, XdmValue.From("received"));
await container.SetMetadataAsync("message.xml", btPort, XdmValue.From("ReceivePort1"));
await container.SetMetadataAsync("message.xml", appStatus, XdmValue.From("processed"));

// Both "status" names coexist: different namespaces
XdmValue? bt = await container.GetMetadataAsync("message.xml", btStatus);
string? received = bt is { } v ? XdmValue.To<string>(v) : null;
// "received"
```

`MetadataName(container, namespaceUri, localName)` resolves a `null` namespace to the container's default metadata namespace (the same one the string overloads use), treats `""` as explicitly no namespace, and interns any other URI. `db.GetOrCreateNamespaceId(uri)` returns the interned `NamespaceId` directly, for building an `XdmQName` yourself.

### Typed values

`XdmValue.From` keeps the CLR type: `string`, `bool`, `long`, `int`, `short`, `byte`, `decimal`, `double`, `float`, `DateTimeOffset`, `DateTime`, `DateOnly`, `TimeOnly`, `TimeSpan`, `Uri`, `XdmQName` and `byte[]`. Any other type throws `NotSupportedException`. A `DateTime` (from Core 2.1.0) must have `Kind` `Utc` or `Local`; `Unspecified` throws `ArgumentException`, because it names no instant. `To<DateTime>` returns the stored instant as UTC. `XdmValue.To<T>` reads a value back and throws `InvalidCastException` when the stored type doesn't match `T`.

For names you use repeatedly, a `MetadataProperty<T>` (`PhoenixmlDb.Core.Metadata`) carries the namespace, the local name and the CLR type together:

```csharp
using PhoenixmlDb.Core.Metadata;

var workflowNs = db.GetOrCreateNamespaceId("urn:example:workflow");
var created = new MetadataProperty<DateTimeOffset>(workflowNs, "created");

await container.SetMetadataAsync("report.xml", created, DateTimeOffset.UtcNow);
DateTimeOffset when = await container.GetMetadataAsync("report.xml", created);
```

### How It Works

Each entry's key is `[8-byte document id][4-byte namespace id][UTF-8 local name]`. The namespace is an interned numeric id, not a string prefix, so there is no separator and no way for a namespace to bleed into a local name. Values are stored with their XDM type.

## Retrieving Metadata

### Single Key

```csharp
// Unqualified name, container default namespace
string? value = await container.GetMetadataAsync("doc.xml", "status");

// Qualified name
XdmValue? typed = await container.GetMetadataAsync("doc.xml", db.MetadataName(container, "urn:example:source", "type"));
```

### All Metadata

```csharp
MetadataCollection all = await container.GetAllMetadataAsync("doc.xml");

foreach (var (name, value) in all)
{
    Console.WriteLine($"{db.GetNamespaceUri(name.Namespace)} {name.LocalName} = {value}");
}
```

`MetadataCollection` is keyed by `XdmQName`, and `ByNamespace` groups the entries by namespace.

### Filter by Namespace

```csharp
var sourceNs = db.GetOrCreateNamespaceId("urn:example:source");
MetadataCollection sourceMeta = await container.GetMetadataByNamespaceAsync("doc.xml", sourceNs);
```

## Querying by Metadata

Find the documents that hold a given metadata value:

```csharp
var status = db.MetadataName(container, null, "status");

await foreach (DocumentInfo doc in container.QueryMetadataAsync(status, XdmValue.From("pending")))
{
    Console.WriteLine(doc.Name);
}

// Namespaced name
await foreach (DocumentInfo doc in container.QueryMetadataAsync(btStatus, XdmValue.From("received")))
{
    Console.WriteLine(doc.Name);
}
```

`QueryMetadataRangeAsync(name, lowerBound, upperBound, lowerInclusive, upperInclusive)` finds documents whose value falls in a range. Both methods also have `MetadataProperty<T>` overloads.

## Metadata in Transactions

Metadata writes participate in write transactions. Operations are buffered and applied together at `CommitAsync`:

```csharp
var workflowStatus = db.MetadataName(container, "urn:example:workflow", "status");
var workflowStep = db.MetadataName(container, "urn:example:workflow", "step");

await using var txn = await db.BeginWriteAsync();

// Store a document and set its metadata atomically
await txn.PutDocumentAsync(container.Id, "order.xml", orderXml);
await txn.SetMetadataAsync(container.Id, "order.xml", workflowStatus, XdmValue.From("new"));
await txn.SetMetadataAsync(container.Id, "order.xml", workflowStep, XdmValue.From("validation"));

await txn.CommitAsync();
// Both document and metadata are committed together, or neither is
```

A document put earlier in the same transaction counts as existing for `SetMetadataAsync`. Metadata can also be supplied with the document itself through `DocumentOptions.Metadata`.

## Metadata Indexing

Metadata names can be indexed for fast lookups. `AddMetadataIndex` takes a qualified `XdmQName` (`PhoenixmlDb.Xdm`), not a bare or colon-separated string. The namespace dimension that keeps two systems' `status` names apart in storage is the same one the index is keyed on:

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Xdm;

const string appNs = "urn:example:app";
var appNsId = db.GetOrCreateNamespaceId(appNs);
var biztalkNs = db.GetOrCreateNamespaceId("urn:example:biztalk");
var workflowNs = db.GetOrCreateNamespaceId("urn:example:workflow");

var container = await db.OpenOrCreateContainerAsync("orders", opts =>
{
    opts.DefaultMetadataNamespace = appNs; // where SetMetadataAsync(doc, "status", ...) writes
    opts.Indexes
        .AddMetadataIndex(new XdmQName(appNsId, "status"), XdmValueType.XdmString)
        .AddMetadataIndex(new XdmQName(biztalkNs, "status"), XdmValueType.XdmString)
        .AddMetadataIndex(new XdmQName(workflowNs, "step"), XdmValueType.XdmString);
});
```

`OpenOrCreateContainerAsync` applies `configure` only when it creates the container; an existing container keeps the indexes it was created with.

`QueryMetadataAsync` and `QueryMetadataRangeAsync` use a matching index when indexing is enabled for the process (`db.EnableIndexing()`) and the container's indexes are not stale; otherwise they scan. Either way they return the same documents. See [Indexing](indexing.md).

## Accessing Metadata in XQuery

The `phx:metadata()` function retrieves metadata from within XQuery expressions. The engine binds
the `phx` prefix on every query path, so no prolog declaration is needed. **Every form takes the
node whose document you are asking about** — there is no single-argument key-only form:

```xquery
(: Get metadata for the current document :)
phx:metadata(., 'status')

(: A system name from the document header: name, content-type, created, modified, size, node-count :)
phx:metadata(., 'dbxml:name')

(: Any namespace, written in full :)
phx:metadata(., 'Q{https://example.com/biztalk}status')

(: Filter documents by metadata :)
for $doc in collection('orders')
where phx:metadata($doc, 'workflow:status') = 'pending'
return $doc

(: All of a document's metadata, as a map :)
phx:metadata(.)
```

A key written as `prefix:local` resolves `prefix` through the container's
`ContainerOptions.DefaultNamespaces`. **A prefix that is not bound there raises `FONS0004`** — it
does not quietly return nothing. Use `Q{uri}local` when you do not control the container's
bindings, and an unprefixed key for the container's default metadata namespace. `dbxml:` is the
exception: it always resolves to the engine's metadata namespace, whatever it is bound to.

Values come back in their lexical (string) form, except `dbxml:size` and `dbxml:node-count`, which
come back as integers. `phx:metadata()` does not use metadata indexes.

## Use Cases

### Enterprise Integration (BizTalk Migration)

BizTalk message context properties map directly to namespaced metadata:

```csharp
const string Bts = "http://schemas.microsoft.com/BizTalk/2003/system-properties";

await container.SetMetadataAsync("msg.xml", db.MetadataName(container, Bts, "MessageType"), XdmValue.From(messageType));
await container.SetMetadataAsync("msg.xml", db.MetadataName(container, Bts, "ReceivePortName"), XdmValue.From(portName));
await container.SetMetadataAsync("msg.xml", db.MetadataName(container, Bts, "InboundTransportType"), XdmValue.From("FILE"));
await container.SetMetadataAsync("msg.xml", db.MetadataName(container, "urn:example:app", "CorrelationId"), XdmValue.From(correlationId));
```

### Document Workflow

Track document lifecycle without modifying the document content:

```csharp
XdmQName Workflow(string local) => db.MetadataName(container, "urn:example:workflow", local);

await container.SetMetadataAsync("report.xml", Workflow("status"), XdmValue.From("draft"));
await container.SetMetadataAsync("report.xml", Workflow("author"), XdmValue.From("alice"));
await container.SetMetadataAsync("report.xml", Workflow("created"), XdmValue.From(DateTimeOffset.UtcNow));

// Later...
await container.SetMetadataAsync("report.xml", Workflow("status"), XdmValue.From("reviewed"));
await container.SetMetadataAsync("report.xml", Workflow("reviewer"), XdmValue.From("bob"));
```

### Content Classification

Attach tags and categories without schema changes:

```csharp
await container.SetMetadataAsync("article.xml", db.MetadataName(container, "urn:example:taxonomy", "category"), XdmValue.From("technology"));
await container.SetMetadataValuesAsync("article.xml", db.MetadataName(container, "urn:example:taxonomy", "tags"),
    new[] { XdmValue.From("xml"), XdmValue.From("database"), XdmValue.From("dotnet") });
await container.SetMetadataAsync("article.xml", db.MetadataName(container, "urn:example:audit", "imported-from"), XdmValue.From("legacy-cms"));
await container.SetMetadataAsync("article.xml", db.MetadataName(container, "urn:example:audit", "import-date"), XdmValue.From(DateTimeOffset.UtcNow));
```

`SetMetadataValuesAsync` (`PhoenixmlDb.Storage.ContainerMetadataExtensions`) stores a set of values under one name, and `GetMetadataValuesAsync` reads them back. `GetAllMetadataAsync` keeps only one value per name, so use `GetAllMetadataEntriesAsync` when a multi-value name must come back whole.

## Best Practices

1. **Use namespaces** for metadata from different systems or concerns, and set `DefaultMetadataNamespace` on every container
2. **Index the names you query** with `QueryMetadataAsync`; unindexed metadata queries scan the container
3. **Use transactions** for multi-key updates that must be atomic
4. **Store typed values** (`DateTimeOffset`, `long`, `decimal`) rather than formatted strings, so range queries compare them correctly

## Next Steps

| Storage | Querying | Extensions |
|---------|----------|------------|
| **[Documents & Storage](documents-and-storage.md)**<br>Document operations | **[Indexing](indexing.md)**<br>Index optimization | **[Database Extensions](database-extensions.md)**<br>phx:metadata() function |
