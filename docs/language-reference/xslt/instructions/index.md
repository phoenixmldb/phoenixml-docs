---
title: Instructions Reference
description: Complete reference for all XSLT 3.0/4.0 instructions
sort: 3
---

# XSLT Instructions Reference

Every XSLT instruction is an XML element in the `xsl:` namespace that controls how the transformation proceeds. This reference covers all instructions supported by the PhoenixmlDb XSLT engine, organized by purpose.

## Instruction Categories

| Category | Instructions | Description |
|----------|-------------|-------------|
| [Output](output.md) | value-of, text, comment, processing-instruction, sequence, message | Producing text, nodes, and diagnostic output |
| [Control Flow](control-flow.md) | if, choose/when/otherwise, switch, where-populated, on-empty, on-non-empty | Conditional processing |
| [Variables and Parameters](variables-parameters.md) | variable, param, with-param | Declaring and passing values |
| [Iteration and Sorting](iteration-sorting.md) | for-each, sort, perform-sort, iterate, break, next-iteration | Looping and ordering |
| [Grouping](grouping.md) | for-each-group | Four grouping modes with current-group() and current-grouping-key() |
| [Copying and Identity](copying-identity.md) | copy, copy-of, mode on-no-match | Copying nodes and the identity transform pattern |
| [Node Construction](node-construction.md) | element, attribute, namespace, document | Building nodes with dynamic names |
| [Multiple Outputs](multiple-outputs.md) | result-document, output | Generating multiple files and controlling serialization |
| [Functions](functions.md) | function | Defining reusable functions callable from XPath |
| [Keys and Cross-References](keys.md) | key | Indexing documents for fast lookup |
| [String Analysis](analyze-string.md) | analyze-string, matching-substring, non-matching-substring | Regex-based string processing |
| [Error Handling](error-handling.md) | try, catch, assert, fallback | Handling errors and asserting conditions |
| [Merging](merge.md) | merge, merge-source, merge-key, merge-action | Combining sorted input sources |
| [Maps, Arrays, and Records](maps-arrays.md) | map, map-entry, array, array-member, for-each-member, record | Constructing structured data (XSLT 3.0/4.0) |
| [Streaming and Accumulators](streaming.md) | source-document, accumulator, accumulator-rule, fork | Processing large documents efficiently |
| [Packages](packages.md) | use-package, accept, override, expose | Reusable stylesheet libraries with visibility control |
| [Dynamic Evaluation](dynamic-evaluation.md) | evaluate | Runtime XPath evaluation |
| [Number Formatting](number-formatting.md) | number, decimal-format, character-map | Numbering schemes and format customization |

## Quick Reference

Every instruction follows this pattern:

```xml
<xsl:instruction-name attribute="value">
  <!-- content (other instructions or literal output) -->
</xsl:instruction-name>
```

Instructions can appear in two places:
- **Top-level declarations** (children of `xsl:stylesheet`) — `xsl:template`, `xsl:variable`, `xsl:function`, `xsl:key`, `xsl:output`, etc.
- **Sequence constructors** (inside templates and functions) — `xsl:value-of`, `xsl:for-each`, `xsl:if`, etc.

Some instructions (like `xsl:variable` and `xsl:param`) can appear in both positions with slightly different semantics.
