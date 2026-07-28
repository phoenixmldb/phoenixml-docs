---
title: XPointer
description: The XPointer Framework that XInclude uses to select a subset of a target document
sort: 1
---

# XPointer

XPointer identifies a fragment of an XML document. XInclude uses it to select
part of a target document instead of the whole document element. There is no
standalone XPointer API; the only way to reach it is the `xpointer` (or
`fragid`) attribute on `xi:include`. See [XInclude](../xinclude/index.md).

## How XInclude reaches XPointer

An `xi:include` with an `xpointer` or `fragid` attribute passes that
attribute's value to the XPointer evaluator, together with the target
document. The evaluator returns the matched nodes, or an empty result. An
empty result triggers `xi:fallback` if present; see
[Fallback](../xinclude/fallback.md).

```xml
<xi:include xmlns:xi="http://www.w3.org/2001/XInclude"
            href="catalog.xml" xpointer="chapter-3"/>
```

The same attribute with no `href` selects from the including document
itself.

## The Framework: scheme-based parts

An XPointer value is either a shorthand (see
[Shorthand and element()](shorthand-and-element.md)) or a sequence of one or
more scheme-based parts: `scheme(data) scheme(data) ...`. The evaluator tries
each part in order and returns the first one that matches at least one node.

Three scheme-based parts are supported:

| Scheme | Purpose | Page |
|--------|---------|------|
| `element()` | Selects an element by ID or child sequence | [Shorthand and element()](shorthand-and-element.md) |
| `xmlns()` | Binds a prefix for a following `xpath1()` part | [Namespaces and xpath1()](namespaces-and-xpath1.md) |
| `xpath1()` | Selects nodes with an XPath 1.0 expression | [Namespaces and xpath1()](namespaces-and-xpath1.md) |

An unrecognized scheme name is not an error. The evaluator ignores that part
and tries the next one. Only a value with no matching part at all, or a value
that violates the Framework's own grammar, is malformed.

## No user extension point

XPointer has no user extension point. The set of supported schemes —
shorthand, `element()`, `xmlns()`, and `xpath1()` — is fixed by the engine.
There is no way to register a custom scheme, and no public API surfaces the
evaluator directly; it is an internal detail of XInclude processing. Do not
design a document format around an XPointer scheme the engine does not
implement — the pointer part is silently skipped rather than rejected.

> For C# developers: this is unlike an `IXmlResourceResolver`, which is a
> public extension point on `XIncludeOptions`. XPointer scheme resolution has
> no equivalent hook.
