---
title: Advanced FLWOR
description: Window clauses, count, group by, while, otherwise — advanced FLWOR patterns
sort: 2
---

# Advanced FLWOR

The [basic FLWOR page](flwor.md) covers `for`, `let`, `where`, `order by`, and `return`. This page covers the clauses that make FLWOR a genuinely powerful data processing language: window clauses, count, group by, and the XQuery 4.0 additions `while` and `otherwise`.

## Contents

- [Window Clauses](#window-clauses)
- [Count Clause](#count-clause)
- [Group By Clause](#group-by-clause)
- [While Clause](#while-clause)
- [Otherwise Clause](#otherwise-clause)
- [Combining Clauses](#combining-clauses)

---

## Window Clauses

Window clauses partition a sequence into groups of consecutive items called windows. This is essential for time-series analysis, batch processing, and any situation where you need to process items in chunks.

There are two kinds: **tumbling windows** (non-overlapping) and **sliding windows** (overlapping).

### Tumbling Windows

A tumbling window moves forward without overlap. Each item belongs to exactly one window.

```xquery
(: Split sensor readings into groups of 3 :)
for tumbling window $batch in (10, 22, 15, 31, 8, 19, 27, 12)
    start at $s when true()
    end at $e when $e - $s eq 2
return <batch avg="{ avg($batch) }">{ $batch }</batch>
```

**Output:**
```xml
<batch avg="15.666666666666666">10 22 15</batch>
<batch avg="19.333333333333332">31 8 19</batch>
<batch avg="19.5">27 12</batch>
```

The `start` condition fires for the first item in each window. The `end` condition fires when the window should close. The positional variables `$s` and `$e` track start and end positions.

**C# parallel:** `Chunk` from .NET 6+:
```csharp
int[] readings = { 10, 22, 15, 31, 8, 19, 27, 12 };
var batches = readings.Chunk(3);
foreach (var batch in batches)
    Console.WriteLine($"Avg: {batch.Average()}");
```

### Tumbling Windows by Value

Windows don't have to be fixed-size. You can partition by value conditions:

```xquery
(: Group temperature readings into windows where each window
   stays within a 5-degree range of its starting value :)
let $readings := (20, 21, 23, 28, 30, 31, 18, 19, 22)

for tumbling window $group in $readings
    start $first when true()
    end $last next $next when abs($next - $first) > 5
return <range from="{ min($group) }" to="{ max($group) }">{ $group }</range>
```

**Output:**
```xml
<range from="20" to="23">20 21 23</range>
<range from="28" to="31">28 30 31</range>
<range from="18" to="22">18 19 22</range>
```

### Practical Example: Monthly Batching

```xquery
(: Group orders by month :)
for tumbling window $monthly-orders in (
    for $o in //orders/order
    order by xs:date($o/@date)
    return $o
)
    start $first when true()
    end $last next $next when
        month-from-date(xs:date($next/@date)) ne month-from-date(xs:date($first/@date))
        or year-from-date(xs:date($next/@date)) ne year-from-date(xs:date($first/@date))
return <month
    period="{ format-date(xs:date($first/@date), '[Y]-[M01]') }"
    count="{ count($monthly-orders) }"
    total="{ sum($monthly-orders/total) }"/>
```

### Sliding Windows

A sliding window moves one item at a time, so windows overlap. This is the tool for running averages, trend detection, and comparing adjacent items.

```xquery
(: 3-day moving average of stock prices :)
let $prices := (142.50, 145.20, 143.80, 148.30, 151.00, 149.75, 153.20)

for sliding window $w in $prices
    start at $s when true()
    end at $e when $e - $s eq 2
return <day position="{ $s }" moving-avg="{ round(avg($w), 2) }"/>
```

**Output:**
```xml
<day position="1" moving-avg="143.83"/>
<day position="2" moving-avg="145.77"/>
<day position="3" moving-avg="147.7"/>
<day position="4" moving-avg="149.68"/>
<day position="5" moving-avg="151.32"/>
```

**C# parallel:** There is no built-in sliding window in LINQ. You'd write it manually:
```csharp
decimal[] prices = { 142.50m, 145.20m, 143.80m, 148.30m, 151.00m, 149.75m, 153.20m };
var movingAvg = Enumerable.Range(0, prices.Length - 2)
    .Select(i => new {
        Position = i + 1,
        Avg = Math.Round(prices.Skip(i).Take(3).Average(), 2)
    });
```

### Window Variable Bindings

Window clauses support several positional and value variables:

```xquery
for tumbling window $w in $sequence
    start $startVal at $startPos previous $prevVal next $nextVal
        when (condition)
    end $endVal at $endPos previous $endPrevVal next $endNextVal
        when (condition)
return ...
```

| Variable | Meaning |
|----------|---------|
| `$startVal` | The value of the item at the start of the window |
| `$startPos` | The position (1-based) of the start item |
| `$prevVal` | The item before the start item (empty for first window) |
| `$nextVal` | The item after the start item |
| `$endVal` | The value of the item at the end of the window |
| `$endPos` | The position of the end item |

---

## Count Clause

The `count` clause assigns a sequential number to each tuple in the FLWOR pipeline. It looks simple, but it solves a problem the positional `at` variable cannot: numbering items **after** filtering and ordering.

### Count vs At

With `at`, the position reflects the original sequence:

```xquery
(: 'at' shows original positions — gaps after filtering :)
for $book at $pos in //catalog/book
where $book/price > 30
return <result pos="{ $pos }">{ $book/title/text() }</result>
(: pos might be 2, 5, 8 — the original positions :)
```

With `count`, the number is assigned after `where` and `order by`:

```xquery
(: 'count' gives clean sequential numbers :)
for $book in //catalog/book
where $book/price > 30
order by $book/price descending
count $rank
return <result rank="{ $rank }">{ $book/title/text() }</result>
(: rank is always 1, 2, 3 — sequential after filtering and sorting :)
```

**C# parallel:** `Select((item, index) => ...)` after `Where` and `OrderBy`:
```csharp
var ranked = books
    .Where(b => b.Price > 30)
    .OrderByDescending(b => b.Price)
    .Select((book, i) => new { Rank = i + 1, book.Title });
```

### Practical Example: Paginated Results

```xquery
let $page := 3
let $page-size := 10

for $product in //products/product
order by $product/name
count $n
where $n > ($page - 1) * $page-size and $n <= $page * $page-size
return <item num="{ $n }">{ $product/name/text() }</item>
```

Note how `count` is placed between `order by` and the second `where`. The position in the FLWOR pipeline matters: `count` numbers items based on whatever precedes it.

### Count with Group By

`count` is especially useful after grouping:

```xquery
for $order in //orders/order
group by $status := $order/@status
order by count($order) descending
count $rank
return <status rank="{ $rank }" name="{ $status }" count="{ count($order) }"/>
```

---

## Group By Clause

The `group by` clause groups FLWOR iterations by one or more keys. After grouping, all non-grouping variables become sequences containing the values from each group member.

### Basic Grouping

```xquery
for $order in //orders/order
group by $status := $order/@status
return <status name="{ $status }" count="{ count($order) }">
  { for $o in $order return <order id="{ $o/@id }"/> }
</status>
```

After `group by`, `$order` is no longer a single element. It's a sequence of all orders that share the same `$status`. This is the key concept.

**C# parallel:**
```csharp
from order in orders
group order by order.Status into g
select new {
    Status = g.Key,
    Count = g.Count(),
    Orders = g.ToList()
}
```

### Composite Group Keys

Group by multiple values:

```xquery
for $sale in //sales/sale
group by $year := year-from-date(xs:date($sale/@date)),
         $region := $sale/@region
order by $year, $region
return <group year="{ $year }" region="{ $region }"
    total="{ sum($sale/amount) }"
    count="{ count($sale) }"/>
```

**C# parallel:**
```csharp
from sale in sales
group sale by new { sale.Date.Year, sale.Region } into g
orderby g.Key.Year, g.Key.Region
select new { g.Key.Year, g.Key.Region, Total = g.Sum(s => s.Amount) }
```

### Aggregation Over Groups

Because non-grouping variables become sequences after `group by`, you can aggregate naturally:

```xquery
for $employee in //hr/employee
let $salary := xs:decimal($employee/salary)
group by $dept := $employee/@department
return <department name="{ $dept }">
  <headcount>{ count($employee) }</headcount>
  <total-salary>{ sum($salary) }</total-salary>
  <avg-salary>{ round(avg($salary), 2) }</avg-salary>
  <min-salary>{ min($salary) }</min-salary>
  <max-salary>{ max($salary) }</max-salary>
  <employees>{
    for $e in $employee
    order by $e/name
    return <employee>{ $e/name/text() }</employee>
  }</employees>
</department>
```

### Grouping Without an Explicit Key Variable

If you use an existing variable as the group key, you don't need the `:=` assignment:

```xquery
for $book in //books/book
let $category := string($book/@category)
group by $category
return <cat name="{ $category }">{ count($book) } books</cat>
```

### Practical Example: Pivot Table

```xquery
(: Sales by product and quarter :)
let $sales := //sales/transaction

for $t in $sales
let $product := string($t/@product)
let $quarter := concat("Q", ceiling(month-from-date(xs:date($t/@date)) div 3))
group by $product, $quarter
order by $product, $quarter
return <cell product="{ $product }" quarter="{ $quarter }"
    revenue="{ sum($t/amount) }"/>
```

---

## While Clause

*XQuery 4.0*

The `while` clause stops FLWOR iteration early when a condition becomes false. This is useful for processing sequences where you want to stop at a boundary rather than filter.

```xquery
(: Process log entries until you hit an error :)
for $entry in //log/entry
while $entry/@level ne "ERROR"
return <processed>{ $entry/message/text() }</processed>
```

Unlike `where`, which skips non-matching items and continues, `while` terminates the entire iteration. No items after the first failure are processed.

**C# parallel:** `TakeWhile`:
```csharp
var processed = logEntries
    .TakeWhile(e => e.Level != "ERROR")
    .Select(e => e.Message);
```

### Practical Example: Running Total with Budget Cap

```xquery
for $item in //purchase-requests/item
order by $item/priority ascending, xs:date($item/requested) ascending
let $running := sum(
    for $prev in //purchase-requests/item
    where $prev/priority < $item/priority
       or ($prev/priority = $item/priority
           and xs:date($prev/requested) <= xs:date($item/requested))
    return xs:decimal($prev/cost)
)
while $running <= 50000
return <approved item="{ $item/@id }" cost="{ $item/cost/text() }"
    running-total="{ $running }"/>
```

### While with Count

Combine `while` with `count` to know how many items were processed:

```xquery
for $reading in //sensor/readings/value
while xs:decimal($reading) < 100
count $n
return ()
,
(: $n now holds how many readings were below threshold :)
```

---

## Otherwise Clause

*XQuery 4.0*

The `otherwise` clause provides a default result when the entire FLWOR expression produces an empty sequence.

```xquery
for $match in //products/product[contains(name, $search-term)]
order by $match/name
return <result>{ $match/name/text() }</result>
otherwise <no-results>No products matching "{ $search-term }"</no-results>
```

Without `otherwise`, an empty result from the FLWOR would produce nothing. With `otherwise`, you always get at least one item back.

**C# parallel:** `DefaultIfEmpty`:
```csharp
var results = products
    .Where(p => p.Name.Contains(searchTerm))
    .OrderBy(p => p.Name)
    .Select(p => p.Name)
    .DefaultIfEmpty($"No products matching \"{searchTerm}\"");
```

### Practical Example: Dashboard Widgets

```xquery
(: Always return a widget, even if there's no data :)
<dashboard>{
  <alerts>{
    for $alert in //system/alerts/alert
    where $alert/@severity = "critical"
    order by xs:dateTime($alert/@timestamp) descending
    return <item>{ $alert/message/text() }</item>
    otherwise <item class="ok">No critical alerts</item>
  }</alerts>,

  <recent-orders>{
    for $order in //orders/order
    where xs:date($order/@date) >= current-date() - xs:dayTimeDuration("P7D")
    order by xs:date($order/@date) descending
    count $n
    where $n <= 5
    return <order id="{ $order/@id }" total="{ $order/total/text() }"/>
    otherwise <none>No orders in the last 7 days</none>
  }</recent-orders>
}</dashboard>
```

---

## Combining Clauses

The real power of FLWOR emerges when you combine multiple clauses. Here's the full clause order:

```
(for | let | window)+
where*
group by?
order by?
count?
where*        (: yes, where can appear again after group/order/count :)
while?
return
otherwise?
```

Clauses can be interleaved and repeated. Each clause operates on the result of what precedes it.

### Example: Sales Report with Ranking

```xquery
(: Top 3 product categories by revenue, with product details :)
for $sale in //sales/transaction
let $product := //products/product[@id = $sale/@product-id]
let $revenue := xs:decimal($sale/quantity) * xs:decimal($product/price)
group by $category := $product/@category
let $category-revenue := sum($revenue)
order by $category-revenue descending
count $rank
where $rank <= 3
return <category rank="{ $rank }"
    name="{ $category }"
    revenue="{ $category-revenue }">
  {
    for $p in distinct-values($product/@id)
    let $prod := //products/product[@id = $p]
    let $prod-revenue := sum(
      $revenue[index-of($product/@id, $p)]
    )
    order by $prod-revenue descending
    count $prod-rank
    where $prod-rank <= 5
    return <product rank="{ $prod-rank }"
        name="{ $prod/name/text() }"
        revenue="{ $prod-revenue }"/>
  }
</category>
```

### Example: Log Analysis Pipeline

```xquery
for $entry in //log/entry
let $timestamp := xs:dateTime($entry/@timestamp)
let $hour := hours-from-dateTime($timestamp)
let $level := string($entry/@level)
where $level = ("WARN", "ERROR", "FATAL")

group by $hour, $level
let $count := count($entry)
order by $hour, $level

return <bucket hour="{ $hour }" level="{ $level }" count="{ $count }">
  {
    if ($count > 10) then
      attribute alert { "high-volume" }
    else ()
  }
  {
    for $e in $entry
    order by xs:dateTime($e/@timestamp) descending
    count $n
    where $n <= 3
    return <sample>{ $e/message/text() }</sample>
  }
</bucket>
otherwise <clean-log>No warnings or errors found</clean-log>
```

### Example: Full Pipeline with Multiple For Clauses

```xquery
for $customer in //customers/customer
let $orders := //orders/order[@customer-id = $customer/@id]
where exists($orders)

for $order in $orders
let $items := $order/line-item
let $order-total := sum(
  for $item in $items
  return xs:decimal($item/@qty) * xs:decimal($item/@unit-price)
)

group by $customer-id := $customer/@id,
         $customer-name := $customer/name/text()
let $total-spend := sum($order-total)
let $order-count := count($order)

order by $total-spend descending
count $rank
where $rank <= 10

return <top-customer rank="{ $rank }">
  <name>{ $customer-name }</name>
  <orders>{ $order-count }</orders>
  <total-spend>{ $total-spend }</total-spend>
  <avg-order>{ round($total-spend div $order-count, 2) }</avg-order>
</top-customer>
```

This single FLWOR expression joins customers and orders, calculates totals, groups by customer, aggregates spending, sorts by total, and returns the top 10. The C# equivalent would require significantly more code:

```csharp
var topCustomers = (
    from customer in customers
    let orders = allOrders.Where(o => o.CustomerId == customer.Id)
    where orders.Any()
    from order in orders
    let orderTotal = order.LineItems.Sum(li => li.Qty * li.UnitPrice)
    group new { order, orderTotal }
        by new { customer.Id, customer.Name } into g
    let totalSpend = g.Sum(x => x.orderTotal)
    let orderCount = g.Count()
    orderby totalSpend descending
    select new {
        g.Key.Name,
        Orders = orderCount,
        TotalSpend = totalSpend,
        AvgOrder = Math.Round(totalSpend / orderCount, 2)
    }
).Take(10)
 .Select((c, i) => new { Rank = i + 1, c.Name, c.Orders, c.TotalSpend, c.AvgOrder });
```
