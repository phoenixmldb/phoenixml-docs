---
title: Release Notes
description: PhoenixmlDb version history and changelog
sort: 5
---

## Unreleased: database server

### Storage engine on LMDB 1.0

Since phoenixml `main` ee0c056, the storage engine uses LightningDB 0.23.1 (LMDB 1.0.1). LMDB 0.9
files (databases, Raft logs, backups, snapshots) are detected and refused with
`LmdbMigrationRequiredException`; the `PhoenixmlDb.Migrate` tool converts them. **Linux now needs
glibc 2.38 or later.** Restores are staged and checked before they replace anything, and need a
stopped database. Cluster nodes can be upgraded one at a time. Fixed: a failed open no longer
reports a false handle leak (#71). New storage events 1015–1021. See
[Upgrading to LMDB 1.0](phoenixmldb/deployment/lmdb-upgrade.md).

### Backups and snapshots are consistent during writes; `compact` works

Since phoenixml `main` dce9c56 (issues #87 and #79), backups (`BackupAsync`, `BackupToStreamAsync`,
`BackupService`, the gRPC admin backup) and cluster snapshots use LMDB's native consistent copy, so
they're safe while the database is being written to. Before this fix, 251 of 300 copies taken under
concurrent writes were torn; after it, 0 of 2,400. **Any backup taken during writes before this fix
may be inconsistent.**

- `compact: true` now leaves out free pages (it was ignored before). A compact copy that finds a
  page leak falls back to a plain copy and logs event 1010.
- Backups are staged beside the destination and renamed into place; size `MapSize` with headroom,
  because a long backup holds a read transaction while writes continue.
- New storage events 1010–1014. See
  [Backup and Recovery](phoenixmldb/documents-and-storage.md#backup-and-recovery).

### Breaking: the REST server requires authentication

Since phoenixml `main` 0d46e91 (issue #45), the REST server is **secure by default**:

- Every endpoint requires an API key (`X-Api-Key` header) or a JWT (`Authorization: Bearer`).
  Anonymous requests get `401`. Only `/health`, `/health/live` and `/health/ready` stay open,
  plus the Swagger UI in Development.
- A production host running the shipped `appsettings.json` **refuses to start until an operator
  configures a key**.
- Settings moved to the **`Auth`** section. A configuration that still has an `Authentication`
  section fails at startup, with a message saying what to rename.
- Outside Development, API keys must be at least 32 characters, and development keys are refused.

See [Server Mode: Authentication](phoenixmldb/deployment/server-mode.md#authentication) for every
setting and startup check.

The gRPC server authenticates with API keys too, and refuses to start on a network address
without one; see [Server Mode: gRPC server](phoenixmldb/deployment/server-mode.md#grpc-server).

### Security: REST permissions are enforced on every route

Since phoenixml `main` f47df75 (issue #66), the REST server checks the caller's permission on
every route. Before this, a key with `read` permission could create, overwrite and delete
documents, and with `Auth:RequireAuthentication` set to `false`, anonymous callers reached every
write route. Now `read`, `write` and `admin` routes each require that level, insufficient
permission gets `403`, and anonymous callers get read routes only. **Upgrade any server that
issues read-only keys or runs with authentication off.** See
[Server Mode: Permissions](phoenixmldb/deployment/server-mode.md#permissions).

### Clusters work over gRPC, and the Raft port serves only Raft

Since phoenixml `main` 1023078 (issue #63):

- **Fixed:** multi-node clusters over gRPC couldn't elect a leader, because every incoming Raft
  call was refused, even with the correct cluster secret. A wrong or missing secret now gets
  `Unauthenticated`.
- **Security:** the client API was also served on the Raft port, which binds every interface, so
  with Raft enabled and no API keys it was reachable from the network without authentication. The
  Raft port now serves only Raft, the client ports refuse Raft calls, and the server decides by the
  port a connection arrives on, not by the `Host` header.
- **Breaking:** the server refuses to start when Raft is enabled with no
  `PhoenixmlDb:Auth:ApiKeys`, or when `PhoenixmlDb:Raft:ListenPort` equals `Endpoints:Port` or
  `Endpoints:HttpsPort`.

See [Cluster Mode](phoenixmldb/deployment/cluster-mode.md).

### API keys are stored as hashes and can be rotated

Since phoenixml `main` 58e4b5b (issue #50), both servers take a **list** of key entries, each with
an `Id`, an optional `Expires`, and either the key's SHA-256 or the key supplied as a secret value:
`Auth:ApiKey:Clients` on the REST server, `PhoenixmlDb:Auth:ApiKeys` on the gRPC server. Several
entries can share a `Name`, which is how a key is rotated.

- **Deprecated:** the REST server's `Auth:ApiKey:Keys:<key>` shape still works for one release,
  with a startup warning. gRPC entries without an `Id` use their `Name`, with a warning.
- **Breaking for operators:** `"Key": ""` (for example a missing optional secret) now stops the
  server from starting; it used to be treated as unset. Duplicate `Id`s and two entries holding the
  same key also stop startup.

See [Server Mode: API keys](phoenixmldb/deployment/server-mode.md#api-keys).

### Breaking: queries and stylesheets can't read files or URLs by default

Since phoenixml `main` a2b9963 (issue #59), XQuery and XSLT supplied by callers can read only the
stored documents, in the embedded engine and in both servers. Local files, HTTP requests, module
and stylesheet imports by location, `xsl:evaluate`, and external DTDs and entities are denied
until the operator allows specific directories or origins
(`PhoenixmlDb:ResourceAccess:AllowedFileRoots` / `AllowedHttpOrigins` on the servers,
`DocumentDatabase.ResourceAccessPolicy` embedded). `doc()` and `collection()` of stored documents
work as before. An embedded application that relied on the old behaviour for trusted code can set
`ResourceAccessPolicy.Unrestricted`. See [Resource Access](phoenixmldb/resource-access.md).

### Breaking for monitoring: health endpoints are status-only

Since phoenixml `main` 170adf3 (issue #51), `/health`, `/health/live` and `/health/ready` return
only `Healthy` / `Degraded` / `Unhealthy` as plain text: `200`, or `503` when unhealthy. The
detailed JSON report moved to **`/health/details`**, which requires an admin credential. Anything
that parsed JSON from `/health` must call `/health/details` instead. `/health/ready` now runs the
database and engine checks; it used to always return `200`. See
[Server Mode: Health Endpoints](phoenixmldb/deployment/server-mode.md#health-endpoints).

### OpenTelemetry export

Since phoenixml `main` 1e071af:

- **Servers:** set `PhoenixmlDb:Telemetry:OtlpEndpoint` to export traces and metrics over OTLP
  (gRPC by default; `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` for HTTP). Unset, nothing changes.
  Requests get server spans with the database spans beneath them; health endpoints and the Raft
  port aren't traced. Event 3009 logs that export is on. See
  [Server Configuration](phoenixmldb/deployment/server-configuration.md#telemetry-export).
- **Embedded:** a new optional `PhoenixmlDb.OpenTelemetry` package (1.0.0-preview.1, not yet
  published) with `AddPhoenixmlDbInstrumentation` and a storage health check.
- **Query text** is off by default (`RecordQueryText`). It's exported only when every instrumented
  tracer provider in the process opted in, and a listener that subscribes without the package's
  instrumentation receives it whenever another provider opted in. See
  [Logging and Telemetry](phoenixmldb/logging.md#query-text).
- **Fixed (#88, since `main` 449c09c):** an idle server emitted about two `phoenixmldb.transaction` spans a
  second. The full-text worker now checks its queue in a read transaction and opens a write
  transaction only when work is queued: 155 spans in 75 s before, none after, and an idle server no
  longer takes the writer lock on every check.

### Telemetry and health

Since phoenixml `main` 0cd95b1, the engine publishes metrics and traces through `System.Diagnostics`
(`PhoenixmlDb.Storage`, `PhoenixmlDb.Indexing`, `PhoenixmlDb.Cluster`), and
`DocumentDatabase.GetHealth()` / `RaftNode.GetHealth()` report storage and cluster health. See
[Logging and Telemetry](phoenixmldb/logging.md#metrics-and-traces).

- **gRPC server health:** `/health` reports real status: it used to always answer Healthy.
  `/health/ready` checks storage (and Raft when enabled), `/health/details` needs admin scope, and
  `grpc.health.v1` is available. `/healthz` is a deprecated alias for one release. The TLS port now
  accepts HTTP/1.1, so HTTPS probes work. See [Server Mode](phoenixmldb/deployment/server-mode.md#health-endpoints).
- **New health codes:** `storage_map_nearly_full` (Degraded at
  `PhoenixmlDb:Health:MapUsageDegradedPercent`, default 90), `raft_no_leader`, `raft_unavailable`.
  The REST server's database check can now report Degraded.
- **`AdminService.HealthCheck`** returns the components `storage` and `raft`, instead of a fixed
  healthy set.
- **Event 3008** `HealthCheckFailed` in both servers. API-key rejection logs now come from the
  `ApiKeyAuthenticator` category.

### Logging: a logger factory, stable event ids, and server logging

Since phoenixml `main` 25fccbe, the database logs through `Microsoft.Extensions.Logging` with
**stable event ids**: Storage 1000–1009, Indexing 1100–1102, Cluster 2000–2094. Ids, names and levels
won't change once released. See [Logging](phoenixmldb/logging.md).

- **Embedded:** supply a factory with `LmdbStorageOptions.LoggerFactory`. Without one, Warning and
  above go to `System.Diagnostics.Trace` as before. `BackupFailed` (1008) is now always logged, and
  `IndexConfigurationUnreadable` (1007) includes the full exception.
- **Servers:** engine events now reach the host's logging. The gRPC server no longer logs a
  full-text indexing failure twice.
- **Changed category:** cluster events log under `PhoenixmlDb.Cluster.Raft` (previously
  `PhoenixmlDb.Cluster.Raft.RaftNode`); update filters that use the old name.
- **API:** `DocumentDatabase.LoggerFactory`, `ContainerManager(IStorageEngine, ILogger?)` and
  `ContainerRecord.Deserialize(ReadOnlySpan<byte>, ILogger?)`. The Storage package now references
  `Microsoft.Extensions.Logging.Abstractions` 10.0.9.

### REST server: resource limits, container defaults, and versioning off by default

Since phoenixml `main` b622b1c, the REST server's resource limits are configurable and validated at
startup: `PhoenixmlDb:Query`, `PhoenixmlDb:Documents`, `PhoenixmlDb:Transform` and
`PhoenixmlDb:Containers:Defaults`. See the
[Server Configuration reference](phoenixmldb/deployment/server-configuration.md#rest-server-resource-limits).

**Behaviour changes, read before upgrading:**

- **Versioning is off by default.** It used to be always on. Turn it on per container, or with
  `PhoenixmlDb:Containers:Defaults:VersioningEnabled=true`. Existing history stays readable and
  restorable; restoring with versioning off keeps no copy of the replaced content. A `MaxVersions`
  (or the old `Phoenixml:MaxVersionsPerDocument`) below 1 now stops startup instead of being raised
  to 1.
- **Container `PUT` merges settings:** a field left out keeps its stored value. Container settings
  that aren't set appear as `null` ("use the server default"). Changing `DefaultNamespaces` returns
  `400`, since namespaces are fixed at creation.
- **Document content is classified from the content itself** (XML or JSON; a leading BOM and
  whitespace are stripped). Content that is neither, or that contradicts a declared `Format`, returns
  `400`. Top-level JSON scalars are accepted. JSON is refused with `400` when the container's
  `AllowJson` is false.
- **Write-time validation** runs when the container requires it (`ValidateOnWrite`) or the request
  asks for it. It supports XSD; other schema types return `501`. A failure returns
  `400 SCHEMA_VALIDATION_ERROR` with the validator's errors, and nothing is stored. Restore applies the
  current size, JSON and validation rules.
- **Queries:** timeouts return `504 QUERY_TIMEOUT` with the limit that applied. `/api/query/execute`'s
  `maxResults`, `skip` and `timeout` parameters now take effect. Per-request `Namespaces` on a query
  or explain return `400`; declare them in the query prolog.
- **Transformations:** the response content type follows the stylesheet's output method, and output
  methods outside `AllowedOutputMethods` are refused with `400`. Since phoenixml `main` e897c06, each
  transformation runs on its own thread, so long-running or abandoned transformations no longer delay
  other requests, and `MaxConcurrentTransforms` defaults to a value based on the processor count (4 to 16).
- **Errors:** deliberate refusals return `501` (they returned `500`), and `4xx` errors are logged at
  Information.
- **Regular expressions** are time-bounded in both servers (`PhoenixmlDb:Query:RegexMatchTimeoutMs`,
  default 2 s).

### Configuration: storage, indexing and validation settings move under `PhoenixmlDb`

Since phoenixml `main` ad3569b, both servers read storage settings from `PhoenixmlDb:Storage`
(`DataPath`, `MapSizeMb`, `MaxReaders`, `CreateIfMissing`). The gRPC server reads
`PhoenixmlDb:Indexing:FullText`, and the REST server reads `PhoenixmlDb:Validation`. All are
validated at startup, and each server logs an `EffectiveConfiguration` summary (event 3001) with
secrets masked. See the [Server Configuration reference](phoenixmldb/deployment/server-configuration.md).

- **Old keys work for one release**, with a warning naming the new key: `PhoenixmlDb:DataPath`
  (gRPC); `Phoenixml:DataPath`, `Phoenixml:MaxVersionsPerDocument` and `Validation:*` (REST).
- **`XrxServer:*` keys were never read**, and are now ignored with a warning, so upgrading changes
  nothing for them. `Validation:EnableXsd11` and `Validation:DefaultSchematronBinding` were never
  implemented and are ignored.
- **The REST server opens its database at startup**, not on the first request.
- **gRPC server data path:** with no setting, it's now `{ContentRoot}/data` instead of `./data`
  relative to the working directory. The two differ only when the content root is set explicitly or
  the server runs as a Windows service. If an old `./data` database is left behind, startup logs a
  warning naming both paths.
- **Stricter values:** a blank validation `BasePath` or `BundlePath`, or a map size smaller than the
  data already stored, now stops startup.
- **Embedded:** `DocumentDatabase` validates `LmdbStorageOptions`, which gains `CreateIfMissing`.
  Invalid full-text indexing options throw `ArgumentException` listing every problem (they were
  `ArgumentOutOfRangeException`). A `MaxDatabases` below the engine's named-database count is
  rejected.

### Stylesheets: more of the allowlist applies on the REST server

Since phoenixml `main` 1eee618, the REST server relies on the 2.5.1 engine to enforce resource
access in stylesheets. `json-doc`, `load-xquery-module`, literal shadow attributes, schema imports
and HTTP stylesheet imports from allowed origins, and computed `xsl:source-document` hrefs are
now governed by `PhoenixmlDb:ResourceAccess` instead of being refused outright. A stylesheet that
reads a denied resource is now refused when it runs (`400`), not when it's registered.
`fn:transform`, `fn:function-lookup`, `xsl:evaluate` and `xsl:result-document` are still refused.
See [Resource Access](phoenixmldb/resource-access.md#stylesheets-on-the-rest-server).

### The database runs on the 2.5.1 engines

Since phoenixml `main` 53274a6, the database uses **PhoenixmlDb.XQuery and PhoenixmlDb.Xslt 2.5.1**,
which include the resource-policy security fixes. Allowed HTTP origins now match on their exact
port, and allowed file roots match whole path segments; see
[Resource Access](phoenixmldb/resource-access.md).

### Upgrade: full-text indexes are rebuilt once

Since phoenixml `main` 8d23b02, the database uses **PhoenixmlDb.XQuery and PhoenixmlDb.Xslt
2.4.1** (Core stays at 2.0.0), and a full-text index records which text analysis built it.
Existing indexes carry no such record, so the first time a database is opened with indexing
enabled, **every full-text index is marked stale and rebuilt once**. The gRPC server does this in
the background at startup. Embedded applications must call `RebuildIndexesAsync` for each
container in `ContainersWithStaleIndexes()`; until then `SearchFullText` throws on that container
and other index-backed reads scan. Full-text query behaviour itself is unchanged by this bump;
stemming and position-based phrases are not in 2.4.1. See
[Full-Text Search: After an engine upgrade](phoenixmldb/full-text-search.md#after-an-engine-upgrade).

## Engines: PhoenixmlDb.Xslt and PhoenixmlDb.XQuery

Since 2.0.0 the two engines release together as one **train**: the Xslt and XQuery versions
match, and each release pins the other at the same version. The full per-version notes live in
each repo: [Xslt](https://github.com/phoenixmldb/phoenixmldb-xslt/blob/main/RELEASES.md) · [XQuery](https://github.com/phoenixmldb/phoenixmldb-xquery/blob/main/RELEASES.md). The summaries below lead with each release's
**measured** W3C figures, as recorded when it shipped.

> **On comparing figures across releases.** The test harness was corrected more than once. On
> 2026-09-04, expected-error tests had been scored as passes on *any* error, so earlier XSLT
> figures are overstated. Later corrections changed the case count (denominator). A figure is
> exact for its own release; subtracting across a harness change compares different
> measurements.

### 2.7.0 (2026-10-07): XQuery and Xslt 2.7.0, Core 2.2.0

**W3C QT3: 257 failing of 31,331** (427 at 2.6.0) · **W3C XSLT 3.0: 131 failing** (unchanged).

> **Security fixes in 2.7.0**
> ([GHSA-6whf-hvfp-757r](https://github.com/phoenixmldb/phoenixmldb-xquery/security/advisories/GHSA-6whf-hvfp-757r),
> [GHSA-xxjq-rwpx-m5ww](https://github.com/phoenixmldb/phoenixmldb-xslt/security/advisories/GHSA-xxjq-rwpx-m5ww)).
> Only hosts that run queries or stylesheets from untrusted parties are affected.
>
> - A module loaded with `fn:load-xquery-module` now runs inside the caller's limits,
>   cancellation token and host function replacements. Module import chains and nested
>   `load-xquery-module` calls are capped at 64 (`XQST0059`, `FOQM0003`); schema nesting at 512.
> - `RegexMatchTimeout` and cancellation now reach XSLT static expressions, nested `fn:transform`
>   and `fn:transform` from a query, and bound XSD `pattern` facets in casts, validation and schema
>   loading. New `CompilationOptions.RegexMatchTimeout` and `XsdSchemaProvider.PatternMatchTimeout`
>   for schemas imported at compile time.
> - `fn:parse-xml` is linear in nesting depth, can be cancelled, and no longer overflows the stack
>   on deeply nested input, including on Windows.
> - A schema's own includes and imports can be checked against a resource policy
>   (`XsdSchemaProvider.Add` / `AddFromString` overloads), and a text load the policy refuses ends
>   with `FOUT1170` instead of being read anyway.
> - New `IResourceResolver.ResolveContent` and `SuppliesAllContent`: a host can supply the content
>   of everything the engines load, which removes the gap between checking a location and opening
>   it. See [Resource Policy](phoenixmldb/api-reference/resource-policy.md).
>
> Not fixed: when the host neither refuses a location nor supplies its content, a file can still be
> replaced between the check and the open.

**Schema-aware typing.** A validated node now carries its schema type through atomization, type
tests, casts and `fn:idref`:

- `data()` of a validated node gives values of its schema type (including restrictions, lists and
  unions); a node with element-only content has no typed value (`FOTY0012`).
- Validated nodes match `element(*, p:T)`, `schema-element(p:e)` and `schema-attribute(p:a)`,
  substitution groups included.
- Casts to schema-defined list and union types work; `fn:idref` finds schema-typed `IDREF` nodes.
- Nodes that were not validated are unaffected.

Behaviour changes, read before upgrading:

- `validate strict` of an element with no declaration is `XQDY0084`.
- A date or dateTime out of range is `FODT0001` (was `FORG0001`); a reserved name in a named
  function reference such as `attribute#0` is `XPST0003` (was `XPST0017`).
- `fn:unparsed-text` with a named encoding reports `FOUT1190` for content that is not valid in it,
  and `fn:unparsed-text-available` answers false for an encoding the runtime refuses.
- A schema import's static rules are checked first: `XQST0070`, `XQST0057` and `XQST0058` where
  each used to be `XQST0059`.
- An imported module file must declare the namespace it was imported for (`XQST0059`), and an
  external variable with no value is `XPDY0002`.

Fixed:

- **An element parsed with `xmlns=""` keeps its undeclared default namespace** in `fn:serialize`
  output and in `in-scope-prefixes()` (#105). Known issue: the `xquery4` CLI's own output still
  drops `xmlns=""` in that case; use `fn:serialize` until it is fixed.
- **A string returned through `fn:transform` is no longer parsed as XML** with raw delivery, a
  regression since 2.4.0 that XSpec suites run with `run-as="external"` hit (#314).
- `$err:code` and other qualified local variables work in library modules; a map constructor entry
  whose key begins with a prefixed name keeps its whole value.

New API: synchronous `XsltTransformer.LoadStylesheet` / `Transform` for desktop and plugin hosts
(see [Hosting the Engines](phoenixmldb/api-reference/hosting.md)), `IResourceResolver.ResolveContent`
/ `SuppliesAllContent`, and `ISchemaProvider.HasIdrefTypedValue` (default `false`; custom providers
compile unchanged).

### 2.6.0 (2026-10-05): XQuery and Xslt 2.6.0, Core 2.1.0

**W3C XSLT 3.0: 131 failing** (216 at 2.5.1) · **W3C QT3: 427 failing** (708 at 2.5.1).

> **Security fixes in 2.6.0.** A cancelled query or transformation now stops inside regex matching,
> sorting and XPath evaluation
> ([GHSA-2wrh-863w-x2m9](https://github.com/phoenixmldb/phoenixmldb-xquery/security/advisories/GHSA-2wrh-863w-x2m9),
> [GHSA-h2xc-4m53-6j8r](https://github.com/phoenixmldb/phoenixmldb-xslt/security/advisories/GHSA-h2xc-4m53-6j8r)).
> A .NET regex match can't observe a `CancellationToken`, and the engines built every regex with no
> match timeout, so a pattern with catastrophic backtracking kept running after cancellation, for a
> time exponential in the input; sorts ran to completion first; and `XsltTransformer` didn't pass
> its token into XPath evaluation at all. A host enforcing a time limit by cancelling was not
> protected.
>
> - New: `QueryExecutionLimits.RegexMatchTimeout` (XQuery), and `XsltTransformer.RegexMatchTimeout`
>   / `XsltTransformOptions.RegexMatchTimeout` (XSLT). **They are opt-in**: the default is `null`, so
>   behaviour is unchanged until a host sets one. A match that runs past the timeout fails with
>   `FOER0000`, or with `OperationCanceledException` when the query was cancelled meanwhile.
> - Sorts (`fn:sort`, `order by`, `array:sort`, `xsl:sort`) check the token as they run, and the
>   token and query limits reach every XPath evaluation in a transformation.
> - A match already running still can't be interrupted before its timeout; choose a timeout no
>   longer than the latency you can accept after a cancel.
>
> **Hosts that run untrusted queries or stylesheets under a time limit should set
> `RegexMatchTimeout`.**

Behaviour changes, read before upgrading:

- **`fn:format-number` rounds half to even**, as the specification requires: `format-number(2.5, '0')`
  is now `2`.
- Errors that previously surfaced with the wrong code now use the specified ones, for example
  `XPTY0019` for a path step whose left operand isn't a node, and the specified cast error codes.
- **Indented output is LF on every OS** (engines and Core); it was CRLF on Windows.
- Opt-in **static typing** (`StrictTypeChecking`) is now implemented.

Fixed:

- **Streaming:** a streamed template that read its children as a value (`{foo}`) lost them, and
  `xsl:copy` with such content produced malformed output; a buffered streamed subtree dropped
  whitespace-only text; a template that reads outside the matched element was streamed with wrong
  results instead of being evaluated on a tree (Martin Honnen's #295 and #301; #298).
- **`--no-stream`** really evaluates against a tree, via the new `XsltTransformer.DisableStreaming`.

Also changed: **`LoadStylesheetAsync` now completes on a thread-pool thread**, as `TransformAsync`
already did, because compilation moved onto the engine's large-stack thread. Hosts with a UI
context are unaffected. A host with no `SynchronizationContext`, such as an editor plugin, now
continues off its UI thread after that `await`. See
[Hosting the Engines](phoenixmldb/api-reference/hosting.md).
- **Browser WebAssembly:** XSLT runs again in Blazor WebAssembly (#237, a 2.5.1 regression), and deep
  recursion there no longer exhausts the stack.
- **Schematron performance:** applying compiled ISO Schematron validators allocates about 8× less
  and runs 2–3× faster than 2.5.1, measured on the published 2.6.0 packages against real EMS
  validators and payloads, with output identical to Saxon's.
- DocBook xslTNG: cross-references, annotations and tables of contents that 2.5.1 rendered
  incompletely.

New API: `XsltTransformer.DisableStreaming`, `AllowedOutputMethods`, `OutputDeclarations` and
`XQueryModules`; Core `XdmValue.From(DateTime)`. See the
[XSLT API](phoenixmldb/api-reference/xslt-api.md#new-in-260).

### 2.5.1 (2026-10-01): XQuery 2.5.0 and 2.5.1, Xslt 2.5.1

**W3C XSLT 3.0: 216 failing** (442 at 2.4.0) · **W3C QT3: 708 failing** (1484 at 2.4.0). Much of
the QT3 drop comes from correcting the test harness, which had scored some correct results as
failures, so the 2.4.0 figures were measured before those corrections (see the note on comparing
figures above).

> **Security fixes in 2.5.** PhoenixmlDb.XQuery 2.5.0 and PhoenixmlDb.Xslt 2.5.1 fix advisories
> [GHSA-wjxc-7p24-xf7w](https://github.com/phoenixmldb/phoenixmldb-xquery/security/advisories/GHSA-wjxc-7p24-xf7w)
> (XQuery) and [GHSA-86rg-wxgp-9p5j](https://github.com/phoenixmldb/phoenixmldb-xslt/security/advisories/GHSA-86rg-wxgp-9p5j)
> (XSLT). In earlier versions, a configured `ResourcePolicy`, `ServerDefault` included, was
> enforced only when loading documents, so queries and stylesheets could read files or fetch URLs
> the policy forbade, through functions like `unparsed-text`, `json-doc`, module and schema
> imports, `xsl:source-document`, `fn:transform` and HTTP redirects. In 2.5.x every read, fetch
> and dynamic evaluation is checked against the policy, at load time as well as at run time. With
> no policy configured, nothing changes. Hosts that run untrusted queries or stylesheets should
> upgrade XQuery and Xslt together to 2.5.1.

There is no Xslt 2.5.0. Xslt's version follows the XQuery it's built on, and XQuery needed a 2.5.1
patch, found by this release's own testing, before Xslt could ship. The `xquery` CLI ships as
`cli-v2.5.1`.

Behaviour changes, read before upgrading:

- **Resource policy rules are stricter** when a policy is set: read access no longer implies
  import access, an empty rule list denies, a host rule admits only the default port unless one
  is given, and path prefixes match whole segments. See
  [Resource Policy](phoenixmldb/api-reference/resource-policy.md).
- An accumulator that isn't applicable to the principal source document raises `XTDE3362`, as in
  Saxon (#213). Add it to the initial mode's `use-accumulators`.
- The `unparsed-text` family resolves relative URIs against the calling module and raises
  `FOUT1170` (#195).

Fixed and added:

- **Streaming:** grouping over attributes and text, streamable functions, attribute-only
  `current-group()`, and accumulator rules.
- **Grouping focus** inside `apply-templates` follows XSLT 3.0 §14.2: kept, except within a
  declared-streamable construct.
- **`system-property()` and `element-available()`** resolve prefixes where the function item was
  created (+22 W3C cases).
- **Schemas:** schema-defined simple types as item types and constructors, `json-to-xml`
  validation, XSD 1.1 conditional inclusion, and reliable `xml:id` on every runtime.
- **Deep documents** no longer crash the process.
- Many errors that surfaced as raw .NET exceptions now raise the codes the specifications assign.

### 2.4.1 (2026-09-28): patch

- **Fixed a 2.4.0 regression that broke XSpec compilation.** A string subtype such as `xs:NCName`
  had no effective boolean value, and 2.4.0 had made `prefix-from-QName` return one. Fixed in
  both engines, along with string-subtype map keys, `fn:translate` and `fn:collation-key`.
- **New release gate:** every release is now checked against real-world stylesheets (the XSpec
  compiler, DocBook xslTNG, reported repros) on the previous version and the candidate before it
  ships.

### 2.4.0 (2026-09-28)

**W3C XSLT 3.0: 10,397 / 10,839 (95.92%)** · **W3C QT3: 29,895 / 31,379 (95.27%)**

Behaviour changes, read before upgrading:

- `fn:namespace-uri` returns `xs:anyURI`, `fn:prefix-from-QName` returns `xs:NCName`, and
  `fn:default-language` returns `xs:language`, as the spec requires. They previously returned
  plain strings.
- `fn:distinct-values` treats an `xs:anyURI` and an equal `xs:string` as one value.
- The `xquery` CLI rejects an unknown output method (exit code 1, or `SEPM0016` in the prolog)
  instead of silently producing adaptive output. It gains `html` and `xhtml`.

Fixed:

- **Streaming**: `xsl:message` content, templates below unmatched elements, subtree ancestors,
  `has-children()`, `xsl:strip-space` / `xml:space`, early-closing parent tags, and unrequested
  child processing. Closes the three streaming sets that had fallen below their 1.6.10 scores.
- **`fn:transform`** honours `source-location`, and raw delivery from XQuery returns the nodes a
  template constructs instead of nothing.
- **CLI output is UTF-8 on every platform.** On Windows it followed the console code page, which
  corrupted non-ASCII characters in redirected output.

There is no Xslt 2.3.0. XQuery 2.3.0 (below) was published and then superseded, and both
engines moved to 2.4.0 together.

### 2.3.0 (2026-09-28): XQuery only, superseded

A lockstep version bump; the library is byte-identical to 2.2.0. Moving from 2.2.0 straight to
2.4.0 is the intended upgrade path.

### 2.2.0 (2026-09-24/25)

**W3C XSLT 3.0: 10,384 / 10,839 (95.80%)** · **W3C QT3: 29,803 / 31,379 (94.98%)**

- **`xs:IDREFS`, `xs:NMTOKENS` and `xs:ENTITIES`** are valid cast and castable targets (+63 QT3).
- **`xsl:expose`** selects components correctly.
- **A match pattern with any predicate was O(n²)** in sibling count: 12.6× faster at 4,000
  siblings.
- Streamed `group-adjacent` key checks, `xsl:sort`/`xsl:key` temporary output state,
  `regex-group()` in patterns, text nodes returned by `xsl:function`, and static declarations
  coming into scope in declaration order.

### 2.1.0 (2026-09-17)

**W3C XSLT 3.0: 10,347 / 10,839 (95.46%)** · **W3C QT3: 29,822 / 31,379 (95.0%)**, as recorded in
the XQuery 2.1.0 notes.

Breaking: a typed variable whose body produces the wrong number of items raises `XTTE0570`.
`xsl:strip-space` / `xsl:preserve-space` in imported modules are applied, with conflicts resolved
by import precedence. `xsl:map-entry` keys are atomized.

### 2.0.0 (2026-09-15)

**W3C QT3: 29,813**

Major because the train is: `PhoenixmlDb.Core`, `PhoenixmlDb.XQuery` and `PhoenixmlDb.Xslt`
moved to 2.0.0 together.

- **Breaking:** built-in functions apply argument cardinality, and their signatures match F&O 3.1,
  so some existing queries stop compiling. The extension functions moved.
- In-scope namespaces survive copies and serialization. Serialization parameters are read
  properly. The XSLT-side `fn:serialize` override is retired.

### 1.8.0 (2026-09-13)

**W3C XSLT 3.0: 10,292 / 10,630 (96.82%)** · **W3C QT3: 29,534 / 31,414 (94.02%)**. This is a
different denominator from 2.x.

Silent wrong answers fixed: `xsl:function cache="yes"` returning other calls' results;
accumulators reading a later-declared accumulator one node late; `as="item()*"` functions losing
element nodes; `xsl:merge` merging only one of two sources; and `xsl:try` running its body in the
caller's scope.

### 1.7.0 (2026-09-10)

**W3C XSLT 3.0: 10,082 / 10,630 (94.8%)**

- `fn:sum` returned 0 for `xs:integer` values cast from text.
- Aggregates over storage-backed elements atomized to `""`.
- `map:put` / `map:remove` / `map:replace` copied the whole map on every update (O(n²)).
- A caller's timeout could not stop recursion, callbacks or a slow `every`.
- Several `contains text` defects.

### 1.2 – 1.6 (April – September 2026)

A long run of frequent, often daily, releases: over a hundred versions across both engines. That
cadence has since been replaced by releases that each carry a complete batch. Highlights:
serialization conformance (character maps, HTML/XHTML output methods), streaming, QT3 production
sweeps, and input hardening (parser recursion bounds, `XQST0090` on invalid character references,
concurrent namespace interning).
Figures in this period predate the 2026-09-04 harness correction. Each version's notes are in
the [Xslt](https://github.com/phoenixmldb/phoenixmldb-xslt/blob/main/RELEASES.md) and [XQuery](https://github.com/phoenixmldb/phoenixmldb-xquery/blob/main/RELEASES.md) repos.

## Version 1.1.0 (March 2026)

Major update focused on standards compliance, streaming, and API completeness.

### XSLT Engine

- **Streaming execution**: XmlReader-based forward-only processing for `xsl:source-document streamable="yes"` and `xsl:mode streamable="yes"`
- **Stream API**: `TransformAsync(TextReader)`, `TransformAsync(Stream)`, `TransformAsync(TextWriter)`, `TransformAsync(Stream, Stream)`, `ResultDocumentHandler`
- **Serialization**: `indent="yes"` (XML, HTML, XHTML), DOCTYPE generation, `suppress-indentation`, `byte-order-mark`, `escape-uri-attributes`
- **xsl:record**: Proper XDM map construction
- **xsl:expose**: Full package visibility control (conformance tests enabled)
- **Error handling**: Proper XTSE0020 for invalid `on-no-match`/`on-multiple-match` values
- **System properties**: `supports-streaming=yes`, `supports-namespace-axis=yes`, `xpath-version=4.0`

### XQuery Engine

- **Direct element constructors**: `<element>text {expr}</element>` with ANTLR lexer modes
- **XQuery Update Facility**: Full execution (insert, delete, replace, rename, transform copy-modify-return)
- **Annotations**: `%public`, `%private`, `%updating` on function/variable declarations
- **String constructors**: `` ``[Hello `{$name}`!]`` `` backtick interpolation
- **Module imports**: Parsed with XQST0059 error when resolver not configured
- **UCA collations**: Unicode Collation Algorithm with lang/strength/fallback parameters
- **External variables**: `SetExternalVariable()` API with XPDY0002 for unbound
- **JSON serialization**: Maps/arrays serialize as JSON, `declare option output:method "json"` support
- **Node constructors**: All constructor types (element, attribute, text, comment, PI, document) fully operational

### CLI Tools

- **xslt CLI**: `--stream` flag for large file processing, version 1.1.0
- **xquery CLI**: `--output json` flag, auto-detect serialization options, version 1.1.0
- CLI tools moved into engine repos (same CI, same release)

### Quality

- 843 XQuery tests (including 30 integration tests through XQueryFacade)
- 300 XSLT tests (including 36 integration tests through XsltTransformer)
- Zero TODOs in source
- Zero silent exception swallowing
- All README claims verified by tests

---

## Version 1.0.0

**Release Date:** 2025

The initial release of PhoenixmlDb, a modern embedded XML/JSON document database for .NET.

### Features

#### Core Database
- Embedded database with LMDB storage
- ACID transactions with MVCC
- Multiple containers per database
- XML and JSON document storage
- Document metadata support

#### Query Engine
- Full XQuery 3.1 implementation
- XQuery 4.0 features (partial)
- XPath 3.1 support
- XSLT 3.0/4.0 transformations
- Query optimization
- Prepared queries

#### Indexing
- Path indexes for element/attribute lookup
- Value indexes for range queries
- Full-text indexes with stemming
- Structural indexes for navigation
- Metadata indexes

#### Server Mode
- gRPC-based server
- TLS support
- Authentication (basic, API keys)
- Role-based access control
- Health monitoring

#### Cluster Mode
- Raft consensus for leader election
- Automatic failover
- Sharding with consistent hashing
- Replication for fault tolerance
- Distributed transactions (2PC)

### System Requirements

- .NET 10.0 or later
- Windows 10+, Linux (Ubuntu 20.04+, RHEL 8+), macOS 12+

### Known Limitations

- XQuery full-text extension not yet implemented
- Schema validation is basic (planned for 1.1)
- XSLT streaming limited to certain patterns
- Maximum database size limited by LMDB (depends on platform)

### Upgrade Notes

This is the initial release. No upgrade path needed.

---

## Roadmap

### Version 1.2 (Planned)

- Full XML Schema validation
- XQuery Full-Text extension
- Improved query optimizer
- GraphQL API
- More XSLT 4.0 features

### Version 1.3 (Planned)

- Change data capture (CDC)
- Event sourcing support
- Improved cluster rebalancing
- Admin UI

### Future

- Geographic replication
- Column-oriented storage for analytics
- Machine learning integration
- Cloud-native deployment options

---

## Deprecation Policy

- Major versions supported for 3 years
- Minor versions supported for 1 year
- Security patches for supported versions
- Migration guides provided for breaking changes

## Contributing

We welcome contributions! See our [Contributing Guide](https://github.com/endpointsystems/phoenixml/blob/main/CONTRIBUTING.md) for details.

## License

PhoenixmlDb is licensed under the Apache 2.0 License.

## Acknowledgments

PhoenixmlDb builds on these excellent projects:
- [LMDB](http://www.lmdb.tech/doc/) - Lightning Memory-Mapped Database
- [LightningDB](https://github.com/CoreyKaylor/Lightning.NET) - .NET bindings for LMDB
- [ANTLR4](https://www.antlr.org/) - Parser generator

Special thanks to the W3C for the XQuery, XPath, XSLT, and XDM specifications.
