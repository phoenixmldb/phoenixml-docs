---
title: Document Structure
description: XML elements, attributes, and the document tree explained for JSON developers
sort: 2
---

# Document Structure

Every XML document is a tree. If you've worked with the DOM in JavaScript or `XDocument` in .NET, you already understand the shape — XML just has more node types than JSON.

## The Node Types

JSON has objects, arrays, strings, numbers, booleans, and null. XML has seven node types:

| Node Type | Example | JSON Equivalent |
|-----------|---------|-----------------|
| **Document** | The root container | The top-level `{ }` |
| **Element** | `<order>...</order>` | An object key + value |
| **Attribute** | `id="12345"` | No direct equivalent |
| **Text** | Content inside elements | A string value |
| **Comment** | `<!-- note -->` | Not supported |
| **Processing Instruction** | `<?xml-stylesheet ?>` | Not supported |
| **Namespace** | `xmlns:xs="..."` | Not supported |

For most practical work, you'll deal with elements, attributes, and text.

## Elements vs Attributes

This is the first design decision XML gives you that JSON doesn't:

```xml
<!-- Data as an element -->
<customer>
  <name>Acme Corp</name>
</customer>

<!-- Data as an attribute -->
<customer name="Acme Corp"/>
```

Both are valid. The rule of thumb:

- **Attributes** for simple metadata: IDs, dates, types, flags
- **Elements** for content: text, nested structures, things that might repeat

Attributes cannot contain child elements or mixed content. Elements can contain anything.

## Mixed Content

This is something JSON fundamentally cannot represent:

```xml
<paragraph>
  For more details, see <link href="/api">the API reference</link>
  or contact <emphasis>support</emphasis>.
</paragraph>
```

Text and elements interleaved. This is why every document format (HTML, DocBook, DITA, OOXML) uses XML — JSON has no way to express "text with inline markup."

## Well-Formedness

Every XML document must be well-formed:

- Exactly one root element
- Every opening tag has a closing tag (or is self-closing: `<br/>`)
- Tags are properly nested (no `<b><i></b></i>`)
- Attribute values are quoted
- Element and attribute names are case-sensitive

This is stricter than JSON (which allows trailing commas in some parsers) but means every XML parser produces the same tree — no ambiguity.

## In .NET

```csharp
using System.Xml.Linq;

var doc = XDocument.Parse("""
    <order id="12345">
      <customer>Acme Corp</customer>
    </order>
    """);

// Navigate the tree
var orderId = doc.Root?.Attribute("id")?.Value;     // "12345"
var customer = doc.Root?.Element("customer")?.Value; // "Acme Corp"
```

This is LINQ to XML — and it maps directly to the tree structure we've described. XPath and XQuery provide a more powerful way to navigate these same trees, which we'll cover next.
