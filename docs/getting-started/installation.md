---
title: Installation
description: Platform requirements and NuGet packages
sort: 1
---

# Installation

## Package Availability

> **Note:** The PhoenixmlDb database packages are not yet published on NuGet. The commands
> below will not resolve until they are.

The database is split into the following packages. Each package ID is the project name.

| Package | Description | Use Case |
|---------|-------------|----------|
| `PhoenixmlDb.Storage` | LMDB storage core: `DocumentDatabase`, containers, documents, metadata, XQuery over a container | Embedded use (base package) |
| `PhoenixmlDb.Indexing` | Index maintenance, enabled with `db.EnableIndexing()` | Embedded use with indexes |
| `PhoenixmlDb.Client` | gRPC client SDK | Connect to a PhoenixmlDb server |

`PhoenixmlDb.Storage` depends on the published `PhoenixmlDb.Core` and `PhoenixmlDb.XQuery`
packages.

## Embedded Installation

For embedded use in a single application, once the packages are published:

```bash
dotnet add package PhoenixmlDb.Storage

# Optional: index maintenance
dotnet add package PhoenixmlDb.Indexing
```

## Engine Packages

The XQuery and XSLT engines the database is built on are published on NuGet and can be used
on their own, without the database:

```bash
dotnet add package PhoenixmlDb.XQuery
dotnet add package PhoenixmlDb.Xslt
```

The engine packages target `net8.0` and `net10.0`.

## Platform Requirements

- The database projects target **.NET 10** (`net10.0`).
- LMDB native binaries are supplied by the `LightningDB` package dependency, so no separate
  `liblmdb` install is needed.
- **Linux needs glibc 2.38 or later** (for example Ubuntu 24.04 or the `aspnet:10.0` image). Debian
  12, Ubuntu 22.04, RHEL 9 and Amazon Linux 2023 are not supported. See
  [Upgrading to LMDB 1.0](../phoenixmldb/deployment/lmdb-upgrade.md).
- ICU globalization must be available. Do not set `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`:
  the query engines depend on ICU for `normalize-unicode()`, collations, and regex character
  classes.

## Verifying Installation

Create a simple test to verify the installation:

```csharp
using PhoenixmlDb.Storage;

// Create a temporary database (the directory is created if missing)
var tempPath = Path.Combine(Path.GetTempPath(), "phoenixml-test");

await using (var db = new DocumentDatabase(tempPath))
{
    // Create a container
    var test = await db.CreateContainerAsync("test");

    // Store and retrieve a document
    await test.PutDocumentAsync("hello.xml", "<greeting>Hello, PhoenixmlDb!</greeting>");
    var doc = await test.GetDocumentAsync("hello.xml");

    Console.WriteLine(await doc!.GetContentAsync());
}

// Cleanup
Directory.Delete(tempPath, recursive: true);
Console.WriteLine("Installation verified successfully!");
```

## Next Steps

| Learn Basics | Configure | Deploy |
|---|---|---|
| **[Quick Start](quick-start.md)**<br>Learn the basics with hands-on examples. | **[Configuration](../phoenixmldb/configuration.md)**<br>Configure storage and performance options. | **[Deployment](../phoenixmldb/deployment/index.md)**<br>Deploy in server or cluster mode. |
