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
using PhoenixmlDb.Core;
using PhoenixmlDb.Storage;

await using var db = new DocumentDatabase("./data");

// Simple creation
var products = await db.CreateContainerAsync("products");

// With options
var orders = await db.CreateContainerAsync("orders", opts =>
{
    opts.PreserveWhitespace = false;
    opts.DefaultNamespaces.Add("o", "http://example.com/orders");
});

// Open existing or create new
var customers = await db.OpenOrCreateContainerAsync("customers");

// Open existing only (null if it does not exist)
IContainer? archive = await db.OpenContainerAsync("archive");
```

### Container Options

| Option | Description | Default |
|--------|-------------|---------|
| `Indexes` | Index definitions for the container (see [Indexing](indexing.md)) | None |
| `PreserveWhitespace` | Keep whitespace-only text nodes in XML documents. When `false`, they are dropped on store | `false` |
| `DefaultNamespaces` | Prefix-to-URI bindings available to every query on the container. A query's own `declare namespace` overrides them | Empty |
| `DefaultMetadataNamespace` | Namespace URI that unqualified metadata names resolve to (see [Metadata](metadata.md)) | `null` |
| `ValidationMode` | `None`, `WellFormed` or `Schema`. Stored with the container, but storage does not currently act on it: every document is parsed when it is stored, whatever the mode | `None` |

`DefaultNamespaces` are checked when the container is created: a binding the XQuery compiler would
reject (an empty prefix, a non-NCName prefix, or one that rebinds a predeclared prefix such as `fn`,
`xs` or `phx`) makes `CreateContainerAsync` throw `ArgumentException`.

### Container Operations

```csharp
// List all containers
await foreach (var info in db.ListContainersAsync())
{
    Console.WriteLine($"{info.Name}: {info.DocumentCount} documents (created {info.Created})");
}

// Delete a container
bool deleted = await db.DeleteContainerAsync("temp-data");
```

`DeleteContainerAsync` removes the container's record and returns `false` if there was no such
container. It does not reclaim the space the container's documents occupy in `data.mdb`.

## Documents

Documents are individual XML or JSON documents stored within containers.

### Document Names

Document names are unique, case-sensitive identifiers within a container:

```csharp
// Simple names
await container.PutDocumentAsync("product.xml", xml);

// Hierarchical names (virtual paths)
await container.PutDocumentAsync("2024/01/order-001.xml", xml);
await container.PutDocumentAsync("2024/01/order-002.xml", xml);
await container.PutDocumentAsync("2024/02/order-003.xml", xml);

// List with prefix
await foreach (var doc in container.ListDocumentsAsync("2024/01/"))
{
    Console.WriteLine($"{doc.Name} ({doc.SizeBytes} bytes, {doc.ContentType})");
}
```

#### The name rule

A document name is a relative name inside its container. It is not a location. When a document is
**written**, the name is refused if it

1. is empty or only white space, or contains a control character U+0000 to U+001F;
2. has a segment that is exactly `.` or `..` when split on `/` and `\`;
3. begins with `/` or `\`;
4. begins with a drive: one letter and a colon, with or without a separator;
5. begins with a URI scheme followed by `/` or `\`;
6. begins with `file:`, `phoenixml:` or `phx-schema:` in any letter case, whatever follows;
7. is longer than **507 bytes in UTF-8**.

Nothing is decoded or normalised. The length is checked first.

| Refused | Accepted |
|---|---|
| `a/../b`, `..`, `./x`, `a/./b`, `a\..\b` | `a/b/c.xml`, `a..b`, `..x`, `x..`, `...`, `a/.../b`, `.hidden` |
| `/x`, `\x`, `//host/x`, `\\server\share\x` | `a\b.xml`, names with spaces, Unicode, `%`, `%2e%2e/x` |
| `C:\x`, `c:/x`, `C:x`, `c:`, `a:b`, `x:doc.xml` | `ab:c`, `ns:doc.xml`, `ns:a/b.xml`, `a/b:c.xml` |
| `http://x`, `https://x`, `custom:/y`, `custom:\y` | `http:x.xml`, `urn:x`, `urn:isbn:0451450523` |
| `file:///x`, `file:x.xml`, `FILE:x.xml`, `phoenixml:container/c/x`, `phx-schema:x` | `log-2026-10-10T10:00:00.xml`, `report:2026.xml`, `2026-01-02T10:30.xml` |

