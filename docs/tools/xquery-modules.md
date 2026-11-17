---
title: XQuery modules
description: XQuery 3.1 library modules for everyday work with JSON and XML
sort: 5
---

# XQuery modules

Two XQuery 3.1 library modules make common JSON and XML tasks short: load files, select values,
group, count, and convert to CSV, JSON or XML. They are plain XQuery source, so they run on the
[`xquery` CLI](xquery-cli.md), the PhoenixmlDb XQuery engine and other XQuery 3.1 processors.

| Module | Namespace | Source |
|---|---|---|
| JSON (`pj`) | `https://phoenixml.dev/modules/json` | [`json.xqm`](https://phoenixml.dev/modules/1.0.0/json.xqm) |
| XML (`px`) | `https://phoenixml.dev/modules/xml` | [`xml.xqm`](https://phoenixml.dev/modules/1.0.0/xml.xqm) |

The source, tests and releases are in the
[xquery-modules repository](https://github.com/phoenixmldb/xquery-modules). The license is
Apache 2.0.

## Import a module

The `at` URL in the import tells the processor where to read the module. The processor reads the
file when it compiles the query; nothing is installed.

```xquery
import module namespace pj = "https://phoenixml.dev/modules/json"
  at "https://phoenixml.dev/modules/1.0.0/json.xqm";

pj:select(pj:load("orders.json", static-base-uri()), "items.*.name")
```

The namespace is the module's name only; the processor does not read anything from it.

**Use a version in the URL**, such as `1.0.0`. The file at a version URL does not change; a new
release gets a new version URL. The same files are in the GitHub repository, at
`https://raw.githubusercontent.com/phoenixmldb/xquery-modules/v1.0.0/modules/json.xqm`.

**Or use a local copy.** Download the `.xqm` file, put it next to your query, and import it by its
path. A local copy does not need the network, and you control which code your queries run:

```xquery
import module namespace pj = "https://phoenixml.dev/modules/json" at "json.xqm";
```

**Resource policy.** A host that runs queries under a `ResourcePolicy` must allow the module URL
for import, and the data files for reading. The import rules, settings and limits are in
[XQuery library modules](/phoenixmldb/xquery-modules.md).

## Relative paths

A relative path in a library module resolves against the module's own location, not against your
query. For a module read from GitHub, `"orders.json"` would point to GitHub. The `load` functions
therefore take your query's base URI as a second argument:

```xquery
pj:load(("a.json", "b.json"), static-base-uri())
```

With one argument, `load` takes absolute URIs only, and a relative path raises the error
`pj:relative-uri` (or `px:relative-uri`).

## JSON functions

| Function | Result |
|---|---|
| `pj:load($uris)` | Each JSON file, parsed. The URIs must be absolute. |
| `pj:load($paths, $base)` | Each JSON file, parsed. Paths resolve against `$base`. |
| `pj:select($json, $path)` | Values at a dotted path. A step is a key, `*` (all members or values), or an array position from 1: `"items.*.name"`, `"items.2.price"`. |
| `pj:records($json)` | All array members, with nested arrays flattened. |
| `pj:group-by($records, $key)` | A map from each value of field `$key` to an array of its records. |
| `pj:to-csv($records, $fields)` | CSV text with a header row. Values with a comma, quote or line break are quoted; maps and arrays are written as JSON. |
| `pj:to-xml($json)` | The W3C XML representation of the JSON (`fn:json-to-xml`). |

Items with a price over 3, from two files, as CSV:

```xquery
import module namespace pj = "https://phoenixml.dev/modules/json"
  at "https://phoenixml.dev/modules/1.0.0/json.xqm";

let $items := pj:records(pj:load(("a.json", "b.json"), static-base-uri())?items)
return pj:to-csv($items[?price > 3], ("name", "price"))
```

## XML functions

| Function | Result |
|---|---|
| `px:load($uris)` | Each XML document. The URIs must be absolute. |
| `px:load($paths, $base)` | Each XML document. Paths resolve against `$base`. |
| `px:to-json($element)` | A value ready for JSON output: `"@name"` for attributes, the local name for child elements (an array when a name repeats), `"#text"` for text. An element with no attributes and no children gives its string value. |
| `px:to-csv($elements, $fields)` | CSV text with a header row. A field is a child element name or `@attribute`. |
| `px:strip-namespaces($node)` | A copy with local names only. |
| `px:path($node)` | A readable path, for example `/catalog[1]/product[2]/@id`. |
| `px:count-by($items, $key)` | A map from each key to its count. `$key` is a function. |

Products by category, then the catalog as JSON:

```xquery
import module namespace px = "https://phoenixml.dev/modules/xml"
  at "https://phoenixml.dev/modules/1.0.0/xml.xqm";

let $doc := px:load("catalog.xml", static-base-uri())
return (
  px:count-by($doc//product, function($p) { string($p/@category) }),
  serialize(px:to-json($doc/catalog), map { "method": "json" })
)
```

Run a query file with the CLI:

```bash
xquery -f report.xq
```
