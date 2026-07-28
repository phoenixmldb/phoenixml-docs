---
title: Text Inclusion
description: Splice a resource's raw text into a document with parse="text"
sort: 3
---

# Text Inclusion

`parse="text"` reads the target resource as text instead of XML, and splices
its decoded content in as a single text node in place of the `xi:include`:

```xml
<xi:include xmlns:xi="http://www.w3.org/2001/XInclude"
            href="notice.txt" parse="text"/>
```

A fragment identifier in `href` (a `#` character) is still a fatal error. A
text resource has no internal structure to point into, so `xpointer` and
`fragid` do not apply to `parse="text"`.

## Encoding and content negotiation

Three attributes control how the target is fetched and decoded:

- `encoding` names the character encoding to decode the resource with. When
  omitted, the processor detects a byte-order mark, then falls back to
  UTF-8.
- `accept` sets the HTTP `Accept` header on a remote fetch, requesting a
  preferred media type.
- `accept-language` sets the HTTP `Accept-Language` header on a remote
  fetch, requesting a preferred language.

`accept` and `accept-language` apply only when the resolver fetches a remote
resource. See [Security and Limits](security-and-limits.md) — remote
fetching is disabled by default.

## Resource errors and fallback

A fetch or decode failure on a `parse="text"` target is a resource error,
exactly as it is for `parse="xml"`. It recovers through an `xi:fallback`
child when one is present. See [Fallback](fallback.md) for the recovery
rules.
