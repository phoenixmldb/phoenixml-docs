---
title: Documents & Storage
description: Storing and retrieving XML and JSON documents in containers
sort: 2
---

# Documents & Storage

Documents and containers are the fundamental organizational units in PhoenixmlDb. This page covers container and document operations as well as the LMDB storage layer options that control durability, performance, and disk usage.

## Containers

A container is a logical grouping of related documents, similar to a table in a relational database or a collection in MongoDB.

### Creating Containers

```csharp
// Simple creation
var products = db.CreateContainer("products");

// With options
var orders = db.CreateContainer("orders", new ContainerOptions
{
    ValidationMode = ValidationMode.WellFormed,  // or Schema, DTD, None
    PreserveWhitespace = false,
    DefaultNamespaces = new Dictionary<string, string>
    {
        [""] = "http://example.com/orders",
        ["xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    }
});

// Open existing or create new
var customers = db.OpenOrCreateContainer("customers");
```

### Container Options

| Option | Description | Default |
|--------|-------------|---------|
| `ValidationMode` | Document validation level | `WellFormed` |
| `PreserveWhitespace` | Keep whitespace-only text nodes | `true` |
| `DefaultNamespaces` | Default namespace bindings | Empty |
| `IndexOnStore` | Auto-index documents on store | `true` |

### Container Operations

```csharp
// List all containers
foreach (var name in db.ListContainers())
{
    Console.WriteLine(name);
}

// Get container info
var info = db.GetContainerInfo("products");
Console.WriteLine($"Documents: {info.DocumentCount}");
Console.WriteLine($"Size: {info.SizeBytes} bytes");

// Delete container (removes all documents and indexes)
db.DeleteContainer("temp-data");
```

## Documents

Documents are individual XML or JSON files stored within containers.

### Document Names

Document names are unique identifiers within a container:

```csharp
// Simple names
container.PutDocument("product.xml", xml);

// Hierarchical names (virtual paths)
container.PutDocument("2024/01/order-001.xml", xml);
container.PutDocument("2024/01/order-002.xml", xml);
container.PutDocument("2024/02/order-003.xml", xml);

// List with prefix
var januaryOrders = container.ListDocuments(prefix: "2024/01/");
```

### Storing Documents

```csharp
// From string
container.PutDocument("doc.xml", """
    <root>
        <item>Content</item>
    </root>
    """);

// From stream (for large documents)
using var stream = File.OpenRead("large-file.xml");
container.PutDocument("large.xml", stream);

// From XDocument
var xdoc = new XDocument(
    new XElement("root",
        new XElement("item", "Content")));
container.PutDocument("from-xdoc.xml", xdoc);

// With metadata
container.PutDocument("tracked.xml", xml, new DocumentMetadata
{
    ["author"] = "system",
    ["created"] = DateTime.UtcNow.ToString("O"),
    ["version"] = "1.0",
    ["tags"] = "important,reviewed"
});
```

### Retrieving Documents

```csharp
// Get as string
string xml = container.GetDocument("product.xml");

// Get as XDocument
XDocument xdoc = container.GetDocumentAsXDocument("product.xml");

// Get as stream (for large documents)
using var stream = container.GetDocumentAsStream("large.xml");

// Check existence
if (container.DocumentExists("product.xml"))
{
    // ...
}

// Try get pattern
if (container.TryGetDocument("product.xml", out var doc))
{
    Console.WriteLine(doc);
}
```

### Document Metadata

Metadata provides additional information about documents without modifying the document content:

```csharp
// Set metadata
container.SetMetadata("product.xml", new DocumentMetadata
{
    ["lastModified"] = DateTime.UtcNow.ToString("O"),
    ["modifiedBy"] = "admin"
});

// Get metadata
var metadata = container.GetMetadata("product.xml");
Console.WriteLine($"Author: {metadata["author"]}");
Console.WriteLine($"Created: {metadata["created"]}");

// Update single metadata value
container.SetMetadataValue("product.xml", "version", "2.0");

// Query by metadata (C# API)
var recentDocs = db.Query("""
    for $doc in collection('products')
    where doc-metadata($doc, 'author') = 'admin'
    return document-uri($doc)
    """);
```

#### Accessing Metadata from XQuery

You can also access document metadata directly from XQuery using the `dbxml:metadata()` extension function:

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";

(: Get a specific metadata value :)
for $doc in collection('products')
where dbxml:metadata($doc, "author") = "admin"
return dbxml:metadata($doc, "dbxml:name")

(: Get all metadata as a map :)
let $meta := dbxml:metadata($doc)
return map:keys($meta)

(: Access system metadata :)
dbxml:metadata($doc, "dbxml:created")    (: creation timestamp :)
dbxml:metadata($doc, "dbxml:size")       (: document size in bytes :)
```

See [Database Extensions](database-extensions.md) for the full reference.

### Updating Documents

```csharp
// Full replacement
container.PutDocument("product.xml", newXml);

// Partial update with XQuery Update
db.Execute("""
    let $product := doc('products/product.xml')/product
    return (
        replace value of node $product/price with 29.99,
        insert node <discount>10%</discount> after $product/price
    )
    """);
```

### Deleting Documents

```csharp
// Delete single document
container.DeleteDocument("old-product.xml");

// Delete multiple documents
foreach (var name in container.ListDocuments(prefix: "temp/"))
{
    container.DeleteDocument(name);
}

// Delete with XQuery
db.Execute("""
    for $doc in collection('products')
    where $doc/product/discontinued = 'true'
    return delete node $doc
    """);
```

## JSON Documents

PhoenixmlDb stores JSON documents by converting them to an XML representation internally:

```csharp
// Store JSON
container.PutJsonDocument("user.json", """
    {
        "id": 1,
        "name": "Alice",
        "email": "alice@example.com",
        "roles": ["admin", "user"],
        "profile": {
            "age": 30,
            "city": "New York"
        }
    }
    """);

