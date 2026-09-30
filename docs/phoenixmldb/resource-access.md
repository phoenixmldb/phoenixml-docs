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

- **Paths are canonicalised.** A `..` that climbs out of a root, or a symbolic link that points
  outside it, is denied.
- **The port is part of the origin.** `https://example.com` doesn't allow `https://example.com:8443`.
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

## Currently refused by the REST server

The REST server refuses stylesheets that use the following with `400`, **even when an allowlist is
configured**:

- `xsl:evaluate`
- calls or function references to `fn:transform`, `fn:json-doc`, `fn:load-xquery-module` and
  `fn:function-lookup`
- shadow attributes (`_name="…"`) on XSL elements
- `http:` and `https:` `xsl:import-schema` locations; use a schema file in an allowed directory

Allowed HTTP documents and imported stylesheets are fetched by the server itself, without
following redirects.

## Next Steps

- [Server Mode](deployment/server-mode.md): authentication and the other server settings
- [Embedded Mode](deployment/embedded-mode.md)
