---
title: Resource Policy
---

# Resource Policy

Control what external resources XSLT and XQuery code can access. Essential for running transformations in server environments where untrusted stylesheets or queries must be sandboxed.

## Quick Start

```csharp
// Lock down for server use — no filesystem, no network
var transformer = new XsltTransformer();
transformer.ResourcePolicy = ResourcePolicy.ServerDefault;
await transformer.LoadStylesheetAsync(stylesheet);
var result = await transformer.TransformAsync(inputXml);
// doc('file:///etc/passwd') → ResourceAccessDeniedException
```

## Presets

### ResourcePolicy.ServerDefault

Denies all external access by default. Only documents pre-loaded by the application or served by a custom resolver are accessible. Limits: 100 document loads, 10 result documents, 10 MB output.

### ResourcePolicy.InMemoryOnly

No external access at all. Only in-memory documents provided via a custom `IResourceResolver`.

### ResourcePolicy.Unrestricted

Backwards-compatible default. All schemes allowed, file-only resolution (same as no policy).

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

## What Gets Controlled

| Access Point | Read Policy | Write Policy | Import Policy |
|---|---|---|---|
| `doc()`, `document()` | AllowedSchemes / ReadRules | — | — |
| `unparsed-text()` | AllowedSchemes / ReadRules | — | — |
| `collection()` | AllowedSchemes / ReadRules | — | — |
| `xsl:result-document` | — | AllowedWriteSchemes / WriteRules | — |
| `xsl:import`, `xsl:include` | — | — | AllowedSchemes / ImportRules |

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
| Default | Allow all | `ServerDefault` denies all |
| Resource budgets | No | Max document loads, result documents, output size, text loads |
| Import filtering | No | Yes — separate `ImportRules` |
