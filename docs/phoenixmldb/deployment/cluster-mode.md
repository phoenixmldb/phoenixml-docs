---
title: Cluster Mode
description: Raft replication across server nodes — configuration, port separation, securing the Raft and client ports, and current limits
sort: 3
---

# Cluster Mode

PhoenixmlDb servers replicate with **Raft**. That's worth stating plainly, because it isn't what
people usually expect from a database's replication settings:

- There is **no primary to designate**. The nodes elect a leader from the configured peer set.
- **Failover is automatic.** A follower that stops hearing heartbeats starts an election.
- A write needs a **majority**, so a cluster should have an **odd** number of nodes. Three
  tolerate one failure, five tolerate two. A two-node cluster is worse than one node: it needs both
  members for a majority, so either failure stops writes.

Replication is **logical**. The leader ships database commands (create container, put document,
delete, …) through the replicated log, and every node applies the same sequence to its own store.
Storage pages are not shipped.

> **Fixed in phoenixml `main` 1023078 (issue #63):** before this, every incoming Raft call over
> gRPC was refused, even with the correct cluster secret, so a multi-node cluster could never elect
> a leader. A two-node cluster over TLS now elects a leader and replicates writes.

## Configuring a three-node cluster

Each node names itself and lists the *other* nodes. On `node-1`:

```json
{
  "PhoenixmlDb": {
    "DataPath": "/var/lib/phoenixml",
    "Raft": {
      "Enabled": true,
      "NodeId": "node-1",
      "ListenPort": 5002,
      "ClusterSecret": "<32+ characters, the same on every node>",
      "CertificatePath": "/etc/phoenixml/raft.pfx",
      "Peers": [
        { "Id": "node-2", "Address": "https://10.0.0.2:5002" },
        { "Id": "node-3", "Address": "https://10.0.0.3:5002" }
      ]
    },
    "Auth": {
      "ApiKeys": [
        { "Id": "app-2026", "Name": "app", "Sha256": "<64 hex>" }
      ]
    }
  }
}
```

`node-2` and `node-3` get the same file with their own `NodeId` and the other two as `Peers`.
Every setting can also come from the environment, which is often easier per node, for example
`PhoenixmlDb__Raft__NodeId=node-1`.

| Setting | Default | Notes |
|---|---|---|
| `Raft:Enabled` | `false` | An embedded database never starts electing leaders by accident. |
| `Raft:NodeId` | | Required when enabled. Must stay the **same across restarts**: the node's persisted vote is recorded against it. |
| `Raft:Peers` | `[]` | The **other** members, each with `Id`, an `https://` `Address`, and an optional `Thumbprint`. Listing this node is rejected. |
| `Raft:ListenPort` | `5002` | Raft's own port. See [Ports](#ports). |
| `Raft:ClusterSecret` | | Required. At least 32 characters, the same on every node. |
| `Raft:CertificatePath` / `CertificatePassword` | | Required. The TLS certificate this node presents to its peers. |
| `Raft:LogPath` | `<DataPath>/raft` | The Raft log's own storage environment. |
| `Raft:ElectionTimeoutMinMs` / `MaxMs` | `150` / `300` | Randomised between the two, so they must differ. |
| `Raft:HeartbeatIntervalMs` | `50` | Must be well under the election timeout. |

Configuration is validated at **startup**, and bad values stop the server rather than degrading
it. Rejected: a missing `NodeId`, a node listing itself as a peer, duplicate peer ids or
addresses, a heartbeat interval at or above the election timeout, and identical minimum and
maximum election timeouts. Raft relies on that randomisation to break ties; in lockstep, nodes
can split the vote for a long time.

## Ports

Raft gets its own port. Sharing a listener with client traffic would let a large query response
delay a heartbeat queued behind it, and a heartbeat that is late enough looks like a dead leader.

The server tells the two kinds of traffic apart **by the port a connection arrives on**, never by
the `Host` header:

- The **Raft port** (`PhoenixmlDb:Raft:ListenPort`) serves only Raft. A client call there gets
  `PermissionDenied`, and `/health` or any other HTTP request gets `404`.
- The **client ports** (`PhoenixmlDb:Endpoints:Port` and `HttpsPort`) refuse Raft calls with
  `PermissionDenied`.

The server **refuses to start** when `Raft:ListenPort` equals `Endpoints:Port` or
`Endpoints:HttpsPort`, and the message names both settings.

## Securing the Raft port

The Raft listener binds every interface, because peers are on other machines. An unauthenticated
Raft port would let anyone who reaches it claim leadership and have their entries applied, or
replace the database with a snapshot. So both of these are **required**, and the server refuses
to start without them:

- **`ClusterSecret`**: at least 32 characters, identical on every node. A wrong or missing secret
  gets `Unauthenticated`.
- **A TLS certificate** (`CertificatePath`), with `https://` peer addresses. Set a peer's
  `Thumbprint` to pin its exact certificate, which suits self-signed certificates. Omit it to
  validate against the system trust store, which suits an internal PKI.

This is weaker than mutual TLS, and the trade-off is deliberate. One leaked secret compromises the
cluster, and there is no per-node revocation. Mutual TLS would give each peer its own identity,
but it needs a PKI to generate, distribute and rotate certificates.

## Securing the client API

API keys never authenticate Raft, and the cluster secret never authenticates the client API.

**A Raft-enabled server must have at least one API key** (`PhoenixmlDb:Auth:ApiKeys`), or it
refuses to start. The Raft listener is on every interface, so a Raft-enabled server counts as
reachable from the network whatever `Endpoints:ListenAddress` says. Before #63, the client API was
also served on the Raft port, so a cluster with no keys exposed it to the network without
authentication.

Keys, scopes, rotation and the other startup checks are described in
[Server Mode: gRPC server](server-mode.md#grpc-server).

## What this does not do yet

"It replicates" is easily mistaken for more than it is:

- **Reads are not linearizable.** A node answers from whatever it has applied locally, so a
  follower can return stale data, and even the leader can answer a read that races a write it
  hasn't applied yet.
- **Writes are not forwarded.** A write sent to a follower is refused with the leader's id, and
  the client is expected to retry against the leader.
- **Snapshot install is limited.** A follower that falls far enough behind to need a snapshot
  needs operator help.
- **Membership is fixed at startup.** Nodes can't be added or removed from a running cluster; the
  cluster is what the configuration says when the nodes start.

## Next Steps

- [Server Mode](server-mode.md): API keys, endpoints and the other server settings
- [Configuration](../configuration.md)
- [Troubleshooting](../troubleshooting.md)
