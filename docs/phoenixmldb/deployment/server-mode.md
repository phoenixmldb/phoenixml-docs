---
title: Server Mode
description: Standalone server with gRPC API, authentication, TLS, and Docker deployment
sort: 2
---

# Server Mode

Server mode runs PhoenixmlDb as a standalone service, allowing multiple clients to connect via gRPC.

## Overview

```
┌─────────┐     ┌──────────────────────────────┐
│ Client  │────▶│     PhoenixmlDb Server       │
│  App 1  │     │  ┌────────────────────────┐  │
└─────────┘     │  │    gRPC Service        │  │
                │  └────────────────────────┘  │
┌─────────┐     │  ┌────────────────────────┐  │
│ Client  │────▶│  │    Query Engine        │  │
│  App 2  │     │  └────────────────────────┘  │
└─────────┘     │  ┌────────────────────────┐  │
                │  │    Storage (LMDB)      │  │
┌─────────┐     │  └────────────────────────┘  │
│ Client  │────▶│                              │
│  App 3  │     └──────────────────────────────┘
└─────────┘
```

## Installation

### Server Package

```bash
# Install as global tool
dotnet tool install -g PhoenixmlDb.Server

# Or as project dependency
dotnet add package PhoenixmlDb.Server
```

### Client SDK

```bash
dotnet add package PhoenixmlDb.Client
```

## Starting the Server

### Command Line

```bash
# Basic start
phoenixmldb-server --data ./data --port 5432

# With options
phoenixmldb-server \
    --data ./data \
    --port 5432 \
    --host 0.0.0.0 \
    --max-connections 100 \
    --tls-cert ./cert.pem \
    --tls-key ./key.pem
```

### As Windows Service

```bash
# Install as service
phoenixmldb-server install --service-name PhoenixmlDb

# Start service
net start PhoenixmlDb
```

### As systemd Service

```ini
# /etc/systemd/system/phoenixmldb.service
[Unit]
Description=PhoenixmlDb Server
After=network.target

[Service]
Type=simple
User=phoenixmldb
ExecStart=/usr/local/bin/phoenixmldb-server --data /var/lib/phoenixmldb --port 5432
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable phoenixmldb
sudo systemctl start phoenixmldb
```

## Server Configuration

### Configuration File

```json
{
    "server": {
        "host": "0.0.0.0",
        "port": 5432,
        "maxConnections": 100,
        "connectionTimeout": "30s"
    },
    "storage": {
        "path": "/var/lib/phoenixmldb",
        "mapSize": "10GB",
        "maxContainers": 100
    },
    "authentication": {
        "enabled": true,
        "type": "basic",
        "users": {
            "admin": "hashed-password"
        }
    },
    "tls": {
        "enabled": true,
        "certificate": "/etc/phoenixmldb/cert.pem",
        "key": "/etc/phoenixmldb/key.pem"
    },
    "logging": {
        "level": "Information",
        "file": "/var/log/phoenixmldb/server.log"
    }
}
```

### Environment Variables

```bash
export PHOENIXMLDB_HOST=0.0.0.0
export PHOENIXMLDB_PORT=5432
export PHOENIXMLDB_DATA=/var/lib/phoenixmldb
export PHOENIXMLDB_TLS_CERT=/etc/phoenixmldb/cert.pem
```

## Client Connection

### Basic Connection

```csharp
using PhoenixmlDb.Client;

var client = new PhoenixmlClient("localhost:5432");

// Create container
await client.CreateContainerAsync("products");

// Store document
await client.PutDocumentAsync("products", "p1.xml", "<product/>");

// Query
var results = await client.QueryAsync("collection('products')//product");
```

### With Authentication

```csharp
var options = new ClientOptions
{
    Host = "localhost",
    Port = 5432,
    Username = "admin",
    Password = "secret"
};

var client = new PhoenixmlClient(options);
```

### With TLS

