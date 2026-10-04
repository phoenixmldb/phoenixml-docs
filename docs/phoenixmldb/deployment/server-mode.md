---
title: Server Mode
description: The gRPC and REST servers — starting them, connecting, authentication, TLS and health
sort: 2
---

# Server Mode

PhoenixmlDb has two servers built on ASP.NET Core:

- the **gRPC server** (`PhoenixmlDb.Server`), with a .NET client library (`PhoenixmlDb.Client`);
- the **REST server**, an HTTP API.

Both store data with the same engine, read the same `PhoenixmlDb:*` settings, and are configured
through standard ASP.NET Core configuration.

> **Availability.** The servers and the client library are not yet published as NuGet packages,
> .NET tools or container images.

## Starting the server

Each server is an ASP.NET Core application. Settings come from `appsettings.json`, environment
variables (`__` between levels) and the command line, for example:

```bash
dotnet PhoenixmlDb.Server.dll --PhoenixmlDb:Storage:DataPath=/var/lib/phoenixml
```

The gRPC server listens on `127.0.0.1` by default: a plaintext HTTP/2 port (`5000`) on loopback
only, and a TLS port (`5001`). See [gRPC server](#grpc-server) for the endpoint settings and the
rules for listening on a network address.

## Server Configuration

Settings come from `appsettings.json`, environment variables (`__` between levels) and the command
line, and are validated at startup. For example:

```json
{
  "PhoenixmlDb": {
    "Storage": { "DataPath": "/var/lib/phoenixml", "MapSizeMb": 102400 }
  }
}
```

```bash
export PhoenixmlDb__Storage__DataPath=/var/lib/phoenixml
```

Every setting, its default and its startup check is in the
[Server Configuration reference](server-configuration.md).

## Client connection

The .NET client connects to the gRPC server by address, including the scheme:

```csharp
using PhoenixmlDb.Client;

await using var client = new PhoenixmlClient("http://localhost:5000");

var products = await client.CreateContainerAsync("products");
await products.PutDocumentAsync("p1.xml", "<product/>");

var result = await products.QueryAsync("collection()//product");
```

`PhoenixmlClientOptions` sets `MaxMessageSize`, `TimeoutMs`, retries (`EnableRetry`,
`MaxRetries`) and the gRPC `Credentials`.

### With an API key

The gRPC server expects `authorization: Bearer <key>` metadata (see [gRPC server](#grpc-server)).
Supply it as call credentials over TLS:

```csharp
using Grpc.Core;
using PhoenixmlDb.Client;

var apiKey = Environment.GetEnvironmentVariable("PHOENIXML_API_KEY");
var callCredentials = CallCredentials.FromInterceptor((context, metadata) =>
{
    metadata.Add("authorization", $"Bearer {apiKey}");
    return Task.CompletedTask;
});

await using var client = new PhoenixmlClient("https://db.example.com:5001", new PhoenixmlClientOptions
{
    Credentials = ChannelCredentials.Create(new SslCredentials(), callCredentials),
});
```

The REST server takes the key in the `X-Api-Key` header (see [Authentication](#authentication)):

```csharp
using var http = new HttpClient { BaseAddress = new Uri("https://localhost:5001") };
http.DefaultRequestHeaders.Add("X-Api-Key", Environment.GetEnvironmentVariable("PHOENIXML_API_KEY"));
```

## Authentication

> **Breaking change** (phoenixml `main`, 0d46e91): the REST server is now **secure by default**.
> Every endpoint requires credentials, and a production host refuses to start until an operator
> configures a key. The settings section is **`Auth`**. The older `authentication` section shown
> in earlier versions of this page **makes the server refuse to start**.

Both servers authenticate with **API keys that you issue and store as hashes** (issue #50). The
REST server also accepts JWTs. The gRPC server is covered in [gRPC server](#grpc-server) below.

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
| `Auth:RequireAuthentication` | `true` | Set `false` only to run an open server on purpose, and leave `Auth:ApiKey:Enabled` true. Startup logs a warning. Anonymous callers then get **read** routes only; write and admin routes still need a credential. |
| `Auth:ApiKey:Enabled` | `true` | |
| `Auth:ApiKey:HeaderName` | `X-Api-Key` | Case-insensitive. Must not be `Authorization`. |
| `Auth:ApiKey:QueryParameterName` | *(empty)* | Empty disables query-string keys, which leak into request logs. |
| `Auth:ApiKey:Clients` | *(empty)* | The accepted keys, one list entry per key. See [API keys](#api-keys). |
| `Auth:Jwt:Enabled` | `false` | |
| `Auth:Jwt:SecretKey` | | Secret. At least 32 bytes UTF-8, and not the placeholder that older builds shipped. |
| `Auth:Jwt:Issuer` | | Required when JWT is enabled. |
| `Auth:Jwt:Audience` | | Required when JWT is enabled. |
| `Auth:Jwt:Authority` | | Not supported yet (no OpenID Connect): setting it fails startup. |

### API keys

Each entry in `Auth:ApiKey:Clients` describes one key:

| Field | Notes |
|---|---|
| `Id` | Required and unique. Logs and revocation refer to the entry by its `Id`, never by the key. |
| `Name` | Who holds the key. Several entries may share a `Name`; that is how you rotate. |
| `Sha256` | The hex SHA-256 of the key, in either letter case. Set exactly one of `Sha256` and `Key`. |
| `Key` | The key itself, supplied as a configuration **value** (a Kubernetes `secretKeyRef`, a Docker secret). Hashed once at startup. |
| `Permission` | `read`, `write`, `admin` or `full` |
| `Enabled` | Default `true`. |
| `Expires` | Optional date and time, e.g. `2027-01-01T00:00:00Z`. |
| `ContainerPermissions` | Must be empty: per-container permissions aren't implemented yet, and startup fails if it's set. |

Store the hash, not the key, wherever configuration gets committed or backed up:

```bash
# Linux
KEY="phx_$(openssl rand -hex 24)"; printf '%s' "$KEY" | sha256sum | cut -d' ' -f1
# macOS
KEY="phx_$(openssl rand -hex 24)"; printf '%s' "$KEY" | shasum -a 256 | cut -d' ' -f1
```

```powershell
$k = "phx_" + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)).ToLower()
[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($k)))
```

Use `printf '%s'`, not `echo`: a trailing newline changes the hash. Give `$KEY` to the caller and
put the hash in configuration:

```json
{
  "Auth": {
    "ApiKey": {
      "Clients": [
        { "Id": "reporting-2026-10", "Name": "reporting", "Sha256": "<hex sha-256>", "Permission": "read" }
      ]
    }
  }
}
```

As environment variables, index the list: `Auth__ApiKey__Clients__0__Id`,
`Auth__ApiKey__Clients__0__Sha256` (or `__Key`), `Auth__ApiKey__Clients__0__Permission`. Entries
from different configuration sources merge **by list index**, so give each source its own indexes.

Send the key in the `X-Api-Key` header (`Auth:ApiKey:HeaderName`). An unknown, disabled or
expired key gets `401` with the same message; the server logs the real reason against the entry's
`Id`.

**Rotating a key:** add an entry with the same `Name` and a new `Id` and key, move callers over,
then disable or remove the old entry. Setting `Expires` on the old entry retires it on schedule.

> **Deprecated:** the older `Auth:ApiKey:Keys:<key>` shape, where the key itself was the setting
> name, is still accepted for one release, with a startup warning naming the entries. It put the
> key in configuration paths and environment-variable names, which tooling prints. Move each entry
> to `Clients`.

### Startup checks

The server validates its configuration at startup and refuses to start, with a message naming
the setting, when:

- `Auth:RequireAuthentication` is true and nothing could authenticate: no enabled API key and no JWT;
- outside Development, an API key is shorter than **32 characters**, or is a development key;
- a key has no `Permission`, or has `ContainerPermissions`;
- two entries share an `Id`, or two entries hold the same key (compared by hash, so a `Key` entry and a `Sha256` entry can collide);
- a `Key` is empty or whitespace, or a `Sha256` is the hash of the empty string. **`"Key": ""` fails startup**: an optional secret that's missing is no longer treated as unset;
- an entry sets both or neither of `Sha256` and `Key`;
- JWT is enabled with a missing, placeholder or too-short `SecretKey`, or without `Issuer`/`Audience`;
- `Auth:Jwt:Authority` is set;
- an `Authentication` section exists. The section is `Auth`.

An entry that has already expired at startup only logs a warning. Startup errors never contain a
key or a hash.

### JWTs

Tokens must be **HS256**-signed with `Auth:Jwt:SecretKey`, carry `exp`, and match the configured
issuer and audience. They're validated with a 30-second clock skew. The caller's permission comes
from the token's `permission` claim.

### Permissions

Every REST route requires a permission level. A key's `Permission`, or a JWT's `permission`
claim, is `read`, `write`, `admin` or `full`; `full` is the same as `admin`, and each level
includes the ones below it.

| Level | Routes |
|---|---|
| none | `/health`, `/health/live`, `/health/ready` |
| `read` | Containers: list, get, statistics. Documents: list, get, content, metadata, versions. Every `/api/query` call (execute, explain, validate, compile, stream). `/api/transform` and stylesheet list, get, content and validate. Schema list, get, content, versions and validation, and every `/api/v1/validate` call. |
| `write` | Containers: create, update, delete. Indexes: add, remove, rebuild. Documents: create, update, content, delete, metadata update, version restore. Stylesheets: register, update, delete, and clearing the transform cache. Schemas: register, update, delete, activate, and `POST /api/v1/schemas`. |
| `admin` | `/health/details`, `DELETE /api/v1/schemas/{name}`, and loading or unloading schema bundles. |

A credential without the level a route needs gets `403`. When `Auth:RequireAuthentication` is
`false`, an anonymous caller gets `401` on any write or admin route.

Queries and transformations are `read` routes: updating XQuery expressions aren't applied to
stored documents, and XSLT has no path that writes to the database.

## Resource Access

Queries and stylesheets sent to either server can read only the stored documents, unless you list
directories in `PhoenixmlDb:ResourceAccess:AllowedFileRoots` or origins in
`PhoenixmlDb:ResourceAccess:AllowedHttpOrigins`. Both are empty by default and validated at
startup. See [Resource Access](../resource-access.md).

### gRPC server

The gRPC server reads its keys from **`PhoenixmlDb:Auth:ApiKeys`**, a list with the same fields
and rules as above: `Id`, `Name`, `Sha256` or `Key`, `Enabled`, `Expires`, plus `Scopes` in place
of `Permission`:

| Scope | Allows |
|---|---|
| `read` | reading documents, containers, indexes and server status |
| `write` | everything in `read`, plus changing data and indexes |
| `admin` | everything in `write`, plus backup, restore and shutdown |

An entry with no `Scopes` gets `read` and `write`. Queries run with the `read` scope.
Updating expressions (XQuery Update Facility) are not applied to stored documents; use the
document APIs to write. Clients send the key as gRPC metadata,
`authorization: Bearer <key>`. A wrong key gets `Unauthenticated`. A valid key without the scope a
call needs gets `PermissionDenied`.

An entry without an `Id` still works for one release: it uses its `Name` as its `Id`, with a
startup warning. A `Key` must be at least 32 characters.

**Where it listens:** `PhoenixmlDb:Endpoints:ListenAddress` (default `127.0.0.1`), `Port` (default
`5000`) and `HttpsPort` (default `5001`). With no keys configured, the server accepts every call,
and so it **refuses to start on a non-loopback address unless at least one key is configured**.
A hostname counts as non-loopback.

The cluster's Raft traffic is authenticated separately, by the cluster secret and a TLS
certificate, and needs no API key.

## TLS

The gRPC server's TLS port uses Kestrel's standard certificate configuration, for example
`Kestrel:Certificates:Default:Path` and `Kestrel:Certificates:Default:Password`. The TLS port accepts
HTTP/1.1 as well as HTTP/2, so HTTPS health probes work against it. The plaintext port is HTTP/2
only and is bound on loopback. The cluster's Raft port has its own certificate settings; see
[Cluster Mode](cluster-mode.md#securing-the-raft-port).

## Load balancing

A single server needs no special handling behind a TCP or HTTP/2 load balancer. In a cluster, only
the leader accepts writes: a write sent to a follower is refused with the leader's id, and reads are
served from the node that receives them. See [Cluster Mode](cluster-mode.md#what-this-does-not-do-yet).

## Monitoring

### Health endpoints

Both servers expose the same endpoints. The public ones return **status only**: a plain-text body
of `Healthy`, `Degraded` or `Unhealthy`, with `200` for Healthy or Degraded and `503` for
Unhealthy.

| Endpoint | Auth | Checks |
|---|---|---|
| `/health/live` | anonymous | none: liveness only |
| `/health/ready` | anonymous | REST server: database, query engine, transform engine. gRPC server: storage, plus Raft when enabled. |
| `/health` | anonymous | the same as `/health/ready` |
| `/health/details` | **admin** | a JSON report with a fixed code and data per check, never exception text |

```bash
curl -i https://localhost:5001/health/ready
# HTTP/1.1 200 OK
# Healthy

curl -H "X-Api-Key: $ADMIN_KEY" https://localhost:5001/health/details
```

`/health/details` returns `401` without a credential and `403` for a key without admin permission.
Point a liveness probe at `/health/live`, and a readiness probe or load balancer at
`/health/ready`. On the gRPC server, `/healthz` is a deprecated alias of `/health` for one release,
and the standard `grpc.health.v1` service is available anonymously (overall service `""`; Degraded
maps to `SERVING`, Unhealthy to `NOT_SERVING`). The Raft port refuses health requests.

**Health codes** in the detailed report:

| Code | Status |
|---|---|
| `database_unavailable` | Unhealthy |
| `storage_map_nearly_full` | Degraded, when storage map usage reaches `PhoenixmlDb:Health:MapUsageDegradedPercent` (default 90, 1–100) |
| `raft_no_leader` | Degraded: a candidate, or a follower with no known leader |
| `raft_unavailable` | |
| `query_engine_unavailable`, `transform_engine_unavailable` | Unhealthy (REST server) |

A failed health check also logs event 3008 `HealthCheckFailed` (Error).

### Metrics and traces

The engine publishes metrics and traces through `System.Diagnostics`, under the names
`PhoenixmlDb.Storage`, `PhoenixmlDb.Indexing` and `PhoenixmlDb.Cluster`. See
[Logging: metrics and traces](../logging.md#metrics-and-traces).

## Containers

No container image is published. When you build one, configure the server through environment
variables:

```yaml
    environment:
      - PhoenixmlDb__Storage__DataPath=/data
      - PhoenixmlDb__Endpoints__ListenAddress=0.0.0.0
      # A non-loopback address needs at least one API key (PhoenixmlDb__Auth__ApiKeys__0__…).
```

## Best practices

1. **Use TLS** for anything that leaves the machine.
2. **Configure API keys** with the narrowest permission or scope each caller needs.
3. **Probe `/health/ready`** and alert on `Degraded` as well as `Unhealthy`.
4. **Back up** the data directory; replication is not a backup.

## Next Steps

| High Availability | Configuration | Support |
|-------------------|---------------|---------|
| **[Cluster Mode](cluster-mode.md)**<br>High availability | **[Configuration](../configuration.md)**<br>All settings | **[Troubleshooting](../troubleshooting.md)**<br>Problem solving |
