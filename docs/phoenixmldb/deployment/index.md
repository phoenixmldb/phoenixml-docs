---
title: Deployment
description: Run PhoenixmlDb as an embedded library, standalone server, or distributed cluster
sort: 7
---

# Deployment

PhoenixmlDb supports three deployment modes, from single-process embedded to multi-node distributed:

- **[Embedded Mode](embedded-mode.md)** — Run as an in-process library, no separate server
- **[Server Mode](server-mode.md)** — Standalone server with gRPC API, authentication, and TLS
- **[Cluster Mode](cluster-mode.md)** — Multi-node replication with Raft consensus
- **[Upgrading to LMDB 1.0](lmdb-upgrade.md)** — Migrating databases created on LMDB 0.9; the glibc 2.38 floor
