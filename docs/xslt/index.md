---
title: XSLT
description: Transform XML documents with XSLT — the declarative transformation language
sort: 3
---

# XSLT

XSLT (Extensible Stylesheet Language Transformations) is a declarative language for transforming XML documents. If you've written Razor views, Handlebars templates, or even CSS selectors, XSLT takes that idea further — pattern matching on XML trees to produce any output format.

XSLT is how you turn XML data into HTML pages, other XML formats, JSON, CSV, or plain text. It's the transformation layer that makes XML practical.

## What's Here

- **[Your First Transform](first-transform.md)** — A hands-on introduction. We'll take an XML document and transform it into HTML, step by step.
- **[Template Matching](template-matching.md)** — The core of XSLT: how template rules match nodes and produce output. This is the paradigm shift from imperative to declarative thinking.
- **[Built-in Instructions](instructions.md)** — `xsl:for-each`, `xsl:if`, `xsl:choose`, `xsl:variable`, and the other instructions you'll use daily.
- **[Output Methods](output-methods.md)** — Producing HTML, XML, JSON, CSV, and text from the same source data.

## The Mental Model

If you're a C# developer, think of XSLT like this:

| C# Concept | XSLT Equivalent |
|-------------|-----------------|
| A method that takes input and returns output | A template rule that matches a node and produces output |
| `switch` on type | Template matching with `match` patterns |
| `foreach` over a collection | `xsl:for-each` or `xsl:apply-templates` |
| String interpolation | Attribute value templates: `href="{@url}"` |
| Method overloading | Template priority and import precedence |

The key difference: in C# you write imperative code that says *how* to process data. In XSLT you write declarative rules that say *what* to produce for each pattern. The XSLT engine handles the traversal.