Accepted names are stored and read back exactly as written. For accepted names with a colon,
`doc(name)`, `doc-available(name)`, `collection(name)` and `uri-collection(name)` find the stored
document.

The engine's document URI, `phoenixml:container/<container>/<name>`, is a URI for a document. It is
refused as a name. `doc()` by that URI works.

**Maximum length.** 507 bytes of UTF-8 (`DocumentNameRules.MaxNameBytes`): 507 ASCII characters,
253 two-byte characters, 169 three-byte characters. Container names and metadata names have their
own limits (511 and 499 bytes).

To check a name in advance, call `PhoenixmlDb.Storage.DocumentNameRules.Validate(name)` or
`IsValid(name)`.

**Where the rule is checked:**

| Host | Operations |
|---|---|
| Embedded | `PutDocumentAsync` (string and stream), `PutDocumentsAsync` (each document), `PutDocumentWithMetadataValuesAsync`, the same puts on a write transaction (at the put call), `DocumentDatabase.UpdateDocumentByIdAsync`; XML and JSON |
| gRPC server | `PutDocument` (with and without a transaction), `UpdateDocument` (by name and by id), `BulkPutDocuments`. With Raft, on the node that proposes the write. |
| REST server | `POST api/containers/{id}/documents`, `PUT …/documents/{docId}`, `PUT …/documents/{docId}/content`, `POST …/versions/{v}/restore` |

The rule is not checked by reads, deletes, listings, metadata reads and writes, queries, index
maintenance and rebuild, opening a database, or the apply of a replicated command. The engine has
no rename, move or copy of a document.

**Errors:**

| Host | Answer |
|---|---|
| Embedded | `PhoenixmlDb.Storage.InvalidDocumentNameException` (an `ArgumentException`). A null name is `ArgumentNullException`. `PutDocumentAsync(name, Stream)` checks the name before it reads the stream. |
| gRPC `PutDocument`, `UpdateDocument` | `success = false`, `error` = `INVALID_DOCUMENT_NAME: ` + the message |
| gRPC `BulkPutDocuments` | the document is listed in the per-document `errors` with the same text; the other documents are stored |
| Client SDK (`PhoenixmlDb.Client`) | `PhoenixmlException` with that text |
| REST server | HTTP `400`, `application/problem+json`: `title: "Validation Error"`, `errorCode: "VALIDATION_ERROR"`, `detail` = the message, `errors: [{ field: "name", message, code: "INVALID_DOCUMENT_NAME" }]`. An empty name on create is this `400` too. |

The message has this form:

```
Document name 'a/../b' is refused: a document name is not a location. A name must not have a segment that is '.' or '..'.
```

- The name is shown as written. Control characters are shown escaped. A name over 80 characters is
  cut and its length given. No text is longer than 400 characters.
- Over-long: `A name is at most 507 bytes in UTF-8; this one is 508.`
- In a `PutDocumentsAsync` batch, a refused name fails the call. The current uncommitted batch (up to
  1000 documents) is not stored. Batches committed earlier in the same call stay stored.
- The gRPC server logs a refused name as a warning.

**Documents stored under a name the rule refuses:**

- They stay readable, listable, queryable and deletable by their exact name: get, exists, list, get
  by id, `doc()`, `doc-available()`, `collection()`, metadata set / get / query / delete, delete,
  index rebuild. A database that holds such names opens with no warning.
- They cannot be written again under that name. A put, an update by id, a gRPC `PutDocument` /
  `UpdateDocument`, a REST `PUT` or a version restore is refused with the error above and changes
  nothing.
