---
title: Home
description: XPath, XSLT, and XQuery documentation for .NET developers
sort: 0
---

# PhoenixML Documentation

A practical guide to XPath, XSLT, and XQuery for .NET developers who work with data integration.

If you've spent your career working with JSON and REST APIs, you might wonder why XML technologies still matter. The answer is simple: XML remains the backbone of enterprise data exchange, document processing, healthcare (HL7/FHIR), financial services (FpML, SWIFT), government standards, and publishing. When you need to transform, query, or validate structured documents at scale, XPath, XSLT, and XQuery are purpose-built tools that no amount of `System.Text.Json` will replace.

This documentation assumes you're comfortable with C# and .NET. We'll draw parallels to LINQ, JSON processing, and other patterns you already know — then show you where XML technologies go further.

## Where to Start

- **[XML Foundations](xml-foundations/index.md)** — If you're new to XML or need a refresher, start here. We cover just enough to be productive, drawing comparisons to JSON along the way.
- **[XPath](xpath/index.md)** — The query language for XML. Think of it as LINQ expressions for XML trees — but standardized, portable, and incredibly powerful.
- **[XSLT](xslt/index.md)** — Transform XML documents into HTML, other XML formats, JSON, CSV, or plain text. If you've ever written a Razor view or a string template, XSLT is the industrial-strength version.
- **[XQuery](xquery/index.md)** — A full programming language for querying and constructing XML. Where XPath selects nodes, XQuery builds new documents from them.

## Why These Tools?

| If you know... | Then you'll appreciate... |
|----------------|--------------------------|
| LINQ to XML | XPath — same idea, standardized syntax |
| Razor / Handlebars | XSLT — declarative template-based transforms |
| SQL | XQuery — query language for hierarchical data |
| `jq` for JSON | XPath/XQuery — the XML equivalents, with more power |

## About This Site

This documentation is built with [Crucible](https://github.com/phoenixmldb/crucible), a static site generator powered by the [PhoenixmlDb](https://github.com/phoenixmldb) XSLT 4.0 engine. The site you're reading was transformed from Markdown through XML via XSLT — an example of the technology it teaches.
