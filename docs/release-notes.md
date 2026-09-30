---
title: Release Notes
description: PhoenixmlDb version history and changelog
sort: 5
---

## Unreleased: database server

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

**The gRPC server has no authentication yet.** Don't expose it outside a trusted network.

### Breaking for monitoring: health endpoints are status-only

Since phoenixml `main` 170adf3 (issue #51), `/health`, `/health/live` and `/health/ready` return
only `Healthy` / `Degraded` / `Unhealthy` as plain text: `200`, or `503` when unhealthy. The
detailed JSON report moved to **`/health/details`**, which requires an admin credential. Anything
that parsed JSON from `/health` must call `/health/details` instead. `/health/ready` now runs the
database and engine checks; it used to always return `200`. See
[Server Mode: Health Endpoints](phoenixmldb/deployment/server-mode.md#health-endpoints).

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
