---
title: Security and Limits
description: The resource-safety limits on XIncludeOptions and the resolver extension point
sort: 5
---

# Security and Limits

XInclude resolves `href` values that can come from an untrusted document. Read
this page before you enable XInclude on input you do not fully control.

## Disabled by default

`XIncludeOptions.Enabled` defaults to `false`. A document's `xi:include`
elements are left untouched unless you opt in.

`XIncludeOptions.AllowRemote` also defaults to `false`. With the default
resolver, only local file resources resolve; a non-`file:` URI (such as
`http:` or `https:`) is a fatal error. Enable `AllowRemote` only when you
trust every document that reaches the processor. A remote `href` can force
the process to fetch an arbitrary URI on the include author's behalf.

The default resolver also blocks a `file:` URI that carries a host, such as a
UNC path (`file://host/share/x.xml`). A host-bearing `file:` URI reaches a
remote host over SMB, so it is gated by `AllowRemote` exactly like `http:`
and `https:`.

## Resource-safety limits

Five limits on `XIncludeOptions` bound the cost of expansion. Each guards
against a different failure mode:

| Option | Default | Guards against |
|--------|---------|-----------------|
| `MaxIncludeDepth` | 40 | Runaway or circular `xi:include` nesting |
| `MaxExpansionDepth` | 5000 | Stack exhaustion from deeply nested content or fallback chains |
| `MaxExpandedNodes` | 10,000,000 | Exponential (billion-laughs-style) node blow-up |
| `MaxResourceBytes` | 64 MiB (64 × 1024 × 1024) | One include pulling in an oversized resource |
| `MaxXPathEvalMilliseconds` | 5000 | A pathological `xpath1()` evaluation over a large document |

`MaxIncludeDepth` and `MaxExpansionDepth` are distinct bounds. The first
counts nested `xi:include` targets; the second counts tree-descent recursion
during expansion, including the recursion inside a fallback chain.

A value of zero or less disables `MaxExpansionDepth`, `MaxExpandedNodes`,
`MaxResourceBytes`, or `MaxXPathEvalMilliseconds` individually.

Keep `MaxExpansionDepth` at or near its default. Expansion runs on a worker
thread with a stack sized for the default value. Raising the value far
beyond the default, on adversarial input, can exceed that stack.

A limit breach is always a fatal error. It is never recovered through
`xi:fallback`, unlike a resource error — see [Fallback](fallback.md).

## `IXmlResourceResolver`: security control and extension point

`XIncludeOptions.Resolver` selects the component that dereferences an
`xi:include` target. When you leave it `null`, the processor uses
`LocalFileResourceResolver`, configured from `AllowRemote` and
`MaxResourceBytes`.

A custom `IXmlResourceResolver` implementation serves two purposes at once.

As a security control, a custom resolver can restrict resolution to an
allowlisted directory. It can deny particular schemes outright, or apply a
sandboxing policy the default resolver does not implement. A custom resolver
must enforce its own remote-access and size policy. `AllowRemote` and
`MaxResourceBytes` on `XIncludeOptions` apply only to the built-in
`LocalFileResourceResolver`.

As an extension point, a custom resolver can add a response cache or support
a custom URI scheme. It can also resolve an `href` against a database-backed
document store instead of the filesystem. Implement `ResolveXml` for
`parse="xml"` targets and `ResolveText` for `parse="text"` targets, and
assign the instance to `XIncludeOptions.Resolver`.
