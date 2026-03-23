---
title: "Streaming and Accumulators"
description: "xsl:source-document, xsl:accumulator, xsl:fork — processing large documents efficiently"
sort: 15
---

# Streaming and Accumulators

When a document is too large to fit in memory — tens of gigabytes of log data, massive data exports, or continuous feeds — XSLT 3.0's streaming features let you process it in a single pass without building the entire tree. If you have worked with `IAsyncEnumerable`, `Utf8JsonReader`, or `System.IO.Pipelines` in C#, the motivation is the same: process data as it flows through, never holding more than a small window in memory.

## Contents

- [The Streaming Concept](#the-streaming-concept)
- [xsl:source-document](#xslsource-document)
- [xsl:accumulator and xsl:accumulator-rule](#xslaccumulator-and-xslaccumulator-rule)
- [xsl:fork](#xslfork)
- [Streamability Rules](#streamability-rules)
- [use-accumulators on Modes](#use-accumulators-on-modes)

---

## Primary Source Streaming

The simplest way to enable streaming is to declare a streamable mode for the primary input document. When the default mode (or a named mode) is streamable, the XSLT processor reads the principal source document through an XmlReader rather than building a full in-memory tree:

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <!-- Stream the primary source document -->
  <xsl:mode streamable="yes"/>

  <xsl:template match="/">
    <summary>
      <xsl:apply-templates select="catalog/product"/>
    </summary>
  </xsl:template>

  <xsl:template match="product">
    <item name="{@name}" price="{@price}"/>
  </xsl:template>

</xsl:stylesheet>
```

With `xsl:mode streamable="yes"` on the unnamed (default) mode, the initial `apply-templates` call reads the input document as a stream. No tree is built for the primary source.

### Detecting Streaming Support

You can check at compile time whether the processor supports streaming:

```xml
<xsl:if test="system-property('xsl:supports-streaming') = 'yes'">
  <!-- streaming-specific logic -->
</xsl:if>
```

`system-property('xsl:supports-streaming')` returns `"yes"` in PhoenixmlDb.

---

## The Streaming Concept

In conventional (non-streaming) XSLT processing, the entire input document is parsed into an in-memory tree before any templates execute. This is fine for documents up to a few hundred megabytes, but fails for larger documents.

Streaming changes the execution model: the processor reads the document as a stream of events (start-element, text, end-element) and executes templates as each node passes by. At any point, only the current node and its ancestors are in memory.

### When You Need Streaming

- The document is too large for available memory (multi-gigabyte XML exports)
- You want to start producing output before the entire input is read
- You are processing a continuous feed that never ends
- You want to minimize memory footprint even for moderate-sized documents

### When You Do Not Need Streaming

- Documents fit comfortably in memory (most XML files)
- You need random access to the document (looking backward or forward freely)
- The transformation requires multiple passes over the same data

**C# parallel:** The same trade-off exists in .NET. `XmlDocument` or `XDocument` loads everything into memory (like non-streaming XSLT). `XmlReader` and `Utf8JsonReader` stream through the data, but you lose the ability to navigate freely:

```csharp
// Non-streaming: full tree in memory
var doc = XDocument.Load("huge-file.xml");
var items = doc.Descendants("item").Where(x => ...);

// Streaming: one node at a time
using var reader = XmlReader.Create("huge-file.xml");
while (reader.Read())
{
    if (reader.NodeType == XmlNodeType.Element && reader.Name == "item")
    {
        // Process one item at a time
    }
}
```

XSLT streaming gives you the memory efficiency of `XmlReader` with the declarative power of templates.

---

## xsl:source-document

`xsl:source-document` (XSLT 3.0) loads an external document, optionally in streaming mode. It replaces the `doc()` function when you need streaming access.

### Basic Usage

```xml
<!-- Non-streaming (same as doc()) -->
<xsl:source-document href="data.xml">
  <xsl:apply-templates select="./catalog/product"/>
</xsl:source-document>

<!-- Streaming mode -->
<xsl:source-document href="huge-data.xml" streamable="yes">
  <xsl:apply-templates select="./catalog/product" mode="streaming"/>
</xsl:source-document>
```

### Attributes

| Attribute | Values | Description |
|-----------|--------|-------------|
| `href` | URI | The document to load |
| `streamable` | `yes`, `no` | Whether to process the document as a stream |
| `use-accumulators` | Space-separated list of accumulator names | Which accumulators to apply to this document |
| `validation` | `strict`, `lax`, `preserve`, `strip` | Schema validation mode |

### Streaming Example: Extracting from a Large File

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">

  <xsl:mode name="streaming" streamable="yes"/>

  <xsl:template match="/">
    <summary>
      <xsl:source-document href="transactions.xml" streamable="yes">
        <xsl:apply-templates select="./transactions/transaction" mode="streaming"/>
      </xsl:source-document>
    </summary>
  </xsl:template>

  <xsl:template match="transaction[@amount > 10000]" mode="streaming">
    <large-transaction id="{@id}" amount="{@amount}" date="{@date}"/>
  </xsl:template>

  <!-- Skip transactions under the threshold -->
  <xsl:template match="transaction" mode="streaming"/>

</xsl:stylesheet>
```

This stylesheet reads a potentially enormous transactions file and outputs only those exceeding $10,000, without ever loading the whole file into memory.

### Replacing doc() with xsl:source-document

The `doc()` function always builds a full in-memory tree. If you are migrating to streaming, replace `doc()` calls with `xsl:source-document`:

```xml
<!-- Before: non-streaming -->
<xsl:variable name="data" select="doc('large-file.xml')"/>
<xsl:for-each select="$data//record">
  <!-- ... -->
</xsl:for-each>

<!-- After: streaming -->
<xsl:source-document href="large-file.xml" streamable="yes">
  <xsl:for-each select="./records/record">
    <!-- ... -->
  </xsl:for-each>
</xsl:source-document>
```

Note the change from `$data//record` (using the `//` descendant axis, which requires random access) to `./records/record` (a direct child path, which is streamable).

---

## xsl:accumulator and xsl:accumulator-rule

Accumulators maintain running state as the processor streams through a document. They solve the problem that streaming templates cannot look backward — once a node has passed, it is gone. An accumulator watches the stream and updates a value as each matching node passes by.

**C# parallel:** Think of accumulators like `Aggregate()` over an `IAsyncEnumerable`, or like registering callbacks on a SAX parser that update shared state:

```csharp
decimal runningTotal = 0;
int count = 0;

await foreach (var transaction in streamReader.ReadTransactionsAsync())
{
    runningTotal += transaction.Amount;
    count++;
}
```

### Declaring an Accumulator

Accumulators are top-level declarations (children of `xsl:stylesheet`):

```xml
<xsl:accumulator name="total-amount"
                 as="xs:decimal"
                 initial-value="0"
                 streamable="yes">
  <xsl:accumulator-rule match="transaction"
                        phase="end"
                        select="$value + xs:decimal(@amount)"/>
</xsl:accumulator>
```

### Accumulator Parts

| Part | Description |
|------|-------------|
| `name` | Unique name for the accumulator |
| `as` | Data type of the accumulated value |
| `initial-value` | Starting value before any nodes are processed |
| `streamable` | Whether this accumulator is used in streaming mode |
| `xsl:accumulator-rule` | One or more rules that update the value |

### xsl:accumulator-rule

Each rule specifies when and how to update the accumulated value:

| Attribute | Description |
|-----------|-------------|
| `match` | Pattern — which nodes trigger this rule |
| `phase` | `start` or `end` — fire when the element opens or closes |
| `select` | New value expression (can reference `$value` for current accumulated value) |
| `new-value` | Alternative to `select` for complex computation |

### Phase: start vs. end

- **`start`** — fires when the opening tag is encountered. At this point, the element's attributes are available, but child content has not been read yet.
- **`end`** — fires when the closing tag is encountered. At this point, the element's text content has been read (but not stored in memory).

```xml
<!-- Count elements as they open -->
<xsl:accumulator name="element-count"
                 as="xs:integer"
                 initial-value="0"
                 streamable="yes">
  <xsl:accumulator-rule match="transaction" phase="start"
                        select="$value + 1"/>
</xsl:accumulator>
```

### Reading Accumulator Values

Two functions retrieve the accumulated value at any point during processing:

| Function | Description |
|----------|-------------|
| `accumulator-before('name')` | Value of the accumulator before the current node was processed |
| `accumulator-after('name')` | Value of the accumulator after the current node was processed |

```xml
<xsl:template match="transaction" mode="streaming">
  <row>
    <number><xsl:value-of select="accumulator-after('element-count')"/></number>
    <amount><xsl:value-of select="@amount"/></amount>
    <running-total><xsl:value-of select="accumulator-after('total-amount')"/></running-total>
  </row>
</xsl:template>
```

### Complete Accumulator Example: Log File Statistics

```xml
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="3.0">

  <xsl:mode name="streaming" streamable="yes" use-accumulators="entry-count error-count max-response-time"/>
  <xsl:output method="xml" indent="yes"/>

  <!-- Count all entries -->
  <xsl:accumulator name="entry-count" as="xs:integer"
                   initial-value="0" streamable="yes">
    <xsl:accumulator-rule match="entry" phase="start"
                          select="$value + 1"/>
  </xsl:accumulator>

  <!-- Count error entries -->
  <xsl:accumulator name="error-count" as="xs:integer"
                   initial-value="0" streamable="yes">
    <xsl:accumulator-rule match="entry[@level='ERROR']" phase="start"
                          select="$value + 1"/>
  </xsl:accumulator>

  <!-- Track maximum response time -->
  <xsl:accumulator name="max-response-time" as="xs:decimal"
                   initial-value="0" streamable="yes">
    <xsl:accumulator-rule match="entry[@response-ms]" phase="start"
                          select="max(($value, xs:decimal(@response-ms)))"/>
  </xsl:accumulator>

  <xsl:template match="/">
    <xsl:source-document href="access-log.xml" streamable="yes">
      <xsl:apply-templates select="." mode="streaming"/>
    </xsl:source-document>
  </xsl:template>

  <xsl:template match="log" mode="streaming">
    <log-summary>
      <total-entries><xsl:value-of select="accumulator-after('entry-count')"/></total-entries>
      <error-entries><xsl:value-of select="accumulator-after('error-count')"/></error-entries>
      <max-response-time-ms><xsl:value-of select="accumulator-after('max-response-time')"/></max-response-time-ms>
    </log-summary>
  </xsl:template>

</xsl:stylesheet>
```

Input (`access-log.xml`, potentially gigabytes):

```xml
<log>
  <entry timestamp="2025-03-15T08:00:01" level="INFO" response-ms="45"/>
  <entry timestamp="2025-03-15T08:00:02" level="INFO" response-ms="120"/>
  <entry timestamp="2025-03-15T08:00:03" level="ERROR" response-ms="5023"/>
  <!-- ... millions more entries ... -->
</log>
```

Output:

```xml
<log-summary>
  <total-entries>3847291</total-entries>
  <error-entries>12847</error-entries>
  <max-response-time-ms>15234</max-response-time-ms>
</log-summary>
```

### Use Cases for Accumulators

| Use Case | Accumulator Pattern |
|----------|-------------------|
| Running total | `select="$value + @amount"` |
| Counting | `select="$value + 1"` |
| Maximum value | `select="max(($value, @val))"` |
| Minimum value | `select="if ($value = 0) then @val else min(($value, @val))"` |
| Context tracking | `select="@category"` (track the current section/category) |
| Last-seen value | `select="@id"` (remember the most recent ID) |
| Collecting distinct values | `select="distinct-values(($value, @type))"` |

### Context Tracking Accumulator

A powerful pattern: track which section you are in while streaming, so inner elements can reference the current section name without looking backward:

```xml
<xsl:accumulator name="current-section" as="xs:string"
                 initial-value="''" streamable="yes">
  <xsl:accumulator-rule match="section" phase="start"
                        select="string(@name)"/>
</xsl:accumulator>

<xsl:template match="entry" mode="streaming">
  <row section="{accumulator-before('current-section')}">
    <xsl:value-of select="@message"/>
  </row>
</xsl:template>
```

---

## xsl:fork

`xsl:fork` splits processing into independent branches that each consume the streamed document independently. Without `xsl:fork`, a streaming template can only make one downward pass through the children. With `xsl:fork`, you can process the same children in multiple ways simultaneously.

**C# parallel:** Think of `xsl:fork` like `Channel<T>` fan-out, or `tee` in Unix — one input stream split to multiple consumers:

```csharp
// Conceptually similar: multiple consumers of the same stream
var channel = Channel.CreateUnbounded<XmlNode>();
Task.WhenAll(
    ProcessErrors(channel.Reader),
    ComputeStats(channel.Reader),
    GenerateReport(channel.Reader)
);
```

### Basic Usage

```xml
<xsl:template match="log" mode="streaming">
  <report>
    <xsl:fork>
      <!-- Branch 1: extract errors -->
      <xsl:sequence>
        <errors>
          <xsl:apply-templates select="entry[@level='ERROR']" mode="streaming"/>
        </errors>
      </xsl:sequence>

      <!-- Branch 2: extract warnings -->
      <xsl:sequence>
        <warnings>
          <xsl:apply-templates select="entry[@level='WARN']" mode="streaming"/>
        </warnings>
      </xsl:sequence>

      <!-- Branch 3: count by for-each-group (if supported in streaming) -->
      <xsl:sequence>
        <summary>
          <xsl:for-each-group select="entry" group-by="@level">
            <level name="{current-grouping-key()}" count="{count(current-group())}"/>
          </xsl:for-each-group>
        </summary>
      </xsl:sequence>
    </xsl:fork>
  </report>
</xsl:template>
```

Each `xsl:sequence` inside `xsl:fork` is an independent branch. The processor feeds each branch from the same stream of events. The branches cannot communicate with each other, but they can each produce output that is concatenated in order.

### When to Use xsl:fork

Use `xsl:fork` when a single streaming pass needs to produce multiple independent outputs from the same data:

- Generating both a summary and detail view in one pass
- Writing to multiple result documents from the same streamed input
- Applying different filters to the same stream

Without `xsl:fork`, you would need multiple passes over the document (defeating the purpose of streaming) or would need to handle everything in a single set of templates.

---

## Streamability Rules

Not every XSLT stylesheet can be executed in streaming mode. The processor enforces streamability rules that ensure the transformation can work in a single forward pass.

### Core Principle

In streaming mode, a node is available only while the processor is "positioned" on it. Once the processor moves past a node, it is gone. This means:

- You can read **attributes** and **namespace nodes** of the current element (they arrive with the start tag)
- You can process **child nodes** in document order (one at a time, as they stream by)
- You **cannot** go backward (no preceding siblings, no ancestor's other children)
- You **cannot** read the same child node twice

### Consuming vs. Non-Consuming Operations

| Operation Type | Description | Examples |
|---------------|-------------|---------|
| **Non-consuming** | Reads data available without advancing the stream | `@attribute`, `name()`, `position()`, `accumulator-before()` |
| **Consuming** | Reads child content, advancing the stream | `string(.)`, `xsl:apply-templates`, `xsl:for-each select="child"` |

The key rule: **you can perform at most one consuming operation on any given node.** You cannot, for example, both `xsl:apply-templates` to the children and then `xsl:value-of select="."` on the same element — both consume the children.

### Grounded vs. Free-Ranging Expressions

- **Grounded expression:** Evaluates to a value without navigating through streamed content. Examples: `@id`, `$variable`, `position()`, literal values.
- **Free-ranging expression:** Navigates through descendant content. Examples: `.//item`, `string(.)`, `sum(item/price)`.

A streamable template can use one free-ranging expression (consuming the children), but everything else must be grounded.

### Making Templates Streamable

Here are common patterns and their streamable alternatives:

```xml
<!-- NOT STREAMABLE: uses descendant axis -->
<xsl:template match="catalog">
  <xsl:value-of select="count(.//product)"/>
</xsl:template>

<!-- STREAMABLE: use an accumulator instead -->
<xsl:accumulator name="product-count" as="xs:integer"
                 initial-value="0" streamable="yes">
  <xsl:accumulator-rule match="product" phase="start"
                        select="$value + 1"/>
</xsl:accumulator>

<xsl:template match="catalog" mode="streaming">
  <count><xsl:value-of select="accumulator-after('product-count')"/></count>
</xsl:template>
```

```xml
<!-- NOT STREAMABLE: reads children twice -->
<xsl:template match="product">
  <name><xsl:value-of select="name"/></name>
  <price><xsl:value-of select="price"/></price>
</xsl:template>

<!-- STREAMABLE: use copy-of or apply-templates (one consuming operation) -->
<xsl:template match="product" mode="streaming">
  <xsl:copy-of select="."/>
</xsl:template>

<!-- OR: use xsl:fork to split the processing -->
<xsl:template match="product" mode="streaming">
  <xsl:fork>
    <xsl:sequence>
      <name><xsl:value-of select="name"/></name>
    </xsl:sequence>
    <xsl:sequence>
      <price><xsl:value-of select="price"/></price>
    </xsl:sequence>
  </xsl:fork>
</xsl:template>
```

### Streamability Checklist

Before making a stylesheet streamable, verify:

1. Templates process children in document order only (no backward navigation)
2. Each template performs at most one consuming operation on the streamed input
3. Conditions and computations use only attributes, accumulators, or variables (not child content multiple times)
4. The `xsl:mode` declaration includes `streamable="yes"`
5. Accumulators are declared with `streamable="yes"`

---

## use-accumulators on Modes

For accumulators to fire during streaming, the mode must declare which accumulators it uses. This is a whitelist — unlisted accumulators are not evaluated, which saves processing time.

```xml
<!-- Declare a streamable mode with specific accumulators -->
<xsl:mode name="streaming"
          streamable="yes"
          use-accumulators="entry-count error-count max-response-time"/>
```

You can also use the `#all` token to enable all accumulators:

```xml
<xsl:mode name="streaming"
          streamable="yes"
          use-accumulators="#all"/>
```

And on `xsl:source-document`:

```xml
<xsl:source-document href="data.xml"
                     streamable="yes"
                     use-accumulators="record-count running-total">
  <xsl:apply-templates select="." mode="streaming"/>
</xsl:source-document>
```

### Why the Whitelist?

Evaluating accumulators has a cost — each accumulator-rule must be tested against every node in the stream. By declaring which accumulators a mode uses, the processor can skip unnecessary evaluations. This matters when streaming millions of nodes per second.

**C# parallel:** This is similar to subscribing to specific events rather than receiving all events:

```csharp
// Only subscribe to the events you need
stream.OnError += HandleError;
stream.OnLargeTransaction += TrackMaxAmount;
// Not subscribing to OnInfo saves processing time
```

---

## Streaming Limitations

While streaming enables processing of arbitrarily large documents, it imposes certain restrictions:

### `last()` is Not Available

In streaming mode, the processor does not know the total size of the sequence being iterated. The `last()` function — which returns the size of the current sequence — is therefore unavailable:

```xml
<!-- NOT AVAILABLE in streaming mode -->
<xsl:template match="item" mode="streaming">
  <xsl:if test="position() = last()">  <!-- ERROR: last() not supported -->
    <final-item/>
  </xsl:if>
</xsl:template>

<!-- WORKAROUND: use an accumulator to detect the last item after the fact,
     or restructure the logic to not depend on last() -->
```

If you need to know when you are processing the final item, consider using an accumulator to track state, or post-process the output.

### `xsl:fork` Executes Sequentially

Although `xsl:fork` is conceptually a parallel construct (splitting the stream to multiple consumers), in PhoenixmlDb the branches execute **sequentially**, not in parallel. Each branch processes the stream independently, but one at a time. The output of all branches is concatenated in document order.

This means `xsl:fork` is functionally correct — it produces the right output — but does not provide a parallelism performance benefit. It remains useful for structuring streaming stylesheets where multiple independent consuming operations are needed on the same streamed input.

### Other Restrictions

- **No backward navigation** — Axes like `preceding-sibling`, `preceding`, and `ancestor` content are not available (ancestor *names* and *attributes* are available via accumulators or `ancestor::*/name()`)
- **Single consuming operation per node** — Each template can perform at most one operation that reads child content
- **No `xsl:number` with `level="any"`** — This requires counting across the entire document, which is incompatible with streaming
