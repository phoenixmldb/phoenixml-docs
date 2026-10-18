---
title: Reads During Writes
description: What a read, a query and a read transaction return while documents are written — one committed version per read, read transactions, limits on readers and running queries, and how the servers answer them
sort: 18
---

# Reads During Writes

Every read of a document returns one committed version of it. A query and a read transaction from
`BeginRead` read one committed state of the database. This page gives the rules, the limits on
readers and running queries, and the answers of the servers at those limits.

## What a read returns

A read of a document returns one committed version of it, whole: the content, the node tree, the
metadata and the header values (id, size, timestamps, content type) are as one write left them. A
write that commits while the read runs is not seen by that read.

| While the read runs | The read returns |
|---|---|
| The document is replaced | The old version or the new version; never parts of both |
| The document is deleted | The whole document, or "not found" |
| The document is deleted and stored again | The deleted document, "not found", or the new document |

A read never returns empty content for a document that has content, and never an internal error
because of a write.

This holds for every read of a document:

| Host | Reads |
|---|---|
| Embedded | `IDocument.GetContentAsync`, `GetContentStreamAsync`, `GetRootNodeAsync`, `GetMetadataAsync`, `GetAllMetadataAsync`; `IContainer.GetMetadataAsync`, `GetAllMetadataAsync`, `GetMetadataByNamespaceAsync`, `GetMetadataValuesAsync`, `GetAllMetadataEntriesAsync`; `ReadDocumentAsync`, `ReadContentAsync` ([below](#a-document-in-one-call)) |
| gRPC server | `GetDocument` by name and by id: content, metadata and timestamps of one version. `ListDocuments`: each row is the size, the timestamps and the metadata of one version; a document deleted during the listing has no row |
| REST server | `GET …/documents/{documentId}`, `…/content`, `…/metadata`: content, `ETag`, properties, tags and timestamps of one version |

## A document in one call

`ContainerReadExtensions` (namespace `PhoenixmlDb.Storage`) has two reads on `IContainer`:

| Method | Returns |
|---|---|
| `ReadDocumentAsync(name)` | A `StoredDocument`: `Info` (id, name, created, modified, size, content type), `Content` and `Metadata` (every entry; a multi-value name has one entry per value, marked `IsMultiValue`), all of one version. `null` when no document has the name |
| `ReadContentAsync(name)` | The content, or `null` when no document has the name |

`GetDocumentAsync` followed by `GetContentAsync` is two reads: a document deleted between them is a
`DocumentNotFoundException` from the second ([below](#a-document-object-obtained-earlier)).

With a cancelled `CancellationToken`, neither method reads anything. `ReadDocumentAsync` also checks
the token between the content and the metadata.

## A document object obtained earlier

An `IDocument` from `IContainer.GetDocumentAsync` is a handle on the document that has that name in
that container. Each read through it is one read as described in
[What a read returns](#what-a-read-returns), of the version that is current when the read starts.

| Since `GetDocumentAsync` returned, the document has been | A read through the object returns |
|---|---|
| replaced | the replacement |
| deleted | `DocumentNotFoundException`, with `Container` and `DocumentName` |
| deleted and stored again | the new document |

| Member | Value |
|---|---|
| `Name`, `Container` | Do not change |
| `Id`, `Created`, `Modified`, `SizeBytes`, `ContentType` | Those of the header last read through the object: at first the header `GetDocumentAsync` read; after `GetContentAsync`, `GetContentStreamAsync`, `GetRootNodeAsync`, `GetMetadataAsync` or `GetAllMetadataAsync` returns, those of the version that read returned. A read that throws does not change them |
| `GetContentAsync`, `GetContentStreamAsync` | Content of the current version |
| `GetRootNodeAsync` | The root of the current version; its other nodes are read later, see [Streams and node trees](#streams-and-node-trees) |
| `GetMetadataAsync`, `GetAllMetadataAsync` | Metadata of the document that has the name at the time of the call |

After a content read, `Modified`, `SizeBytes` and `Id` describe the content that read returned. If
one of them differs from the value read with the header earlier, the content is of a later version.

`DocumentDatabase.GetDocumentByIdAsync` returns `null` for the id of a deleted document, also when
another document has been stored under its name.

## Read transactions

`DocumentDatabase.BeginRead()` returns a transaction that reads the committed state at the moment
`BeginRead` is called. Everything read through it is of that state, whatever is written afterwards:

- `GetDocumentAsync`, and every read through the document it returns: content, stream, node tree,
  metadata. A document replaced after `BeginRead` is read in the version of `BeginRead`; a document
  deleted after `BeginRead` is still returned, whole; a document stored after `BeginRead` is not
  found.
- `ListDocumentsAsync`.
- `QueryAsync`: the documents, their content and their metadata (`phx:metadata`). A query in a read
  transaction does not use value indexes: it is evaluated on every document, and gives the answer it
  gives with them ([Indexing: Value Index](indexing.md#value-index)).

```csharp
using (var txn = db.BeginRead())
{
    // Both reads are of the state at BeginRead, whatever commits in between
    IDocument? doc = await txn.GetDocumentAsync(products.Id, "p1.xml");
    await foreach (var item in txn.QueryAsync(products.Id, "count(collection())"))
        Console.WriteLine(item);
}
```

What an open read transaction costs:

- It holds one of the database's reader slots ([Limits on readers](#limits-on-readers)) from
  `BeginRead` until it ends.
- While it is open, the space of every version written after `BeginRead` is not reused. Each write
  takes new space in the database file, up to the map size (`PhoenixmlDb:Storage:MapSizeMb`); at the
  map size writes fail. The space is reused after the transaction ends.

A read transaction ends when:

- it is disposed;
- its maximum lifetime is over. There is none unless one is set:
  `DocumentDatabase.BeginRead(TimeSpan maxLifetime)` for one transaction,
  `LmdbStorageOptions.ReadTransactionMaxLifetime` / `PhoenixmlDb:Storage:ReadTransactionMaxLifetimeSeconds`
  for every transaction of the database;
- its database is disposed. `Dispose` and `DisposeAsync` of the database end every read transaction
  that is still open and the read transaction of every query that is still running
  ([Queries](#queries)), after a read that is running through one has completed. When they return,
  the database directory can be opened again.

After it has ended, the transaction and every document obtained from it raise
`ObjectDisposedException`; the text says which of the three ended it. A transaction may be used
from several threads; its reads run one at a time.

The number of read transactions open at one moment is limited
([Limits on readers](#limits-on-readers)).

A read through a write transaction (`BeginWriteAsync`) reads the committed state at the moment of
that read, as one read ([What a read returns](#what-a-read-returns)).

## Streams and node trees

`GetContentStreamAsync` reads the whole content and then returns. The stream is of one version
whenever it is read, and it holds no transaction: a stream that is not disposed holds no reader
slot. The memory it holds is the UTF-8 bytes of the document.

`GetRootNodeAsync` reads the header and the document node. The other nodes are read when they are
asked for: `Parent` reads one node, `StringValue` reads the descendants of the node, each as one
read. No tree is kept in memory.

The nodes are those of the version the root came from, and never of another:

| Since `GetRootNodeAsync` returned the root, the document has been | `Parent` and `StringValue` |
|---|---|
| not written | answer |
| replaced, also by the same content | `DocumentReplacedException` (an `InvalidOperationException`; `Container`, `DocumentName`) |
| deleted and stored again | `DocumentReplacedException` |
| deleted | `DocumentNotFoundException` |

A node keeps a `StringValue` it has read once. A root obtained again reads the document as it is at
that time. A root from a document of a read transaction ([Read transactions](#read-transactions))
reads through the transaction and is not affected by writes.

The engine has no limit on the size of a document. The servers have: the REST server stores
documents up to `PhoenixmlDb:Documents:MaxDocumentSize` (default 10 MB), and the gRPC server
receives messages up to 100 MB.

## Queries

A query reads through one read transaction, opened when the query starts. The documents it lists,
the entries of a value index that name its candidates, every document it loads (its own and those
`doc()` names), their metadata (`phx:metadata`) and the statistics it is planned with are of the
state of the container at that moment. This holds for a query that is evaluated once per document
and for one that is evaluated once over the container (`fn:collection()` with an aggregate,
`order by`, `group by`, `distinct-values`); see
[Once per document or once over the container](documents-and-storage.md#once-per-document-or-once-over-the-container).

- A document replaced or deleted while the query runs is answered in the version the query started
  with.
- A document stored after the query started is not visited.
- A container that held no document when the query started answers nothing.
- An answer with a value index is the answer without it, also while documents are written.

A query runs from its start, the first `MoveNextAsync`, until its results are enumerated to the
end, its enumerator is disposed (leaving an `await foreach` early does that), it is cancelled or it
fails. While it runs it holds one reader slot ([Limits on readers](#limits-on-readers)), and no
second one. The cost of an open read transaction ([Read transactions](#read-transactions)) applies
for as long as the query is enumerated.

The number of queries running at one moment is limited (`MaxConcurrentQueries`). A query that
starts at the limit, or when no reader slot is free, fails at its start with `ReaderLimitException`.
It does not wait for a place.

A database that is disposed ends every query that is still running: the next `MoveNextAsync` of
such a query raises `ObjectDisposedException` ("The query ended: its database was disposed."), also
for an enumerator that is never disposed.

A query in a read transaction reads through the transaction, holds no slot of its own and is not
counted as a running query of the database.

### Time limits

| Host | The longest a query is enumerated |
|---|---|
| REST server | The request's `timeoutSeconds`, else the container's `QueryTimeoutSeconds`, else `PhoenixmlDb:Query:DefaultTimeoutSeconds` (30), at most `PhoenixmlDb:Query:MaxTimeoutSeconds` (300) |
| gRPC server | The request's `timeout_ms`, at most `PhoenixmlDb:Query:MaxTimeoutSeconds` (300); that maximum when the request names none. A larger `timeout_ms` is the maximum, as a larger `timeoutSeconds` is for the REST server |
| Embedded | No limit: until the caller ends the enumeration, or cancels through the `CancellationToken` |

The limit covers the whole call: for a streamed answer it includes the time the client takes to
read the results.

| Host | A query that ran for its limit |
|---|---|
| REST server | `504`, `errorCode` `QUERY_TIMEOUT` |
| gRPC server | Status `DeadlineExceeded`, on `ExecuteQuery`, `ExecutePrepared` and `ExecuteQueryStream`; the text gives the limit and names `PhoenixmlDb:Query:MaxTimeoutSeconds` |

### Running queries per API key

Both servers limit the queries one API key has running at one moment
(`PhoenixmlDb:Query:MaxConcurrentQueriesPerApiKey`, default 16; all callers together on a server
without keys). One more does not start and does not wait:

| Host | Calls counted | Answer at the limit |
|---|---|---|
| gRPC server | `ExecuteQuery`, `ExecutePrepared`, `ExecuteQueryStream` (to the end of the stream) | Status `ResourceExhausted` |
| REST server | `POST api/query`, `api/query/containers/{id}`, `api/query/execute`, `api/query/compiled/{id}/execute`, `api/query/stream` (to the end of the answer) | `503`, `errorCode` `QUERY_LIMIT_API_KEY` |

The REST server limits transformations separately (`PhoenixmlDb:Transform:MaxConcurrentTransforms`,
for the server, `503` `TRANSFORMS_UNAVAILABLE`); a transformation is not a running query.

## Limits on readers

A database has `MaxReaders` reader slots. Every read transaction that is open holds one: a read of
a document or of metadata (for the time of the read), a running query ([Queries](#queries)), a
backup, an open read transaction ([Read transactions](#read-transactions)).

| Setting | Default | Limit |
|---|---|---|
| `PhoenixmlDb:Storage:MaxReaders` (`LmdbStorageOptions.MaxReaders`) | 126 | Read transactions of every kind open at one moment |
| `PhoenixmlDb:Storage:MaxReadTransactions` (`LmdbStorageOptions.MaxReadTransactions`) | a quarter of `MaxReaders`, at most 32: 31 | Read transactions from `BeginRead` open at one moment. At least 1, at most half of `MaxReaders`; another value stops startup |
| `PhoenixmlDb:Storage:MaxConcurrentQueries` (`LmdbStorageOptions.MaxConcurrentQueries`) | half of `MaxReaders`: 63 | Queries running at one moment. At least 1, and at most `MaxReaders` less the limit on read transactions and a reserve of an eighth of `MaxReaders` (with the defaults at most 126 − 31 − 15 = 80); another value stops startup |
| `PhoenixmlDb:Storage:ReadTransactionMaxLifetimeSeconds` (`LmdbStorageOptions.ReadTransactionMaxLifetime`) | unset: no limit | The longest a read transaction from `BeginRead` stays open |

With the defaults, read transactions and running queries together hold at most 31 + 63 = 94 of the
126 reader slots. 32 are left for the reads that hold a slot for the time of one read: document and
metadata reads in progress, a backup, the full-text indexer.

A read that cannot begin because a limit is reached fails with `ReaderLimitException`
(a `PhoenixmlDbStorageException`; `SettingName`, `Limit`). Nothing is read and nothing is changed;
the read succeeds when a reader has ended.

| Limit reached | Who is refused |
|---|---|
| `MaxReaders` | Any read: a document read, a listing, a query, `BeginRead` |
| `MaxReadTransactions` | `BeginRead` only. The reads, queries and writes of other callers are not affected: at least half of the reader slots are never held by read transactions |
| `MaxConcurrentQueries` | A query, at its start. Document reads, writes, `BeginRead`, a backup and queries in a read transaction are not affected. A refused query is not queued |

| Host | `ReaderLimitException` is answered |
|---|---|
| gRPC server | Status `ResourceExhausted`, with the text of the exception (it names the setting) |
| REST server | `503`, `errorCode` `READER_LIMIT`, `setting` with the key of the limit |

## REST server: a document deleted during a request

A request that finds a document and then reads it again after it has been deleted answers `404`
with `errorCode` `NOT_FOUND` and `resourceType` `Document`. The answer carries no document name.

## gRPC server: transactions

The transactions of `TransactionService.BeginTransaction`, read-only and read-write, have limits
set under `PhoenixmlDb:Transactions` (`LeaseSeconds`, `MaxLifetimeSeconds`, `MaxOpen`,
`MaxOpenPerApiKey`; see
[Server Configuration: Transactions](deployment/server-configuration.md#grpc-server-transactions)).

- A transaction that no call has used for `LeaseSeconds` is rolled back. A use is a call that names
  the transaction: a write, a commit, a rollback. `GetTransactionStatus` is not a use.
- A transaction that has been open for `MaxLifetimeSeconds` is rolled back, used or not.
- One more `BeginTransaction` at `MaxOpen` or `MaxOpenPerApiKey` is answered `ResourceExhausted`,
  and nothing is begun for it: a refused read-write transaction does not wait for the write lock.
- A transaction whose lease or lifetime ends while a call is in flight on it is rolled back when
  that call has returned; the call completes as it would have. Calls that name the transaction
  afterwards are answered that it is not open.

A read-only transaction holds no reader slot and keeps no space from being reused while no call
reads through it. No gRPC call reads through a read-only transaction: `GetDocument`,
`ListDocuments` and the query calls read the current state, each as described in
[What a read returns](#what-a-read-returns) and [Queries](#queries).

## Next Steps

- [Transactions](transactions.md): write transactions and what is atomic
- [Documents & Storage](documents-and-storage.md): storing and retrieving documents
- [Server Configuration](deployment/server-configuration.md): every server setting
