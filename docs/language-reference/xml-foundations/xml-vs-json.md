---
title: XML vs JSON
description: Side-by-side comparison of XML and JSON for developers who think in JSON
sort: 1
---

# XML vs JSON

You already know JSON. Let's use that as a bridge to understanding XML.

## The Same Data, Two Ways

**JSON:**
```json
{
  "order": {
    "id": "12345",
    "date": "2026-03-19",
    "customer": {
      "name": "Acme Corp",
      "email": "orders@acme.com"
    },
    "items": [
      { "sku": "WIDGET-1", "qty": 10, "price": 9.99 },
      { "sku": "GADGET-2", "qty": 5, "price": 24.50 }
    ]
  }
}
```

**XML:**
```xml
<order id="12345" date="2026-03-19">
  <customer>
    <name>Acme Corp</name>
    <email>orders@acme.com</email>
  </customer>
  <items>
    <item sku="WIDGET-1" qty="10" price="9.99"/>
    <item sku="GADGET-2" qty="5" price="24.50"/>
  </items>
</order>
```

They carry the same information. The differences are in what each format *enables*.

## Key Differences

| Aspect | JSON | XML |
|--------|------|-----|
| **Attributes** | No equivalent | Metadata on elements (`id="12345"`) |
| **Mixed content** | Not possible | Text and elements can mix (`<p>Click <a>here</a></p>`) |
| **Namespaces** | No | Yes — avoids name collisions in combined documents |
| **Schema validation** | JSON Schema (optional) | XSD, RelaxNG, Schematron (mature ecosystem) |
| **Transformation** | Roll your own | XSLT — a dedicated language |
| **Query** | JSONPath (limited) | XPath/XQuery — standardized, powerful |
| **Comments** | Not allowed | `<!-- supported -->` |
| **Document order** | Objects unordered | Elements preserve order |

## When XML Wins

- **Document processing** — mixed content (text + markup) is XML's strength
- **Enterprise integration** — many standards (HL7, FpML, XBRL, DITA) are XML-native
- **Transformation pipelines** — XSLT can reshape documents declaratively
- **Validation** — XSD provides type-safe contracts between systems
- **Querying hierarchical data** — XPath/XQuery handle deep nesting naturally

## When JSON Wins

- **Web APIs** — lighter wire format, native to JavaScript
- **Configuration** — simpler for flat key-value data
- **Developer familiarity** — most developers encounter JSON first

## The .NET Perspective

In .NET, you have tools for both:

| Task | JSON | XML |
|------|------|-----|
| Parse | `System.Text.Json` | `System.Xml.Linq` (LINQ to XML) |
| Serialize | `JsonSerializer` | `XmlSerializer` |
| Query | LINQ + `JsonElement` | LINQ to XML / XPath |
| Transform | Manual code | XSLT via PhoenixmlDb |

The key insight: JSON tools in .NET are general-purpose. XML tools are *specialized* — and that specialization is what makes them powerful for the right problems.
