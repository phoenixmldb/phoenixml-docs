---
title: Resource Access
description: Queries and stylesheets can read only stored documents unless the operator allows local directories or HTTP origins
sort: 8
---

# Resource Access

> **Breaking change** (phoenixml `main`, a2b9963, issue #59): queries and stylesheets supplied by
> callers are **deny-by-default**. They can read the documents stored in the database, and nothing
> else, until the operator allows specific directories or HTTP origins. This applies to the
> embedded engine, the gRPC server (including its REST query endpoint) and the REST server.

PhoenixmlDb can't know what data goes into a database, or what an application built on it is
meant to expose. So nothing outside the stored documents is reachable by default, and each
inclusion is a deliberate, explicit choice by whoever runs the system. In the owner's words:

> We have no idea what kind of data is going into these databases, and we're going to have to rely
> on customers having the foreknowledge that they're building a system to intentionally
> include/remove data for specific purposes.

## What is blocked by default

A caller's XQuery or XSLT cannot read local files or make network requests through:

- `fn:doc()`, `document()`, `fn:collection()` with a URI that isn't a stored document or collection
- `fn:unparsed-text()`, `fn:unparsed-text-lines()`, `fn:unparsed-text-available()`, `fn:json-doc()`
- `xsl:source-document`, `xsl:import`, `xsl:include`
- `import module … at` and `import schema … at` location hints
- `fn:transform` stylesheet locations, and `xsl:evaluate`
- external DTDs and external entities

**Stored documents resolve as before.** `doc()` and `collection()` of stored documents work under
every policy.

In XQuery, `fn:doc()`, `fn:doc-available()` and `fn:collection()` **only ever** resolve stored
documents. An allowlist doesn't make them read files; use `fn:unparsed-text()` or `fn:json-doc()`
for an allowed file. `fn:transform` called from XQuery stays denied under any allowlist and runs
only under the `Unrestricted` policy.

## Allowing directories and origins (servers)

Both servers read the same settings, empty by default:

| Setting | Value |
|---|---|
| `PhoenixmlDb:ResourceAccess:AllowedFileRoots` | Absolute paths of directories that exist. Files under them may be read. |
| `PhoenixmlDb:ResourceAccess:AllowedHttpOrigins` | Origins, `scheme://host[:port]`, with no path, query, fragment or user info. `http` or `https` only. |

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

`ResourceAccessPolicy.Unrestricted` restores the behaviour before this change: queries and
stylesheets can read any file or URL the process can. **Use it only when every query and
stylesheet is your own trusted code**, never for text that comes from users.

## Errors

A denied access raises an error in the query or transformation:

| Access | Error |
|---|---|
| `import module` / `import schema` location | `XQST0059` |
| `fn:unparsed-text()` and related functions | `FOUT1170` |
| `fn:doc()` and related functions | `FODC…` codes |

The REST server answers a denied query or transformation with `400`. The response doesn't include
the denied content or a stack trace.

## Stylesheets on the REST server

Since phoenixml `main` 1eee618, the REST server relies on the 2.5.1 engine to enforce the
resource-access policy inside stylesheets. These are now governed by
`PhoenixmlDb:ResourceAccess`, so they're denied by default and allowed for listed directories
and origins:

- `fn:json-doc` on files. The engine doesn't read `json-doc` over HTTP.
- `fn:load-xquery-module`.
- Shadow attributes (`_href`, `_schema-location`, `_select`, …) with a literal value.
- `xsl:import-schema` over `http`/`https` from an allowed origin, on its exact port.
- `xsl:source-document` and `xsl:stream` with a computed href. The URI is checked when the
  transformation runs.
- `xsl:import` and `xsl:include` of an HTTP module from an allowed origin. Every redirect is
  checked again, and a redirect to an origin that isn't allowed is denied.

Modules imported from allowed directories and origins are trusted, and anything they run is still
subject to the same policy.

**A stylesheet that reads a denied resource can be registered.** It fails with `400` when it
runs, not when it's registered.

### Still refused

The REST server refuses stylesheets that use the following with `400` ("Stylesheet refused by the
resource access policy"), whatever the allowlist says:

- `fn:transform`, called directly or by named function reference, and `fn:function-lookup`
- a shadow attribute whose value is computed (contains `{`)
- `xsl:evaluate`, which is disabled; the engine raises `XTDE3175`
- `xsl:result-document` writes
- DTDs and external entities

### Known limitations

- An attribute value template whose literal text contains `transform(` or `function-lookup(` is
  refused. Build the text instead, for example `{concat('trans','form(')}`.
- In a stylesheet that turns on `expand-text`, text containing a lone `{` or `}` is refused, even
  inside a part where `xsl:expand-text="no"` turns it off again. Emit that text with `xsl:text`
  or `xsl:value-of`.

## Next Steps

- [Server Mode](deployment/server-mode.md): authentication and the other server settings
- [Embedded Mode](deployment/embedded-mode.md)
