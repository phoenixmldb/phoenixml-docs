---
title: Schemas and Validation
description: "XSD schemas in XQuery, XSLT and .NET hosts: import schema, xsl:import-schema, XsdSchemaProvider, and the PhoenixmlDb.Core.Schema layer"
sort: 8
---

# Schemas and Validation

The XQuery and XSLT engines compile and validate XSD 1.0 schemas through one shared layer in
PhoenixmlDb.Core, the `PhoenixmlDb.Core.Schema` namespace. That layer reads every schema
document, applies the limits, compiles, caches and validates, and it reports problems the same
way whichever engine asked. XSD 1.1 is not supported. The only 1.1 features the layer handles
are the `vc:` version-control markers and the 1.1 duration types (see
[XSD 1.1](#xsd-1-1)). A schema that requires XSD 1.1 is refused with a message that says so.

This page describes PhoenixmlDb.Core 2.4.0, PhoenixmlDb.XQuery 2.8.0 and PhoenixmlDb.Xslt 2.8.0.

## Contents

- [Using schemas from XQuery](#using-schemas-from-xquery)
- [Using schemas from XSLT](#using-schemas-from-xslt)
- [The Core schema layer](#the-core-schema-layer)
- [Stricter than System.Xml](#stricter-than-system-xml)
- [Known limits](#known-limits)

---

## Using schemas from XQuery

### In the query

```xquery
import schema namespace o = "urn:example:order" at "order.xsd";

validate strict { <o:order><o:qty>3</o:qty></o:order> } instance of schema-element(o:order)
```

- **`import schema`** loads the schema when the query is compiled. A relative `at` hint is
  resolved against the query's base URI (`CompilationOptions.BaseUri`), not against the current
  directory. Each hint is tried in turn. If none loads, the error is `XQST0059`, and it lists why
  each hint failed. Under a [resource policy](resource-policy.md), each hint must be allowed for
  import, and so must every document the schema itself includes or imports. The exception is a
  document that the policy's resource resolver supplies.
- **Static rules come first:** binding `xml` or `xmlns` is `XQST0070`, a prefix with an empty
  target namespace is `XQST0057`, and two imports of the same namespace are `XQST0058`.
- **`validate`** (`strict`, `lax`, or `type`) validates a node against the imported schemas.
  `validate strict` of an element that has no declaration is `XQDY0084`.

Once a node has been validated, it carries its schema type:

- `data()` returns values of the schema type, including restrictions, lists and unions. Atomizing
  a node whose type has element-only content is `FOTY0012`.
- Validated nodes match `element(*, p:T)`, `schema-element(p:e)` and `schema-attribute(p:a)`,
  including through substitution groups.
- Each simple type the schema declares has a constructor function, and an atomic value keeps its
  schema type: `o:size('8') instance of o:size` is true. Casts to schema-defined list and union
  types work.
- `fn:idref` finds nodes that the schema types as `xs:IDREF` or `xs:IDREFS`.

Nodes that were not validated are unaffected.

### XsdSchemaProvider

`QueryEngine` uses an `ISchemaProvider` (namespace `PhoenixmlDb.XQuery`) for schema features.
If you don't pass one, it creates a new, empty `XsdSchemaProvider`. If you pass `null`, schema
features are switched off.

```csharp
using PhoenixmlDb.XQuery;
using PhoenixmlDb.XQuery.Execution;

var store = new XdmDocumentStore();
var engine = new QueryEngine(
    nodeProvider: store,
    documentResolver: store,
    schemaProvider: new XsdSchemaProvider(compiledSchema));   // compiled once, see below
```

| Constructor | What it does |
|---|---|
| `XsdSchemaProvider()` | Creates an empty provider. `import schema` and the `Add` methods load into it. |
| `XsdSchemaProvider(params string[] schemaFiles)` | Creates a provider with these files loaded, as `Add(string)` would load them. |
| `XsdSchemaProvider(CompiledSchema schema)` | Creates a provider on a schema that the [Core layer](#the-core-schema-layer) compiled. The compiled schema is shared and never changes. An `import schema` for a namespace it declares is satisfied by it. An import for any other namespace is `XQST0059`, and so is any `Add`. |

| Method | Loads |
|---|---|
| `Add(string schemaPath)` | A schema file. |
| `Add(string targetNamespace, TextReader reader)` | Schema text with no location. A relative `schemaLocation` in it names nothing, so the load fails. |
| `AddFromString(string targetNamespace, string xsdContent)` | Same as above, from a string. |
| `Add(string targetNamespace, TextReader reader, ResourcePolicy policy)` | Schema text. The documents it includes, imports or redefines are read only where `policy` allows imports. `ResourcePolicy.InMemoryOnly` resolves nothing. |
| `AddFromString(string targetNamespace, string xsdContent, ResourcePolicy policy)` | Same as above, from a string. |
| `AddFromString(string targetNamespace, string xsdContent, Uri baseUri, ResourcePolicy? policy = null)` | Schema text that came from `baseUri`, so a relative `schemaLocation` in it resolves against that URI. With a `null` policy, the documents it refers to are read with no restriction. |
| `ImportSchema(string targetNamespace, IReadOnlyList<string>? locationHints = null)` | What `import schema` calls. There is also an overload that takes a `ResourcePolicy?`. |

The overloads that take no policy resolve a schema's own references with no restriction: any
file the process can read, and any URL it can reach. If you vetted the schema text but not what
it points to, use a policy overload. `ResourcePolicy` is in `PhoenixmlDb.XQuery.Security`.

```csharp
var provider = new XsdSchemaProvider { PatternMatchTimeout = TimeSpan.FromSeconds(1) };
provider.AddFromString("urn:example:order", xsdText,
    new Uri("file:///srv/schemas/order.xsd"), ResourcePolicy.ServerDefault);
```

| Property | Type | Default | Meaning |
|---|---|---|---|
| `ImportCache` (static) | `SchemaCache` | `CheckInterval = TimeSpan.Zero` | Where `import schema` keeps compiled schemas for every provider in the process. See below. |
| `Catalog` | `XmlCatalog?` | `null` | Says where the documents a schema names are really read from (see [XmlCatalog](#xmlcatalog)). What it maps a name to is still read under the load's resource policy. |
| `PatternMatchTimeout` | `TimeSpan?` | `null` | The most time one match of an `xs:pattern` facet may take, in casts, in validation and while a schema compiles. `null` leaves .NET's process-wide default, which is infinite unless the host sets it. Set it before you add a schema. |

**`ImportCache`.** A schema loaded from files is compiled once and shared by every provider that
imports the same files. On each use, the cache checks the size and time of **every** document of
the schema, includes and imports as well as the root, and asks that use's resource policy about
each one. A changed schema file or included file is therefore seen by the next query. A schema
is cached only when all of these hold:

- its root is a file;
- the provider has no `Catalog`;
- the policy has no resource resolver;
- the provider holds nothing the cache did not compile.

Anything else is compiled for that provider alone.

**Pattern time limits.** A pattern match that runs past `PatternMatchTimeout` throws
`RegexMatchTimeoutException` from the provider's own methods. A query reports it as `FOER0000`. A
schema whose own enumeration, default or fixed values run past the limit is refused with
`XQST0059`. A query that runs with `QueryExecutionLimits.RegexMatchTimeout` lowers the provider's
limit, and the limit stays lowered. A provider made from a `CompiledSchema` can have its limit
lowered but not raised or removed.

`import schema` compiles its schema while the query is being compiled, before any run-time limit
applies. To bound that step, set `CompilationOptions.RegexMatchTimeout`:

```csharp
var result = engine.Compile(query, new CompilationOptions
{
    BaseUri = "file:///srv/queries/report.xq",
    RegexMatchTimeout = TimeSpan.FromSeconds(1),
});
```

If you compile queries you didn't write, set it to the same value as
`QueryExecutionLimits.RegexMatchTimeout`.

---

## Using schemas from XSLT

```xml
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:o="urn:example:order">
  <xsl:import-schema namespace="urn:example:order" schema-location="order.xsd"/>

  <xsl:template name="xsl:initial-template">
    <o:order xsl:validation="strict"><o:qty>2</o:qty></o:order>
  </xsl:template>
</xsl:stylesheet>
```

- **`xsl:import-schema`** in any module, whether imported or included, is passed to
  `XsltTransformer.SchemaProvider` when the stylesheet loads. A relative `schema-location` is
  resolved against the stylesheet's base URI. Under a resource policy, each location must be
  allowed for import. If none is allowed, the error is `XTSE0220`.
- **An inline `xs:schema`** child of `xsl:import-schema` is read through the provider. A relative
  `schemaLocation` inside it is relative to the stylesheet. A provider that cannot take schema
  text gives `XTSE0220`.
- **A bare `<xsl:import-schema/>`**, with no namespace and no location, loads nothing but makes
  the stylesheet schema-aware. In a stylesheet with no `xsl:import-schema` at all,
  `validation="strict"` or `"type"` and `default-validation="strict"` are `XTSE1660`.
- **`validation=`** on instructions such as `xsl:element`, `xsl:document` and `xsl:copy-of`,
  and **`xsl:validation`** on literal result elements, are applied.
- **Constructor functions of imported schema types** can be called (`o:size('8')`,
  `o:size#1`), and `function-available` answers for them. `cast as o:size` and
  `castable as o:size` work.

The schema-aware typing described [for XQuery](#in-the-query) applies to XPath in stylesheets.

### XsltTransformer.SchemaProvider

```csharp
public PhoenixmlDb.XQuery.ISchemaProvider? SchemaProvider { get; set; }
```

By default this is a new `XsdSchemaProvider` that already holds a schema for the XML namespace,
so a schema can `xs:import` that namespace with no `schemaLocation`. Replace it before calling
`LoadStylesheetAsync`. If you set it to `null`, every `schema-element`/`schema-attribute`
reference becomes `XPST0008` and every `validation="strict"` raises a run-time error.

Because the default provider is never empty, it doesn't share compiled schemas through
`XsdSchemaProvider.ImportCache`. Each transformer compiles its own `xsl:import-schema`. To
compile once and share across transformers, give each one a provider on a `CompiledSchema`. An
`xsl:import-schema` for a namespace that schema declares is then satisfied without loading
anything:

```csharp
var transformer = new XsltTransformer { SchemaProvider = new XsdSchemaProvider(compiledSchema) };
await transformer.LoadStylesheetAsync(stylesheetXml);
```

`XsltTransformer.RegexMatchTimeout` is passed to the provider before the first schema import, so
it also bounds pattern facets while the stylesheet's schemas compile.

---

## The Core schema layer

Hosts that compile or validate directly use the `PhoenixmlDb.Core.Schema` namespace (package
`PhoenixmlDb.Core`). A compilation has two steps:

1. **Read the closure.** The layer reads the roots, then every document they include, import or
   redefine, each one once, within the limits.
2. **Compile in memory.** Nothing is fetched in this step. If the compiler asks for a document
   that step 1 didn't read, the compilation fails.

### End-to-end example

This example compiles a schema from text, with no file or network access, validates a document
against it, and prints the diagnostics.

```csharp
using PhoenixmlDb.Core.Schema;

const string Xsd = """
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
               targetNamespace="urn:example:order" xmlns="urn:example:order"
               elementFormDefault="qualified">
      <xs:element name="order">
        <xs:complexType>
          <xs:sequence>
            <xs:element name="qty" type="xs:positiveInteger"/>
          </xs:sequence>
        </xs:complexType>
      </xs:element>
    </xs:schema>
    """;

var schemaUri = new Uri("urn:example:order.xsd");
CompiledSchema schema;
try
{
    schema = await SchemaCompiler.CompileAsync(
        [schemaUri],
        SchemaAccessGate.SuppliedOnly,
        [SchemaSource.FromText(Xsd, schemaUri)]);
}
catch (SchemaCompilationException ex)
{
    foreach (var diagnostic in ex.Diagnostics)
        Console.WriteLine(diagnostic);
    return;
}

var result = SchemaValidator.Validate(
    schema,
    """<order xmlns="urn:example:order"><qty>0</qty></order>""",
    new Uri("urn:example:order-1.xml"));

Console.WriteLine(result.IsValid ? "valid" : "invalid");
foreach (var diagnostic in result.Diagnostics)
    Console.WriteLine($"{diagnostic.Code ?? "-"} {diagnostic}");
```

This prints `invalid`, then one error with code `cvc-datatype-valid.1.2.1`, located at
`urn:example:order-1.xml(1,42)`.

### SchemaSource

`SchemaSource` is a schema document that the host supplies itself. It is always named by an
**absolute** URI. That URI is what an `xs:include` or `xs:import` elsewhere refers to it by, and
the base its own relative references resolve against. A relative URI is an `ArgumentException`.

| Factory | Use |
|---|---|
| `FromText(string schema, Uri uri)` | Schema text. The version token is a SHA-256 of the text. |
| `FromResource(Assembly assembly, string resourceName, Uri uri)` | A manifest resource. A missing resource is an `ArgumentException`. |
| `FromStore(Uri uri, Func<CancellationToken, ValueTask<Stream>> open, string version)` | Content the host reads on demand, such as a schema held in a database. `open` is called once for each compilation that needs it. `version` must change whenever the content changes, and must not be empty. |

Properties: `Uri`, and `Version` (the token a compiled schema is compared by).

A document that is supplied as a source is never passed to the gate. A schema on disk or on the
network needs no source: it is named by URI and read through the gate.

### ISchemaAccessGate

The gate is the only route by which the layer reads a document the host did not supply: a root
named by URI, and every `xs:include`, `xs:import` and `xs:redefine` in the whole closure. Nothing
in the layer opens a file or a connection itself.

```csharp
public interface ISchemaAccessGate
{
    string Identity { get; }
    ValueTask<SchemaDocumentContent?> OpenAsync(SchemaDocumentRequest request, CancellationToken cancellationToken);
    ValueTask<string?> GetVersionAsync(SchemaDocumentRequest request, CancellationToken cancellationToken);
}
```

- `SchemaDocumentRequest(Uri Uri, string Location, Uri? Referrer)` gives the absolute URI, the
  location as it was written, and the referring document. `IsRoot` is true when `Referrer` is
  null.
- `OpenAsync` returns `new SchemaDocumentContent(stream, version)`, or `null`. A refused document
  and a missing one both return `null`, so a refusal doesn't reveal whether the document exists.
  The layer disposes the stream.
- `GetVersionAsync` returns the version token without the content. The cache uses it.
- `Identity` names the gate's rules, so that differently configured gates get separate cache
  entries. It does not grant access by itself.
- Within one compilation each document is opened at most once, so a gate can count opens against
  a budget. An exception thrown by a gate reaches the caller unchanged.

| Gate | Admits |
|---|---|
| `SchemaAccessGate.SuppliedOnly` | Nothing. A schema can be made only of the supplied `SchemaSource` documents. A reference to anything else fails. |
| `SchemaAccessGate.LocalFiles(params string[] roots)` | `file:` documents under one of the root directories. At least one root is required. On Linux and Windows, the decision is made on the path of the file that was actually opened, with all links resolved. On other platforms, a path with a symbolic link in any component below its root is refused. **The roots must be writable only by the operator.** |

The layer has no gate that fetches from the network. A host that wants one implements it.

### SchemaCompiler

```csharp
ValueTask<CompiledSchema> CompileAsync(IEnumerable<Uri> roots, ISchemaAccessGate gate,
    IEnumerable<SchemaSource>? sources = null, SchemaCompileOptions? options = null,
    CancellationToken cancellationToken = default);

CompiledSchema Compile(IEnumerable<Uri> roots, ISchemaAccessGate gate,
    IEnumerable<SchemaSource>? sources = null, SchemaCompileOptions? options = null);
```

Roots must be absolute URIs, and at least one is required. `Compile` blocks the calling thread.
Use it only when your gate and sources answer at once (files, text, resources) or when blocking a
thread is acceptable. The cancellation token is passed to the gate and the sources, and is checked
between documents. The compile step itself can't be interrupted.

Failures throw `SchemaCompilationException`. That includes a document that isn't available, is
too large, isn't well-formed, has a document type declaration or nests too deeply, as well as a
schema that doesn't compile. `SchemaCompiler.MaxNestingDepth` is `512`.

**CompiledSchema** never changes. If its documents change, the schema is compiled again into a
new instance.

| Member | Meaning |
|---|---|
| `SchemaSet` | The compiled `XmlSchemaSet`. It is shared, so **do not add to it, remove from it, or recompile it.** |
| `Roots` | The URIs the schema was requested by. |
| `Documents` | Every document that was read, as `SchemaDocumentVersion(Uri Uri, string Version)`. |
| `Warnings` | Warnings from the compilation. A schema with errors is never constructed. |
| `GateIdentity` | The identity of the gate its documents were read through. |
| `PatternMatchTimeout` | The pattern limit it was compiled with, or `null`. |

### SchemaCompileOptions

A record. `SchemaCompileOptions.Default` is used when you pass `null`.

| Property | Type | Default | Meaning |
|---|---|---|---|
| `MaxDocumentBytes` | `long` | 16 MiB | The largest single schema document. The layer never takes more than this from a stream. |
| `MaxTotalBytes` | `long` | 64 MiB | The total size of all documents in one compilation. |
| `MaxDocuments` | `int` | 1,024 | The most documents one compilation may read, roots included. |
| `Xsd11Compatibility` | `bool` | `true` | Reads a schema written for XSD 1.1 as a 1.0 processor should (see [XSD 1.1](#xsd-1-1)). With `false`, such a schema fails to compile. |
| `Catalog` | `XmlCatalog?` | `null` | Consulted for each root, for each `schemaLocation` (first as written, then as the resolved absolute URI), and, for an `xs:import` with no location, for the namespace. |
| `PatternMatchTimeout` | `TimeSpan?` | `null` | The most time one match of an `xs:pattern` facet may take, both while compiling and in every validation against the compiled schema. Must be positive. `null` sets no limit of the layer's own. |

If you compile schemas you didn't write, or validate values you didn't write against patterns that
may backtrack, set `PatternMatchTimeout`. With a limit set, a schema whose own enumeration,
default or fixed values run past it does not compile.

### SchemaCache

`SchemaCache` keeps compiled schemas so that each one is compiled once and used until **any**
document of its closure changes, not only a root. Schemas are looked up by their roots, the
gate's identity and the compile options. A supplied `SchemaSource` is compared by its `Version`.
Every other document is checked with the gate's `GetVersionAsync`.

```csharp
var cache = new SchemaCache(new SchemaCacheOptions { CheckInterval = TimeSpan.FromSeconds(5) });
var gate = SchemaAccessGate.LocalFiles("/srv/schemas");

CompiledSchema schema = await cache.GetAsync([new Uri("file:///srv/schemas/order.xsd")], gate);

cache.Invalidate(new Uri("file:///srv/schemas/common.xsd"));   // drops every schema that uses it
```

| `SchemaCacheOptions` | Default | Meaning |
|---|---|---|
| `CheckInterval` | 30 seconds | How long a cached schema is handed out without checking its documents. `TimeSpan.Zero` checks on every use. `Timeout.InfiniteTimeSpan` never checks, so only `Invalidate` and `Clear` replace a schema. |
| `MaxEntries` | 256 | The most compiled schemas kept. The least recently used is evicted first. |
| `TimeProvider` | `null` (system clock) | The clock the interval is measured by. |

| `SchemaCache` member | Meaning |
|---|---|
| `GetAsync(roots, gate, sources = null, options = null, cancellationToken = default)` | Returns the cached schema if it is still current and `gate` admits it. Otherwise compiles. Same parameters and exceptions as `SchemaCompiler.CompileAsync`. |
| `Get(roots, gate, sources = null, options = null)` | The blocking form. |
| `Invalidate(Uri uri)` | Drops every compiled schema that has `uri` anywhere in its closure. |
| `Clear()` | Drops every compiled schema. |
| `Count` | How many compiled schemas the cache holds. |
| `SchemaCache.Default` | A process-wide instance. The 2.8.0 engines don't use it: `import schema` uses `XsdSchemaProvider.ImportCache`. |

When several requests for the same schema arrive together, it is compiled once. A failed
compilation is not kept. `CheckInterval` must not be negative unless it is infinite, and
`MaxEntries` must be at least 1. Otherwise the constructor throws `ArgumentOutOfRangeException`.

### SchemaValidator

```csharp
SchemaValidationResult Validate(CompiledSchema schema, string instance, Uri? sourceUri = null,
    SchemaValidationOptions? options = null, CancellationToken cancellationToken = default);
```

There are also overloads that take a `TextReader` or a `Stream` instance. `sourceUri` is the name
diagnostics use for the document. Any number of validations can run against one compiled schema
at once. The instance is read with no document type declaration allowed and nothing resolved.
`xsi:schemaLocation`, `xsi:noNamespaceSchemaLocation` and inline schemas in the instance are
ignored. The schema is always the one you pass in.

| `SchemaValidationOptions` | Default | Meaning |
|---|---|---|
| `RequireDeclaredRoot` | `true` | The document element must be declared by the schema. If it isn't, the error has code `cvc-elt.1`. |
| `CheckIdentityConstraints` | `true` | Checks `xs:key`, `xs:keyref` and `xs:unique`. |
| `ReportWarnings` | `false` | Includes the schema processor's warnings with the errors. |
| `MaxDiagnostics` | 1,000 | Validation stops after this many diagnostics. |
| `MaxDepth` | 0 (no limit) | How deeply the instance's elements may nest. Deeper is an error, and validation stops. |

| `SchemaValidationResult` | Meaning |
|---|---|
| `IsValid` | True when no error was reported. Always false if validation stopped early. |
| `Diagnostics` | The errors, plus warnings if requested, in document order. |
| `Truncated` | Validation stopped before the end of the document: at `MaxDiagnostics`, at `MaxDepth`, or where the document is not well-formed. Anything after that point wasn't checked. |
| `PatternTimedOut` | A pattern match ran past the schema's `PatternMatchTimeout`. `Truncated` is then true too. |

### SchemaDiagnostic

```csharp
public sealed record SchemaDiagnostic(SchemaSeverity Severity, string Message,
    string? SourceUri = null, int Line = 0, int Column = 0)
{
    public string? Code { get; init; }
    public string? MessageId { get; init; }
}
```

Compilation and validation report problems in the same shape. `Severity` is
`SchemaSeverity.Warning` or `SchemaSeverity.Error`. `Line` and `Column` count from 1, and are 0
when unknown. `ToString()` gives `source(line,column): error: message`.

- **`Code`** is the XSD validation rule the diagnostic reports, such as `cvc-complex-type.2.4.a`
  or `cvc-pattern-valid`. It is set only for a validation error whose message maps to exactly one
  rule. It is `null` in these cases:
  - for a message that covers several rules, such as a duplicate key and a duplicate unique value;
  - for every compilation diagnostic;
  - for diagnostics the layer reports itself (except `cvc-elt.1` for an undeclared document
    element).
- **`MessageId`** is System.Xml's own name for the message (for example
  `Sch_UndeclaredElement`). It is the same for every diagnostic of one kind, whatever names and
  values the text contains. It is `null` when unknown, and for diagnostics the layer reports
  itself. The names belong to System.Xml, not to this library, and they may differ between .NET
  versions.

Both values come from which message System.Xml raised, never from the message wording. Both are
`null` on a runtime where System.Xml's private state can't be read.

**SchemaCompilationException** (derives from `XmlDbException`) is thrown for a schema that
cannot be loaded or doesn't compile. Its `Diagnostics` property lists every error and warning, in
order.

### XmlCatalog

An OASIS XML Catalogs 1.1 catalog, used through `SchemaCompileOptions.Catalog`. For example, it
lets a schema that refers to `http://www.w3.org/2001/xml.xsd` compile from a local copy.

```csharp
var catalog = await XmlCatalog.LoadAsync([new Uri("file:///srv/schemas/catalog.xml")], gate);
var options = new SchemaCompileOptions { Catalog = catalog };
```

- **Supported entries:** all of them. That is `uri`, `system`, `public`, `rewriteURI`,
  `rewriteSystem`, `uriSuffix`, `systemSuffix`, `delegateURI`, `delegateSystem`,
  `delegatePublic`, `group` and `nextCatalog`, with `xml:base` and `prefer` where they apply.
  Names are compared after the specification's normalization, and a `urn:publicid:` name is read
  as the public identifier it stands for.
- **A catalog only renames.** Whatever it maps a name to is still read from a source or through
  the gate.
- **Loading.** The catalog files, and every `nextCatalog` and delegated catalog, are read at
  load time through the same gate and sources. If one can't be read, the load fails. A loaded
  catalog never changes and reads nothing more. A document type declaration in a catalog file
  is skipped.
- **Limits.** At most `XmlCatalog.MaxCatalogFiles` (64) files.

Members:

- `LoadAsync(catalogs, gate, sources = null, limits = null, cancellationToken = default)` and the
  blocking `Load` load a catalog.
- `ResolveUri(string)`, `ResolvePublic(string)` and `ResolveExternalIdentifier(string?, string?)`
  look names up.
- `Identity` and `Documents` describe what was loaded. `XmlCatalog.Empty` is a catalog with no
  entries.

### XSD 1.1

The schema processor is System.Xml's, which implements XSD 1.0. With
`SchemaCompileOptions.Xsd11Compatibility` (on by default):

- Elements marked as 1.1-only with `vc:minVersion` / `vc:maxVersion` are removed, as XSD 1.1
  §4.2.2 says a 1.0 processor should do. An include that is marked 1.1-only is not fetched.
- References to `xs:dayTimeDuration`, `xs:yearMonthDuration` and `xs:dateTimeStamp` are read as
  the 1.0 types they restrict. The 1.1 type's own constraint is not applied: an
  `xs:dayTimeDuration` of `P1Y` is accepted.
- A rewritten document is serialized again. Line and column numbers in later diagnostics about it
  can therefore differ from the original.

Some schemas require XSD 1.1:

- an `xs:schema` with `vc:minVersion="1.1"`;
- a schema that uses `xs:assert`, `xs:assertion`, `xs:alternative`, `xs:openContent`,
  `xs:defaultOpenContent` or `xs:override` outside a `vc:` guard.

Such a schema fails with a message that names the document and the constructs:

```text
The schema document 'urn:example:v11.xsd' requires XSD 1.1: it uses xs:assert (1) with no
vc:minVersion guard. This processor implements XSD 1.0 and reads only the parts of a schema
that are marked for it.
```

---

## Stricter than System.Xml

These defaults are stricter than a bare `XmlSchemaSet` or validating `XmlReader`. They apply to
the Core layer and so to both engines. In XQuery and XSLT, a load failure is `XQST0059`.

- **An unreadable include or import fails the compilation.** System.Xml reports it as a warning
  and compiles what is left. For example, an unused `xs:import` would compile silently without
  its document. The message is `The schema document 'common.xsd' is not available: no source
  supplies it and the access gate does not admit it.`
- **A schema document may not have a document type declaration.**
- **A schema document may not nest elements deeper than 512 levels.**
- **Schema text with no base URI doesn't resolve relative locations against the current
  directory.** Give a base URI (`SchemaSource` always has one, and so does
  `XsdSchemaProvider.AddFromString(namespace, text, baseUri)`).
- **The document element must be declared** (`RequireDeclaredRoot`). Without this check, a
  document validated against a schema for another vocabulary would be reported valid.
- **The instance's own schema hints are not followed.** `xsi:schemaLocation`,
  `xsi:noNamespaceSchemaLocation` and inline schemas are ignored. The instance may not have a
  document type declaration.
- **A cached schema goes to a request only after that request's own gate has admitted every
  document in it.** A gate object the cache hasn't seen is always asked first. After that, its
  answer holds for one `CheckInterval`. If one gate object serves many requests and a withdrawn
  permission must take effect at once, set `CheckInterval` to `TimeSpan.Zero`, or use a separate
  gate object for each request.

---

## Known limits

- **A `CompiledSchema` is not opaque.** Its `XmlSchemaSet` exposes every declaration, and
  `Documents` lists each document's URI. If the code you run must not see those, don't give it
  the object.
- **XSD 1.0 only.** XSD 1.1 is limited to what [XSD 1.1](#xsd-1-1) describes. A 1.1 type's own
  constraint is not checked.
- **Pattern limits depend on System.Xml internals.** `PatternMatchTimeout` works by replacing
  System.Xml's compiled pattern expressions, which are private. On a runtime where they can't be
  reached, a schema that declares a pattern doesn't compile with a limit set, rather than running
  unbounded. `XsdSchemaProvider.PatternMatchTimeout` throws `NotSupportedException` in the same
  case.
- **Without a pattern limit, matches are unbounded.** A pattern that backtracks catastrophically
  takes as long as the value makes it.
- **No network gate is included.** The layer ships `SuppliedOnly` and `LocalFiles` only.
- **The `LocalFiles` roots must be writable only by the operator.** Anyone who can write inside a
  root can choose what a schema is compiled from.

See also: [Resource Policy](resource-policy.md) · [XSLT API](xslt-api.md) ·
[Queries API](queries.md)
