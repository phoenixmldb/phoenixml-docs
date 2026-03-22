---
title: Release Notes
description: PhoenixmlDb version history and changelog
sort: 5
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

### Version 1.1 (Planned)

- Full XML Schema validation
- XQuery Full-Text extension
- Improved query optimizer
- GraphQL API
- More XSLT 4.0 features

### Version 1.2 (Planned)

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

PhoenixmlDb is licensed under the MIT License.

## Acknowledgments

PhoenixmlDb builds on these excellent projects:
- [LMDB](http://www.lmdb.tech/doc/) - Lightning Memory-Mapped Database
- [LightningDB](https://github.com/CoreyKaylor/Lightning.NET) - .NET bindings for LMDB
- [ANTLR4](https://www.antlr.org/) - Parser generator

Special thanks to the W3C for the XQuery, XPath, XSLT, and XDM specifications.
