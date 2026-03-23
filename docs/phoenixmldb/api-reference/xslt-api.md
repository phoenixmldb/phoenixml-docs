---
title: XSLT API
description: "XsltTransformer .NET API — transform XML with XSLT from C#"
sort: 6
---

# XSLT API

The `XsltTransformer` class is the primary .NET API for executing XSLT transformations. It provides a string-in/string-out interface for simple cases, plus stream-based overloads for large documents and advanced control over result documents, source selection, and initial modes.

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
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Set parameters
transformer.SetParameter("title", "My Report");
transformer.SetParameter("date", DateTime.Now.ToString("yyyy-MM-dd"));

// Transform
string result = await transformer.TransformAsync(inputXml);
```

For extension functions, secondary result documents, and parameter passing, see **[Extensibility](../../language-reference/xslt/extensibility.md)**.

---

## Stream API Overloads

For large documents or when working with streams directly (avoiding string allocations), `XsltTransformer` provides overloads that accept `TextReader`, `Stream`, and `TextWriter`:

### TextReader / TextWriter

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Transform from TextReader to TextWriter
using var input = new StreamReader("input.xml");
using var output = new StreamWriter("output.html");
await transformer.TransformAsync(input, output);
```

### Stream-based

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Transform from Stream to Stream
using var inputStream = File.OpenRead("input.xml");
using var outputStream = File.Create("output.html");
await transformer.TransformAsync(inputStream, outputStream);
```

### Mixed overloads

```csharp
// Read from a Stream, write to a TextWriter
using var inputStream = File.OpenRead("input.xml");
using var output = new StringWriter();
await transformer.TransformAsync(inputStream, output);
string result = output.ToString();

// Read from a TextReader, write to a Stream
using var input = new StringReader(inputXml);
using var outputStream = File.Create("output.html");
await transformer.TransformAsync(input, outputStream);
```

The stream overloads are particularly useful for:
- Avoiding large string allocations for multi-megabyte documents
- Piping XSLT output directly to HTTP responses, file streams, or other consumers
- Integration with ASP.NET Core middleware that works with streams

---

## ResultDocumentHandler

When a stylesheet uses `xsl:result-document` to produce multiple output files, you can provide a `ResultDocumentHandler` delegate to control how each secondary result is handled. This replaces the default behavior of collecting results into `SecondaryResultDocuments`.

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Custom handler: write each result document to disk as it is produced
transformer.ResultDocumentHandler = async (href, content) =>
{
    string outputPath = Path.Combine(outputDir, href);
    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    await File.WriteAllTextAsync(outputPath, content);
    Console.WriteLine($"  Written: {outputPath}");
};

string primaryResult = await transformer.TransformAsync(inputXml);
await File.WriteAllTextAsync(Path.Combine(outputDir, "index.html"), primaryResult);
```

The handler receives:
- `href` — the URI from the `xsl:result-document` `href` attribute (resolved relative to the base output URI)
- `content` — the serialized content of that result document

### Stream-based ResultDocumentHandler

For large secondary results, use the stream-based overload:

```csharp
transformer.ResultDocumentHandler = async (href, contentStream) =>
{
    string outputPath = Path.Combine(outputDir, href);
    Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
    using var fileStream = File.Create(outputPath);
    await contentStream.CopyToAsync(fileStream);
};
```

This avoids materializing the entire secondary result as a string, which matters for transforms that produce many or large secondary documents.

---

## Source and Mode Selection

### SetSourceSelect

`SetSourceSelect` specifies which nodes from the source document to use as the initial context. By default, the entire document node is the initial context. With `SetSourceSelect`, you can narrow to a specific subtree:

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Only transform the "orders" subtree
transformer.SetSourceSelect("/root/orders");

string result = await transformer.TransformAsync(inputXml);
```

The XPath expression is evaluated against the source document, and the resulting node(s) become the initial context for the transformation.

### SetInitialModeSelect

`SetInitialModeSelect` sets the initial mode for the transformation. This determines which set of template rules is active when processing begins:

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Start the transform in "summary" mode
transformer.SetInitialModeSelect("summary");

string result = await transformer.TransformAsync(inputXml);
```

This is equivalent to having the initial `apply-templates` use `mode="summary"`. It is useful when a single stylesheet contains multiple named modes for different output formats (e.g., `detail`, `summary`, `toc`).

```csharp
// Generate different outputs from the same stylesheet and input
transformer.SetInitialModeSelect("detail");
string detailHtml = await transformer.TransformAsync(inputXml);

transformer.SetInitialModeSelect("summary");
string summaryHtml = await transformer.TransformAsync(inputXml);
```

---

## Collection Binding

### SetCollection

`SetCollection` binds a named collection to a set of XML documents, making them available to the `collection()` function in the stylesheet:

```csharp
var transformer = new XsltTransformer();
await transformer.LoadStylesheetAsync(stylesheetXml, baseUri);

// Bind a collection of product documents
transformer.SetCollection("products", new[]
{
    File.ReadAllText("data/product-001.xml"),
    File.ReadAllText("data/product-002.xml"),
    File.ReadAllText("data/product-003.xml")
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

You can also bind the default collection (used when `collection()` is called with no argument):

```csharp
transformer.SetCollection(null, documents);  // default collection
```

---

## Full API Reference

### XsltTransformer Class

```csharp
public class XsltTransformer
{
    // Stylesheet loading
    Task LoadStylesheetAsync(string stylesheet, string baseUri);

    // String-based transform
    Task<string> TransformAsync(string inputXml);

    // Stream-based transforms
    Task TransformAsync(TextReader input, TextWriter output);
    Task TransformAsync(Stream input, Stream output);
    Task TransformAsync(Stream input, TextWriter output);
    Task TransformAsync(TextReader input, Stream output);

    // Parameters
    void SetParameter(string name, object value);

    // Source and mode selection
    void SetSourceSelect(string xpathExpression);
    void SetInitialModeSelect(string modeName);

    // Collections
    void SetCollection(string? name, IEnumerable<string> documents);

    // Extension functions
    void RegisterFunction(string namespaceUri, string localName, Delegate function);

    // Result document handling
    ResultDocumentHandler? ResultDocumentHandler { get; set; }
    IReadOnlyDictionary<string, string> SecondaryResultDocuments { get; }
}
```

### Thread Safety

`XsltTransformer` instances are **not** thread-safe. Create a new instance per thread or per request. The compiled stylesheet can be shared (loaded once, used many times), but the transformer state (parameters, collections, result documents) is per-instance.
