---
title: Resource Access
description: Queries and stylesheets can read only stored documents unless the operator allows local directories or HTTP origins
sort: 8
---

# Resource Access

Queries and stylesheets supplied by callers can read the documents stored in the database, and
nothing else, until the operator allows specific directories or HTTP origins. This applies to the
embedded engine, the gRPC server and the REST server.

PhoenixmlDb can't know what data goes into a database, or what an application built on it is
meant to expose. So nothing outside the stored documents is reachable by default, and each
inclusion is a deliberate, explicit choice by whoever runs the system. In the owner's words:

> We have no idea what kind of data is going into these databases, and we're going to have to rely
> on customers having the foreknowledge that they're building a system to intentionally
> include/remove data for specific purposes.

The rules on this page hold under any policy made with `ResourceAccessPolicy.Create` and in both
servers. `ResourceAccessPolicy.Unrestricted` (embedded only) leaves resolution to the libraries,
except where noted.

## Allowing directories and origins (servers)

Both servers read the same settings, empty by default:

| Setting | Value |
|---|---|
| `PhoenixmlDb:ResourceAccess:AllowedFileRoots` | Absolute paths of directories that exist. Files under them, at any depth, may be read. Nothing is writable. |
| `PhoenixmlDb:ResourceAccess:AllowedHttpOrigins` | Origins, `scheme://host[:port]`, with no path, query, fragment or user info. `http` or `https` only. |

