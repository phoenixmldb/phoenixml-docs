---
title: XDM Data Model
description: The XQuery Data Model — how PhoenixmlDb represents documents internally
sort: 3
---

# XDM Data Model

PhoenixmlDb uses the XQuery Data Model (XDM) as its foundational data representation. Understanding XDM helps you write effective queries and understand how your documents are stored.

## Overview

XDM represents XML documents as trees of nodes. Every document, element, attribute, and text content is a node with specific properties and relationships.

## Node Types

XDM defines seven node types:

### Document Node

The root of an XML document tree.

```xml
<!-- Document node contains the entire document -->
<?xml version="1.0"?>
<root>
    <item>Content</item>
</root>
```

```xquery
(: In a container query, doc() resolves a document of the same container by name :)
let $doc := doc('document.xml')
return $doc  (: Returns document node :)
```

### Element Node

Represents an XML element with its tag name, namespace, and content.

```xml
<book xmlns="http://example.com/books" id="123">
    <title>XQuery Fundamentals</title>
</book>
```

Properties:
- **Node name**: QName (namespace URI + local name)
- **String value**: Concatenated text content of descendants
- **Typed value**: Based on schema type annotation

### Attribute Node

Represents an XML attribute.

```xml
<product id="123" category="electronics"/>
```

```xquery
(: Access attributes :)
$product/@id           (: Returns attribute node :)
$product/@id/string()  (: Returns "123" :)
data($product/@id)     (: Returns the typed value: xs:untypedAtomic without a schema :)
```

### Text Node

Contains character data between elements.

```xml
<message>Hello, World!</message>
```

> **Note:** Adjacent text nodes are always merged. CDATA sections become text nodes. Unless the
> container sets `PreserveWhitespace = true`, whitespace-only text nodes are dropped when a
> document is stored.

### Comment Node

Represents XML comments.

```xml
<!-- This is a comment -->
```

```xquery
$doc//comment()  (: Selects all comment nodes :)
```

### Processing Instruction Node

Represents XML processing instructions.

```xml
<?xml-stylesheet type="text/xsl" href="style.xsl"?>
```

```xquery
$doc//processing-instruction()  (: All PIs :)
$doc//processing-instruction('xml-stylesheet')  (: Specific PI :)
```

### Namespace Node

Represents namespace declarations (inherited by descendants).

```xml
<root xmlns="http://default.ns" xmlns:custom="http://custom.ns">
```

PhoenixmlDb stores namespace declarations on the element's own record rather than as separate
node entries.

## Node Identity and Equality

### Node Identity

Every node has a unique identity. Two nodes are identical only if they are the exact same node in the tree.

```xquery
let $x := <item>1</item>
let $y := $x
return $x is $y  (: true - same node :)
```

```xquery
let $a := <item>1</item>
let $b := <item>1</item>
return $a is $b  (: false - different nodes :)
```

### Value Equality

Nodes can have equal values without being identical.

```xquery
let $a := <item>1</item>
let $b := <item>1</item>
return (
  $a = $b,   (: true - equal values :)
  $a eq $b   (: true - equal values :)
)
```

## Node Relationships

### Parent-Child

```
         Document
             │
           <root>
           /    \
      <item>    <item>
         │         │
       "A"       "B"
```

```xquery
$node/parent::*     (: Parent element :)
$node/..            (: Parent (shorthand) :)
$node/child::*      (: Child elements :)
$node/*             (: Child elements (shorthand) :)
```

### Ancestor-Descendant

```xquery
$node/ancestor::*           (: All ancestors :)
$node/ancestor-or-self::*   (: Self and ancestors :)
$node/descendant::*         (: All descendants :)
$node//item                 (: Descendant items (shorthand) :)
```

### Sibling

```xquery
$node/preceding-sibling::*  (: Siblings before :)
$node/following-sibling::*  (: Siblings after :)
```

## Document Order

Nodes are ordered in **document order**:
1. Document node first
2. Element before its children
3. Attributes before children (order among attributes is implementation-defined)
4. Children in order of appearance

```xquery
(: Path and union operators return nodes in document order, without duplicates :)
$c | $a | $b
($c, $a, $b)/.
```

## Atomic Values

XDM also includes atomic values (not nodes):

| Type | Example | XQuery Literal |
|------|---------|----------------|
| `xs:string` | "hello" | `"hello"` |
| `xs:integer` | 42 | `42` |
| `xs:decimal` | 3.14 | `3.14` |
| `xs:double` | 1.5e10 | `1.5e10` |
| `xs:boolean` | true | `true()` |
| `xs:date` | 2024-01-15 | `xs:date("2024-01-15")` |
| `xs:dateTime` | 2024-01-15T10:30:00 | `xs:dateTime("2024-01-15T10:30:00")` |
| `xs:QName` | ex:local | `QName("http://example.com/ns", "ex:local")` |

## Sequences

In XDM, everything is a sequence. A single value is a sequence of one item.

```xquery
(: Empty sequence :)
()

(: Single item (sequence of one) :)
42
<item/>

(: Multiple items :)
(1, 2, 3)
(<a/>, <b/>, <c/>)

(: Mixed sequence :)
(1, "two", <three/>)

(: No nested sequences - automatically flattened :)
(1, (2, 3), 4)  (: Same as (1, 2, 3, 4) :)
```

## Type System

### Sequence Types

```xquery
(: Type declarations :)
declare variable $x as xs:integer := 42;
declare variable $items as element()* := $doc//item;

(: Occurrence indicators :)
xs:integer      (: Exactly one integer :)
xs:integer?     (: Zero or one integer :)
xs:integer*     (: Zero or more integers :)
xs:integer+     (: One or more integers :)
```

### Type Checking

```xquery
(: Instance of :)
$x instance of xs:integer

(: Cast :)
xs:integer($string)
$value cast as xs:date

(: Treat :)
$node treat as element()
```

## Storage in PhoenixmlDb

PhoenixmlDb stores XDM nodes as follows:

1. **Node Shredding**: Documents are decomposed into individual nodes, one LMDB entry per node, keyed by node ID
2. **Namespace Interning**: Namespace URIs are stored once and referenced by ID
3. **Linked Node Records**: Each record holds its parent's ID and its attributes' and children's IDs, so navigation follows IDs instead of reparsing text
4. **String Values**: Attribute and text values are stored as strings; typed values are derived from them when queried

A separate structural (parent-child) index, along with the other indexes, is maintained only when
indexing is enabled with `db.EnableIndexing()` (see [Indexing](indexing.md)).

```
Node Store (one entry per node, keyed by NodeId):
┌──────┬──────┬─────────┬────────┬─────────────┬──────────┐
│ ID   │ Kind │ Name    │ Parent │ Children    │ Value    │
├──────┼──────┼─────────┼────────┼─────────────┼──────────┤
│ 1    │ Doc  │ -       │ -      │ 2           │ -        │
│ 2    │ Elem │ "root"  │ 1      │ 4 (attr: 3) │ -        │
│ 3    │ Attr │ "id"    │ 2      │ -           │ "123"    │
│ 4    │ Elem │ "item"  │ 2      │ 5           │ -        │
│ 5    │ Text │ -       │ 4      │ -           │ "Hello"  │
└──────┴──────┴─────────┴────────┴─────────────┴──────────┘
```

## Best Practices

1. **Understand node vs value**: Use `data()` or `/text()` when you need string values
2. **Use typed comparisons**: Compare typed values for correct ordering
3. **Leverage document order**: Use positional predicates effectively
4. **Mind the sequences**: Functions behave differently with sequences vs single items
