---
title: Resource Policy
---

# Resource Policy

Control what external resources XSLT and XQuery code can access. Essential for running transformations in server environments where untrusted stylesheets or queries must be sandboxed.

> **Upgrade to 2.5.1.** Before PhoenixmlDb.XQuery 2.5.0 and PhoenixmlDb.Xslt 2.5.1, a policy was
> enforced only when loading documents, so `unparsed-text`, `json-doc`, imports,
> `xsl:source-document`, `fn:transform` and HTTP redirects could reach what it forbade
> ([GHSA-wjxc-7p24-xf7w](https://github.com/phoenixmldb/phoenixmldb-xquery/security/advisories/GHSA-wjxc-7p24-xf7w),
> [GHSA-86rg-wxgp-9p5j](https://github.com/phoenixmldb/phoenixmldb-xslt/security/advisories/GHSA-86rg-wxgp-9p5j)).
> This page describes 2.5.1.

## Quick Start

```csharp
// Lock down for server use — no filesystem, no network
var transformer = new XsltTransformer();
transformer.ResourcePolicy = ResourcePolicy.ServerDefault;
await transformer.LoadStylesheetAsync(stylesheet);
var result = await transformer.TransformAsync(inputXml);
// doc('file:///etc/passwd') → ResourceAccessDeniedException
```

## Choosing a policy

`ResourcePolicy` is optional on `XsltTransformer`, `XsltTransformOptions`, `XQueryFacade` and
`QueryEngine`. Leaving it unset is a deliberate choice, not an oversight:

| Who runs the code | Use |
|---|---|
| You wrote it: command-line tools, build pipelines, doc generators, test suites | **no policy** (`null`) |
| Someone else wrote it: a server running users' queries or stylesheets | `ServerDefault`, or a builder allowlist |
| Everything is served by your own `IResourceResolver` | `InMemoryOnly` |

**No policy means no restrictions**: queries and stylesheets can read any file or URL the process
can, and behave exactly as before 2.5. `ResourcePolicy.Unrestricted` is **not** the same as no
policy:

- **DTDs:** `Unrestricted` doesn't resolve external DTD subsets or external entities, in
  `fn:parse-xml` or in a stylesheet's DOCTYPE. The internal subset still works. With no policy,
  they resolve.
- **HTTP:** under any policy, `Unrestricted` included, a redirect is re-checked against the policy
  at every hop, and remote XQuery modules are fetched fresh on each compilation instead of from
  the process-wide cache. With no policy, both behave as before.

## Presets

### ResourcePolicy.ServerDefault

Denies all external access by default: no file system, no network, no DTDs, no `xsl:evaluate`. Only documents pre-loaded by the application or served by a custom resolver are accessible. Limits: 100 document loads, 10 result documents, 10 MB output, 50 `unparsed-text` loads.

### ResourcePolicy.InMemoryOnly

No external access at all. Only in-memory documents provided via a custom `IResourceResolver`.

### ResourcePolicy.Unrestricted

All schemes allowed for reading, importing and writing, and `xsl:evaluate` on. External DTDs and entities are off, and redirects are re-checked, so it is **not** the same as no policy (see [Choosing a policy](#choosing-a-policy)).

## Builder API

```csharp
// Allow HTTPS reads from a specific domain
transformer.ResourcePolicy = ResourcePolicy.CreateBuilder()
    .AllowReadFrom("https", host: "api.example.com")
    .AllowReadFrom("https", host: "cdn.example.com", pathPrefix: "/schemas/")
    .WithMaxDocumentLoads(100)
    .Build();

// Separate read and write policies
transformer.ResourcePolicy = ResourcePolicy.CreateBuilder()
    .AllowReadFrom("https")
    .AllowWriteTo("s3")
    .WithMaxResultDocuments(10)
    .Build();

// Allow imports from specific paths
transformer.ResourcePolicy = ResourcePolicy.CreateBuilder()
    .AllowImportFrom("file", pathPrefix: "/app/stylesheets/")
    .AllowReadFrom("https")
    .Build();

// A non-default port must be named (UriRule.AnyPort allows any)
transformer.ResourcePolicy = ResourcePolicy.CreateBuilder()
    .AllowReadFrom("https", "api.example.com", "/v1/", port: 8443)
    .Build();

// DTD processing and xsl:evaluate are off in a built policy until enabled
transformer.ResourcePolicy = ResourcePolicy.CreateBuilder()
    .AllowReadFrom("file", pathPrefix: "/data/")
    .AllowDtdProcessing()
    .AllowXslEvaluate()
    .Build();
```

### How rules match

- **Access kinds are separate.** A read rule admits reads only; importing a module or stylesheet
  needs an import rule (`AllowImportFrom`), and writing a write rule. A scheme allowed with
  `AllowScheme` (or `"*"`) admits every kind.
- **An empty rule list denies.**
- **Ports:** a host rule admits only the scheme's default port unless it names one.
- **Paths** match whole segments (`/app/data` doesn't admit `/app/database`), case-sensitively
  where the file system is, against the canonical path with symbolic links resolved.
- A rooted path such as `/etc/x` is a `file:` URI, not a relative reference.
- `ResourcePolicy.Authorize(uri, access)` (or `TryAuthorize`) applies the same check from your own
  code and returns the URI to open.

### Upgrading rules built before 2.5

Two mistakes deny access that a pre-2.5 rule allowed. Both fail closed:

- **Name the port for an origin on a non-default port.** A rule for `https://api.example.com:8443`
  built without a port admits only port 443:

  ```csharp
  var origin = new Uri("https://api.example.com:8443");
  builder.AllowReadFrom(origin.Scheme, origin.Host, pathPrefix: null, port: origin.Port);
  ```

  Pass `UriRule.AnyPort` only if any port really is acceptable.
- **Build file prefixes from a local path, not from `Uri.AbsolutePath`.** File rules are compared
  with the canonical local path. `AbsolutePath` is percent-escaped, so a root containing a space
  or a non-ASCII character (`/srv/my%20data/`) never matches. Use `Uri.LocalPath` or
  `Path.GetFullPath(...)`:

  ```csharp
  builder.AllowReadFrom("file", pathPrefix: Path.GetFullPath("/srv/my data/"));
  ```

## Custom Resource Resolver

The `IResourceResolver` interface lets you plug in any storage backend. XSLT/XQuery code uses standard functions (`doc()`, `unparsed-text()`, `collection()`) and your resolver handles the URI.

```csharp
public class S3ResourceResolver : ResourceResolverBase
{
    private readonly IAmazonS3 _s3;
    private readonly string _bucket;

    public S3ResourceResolver(IAmazonS3 s3, string bucket)
    {
        _s3 = s3;
        _bucket = bucket;
    }

    public override XdmDocument? ResolveDocument(string uri, ResourceAccessKind access)
    {
        if (!uri.StartsWith("s3://")) return null;
        var key = uri.Replace("s3://", "").TrimStart('/');
        var response = _s3.GetObjectAsync(_bucket, key).Result;
        using var reader = new StreamReader(response.ResponseStream);
        var xml = reader.ReadToEnd();
        var store = new XdmDocumentStore();
        return store.LoadFromString(xml, uri);
    }
}

// Wire it up
transformer.ResourcePolicy = ResourcePolicy.CreateBuilder()
    .WithResourceResolver(new S3ResourceResolver(s3Client, "my-bucket"))
    .AllowReadFrom("s3")
    .Build();
```

Now XSLT code can do:

```xml
<xsl:variable name="config" select="doc('s3://my-bucket/config.xml')"/>
```

### IResourceResolver Methods

| Method | Purpose |
|--------|---------|
| `ResolveDocument(uri, access)` | Load XML documents (`doc()`, `document()`) |
| `ResolveText(uri, encoding)` | Load text files (`unparsed-text()`) |
| `ResolveCollection(uri)` | Load document collections (`collection()`) |
| `OpenResultDocument(href)` | Write output (`xsl:result-document`) |
| `ResolveStylesheetModule(href, baseUri)` | Load stylesheets (`xsl:import`, `xsl:include`) |
| `IsDocumentAvailable(uri)` | Check availability (`doc-available()`) |
| `IsTextAvailable(uri)` | Check availability (`unparsed-text-available()`) |

Use `ResourceResolverBase` as a base class — it returns `null` for all methods, so you only override what you need.

### Supplying the content yourself (2.7.0)

Normally the engine checks a location against the policy and then opens it by name. Those are two
steps, so a file replaced between them, for example swapped for a link out of the allowed folder,
is read. Since 2.7.0 a resolver can close that gap by handing the engine the content itself:

| Member | Purpose |
|--------|---------|
| `ResolveContent(ResourceRequest request)` | Return a `ResourceContent` (text or a stream, plus the base URI it is known by) for a module, schema (including its includes and imports), DTD or entity, document, JSON or text resource, or a stylesheet or document named to `fn:transform`. Return `null` to decline. |
| `SuppliesAllContent` | `true` makes the resolver the only source: a declined request fails instead of falling back to opening the location. |

Relative references inside supplied content resolve against its base URI and come back to the
resolver. Supplied content is the host's own decision and is not checked against the policy's URI
rules. Hosts that run untrusted queries or stylesheets should supply content this way and set
`SuppliesAllContent`.

## What Gets Controlled

| Access point | Checked as |
|---|---|
| `doc()`, `document()`, `collection()`, `xsl:source-document`, `xsl:merge` sources, parameter documents | read |
| `unparsed-text`, `unparsed-text-lines`, `unparsed-text-available`, `json-doc` | read (`FOUT1170` when refused) |
| `fn:transform` | import for the stylesheet, read for the source; the nested transformation runs under the caller's policy |
| `xsl:import`, `xsl:include`, `import module … at`, `load-xquery-module` | import (`XQST0059` for XQuery modules) |
| `xsl:import-schema`, `import schema … at`, and every document a schema includes or imports | import |
| External DTDs and entities in `fn:parse-xml` and stylesheets | only with `AllowDtdProcessing`, then read |
| `xsl:evaluate` | only with `AllowXslEvaluate` (`XTDE3175` otherwise) |
| `xsl:result-document` | write |
| HTTP redirects | every hop re-checked |

Checks run while a stylesheet loads as well as while it runs: the stylesheet pre-fetch and static
expressions (`use-when`, static parameters, shadow attributes) are evaluated under the policy.
`doc-available`, `unparsed-text-available` and `stream-available` return false for a refused
resource, and a refused import reads as "not found", so neither reveals whether a file exists.

## Resource Budgets

| Property | Default (Unrestricted) | Default (ServerDefault) | Purpose |
|----------|----------------------|------------------------|---------|
| `MaxDocumentLoads` | 0 (unlimited) | 100 | Limit `doc()` calls |
| `MaxResultDocuments` | 1000 | 10 | Limit `xsl:result-document` |
| `MaxOutputSize` | 50 MB | 10 MB | Limit primary output size |
| `MaxUnparsedTextLoads` | 0 (unlimited) | 50 | Limit `unparsed-text()` calls |

## XQuery

The same `ResourcePolicy` works on `XQueryFacade`:

```csharp
var xquery = new XQueryFacade();
xquery.ResourcePolicy = ResourcePolicy.ServerDefault;
var result = await xquery.EvaluateAsync("doc('file:///etc/passwd')");
// → ResourceAccessDeniedException
```

## Comparison with Saxon

| Feature | Saxon | PhoenixmlDb |
|---------|-------|-------------|
| Protocol filtering | `AllowedProtocols` (comma-separated string) | `AllowedSchemes` (typed set) |
| Host/path scoping | No | Yes — per-host, per-path rules |
| Separate read/write | No | Yes — `AllowedSchemes` vs `AllowedWriteSchemes` |
| Custom resolver | `ResourceResolver` callback | `IResourceResolver` with typed methods per resource type |
| Default | Allow all | No policy allows all; `ServerDefault` denies all |
| Resource budgets | No | Max document loads, result documents, output size, text loads |
| Import filtering | No | Yes — separate `ImportRules` |
