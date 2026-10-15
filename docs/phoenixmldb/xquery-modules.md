---
title: XQuery Library Modules
description: Importing XQuery library modules from files and http(s) URLs, the module settings and limits, resolution rules, fn:load-xquery-module, and the errors each host reports
sort: 8
---

# XQuery Library Modules

A library module is an XQuery file that begins `module namespace p = "uri";`. It is a file on disk
or a document at an http(s) URL. A query brings it in with

```xquery
import module namespace p = "uri" at "location";
```

or with `fn:load-xquery-module("uri", map { "location-hints": "location" })`.

Library modules work in the embedded engine, the gRPC server and the REST server. For the
language itself, see [Functions and Modules](../language-reference/xquery/functions-modules.md).

## Enabling modules

Nothing outside the stored documents is readable by default. An operator lists the directories
and http(s) origins that modules may be read from. The same lists govern every other read; see
[Resource Access](resource-access.md).

### Embedded engine

```csharp
using PhoenixmlDb.Storage;
using PhoenixmlDb.Storage.Security;

var options = new ResourceAccessOptions();
options.AllowedFileRoots.Add("/srv/xquery-modules");            // absolute path of an existing directory
options.AllowedHttpOrigins.Add("https://modules.example.com");  // scheme://host[:port], no path

using var db = new DocumentDatabase("/var/lib/mydb");
db.ResourceAccessPolicy = ResourceAccessPolicy.Create(options);
```

- The default is `ResourceAccessPolicy.DenyAll`.
- `ResourceAccessPolicy.Create` throws `ArgumentException` listing each bad value.
  `ResourceAccessOptions.Validate()` returns the same list.
- Under `ResourceAccessPolicy.Unrestricted`, the XQuery library resolves and reads locations
  itself, and the limits and error texts on this page do not apply.

### Servers

The gRPC server (`PhoenixmlDb.Server`) and the REST server bind the same section,
`PhoenixmlDb:ResourceAccess`:

```json
{
  "PhoenixmlDb": {
    "ResourceAccess": {
      "AllowedFileRoots": [ "/srv/xquery-modules" ],
      "AllowedHttpOrigins": [ "https://modules.example.com" ]
    }
  }
}
```

For the gRPC server, as environment variables:

```bash
PhoenixmlDb__ResourceAccess__AllowedFileRoots__0=/srv/xquery-modules
PhoenixmlDb__ResourceAccess__AllowedHttpOrigins__0=https://modules.example.com
```

A bad value stops startup with a message that names the key, for example:

```
PhoenixmlDb:ResourceAccess:MaxModules must be between 1 and 1024 (was 0).
```

The gRPC server logs the policy at startup:

```
file roots: …; HTTP origins: …; module limits: depth 32, 256 modules, 4194304 bytes each, 33554432 bytes in total; text resources: 67108864 bytes each, 268435456 bytes in total
```

## Settings

All settings are under `PhoenixmlDb:ResourceAccess`. Each is also a property of the same name on
`ResourceAccessOptions`.

| Setting | Default | Meaning |
|---|---|---|
| `AllowedFileRoots` | empty | Absolute paths of existing directories. A query or stylesheet may read their files, at any depth. Nothing is writable. |
| `AllowedHttpOrigins` | empty | Origins a query or stylesheet may fetch from: `http` or `https`, `scheme://host[:port]`, with no path, query, fragment or user info. Scheme, host and port must all match. |
| `MaxModuleDepth` | `32` | How many imports or loads deep a module may be, counted from the query (a module the query imports is 1). Also bounds chains of schema documents a query imports. Not applied to a transformation: stylesheet modules and the schema documents of `xsl:import-schema` are not counted by depth. |
| `MaxModules` | `256` | 1–1024. How many distinct module files and schema documents one query or transformation brings in. |
| `MaxModuleBytes` | `4194304` (4 MiB) | 1–268435456. Largest module file, schema document, or external entity fetched over http(s). |
| `MaxTotalModuleBytes` | `33554432` (32 MiB) | `MaxModuleBytes`–4294967296. Module and schema text one query or transformation brings in altogether. |
| `MaxTextResourceBytes` | `67108864` (64 MiB) | 1–1073741824. Largest file read by `fn:unparsed-text`, `fn:unparsed-text-lines`, `fn:unparsed-text-available` and `fn:json-doc`. For a transformation, also the largest document read. |
| `MaxTotalTextResourceBytes` | `268435456` (256 MiB) | `MaxTextResourceBytes`–68719476736. Text one query or transformation reads altogether. Each distinct file counts once. |

Bounds that are not settings:

- An import chain longer than **64 modules** is `XQST0059`, whatever `MaxModuleDepth` is. It
  applies to the longest chain in the import graph.
- One http(s) fetch may take 30 seconds, headers and body together.
- Redirects are not followed.

`PhoenixmlDb:ResourceAccess:AllowStylesheetFileAccess` is not a setting. A configuration that
carries the key, with any value, fails validation at startup:

