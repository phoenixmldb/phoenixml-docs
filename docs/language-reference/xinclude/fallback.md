---
title: Fallback
description: Recover from a failed xi:include with xi:fallback substitute content
sort: 4
---

# Fallback

An `xi:include` can carry an `xi:fallback` child. When the include's target
cannot be resolved, the processor uses the fallback's content instead of
raising a fatal error:

```xml
<xi:include xmlns:xi="http://www.w3.org/2001/XInclude"
            href="optional-notice.xml">
  <xi:fallback>
    <p>No notice is available.</p>
  </xi:fallback>
</xi:include>
```

An `xi:include` may have at most one `xi:fallback` child. More than one is a
fatal error. An `xi:fallback` that is not a direct child of an `xi:include`
is also always a fatal error, whether or not any include actually fails.

## Resource errors vs. fatal errors

The processor distinguishes two kinds of failure.

A **resource error** is a failure to fetch, parse, or decode the target.
Causes include:

- A missing file or a network failure.
- Malformed XML content or an unknown text encoding.
- An oversized resource.
- An `xpointer` selection that matches no node.

A resource error recovers through the include's `xi:fallback` when one is
present. Without a fallback, it rethrows as a fatal error.

A **fatal error** always aborts processing, with or without a fallback
present. Causes include:

- A malformed `xi:include`: an invalid `parse` value, a missing `href`, or a
  fragment identifier in `href`.
- A misplaced or duplicate `xi:fallback`.
- Cyclic or over-deep inclusion.
- A resource-safety limit breach.
- A remote or UNC fetch blocked because `AllowRemote` is `false`.

A blocked fetch is a security-policy decision, not a transient resource
problem. It is never fallback-eligible.

## How the substitution works

When a resource error recovers through `xi:fallback`, the fallback's
children — not the `xi:fallback` element itself — replace the `xi:include`.
That content is itself XInclude-processed first, so a nested `xi:include` or
`xi:fallback` inside the fallback subtree works exactly as it would
anywhere else in the document. An empty `xi:fallback` removes the failed
`xi:include`, leaving nothing behind.
