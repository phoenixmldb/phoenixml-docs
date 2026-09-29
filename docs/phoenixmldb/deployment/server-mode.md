---
title: Server Mode
description: Standalone server with REST and gRPC APIs, authentication, TLS, and Docker deployment
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

The REST server authenticates by API key or JWT; see [Authentication](#authentication).

```csharp
using var http = new HttpClient { BaseAddress = new Uri("https://localhost:5001") };
http.DefaultRequestHeaders.Add("X-Api-Key", Environment.GetEnvironmentVariable("PHOENIXML_API_KEY"));
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
    "Host=localhost;Port=5432;UseTls=true");
```

## Authentication

> **Breaking change** (phoenixml `main`, 0d46e91): the REST server is now **secure by default**.
> Every endpoint requires credentials, and a production host refuses to start until an operator
> configures a key. The settings section is **`Auth`**. The older `authentication` section shown
> in earlier versions of this page **makes the server refuse to start**.

> **The gRPC server has no authentication today.** It will get the same model as the REST server
> described here. Until then, don't expose the gRPC port outside a trusted network.

Every REST endpoint requires either an **API key** in the `X-Api-Key` header or a **JWT** in
`Authorization: Bearer <token>`. Anonymous requests get `401`. Only these are open:

- `/health`, `/health/live`, `/health/ready`: status only; the detailed `/health/details` needs an admin credential (see [Health Endpoints](#health-endpoints))
- the Swagger UI, and only in the Development environment

```bash
curl -H "X-Api-Key: $PHOENIXML_API_KEY" https://localhost:5001/api/containers
curl -H "Authorization: Bearer $TOKEN"  https://localhost:5001/api/containers
```

### Settings

Settings live in the `Auth` section. As environment variables, use `__` between levels, for
example `Auth__Jwt__SecretKey`. Supply secrets through `dotnet user-secrets` or the environment,
never in a committed `appsettings.json`.

| Setting | Default | Notes |
|---|---|---|
| `Auth:RequireAuthentication` | `true` | Set `false` only to run an open server on purpose, and leave `Auth:ApiKey:Enabled` true. Startup logs a warning. |
| `Auth:ApiKey:Enabled` | `true` | |
| `Auth:ApiKey:HeaderName` | `X-Api-Key` | Case-insensitive. Must not be `Authorization`. |
| `Auth:ApiKey:QueryParameterName` | *(empty)* | Empty disables query-string keys, which leak into request logs. |
| `Auth:ApiKey:Keys:<key>:Permission` | *(required)* | `read`, `write`, `admin` or `full` |
| `Auth:ApiKey:Keys:<key>:Name` | | Identifies the key in errors; the key itself is never logged. |
| `Auth:ApiKey:Keys:<key>:Enabled` | `true` | |
| `Auth:ApiKey:Keys:<key>:ContainerPermissions` | *(empty)* | Must be empty: per-container permissions aren't implemented yet, and startup fails if it's set. |
| `Auth:Jwt:Enabled` | `false` | |
| `Auth:Jwt:SecretKey` | | Secret. At least 32 bytes UTF-8, and not the placeholder that older builds shipped. |
| `Auth:Jwt:Issuer` | | Required when JWT is enabled. |
| `Auth:Jwt:Audience` | | Required when JWT is enabled. |
| `Auth:Jwt:Authority` | | Not supported yet (no OpenID Connect): setting it fails startup. |

An API key is the setting's own name (`<key>` above). For example:

```bash
KEY=$(openssl rand -hex 24)            # 48 characters; keys under 32 are refused outside Development
export "Auth__ApiKey__Keys__${KEY}__Permission=read"
```

### Startup checks

The server validates its configuration at startup and refuses to start, with a message naming
the setting, when:

- `Auth:RequireAuthentication` is true and nothing could authenticate: no enabled API key and no JWT;
- outside Development, an API key is shorter than **32 characters**, or is a development key;
- a key has no `Permission`, or has `ContainerPermissions`;
- JWT is enabled with a missing, placeholder or too-short `SecretKey`, or without `Issuer`/`Audience`;
- `Auth:Jwt:Authority` is set;
- an `Authentication` section exists. The section is `Auth`.

### JWTs

Tokens must be **HS256**-signed with `Auth:Jwt:SecretKey`, carry `exp`, and match the configured
issuer and audience. They're validated with a 30-second clock skew. The caller's permission comes
from the token's `permission` claim.

### Permissions

| Policy | Accepts permission |
|---|---|
| `RequireRead` | `read`, `write`, `admin`, `full` |
| `RequireWrite` | `write`, `admin`, `full` |
| `RequireAdmin` | `admin`, `full` |

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

### Health Endpoints

The REST server exposes four health endpoints. The three public ones return **status only**: a
plain-text body of `Healthy`, `Degraded` or `Unhealthy`, with no check names, data or error text.

| Endpoint | Auth | Checks | HTTP status |
|---|---|---|---|
| `/health/live` | anonymous | none: liveness only | `200` while the process is up |
| `/health/ready` | anonymous | database, query engine, transform engine | `200` Healthy or Degraded, `503` Unhealthy |
| `/health` | anonymous | the same as `/health/ready` | as `/health/ready` |
| `/health/details` | **admin** (`RequireAdmin`) | every registered check | detailed JSON report |

```bash
curl -i https://localhost:5001/health/ready
# HTTP/1.1 200 OK
# Healthy

curl -H "X-Api-Key: $ADMIN_KEY" https://localhost:5001/health/details   # names, status, durations, data
```

`/health/details` returns `401` without a credential and `403` for a key without admin
permission.

**Probes.** Point a liveness probe at `/health/live`, and a readiness probe or load balancer at
`/health/ready`. `/health/ready` actually runs the checks; before phoenixml `main` 170adf3 it
checked nothing and always returned `200`.

**No health response contains exception text.** Failures are logged on the server. The detailed
report carries a fixed code instead: `database_unavailable`, `query_engine_unavailable` or
`transform_engine_unavailable`.

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