```
PhoenixmlDb:ResourceAccess:AllowStylesheetFileAccess is not a setting: what a stylesheet may read follows PhoenixmlDb:ResourceAccess:AllowedFileRoots and PhoenixmlDb:ResourceAccess:AllowedHttpOrigins. Remove it.
```

## Worked example

Five documents in the container, `b1.xml` … `b5.xml`:

```xml
<book isbn="isbn-1"><title>t1</title><price>10</price></book>
<book isbn="isbn-2"><title>t2</title><price>20</price></book>
…
<book isbn="isbn-5"><title>t5</title><price>50</price></book>
```

Module file `/srv/xquery-modules/shop.xqm`, with `/srv/xquery-modules` in `AllowedFileRoots`:

```xquery
module namespace shop = "urn:example:shop";

declare variable $shop:vat as xs:decimal := 0.2;
declare variable $shop:factor as xs:decimal := 1 + $shop:vat;
declare %private variable $shop:currency := "EUR";

declare %private function shop:format($amount as xs:decimal) as xs:string {
  $shop:currency || " " || string($amount)
};

declare function shop:gross($book as element(book)) as xs:string {
  shop:format(xs:decimal($book/price) * $shop:factor)
};

declare function shop:titles() as xs:string* {
  collection()/book/title/string()
};

declare function shop:cheaper-than($limit as xs:decimal) as element(book)* {
  collection()/book[xs:decimal(price) lt $limit]
};

declare function shop:by-isbn($isbn as xs:string) as element(book)* {
  collection()/book[@isbn = $isbn]
};

declare function shop:label($book as element(book)) as xs:string {
  "book " || $book/title
};
```

Query:

```xquery
import module namespace shop = "urn:example:shop" at "/srv/xquery-modules/shop.xqm";
shop:gross(/book)
```

Result: `EUR 12`, `EUR 24`, `EUR 36`, `EUR 48`, `EUR 60`.

More queries with the same import:

| Query | Result |
|---|---|
| `shop:titles()` | `t1`, `t2`, `t3`, `t4`, `t5` |
| `count(shop:titles())` | `5` |
| `shop:cheaper-than(25)/title/string()` | `t1`, `t2` |
| `for $b in /book where xs:decimal($b/price) gt 30 return shop:label($b)` | `book t4`, `book t5` |
| `$shop:currency` | error `XPST0008` |
| `shop:format(1.0)` | error `XPST0017` |

The same module through `fn:load-xquery-module`:

```xquery
load-xquery-module("urn:example:shop", map { "location-hints": "/srv/xquery-modules/shop.xqm" })
  ?functions(QName("urn:example:shop", "gross"))(1)(/book)
```

Result: `EUR 12`, `EUR 24`, `EUR 36`, `EUR 48`, `EUR 60`.

## How a module function reaches the stored documents

- A function body has no context item. Pass the node in (`shop:gross(/book)`) or read
  `collection()`. A function that uses `/` with no argument is `XPDY0002`.