The same section holds six size and count limits (`MaxModuleDepth`, `MaxModules`,
`MaxModuleBytes`, `MaxTotalModuleBytes`, `MaxTextResourceBytes`, `MaxTotalTextResourceBytes`);
see [XQuery Library Modules: Settings](xquery-modules.md#settings) for their defaults and ranges.

As environment variables, index each entry:

```bash
export PhoenixmlDb__ResourceAccess__AllowedFileRoots__0=/srv/phoenixml/shared
export PhoenixmlDb__ResourceAccess__AllowedHttpOrigins__0=https://schemas.example.com
```

```json
{
  "PhoenixmlDb": {
    "ResourceAccess": {
      "AllowedFileRoots": [ "/srv/phoenixml/shared" ],
      "AllowedHttpOrigins": [ "https://schemas.example.com" ]
    }
  }
}
```

- **Paths are canonicalised and match whole segments.** `/data/a` doesn't admit `/data/ab`. A
  `..` that climbs out of a root, or a symbolic link that points outside it, is denied. Roots
  containing spaces or non-ASCII characters work.
- **The port is part of the origin.** An origin without a port means the scheme's default port
  (443 for `https`, 80 for `http`) only, so `https://example.com` doesn't allow
  `https://example.com:8443`.
- **HTTP fetches don't follow redirects.** A redirect is a failed read, never a request to the
  redirect target.
- **Invalid values stop the server from starting**, with a message naming the setting (for example
  `PhoenixmlDb:ResourceAccess:AllowedFileRoots:0`).
- **The effective allowlist is logged at startup.**
- **The allowlist is configuration only.** It can't be changed at runtime or through an API.
- `PhoenixmlDb:ResourceAccess:AllowStylesheetFileAccess` is not a setting. A configuration that
  carries it, with any value, fails validation at startup.

## Embedded applications

`DocumentDatabase.ResourceAccessPolicy` (namespace `PhoenixmlDb.Storage.Security`) defaults to
`ResourceAccessPolicy.DenyAll`. To opt in:

```csharp
using PhoenixmlDb.Storage.Security;

var options = new ResourceAccessOptions();
options.AllowedFileRoots.Add("/srv/phoenixml/shared");
options.AllowedHttpOrigins.Add("https://schemas.example.com");

db.ResourceAccessPolicy = ResourceAccessPolicy.Create(options);
```

`Create` throws `ArgumentException` listing every invalid setting; `options.Validate()` returns the same messages without throwing. Empty options give `DenyAll`.

Under `ResourceAccessPolicy.Unrestricted`, queries and stylesheets can read any file or URL the
process can. **Use it only when every query and stylesheet is your own trusted code**, never for
text that comes from users.

## What a query may read

| Construct | Reads |
|---|---|
| `fn:doc`, `fn:doc-available`, `fn:collection`, `fn:uri-collection` | **Stored documents only**, under every policy including `Unrestricted`. `fn:doc` with a file path or URL that names no stored document is `FODC0002`; `doc-available` answers `false`. |
| `import module … at`, `fn:load-xquery-module` | Files inside `AllowedFileRoots`; URLs on `AllowedHttpOrigins`. See [XQuery Library Modules](xquery-modules.md). |
| `import schema … at`, and the documents a schema document names | Files inside `AllowedFileRoots`; URLs on `AllowedHttpOrigins`. |
| `fn:unparsed-text`, `fn:unparsed-text-lines`, `fn:unparsed-text-available`, `fn:json-doc` | Files inside `AllowedFileRoots`. An http(s) reference is `FOUT1170` (`false` from the availability function). |
| External entities and DTDs in `fn:parse-xml` input | Files inside `AllowedFileRoots`; URLs on `AllowedHttpOrigins`. |
| `fn:transform` | Not available: `FOXT0004`. See [fn:transform](#fn-transform). |

A module is held to the same rules as the query that brings it in.

Text functions:

- A file larger than `MaxTextResourceBytes` is not read:
  `FOUT1170 … it is larger than N bytes (PhoenixmlDb:ResourceAccess:MaxTextResourceBytes)`.
  `unparsed-text-available` answers `false`.
- Past `MaxTotalTextResourceBytes`: `FOUT1170` naming that setting.
- A missing file is `FOUT1170`.
- With a requested encoding, an encoding that cannot be used, octets it cannot decode, and
  characters XML does not allow are `FOUT1190`. With no requested encoding: `FOUT1200`.

`fn:parse-xml`:

- Input with a document type declaration that does not parse is `FODC0006`.
- Input that reads an external entity and nests elements more than 512 deep is `FODC0006`.

## What a stylesheet may read (REST server)

This applies to `POST /api/transform`, `/api/transform/raw` and `/api/transform/pipeline`, and to
stylesheet registration, update and validation; to inline and registered stylesheets, and to every
module they import or include.

A stylesheet reads what a query may: files inside `AllowedFileRoots` and URLs on
`AllowedHttpOrigins`. The server reads each location and counts it against the
[limits](xquery-modules.md#settings).

| Construct | Available |
|---|---|
| `xsl:import`, `xsl:include` | Yes; file or http(s). Modules count against `MaxModules`, `MaxModuleBytes`, `MaxTotalModuleBytes`; `MaxModuleDepth` does not apply. |
| `doc()`, `document()`, `doc-available()` | Yes; file or http(s). |
| `unparsed-text()`, `unparsed-text-lines()`, `unparsed-text-available()` | Yes. |
| `json-doc()` | Yes; file or http(s). |
| `xsl:source-document`, streamed or not | Yes; file or http(s). |
| `xsl:merge` sources | Yes (without `streamable`). |

- One read per location per transformation, however often the stylesheet asks.
- Redirects are not followed.
- `MaxTextResourceBytes` and `MaxTotalTextResourceBytes` bound documents and text, over http(s) too.
- A module the stylesheet imports or includes is checked exactly like the stylesheet.
- A registered stylesheet is checked again at every transformation, with its modules as they are then.
- A stylesheet that reads a location outside the allowlist at run time registers, and is refused
  when it runs.
- `xsi:schemaLocation` and `xsi:noNamespaceSchemaLocation` in a document a stylesheet validates are
  not read.

### Not available in stylesheets

These are refused before the stylesheet runs, with HTTP `400` and the detail
`Stylesheet refused by the resource access policy (PhoenixmlDb:ResourceAccess): <reason>.`

| Construct | Reason text |
|---|---|
| `fn:transform` (call or named function reference) | `fn:transform is disabled for stylesheets: EPS does not run nested transformations` |
| `fn:function-lookup` | `fn:function-lookup is disabled for stylesheets: functions are available by name only` |
| `fn:load-xquery-module`, `fn:stream-available`, `fn:collection`, `fn:uri-collection` | `fn:<name> is not available in stylesheets here` |
| `fn:environment-variable`, `fn:available-environment-variables` in a static expression (`use-when`, a static `xsl:param` or `xsl:variable`, and their shadow forms) | `fn:<name> is not available in a static expression of a stylesheet here (use-when, a static parameter or a static variable): the server's environment is not available to stylesheets` |
| `xsl:import-schema` with `schema-location`, with no inline schema, or whose inline schema has a `schemaLocation` | `xsl:import-schema with a schema location is not available in stylesheets here: write the schema inline in xsl:import-schema` |
| `xsl:use-package` | `xsl:use-package is not available in stylesheets here: packages are not offered; use xsl:import or xsl:include` |
| `xsl:result-document` with `href` | `xsl:result-document with an href is not available in stylesheets here: a transformation has one result, and it is returned to the caller` |
| `xsl:merge-source` with `streamable` other than `no`, `false`, `0` | `xsl:merge-source with streamable is not available in stylesheets here: leave streamable out, and the merge source is read like any other document` |
| `parameter-document` attribute | `the parameter-document attribute of xsl:<element> is not available in stylesheets here` |
| A computed shadow attribute (value contains `{`) on an XSLT element | `the shadow attribute … is computed; its value is built while the stylesheet compiles and cannot be checked` |

Also:

- `xsl:evaluate` is disabled (`XTDE3175`).
- At run time `environment-variable()` answers the empty sequence and
  `available-environment-variables()` an empty list.
- External entities are not read.
- The check reads XSLT attributes whole. A string literal that contains a refused function name
  followed by `(` or `#` is refused too. Build such text in an expression, for example
  `{concat('trans', 'form(')}`.
- Validation (`POST /api/transform/stylesheets/validate`) reports the same text with
  `isValid: false` (HTTP `200`).

### Errors for a stylesheet read

A location that is not supplied (outside the allowlist, missing, unreadable, a link that leads out,
or relative with no base) gets one answer per construct, naming the location as the stylesheet
wrote it:

| Construct | Answer |
|---|---|
| `xsl:import`, `xsl:include` | `XTSE0165: Cannot find stylesheet module '<href>'` |
| `doc`, `document`, `xsl:source-document`, `xsl:merge-source` | `FODC0002: Cannot retrieve the document '<uri>': it is not available under the resource access settings (PhoenixmlDb:ResourceAccess).` |
| `unparsed-text`, `unparsed-text-lines`, `json-doc` | `FOUT1170: Cannot retrieve the resource '<uri>': it is not available under the resource access settings (PhoenixmlDb:ResourceAccess).` |
| `doc-available`, `unparsed-text-available` | `false` |
| Past a size limit | `…Cannot read '<uri>': it is larger than N bytes (PhoenixmlDb:ResourceAccess:MaxTextResourceBytes).` |
| A module that is not well-formed XML | `XTSE0165: Cannot load stylesheet module '<location>': <parser message>` |

### How stylesheet modules read from files are named

Inside a module that was read from a file, `static-base-uri()`, `base-uri()`, `resolve-uri('x')`
and `document-uri(document(''))` give

```
phoenixmldb-file:///root-N/<path under the allowed root>
```

where N is the position of the root in `PhoenixmlDb:ResourceAccess:AllowedFileRoots` (0 for the
first). Example with root 0 = `/srv/xsl`:

| Module named as | `static-base-uri()` |
|---|---|
| `file:///srv/xsl/lib/m.xsl`, `/srv/xsl/lib/m.xsl`, or `lib/m.xsl` under `xml:base="file:///srv/xsl/"` | `phoenixmldb-file:///root-0/lib/m.xsl` |
| included by another module as `inner/m.xsl` | `phoenixmldb-file:///root-0/<that module's directory>/inner/m.xsl` |
| a module on an allowed origin | its own URL |
| the stylesheet sent in the request or registered | empty (it has no base); `document('')` is `FODC0002` |

- Relative references inside a file module (`xsl:import href="../lib.xsl"`, `doc('data.xml')`,
  `unparsed-text('notes/a.txt')`) resolve under the same root and are read by the usual rules.
- A document or text read that way reports the rooted name as its `base-uri()` / `document-uri()`.
  One read by a `file:` URI the stylesheet wrote keeps that URI.
- A reference that climbs out of its root names nothing: `XTSE0165` / `FODC0002` / `FOUT1170`,
  and `false` from the availability functions.
- A stylesheet may write a rooted name itself (`phoenixmldb-file:///root-1/shared/lib.xsl`). It
  names that file under that allowed root.
- `file:/x` (one slash), `file://localhost/x`, UNC paths, and schemes other than `file` and
  http(s) name no module (`XTSE0165`). Write `file:///…` or a relative href.
- Inside a module, `doc('file:/abs/x.xml')` and `unparsed-text('file:/abs/x.txt')` are answered like
  any location that is not available: HTTP `400` with `FODC0002` / `FOUT1170`.

## fn:transform

No nested transformation runs under a policy made with `ResourceAccessPolicy.Create` or under
`DenyAll`, in a query or in a stylesheet:

| Where | Answer |
|---|---|
| A query (embedded, gRPC, REST), any call form | `FOXT0004: fn:transform is disabled by the resource access policy (PhoenixmlDb:ResourceAccess): the nested transformation would run outside it.` |
| A stylesheet on the REST server | HTTP `400` ([Not available in stylesheets](#not-available-in-stylesheets)) |
| A stylesheet run by an embedded application with the policy object of `ResourceAccessPolicy.ToStylesheetResourcePolicy` (direct call, `transform#1`, partial application, a variable, in an imported module) | `FOXT0001: fn:transform is not available: the host's resource policy does not allow it` |
| `function-available('transform')`, also in `use-when` | `false` |
| `function-lookup(xs:QName('fn:transform'), 1)` in a stylesheet | The empty sequence |

The policy objects the database gives the XQuery and XSLT libraries have `AllowTransformFunction`
off. Under `ResourceAccessPolicy.Unrestricted` the database builds no policy object and
`fn:transform` is not restricted.

## Stylesheets in embedded applications

These rules hold for an application that runs a stylesheet with the database's stylesheet policy
(`ResourceAccessPolicy.ToStylesheetResourcePolicy`).

- **`xsl:import-schema` with a `schema-location`.** The schema document, and each document it
  includes or imports, is read once, inside `AllowedFileRoots` / `AllowedHttpOrigins`. A location
  that is not supplied is `XTSE0165: Cannot find stylesheet module '<location>'`. A relative
  location with no base is `XTSE0165 … is relative and the stylesheet has no base URI to resolve it
  against`. The REST server refuses this construct ([Not available in stylesheets](#not-available-in-stylesheets)).
- **Limits.** Schema documents count, with the stylesheet modules, against `MaxModules`,
  `MaxModuleBytes` and `MaxTotalModuleBytes`. `MaxModuleDepth` does not apply to them or to
  stylesheet modules.
- `xsi:schemaLocation` and `xsi:noNamespaceSchemaLocation` in a document a stylesheet validates are
  not read.
- **The stylesheet resolver.** The `ResourceResolver` of `ResourceAccessPolicy.ToStylesheetResourcePolicy`
  answers a stylesheet module that is not supplied (not allowed, not there, not readable, past a
  module limit, or a relative reference with no base) with
  `PhoenixmlDb.XQuery.Functions.XQueryException`: `XTSE0165` in its `ErrorCode` and the engine's
  text as its message. A document that is not supplied is answered the same way with `FODC0002`,
  and text with `FOUT1170`. A module past a module limit is refused each time it is asked for. A
  caller of `XsltTransformer` sees that exception as the error of the load.
- **Implicit timezone.** An application that runs its own `XsltTransformer` with this policy sets
  `ImplicitTimezone` itself, to `DocumentDatabase.ImplicitTimezone`. Without it the library takes
  the zone of the host. See [Dates and Times](dates-and-times.md).

## Relative references with no base

A relative location with no base URI names no location.

| Construct | Answer |
|---|---|
| `import module … at 'shop.xqm'` | `XQST0059: import module location 'shop.xqm' is not allowed by the resource access settings: it cannot be resolved to an absolute location (PhoenixmlDb:ResourceAccess).` |
| `import schema … at`, `fn:load-xquery-module`, `fn:json-doc`, `fn:unparsed-text*`, an external entity in `fn:parse-xml` | the construct's own code, same reason |
| `fn:unparsed-text-available` | `false` |
| `xsl:import` / `xsl:include` in a stylesheet with no `xml:base` | `XTSE0165: Cannot find stylesheet module '<href>'` |

Use an absolute path or URI, `declare base-uri` in a query, or `xml:base` on the stylesheet.
A stylesheet with no `xml:base` can import or include a module by an absolute location.

## Modules read over HTTP

**A transformation or a query that includes a module read from an http(s) location reads no files.**

- "Module" means a stylesheet module (`xsl:import`, `xsl:include`) or an XQuery library module
  (`import module … at`, `fn:load-xquery-module`). A document or text read from http(s) as data is
  not a module. A schema document is not a module.
- "Reads no files" means every file location, whatever names it and in whatever spelling (`file:`
  URI, path, `phoenixmldb-file:///root-N/…`, a relative reference under any base).
- One unit is one transformation (each pipeline step is its own) or one query (all its
  per-document evaluations and everything it loads).
- http(s) locations on allowed origins keep working. Stored documents are not files.
- With no http(s) module, nothing in this section applies.
- `ResourceAccessPolicy.Unrestricted` is not held to this rule.

A stylesheet or query that needs both a library from an http(s) origin and files can fetch the
files over http(s) too, or keep the library as a file.

Each construct keeps its error code. The text ends with the sentence that names the rule:

| Construct | Code | Text |
|---|---|---|
| `xsl:import`, `xsl:include` | `XTSE0165` | `Cannot find stylesheet module '…'. A transformation that includes a module read from an http(s) location reads no files.` |
| `doc`, `document`, `xsl:source-document`, `xsl:merge-source` | `FODC0002` | `Cannot retrieve the document '…': it is not available under the resource access settings (PhoenixmlDb:ResourceAccess). A transformation that includes …` |
| `unparsed-text`, `unparsed-text-lines`, `json-doc` (stylesheets) | `FOUT1170` | `Cannot retrieve the resource '…': … A transformation that includes …` |
| `doc-available`, `unparsed-text-available` | — | `false` |
| `import module … at` | `XQST0059` | `import module location '…' is not read. A query that includes a module read from an http(s) location reads no files.` |
| `import schema … at` | `XQST0059` | `import schema location '…' is not read. A query that includes …` |
| `fn:load-xquery-module` of a file | `FOQM0002` | `Module '…' cannot be loaded: [XQST0059] import module location '…' is not read. A query that includes …` |
| `unparsed-text`, `unparsed-text-lines`, `json-doc` (queries) | `FOUT1170` | `Cannot read '…': not allowed by the resource access policy (PhoenixmlDb:ResourceAccess). A query that includes …` |
| `fn:parse-xml` external entity or DTD naming a file | `FODC0006` | `External entity '…' is not allowed by the resource access policy (PhoenixmlDb:ResourceAccess). A query that includes …` |

Rules for content read from http(s):

- A stylesheet module read from http(s) whose `xsl:import` / `xsl:include` `href` names a file is
  not loaded (`XTSE0165`).
- A stylesheet module read from http(s) declares an http(s) or relative `xml:base` only. Otherwise:
  `XTSE0165: Cannot load stylesheet module '<its URL>': its xml:base '…' is neither an http(s) URI nor relative. A stylesheet module read from an http(s) location declares no other base.`
  An `xml:base` that begins with `/` or `\` on an XSLT element of such a module is refused too.
- A schema document read from http(s) refers to documents at http(s) locations only:
  `XQST0059 import schema location '…', referred to by the schema document at '…', is not read: a schema document read from an http(s) location refers to documents at http(s) locations only.`
  A query that imports a schema from http(s) still reads files.
- Pipelines: the rule is per step. With `ContinueOnError` the step reports the error.
- With `MaxModules = N`, a stylesheet that names more http(s) modules has N + 1 requested.

## Schema imports in queries

- `import schema … at` reads the schema document and every document it names with `xs:include`,
  `xs:import`, `xs:redefine` and `xs:override`. Each is held to the allowlist. A refusal is
  `XQST0059`, naming the location as the schema document wrote it and "referred to by the schema
  document at '…'".
- A relative `schemaLocation` is relative to where the referring document was read from, for files
  and over http(s). Documents that include each other load, each read once.
- `xs:import` with a namespace and no `schemaLocation` loads nothing.
- A schema document with a document type declaration is `XQST0059`.
- A schema document whose elements nest more than **512** deep is `XQST0059`
  ("nests elements more than 512 deep; such a document is not read as a schema").
- Schema documents count toward `MaxModuleDepth`, `MaxModules`, `MaxModuleBytes` and
  `MaxTotalModuleBytes`.
- `xsi:schemaLocation` written in an element given to `validate` loads nothing.
- Binding `xml` or `xmlns`, a prefix with an empty target namespace, and two imports of one
  namespace are refused. `ErrorCode` is `XPST0003`; the message leads with `XQST0070`, `XQST0057`
  or `XQST0058`.
- `import schema` written inside a library module is `XQST0009`.

## Schema locations in the REST server validators

This applies to `POST /api/v1/validate`, `/api/v1/validate/upload`, `/api/v1/validate/xml`,
`/api/v1/validate/svrl`, `/api/v1/validate/batch`, `/api/schemas/validate`,
`/api/schemas/{id}/validate`, `/api/schemas/validate-schema`, schema registration, and write-time
validation.

A schema location is `Schemas[].Uri` in a validate request, the `schemaLocation` of `xs:include`,
`xs:import` and `xs:redefine`, and the `href` of `sch:include`. It is served when it is, in this
order:

1. a **registered schema**: the location is the name it was registered under;
2. a **file in the schema directory**: a relative name inside `PhoenixmlDb:Validation:BasePath`.
   A name that leads out of the directory is not served from it;
3. a **location allowed by `PhoenixmlDb:ResourceAccess`**: an absolute path or `file:` URI inside
   `AllowedFileRoots`, or an http(s) URL whose origin is in `AllowedHttpOrigins`.

The `PhoenixmlDb:Validation` settings are listed in
[Server Configuration: Schema validation](deployment/server-configuration.md#schema-validation).

- An http(s) location needs **both** `PhoenixmlDb:Validation:AllowHttpResolution: true` **and** its
  origin in `PhoenixmlDb:ResourceAccess:AllowedHttpOrigins`.
- Redirects are not followed.
- A location is at most `PhoenixmlDb:ResourceAccess:MaxModuleBytes`; larger is a `400` naming the
  setting.
- A relative `schemaLocation` inside a served file or URL is relative to where that document was
  read from.
- `sch:include href` is a registered name, a schema-directory file, or an absolute allowed
  location. It is not relative to the including file.
- A schema brings in at most 256 locations.
- An XSD read from an http(s) origin names http(s) locations only.

**A location that is not served is HTTP `400`**: `title: "Validation Error"`,
`errorCode: "SCHEMA_LOCATION_NOT_AVAILABLE"`,
`errors: [{ field: "schemaLocation", message, code: "SCHEMA_LOCATION_NOT_AVAILABLE" }]`, and the
detail:

```
Schema location '<as written>' is not available: it is not a registered schema, not a file in the schema directory (PhoenixmlDb:Validation:BasePath), and not a location allowed by PhoenixmlDb:ResourceAccess (an http(s) location also needs PhoenixmlDb:Validation:AllowHttpResolution).
```

The text is the same for every reason.

These are not schema locations. Nothing is read for them, with any settings:

- a DOCTYPE in an XSD schema or in a document validated by XSD or Schematron: not accepted;
- `xsi:schemaLocation` / `xsi:noNamespaceSchemaLocation` in the document: not followed;
- `document()` in a Schematron assertion or rule context: not available;
- `sch:extends href`, RELAX NG `externalRef` / `include`: not implemented.

## Document nesting bounds

| What | Bound | Answer past it |
|---|---|---|
| A schema document (`import schema`; inline, registered or located in the REST validators) | 512 elements deep | `XQST0059` in a query; a `400` in the validators |
| `fn:parse-xml` input that reads an external entity | 512 | `FODC0006` |
| A document validated by XSD, Schematron, RELAX NG or DTD on the REST server, including write-time validation | 1024 | validation error: `The document nests elements more than 1024 deep; <XSD\|Schematron\|RELAX NG\|DTD> validation reads documents at most 1024 deep.` |

Neither bound is a setting.

## What error texts contain

- An error names a location as the caller, or the importing module, wrote it.
- For stylesheets, the text is the same whether the location is outside the allowlist, missing, a
  directory, or a link that leads out.
- For queries, there is one text for every location outside the allowed directories, and another
  (`… was not found …`) for a location inside an allowed directory with no file to read.
- REST transform errors name a file location only when the request wrote it: as an attribute value
  of the stylesheet, a string literal in one of its expressions, or a string parameter. Any other
  file location appears as `the requested location`. Line and column are kept:
  `[the requested location:1:126]`. Relative names and http(s) URLs appear as written.
- The REST server's response doesn't include the denied content or a stack trace.

## Known limits

- Inside a module, an `xml:base` that is a one-slash `file:/` location (`xml:base='file:/one/slash/'`
  on `xsl:import`) or is not a URI (`http://[not-a-host/`, on `xsl:import` or on a literal result
  element) answers HTTP `500`, detail `Invalid URI: …`. The same in the stylesheet of the request
  is a `400`. Write `file:///`.
- The two-argument `unparsed-text-available($uri, $encoding)` answers from whether the resource is
  readable; it does not test the encoding.
- `xsl:use-package` is not offered.
- In a stylesheet that turns on `expand-text`, text containing a lone `{` or `}` is refused, even
  inside a part where `xsl:expand-text="no"` turns it off again. Emit that text with `xsl:text`
  or `xsl:value-of`.
- Validators: `sch:extends href` and RELAX NG `externalRef` / `include` are not implemented.

## Next Steps

- [XQuery Library Modules](xquery-modules.md): module settings, resolution and errors
- [Server Mode](deployment/server-mode.md): authentication and the other server settings
- [Embedded Mode](deployment/embedded-mode.md)