```csharp
var options = new ClientOptions
{
    Host = "db.example.com",
    Port = 5432,
    UseTls = true,
    TlsServerName = "db.example.com"  // For certificate validation
};

var client = new PhoenixmlClient(options);
```

### Connection String

```csharp
var client = new PhoenixmlClient(
    "Host=localhost;Port=5432;Username=admin;Password=secret;UseTls=true");
```

## Authentication

### Basic Authentication

```json
{
    "authentication": {
        "enabled": true,
        "type": "basic",
        "users": {
            "admin": "$2a$10$...",  // bcrypt hash
            "reader": "$2a$10$..."
        }
    }
}
```

### API Keys

```json
{
    "authentication": {
        "enabled": true,
        "type": "apikey",
        "keys": {
            "app1": "key-hash-1",
            "app2": "key-hash-2"
        }
    }
}
```

### Role-Based Access

```json
{
    "authorization": {
        "roles": {
            "admin": ["*"],
            "reader": ["query", "get"],
            "writer": ["query", "get", "put", "delete"]
        },
        "userRoles": {
            "admin": "admin",
            "app1": "writer",
            "app2": "reader"
        }
    }
}
```

## TLS Configuration

### Generate Certificates

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 \
    -keyout key.pem -out cert.pem \
    -days 365 -nodes \
    -subj "/CN=phoenixmldb"
```

### Configure Server

```json
{
    "tls": {
        "enabled": true,
        "certificate": "./cert.pem",
        "key": "./key.pem",
        "clientCertificates": false  // Require client certs
    }
}
```

## Load Balancing

### HAProxy Configuration

```
frontend phoenixmldb
    bind *:5432
    default_backend phoenixmldb_servers

backend phoenixmldb_servers
    balance roundrobin
    server server1 10.0.0.1:5432 check
    server server2 10.0.0.2:5432 check
```

### Read Replicas

```csharp
var options = new ClientOptions
{
    WriteHost = "primary.db.local:5432",
    ReadHosts = ["replica1.db.local:5432", "replica2.db.local:5432"]
};

var client = new PhoenixmlClient(options);

// Writes go to primary
await client.PutDocumentAsync(...);

// Reads distributed to replicas
var results = await client.QueryAsync(...);
```

## Monitoring

### Health Endpoint

```bash
curl http://localhost:5432/health
# {"status":"healthy","version":"1.0.0","uptime":"3d 4h"}
```

### Metrics Endpoint

```bash
curl http://localhost:5432/metrics
# Prometheus format metrics
```

### Grafana Dashboard

Import the PhoenixmlDb dashboard for visualization of:
- Query throughput
- Response times
- Connection count
- Error rates
- Storage metrics

## Docker Deployment

### Dockerfile

```dockerfile
FROM mcr.microsoft.com/dotnet/runtime:10.0
COPY phoenixmldb-server /app/
WORKDIR /app
EXPOSE 5432
VOLUME /data
CMD ["./phoenixmldb-server", "--data", "/data"]
```

### Docker Compose

```yaml
version: '3'
services:
  phoenixmldb:
    image: phoenixmldb/server:latest
    ports:
      - "5432:5432"
    volumes:
      - phoenixmldb-data:/data
    environment:
      - PHOENIXMLDB_MAP_SIZE=10GB

volumes:
  phoenixmldb-data:
```

## Best Practices

1. **Enable TLS** - Always use TLS in production
2. **Use authentication** - Secure access to your data
3. **Monitor health** - Set up health checks and alerts
4. **Regular backups** - Implement backup strategy
5. **Limit connections** - Set appropriate max connections
6. **Use connection pooling** - In client applications

## Next Steps

| High Availability | Configuration | Support |
|-------------------|---------------|---------|
| **[Cluster Mode](cluster-mode.md)**<br>High availability | **[Configuration](../configuration.md)**<br>All settings | **[Troubleshooting](../troubleshooting.md)**<br>Problem solving |
