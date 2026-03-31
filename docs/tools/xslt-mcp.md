---
title: XSLT MCP Server
---

# XSLT MCP Server

An [MCP](https://modelcontextprotocol.io) server that gives AI agents access to XSLT spec reference and the PhoenixmlDb XSLT engine. Look up instructions, functions, and error codes. Validate and execute stylesheets.

## Install

### Self-contained binary (no .NET required)

Download from [GitHub Releases](https://github.com/phoenixmldb/xslt-mcp/releases):

| Platform | Binary |
|----------|--------|
| Linux x64 | `xslt-mcp-linux-x64` |
| Linux ARM64 | `xslt-mcp-linux-arm64` |
| macOS x64 | `xslt-mcp-osx-x64` |
| macOS ARM64 | `xslt-mcp-osx-arm64` |
| Windows x64 | `xslt-mcp-win-x64.exe` |

### .NET tool

```bash
dotnet tool install -g xslt-mcp
```

## Configure

### Claude Code

Add to `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "xslt": {
      "command": "xslt-mcp"
    }
  }
}
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "xslt": {
      "command": "xslt-mcp",
      "args": []
    }
  }
}
```

## Tools

### Spec Reference

- **xslt_lookup_instruction** — Look up any XSLT instruction (attributes, content model, examples)
- **xslt_lookup_function** — Look up XPath/XSLT functions (signature, parameters, return type)
- **xslt_lookup_output_method** — Look up output methods (xml, html, json, text, etc.)
- **xslt_lookup_error_code** — Look up error codes with descriptions and fix suggestions
- **xslt_search** — Full-text search across all 295 spec entries
- **xslt_list_instructions** — List all 74 XSLT instructions
- **xslt_list_functions** — List all 163 functions by category

### Execution

- **xslt_transform** — Run an XSLT transformation and get the output
- **xslt_validate** — Compile a stylesheet without executing
- **xpath_evaluate** — Evaluate an XPath expression against XML
- **xslt_explain_error** — Explain an error code with causes and fixes

### Utilities

- **xml_validate_schema** — Validate XML against an XSD schema
- **xml_format** — Pretty-print XML

## How It Works

The server bundles 295 spec reference files covering XSLT 3.0/4.0, XPath 3.1, and Functions & Operators. At startup, it loads them into an in-memory index. Lookup tools search the index; execution tools delegate to the PhoenixmlDb.Xslt engine.

When installed as a dotnet tool or self-contained binary, spec files are embedded as assembly resources. For local development, override the spec path:

```bash
XSLT_SPEC_PATH=/path/to/spec xslt-mcp
```

## Source

[github.com/phoenixmldb/xslt-mcp](https://github.com/phoenixmldb/xslt-mcp)
