---
title: Path Expressions
description: Navigate XML trees with XPath path expressions, axes, and predicates
sort: 1
---

# Path Expressions

Path expressions are the core of XPath. A path expression navigates the
document tree through a series of steps separated by `/`.

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

> For C# developers: several XPath constructs mirror LINQ to XML methods.
> `//` resembles `Descendants()`. A predicate in brackets resembles a
> `.Where()` call. The `|` operator resembles `.Union()`. It also preserves
> document order, which `.Union()` does not guarantee.

## Descendant Shortcut: `//`

`//` selects descendants at any depth:

```
//title        => every <title> element in the document
//book/title   => every <title> that is a child of a <book>, at any depth
```

Use `//` sparingly in large documents. It searches the entire subtree.

## Predicates: Filtering

Square brackets filter the selected nodes:

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

This selects programming books under $50.

## Attributes: `@`

The `@` prefix selects attributes:

```
/catalog/book/@isbn        => all isbn attributes
/catalog/book/@category    => all category attributes
```

## Axes: Navigating in Every Direction

By default, XPath navigates to **children**. The tree has other
relationships. Axes select nodes along any of these relationships.

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

A wildcard selects nodes at a step without naming them:

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

The combined result preserves document order.

## Putting It Together

This example selects the titles of books published after 2010 with a price
in USD:

```xpath
/catalog/book[published > '2010-01-01']
             [price/@currency='USD']
             /title
```

The first predicate filters by publication date. The second predicate
filters by currency. The final step returns the title of each remaining
book.
