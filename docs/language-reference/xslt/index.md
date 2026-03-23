---
title: XSLT
description: Transform XML documents with XSLT — the declarative transformation language
sort: 3
---

# XSLT

XSLT (Extensible Stylesheet Language Transformations) is a declarative language for transforming XML documents. If you've written Razor views, Handlebars templates, or even CSS selectors, XSLT takes that idea further — pattern matching on XML trees to produce any output format.

XSLT is how you turn XML data into HTML pages, other XML formats, JSON, CSV, or plain text. It's the transformation layer that makes XML practical.

## Getting Started

- **[Your First Transform](first-transform.md)** — A hands-on introduction. Transform XML to HTML, step by step.
- **[Template Matching](template-matching.md)** — The core paradigm shift: declarative rules instead of imperative code.
- **[Output Methods](output-methods.md)** — Producing HTML, XML, JSON, CSV, and text from the same source data.
- **[Extensibility](extensibility.md)** — Custom functions, packages, extension instructions, and .NET integration.

## Instructions Reference

The complete set of XSLT 3.0/4.0 instructions, organized by purpose:

- **[Instructions Overview](instructions/index.md)** — Index of all instruction categories
- **[Output](instructions/output.md)** — value-of, text, sequence, message
- **[Control Flow](instructions/control-flow.md)** — if, choose, switch (4.0), where-populated
- **[Variables and Parameters](instructions/variables-parameters.md)** — variable, param, static params, tunnel params
- **[Iteration and Sorting](instructions/iteration-sorting.md)** — for-each, sort, iterate/break/next-iteration
- **[Grouping](instructions/grouping.md)** — for-each-group with all four modes
- **[Copying and Identity](instructions/copying-identity.md)** — copy, copy-of, identity transform pattern
- **[Node Construction](instructions/node-construction.md)** — element, attribute, namespace, AVTs
- **[Multiple Outputs](instructions/multiple-outputs.md)** — result-document, named output formats
- **[Functions](instructions/functions.md)** — Defining reusable XPath functions
- **[Keys](instructions/keys.md)** — Indexing for fast lookup
- **[String Analysis](instructions/analyze-string.md)** — Regex-based processing
- **[Error Handling](instructions/error-handling.md)** — try/catch, assert, fallback
- **[Merging](instructions/merge.md)** — Combining sorted inputs
- **[Maps, Arrays, Records](instructions/maps-arrays.md)** — Structured data (3.0/4.0)
- **[Streaming](instructions/streaming.md)** — Large document processing with accumulators
- **[Packages](instructions/packages.md)** — Reusable stylesheet libraries
- **[Dynamic Evaluation](instructions/dynamic-evaluation.md)** — Runtime XPath evaluation
- **[Number Formatting](instructions/number-formatting.md)** — Numbering, decimal formats, character maps

## Streaming

PhoenixmlDb supports XSLT 3.0 streaming for processing documents that are too large to fit in memory. Streaming processes the input as a forward-only event stream, never building the full tree.

- **[Streaming and Accumulators](instructions/streaming.md)** — `xsl:mode streamable="yes"`, `xsl:source-document`, accumulators, `xsl:fork`, and streamability rules.

Key capabilities:

- **Primary source streaming** — Declare `xsl:mode streamable="yes"` to stream the principal input document via XmlReader
- **External document streaming** — Use `xsl:source-document streamable="yes"` to stream documents loaded during transformation
- **Accumulators** — Maintain running state (counts, totals, max values) as nodes flow past
- **Static streamability checking** — The compiler analyzes your stylesheet and reports streamability violations at compile time
- **`system-property('xsl:supports-streaming')`** returns `"yes"`
- **Limitations:** `last()` is not available in streaming mode; `xsl:fork` branches execute sequentially (not in parallel)

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
