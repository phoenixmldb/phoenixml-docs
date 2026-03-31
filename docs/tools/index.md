---
title: Tools
description: PhoenixmlDb command-line tools and MCP servers
sort: 4
---

# Tools

## Command-Line Tools

| Tool | Purpose | Install |
|------|---------|---------|
| **[xslt](xslt-cli.md)** | Run XSLT 3.0/4.0 transformations | `dotnet tool install -g PhoenixmlDb.Xslt.Cli` |
| **[xquery](xquery-cli.md)** | Execute XQuery expressions against XML | `dotnet tool install -g PhoenixmlDb.XQuery.Cli` |
| **[crucible](crucible.md)** | Generate static documentation sites | `dotnet tool install -g crucible` |

All three are .NET global tools — install once, use from anywhere on the command line.

## MCP Servers

AI-native tools that give language models (Claude, GPT, etc.) access to spec reference and engine execution via the [Model Context Protocol](https://modelcontextprotocol.io).

| Server | Purpose | Install |
|--------|---------|---------|
| **[xslt-mcp](xslt-mcp.md)** | XSLT spec lookup + transform/validate/XPath | `dotnet tool install -g xslt-mcp` or [download binary](https://github.com/phoenixmldb/xslt-mcp/releases) |
| **[xquery-mcp](xquery-mcp.md)** | XQuery spec lookup + evaluate/validate/XPath | `dotnet tool install -g xquery-mcp` or [download binary](https://github.com/phoenixmldb/xquery-mcp/releases) |

MCP servers are also available as self-contained binaries — no .NET SDK required.

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
- **ICU globalization** — see [Unicode and .NET Requirements](/language-reference/xml-foundations/unicode-and-dotnet.md) for details

Ensure `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` is **not** set to `1` in your environment.
