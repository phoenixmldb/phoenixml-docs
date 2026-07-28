---
title: XML Inclusion
description: Splice a parsed XML document into another with parse="xml"
sort: 2
---

# XML Inclusion

`parse="xml"` is the default `xi:include` mode. The processor fetches the
resource named by `href`, parses it as XML, and splices its document element
in place of the `xi:include`:

```xml
<xi:include xmlns:xi="http://www.w3.org/2001/XInclude"
            href="shared-section.xml"/>
```

Only the target's document element is spliced in. A comment or a processing
instruction that sits outside the target's root element is not included.

## Resolving `href`

`href` resolves against the in-scope base URI. That base is the including
document's base URI, adjusted by an `xml:base` attribute on any ancestor
element, and by an `xml:base` attribute on the `xi:include` element itself.

A fragment identifier in `href` (a `#` character) is a fatal error. XInclude
1.0 §4.2 reserves fragments for selecting into the parsed result, not the
resource itself. Use the `xpointer` or `fragid` attribute instead — see
[XPointer](../xpointer/index.md).

## Cyclic and over-deep inclusion

A resource that includes itself, directly or through a chain of other
includes, is a fatal error. The processor tracks every target currently
being expanded and rejects a repeat.

Nesting deeper than `MaxIncludeDepth` is also a fatal error. See
[Security and Limits](security-and-limits.md) for the default and how to
change it.

## `xml:base` and `xml:lang` fixup (§4.5)

The processor splices a top-level included element into the host document.
It then stamps two attributes on that element, unless the element already
carries its own:

- `xml:base`, set to the resolved target URI. A descendant element that
  moves with the include still resolves its own relative URIs correctly,
  because it inherits this stamped `xml:base`.
- `xml:lang`, set to the in-scope `xml:lang` from the `xi:include`'s
  ancestor chain, if any is in scope.

Only the top-level included element receives this fixup. A descendant
element resolves its base and language through the stamped attribute plus
its own existing `xml:base`/`xml:lang` chain. This is the normal resolution
rule for any XML document.

## Sub-resource selection

An `xi:include` with an `xpointer` or `fragid` attribute selects a subset of
the target instead of its whole document element. The same attribute with no
`href` selects from the including document itself. See
[XPointer](../xpointer/index.md) for the pointer syntax and evaluation
rules.