- A REST `PUT …/documents/{docId}` of such a document is refused even when only its metadata
  differs. `PUT …/documents/{docId}/metadata` has no name check.
- To change such a document: read it, put its content under an accepted name, and delete the old
  one by its exact name. A put does not carry metadata; copy it too if needed.
- Two stored names that `doc(name)` does not find by bare name: a name of the form
  `phoenixml:container/c/x`, and `C:x`. Both are found by their own document URI and by get, list
  and delete.

**Tools and the Mobile store:**

- Tools that derive document names from file paths must pass relative names without `.` or `..`
  segments. An absolute path, a `file:` URI, a drive path or a path with `..` is refused as a
  document name.
- `PhoenixmlDb.Mobile` keeps its own local store. The rule does not apply there.

### Storing Documents

Each put runs in its own write transaction: the document is parsed into nodes, stored and (when
indexing is enabled) indexed atomically.

```csharp
// From string
await container.PutDocumentAsync("doc.xml", """
    <root>
        <item>Content</item>
    </root>
    """);

// From stream (read in full, as UTF-8 unless a byte-order mark says otherwise;
// the stream is not disposed)
await using var stream = File.OpenRead("large-file.xml");
await container.PutDocumentAsync("large.xml", stream);

// From XDocument
var xdoc = new XDocument(
    new XElement("root",
        new XElement("item", "Content")));
await container.PutDocumentAsync("from-xdoc.xml", xdoc.ToString());

// Insert-only: throws DocumentExistsException if the name is taken
await container.PutDocumentAsync("tracked.xml", xml, new DocumentOptions { Overwrite = false });

// Many documents: committed in batches of up to 1,000 per write transaction
int stored = await container.PutDocumentsAsync(
[
    new DocumentInput("a.xml", "<a/>"),
    new DocumentInput("b.xml", "<b/>"),
]);
```

`DocumentOptions` has three properties: `ContentType` (`Xml` or `Json`; when `null`, content starting
with `{` or `[` is treated as JSON and everything else as XML), `Overwrite` (default `true`), and
`Metadata`, an initial set of metadata values stored atomically with the document.

### Retrieving Documents

```csharp
// Get the document (null if it does not exist)
IDocument? doc = await container.GetDocumentAsync("product.xml");
if (doc is not null)
{
    string xml = await doc.GetContentAsync();
    Console.WriteLine($"{doc.Name}: {doc.SizeBytes} bytes, modified {doc.Modified}");

    // As XDocument
    XDocument xdoc = XDocument.Parse(xml);

    // As a stream
    await using var content = await doc.GetContentStreamAsync();
}

// Check existence
if (await container.DocumentExistsAsync("product.xml"))
{
    // ...
}
```

`GetContentAsync` reassembles the document from its stored nodes, so the text that comes back is a
fresh serialization, not the original bytes. `GetContentStreamAsync` serializes the whole document
into memory and returns a read-only stream over it.

Each read returns one committed version of the document, whole, also while the document is
replaced or deleted. `GetDocumentAsync` followed by `GetContentAsync` is two reads: a document
deleted between them is a `DocumentNotFoundException` from the second. `ReadDocumentAsync(name)`
(`ContainerReadExtensions`, namespace `PhoenixmlDb.Storage`) returns the header, the content and the
metadata of one version in one call. See [Reads During Writes](reads-during-writes.md).

### Document Metadata

Metadata provides additional information about documents without modifying the document content:

```csharp
// Set metadata (in the container's default metadata namespace)
await container.SetMetadataAsync("product.xml", "modifiedBy", "admin");
await container.SetMetadataAsync("product.xml", "lastModified", DateTime.UtcNow.ToString("O"));

// Get one value (null if not set)
string? author = await container.GetMetadataAsync("product.xml", "modifiedBy");

// Get everything
var all = await container.GetAllMetadataAsync("product.xml");
```

The metadata calls throw `DocumentNotFoundException` when the document does not exist. Typed values,
qualified names, multi-value metadata and metadata queries are covered in [Metadata](metadata.md).

#### Accessing Metadata from XQuery

