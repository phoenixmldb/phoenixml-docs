---
title: XSLT API
description: "XsltTransformer .NET API — transform XML with XSLT from C#"
sort: 6
---

# XSLT API

The `XsltTransformer` class (`PhoenixmlDb.Xslt`, in the published `PhoenixmlDb.Xslt` package; this page describes version 2.9.0) is the primary .NET API for executing XSLT transformations. It provides a string-in/string-out interface for simple cases, plus `TextReader`, `Stream` and `TextWriter` overloads, a callback for secondary result documents, and control over the initial context, mode and match selection.

## Contents

- [Basic Usage](#basic-usage)
- [Stream API Overloads](#stream-api-overloads)
- [ResultDocumentHandler](#resultdocumenthandler)
- [Source and Mode Selection](#source-and-mode-selection)
- [Collection Binding](#collection-binding)
- [Full API Reference](#full-api-reference)

---

## Basic Usage

The simplest usage: load a stylesheet, transform a string, get a string back.

```csharp
using PhoenixmlDb.Xslt;

var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, new Uri("file:///path/to/stylesheets/"));

// Set parameters
transformer.SetParameter("title", "My Report");
transformer.SetParameter("date", DateTime.Now.ToString("yyyy-MM-dd"));

// Transform
string result = await transformer.TransformAsync(inputXml);
```

`baseUri` resolves relative references in `xsl:import`, `xsl:include`, `doc()` and `document()`; when it is `null`, relative references cannot be resolved. A `string` parameter value is bound as `xs:untypedAtomic`; `SetParameter(string, object?)` with an `int`, `long`, `double`, `decimal` or `bool` binds the corresponding XDM type, and `null` binds the empty sequence.

For secondary result documents and parameter passing, see **[Extensibility](../../language-reference/xslt/extensibility.md)**.

---

## Stream API Overloads

For large documents or when working with streams directly, `XsltTransformer` provides overloads that accept a `TextReader` or `Stream` source and write to a `TextWriter` or `Stream`:

### TextReader / TextWriter

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Transform from TextReader to TextWriter
using var input = new StreamReader("input.xml");
await using var output = new StreamWriter("output.html");
await transformer.TransformAsync(input, output);
```

This overload reads the whole input into a string, transforms it, and writes the result.

### Stream-based

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Transform from Stream to Stream
await using var inputStream = File.OpenRead("input.xml");
await using var outputStream = File.Create("output.html");
await transformer.TransformAsync(inputStream, outputStream);
```

When the stylesheet's initial mode is streamable (`<xsl:mode streamable="yes"/>`), the input stream is fed directly to the streaming engine and peak memory is bounded. Otherwise the input is buffered as with the string overloads.

### Other overloads

```csharp
// Read from a Stream or TextReader, return the result as a string
await using var inputStream = File.OpenRead("input.xml");
string result = await transformer.TransformAsync(inputStream);

// Read from a string, write to a TextWriter
await using var writer = new StreamWriter("output.html");
await transformer.TransformAsync(inputXml, writer);
```

`TransformAsync(Stream, TextWriter)` is the streaming overload: it writes the primary result incrementally and requires the stylesheet's initial mode to be streamable; with a non-streamable mode the engine throws `XsltException`. There is no `TextReader`-to-`Stream` overload.

Every overload takes an optional `CancellationToken`. Cancellation is not transactional — output already written to a writer or stream is not retracted.

The stream overloads are useful for:
- Piping XSLT output directly to HTTP responses, file streams, or other consumers
- Bounding memory with streamable stylesheets
- Integration with ASP.NET Core middleware that works with streams

---

## ResultDocumentHandler

When a stylesheet uses `xsl:result-document` to produce multiple outputs, the secondary results are collected into `SecondaryResultDocuments` (keyed by `href`) after each transform:

```csharp
string primary = await transformer.TransformAsync(inputXml);
await File.WriteAllTextAsync(Path.Combine(outputDir, "index.html"), primary);

foreach (var (href, content) in transformer.SecondaryResultDocuments)
{
    await File.WriteAllTextAsync(Path.Combine(outputDir, href), content);
}
```

To write each secondary result as it is produced instead, set `ResultDocumentHandler`. It is a `Func<string, TextWriter>`: it receives the `href` from `xsl:result-document` and returns the writer the document is written to. When a handler is set, `SecondaryResultDocuments` stays empty.

```csharp
var writers = new List<TextWriter>();

transformer.ResultDocumentHandler = href =>
{
    string outputPath = Path.Combine(outputDir, href);
    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    var writer = new StreamWriter(File.Create(outputPath));
    writers.Add(writer);
    return writer;
};

string primaryResult = await transformer.TransformAsync(inputXml);

// The caller owns the writers: dispose them once the transform completes
foreach (var w in writers)
    await w.DisposeAsync();
```

`MaxResultDocuments` (default `1000`; `0` for unlimited) caps the number of secondary results per transformation.

---

## Source and Mode Selection

### SetSourceSelect

`SetSourceSelect` takes an XPath expression evaluated against the source document; its result becomes the initial context item. By default, the document node is the initial context:

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Start from the "orders" element rather than the document node
transformer.SetSourceSelect("/root/orders");

string result = await transformer.TransformAsync(inputXml);
```

### SetInitialMode

`SetInitialMode` sets the mode whose template rules are applied when processing begins:

```csharp
// Start the transform in "summary" mode
transformer.SetInitialMode("summary");

string result = await transformer.TransformAsync(inputXml);
```

The optional second argument is the mode's namespace URI. Pass `"#unnamed"` to select the unnamed mode explicitly. It is useful when a single stylesheet contains multiple modes for different output formats (e.g., `detail`, `summary`, `toc`):

```csharp
// Generate different outputs from the same stylesheet and input
transformer.SetInitialMode("detail");
string detailHtml = await transformer.TransformAsync(inputXml);

transformer.SetInitialMode("summary");
string summaryHtml = await transformer.TransformAsync(inputXml);
```

### SetInitialModeSelect

`SetInitialModeSelect` is not a mode name: it takes an XPath expression, evaluated with the source document as context, that sets the initial match selection (XSLT 3.0 `initial-match-selection`). Templates of the initial mode are applied to each item it selects instead of to the document node:

```csharp
// Apply templates to every chapter element
transformer.SetInitialModeSelect("//chapter");
```

### Named templates and functions

`SetInitialTemplate(name, namespaceUri)` starts with a named template (pass `null` as the source to `TransformAsync` when no source document is needed); `SetInitialFunction(name, namespaceUri)` with `AddInitialFunctionArgument(value)` starts with a public stylesheet function.

---

## Collection Binding

### SetCollection

`SetCollection` registers a collection URI with a list of XML file paths, making them available to the `collection()` function in the stylesheet:

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Bind a collection of product documents
transformer.SetCollection("products", new List<string>
{
    "data/product-001.xml",
    "data/product-002.xml",
    "data/product-003.xml"
});

// The stylesheet can now use: collection('products')
string result = await transformer.TransformAsync(inputXml);
```

The stylesheet accesses the collection:

```xml
<xsl:template match="/">
  <catalog>
    <xsl:for-each select="collection('products')/product">
      <item name="{name}" price="{price}"/>
    </xsl:for-each>
  </catalog>
</xsl:template>
```

Use an empty string for the default collection (used when `collection()` is called with no argument):

```csharp
transformer.SetCollection("", documentPaths);  // default collection
```

---

## Full API Reference

### XsltTransformer Class

```csharp
public sealed class XsltTransformer
{
    // Stylesheet loading
    Task LoadStylesheetAsync(string stylesheetXml, Uri? baseUri = null,
        Dictionary<string, string>? staticParams = null,
        Dictionary<string, List<(string? Version, string FilePath)>>? packageCatalog = null,
        PackageVersionResolution packageVersionResolution = PackageVersionResolution.Highest);

    // String- and sequence-based transforms
    Task<string> TransformAsync(string? inputXml, CancellationToken ct = default);
    Task<object?> TransformToValueAsync(string? inputXml, CancellationToken ct = default);
    Task<string> TransformAsync(XdmSequence? source, CancellationToken ct = default);
    Task<XdmSequence> TransformToSequenceAsync(XdmSequence? source, CancellationToken ct = default);

    // Reader/stream transforms
    Task<string> TransformAsync(TextReader inputXml, CancellationToken ct = default);
    Task<string> TransformAsync(Stream inputXml, CancellationToken ct = default);
    Task TransformAsync(string? inputXml, TextWriter output, CancellationToken ct = default);
    Task TransformAsync(TextReader inputXml, TextWriter output, CancellationToken ct = default);
    Task TransformAsync(Stream inputXml, TextWriter output, CancellationToken ct = default);
    Task TransformAsync(Stream inputXml, Stream output, CancellationToken ct = default);

    // Parameters
    void SetParameter(string name, string value);
    void SetParameter(string name, object? value);
    void SetParameter(QName name, object? value);
    void SetInitialTemplateParameter(QName name, object? value);
    void SetInitialTunnelParameter(QName name, object? value);

    // Invocation
    void SetInitialTemplate(string name, string? namespaceUri = null);
    void SetInitialMode(string mode, string? namespaceUri = null);
    void SetInitialFunction(string name, string? namespaceUri = null);
    void AddInitialFunctionArgument(object? value);
    void SetSourceSelect(string select);
    void SetInitialModeSelect(string select);

    // URIs and input
    void SetSourceDocumentUri(Uri uri);
    void SetBaseOutputUri(Uri uri);
    void EnableXInclude(bool allowRemote = false, IXmlResourceResolver? resolver = null);
    void SetCollection(string uri, List<string> documentPaths);

    // Result documents
    Func<string, TextWriter>? ResultDocumentHandler { get; set; }
    IReadOnlyDictionary<string, string> SecondaryResultDocuments { get; }
    int MaxResultDocuments { get; set; }              // default 1000; 0 = unlimited

    // Listeners
    Action<string, bool>? MessageListener { get; set; }
    Action<string, bool, int, int>? MessageListenerWithLocation { get; set; }
    Action<string>? WarningListener { get; set; }
    Action<int, string, string>? TraceListener { get; set; }

    // Security and resources
    bool AllowDtdProcessing { get; set; }             // default false
    ResourcePolicy? ResourcePolicy { get; set; }      // see resource-policy.md
    bool DisableStreaming { get; set; }               // evaluate on a tree even for a streamable initial mode
    bool StrictStreamability { get; set; }            // XTSE3430 for what is not guaranteed-streamable (off by default)
    TimeSpan? ImplicitTimezone { get; set; }          // null = the machine's timezone
    TimeSpan? RegexMatchTimeout { get; set; }         // null = .NET's process-wide default
    IReadOnlySet<OutputMethod>? AllowedOutputMethods { get; set; }   // null = any method
    IReadOnlyDictionary<string, IReadOnlyList<string>>? XQueryModules { get; set; }
    PreloadedResources? PreloadedResources { get; set; }
    ISchemaProvider? SchemaProvider { get; set; }
    bool SchemaAware { get; set; }                    // default true; false = basic processor
    ValidationMode? SourceValidation { get; set; }    // Strict or Lax validates the source; null = untyped

    // Inspection
    IReadOnlyList<XsltOutputDeclaration> OutputDeclarations { get; }  // xsl:output declarations, after LoadStylesheetAsync
    bool HasStreamableMode { get; }
    XsltResultTree? PrincipalResultTree { get; }      // the validated principal result as a tree, or null
}
```

`TransformAsync` throws `InvalidOperationException` if no stylesheet has been loaded, and `XsltException` (`PhoenixmlDb.Xslt.Engine`) for errors in the stylesheet or during the transformation. There is no API for registering extension functions on `XsltTransformer`.

### New in 2.9.0

| Member | Also on `XsltTransformOptions` | Default | Meaning |
|---|---|---|---|
| `ImplicitTimezone` | yes | `null` | The timezone a date, time or dateTime with none of its own is taken to be in (comparison, `xsl:sort`, `xsl:for-each-group`, `key()`), and the timezone of `current-dateTime()` and `implicit-timezone()`. `null` is the machine's timezone, as before (on `XsltTransformOptions`, what the host set with `PhoenixmlDb.Xdm.ImplicitTimezone.Use`, or else the machine's). `TimeSpan.Zero` gives the same result on every machine. A whole number of minutes between -14:00 and +14:00; any other value fails the transformation with `ArgumentOutOfRangeException`. Transformations that run at the same time each have their own. Static expressions (`use-when`, static variables) are evaluated when the stylesheet is compiled, in the timezone in effect then. |
| `SchemaAware` | no | `true` | Stylesheets are compiled as by a schema-aware processor: `type` and `validation="strict"` are accepted in any stylesheet. `false` gives a basic processor (XSLT 3.0 §27.1), where they are `XTSE1660` in a stylesheet with no `xsl:import-schema`. Read when a stylesheet is loaded. See [Schemas and Validation](schemas.md#using-schemas-from-xslt). |
| `SourceValidation` | yes | `null` | `ValidationMode.Strict` or `Lax` validates the source against the schema provider's schemas before the transformation; the stylesheet sees typed nodes. A validated source is not streamed. See [Schemas and Validation](schemas.md#xslttransformer-sourcevalidation). |
| `PrincipalResultTree` | no | `null` | The principal result as an `XsltResultTree` with its type annotations, when the whole result was validated as it was built. See [Schemas and Validation](schemas.md#xslttransformer-principalresulttree). |

Also new: `XsltStylesheetSchema`, the schema for XSLT 3.0 stylesheets as an XSD 1.0 copy (see
[Schemas and Validation](schemas.md#xsltstylesheetschema)), and
`ResourcePolicyBuilder.AllowTransformFunction(false)` to turn `fn:transform` off (see
[Resource Policy](resource-policy.md#builder-api)).

**`StrictStreamability` is now the streamability analysis of the specification.** It applies the
posture and sweep rules of XSLT 3.0 §19.8 to every template rule of a streamable mode and to the body
of every `xsl:source-document streamable="yes"`, and reports `XTSE3430` for what is not
guaranteed-streamable: a `preceding-sibling` or other roaming axis, `reverse()`, sorting streamed
nodes, a step down from a parent or an ancestor (`../item`), a leading `/` in the rule of an element,
a comma with two consuming operands, and so on. A template rule is reported when the transformation
starts; an `xsl:source-document` body when that instruction runs. It is still off by default, and
without it such a construct runs on a buffered copy and gives the same result. A stylesheet that
passed the 2.8.0 check can fail this one. Where it differs from the specification:

- It accepts a little more than the specification guarantees, where the engine is known to give the
  right result: a union of two child selections, one branch of `xsl:fork` that returns streamed
  nodes while no other branch reads the input, and `current-group()` anywhere in a group of copied
  nodes.
- It does not check the body of a stylesheet function against its `streamability` category, nor
  that `xsl:apply-templates` names a streamable mode.

**Behaviour changes in 2.9.0** that a host can see: a validation failure in a stylesheet is
`XTTE1510`, `XTTE1512` or `XTTE1515` instead of `XQDY0027` (see
[Schemas and Validation](schemas.md#validation-error-codes-in-xslt)); `TransformAsync(Stream,
TextWriter)` makes the same streamability checks as the other overloads and writes the output of the
rule for the document node when the rule ends; and `xsl:import` and `xsl:include` ask the resolver
once, for the location resolved against the base URI in effect at the element (`xml:base`). See the
[release notes](../../release-notes.md#2-9-0-2026-10-15-xquery-and-xslt-2-9-0-core-2-5-0).

### New in 2.8.0

- **`StrictStreamability`** (also on `XsltTransformOptions`; default `false`): report `XTSE3430` for
  a template rule of a streamable mode that is not guaranteed streamable, instead of running it on a
  buffered copy of the matched subtree, which gives the same result. No effect together with
  `DisableStreaming`. In 2.8.0 the check found one pattern only, a rule with more than one
  instruction that reads the children of the matched node; 2.9.0 replaces it with the complete
  analysis described above.

### New in 2.7.0

- **Synchronous `LoadStylesheet` and `Transform`** overloads (`string`, `XdmSequence`, and
  `TextReader` to `TextWriter`): they block the calling thread and return on it, for desktop and
  plugin hosts without a `SynchronizationContext`. The work runs on the engine's large-stack
  thread. Not available on browser WebAssembly. See [Hosting the Engines](hosting.md).
- **Host-supplied content.** An `IResourceResolver` can implement `ResolveContent` to hand the
  engine the content of imports, includes, source documents and text itself, and
  `SuppliesAllContent` to make it the only source. See [Resource Policy](resource-policy.md).

### New in 2.6.0

- **`DisableStreaming`** (default `false`): the string and node transform overloads evaluate against
  an in-memory tree even when the stylesheet's initial mode is streamable. The `Stream` and
  `XmlReader` overloads for a streamable mode still stream. The CLI's `--no-stream` sets it.
- **`AllowedOutputMethods`** (default `null`, any): the serialization methods a transformation may
  deliver results in. It's checked against the method each result is actually serialized with,
  including a run-time `method` on `xsl:result-document`.
- **`OutputDeclarations`**: the stylesheet's `xsl:output` declarations, including imported and
  included modules, after `LoadStylesheetAsync`.
- **`RegexMatchTimeout`** (default `null`): a time limit for XPath regex functions and
  `xsl:analyze-string`. Opt-in; set it when running untrusted stylesheets under a time limit, since
  a running match can't otherwise be interrupted by cancellation (GHSA-h2xc-4m53-6j8r).
- **`XQueryModules`**: XQuery library modules for `fn:load-xquery-module`, by module namespace URI.
  These are the host's choice and aren't checked against `ResourcePolicy`.

### Thread Safety

`XsltTransformer` instances are **not** thread-safe. The loaded stylesheet, parameters, collections and result documents all belong to the instance; create a new `XsltTransformer` for each transformation rather than sharing one across threads.
