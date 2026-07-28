---
title: XInclude
description: Assemble XML documents from separate files with XInclude 1.0
sort: 1
---

# XInclude

XInclude 1.0 assembles one XML document out of several source files. An
`xi:include` element names another resource. The processor replaces that
element with the resource's content before the document is parsed further.

Use XInclude when a stylesheet, a schema, or a data file grows too large for
one file, or when several documents share common content. Split the shared
content into its own file and reference it from each document that needs it.

## Enabling XInclude processing

XInclude processing is disabled by default. Set `Enabled` on
`XIncludeOptions` to turn it on:

```csharp
var options = new XIncludeOptions
{
    Enabled = true,
};
```

Remote inclusion is disabled by default, even when `Enabled` is true. See
[Security and Limits](security-and-limits.md) before you turn on remote
inclusion or accept documents from an untrusted source.

The engine expands a document's `xi:include` elements through
`XIncludeProcessor.Expand`:

```csharp
XIncludeProcessor.Expand(document, baseUri, options);
```

`document` is the `XmlDocument` to expand, mutated in place. `baseUri` is its
absolute base URI, against which a relative `href` resolves. `options`
carries the settings above. The method returns the same document instance.

A document with no `xi:include` element is returned unchanged; a document
that fails expansion is left partially expanded and must be discarded, not
reused.

## What XInclude supports

- **[XML Inclusion](xml-inclusion.md)** — `parse="xml"`, the default: splices
  a parsed element tree into the host document.
- **[Text Inclusion](text-inclusion.md)** — `parse="text"`: splices a
  resource's decoded content in as a single text node.
- **[Fallback](fallback.md)** — `xi:fallback`: recovers from a resource error
  with substitute content.
- **[Security and Limits](security-and-limits.md)** — the resource-safety
  limits on `XIncludeOptions` and the `IXmlResourceResolver` extension point.

Sub-resource selection with `xpointer`/`fragid` is also supported, for both
an external target and a same-document reference. See
[XPointer](../xpointer/index.md) for the pointer syntax.
