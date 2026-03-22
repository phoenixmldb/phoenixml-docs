---
title: Cluster Mode
description: Multi-node deployment with Raft consensus, sharding, and distributed transactions
sort: 3
---

# Cluster Mode

Cluster mode provides high availability, fault tolerance, and horizontal scaling through distributed deployment.

## Overview

```
              ┌───────────────────────────────────────┐
              │              Cluster                   │
              │                                        │
┌─────────┐   │   ┌───────┐   ┌───────┐   ┌───────┐   │
│ Client  │──▶│   │Node 1 │◀─▶│Node 2 │◀─▶│Node 3 │   │
└─────────┘   │   │Leader │   │Follower│  │Follower│  │
              │   └───────┘   └───────┘   └───────┘   │
              │       │           │           │        │
              │       ▼           ▼           ▼        │
              │   ┌───────┐   ┌───────┐   ┌───────┐   │
              │   │ Data  │   │ Data  │   │ Data  │   │
              │   │Shard 1│   │Shard 2│   │Shard 3│   │
              │   └───────┘   └───────┘   └───────┘   │
              └───────────────────────────────────────┘
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Raft Consensus** | Leader election and log replication |
| **Sharding** | Distribute data across nodes |
| **Replication** | Multiple copies for fault tolerance |
| **Auto-failover** | Automatic leader election |
| **Distributed Transactions** | 2PC across shards |

## Installation

```bash
dotnet add package PhoenixmlDb.Cluster
```

## Cluster Setup

### Initialize Cluster

```bash
# On first node
phoenixmldb-cluster init \
    --node-id node1 \
    --cluster-id my-cluster \
    --peers node2:5433,node3:5433

# On other nodes
phoenixmldb-cluster join \
    --node-id node2 \
    --cluster-id my-cluster \
    --bootstrap-peer node1:5433
```

### Start Nodes

```bash
# Node 1
phoenixmldb-server \
    --cluster \
    --node-id node1 \
    --data /data/node1 \
    --port 5432 \
    --raft-port 5433

# Node 2
phoenixmldb-server \
    --cluster \
    --node-id node2 \
    --data /data/node2 \
    --port 5432 \
    --raft-port 5433

# Node 3
phoenixmldb-server \
    --cluster \
    --node-id node3 \
    --data /data/node3 \
    --port 5432 \
    --raft-port 5433
```

## Configuration

### Cluster Configuration

```json
{
    "cluster": {
        "enabled": true,
        "nodeId": "node1",
        "clusterId": "my-cluster",
        "peers": [
            {"id": "node2", "address": "10.0.0.2:5433"},
            {"id": "node3", "address": "10.0.0.3:5433"}
        ]
    },
    "raft": {
        "electionTimeout": "150-300ms",
        "heartbeatInterval": "50ms",
        "snapshotThreshold": 10000,
        "maxLogEntries": 100000
    },
    "sharding": {
        "enabled": true,
        "shardCount": 16,
        "replicationFactor": 3
    }
}
```

### Raft Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `electionTimeout` | 150-300ms | Random timeout for elections |
| `heartbeatInterval` | 50ms | Leader heartbeat frequency |
| `snapshotThreshold` | 10000 | Log entries before snapshot |
| `maxLogEntries` | 100000 | Max log entries to keep |

### Sharding Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `shardCount` | 16 | Number of shards |
| `replicationFactor` | 3 | Copies per shard |
| `rebalanceThreshold` | 10% | Imbalance threshold |

## Client Connection

### Connect to Cluster

```csharp
var options = new ClusterClientOptions
{
    Nodes = [
        "node1.example.com:5432",
        "node2.example.com:5432",
        "node3.example.com:5432"
    ],
    LoadBalancing = LoadBalanceStrategy.RoundRobin
};

var client = new PhoenixmlClusterClient(options);
```

### Automatic Failover

```csharp
var options = new ClusterClientOptions
{
    Nodes = ["node1:5432", "node2:5432", "node3:5432"],
    RetryPolicy = new RetryPolicy
    {
        MaxRetries = 3,
        RetryDelay = TimeSpan.FromMilliseconds(100),
        ExponentialBackoff = true
    }
};

