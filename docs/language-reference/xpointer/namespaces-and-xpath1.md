---
title: Namespaces and xpath1()
description: Bind namespace prefixes with xmlns() and select nodes with the xpath1() scheme, under a wall-clock timeout
sort: 3
---

# Namespaces and xpath1()

## The `xmlns()` scheme

`xmlns()` binds a namespace prefix for use in a later `xpath1()` part in the
same pointer. Its data is `prefix=uri`:

```
xmlns(c=http://example.com/catalog) xpath1(//c:book)
```

`xmlns()` never selects a node by itself. It only prepares a binding. Place
it before the `xpath1()` part that needs the binding. Parts run in the order
they appear, so the binding must exist before the expression that uses it
evaluates.

The `xml` prefix is always bound to the XML namespace, so `xml:id` and other
`xml:`-prefixed attributes are reachable in an `xpath1()` expression without
an explicit `xmlns()` part.

A malformed `xmlns()` data string — one with no `=`, or an empty prefix — is
a fatal, malformed-pointer error.

## The `xpath1()` scheme

`xpath1()` selects nodes with an XPath 1.0 expression, evaluated against the
target document with System.Xml's built-in XPath 1.0 engine:

```
xpath1(//book[@category='fiction'])
```

An expression that is not valid XPath 1.0 is a fatal, malformed-pointer
error. The error message includes the offending expression text.

### The evaluation timeout

`xpath1()` evaluation runs under a wall-clock budget, because System.Xml's
XPath engine cannot be cancelled mid-evaluation once it starts. The budget is
`MaxXPathEvalMilliseconds` on `XIncludeOptions`, 5000 milliseconds by
default.

An evaluation that exceeds the budget raises a fatal error at the deadline.
The abandoned evaluation keeps running on a dedicated background thread,
off the thread pool, so it does not starve pooled work or the caller.
Discard a document that hits this deadline instead of reusing it, because
that background thread still reads it.

Set `MaxXPathEvalMilliseconds` to `0` or a negative value to remove the
budget. Do this only against a trusted document; an unbounded expression over
an adversarial document can then run without a wall-clock limit.

```csharp
var options = new XIncludeOptions
{
    Enabled = true,
    MaxXPathEvalMilliseconds = 2000,
};
```

### Combining with other parts

An `xpath1()` part can follow `element()` in the same pointer, so the
pointer falls through to an XPath expression when the ID-based lookup finds
nothing. See [Shorthand and element()](shorthand-and-element.md) for the
`element()` scheme and its child-sequence syntax.
