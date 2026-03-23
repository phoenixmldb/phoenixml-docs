---
title: Release Notes
description: PhoenixmlDb version history and changelog
sort: 5
---

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
