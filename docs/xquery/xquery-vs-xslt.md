---
title: XQuery vs XSLT
description: When to use XQuery and when to use XSLT — a practical decision guide
sort: 4
---

# XQuery vs XSLT

XQuery and XSLT overlap significantly. Both can query XML, both can produce output, and both use XPath for navigation. This page helps you choose the right tool for each job.

## The Short Answer

| Task | Prefer |
|------|--------|
| Transform a document from one format to another | **XSLT** |
| Query a database or document collection | **XQuery** |
| Generate HTML from XML data | **Either** (XSLT for template-heavy, XQuery for data-heavy) |
| Build new XML documents from queries | **XQuery** |
| Apply the same transform to many documents | **XSLT** |
| Ad-hoc data exploration | **XQuery** |
| Identity transform with targeted changes | **XSLT** |
| Join data across multiple documents | **XQuery** |

## Paradigm Difference

The fundamental difference is in how you think about the problem:

**XSLT** is **rule-based and declarative**. You write template rules that match patterns in the input document. The engine walks the tree and fires rules. You don't control the traversal — you control what happens when a pattern matches.

```xml
<!-- XSLT: "When you see a product, render it like this" -->
<xsl:template match="product">
  <div class="card">
    <h2><xsl:value-of select="name"/></h2>
    <p>$<xsl:value-of select="price"/></p>
  </div>
</xsl:template>
```

**XQuery** is **expression-based and procedural** (in a functional sense). You write queries that select, filter, transform, and construct. You control the flow explicitly.

```xquery
(: XQuery: "Select products and build cards from them" :)
for $p in //product
return <div class="card">
  <h2>{ $p/name/text() }</h2>
  <p>${ $p/price/text() }</p>
</div>
```

**C# analogy:** XSLT is like event handlers (you register what should happen when something occurs). XQuery is like LINQ (you write the query that produces the result).

## Strengths Comparison

### Where XSLT Excels

**Document-centric transforms.** When you're converting one XML format to another and the output structure closely mirrors the input structure, XSLT's template matching handles this naturally:

```xml
<!-- Copy everything, change just the price format -->
<xsl:mode on-no-match="shallow-copy"/>

<xsl:template match="price">
  <price formatted="true">
    $<xsl:value-of select="format-number(., '#,##0.00')"/>
  </price>
</xsl:template>
```

In XQuery, you'd have to explicitly reconstruct the entire document tree to change one element.

**Multiple output documents.** XSLT's `xsl:result-document` can generate many output files from a single input — ideal for static site generation, batch PDF creation, or splitting large documents.

**Reusable template libraries.** XSLT's import/include mechanism with priority-based override is well-suited to building theme systems and customizable document pipelines.

**Streaming.** XSLT 3.0 supports streaming transformations for very large documents that don't fit in memory.

### Where XQuery Excels

**Database queries.** XQuery was designed as a query language for XML databases. It's the SQL of the XML world:

```xquery
for $order in collection("orders")//order
where $order/@date > xs:date("2026-01-01")
  and $order/total > 1000
order by $order/total descending
return $order
```

**Cross-document joins.** XQuery naturally joins data from multiple sources:

```xquery
for $order in doc("orders.xml")//order
let $customer := doc("customers.xml")//customer[@id = $order/@customer-id]
return <summary>
  <order-id>{ string($order/@id) }</order-id>
  <customer>{ $customer/name/text() }</customer>
  <total>{ $order/total/text() }</total>
</summary>
```

**Ad-hoc analysis.** XQuery expressions can be written interactively (REPL-style) for exploring data:

```xquery
(: Quick analysis — no boilerplate needed :)
let $orders := doc("orders.xml")//order
return map {
  "count": count($orders),
  "total": sum($orders/total),
  "avg": avg($orders/total),
  "top-customer": (
    for $cid in distinct-values($orders/@customer-id)
    let $customer-total := sum($orders[@customer-id = $cid]/total)
    order by $customer-total descending
    return $cid
  )[1]
}
```

**Constructing new documents.** XQuery's constructor syntax is more natural for building complex XML from scratch:

```xquery
<report generated="{ current-dateTime() }">
  {
    for $category in distinct-values(//product/@category)
    let $products := //product[@category = $category]
    return <section name="{ $category }">
      <stats count="{ count($products) }" avg-price="{ avg($products/price) }"/>
      { $products }
    </section>
  }
</report>
```

## They Share XPath

Both languages use XPath 3.1/4.0 for navigation and expression evaluation. All XPath functions, operators, and data types work identically in both. This means:

- Knowledge of XPath transfers directly to both languages
- You can use the same navigation expressions in XSLT match patterns and XQuery FLWOR clauses
- Function libraries (string, numeric, date, sequence) are identical

## Using Them Together

In practice, you often use both:

1. **XQuery** to select and prepare data from a database or document collection
2. **XSLT** to transform the prepared data into the final output format

Example pipeline:
```
XML Database → XQuery (select + join + aggregate) → intermediate XML → XSLT (→ HTML)
```

This is exactly what PhoenixmlDb enables — XQuery for database operations, XSLT for rendering.

## Decision Framework

Ask these questions:

**1. Are you transforming a document or querying data?**
- Transforming → XSLT
- Querying → XQuery

**2. Does the output closely mirror the input structure?**
- Yes (most nodes copied, few changes) → XSLT (identity transform pattern)
- No (different structure, aggregation, joins) → XQuery

**3. Do you need multiple output files?**
- Yes → XSLT (`xsl:result-document`)
- No → Either

**4. Is the input from a database or collection?**
- Database/collection → XQuery
- Single document or known set → Either

**5. Do you need reusable, overridable templates?**
- Yes → XSLT (import/include with priority override)
- No → Either

**6. Are you doing ad-hoc exploration?**
- Yes → XQuery (less boilerplate)
- No → Depends on the task

## The .NET Developer's Perspective

If you're coming from C#:

- **XQuery** will feel more natural initially — it's expression-based like LINQ, with explicit control flow
- **XSLT** requires a paradigm shift to declarative, rule-based thinking — but once it clicks, it's more powerful for document-centric work
- **Learn XPath first** — it's the foundation for both
- **Start with XQuery** for data queries and exploration
- **Move to XSLT** when you need document transformation, multi-output generation, or template-based rendering

Both are valuable tools. The best .NET developers working with XML will use both, choosing the right one for each task.