// Client automatically retries on node failure
var client = new PhoenixmlClusterClient(options);
```

## Sharding

### Shard Key

```csharp
// Documents are sharded by container + document name
// Customize shard key:
var options = new ContainerOptions
{
    ShardKeyPath = "/order/customerId"  // Shard by customer
};

var container = await client.CreateContainerAsync("orders", options);
```

### Cross-Shard Queries

```csharp
// Queries across shards are automatic
var results = await client.QueryAsync("""
    for $order in collection('orders')//order
    where $order/total > 1000
    return $order
    """);
```

### Shard-Local Queries

```csharp
// Force query to specific shard for efficiency
var results = await client.QueryAsync("""
    for $order in collection('orders')//order
    where $order/customerId = 'C123'
    return $order
    """,
    new QueryOptions { ShardKey = "C123" });
```

## Distributed Transactions

### Basic Transaction

```csharp
await using var txn = await client.BeginDistributedTransactionAsync();

// Operations may span multiple shards
await txn.PutDocumentAsync("orders", "o1.xml", order1Xml);
await txn.PutDocumentAsync("inventory", "i1.xml", inventory1Xml);

// Two-phase commit ensures atomicity
await txn.CommitAsync();
```

### Transaction Isolation

```csharp
var options = new TransactionOptions
{
    IsolationLevel = IsolationLevel.Serializable,
    Timeout = TimeSpan.FromSeconds(30)
};

await using var txn = await client.BeginDistributedTransactionAsync(options);
```

## Monitoring

### Cluster Status

```bash
phoenixmldb-cluster status
# Cluster: my-cluster
# Leader: node1
# Nodes:
#   node1: healthy (leader)
#   node2: healthy (follower)
#   node3: healthy (follower)
# Shards: 16 (balanced)
```

### Node Metrics

```bash
curl http://node1:5432/cluster/metrics
```

## Operations

### Add Node

```bash
# On new node
phoenixmldb-cluster join \
    --node-id node4 \
    --bootstrap-peer node1:5433

# Cluster will rebalance automatically
```

### Remove Node

```bash
phoenixmldb-cluster remove-node node4
# Data is migrated before removal
```

### Force Leader Election

```bash
phoenixmldb-cluster transfer-leadership --to node2
```

### Rebalance Shards

```bash
phoenixmldb-cluster rebalance
# Redistributes shards for even load
```

## Failure Handling

### Node Failure

1. Raft detects missing heartbeats
2. Election timeout triggers
3. New leader elected
4. Clients automatically reconnect

### Network Partition

- Majority partition continues operating
- Minority partition becomes read-only
- Automatic recovery when healed

### Data Recovery

```bash
# Restore node from backup
phoenixmldb-cluster restore-node node3 --from backup.tar

# Or rebuild from other nodes
phoenixmldb-cluster rebuild-node node3
```

## Best Practices

1. **Odd number of nodes** - 3 or 5 for proper quorum
2. **Geographic distribution** - Across availability zones
3. **Dedicated network** - Low-latency for Raft
4. **Monitor cluster health** - Set up alerts
5. **Test failover** - Regular disaster recovery drills
6. **Backup strategy** - Despite replication

## Docker Compose Example

```yaml
version: '3'
services:
  node1:
    image: phoenixmldb/server:latest
    command: ["--cluster", "--node-id", "node1", "--peers", "node2:5433,node3:5433"]
    ports:
      - "5432:5432"
    volumes:
      - node1-data:/data

  node2:
    image: phoenixmldb/server:latest
    command: ["--cluster", "--node-id", "node2", "--peers", "node1:5433,node3:5433"]
    ports:
      - "5433:5432"
    volumes:
      - node2-data:/data

  node3:
    image: phoenixmldb/server:latest
    command: ["--cluster", "--node-id", "node3", "--peers", "node1:5433,node2:5433"]
    ports:
      - "5434:5432"
    volumes:
      - node3-data:/data

volumes:
  node1-data:
  node2-data:
  node3-data:
```

## Next Steps

| Deployment | Configuration | Support |
|------------|---------------|---------|
| **[Server Mode](server-mode.md)**<br>Single server setup | **[Configuration](../configuration.md)**<br>Cluster settings | **[Troubleshooting](../troubleshooting.md)**<br>Cluster issues |
