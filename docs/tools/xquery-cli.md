---
title: xquery CLI
description: Command-line XQuery processor — query XML documents from the terminal
sort: 2
---

# xquery CLI

The `xquery` command-line tool executes XQuery expressions against XML files, directories, or URLs. Think of it as `jq` for XML — but with the full power of XQuery 4.0.

## Installation

```bash
dotnet tool install -g PhoenixmlDb.XQuery.Cli
```

After installation, the `xquery` command is available globally.

## Usage

```
xquery [options] <expression> [sources...]
xquery [options] -f <query-file> [sources...]
command | xquery [options] <expression>
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<expression>` | Inline XQuery expression to execute |
| `[sources...]` | XML files, directories, or URLs to query |

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--file <path>` | `-f` | Read XQuery from a file instead of inline |
| `--output <method>` | `-o` | Output method: `adaptive` (default), `xml`, `text` |
| `--stdin` | | Read XML input from stdin (waits indefinitely) |
| `--timeout <ms>` | | Stdin auto-detection timeout in ms (default: 200) |
| `--timing` | | Show parse/compile/execute timing breakdown |
| `--plan` | | Show the execution plan before running |
| `--dry-run` | | Parse and compile only — validate without executing |
| `--verbose` | `-v` | Show detailed error information |
| `--help` | `-h` | Show help message |
| `--version` | | Show version information |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error |
| 2 | Parse error |
| 3 | Runtime error |

## Source Documents

The `xquery` tool supports three types of source input:

| Source | Description |
|--------|-------------|
| **File** | Path to an XML file — loaded as a `doc()` target |
| **Directory** | Path to a directory — all `*.xml` files loaded |
| **URL** | HTTP/HTTPS URL — XML fetched from the network |

When a **single source** is provided, it becomes the context item (`.`), so you can write XPath directly:

```bash
xquery '//title' books.xml
```

**All sources** are available via `doc($uri)` by their path or URL. `collection()` returns all loaded documents.

## Examples

### Quick Queries

The most common use — XPath expressions against a file:

```bash
# Select all titles
xquery '//title' catalog.xml

# Count elements
xquery 'count(//product)' catalog.xml

# Filter by attribute
xquery '//product[@category="electronics"]/name' catalog.xml

# Get attribute values
xquery '//product/@id' catalog.xml
```

**C# developer note:** This is like running LINQ queries from the command line — no project setup, no compilation, just query and get results.

### FLWOR Queries

Use single quotes to wrap multi-line expressions:

```bash
xquery '
  for $book in //book
  where $book/price > 30
  order by $book/price descending
  return concat($book/title, " — $", $book/price)
' catalog.xml
```

### Query Files

For complex queries, write them in a `.xq` file:

```bash
xquery -f report.xq catalog.xml
```

**report.xq:**
```xquery
for $cat in distinct-values(//product/@category)
let $products := //product[@category = $cat]
order by $cat
return <category name="{ $cat }">
  <count>{ count($products) }</count>
  <avg-price>{ format-number(avg($products/price), '#.00') }</avg-price>
</category>
```

### Multiple Source Files

Query across multiple documents:

```bash
# Multiple files
xquery 'count(collection()//product)' products.xml orders.xml

# An entire directory
xquery 'collection()//error' ./logs/

# Join data across files
xquery '
  for $order in doc("orders.xml")//order
  let $customer := doc("customers.xml")//customer[@id = $order/@customer-id]
  return concat($order/@id, ": ", $customer/name)
' orders.xml customers.xml
```

### Reading from stdin

Pipe XML from another command:

```bash
curl https://api.example.com/data.xml | xquery '//item/name'
cat data.xml | xquery 'count(//error)'
```

### JSON Output

Query XML documents and output results as JSON:

```bash
xquery '
  array {
    for $p in //product
    return map {
      "name": string($p/name),
      "price": number($p/price)
    }
  }
' catalog.xml
```

### Working with JSON Input

Query JSON files using `json-doc()`:

```bash
xquery '
  let $data := json-doc("config.json")
  return $data?settings?theme
'
```

### Execution Plan

See how the query engine plans to execute your query:

```bash
xquery --plan 'for $x in //product order by $x/price return $x/name' catalog.xml
```

This shows the query plan before execution — useful for understanding performance characteristics of complex queries.

### Performance Profiling

```bash
xquery --timing '//product[price > 50]' large-catalog.xml
```

Output (to stderr):
```
  parse:     1.2 ms
  compile:   3.4 ms
  execute:  12.8 ms  (15 results)
  total:    17.4 ms
```

### Validation Only

Check that a query compiles without running it:

```bash
xquery --dry-run -f complex-query.xq
```

## Real-World Workflows

### Data Extraction

```bash
# Extract all email addresses from an XML dataset
xquery '//contact/email' contacts.xml

# Get unique categories
xquery 'distinct-values(//product/@category)' catalog.xml

# Find duplicates
xquery '
  for $name in //product/name
  group by $n := string($name)
  where count($name) > 1
  return concat($n, " (", count($name), " occurrences)")
' catalog.xml
```

### Data Validation

```bash
# Find products with missing prices
xquery '//product[not(price)]/@id' catalog.xml

# Find orders with negative amounts
xquery '//order[total < 0]' orders.xml

# Validate email format
xquery '//email[not(matches(., "^[^@]+@[^@]+\.[^@]+$"))]' contacts.xml
```

### Format Conversion

```bash
# XML to CSV
xquery '
  string-join((
    "id,name,price",
    for $p in //product
    return string-join(($p/@id, $p/name, $p/price), ",")
  ), "&#10;")
' -o text catalog.xml > products.csv

# XML to Markdown
xquery '
  string-join((
    "# Products",
    "",
    for $p in //product
    return concat("- **", $p/name, "** — $", $p/price)
  ), "&#10;")
' -o text catalog.xml > products.md
```

### Aggregation and Reporting

```bash
# Summary statistics
xquery '
  let $products := //product
  return map {
    "count": count($products),
    "total": sum($products/price),
    "average": round(avg($products/price), 2),
    "min": min($products/price),
    "max": max($products/price)
  }
' catalog.xml
```

### Shell Pipeline Integration

```bash
# Combine with other tools
xquery '//product/name' catalog.xml | sort | uniq -c | sort -rn

# Feed into jq for further JSON processing
xquery 'array { //product ! map { "name": string(name), "price": number(price) } }' catalog.xml \
  | jq '.[] | select(.price > 50)'

# Watch for changes
watch -n 5 'xquery "count(//error)" /var/log/app/*.xml'
```

## Comparison with Other Tools

| Task | xquery | jq | xmlstarlet | grep |
|------|--------|-----|------------|------|
| Query XML | Native | No XML support | Basic XPath 1.0 | Text only |
| Query JSON | `json-doc()` | Native | No JSON support | Text only |
| FLWOR queries | Full XQuery | Limited | No | No |
| Cross-file joins | `doc()`, `collection()` | Requires scripting | Single file | No |
| Format conversion | XML/JSON/CSV/text | JSON only | XML only | No |
| Type-aware | xs:date, xs:decimal, etc. | Limited | No | No |

## Using from .NET Code

The same engine is available as a library. See [XQuery Extensibility](/xquery/extensibility.md) for programmatic usage including setting variables, registering extension functions, and reading results.