- A query whose answer depends on one document at a time runs once per document.
- A query that reaches `collection()`, in its own text or inside an imported module function it
  calls, runs once over the whole container, except a query whose every answer depends on one
  document at a time (`collection()/book[price > 15]/title`), which runs once per document. See
  [Once per document or once over the container](documents-and-storage.md#once-per-document-or-once-over-the-container).
- A module that is only loaded at run time with `fn:load-xquery-module` is not looked into when the
  engine decides how to run the query. `count(collection())` inside a loaded function answers once
  per document. Read the collection in the query text to get one answer.

## Resolution rules

| Where the location is written | It means |
|---|---|
| In the query, absolute path or `file:` URI | that file |
| In the query, `http(s)://` URL | that URL |
| In the query, relative, with `declare base-uri` | relative to that base |
| In the query, relative, with no base | no location (see [Relative references with no base](resource-access.md#relative-references-with-no-base)) |
| In a module on disk, relative | relative to the directory of that module's file |
| In a module fetched over http(s), relative | relative to that module's URL |
| In a module, absolute | that file or URL |

- Every location is checked against the allowlist, at every depth.
- `at "a.xqm", "b.xqm"` loads both as one module. Every listed location must exist, hold a library
  module, and declare the imported namespace.
- Two modules that import each other compile and call each other.
- A location is allowed when the file it resolves to is inside an allowed directory. A symbolic
  link inside an allowed directory that leads out of it is refused.
- Only regular files are read.
- A module is read once per query, however many documents the query runs over. Nothing is kept
  between queries: the next query reads and compiles the module again.
- If the query and a module write the same relative hint and the two resolve to different files,
  the query is refused (`XQST0059 … name different files`).
- `import schema` written inside a library module is `XQST0009`. Import the schema in the query.
- Cancelling the query stops the reading of modules.
- A query that includes a module read from an http(s) location reads no files; see
  [Modules read over HTTP](resource-access.md#modules-read-over-http).

## `fn:load-xquery-module`

- `location-hints` is required. Without it: `FOQM0002` ("no location-hints were given, and modules
  are loaded from location hints only").
- The result is `map { "functions": map(QName → map(arity → function)), "variables": map(QName → value) }`
  with the public declarations only.
- The `variables` option (a map with `xs:QName` keys) binds the module's external variables.
  `context-item` supplies its context item.
- Several hints load one module.
- The [limits](#settings) are the query's. A loaded module continues from the depth of the code
  that loads it and counts in the same totals.
- The same load made again by the query itself in one evaluation (same module URI and locations,
  no `variables`, no `context-item`) returns the module already loaded. Every other load is a new
  module. One evaluation loads at most `MaxModules`.
- A loaded module runs under the database's query limits, including the regular-expression match
  time limit.

| Code | When |
|---|---|
| `FOQM0001` | empty module URI |
| `FOQM0002` | no `location-hints`; the location is not allowed, not found, or not a library module for that namespace; a limit is passed |
| `FOQM0003` | the module has a static error (the module's own code is in the message) |
| `FOQM0006` | `xquery-version` above 4.0 |
| `XPTY0004` | a malformed option |
| `XPDY0002` | an external variable was not supplied; the module needs a context item and none was given |

## Errors

How each host reports a query error:

| Host | Answer |
|---|---|
| Embedded | exception with `ErrorCode` and `Message` (`PhoenixmlDb.XQuery.Functions.XQueryException` and the library's parse and run-time exceptions) |
| REST server | HTTP 400, problem body with `xqueryErrorCode` and `detail` |
| gRPC, unary calls | `success = false`, `error` text that begins with the code (`XQST0059: …`) |
| gRPC, streaming query | status `InvalidArgument`, the same text as the status detail |

| Situation | `import module` | `fn:load-xquery-module` | Message says |
|---|---|---|---|
| Location outside the allowed directories | `XQST0059` | `FOQM0002` | the location as written; "is not allowed by the resource access settings: it is not inside a directory listed in PhoenixmlDb:ResourceAccess:AllowedFileRoots." |
| Origin not allowed | `XQST0059` | `FOQM0002` | the URL; "its origin is not listed in PhoenixmlDb:ResourceAccess:AllowedHttpOrigins." |
| Another scheme (`ftp:` …) | `XQST0059` | `FOQM0002` | "only file and http(s) locations can be allowed" |
| Relative location with no base | `XQST0059` | `FOQM0002` | "it cannot be resolved to an absolute location (PhoenixmlDb:ResourceAccess)." |
| A module's own import is refused | `XQST0059` | `FOQM0002` | the location as the module wrote it, "imported by the module at '…'", and the setting |
| File missing inside an allowed directory | `XQST0059` | `FOQM0002` | "was not found: there is no file to read at that location." |
| http(s) module missing | `XQST0059` | `FOQM0002` | "could not be read: GET … returned HTTP 404" |
| Redirect | `XQST0059` | `FOQM0002` | "returned HTTP 302 (redirects are not followed)" |
| Fetch past 30 s | `XQST0059` | `FOQM0002` | "did not complete within 30 s" |
| Deeper than `MaxModuleDepth` | `XQST0059` | `FOQM0002` | "is more than N imports deep, counted from the query (PhoenixmlDb:ResourceAccess:MaxModuleDepth)" |
| More than `MaxModules`, larger than `MaxModuleBytes`, past `MaxTotalModuleBytes` | `XQST0059` | `FOQM0002` | the location and the setting |
| Chain longer than 64 modules | `XQST0059` | `FOQM0002` | "is imported through a chain of more than 64 modules" |
| Syntax error in a module | `XPST0003` | `FOQM0003` | "The module at '…' has a syntax error: line L, column C: …" |
| File declares another namespace | `XQST0059` | `FOQM0002` | "holds a module for namespace 'A', not for the imported namespace 'B'." |
| File is not a library module | `XQST0059` | `FOQM0002` | "is not a library module: it does not begin with a 'module namespace' declaration." |
| `import schema` in a library module | `XQST0009` | `FOQM0003` | "…not supported in a library module here: import the schema in the query that imports the module." |
| Function the module does not declare | `XPST0017` | — | "Unknown function: name#arity" |
| Private function or variable used by the query | `XPST0017` / `XPST0008` | not in the result map | |
| Static error inside a module | its own code | `FOQM0003` | the analyzer's message |

On the REST server, the compile-only endpoints read the imported modules too:
`POST /api/query/validate` reports each static error with its own code, and
`POST /api/query/compile` answers `400` with `xqueryErrorCode`.

## Known limits

- Modules are not stored in the database. A module is a file or a URL.
- There is no compiled-module cache. Every query reads and compiles its modules again, and
  fetches an http(s) module again.
- A predicate inside a module function is not answered from a value index.
  `/book[@isbn = 'isbn-7'] ! shop:label(.)` uses the index; `shop:by-isbn('isbn-7')` returns the
  right book from a scan.
- A module loaded only at run time does not change how the query is run (see
  [How a module function reaches the stored documents](#how-a-module-function-reaches-the-stored-documents)).
- `fn:unparsed-text` and `fn:json-doc` in queries read files only, not http(s).
- XSLT cannot import XQuery modules.

## Next Steps

- [Resource Access](resource-access.md): everything else a query or stylesheet may read
- [Server Configuration](deployment/server-configuration.md)
