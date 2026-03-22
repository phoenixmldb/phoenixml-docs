---
title: Installation
description: Platform requirements, NuGet packages, and building from source
sort: 1
---

# Installation

PhoenixmlDb is distributed as NuGet packages. Choose the packages that match your deployment scenario.

## Package Options

| Package | Description | Use Case |
|---------|-------------|----------|
| `PhoenixmlDb` | Core embedded database | Single-application embedded use |
| `PhoenixmlDb.Server` | gRPC server | Multi-client server deployment |
| `PhoenixmlDb.Client` | Client SDK | Connect to PhoenixmlDb server |
| `PhoenixmlDb.Cluster` | Clustering support | Distributed high-availability |

## Embedded Installation

For embedded use in a single application:

**.NET CLI**

```bash
dotnet add package PhoenixmlDb
```

**Package Manager**

```powershell
Install-Package PhoenixmlDb
```

**PackageReference**

```xml
<PackageReference Include="PhoenixmlDb" Version="1.0.0" />
```

## Server Installation

For multi-client server deployment:

```bash
# Server package
dotnet add package PhoenixmlDb.Server

# Client SDK (for client applications)
dotnet add package PhoenixmlDb.Client
```

## Cluster Installation

For distributed deployment with high availability:

```bash
dotnet add package PhoenixmlDb.Cluster
```

## Platform Requirements

### Windows

- Windows 10 version 1607 or later
- Windows Server 2016 or later
- .NET 10.0 runtime

### Linux

- Ubuntu 20.04, 22.04, or 24.04
- Debian 11 or 12
- RHEL 8 or 9
- .NET 10.0 runtime
- `liblmdb` (usually included, or install via package manager)

```bash
# Ubuntu/Debian
sudo apt-get install liblmdb-dev

# RHEL/CentOS
sudo dnf install lmdb-devel
```

### macOS

- macOS 12 (Monterey) or later
- .NET 10.0 runtime
- `lmdb` via Homebrew (optional, native library included)

```bash
brew install lmdb
```

## Verifying Installation

Create a simple test to verify the installation:

```csharp
using PhoenixmlDb;

// Create a temporary database
var tempPath = Path.Combine(Path.GetTempPath(), "phoenixml-test");
using var db = new XmlDatabase(tempPath);

// Create a container
var test = db.CreateContainer("test");

// Store and retrieve a document
test.PutDocument("hello.xml", "<greeting>Hello, PhoenixmlDb!</greeting>");
var doc = test.GetDocument("hello.xml");

Console.WriteLine(doc);
// Output: <greeting>Hello, PhoenixmlDb!</greeting>

// Cleanup
Directory.Delete(tempPath, recursive: true);
Console.WriteLine("Installation verified successfully!");
```

## Build from Source

To build PhoenixmlDb from source:

```bash
# Clone the repository
git clone https://github.com/endpointsystems/phoenixml.git
cd phoenixml

# Build
dotnet build

# Run tests
dotnet test

# Create packages
dotnet pack -c Release
```

## Next Steps

| Learn Basics | Configure | Deploy |
|---|---|---|
| **[Quick Start](quick-start.md)**<br>Learn the basics with hands-on examples. | **[Configuration](../reference/configuration.md)**<br>Configure storage and performance options. | **[Deployment](../deployment/overview.md)**<br>Deploy in server or cluster mode. |
