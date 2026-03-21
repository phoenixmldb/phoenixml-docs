---
title: Path Expressions
description: Navigate XML trees with XPath path expressions, axes, and predicates
sort: 1
---

# Path Expressions

Path expressions are the core of XPath. They navigate the document tree by following steps separated by `/`, much like file system paths.

## Basic Navigation

```
/            => the document root
/catalog     => the root element (if named "catalog")
/catalog/book => all <book> children of <catalog>
```

Each step selects a set of nodes. The next step runs from each selected node.

### The LINQ Parallel

| XPath | LINQ to XML |
|-------|-------------|
| `/catalog` | `doc.Root` |
| `/catalog/book` | `doc.Root.Elements("book")` |
| `/catalog/book/title` | `doc.Root.Elements("book").Elements("title")` |

## Descendant Shortcut: `//`

`//` selects descendants at any depth — like `Descendants()` in LINQ:

```
//title        => every <title> element in the document
//book/title   => every <title> that is a child of a <book>, at any depth
```

Use `//` sparingly in large documents — it searches the entire subtree.

## Predicates: Filtering

Square brackets filter the selected nodes, like `.Where()` in LINQ:

```
/catalog/book[1]                    => first book (XPath is 1-based!)
/catalog/book[last()]               => last book
/catalog/book[price > 40]           => books where price > 40
/catalog/book[@category='data']     => books with category attribute = "data"
/catalog/book[author='Bill Wagner'] => books by Bill Wagner
```

Predicates can be combined:

```
/catalog/book[@category='programming'][price < 50]
```

This selects programming books under $50 — equivalent to chaining `.Where()` calls.

## Attributes: `@`

The `@` prefix selects attributes:

```
/catalog/book/@isbn        => all isbn attributes
/catalog/book/@category    => all category attributes
```

## Axes: Navigating in Every Direction

By default, XPath navigates to **children**. But the tree has more relationships. Axes let you navigate in any direction:

| Axis | Direction | LINQ Equivalent |
|------|-----------|-----------------|
| `child::` | Children (default) | `.Elements()` |
| `parent::` | Parent | `.Parent` |
| `ancestor::` | All ancestors | `.Ancestors()` |
| `descendant::` | All descendants | `.Descendants()` |
| `following-sibling::` | Siblings after | `.ElementsAfterSelf()` |
| `preceding-sibling::` | Siblings before | `.ElementsBeforeSelf()` |
| `attribute::` | Attributes | `.Attributes()` |
| `self::` | The node itself | (identity) |

Most axes have shortcuts:

```
child::book     => book        (child is the default axis)
attribute::isbn => @isbn       (@ is shorthand for attribute::)
parent::*       => ..          (.. is shorthand for parent)
self::*         => .           (. is shorthand for self)
```

## Wildcards

```
/catalog/*       => all children of catalog (any element)
/catalog/book/@* => all attributes of book elements
//*/title        => title elements that are grandchildren of anything
```

## Combining Paths: Union

The `|` operator combines results from multiple paths:

```
//title | //author    => all title and author elements
```

Like LINQ's `.Union()` — but preserves document order.

## Putting It Together

A real-world example — find all books published after 2010 with a price in USD:

```xpath
/catalog/book[published > '2010-01-01']
             [price/@currency='USD']
             /title
```

This reads naturally: "from the catalog, select books published after 2010 with USD pricing, then get their titles."
