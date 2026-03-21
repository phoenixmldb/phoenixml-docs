---
title: Merging
description: "xsl:merge — combining multiple sorted input sources into a single output"
sort: 13
---

# Merging

`xsl:merge` (XSLT 3.0) combines multiple pre-sorted input sources into a single sorted output. If you have ever written a merge-sort or joined two sorted lists in C#, the concept is the same — except XSLT gives you a declarative way to express it.

## Contents

- [Why Merge?](#why-merge)
- [xsl:merge — Structure Overview](#xslmerge--structure-overview)
- [xsl:merge-source — Defining Inputs](#xslmerge-source--defining-inputs)
- [xsl:merge-key — Defining Sort Keys](#xslmerge-key--defining-sort-keys)
- [xsl:merge-action — Processing Matched Groups](#xslmerge-action--processing-matched-groups)
- [Complete Examples](#complete-examples)
- [Comparison with for-each-group](#comparison-with-for-each-group)

---

## Why Merge?

Consider these real-world scenarios:

- **Log aggregation:** Three servers each produce a timestamped log file. You need a single combined log sorted by timestamp.
- **Data feeds:** A product catalog arrives from multiple suppliers, each sorted by SKU. You need a merged catalog.
- **Master-detail joins:** An orders file and a customers file are both sorted by customer ID. You need to join them.

In C#, you might solve these with LINQ's `Join` or by manually interleaving sorted enumerables:

```csharp
// C# merge of two sorted lists by key
var merged = listA
    .Concat(listB)
    .OrderBy(x => x.Timestamp);

// Or for a true merge-join:
var joined = from order in orders
             join customer in customers on order.CustomerId equals customer.Id
             select new { order, customer };
```

The XSLT `xsl:merge` instruction does the same thing declaratively, and it can process inputs in a streaming fashion — meaning it never needs to hold the entire dataset in memory.

---

## xsl:merge — Structure Overview

Every merge has three parts:

1. **`xsl:merge-source`** — one or more input sources, each already sorted (or sorted on the fly)
2. **`xsl:merge-key`** — the key(s) used to align records across sources
3. **`xsl:merge-action`** — what to produce for each group of records that share the same key

```xml
<xsl:merge>
  <!-- One or more merge sources -->
  <xsl:merge-source name="source1" ...>
    <xsl:merge-key .../>
  </xsl:merge-source>

  <xsl:merge-source name="source2" ...>
    <xsl:merge-key .../>
  </xsl:merge-source>

  <!-- Action for each group of matching records -->
  <xsl:merge-action>
    <!-- Use current-merge-group() and current-merge-key() here -->
  </xsl:merge-action>
</xsl:merge>
```

The processor walks through all sources in parallel, advancing through each source based on the merge key order. When records from different sources share the same key value, they are grouped together and handed to `xsl:merge-action`.

---

## xsl:merge-source — Defining Inputs

Each `xsl:merge-source` defines one input to the merge. It has two selection mechanisms:

### for-each-source and for-each-item

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `for-each-source` | Selects documents or collections to iterate over | `for-each-source="collection('logs/')"` |
| `for-each-item` | Selects items within each source document | `for-each-item="log/entry"` |
| `select` | Selects items when there is a single source | `select="doc('orders.xml')//order"` |

When you have a single document, use `select`:

```xml
<xsl:merge-source name="orders"
                  select="doc('orders.xml')//order">
  <xsl:merge-key select="@customer-id" order="ascending"/>
</xsl:merge-source>
```

When you have multiple documents (a collection), use `for-each-source` and `for-each-item`:

```xml
<xsl:merge-source name="logs"
                  for-each-source="collection('server-logs/')"
                  for-each-item="log/entry">
  <xsl:merge-key select="@timestamp" order="ascending"/>
</xsl:merge-source>
```

**C# parallel:** `for-each-source` is like iterating over files in a directory, and `for-each-item` is like selecting records within each file:

```csharp
var entries = Directory.GetFiles("server-logs/")
    .SelectMany(file => LoadXml(file).Descendants("entry"));
```

### sort-before-merge

By default, `xsl:merge` assumes each source is already sorted by the merge key. If a source is not pre-sorted, set `sort-before-merge="yes"`:

```xml
<xsl:merge-source name="unsorted-data"
                  select="doc('raw-data.xml')//record"
                  sort-before-merge="yes">
  <xsl:merge-key select="@id" order="ascending" data-type="number"/>
</xsl:merge-source>
```

When `sort-before-merge="yes"`, the processor sorts the items from that source before beginning the merge. This is convenient but loses the streaming advantage — the entire source must be loaded into memory for sorting.

### The name Attribute

Each source can optionally have a `name`. This lets you distinguish which source a record came from inside the `xsl:merge-action`:

```xml
<xsl:merge-source name="customers" select="doc('customers.xml')//customer">
  <xsl:merge-key select="@id"/>
</xsl:merge-source>

<xsl:merge-source name="orders" select="doc('orders.xml')//order">
  <xsl:merge-key select="@customer-id"/>
</xsl:merge-source>
```

Inside the action, `current-merge-group('customers')` returns only the records from the customers source, and `current-merge-group('orders')` returns only the records from the orders source.

---

## xsl:merge-key — Defining Sort Keys

`xsl:merge-key` declares the key expression and comparison rules. It appears inside each `xsl:merge-source` and describes how that source is sorted.

### Attributes

| Attribute | Values | Default | Description |
|-----------|--------|---------|-------------|
| `select` | XPath expression | required | The key expression evaluated for each item |
| `order` | `ascending`, `descending` | `ascending` | Sort direction |
| `data-type` | `text`, `number` | `text` | Comparison type |
| `collation` | URI | Default collation | String comparison rules |
| `lang` | Language code | System default | Language for collation |

### Multiple Merge Keys

Like `xsl:sort`, you can have multiple `xsl:merge-key` elements for compound keys. They are evaluated in order — the first is the primary key, the second is the tiebreaker:

```xml
<xsl:merge-source name="transactions"
                  select="doc('transactions.xml')//transaction">
  <xsl:merge-key select="@date" order="ascending"/>
  <xsl:merge-key select="@time" order="ascending"/>
</xsl:merge-source>
```

### Key Compatibility

All merge sources must have compatible merge keys — the same number of `xsl:merge-key` elements with compatible types and sort orders. If source A is sorted ascending by date and source B is sorted descending by date, the merge will not produce correct results.

---

## xsl:merge-action — Processing Matched Groups

`xsl:merge-action` is the body of the merge — it runs once for each distinct merge key value found across all sources. Inside it, two functions are available:

### current-merge-group()

Returns all records from all sources that match the current merge key. Optionally, pass a source name to get only the records from that source:

| Call | Returns |
|------|---------|
| `current-merge-group()` | All records matching the current key, from all sources |
| `current-merge-group('orders')` | Only records from the source named "orders" |

### current-merge-key()

Returns the current merge key value. If there are multiple merge keys, it returns a sequence of values.

### Example

```xml
<xsl:merge-action>
  <customer id="{current-merge-key()}">
    <name>
      <xsl:value-of select="current-merge-group('customers')/name"/>
    </name>
    <orders>
      <xsl:for-each select="current-merge-group('orders')">
        <order date="{@date}" total="{@total}"/>
      </xsl:for-each>
    </orders>
  </customer>
</xsl:merge-action>
```

---

## Complete Examples

### Merging Log Files from Multiple Servers

Three servers produce log files, each sorted by timestamp. We merge them into a single chronological log.

Input — `server1.xml`:

```xml
<log server="web-01">
  <entry timestamp="2025-03-15T08:00:12" level="INFO">Server started</entry>
  <entry timestamp="2025-03-15T08:05:30" level="WARN">High memory usage</entry>
  <entry timestamp="2025-03-15T08:12:45" level="ERROR">Connection timeout</entry>
</log>
```

Input — `server2.xml`:

```xml
<log server="web-02">
  <entry timestamp="2025-03-15T08:01:05" level="INFO">Server started</entry>
  <entry timestamp="2025-03-15T08:07:22" level="INFO">Cache refreshed</entry>
  <entry timestamp="2025-03-15T08:10:00" level="ERROR">Disk full</entry>
</log>
```

Stylesheet:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/">
    <merged-log>
      <xsl:merge>
        <xsl:merge-source name="s1"
                          select="doc('server1.xml')/log/entry">
          <xsl:merge-key select="@timestamp" order="ascending"/>
        </xsl:merge-source>

        <xsl:merge-source name="s2"
                          select="doc('server2.xml')/log/entry">
          <xsl:merge-key select="@timestamp" order="ascending"/>
        </xsl:merge-source>

        <xsl:merge-action>
          <xsl:for-each select="current-merge-group()">
            <entry timestamp="{@timestamp}"
                   level="{@level}"
                   server="{ancestor::log/@server}">
              <xsl:value-of select="."/>
            </entry>
          </xsl:for-each>
        </xsl:merge-action>
      </xsl:merge>
    </merged-log>
  </xsl:template>

</xsl:stylesheet>
```

Output (entries interleaved chronologically):

```xml
<merged-log>
  <entry timestamp="2025-03-15T08:00:12" level="INFO" server="web-01">Server started</entry>
  <entry timestamp="2025-03-15T08:01:05" level="INFO" server="web-02">Server started</entry>
  <entry timestamp="2025-03-15T08:05:30" level="WARN" server="web-01">High memory usage</entry>
  <entry timestamp="2025-03-15T08:07:22" level="INFO" server="web-02">Cache refreshed</entry>
  <entry timestamp="2025-03-15T08:10:00" level="ERROR" server="web-02">Disk full</entry>
  <entry timestamp="2025-03-15T08:12:45" level="ERROR" server="web-01">Connection timeout</entry>
</merged-log>
```

### Master-Detail Join: Customers and Orders

Two files sorted by customer ID — merge them into a combined view.

Input — `customers.xml`:

```xml
<customers>
  <customer id="C001"><name>Alice Johnson</name><tier>Gold</tier></customer>
  <customer id="C002"><name>Bob Smith</name><tier>Silver</tier></customer>
  <customer id="C003"><name>Carol Williams</name><tier>Bronze</tier></customer>
</customers>
```

Input — `orders.xml`:

```xml
<orders>
  <order customer-id="C001" date="2025-01-15" total="299.99"/>
  <order customer-id="C001" date="2025-02-20" total="149.50"/>
  <order customer-id="C002" date="2025-01-22" total="75.00"/>
  <order customer-id="C003" date="2025-03-01" total="520.00"/>
  <order customer-id="C003" date="2025-03-10" total="89.99"/>
  <order customer-id="C003" date="2025-03-12" total="200.00"/>
</orders>
```

Stylesheet:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:output method="xml" indent="yes"/>

  <xsl:template match="/">
    <customer-orders>
      <xsl:merge>
        <xsl:merge-source name="customers"
                          select="doc('customers.xml')/customers/customer">
          <xsl:merge-key select="@id" order="ascending"/>
        </xsl:merge-source>

        <xsl:merge-source name="orders"
                          select="doc('orders.xml')/orders/order">
          <xsl:merge-key select="@customer-id" order="ascending"/>
        </xsl:merge-source>

        <xsl:merge-action>
          <xsl:variable name="cust" select="current-merge-group('customers')"/>
          <xsl:variable name="ords" select="current-merge-group('orders')"/>

          <customer id="{current-merge-key()}"
                    name="{$cust/name}"
                    tier="{$cust/tier}"
                    order-count="{count($ords)}"
                    total-spent="{format-number(sum($ords/@total), '#,##0.00')}">
            <xsl:for-each select="$ords">
              <order date="{@date}" total="{@total}"/>
            </xsl:for-each>
          </customer>
        </xsl:merge-action>
      </xsl:merge>
    </customer-orders>
  </xsl:template>

</xsl:stylesheet>
```

Output:

```xml
<customer-orders>
  <customer id="C001" name="Alice Johnson" tier="Gold"
            order-count="2" total-spent="449.49">
    <order date="2025-01-15" total="299.99"/>
    <order date="2025-02-20" total="149.50"/>
  </customer>
  <customer id="C002" name="Bob Smith" tier="Silver"
            order-count="1" total-spent="75.00">
    <order date="2025-01-22" total="75.00"/>
  </customer>
  <customer id="C003" name="Carol Williams" tier="Bronze"
            order-count="3" total-spent="809.99">
    <order date="2025-03-01" total="520.00"/>
    <order date="2025-03-10" total="89.99"/>
    <order date="2025-03-12" total="200.00"/>
  </customer>
</customer-orders>
```

**C# parallel:**

```csharp
var result = from cust in customers
             join order in orders on cust.Id equals order.CustomerId into custOrders
             select new {
                 cust.Id,
                 cust.Name,
                 cust.Tier,
                 OrderCount = custOrders.Count(),
                 TotalSpent = custOrders.Sum(o => o.Total),
                 Orders = custOrders.ToList()
             };
```

### Merging Sorted Data Feeds with Collections

When log files are in a directory, use `for-each-source` with a collection:

```xml
<xsl:merge>
  <xsl:merge-source name="all-logs"
                    for-each-source="collection('logs/?select=*.xml')"
                    for-each-item="log/entry">
    <xsl:merge-key select="@timestamp" order="ascending"/>
  </xsl:merge-source>

  <xsl:merge-action>
    <xsl:for-each select="current-merge-group()">
      <entry timestamp="{@timestamp}" level="{@level}">
        <xsl:value-of select="."/>
      </entry>
    </xsl:for-each>
  </xsl:merge-action>
</xsl:merge>
```

This pattern handles any number of log files without listing them individually.

---

## Comparison with for-each-group

Both `xsl:merge` and `xsl:for-each-group group-by` can combine records by a shared key. The choice depends on your data.

| | `xsl:for-each-group group-by` | `xsl:merge` |
|---|---|---|
| **Input assumption** | Any order | Pre-sorted by key |
| **Memory** | Must hold all items to find groups | Streams through sorted inputs |
| **Multiple sources** | Must combine first, then group | Handles multiple sources natively |
| **Efficiency** | O(n) with hash grouping | O(n) merge of sorted inputs |
| **Best for** | Unsorted data, single source | Pre-sorted data, multiple sources, large datasets |

### When to Use merge

- Your inputs are already sorted (log files with timestamps, database exports with IDs)
- You have multiple source documents
- The data is too large to load entirely into memory (streaming)
- You are performing a join between two datasets by a common key

### When to Use for-each-group

- Your data is not sorted, or the sort order does not match the grouping key
- You have a single source document
- The data fits in memory
- You need one of the four grouping modes (group-by, group-adjacent, group-starting-with, group-ending-with)

### Side-by-Side Comparison

Grouping approach (data not pre-sorted):

```xml
<xsl:for-each-group select="collection('feeds/')//product" group-by="@sku">
  <product sku="{current-grouping-key()}">
    <xsl:for-each select="current-group()">
      <source supplier="{ancestor::feed/@supplier}" price="{@price}"/>
    </xsl:for-each>
  </product>
</xsl:for-each-group>
```

Merge approach (each feed is sorted by SKU):

```xml
<xsl:merge>
  <xsl:merge-source for-each-source="collection('feeds/')"
                    for-each-item="feed/product">
    <xsl:merge-key select="@sku" order="ascending"/>
  </xsl:merge-source>

  <xsl:merge-action>
    <product sku="{current-merge-key()}">
      <xsl:for-each select="current-merge-group()">
        <source supplier="{ancestor::feed/@supplier}" price="{@price}"/>
      </xsl:for-each>
    </product>
  </xsl:merge-action>
</xsl:merge>
```

Both produce the same result, but the merge version can process arbitrarily large feeds without holding them all in memory.
