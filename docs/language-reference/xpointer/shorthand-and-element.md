---
title: Shorthand and element()
description: Select an element by its xml:id, or by a root-relative child sequence
sort: 2
---

# Shorthand and element()

## Shorthand: a bare NCName

A shorthand pointer is a bare NCName with no scheme part: a letter or
underscore, followed by letters, digits, underscores, hyphens, or periods. It
contains no parenthesis.

```xml
<xi:include xmlns:xi="http://www.w3.org/2001/XInclude"
            href="catalog.xml" xpointer="chapter-3"/>
```

The evaluator selects the element whose `xml:id` attribute equals the
shorthand value. It returns an empty result when no element has a matching
`xml:id`.

A shorthand value is validated as an NCName before the lookup runs, so it
never introduces a syntax error into the underlying selection.

## The `element()` scheme

`element()` selects an element by ID and an optional child sequence. Its data
takes one of two forms:

```
element(chapter-3)
element(chapter-3/2/1)
element(/1/2)
```

The first form is an ID alone, equivalent to the shorthand pointer. The
second form is an ID followed by a child sequence: a series of `/` and a
positive integer. Each integer is a 1-based position among the parent's
element children. The third form starts with `/`, making the position
root-relative instead of ID-relative; the document itself is the starting
point.

### Resolution rules

Each integer step counts only element children; text, comment, and
processing-instruction nodes do not count. Position 1 is the first element
child, not the first child of any kind.

State this caution before you rely on `element()`: a child-sequence step
that is not a positive integer is a fatal, malformed-pointer error. A step
that has no matching child, or an ID that no element carries, produces an
empty result rather than an error.

`element()` returns at most one node: the element found at the end of the ID
lookup and the child-sequence walk. It returns an empty result when the walk
ends on a non-element node, such as a text node.

### Combining with other parts

`element()` is one part in a scheme sequence. Follow it with another part,
separated by whitespace, so the pointer falls through to that part when
`element()` matches nothing:

```
element(chapter-3) xpath1(//chapter[@id='chapter-3'])
```

See [Namespaces and xpath1()](namespaces-and-xpath1.md) for the `xpath1()`
scheme and how a preceding `xmlns()` part supplies its namespace bindings.
