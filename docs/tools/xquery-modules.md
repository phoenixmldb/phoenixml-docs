---
title: XQuery and XSLT modules
description: XQuery 3.1 and XSLT 3.0 library modules for JSON, XML, CSV and YAML
sort: 5
---

# XQuery and XSLT modules

Library modules make common JSON, XML, CSV and YAML tasks short: load files, select values, group,
count, compare, and convert between formats. They are plain XQuery 3.1 and XSLT 3.0 source, so
they run on the [`xquery`](xquery-cli.md) and [`xslt`](xslt-cli.md) tools, the PhoenixmlDb engines
and other XQuery 3.1 and XSLT 3.0 processors.

| Module | Language | Namespace | File |
|---|---|---|---|
| JSON (`pj`) | XQuery | `https://phoenixml.dev/modules/json` | [`json.xqm`](https://phoenixml.dev/modules/1.1.0/json.xqm) |
| XML (`px`) | XQuery | `https://phoenixml.dev/modules/xml` | [`xml.xqm`](https://phoenixml.dev/modules/1.1.0/xml.xqm) |
| CSV (`pc`) | XQuery | `https://phoenixml.dev/modules/csv` | [`csv.xqm`](https://phoenixml.dev/modules/1.1.0/csv.xqm) |
| Report (`pr`) | XQuery | `https://phoenixml.dev/modules/report` | [`report.xqm`](https://phoenixml.dev/modules/1.1.0/report.xqm) |
| JSON to XML (`jx`) | XSLT | `https://phoenixml.dev/modules/xslt/json` | [`json.xsl`](https://phoenixml.dev/modules/1.1.0/json.xsl) |
| YAML (`yx`) | XSLT | `https://phoenixml.dev/modules/xslt/yaml` | [`yaml.xsl`](https://phoenixml.dev/modules/1.1.0/yaml.xsl) |

The source, tests and releases are in the
[xquery-modules repository](https://github.com/phoenixmldb/xquery-modules). The license is
Apache 2.0.

## Import a module

The `at` URL of an XQuery import, or the `href` of an `xsl:import`, tells the processor where to
read the module. The processor reads the file when it compiles the query or stylesheet; nothing is
installed.

```xquery
import module namespace pj = "https://phoenixml.dev/modules/json"
  at "https://phoenixml.dev/modules/1.1.0/json.xqm";

pj:select(pj:load("orders.json", static-base-uri()), "items.*.name")
```

```xml
<xsl:import href="https://phoenixml.dev/modules/1.1.0/yaml.xsl"/>
```

The namespace is the module's name only; the processor does not read anything from it.

**Use a version in the URL**, such as `1.1.0`. The file at a version URL does not change; a new
release gets a new version URL. The same files are in the GitHub repository, for example at
`https://raw.githubusercontent.com/phoenixmldb/xquery-modules/v1.1.0/modules/json.xqm`.

**Or use a local copy.** Download the file, put it next to your query, and import it by its path.
A local copy does not need the network, and you control which code your queries run:

```xquery
import module namespace pj = "https://phoenixml.dev/modules/json" at "json.xqm";
```

**Resource policy.** A host that runs queries under a `ResourcePolicy` must allow the module URL
for import, and the data files for reading. The import rules, settings and limits are in
[XQuery library modules](/phoenixmldb/xquery-modules.md).

## Relative paths

A relative path in a library module resolves against the module's own location, not against your
query. For a module read from phoenixml.dev, `"orders.json"` would point to phoenixml.dev. The
`load` functions therefore take your query's base URI as a second argument:

```xquery
pj:load(("a.json", "b.json"), static-base-uri())
```

With one argument, `load` takes absolute URIs only, and a relative path raises the error
`pj:relative-uri` (or `px:relative-uri`, `pc:relative-uri`).

## JSON functions (`pj`)

| Function | Result |
|---|---|
| `pj:load($uris)` | Each JSON file, parsed. The URIs must be absolute. |
| `pj:load($paths, $base)` | Each JSON file, parsed. Paths resolve against `$base`. |
| `pj:select($json, $path)` | Values at a dotted path. A step is a key, `*` (all members or values), or an array position from 1: `"items.*.name"`, `"items.2.price"`. |
| `pj:find($json, $key)` | All values of field `$key` at any depth. |
| `pj:flatten($json)` | A map from each dotted path (`"items.1.name"`) to its value. |
| `pj:records($json)` | All array members, with nested arrays flattened. |
| `pj:pick($records, $fields)` | Each record with only the fields in `$fields`. |
| `pj:sort-by($records, $field)` | The records in order of a field, smallest first; `pj:sort-by($records, $field, true())` gives largest first. Records without the field come last. |
| `pj:group-by($records, $key)` | A map from each value of field `$key` to an array of its records. |
| `pj:to-csv($records, $fields)` | CSV text with a header row. Values with a comma, quote or line break are quoted; maps and arrays are written as JSON. |
| `pj:to-xml($json)` | The W3C XML representation (`fn:json-to-xml`). For readable XML, see `jx:to-xml`. |

```xquery
(: Items over 3, from two files, as CSV :)
let $items := pj:records(pj:load(("data/a.json", "data/b.json"), static-base-uri())?items)
return pj:to-csv($items[?price > 3], ("name", "price"))
```

## XML functions (`px`)

| Function | Result |
|---|---|
| `px:load($uris)` | Each XML document. The URIs must be absolute. |
| `px:load($paths, $base)` | Each XML document. Paths resolve against `$base`. |
| `px:outline($node)` | The element structure: one line for each element path, with counts and attribute names. Use it to explore a file you do not know. |
| `px:to-json($element)` | A JSON-ready value: `"@name"` for attributes, the local name for child elements (an array when a name repeats), `"#text"` for text. An element with no attributes and no children gives its string value. |
| `px:to-csv($elements, $fields)` | CSV text with a header row. A field is a child element name or `@attribute`. |
| `px:strip-namespaces($node)` | A copy with local names only. |
| `px:path($node)` | A readable path, for example `/catalog[1]/product[2]/@id`. |
| `px:diff($a, $b)` | The paths where two nodes differ (names, attributes, text, children by position). Whitespace-only text is ignored. |
| `px:count-by($items, $key)` | A map from each key to its count. `$key` is a function. |

```xquery
(: What is in this file? :)
px:outline(px:load("catalog.xml", static-base-uri()))
```

```
catalog (1)
  product (3) @category @id
    name (3)
    price (3)
    tag (2)
  x:note (1)
    b (1)
```

## CSV functions (`pc`)

The parser follows RFC 4180: a quoted field can hold the separator, line breaks and quotes (`""`).
Blank lines are skipped. All values are strings; cast them where you need numbers.

| Function | Result |
|---|---|
| `pc:load($uris)` / `pc:load($paths, $base)` | Each CSV file with a header row, as records (maps from header name to value). |
| `pc:parse($text)` / `pc:parse($text, $separator)` | Records from CSV text with a header row. A missing value is `""`. |
| `pc:rows($text)` / `pc:rows($text, $separator)` | Each row as an array of strings, with no header handling. |
| `pc:header($text)` | The header names, in column order. |
| `pc:to-xml($records, $fields)` | `<csv><row><name>…</name>…</row></csv>`. A field name that is not an XML name gives `<field name="…">`. |

```xquery
let $orders := pc:load("orders.csv", static-base-uri())
return sum($orders ! xs:decimal(?total))
```

## Report functions (`pr`)

| Function | Result |
|---|---|
| `pr:stats($values)` | `map { "count", "sum", "min", "max", "avg" }` of the values that are numbers. |
| `pr:table($records, $fields)` | A text table with aligned columns, for terminal output. A record is a map or an element. |

```xquery
pr:table(pj:load("a.json", static-base-uri())?items?*, ("name", "price"))
```

```
name  price
----  -----
pen   2.5
ink   7
```

## XSLT: JSON and YAML to XML

Both give the same readable XML form:

- an object member gives an element named by its key; a key that is not an XML name gives
  `<entry key="…">`;
- an array gives one `<item>` child for each member;
- a string, number or boolean gives its text; null gives an empty element;
- member order is kept.

| Function | Result |
|---|---|
| `jx:to-xml($json, $root)` | JSON text as readable XML, with a root element named `$root`. |
| `jx:from-w3c($element, $root)` | The result of `fn:json-to-xml` as readable XML. |
| `yx:to-xml($yaml, $root)` | YAML text as readable XML. |
| `yx:to-json($yaml)` | YAML text as JSON text. |
| `yx:parse($yaml)` | YAML text as maps and arrays, as `parse-json` gives them. |
| `yx:to-w3c($yaml)` | YAML text as the W3C XML representation of JSON. |

```xml
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:yx="https://phoenixml.dev/modules/xslt/yaml">
  <xsl:import href="https://phoenixml.dev/modules/1.1.0/yaml.xsl"/>
  <xsl:template name="xsl:initial-template">
    <xsl:sequence select="yx:to-xml(unparsed-text('config.yaml'), 'config')"/>
  </xsl:template>
</xsl:stylesheet>
```

From the command line, [`json-to-xml.xsl`](https://phoenixml.dev/modules/1.1.0/json-to-xml.xsl) and [`yaml-to-xml.xsl`](https://phoenixml.dev/modules/1.1.0/yaml-to-xml.xsl) convert one file:

```bash
xslt -it main https://phoenixml.dev/modules/1.1.0/yaml-to-xml.xsl -p href="file://$PWD/config.yaml" -p root=config
```

`href` is a URI. A relative `href`, or a path without `file://`, resolves against the stylesheet's
location, so give a `file://` URI (on Windows, `file:///C:/data/config.yaml`).

**YAML support.** One document with block mappings and sequences, plain and quoted scalars, flow
collections (`[a, b]`, `{a: 1}`), literal (`|`) and folded (`>`) block scalars, and comments.
Plain scalars resolve as in the YAML 1.2 core schema (null, booleans, integers including `0x` and
`0o`, floats). Anchors, aliases, tags, complex keys, several documents, and scalars or flow
collections over more than one line raise `yx:unsupported`. Wrong indentation raises `yx:syntax`.
Each error message gives the line number.

Run a query file with the CLI:

```bash
xquery -f report.xq
```