// Retrieve as JSON
string json = container.GetJsonDocument("user.json");

// Query JSON documents with XQuery
var admins = db.Query("""
    for $user in collection('users')/json
    where $user/roles/item = 'admin'
    return $user/name/text()
    """);
```

### JSON to XML Mapping

| JSON | XML |
|------|-----|
| `{"key": "value"}` | `<json><key>value</key></json>` |
| `[1, 2, 3]` | `<array><item>1</item><item>2</item><item>3</item></array>` |
| `true` / `false` | `<value type="boolean">true</value>` |
| `null` | `<value type="null"/>` |
| `123` | `<value type="number">123</value>` |

## Storage Options

The storage layer is backed by LMDB. The following options control how PhoenixmlDb uses it.

### Map Size

The map size determines the maximum database size. LMDB uses memory-mapped files, so this should be set larger than your expected data size.

```csharp
var options = new DatabaseOptions
{
    // 10 GB maximum
    MapSize = 10L * 1024 * 1024 * 1024
};
```

| Data Size | Recommended MapSize |
|-----------|---------------------|
| < 100 MB | 256 MB |
| 100 MB – 1 GB | 2 GB |
| 1 GB – 10 GB | 20 GB |
| 10 GB – 100 GB | 200 GB |
| > 100 GB | 2× expected size |

> **Note:** MapSize can be increased later, but cannot be decreased.

### Sync Modes

**Normal (Default)** — full durability, all data synced to disk on commit:

```csharp
var options = new DatabaseOptions
{
    NoSync = false,
    NoMetaSync = false
};
```

**NoMetaSync** — metadata not synced; slightly faster, data still durable:

```csharp
var options = new DatabaseOptions { NoMetaSync = true };
```

**NoSync** — fastest writes, but data may be lost on crash:

```csharp
var options = new DatabaseOptions { NoSync = true };
```

> **Warning:** `NoSync = true` may result in data loss on process crash. Use only for temporary or recoverable data.

| Mode | Durability | Performance |
|------|------------|-------------|
| Normal | Full | Baseline |
| NoMetaSync | High | ~10% faster |
| NoSync | Low | ~50% faster |

### Read-Only Mode

```csharp
var options = new DatabaseOptions { ReadOnly = true };
```

Useful for analytics workloads, backup processes, and multi-process read access.

### Write Map Mode

```csharp
var options = new DatabaseOptions { WriteMap = true };
```

Uses a writable memory map for writes. Can improve performance but may corrupt the database if the process crashes during a write.

### Maximum Readers and Containers

```csharp
var options = new DatabaseOptions
{
    MaxReaders = 256,    // Default: 126
    MaxContainers = 100  // Each index also uses a slot
};
```

### File Locking

```csharp
var options = new DatabaseOptions { NoLock = true };
```

> **Warning:** Only use when you can guarantee single-process access.

## Storage Layout

PhoenixmlDb creates these files in the database directory:

```
./data/
├── data.mdb          # Main data file
├── lock.mdb          # Lock file
├── phoenixmldb.json  # Configuration (optional)
└── logs/             # Log files (optional)
```

## Backup and Recovery

### Online Backup

```csharp
// Create consistent backup while database is active
db.Backup("./backup");
```

### Offline Backup

```bash
# Stop application, then copy files
cp -r ./data ./backup
```

### Recovery

```csharp
// Restore from backup
if (Directory.Exists("./backup"))
{
    Directory.Delete("./data", true);
    Directory.Move("./backup", "./data");
}

using var db = new XmlDatabase("./data");
```

## Disk Space Management

### Monitor Usage

```csharp
var stats = db.GetStatistics();
Console.WriteLine($"Used: {stats.UsedBytes / 1024 / 1024} MB");
Console.WriteLine($"Free: {stats.FreeBytes / 1024 / 1024} MB");
Console.WriteLine($"Total: {stats.MapSize / 1024 / 1024} MB");
```

### Compact and Resize

```csharp
// Reclaim unused space
db.Compact();

// Increase map size (must be larger than current)
db.Resize(20L * 1024 * 1024 * 1024);
```

## Platform-Specific Settings

**Linux:**

```csharp
var options = new DatabaseOptions
{
    // Use direct I/O for better performance
    Flags = LmdbFlags.NoReadAhead
};
```

**macOS:**

```csharp
var options = new DatabaseOptions
{
    // macOS has limited mmap - set appropriate MapSize
    MapSize = 2L * 1024 * 1024 * 1024
};
```

## Best Practices

### Container Design

1. **Group related documents** — Put documents that are often queried together in the same container
2. **Separate by access patterns** — Different containers for read-heavy vs write-heavy data
3. **Consider index scope** — Indexes are container-specific

### Document Design

1. **Use meaningful names** — Names should identify the document content
2. **Leverage virtual paths** — Use `/` in names for logical organization
3. **Keep documents focused** — Don't store unrelated data in one document
4. **Use metadata** — Store non-content information as metadata

### Storage

1. **Set appropriate MapSize** — Larger than expected data, but not excessive
2. **Use NoMetaSync for performance** — If slight crash risk is acceptable
3. **Monitor disk space** — Ensure sufficient free space
4. **Regular backups** — Use online backup for consistency
5. **SSD recommended** — For production workloads

### Storage Troubleshooting

**"Map full" error** — Increase MapSize:

```csharp
db.Resize(currentMapSize * 2);
```

**"Max readers reached"** — Increase `MaxReaders` or ensure read transactions are being disposed.

**Slow writes** — Check disk I/O, consider `NoMetaSync`, or batch multiple writes in a single transaction.
