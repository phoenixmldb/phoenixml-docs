---
title: Node Functions
description: XPath node properties, names, namespaces, and document access functions
sort: 6
---

# Node Functions

These functions inspect and access properties of XML nodes — names, namespaces, document URIs, and related information. They're essential when writing XSLT templates that need to work generically with different element types.

## Contents

- [Node Identity and Properties](#node-identity-and-properties)
- [Name Functions](#name-functions)
- [Namespace Functions](#namespace-functions)
- [Document Access](#document-access)

---

## Node Identity and Properties

### root()

Returns the root node (document node) of the tree containing a given node.

**Signature:** `root($node as node()?) as node()?`

```xpath
root()                    => the document node of the context node
root(//item[1])           => the document node containing that item
```

**C# equivalent:** `node.Document` in LINQ to XML

---

### base-uri()

Returns the base URI of a node, used for resolving relative URIs.

**Signature:** `base-uri($node as node()?) as xs:anyURI?`

```xpath
base-uri()                => base URI of the context node
base-uri(/order)          => base URI of the order element
```

**C# equivalent:** `node.BaseUri` in LINQ to XML

---

### document-uri()

Returns the URI of the document containing a node.

**Signature:** `document-uri($node as node()?) as xs:anyURI?`

```xpath
document-uri(/)           => URI of the current document
```

---

### data()

Returns the typed value of a node or sequence of nodes.

**Signature:** `data($values as item()*) as xs:anyAtomicType*`

```xpath
data(//price)             => sequence of price values (typed if schema-aware)
data(@id)                 => the id attribute's value
```

**C# equivalent:** `element.Value` in LINQ to XML

---

## Name Functions

### name()

Returns the qualified name of a node as a string (including prefix if present).

**Signature:** `name($node as node()?) as xs:string`

```xpath
(: Given <xsl:template match="/"> :)
name(.)   => "xsl:template"
```

**C# equivalent:** `element.Name.ToString()` in LINQ to XML (though LINQ to XML uses `{namespace}local` format)

---

### local-name()

Returns the local part of a node's name, without the namespace prefix.

**Signature:** `local-name($node as node()?) as xs:string`

```xpath
(: Given <xsl:template match="/"> :)
local-name(.)   => "template"

(: Given <order id="123"> :)
local-name()    => "order"
local-name(@id) => "id"
```

**C# equivalent:** `element.Name.LocalName`

---

### namespace-uri()

Returns the namespace URI of a node.

**Signature:** `namespace-uri($node as node()?) as xs:anyURI`

```xpath
(: Given <xsl:template xmlns:xsl="http://www.w3.org/1999/XSL/Transform"> :)
namespace-uri(.)   => "http://www.w3.org/1999/XSL/Transform"

(: Given <order> with no namespace :)
namespace-uri()    => ""
```

**C# equivalent:** `element.Name.NamespaceName`

---

### node-name()

Returns the name of a node as an `xs:QName` (qualified name with namespace).

**Signature:** `node-name($node as node()?) as xs:QName?`

```xpath
node-name(//order)   => QName for "order"
```

**Difference from `name()`:** `node-name()` returns a typed QName (with namespace URI), while `name()` returns a string. Use `node-name()` when you need to compare names programmatically; use `name()` for display.

---

## Namespace Functions

### in-scope-prefixes()

Returns all namespace prefixes in scope for an element.

**Signature:** `in-scope-prefixes($element as element()) as xs:string*`

```xpath
(: Given <order xmlns:ship="http://example.com/shipping"> :)
in-scope-prefixes(.)   => ("xml", "ship")
```

---

### namespace-uri-for-prefix()

Returns the namespace URI bound to a prefix on a given element.

**Signature:** `namespace-uri-for-prefix($prefix as xs:string?, $element as element()) as xs:anyURI?`

```xpath
namespace-uri-for-prefix("ship", /order)
=> "http://example.com/shipping"
```

---

## Document Access

### doc()

Loads and returns a document from a URI.

**Signature:** `doc($uri as xs:string?) as document-node()?`

```xpath
doc("catalog.xml")                        => loads catalog.xml
doc("catalog.xml")//book                  => all books in catalog.xml
doc("https://example.com/data.xml")/root  => load from URL
```

**C# equivalent:** `XDocument.Load("catalog.xml")`

**Common XSLT pattern** — joining data from multiple documents:
```xpath
for $id in //order/product-id
return doc("products.xml")//product[@id = $id]/name
```

---

### doc-available()

Tests whether a document can be loaded without actually loading it.

**Signature:** `doc-available($uri as xs:string?) as xs:boolean`

```xpath
if (doc-available("config.xml"))
then doc("config.xml")/config/setting
else "default"
```

---

### collection()

Returns a sequence of documents from a named collection.

**Signature:** `collection($uri as xs:string?) as node()*`

```xpath
collection("my-docs")//title    => all titles from all documents in the collection
```

**Note:** The meaning of collection URIs is implementation-defined. In PhoenixmlDb, collections map to database containers.
