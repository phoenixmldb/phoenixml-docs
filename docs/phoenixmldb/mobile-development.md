---
title: Mobile Development
description: Mobile SDKs are not available yet; what exists in the source tree, and what a mobile app can use today
sort: 14
---

# Mobile Development

> **Not available yet.** There is no usable mobile SDK. The .NET project (`PhoenixmlDb.Mobile`)
> doesn't currently build and isn't packaged, `dotnet add package PhoenixmlDb.Mobile` finds nothing,
> and the native SDKs are scaffolds (phoenixml #78). Use the REST API below from a mobile app.

This page describes what exists in the source tree and what a mobile app can use today.

## SDK Status

| Platform | Source | Language | Status |
|----------|--------|----------|--------|
| iOS/Android (.NET) | `src/PhoenixmlDb.Mobile` | C# | Scaffold; server calls not implemented; not published |
| iOS (Native) | `native/phoenixml-ios` | Swift | Scaffold; server calls not implemented; not published |
| Android (Native) | `native/phoenixml-android` | Kotlin | Scaffold; server calls not implemented; not published |
| Any Platform | EPS server REST API | HTTP/JSON | Available |

All three SDKs are scaffolds for a gRPC client with a local offline cache. In each of them the
calls that would talk to the server are placeholders that do nothing:

- **Connecting** creates a channel but does not contact the server, so it reports success
  whether or not a server is there.
- **Writes** made while "connected" are not sent to the server, and are not queued for sync
  either, so they never reach it. (The .NET SDK also writes them to its local cache when offline
  mode is on.)
- **Reads** from the server return nothing (the .NET SDK then falls back to its local cache);
  listing containers and running queries return empty results.
- **Sync** sends queued offline changes through the same placeholder calls, then marks them
  synced.

Do not use them for real data. None of them is published to NuGet, Swift Package Manager or
Maven. `PhoenixmlDb.Mobile` targets `net10.0`, `net10.0-ios` and `net10.0-android`, needs the
iOS and Android workloads to build, and is excluded from the main solution.

## What exists in PhoenixmlDb.Mobile

For orientation only, since the remote side does nothing yet:

- `MobileDatabase(MobileDatabaseOptions options, ILogger<MobileDatabase>? logger = null)`, with
  `ConnectAsync`, `OpenContainerAsync`, `CreateContainerAsync`, `ListContainersAsync`,
  `QueryAsync(containerName, xquery, variables)`, `SyncAsync`, `IsConnected`,
  `OfflineModeEnabled` and a `ConnectionStateChanged` event.
- `MobileDatabaseOptions` (`ServerAddress`, required; `EnableOfflineMode`, default `true`;
  `LocalDatabasePath`; `ConnectionOptions`).
- `MobileContainer` with `PutXmlDocumentAsync`, `PutJsonDocumentAsync`, `GetXmlDocumentAsync`,
  `GetJsonDocumentAsync`, `UpdateDocumentAsync`, `DeleteDocumentAsync`, `ListDocumentsAsync` and
  `GetPendingChangesCountAsync`.
- `services.AddPhoenixmlDb(MobileDatabaseOptions)` to register a singleton `MobileDatabase`.

The offline cache is SQLite on iOS and Android builds and in-memory on the plain `net10.0` build.

## REST API

A mobile app on any platform can call the EPS server's REST API over HTTPS. Its endpoints include:

```http
GET    /api/containers                                    # List containers
POST   /api/containers                                    # Create container
GET    /api/containers/{containerId}                      # Get container
DELETE /api/containers/{containerId}                      # Delete container

GET    /api/containers/{containerId}/documents            # List documents
POST   /api/containers/{containerId}/documents            # Create document
GET    /api/containers/{containerId}/documents/{documentId}          # Get document
GET    /api/containers/{containerId}/documents/{documentId}/content  # Get raw content
PUT    /api/containers/{containerId}/documents/{documentId}          # Update document
DELETE /api/containers/{containerId}/documents/{documentId}          # Delete document

POST   /api/query                                         # Execute XQuery
POST   /api/query/containers/{containerId}                # Execute XQuery in a container
POST   /api/query/explain                                 # Explain query plan
POST   /api/query/stream                                  # Streaming query
```

Callers authenticate with an API key or a JWT. Create, update and delete need `write` (or
`admin`/`full`) permission; reads need `read` permission, unless the server is configured with
`RequireAuthentication` set to `false`, which allows anonymous reads only. See [Server Mode](deployment/server-mode.md) for
setting up the server and its authentication.

## Platform Requirements

The `PhoenixmlDb.Mobile` project file declares these minimum OS versions:

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 15.0 |
| Android | API 24 (Android 7.0) |
