---
title: xslt CLI
description: Command-line XSLT 3.0/4.0 processor — transform XML documents from the terminal
sort: 1
---

# xslt CLI

The `xslt` command-line tool transforms XML documents using XSLT 3.0/4.0 stylesheets. It's powered by the PhoenixmlDb XSLT engine — the same engine used by Crucible and available as a .NET library.

## Installation

```bash
dotnet tool install -g PhoenixmlDb.Xslt.Cli
```

After installation, the `xslt` command is available globally.

## Usage

```
xslt [options] <stylesheet> [source]
command | xslt [options] <stylesheet>
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<stylesheet>` | Path to the XSLT stylesheet (`.xsl` or `.xslt`) |
| `[source]` | Path to the source XML document (optional — some transforms don't need input) |

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--output <path>` | `-o` | Write output to a file instead of stdout |
| `--output-dir <dir>` | | Base directory for secondary result documents (`xsl:result-document`) |
| `--param <name>=<value>` | `-p` | Set a stylesheet parameter (repeatable) |
| `--initial-template <name>` | `-it` | Start with a named template instead of matching |
| `--initial-mode <name>` | `-im` | Set the initial mode for template matching |
| `--timing` | | Show parse/compile/transform timing breakdown |
| `--trace` | | Log template matching, function calls, built-in rules |
| `--dry-run` | | Parse and compile only — validate without executing |
| `--verbose` | `-v` | Show detailed error information (stack traces) |
| `--help` | `-h` | Show help message |
| `--version` | | Show version information |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error (bad arguments, file not found) |
| 2 | XSLT or XPath error (compile or runtime failure) |

## Examples

### Basic Transform

Transform an XML document to HTML:

```bash
xslt report.xsl data.xml
```

Output goes to stdout. Redirect or use `-o` to save:

```bash
xslt report.xsl data.xml -o report.html
```

### Passing Parameters

Set stylesheet parameters from the command line:

```bash
xslt -p title="Q1 Report" -p year=2026 report.xsl data.xml -o report.html
```

In the stylesheet, access them with `<xsl:param name="title"/>` and `$title`.

### Named Template Invocation

Start with a specific named template instead of matching the document root:

```bash
xslt -it main generate.xsl
```

This is useful for stylesheets that generate output without needing an input document — for example, generating a configuration file or a static page.

### Initial Mode

Apply templates in a specific mode:

```bash
xslt -im toc book.xsl chapter.xml -o toc.html
```

### Multiple Output Documents

When a stylesheet uses `xsl:result-document` to produce multiple files, specify the output directory:

```bash
xslt --output-dir ./pages book-to-html.xsl book.xml
```

The primary output goes to stdout (or `-o`), and secondary documents are written to `./pages/` relative to their `href` attributes.

### Reading from stdin

Pipe XML input from another command:

```bash
curl https://api.example.com/data.xml | xslt transform.xsl
cat data.xml | xslt transform.xsl -o result.html
```

### Performance Profiling

See where time is spent:

```bash
xslt --timing style.xsl large-input.xml
```

Output (to stderr):
```
  read:        2.3 ms  (15,234 chars)
  compile:    12.1 ms
  source:      1.8 ms  (142,567 chars)
  transform:  45.7 ms  (23,456 chars output)
  total:      61.9 ms
```

### Tracing

Watch template matching and function calls for debugging:

```bash
xslt --trace style.xsl data.xml 2>trace.log
```

Trace output (to stderr):
```
  [MatchTemplate] match="/" priority=0.5
    [MatchTemplate] match="product" priority=0
      [CallFunction] my:format-price($amount=29.99)
    [MatchTemplate] match="product" priority=0
      [CallFunction] my:format-price($amount=89.99)
```

### Validation Only

Check that a stylesheet compiles without running it:

```bash
xslt --dry-run style.xsl
```

Exits with code 0 if the stylesheet is valid, 2 if there are errors. Useful in CI/CD pipelines.

## Real-World Workflows

### Generate HTML Documentation from XML

```bash
xslt docs-to-html.xsl api-spec.xml -o docs/api.html
```

### Convert Between XML Formats

```bash
# Convert DocBook to HTML
xslt docbook-html.xsl manual.xml -o manual.html

# Convert between data formats
xslt orders-to-csv.xsl orders.xml -o orders.csv
```

### Batch Transform with Shell

```bash
for file in data/*.xml; do
  base=$(basename "$file" .xml)
  xslt report.xsl "$file" -o "output/${base}.html"
done
```

### CI/CD Pipeline

```yaml
# GitHub Actions example
- name: Generate reports
  run: |
    xslt --dry-run report.xsl  # Validate stylesheet
    xslt --timing report.xsl data.xml -o dist/report.html
```

### Integration with jq (JSON Output)

```bash
# Transform XML to JSON, then query with jq
xslt xml-to-json.xsl catalog.xml | jq '.products[] | select(.price > 50)'
```

## Using from .NET Code

The same engine is available as a library:

```csharp
using PhoenixmlDb.Xslt;

var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(
    File.ReadAllText("style.xsl"),
    new Uri(Path.GetFullPath("style.xsl")));

transformer.SetParameter("title", "My Report");
var html = await transformer.TransformAsync(
    File.ReadAllText("data.xml"));

// Handle secondary result documents
foreach (var (href, content) in transformer.SecondaryResultDocuments)
    File.WriteAllText(Path.Combine(outputDir, href), content);
```

See [XSLT Extensibility](/xslt/extensibility.md) for details on programmatic usage.
