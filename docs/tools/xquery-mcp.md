---
title: XQuery MCP Server
---

# XQuery MCP Server

An [MCP](https://modelcontextprotocol.io) server that gives AI agents access to XQuery spec reference and the PhoenixmlDb XQuery engine. Look up expressions, functions, and error codes. Validate and execute queries.

## Install

### Self-contained binary (no .NET required)

Download from [GitHub Releases](https://github.com/phoenixmldb/xquery-mcp/releases):

| Platform | Binary |
|----------|--------|
| Linux x64 | `xquery-mcp-linux-x64` |
| Linux ARM64 | `xquery-mcp-linux-arm64` |
| macOS x64 | `xquery-mcp-osx-x64` |
| macOS ARM64 | `xquery-mcp-osx-arm64` |
| Windows x64 | `xquery-mcp-win-x64.exe` |

### .NET tool

```bash
dotnet tool install -g xquery-mcp
```

## Configure

### Claude Code

Add to `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "xquery": {
      "command": "xquery-mcp"
    }
  }
}
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "xquery": {
      "command": "xquery-mcp",
      "args": []
    }
  }
}
```

## Tools

### Spec Reference

- **xquery_lookup_expression** — Look up XQuery expressions (FLWOR, path, typeswitch, etc.)
- **xquery_lookup_function** — Look up XPath/XQuery functions (signature, parameters, examples)
- **xquery_lookup_prolog** — Look up prolog declarations (namespaces, functions, modules)
- **xquery_lookup_error_code** — Look up error codes with descriptions and fix suggestions
- **xquery_search** — Full-text search across all spec entries
- **xquery_list_expressions** — List all expression types
- **xquery_list_functions** — List all functions by category

### Execution

- **xquery_evaluate** — Execute an XQuery expression with optional XML input
- **xquery_validate** — Compile a query without executing
- **xpath_evaluate** — Evaluate an XPath expression against XML
- **xquery_explain_error** — Explain an error code with causes and fixes

### Utilities

- **xml_validate_schema** — Validate XML against an XSD schema
- **xml_format** — Pretty-print XML

## How It Works

The server bundles spec reference files covering XQuery 3.1, XPath 3.1, Functions & Operators, and the Update Facility. At startup, it loads them into an in-memory index. Lookup tools search the index; execution tools delegate to the PhoenixmlDb.XQuery engine.

## Source

[github.com/phoenixmldb/xquery-mcp](https://github.com/phoenixmldb/xquery-mcp)