You can also read document metadata from XQuery with the `phx:metadata()` extension function. The
`phx` prefix is predeclared, and a `dbxml:` key names a system value from the document header
(`name`, `content-type`, `created`, `modified`, `size`, `node-count`):

```xquery
(: Run with container.QueryAsync, which evaluates it once per document
   with the document as the context item :)
if (phx:metadata(., 'author') = 'admin')
then phx:metadata(., 'dbxml:name')
else ()
```

```xquery
(: All metadata as a map :)
map:keys(phx:metadata(.))

(: System values :)
phx:metadata(., 'dbxml:created')   (: creation timestamp :)
phx:metadata(., 'dbxml:size')      (: document size in bytes, as xs:integer :)
```

See [Database Extensions](database-extensions.md) for the full reference.

### Querying Documents

`QueryAsync` runs an XQuery over the container's documents, once per document or once over the
container ([below](#once-per-document-or-once-over-the-container)).

```csharp
await foreach (var item in container.QueryAsync("//product[price > 20]/name/string()"))
{
    Console.WriteLine(item);
}

// Variables are bound as external variables
var vars = new Dictionary<string, object> { ["min"] = 20 };
await foreach (var item in container.QueryAsync(
    "declare variable $min external; count(collection()//product[price > $min])", vars))
{
    Console.WriteLine(item);
}
```

Inside a container query, `doc('name.xml')` resolves a document of the same container by name.

### Once per document or once over the container

A container query is evaluated in one of two ways:

- **Once per document**, with that document as the context item, the answers concatenated in
  document order: a query that does not read `fn:collection()`, and a query that reads it but whose
  every answer depends on one document at a time (`collection()/book[price > 15]/title`).
- **Once over the container**, with `fn:collection()` returning every document: any other query that
  reads `fn:collection()`. That is an aggregate (`count`, `sum`, `string-join`, `distinct-values`,
  …), an `order by` or `group by`, a positional filter over the collection
  (`(collection()/book)[last()]`), or a shape the engine cannot prove to depend on one document at a
  time.

In the evaluation once per document, `fn:collection()` returns only the current document. In the
evaluation once over the container there is no context item: a query that starts from the context
item (`/book`, `./title`) and also reads `fn:collection()` where the evaluation over the container is
required raises `XPDY0002` ("the context item is absent"). Write such a query from the collection
(`collection()/book`), not from the context item.

A query reads the collection wherever `fn:collection()` is written in it, and inside an imported
module function or variable it reaches. That includes `fn:collection()` written only inside:

- a quantified expression's `in` clause (`some $x in collection()/book satisfies …`);
- a `typeswitch` case or default, a `switch` case value or result;
- a `catch` clause;
- a map constructor's key or value, a record constructor's field;
- a string constructor's `` `{…}` `` interpolation;
- a `copy` binding of a transform expression;
- a window clause's `start` or `end` `when` condition;
- an expression embedded in a full-text selection (`contains text { … }`).

The same holds for an aggregate, `position()` or `last()` written there: the query is evaluated as it
would be with that expression written at the top level.

| Query (three documents, one `book` each) | Answer |
|---|---|
| `some $x in collection()/book satisfies $x/price > 25` | `true` |
| `typeswitch (1) case xs:integer return count(collection()/book) default return 0` | `3` |
| `map { 'n': count(collection()/book) }?n` | `3` |
| `switch (1) case 1 return count(collection()/book) default return 0` | `3` |

A query nested deeper than the parser accepts (92 nested parentheses and more) is refused by the
parser with `XPST0003`. A query the parser accepts is evaluated by these rules whatever its depth.

### Updating Documents

There is no partial update: storing a document under an existing name replaces it. The previous
version's nodes, index entries and metadata index rows are reclaimed in the same transaction, and
metadata the new put does not mention is kept.

```csharp
// Full replacement
await container.PutDocumentAsync("product.xml", newXml);
```

### Deleting Documents

```csharp
// Delete single document (false if it did not exist)
bool deleted = await container.DeleteDocumentAsync("old-product.xml");

// Delete multiple documents
var names = new List<string>();
await foreach (var info in container.ListDocumentsAsync("temp/"))
{
    names.Add(info.Name);
}
foreach (var name in names)
{
    await container.DeleteDocumentAsync(name);
}
```

Deleting a document removes its header, metadata, nodes and index entries.

## JSON Documents

PhoenixmlDb stores JSON documents by converting them to the XML representation defined for
`fn:json-to-xml` (elements in the `http://www.w3.org/2005/xpath-functions` namespace):

```csharp
// Store JSON (detected from the leading '{'; or set ContentType = ContentType.Json)
await container.PutDocumentAsync("user.json", """
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

// Query JSON documents with XQuery
await foreach (var name in container.QueryAsync("""
    declare namespace j = "http://www.w3.org/2005/xpath-functions";
    /j:map[j:array[@key = 'roles']/j:string = 'admin']/j:string[@key = 'name']/string()
    """))
{
    Console.WriteLine(name);
}
```

The document keeps `ContentType.Json`, but `GetContentAsync` returns the stored XML representation,
not the original JSON.

### JSON to XML Mapping

| JSON | XML (prefix `j` = `http://www.w3.org/2005/xpath-functions`) |
|------|-----|
| `{"key": "value"}` | `<j:map><j:string key="key">value</j:string></j:map>` |
| `[1, 2, 3]` | `<j:array><j:number>1</j:number><j:number>2</j:number><j:number>3</j:number></j:array>` |
| `true` / `false` | `<j:boolean>true</j:boolean>` |
| `null` | `<j:null/>` |
| `123` | `<j:number>123</j:number>` |

A member of an object carries its name in the `key` attribute.

## Storage Options

The storage layer is backed by LMDB. `LmdbStorageOptions` (namespace `PhoenixmlDb.Storage.Lmdb`)
controls how PhoenixmlDb uses it; pass it to the `DocumentDatabase` constructor. The full list is in
[Configuration](configuration.md#all-options).

### Map Size

The map size is the virtual address space LMDB reserves for the memory-mapped file, and so the
maximum database size. It reserves address space, not memory or disk: `data.mdb` grows only as data
is written.

```csharp
var options = new LmdbStorageOptions
{
    // 10 GiB maximum
    MapSize = 10L * 1024 * 1024 * 1024
};
```

The default is 50 GiB in a 64-bit process and 1 GiB in a 32-bit process. The engine never grows the
map at runtime; when it is full, writes throw `PhoenixmlDbStorageException`. To change it, dispose
the database and reopen it with a different `MapSize`. Reopening a writable database with a
`MapSize` at or below the space its data already uses throws `LmdbMapSizeTooSmallException`.

### Sync Modes

**Normal (Default)** — committed data is synced to disk on commit.

**NoSync** — fastest writes, but committed data may be lost on a system crash:

```csharp
var options = new LmdbStorageOptions { NoSync = true };
```

> **Warning:** Use `NoSync = true` only for temporary or recoverable data.

### Read-Only Mode

```csharp
var options = new LmdbStorageOptions { ReadOnly = true };
await using var db = new DocumentDatabase("./data", options);
```

Read-only mode opens the database without write capability. The on-disk
environment is still memory-mapped, so reads are fast; only mutations are
disallowed.

**When to use:**

- Analytics or reporting workloads against a production database
- Multi-process scenarios where one writer and many readers share a directory
- Browsing a backup or snapshot without risk of accidental modification
- Embedding a fixed dataset (e.g. shipped reference data) in an application

**What works:**

- Queries
- Reading documents, metadata and container listings
- Multiple concurrent read transactions across threads and processes
- `db.Statistics`, `db.GetStorageUsage()`

**What does not work — and why:**

Read-only mode cannot create new structures on disk. **The environment and
the named databases the engine uses must already exist** — LMDB cannot
allocate them read-only.

This means you cannot open a brand-new empty directory in read-only mode
and then "fill it in" lazily. The directory must have been initialized by
a writer first.

```csharp
// ❌ This fails: the directory has no data yet, so opening throws
Directory.CreateDirectory("./fresh");
await using var db = new DocumentDatabase("./fresh", new LmdbStorageOptions { ReadOnly = true });

// ✅ This works: a writer initializes first, then a reader attaches
await using (var writer = new DocumentDatabase("./fresh"))
{
    await writer.CreateContainerAsync("my_container");
    // (writer disposes, data is on disk)
}

await using var reader = new DocumentDatabase("./fresh", new LmdbStorageOptions { ReadOnly = true });
var container = await reader.OpenContainerAsync("my_container");  // Works — container exists
```

**Multiple readers:**

PhoenixmlDb supports many concurrent readers per process and across
processes. Each reader gets a consistent snapshot at the moment its
transaction begins (see [MVCC](transactions.md#mvcc-multi-version-concurrency-control)).

A reader transaction can be held open while sub-queries open additional
short-lived read transactions on the same thread — the engine does not bind
reader slots to the calling thread, so there is no per-thread reader limit
beyond `MaxReaders` (default 126). Read transactions from `BeginRead` and running queries have
limits of their own; see [Reads During Writes: Limits on readers](reads-during-writes.md#limits-on-readers).

**Multi-process pattern:**

```csharp
// Process A — writer (long-running service)
await using var writer = new DocumentDatabase("./shared");

// Process B, C, D — readers (CLI tools, dashboards, etc.)
await using var reader = new DocumentDatabase("./shared", new LmdbStorageOptions { ReadOnly = true });
```

Within one process, a directory can be open in only one `DocumentDatabase` at a time, read-only or
not; a second open throws `LmdbEnvironmentAlreadyOpenException`.

Readers see a consistent snapshot per transaction; the writer's commits
become visible to readers that begin a transaction after the commit.

### Write Map Mode

```csharp
var options = new LmdbStorageOptions { WriteMap = true };
```

Uses a writable memory map (`MDB_WRITEMAP`) for writes. Can improve write performance but has
different crash characteristics.

### Maximum Readers and Named Databases

```csharp
var options = new LmdbStorageOptions
{
    MaxReaders = 256,    // Default: 126
    MaxDatabases = 64    // Default: 64; must be at least 16
};
```

`MaxDatabases` limits LMDB named databases, not containers: every container lives in the same
named databases, and the engine opens 16 of them (7 for storage, 9 more when indexing is enabled).

## Storage Layout

PhoenixmlDb creates these files in the database directory:

```
./data/
├── data.mdb          # Main data file
└── lock.mdb          # Lock file
```

## Backup and Recovery

Backups are **consistent while the database is being written to**: they use LMDB's native
consistent copy, inside its own read transaction. Measured: 0 of 2,400 copies taken under
concurrent writes were torn (before phoenixml #87 was fixed, 251 of 300 were). This applies to
`BackupAsync`, `BackupToStreamAsync`, `BackupService`, the gRPC admin backup and cluster snapshots.

- **Map size headroom.** A backup holds a read transaction for its whole duration, so under heavy
  writes the data file can grow while it runs. Size `MapSize` with room for write volume × backup
  duration, or a write can fail with a map-full error.
- **Disk space.** The backup is written to a staging directory (`.phoenixml-backup-*.tmp`) beside
  the destination, flushed to disk, then renamed into place, so overwriting an existing backup briefly
  needs room for both. `BackupService` removes staging directories older than an hour when it starts.
- **Write transactions.** A non-compact backup called on a thread that holds an open write
  transaction throws `InvalidOperationException`.

### File Backup (`BackupAsync`)

Writes a copy of the database to a single file. The database stays open while it runs.

```csharp
await db.BackupAsync("./backups/db-2026-01-01.mdb");
```

The destination's directory is created if needed. With `compact: true` (the default), free pages are
left out, so a database that has had many deletes produces a much smaller file (2.1 MB instead of
8.3 MB in one measurement after deleting three quarters of the data). If a compact copy finds a page
leak, it falls back to a plain copy, which is also consistent, and logs event 1010.

`PhoenixmlDb.Storage.Backup.BackupService` (a hosted `BackgroundService` configured with `BackupOptions`) runs
`BackupAsync` on an interval and prunes old backups.

### Stream Backup (`BackupToStreamAsync`)

Writes the same backup to any `Stream` — a local file, a network socket, a cloud upload stream:

```csharp
await using var fs = File.Create("./backup.mdb");
await db.BackupToStreamAsync(fs);
```

It backs up to a temporary file first, then copies that file to the stream.

### Restore

Restore into a directory that no `DocumentDatabase` has open:

```csharp
// From a backup file. Throws if ./restored already holds a database, unless overwrite is true.
await DocumentDatabase.RestoreAsync("./restored", "./backups/db-2026-01-01.mdb", overwrite: false);

// From a stream
await using var snap = File.OpenRead("./backup.mdb");
await DocumentDatabase.RestoreFromStreamAsync("./restored", snap);

// Open the restored database
await using var db = new DocumentDatabase("./restored");
```

Every restore path writes `data.mdb.restore.tmp` in the target directory, flushes it and checks its
format before replacing `data.mdb`, so an interrupted restore can't leave a half-written file. A
restore needs a stopped database: it throws `InvalidOperationException` if the database is open in
this or another process. A backup or stream in the old LMDB 0.9 format is refused with
`LmdbMigrationRequiredException`; see [Upgrading to LMDB 1.0](deployment/lmdb-upgrade.md).

A database can also restore itself when it opens: set `RestoreFromPath`, `RestoreFromDirectory` or
`RestoreFromStream` in `LmdbStorageOptions`, and the backup is restored when `data.mdb` is missing or
empty (or always, with `RestoreOverwrite = true`). `DocumentDatabase.ListBackups(directory)` lists the
`*.mdb` files in a directory, newest first.

### Offline Backup

When the database is not running, you can copy the files directly:

```bash
# Cleanest: stop the writer first, then copy
systemctl stop my-app
cp -r ./data ./backup
systemctl start my-app
```

Copying a live database directory with `cp` risks an inconsistent copy if writes happen during it.

## Disk Space Management

### Monitor Usage

```csharp
var usage = db.GetStorageUsage();
Console.WriteLine($"Used: {usage.UsedBytes / 1024 / 1024} MB");
Console.WriteLine($"Free: {usage.FreeBytes / 1024 / 1024} MB");
Console.WriteLine($"Total: {usage.MapSize / 1024 / 1024} MB ({usage.PercentUsed:F1}% used)");

var stats = db.Statistics;
Console.WriteLine($"{stats.ContainerCount} containers, {stats.TotalDocumentCount} documents, {stats.TotalNodeCount} nodes");
```

`FreeBytes` is the space left before the map is full, not free space on the disk.

## Best Practices

### Container Design

1. **Group related documents** — Put documents that are often queried together in the same container
2. **Separate by access patterns** — Different containers for read-heavy vs write-heavy data
3. **Consider index scope** — Indexes are configured per container

### Document Design

1. **Use meaningful names** — Names should identify the document content
2. **Leverage virtual paths** — Use `/` in names for logical organization and prefix listing
3. **Keep documents focused** — Don't store unrelated data in one document
4. **Use metadata** — Store non-content information as metadata

### Storage

1. **Set an appropriate MapSize** — Larger than the data you expect to hold
2. **Monitor usage** — Watch `GetStorageUsage().PercentUsed`
3. **Regular backups** — Use `BackupAsync`, `BackupToStreamAsync` or `BackupService`
4. **SSD recommended** — For production workloads

### Storage Troubleshooting

**Map full (`PhoenixmlDbStorageException`)** — Dispose the database and reopen it with a larger `MapSize`.

**Max readers reached** — Increase `MaxReaders` or ensure read transactions are being disposed.

**Slow writes** — Check disk I/O, and store many documents with `PutDocumentsAsync` (batched
transactions) rather than one put per document.
