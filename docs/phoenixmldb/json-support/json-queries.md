---
title: JSON Queries
description: XQuery patterns for querying JSON documents stored in PhoenixmlDb
sort: 2
---

# JSON Queries

This guide covers XQuery patterns optimized for querying JSON documents stored in PhoenixmlDb.

## Basic Field Access

```xquery
(: Access top-level field :)
doc('users/user1.json')/map/name/text()

(: Access nested field :)
//map/profile/address/city/text()

(: Access with default :)
(//map/nickname/text(), 'Anonymous')[1]
```

## Filtering Documents

### Simple Filters

```xquery
(: String equality :)
for $user in collection('users')/map
where $user/status = 'active'
return $user

(: Numeric comparison :)
for $product in collection('products')/map
where $product/price > 100
return $product/name/text()

(: Boolean check :)
for $user in collection('users')/map
where $user/verified = 'true'
return $user/email/text()
```

### Combined Filters

```xquery
for $order in collection('orders')/map
where $order/status = 'pending'
  and xs:decimal($order/total) > 500
  and $order/priority = 'high'
return $order
```

### Null Checks

```xquery
(: Check for null :)
//map[deletedAt/@type = 'null']

(: Check for non-null :)
//map[not(deletedAt/@type = 'null')]

(: Check field exists :)
//map[email]

(: Check field missing :)
//map[not(phone)]
```

## Array Queries

### Contains Element

```xquery
(: Check if array contains value :)
for $product in collection('products')/map
where $product/tags/_ = 'featured'
return $product

(: Multiple values (OR) :)
for $product in collection('products')/map
where $product/tags/_ = ('sale', 'new', 'popular')
return $product

(: Multiple values (AND) :)
for $product in collection('products')/map
where $product/tags/_ = 'electronics'
  and $product/tags/_ = 'wireless'
return $product
```

### Array Index Access

```xquery
(: First element :)
//map/items/_[1]

(: Last element :)
//map/items/_[last()]

(: Slice :)
//map/items/_[position() >= 2 and position() <= 5]
```

### Array Aggregation

```xquery
(: Count array items :)
for $order in collection('orders')/map
let $itemCount := count($order/items/_)
return <order id="{$order/id}">{$itemCount} items</order>

(: Sum array values :)
for $order in collection('orders')/map
let $total := sum($order/items/_/price)
return <order id="{$order/id}">Total: {$total}</order>
```

### Nested Array Queries

```xquery
(: Find orders containing specific product :)
for $order in collection('orders')/map
where $order/items/_/productId = 'P001'
return $order/id/text()

(: Find users with specific role :)
for $user in collection('users')/map
where $user/roles/_ = 'admin'
return $user/email/text()
```

## Nested Object Queries

```xquery
(: Query nested objects :)
for $user in collection('users')/map
where $user/address/country = 'USA'
  and $user/address/state = 'CA'
return concat($user/name, ' - ', $user/address/city)

(: Deep nesting :)
//map/company/departments/_/employees/_[role = 'manager']/name
```

## Type Handling

### Numeric Fields

```xquery
(: Numbers are stored as strings with type="number" :)
for $p in collection('products')/map
let $price := xs:decimal($p/price)
where $price between 10 and 100
order by $price
return $p
```

### Boolean Fields

```xquery
(: Booleans are stored as 'true'/'false' strings :)
//map[active = 'true']
//map[not(deleted = 'true')]
```

### Date Fields

```xquery
(: Parse date strings :)
for $event in collection('events')/map
let $date := xs:dateTime($event/startTime)
where $date > current-dateTime()
order by $date
return $event
```

## Joins

### Simple Join

```xquery
for $order in collection('orders')/map
let $customer := collection('customers')/map[id = $order/customerId]
return <result>
    <orderId>{$order/id/text()}</orderId>
    <customer>{$customer/name/text()}</customer>
    <total>{$order/total/text()}</total>
</result>
```

### Multiple Joins

```xquery
for $order in collection('orders')/map
let $customer := collection('customers')/map[id = $order/customerId]
for $item in $order/items/_
let $product := collection('products')/map[id = $item/productId]
return <line>
    <order>{$order/id/text()}</order>
    <customer>{$customer/name/text()}</customer>
    <product>{$product/name/text()}</product>
    <quantity>{$item/quantity/text()}</quantity>
</line>
```

## Grouping and Aggregation

### Group By

```xquery
for $order in collection('orders')/map
group by $status := $order/status/text()
return <status name="{$status}">
    <count>{count($order)}</count>
    <total>{sum(for $o in $order return xs:decimal($o/total))}</total>
</status>
```

### Complex Aggregation

```xquery
let $orders := collection('orders')/map

return <report>
    <summary>
        <totalOrders>{count($orders)}</totalOrders>
        <totalRevenue>{sum(for $o in $orders return xs:decimal($o/total))}</totalRevenue>
        <averageOrder>{avg(for $o in $orders return xs:decimal($o/total))}</averageOrder>
    </summary>
    <byStatus>{
        for $order in $orders
        group by $status := $order/status/text()
        order by count($order) descending
        return <status name="{$status}" count="{count($order)}"/>
    }</byStatus>
    <topCustomers>{
        for $order in $orders
        group by $customer := $order/customerId/text()
        let $total := sum(for $o in $order return xs:decimal($o/total))
        order by $total descending
        return <customer id="{$customer}" total="{$total}"/>[position() <= 10]
    }</topCustomers>
</report>
```

## Full-Text Search

```xquery
(: Search in text fields :)
for $product in collection('products')/map
where contains(lower-case($product/description), 'wireless')
return $product

(: Multiple terms :)
for $article in collection('articles')/map
where contains($article/content, 'machine')
  and contains($article/content, 'learning')
return $article/title/text()
```

## Pagination

```xquery
(: Skip and limit :)
let $page := 2
let $pageSize := 10
for $product in collection('products')/map
order by $product/name
return $product
  [position() > ($page - 1) * $pageSize]
  [position() <= $pageSize]
```

## Output as JSON

### XQuery 3.1 Maps

```xquery
for $user in collection('users')/map
return map {
    "id": string($user/id),
    "name": string($user/name),
    "email": string($user/email)
}
```

### Serialize to JSON

```xquery
serialize(
    array {
        for $product in collection('products')/map
        where $product/inStock = 'true'
        return map {
            "name": string($product/name),
            "price": number($product/price)
        }
    },
    map { "method": "json" }
)
```

## Best Practices

1. **Index frequently queried paths** — `/map/status`, `/map/customerId`
2. **Use typed comparisons** — Cast to `xs:decimal` for numeric comparisons
3. **Avoid `//` in large collections** — Use specific paths
4. **Filter before joining** — Reduce join cardinality
5. **Use `let` for reused expressions** — Avoid recomputation

## Next Steps

| Storage | Indexing | Functions |
|---------|----------|-----------|
| **[JSON Storage](json-storage.md)**<br>Storage options | **[JSON Indexing](json-indexing.md)**<br>Optimize query performance | **[Functions and Operators](../../language-reference/xpath/functions/index.md)**<br>XQuery functions |
