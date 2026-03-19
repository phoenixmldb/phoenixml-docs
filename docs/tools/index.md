---
title: Tools
description: PhoenixmlDb command-line tools — xslt, xquery, and crucible
sort: 5
---

# Tools

PhoenixmlDb provides three command-line tools for working with XML technologies on .NET:

| Tool | Purpose | Install |
|------|---------|---------|
| **[xslt](xslt-cli.md)** | Run XSLT 3.0/4.0 transformations | `dotnet tool install -g PhoenixmlDb.Xslt.Cli` |
| **[xquery](xquery-cli.md)** | Execute XQuery expressions against XML | `dotnet tool install -g PhoenixmlDb.XQuery.Cli` |
| **[crucible](crucible.md)** | Generate static documentation sites | `dotnet tool install -g Crucible.Cli` |

All three are .NET global tools — install once, use from anywhere on the command line.

## Quick Start

```bash
# Install the tools
dotnet tool install -g PhoenixmlDb.Xslt.Cli
dotnet tool install -g PhoenixmlDb.XQuery.Cli
dotnet tool install -g Crucible.Cli

# Transform XML to HTML
xslt stylesheet.xsl data.xml -o output.html

# Query XML files
xquery '//product[price > 50]/name' catalog.xml

# Build a documentation site
crucible init
crucible build
```

## Prerequisites

All tools require:
- **.NET 10 SDK** or later
- **ICU globalization** — see [Unicode and .NET Requirements](/xml-foundations/unicode-and-dotnet.md) for details

Ensure `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` is **not** set to `1` in your environment.
