---
title: Deployment
description: Run PhoenixmlDb as an embedded library, standalone server, or distributed cluster
sort: 7
---

# Deployment

PhoenixmlDb supports three deployment modes, from single-process embedded to multi-node distributed:

- **[Embedded Mode](embedded-mode.md)** — Run as an in-process library, no separate server
- **[Server Mode](server-mode.md)** — Standalone server with gRPC API, authentication, and TLS
- **[Cluster Mode](cluster-mode.md)** — Multi-node deployment with Raft consensus and sharding
