---
title: Namespaces
description: XML namespaces explained practically — when you need them and how to handle them
sort: 4
---

# Namespaces

Namespaces are the part of XML that trips up most developers. Here's the practical version.

## The Problem Namespaces Solve

Imagine two systems send you XML. Both have an `<address>` element — but one means a street address and the other means an email address. Without namespaces, your parser can't tell them apart.

Namespaces solve this by qualifying element names with a URI:

```xml
<!-- Street address -->
<shipping:address xmlns:shipping="http://example.com/shipping">
  <shipping:street>123 Main St</shipping:street>
</shipping:address>

<!-- Email address -->
<email:address xmlns:email="http://example.com/email">
  <email:value>user@example.com</email:value>
</email:address>
```

The URI doesn't need to resolve to a web page — it's just a unique identifier.

## The JSON Comparison

JSON avoids this problem by not having namespaces at all. When two JSON APIs have a `"name"` field that means different things, you handle it in code. XML handles it in the document structure.

The trade-off: JSON is simpler. XML is more composable — you can merge documents from different sources without name collisions.

## Default Namespaces

You don't always need prefixes. A **default namespace** applies to an element and all its unprefixed descendants:

```xml
<order xmlns="http://example.com/orders">
  <customer>Acme Corp</customer>
  <total>99.50</total>
</order>
```

Every element here is in the `http://example.com/orders` namespace, even without a prefix.

## The XPath Gotcha

This is the number one namespace mistake. Given this document:

```xml
<order xmlns="http://example.com/orders">
  <customer>Acme Corp</customer>
</order>
```

This XPath **does not work**: `/order/customer`

Why? Because `order` and `customer` are in a namespace, but the XPath uses unprefixed names, which XPath treats as "no namespace."

You must register the namespace and use a prefix in your XPath:

```csharp
var ns = new XmlNamespaceManager(new NameTable());
ns.AddNamespace("o", "http://example.com/orders");
// Now this works: /o:order/o:customer
```

Or in XSLT:
```xml
<xsl:stylesheet xmlns:o="http://example.com/orders" ...>
  <xsl:template match="o:order">
    <xsl:value-of select="o:customer"/>
  </xsl:template>
</xsl:stylesheet>
```

## When You Need Them

- **Consuming external standards** (SOAP, XHTML, SVG, XBRL) — they use namespaces, so you must too
- **Combining documents** from different sources
- **Publishing schemas** intended for wide consumption

## When You Don't

- **Internal documents** with a single source — namespaces add complexity without benefit
- **Configuration files** — keep it simple
- **Prototyping** — add namespaces later when the structure is stable

## In .NET

```csharp
XNamespace ns = "http://example.com/orders";

var doc = XDocument.Parse("""
    <order xmlns="http://example.com/orders">
      <customer>Acme Corp</customer>
    </order>
    """);

// LINQ to XML handles namespaces cleanly
var customer = doc.Root?.Element(ns + "customer")?.Value; // "Acme Corp"
```

The `ns + "customer"` syntax is LINQ to XML's way of creating a qualified name. XPath and XQuery use prefix declarations instead, which we'll cover in those sections.
