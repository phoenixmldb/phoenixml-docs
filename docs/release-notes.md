---
title: Release Notes
description: PhoenixmlDb version history and changelog
sort: 5
---

## Unreleased: database server

### 1.0.0-preview.2 (unreleased)

The database packages are not yet published on NuGet.

This version contains:

- **XQuery library modules.** A query can `import module … at` a file or an http(s) URL, and call
  `fn:load-xquery-module`, in the embedded engine, the gRPC server and the REST server. See
  [XQuery Library Modules](phoenixmldb/xquery-modules.md).
- **One resource access allowlist**, `PhoenixmlDb:ResourceAccess`, for queries and stylesheets:
  allowed directories, allowed http(s) origins, and six size and count limits. See
  [Resource Access](phoenixmldb/resource-access.md).
- **Stylesheets read inside the allowlist** on the REST server: `xsl:import`, `xsl:include`, `doc`,
  `document`, the `unparsed-text` functions, `json-doc`, `xsl:source-document` and `xsl:merge`
  sources, from files and from http(s).
- **Schema imports in queries** (`import schema … at`), and `validate` returning typed nodes.
- **A document name rule**: a document name is a relative name inside its container, at most
  507 bytes in UTF-8. See [Documents & Storage: The name rule](phoenixmldb/documents-and-storage.md#the-name-rule).
- **LMDB 1.0.1 storage** (LightningDB 0.23.1), with detection of databases in the LMDB 0.9 format
  and the `PhoenixmlDb.Migrate` tool. See [Upgrading to LMDB 1.0](phoenixmldb/deployment/lmdb-upgrade.md).
- **Libraries**: PhoenixmlDb.Core 2.4.0, PhoenixmlDb.XQuery 2.8.0, PhoenixmlDb.Xslt 2.8.0. See
  [Installation](getting-started/installation.md).
- **Server configuration** under one root, `PhoenixmlDb:*`, validated at startup, with a startup
  summary of the effective configuration. See
  [Server Configuration](phoenixmldb/deployment/server-configuration.md).
- **REST server**: error answers that lead with the XQuery/XSLT error code, schema locations for the
  validators, a transformation concurrency limit, and request variables for queries. See
  [Server Mode: Requests and errors](phoenixmldb/deployment/server-mode.md#requests-and-errors).
- **gRPC server**: error text that leads with the error code.

#### Behaviour you can see

With PhoenixmlDb.XQuery 2.8.0, PhoenixmlDb.Xslt 2.8.0 and PhoenixmlDb.Core 2.4.0:

| Area | Behaviour |
|---|---|
| `validate` in a query | Returns typed nodes: atomization, comparisons, arithmetic, `instance of element(*, T)`, `schema-element()` and `attribute(*, T)` follow the schema type. Stored documents stay untyped; validate in the query to get typed values. |
| Atomizing a validated element with element-only content | `FOTY0012` (`string()` works) |
| `validate strict` of an element with no declaration, including with no schema import | `XQDY0084` |
| `validate` of invalid content | `XQDY0027` |
| `. instance of schema-element(E)` on an unvalidated node | `false` |
| A value cast to, or atomized from, a schema-defined type | Is an instance of that type: `(t:qty cast as t:Qty) instance of t:Qty` is `true` |
| A date or dateTime outside the supported range | `FODT0001` |
| A reserved name in a named function reference (`attribute#0`, `element#1`, `if#1`) | `XPST0003` |
| `fn:unparsed-text`, `fn:unparsed-text-lines` with a requested encoding, characters XML does not allow | `FOUT1190` |
| `fn:unparsed-text-available(f, 'utf-7')` | `false` |
| `fn:load-xquery-module` of a module that needs a context item, none supplied | `XPDY0002` |
| An import chain longer than 64 modules | `XQST0059` at any `MaxModuleDepth` |
| `$err:code` and other qualified local variables inside a library module | Work |
| A map constructor entry whose value begins with a prefixed name (`map { 1: fn:true#0 }`) | Keeps its value |
| Schema import: binding `xml`/`xmlns`, a prefix with an empty target namespace, two imports of one namespace | Refused: `XPST0003`, with a message leading with `XQST0070` / `XQST0057` / `XQST0058` |
| `import schema` inside a library module | `XQST0009` |
| An unavailable stylesheet module | `XTSE0165: Cannot find stylesheet module '<href>'` |

For code that calls the engine's stylesheet resolver directly: a stylesheet module that is not
supplied is answered with `PhoenixmlDb.Storage.Security.StylesheetModuleRefusedException` (an
`UnauthorizedAccessException` that carries the engine's error); a relative module reference with no
base is answered with null.

#### Known limits

- **Modules:** no modules stored in the database; no compiled-module cache; a predicate inside a
  module function is not answered from a value index; a module loaded only at run time does not
  change how the query is run; `fn:unparsed-text` and `fn:json-doc` in queries read files only;
  XSLT cannot import XQuery modules. See
  [XQuery Library Modules: Known limits](phoenixmldb/xquery-modules.md#known-limits).
- **Stylesheets on the REST server:** the constructs listed in
  [Not available in stylesheets](phoenixmldb/resource-access.md#not-available-in-stylesheets) are
  refused, and the limits in [Resource Access: Known limits](phoenixmldb/resource-access.md#known-limits)
  apply. A `match` pattern with a syntax error inside a predicate (`a[`, `a[1 +]`) is accepted by
  the library.
- **Validators:** `sch:extends href` and RELAX NG `externalRef` / `include` are not implemented.
- **A cluster write that reports "Failed to reach consensus" may still be applied.** The leader
  appends the entry to its log, then waits up to 5 seconds for it to be applied. When that time
  passes it answers `Success = false`, `Error = "Failed to reach consensus"`, and the entry stays in
  the log; it can be committed and applied afterwards. A client that gets this answer should read
  before it retries.
- Reads in a cluster are node-local and not linearizable.
- The Raft log format has no version number.
- `PhoenixmlDb:Query:EnableCaching` cannot be turned on.
- Migration tool: only linux-x64 is run; there is no disk-space check up front; a single value of
  about 2 GiB or more is untested.

#### Compatibility checklist for operators

Storage and platform:

- If your Linux host has glibc older than 2.38, the storage library does not load. Use a host with
  glibc 2.38 or newer, or the `aspnet:10.0` image.
- If you have a database, Raft log or backup written with LMDB 0.9, opening it throws
  `LmdbMigrationRequiredException`. Run `PhoenixmlDb.Migrate`; see
  [Upgrading to LMDB 1.0](phoenixmldb/deployment/lmdb-upgrade.md).
- An over-long or otherwise refused document name throws `InvalidDocumentNameException` (an
  `ArgumentException`) before anything is written.

Configuration:

- `Phoenixml:DataPath`, `PhoenixmlDb:DataPath`, `Phoenixml:MaxVersionsPerDocument` and
  `Validation:*` apply for this release, with warning 3002. Rename them; see
  [Legacy keys](phoenixmldb/deployment/server-configuration.md#legacy-keys).
- `XrxServer:*` keys are ignored, with a warning. Set the `PhoenixmlDb:*` key the warning names.
- `PhoenixmlDb:Query:EnableCaching: true` stops startup. Remove it.
- `PhoenixmlDb:ResourceAccess:AllowStylesheetFileAccess` in the configuration stops startup.
  Remove it.
- Any `PhoenixmlDb:*` value out of range stops startup with a message that names the key.
- Container versioning on the REST server is off by default. Set
  `PhoenixmlDb:Containers:Defaults:VersioningEnabled: true` or enable it per container.
- On the gRPC server, `/healthz` is a deprecated alias of `/health` for one release. Use `/health`.

Queries:

- `fn:doc`, `fn:doc-available`, `fn:collection` and `fn:uri-collection` resolve stored documents
  only. A file path or URL that names no stored document is `FODC0002` / `false`.
- A relative location with no base in a query or module is `XQST0059` / `FOQM0002` / `FOUT1170`.
  Use an absolute location or `declare base-uri`.
- A query that reads files or imports modules needs the directories in
  `PhoenixmlDb:ResourceAccess:AllowedFileRoots` and the origins in `AllowedHttpOrigins`.
- Every `at` location of an `import module` must exist and hold the module.
- `import schema` in a library module is `XQST0009`. Move the import to the query.
- A missing context item for `fn:load-xquery-module` is `XPDY0002`.
- A requested encoding that cannot decode a file is `FOUT1190`.
- An out-of-range date is `FODT0001`.
- `attribute#0` and similar named function references are `XPST0003`.
- The result of `validate` is typed: comparing it as untyped (`qty = '012'`) is `XPTY0004`.
  `validate strict` of an undeclared element is `XQDY0084`.
- A module graph that chains more than 64 modules is `XQST0059`.
- A query or transformation that imports a module over http(s) reads no files. Fetch the files over
  http(s) too, or keep the module as a file; see
  [Modules read over HTTP](phoenixmldb/resource-access.md#modules-read-over-http).

Stylesheets (REST server):

- A stylesheet that reads files or URLs needs them listed in `AllowedFileRoots` /
  `AllowedHttpOrigins`.
- A stylesheet that uses `fn:collection`, `fn:uri-collection`, `fn:load-xquery-module`,
  `fn:stream-available`, `fn:transform`, `fn:function-lookup`, `xsl:import-schema` with a location,
  `xsl:use-package`, `xsl:result-document href`, `parameter-document`, `xsl:merge-source streamable`,
  a computed shadow attribute, or the environment functions in a static expression is answered
  HTTP `400` before it runs.
- A relative `xsl:import` / `xsl:include` in a stylesheet with no `xml:base` is `XTSE0165`. Add
  `xml:base` or use an absolute href.
- Inside a file module, `static-base-uri()` and `base-uri()` are `phoenixmldb-file:///root-N/…`; see
  [How stylesheet modules read from files are named](phoenixmldb/resource-access.md#how-stylesheet-modules-read-from-files-are-named).
- An XPath syntax error in a stylesheet is HTTP `400` with `XPST0003` (`XTSE0340` for a pattern).
- Transform error details begin with the error code.
- Requests past `PhoenixmlDb:Transform:MaxConcurrentTransforms` (default two per processor, 4 to
  16) are answered `503`.

Validation (REST server):

- A schema location (`Schemas[].Uri`, `xs:include`, `xs:import`, `xs:redefine`, `sch:include`) that
  is not registered, not in `PhoenixmlDb:Validation:BasePath` and not allowed by
  `PhoenixmlDb:ResourceAccess` is HTTP `400` `SCHEMA_LOCATION_NOT_AVAILABLE`.
- Schemas kept outside the schema directory and named by absolute path need that directory in
  `PhoenixmlDb:ResourceAccess:AllowedFileRoots`.
- `PhoenixmlDb:Validation:AllowHttpResolution: true` also needs the origin in
  `PhoenixmlDb:ResourceAccess:AllowedHttpOrigins`.
- An unknown schema type is HTTP `400`.
- A batch that names a schema that is not registered fails every document with `SCHEMA_NOT_FOUND`.
- `POST /api/v1/schemas` answers `201`.
- Updating, deleting or activating schemas on `/api/schemas` needs an admin key; a write key gets
  `403`.
- A document nested more than 1024 elements deep is a validation error; a schema nested more than
  512 deep is refused.

Documents:

- Document names with a leading `/`, a drive, a URI scheme followed by `/`, `file:`, `phoenixml:`,
  `phx-schema:`, a `.` or `..` segment, a control character, or more than 507 bytes are refused on
  write. One-letter prefixes such as `a:b` are the drive form and are refused.
- Documents already stored under such names stay readable and deletable; put them under an accepted
  name to update them.
- Tools that derive names from file paths must pass relative names without `.` or `..`.

gRPC clients:

- The `error` text of a failed query with an error code begins with the code.
- A write answered "Failed to reach consensus" may have been applied; read before you retry.

Cluster:

- Migrate each node's database directory and Raft log directory. A node on the new build refuses a
  Raft snapshot sent by a node still on LMDB 0.9.
- A Raft-enabled server needs API keys and a Raft port different from both client ports.

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

### 2.8.0 (2026-10-09): XQuery and Xslt 2.8.0, Core 2.4.0

**W3C QT3: 251 failing of 31,331** (257 at 2.7.0) · **W3C XSLT 3.0: 131 failing**.

> **Security fixes in 2.8.0.** Only hosts that run queries or stylesheets from untrusted parties
> are affected. XQuery: [GHSA-g2xr-r7jg-2v33](https://github.com/phoenixmldb/phoenixmldb-xquery/security/advisories/GHSA-g2xr-r7jg-2v33):
> every HTTP redirect is authorized against the resource policy, XInclude reads under the policy,
> and refusals no longer disclose host paths. The XSLT advisory will be linked here when it is
> published. Upgrade to 2.8.0.

**Core 2.4.0 is a breaking release** for code that builds `NodeReader` or reads stored nodes
directly: `new NodeReader(buffer)` is removed, and reading the string value of a node with
children but no resolver now throws instead of returning `""` (switch
`PhoenixmlDb.Xdm.StrictStringValue` to `false` for the old behaviour). The XQuery and XSLT engines
are unaffected.

**The shared schema layer.** Core 2.3.0 added `PhoenixmlDb.Core.Schema` (sources, an access gate,
a compiler, a cache, a validator, XML Catalogs), and in 2.8.0 the engines read every schema
through it:

- Schemas imported with `import schema` / `xsl:import-schema` are **compiled once and shared**
  across queries and transformations; a changed schema file or included file is picked up on the
  next use. Importing a 705 KB schema: 39.7 ms per query before, 1.6 ms now.
- **Stricter loading, check on upgrade:** a schema include or import that cannot be read fails the
  load (`XQST0059`) instead of being skipped; a schema document with a DOCTYPE is refused; schema
  text without a base URI no longer resolves relative locations against the current directory.
- A schema that requires XSD 1.1 now says so, naming the document and the constructs. The
  processor implements XSD 1.0.
- An atomic value keeps its schema type (`t:size('8') instance of t:size` is true), and in XSLT
  the constructor functions of imported schema types can be called.

Other changes:

- XSLT: an inline `xs:schema` in `xsl:import-schema` and `xsl:validation` on literal result
  elements are applied; `StrictStreamability` (opt-in, `--strict-streaming`) reports `XTSE3430`, and
  two wrong results in streamed rules are fixed.
- A cancelled query no longer starts a regex or pattern match.
- The `xquery4` CLI writes `xmlns=""` correctly (#105).
- New API: `JsonXmlConverter`, `XsdSchemaProvider(CompiledSchema)`, `XsdSchemaProvider.Catalog`,
  `ISchemaProvider.AddSchemaText`.

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
