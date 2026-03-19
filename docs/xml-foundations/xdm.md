---
title: The XQuery and XPath Data Model
description: How XPath, XSLT, and XQuery see your XML documents
sort: 3
---

# The XQuery and XPath Data Model (XDM)

XPath, XSLT, and XQuery all operate on the same abstract view of XML documents called the **XDM** (XQuery and XPath Data Model). Understanding the XDM is like understanding how LINQ sees `IEnumerable<T>` — it's the mental model that makes everything else click.

## Why It Matters

When you write XPath like `/order/items/item`, you're not doing string matching. You're navigating a typed tree defined by the XDM. The XDM defines:

- What kinds of nodes exist
- How they relate to each other (parent, child, sibling, ancestor, descendant)
- What values they have
- How sequences work

## Sequences

The fundamental data type in XDM is the **sequence** — an ordered list of items. This is directly analogous to `IEnumerable<T>` in .NET.

Key rules:
- Every value is a sequence (even a single number — it's a sequence of length 1)
- Sequences are flat — no nesting (unlike JSON arrays)
- The empty sequence `()` is like an empty enumerable

```
(1, 2, 3)           => a sequence of three integers
"hello"              => a sequence of one string
()                   => the empty sequence
(1, (2, 3), 4)       => flattened to (1, 2, 3, 4)
```

If you've used LINQ's `SelectMany` to flatten nested collections, the XDM does this automatically.

## Atomic Types

The XDM has a rich type system — much richer than JSON's string/number/boolean/null:

| XDM Type | .NET Equivalent | JSON Equivalent |
|----------|----------------|-----------------|
| `xs:string` | `string` | string |
| `xs:integer` | `long` | number |
| `xs:decimal` | `decimal` | number |
| `xs:double` | `double` | number |
| `xs:boolean` | `bool` | boolean |
| `xs:date` | `DateOnly` | string (convention) |
| `xs:dateTime` | `DateTime` | string (convention) |
| `xs:duration` | `TimeSpan` | not supported |
| `xs:anyURI` | `Uri` | string (convention) |
| `xs:QName` | Qualified name | not supported |

Notice that dates, times, and URIs are first-class types — not strings that happen to look like dates. This means XPath can compare dates, add durations, and sort by time without parsing strings.

## Nodes and Their Properties

Each node in the XDM has:

- **Identity** — two nodes can have the same content but be different nodes
- **Type** — document, element, attribute, text, comment, processing instruction, namespace
- **Name** — elements and attributes have qualified names (namespace + local name)
- **String value** — the text content
- **Typed value** — the value cast to its schema type
- **Children** — for document and element nodes
- **Attributes** — for element nodes
- **Parent** — every node except the document root has one

## The Tree, Visualized

```
Document
└── Element: order (id="12345")
    ├── Attribute: id = "12345"
    ├── Element: customer
    │   └── Text: "Acme Corp"
    └── Element: items
        ├── Element: item (sku="WIDGET-1")
        │   └── Attribute: sku = "WIDGET-1"
        └── Element: item (sku="GADGET-2")
            └── Attribute: sku = "GADGET-2"
```

XPath navigates this tree. XSLT transforms it. XQuery queries and constructs from it. They all see the same XDM.
