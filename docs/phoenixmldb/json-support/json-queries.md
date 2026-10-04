---
title: JSON Queries
description: XQuery patterns for querying JSON documents stored in PhoenixmlDb
sort: 2
---

# JSON Queries

This guide covers XQuery patterns for JSON documents stored in PhoenixmlDb. JSON is stored in its `fn:json-to-xml` representation (see [JSON Support](index.md#json-to-xml-mapping)): every element is in the `http://www.w3.org/2005/xpath-functions` namespace, bound to the predeclared `fn` prefix, and object members are selected by their `key` attribute.

Run the queries with `IContainer.QueryAsync`. A query that does not aggregate across documents runs once per document, with that document as the context item; one that uses `collection()` with an aggregate, `order by` or `group by` runs once over the whole container. See [Query API](../api-reference/queries.md#how-a-query-is-evaluated).

```csharp
await foreach (var name in users.QueryAsync("/fn:map/fn:string[@key='name']/string()"))
    Console.WriteLine(name);
```

To write paths without the prefix, declare the default element namespace:

```xquery
declare default element namespace 'http://www.w3.org/2005/xpath-functions';
/map/string[@key='name']/string()
```

## Basic Field Access

```xquery
(: Top-level field :)
/fn:map/fn:string[@key='name']/string()

(: Nested field :)
/fn:map/fn:map[@key='profile']/fn:map[@key='address']/fn:string[@key='city']/string()

(: With a default :)
(/fn:map/fn:string[@key='nickname']/string(), 'Anonymous')[1]

(: Any member by key, whatever its type :)
/fn:map/fn:*[@key='status']/string()
```

## Filtering Documents

### Simple Filters

```xquery
(: String equality :)
/fn:map[fn:string[@key='status'] = 'active']

(: Numeric comparison :)
/fn:map[fn:number[@key='price'] > 100]/fn:string[@key='name']/string()

(: Boolean check :)
/fn:map[fn:boolean[@key='verified'] = 'true']/fn:string[@key='email']/string()
```

### Combined Filters

```xquery
/fn:map[fn:string[@key='status'] = 'pending']
       [xs:decimal(fn:number[@key='total']) > 500]
       [fn:string[@key='priority'] = 'high']
```

### Null Checks

```xquery
(: Member present with value null :)
/fn:map[fn:null[@key='deletedAt']]

(: Member present and not null :)
/fn:map[fn:*[@key='deletedAt'][not(self::fn:null)]]

(: Member exists :)
/fn:map[fn:*[@key='email']]

(: Member missing :)
/fn:map[not(fn:*[@key='phone'])]
```

## Array Queries

### Contains Element

```xquery
(: Array contains a value :)
/fn:map[fn:array[@key='tags']/fn:string = 'featured']

(: Any of several values (OR) :)
/fn:map[fn:array[@key='tags']/fn:string = ('sale', 'new', 'popular')]

(: All of several values (AND) :)
/fn:map[fn:array[@key='tags']/fn:string = 'electronics']
       [fn:array[@key='tags']/fn:string = 'wireless']
```

### Array Index Access

```xquery
(: First element :)
/fn:map/fn:array[@key='items']/*[1]

(: Last element :)
/fn:map/fn:array[@key='items']/*[last()]

(: Slice :)
/fn:map/fn:array[@key='items']/*[position() = 2 to 5]
```

### Array Aggregation

```xquery
(: Count array items, per document :)
count(/fn:map/fn:array[@key='items']/*)

(: Sum a field across the objects in an array, per document :)
sum(/fn:map/fn:array[@key='items']/fn:map/fn:number[@key='price'])
```

### Nested Array Queries

```xquery
(: Orders containing a specific product :)
/fn:map[fn:array[@key='items']/fn:map/fn:string[@key='productId'] = 'P001']
  /fn:string[@key='id']/string()

(: Users with a specific role :)
/fn:map[fn:array[@key='roles']/fn:string = 'admin']/fn:string[@key='email']/string()
```

## Nested Object Queries

```xquery
/fn:map[fn:map[@key='address']/fn:string[@key='country'] = 'USA']
       [fn:map[@key='address']/fn:string[@key='state'] = 'CA']
  ! concat(fn:string[@key='name'], ' - ', fn:map[@key='address']/fn:string[@key='city'])
```

## Type Handling

### Numeric Fields

`number` elements hold the number's text; it compares as untyped, so cast when you need a specific type:

```xquery
for $p in collection()/fn:map
let $price := xs:decimal($p/fn:number[@key='price'])
where $price ge 10 and $price le 100
order by $price
return $p/fn:string[@key='name']/string()
```

### Boolean Fields

```xquery
(: boolean elements contain 'true' or 'false' :)
/fn:map[fn:boolean[@key='active'] = 'true']
/fn:map[not(fn:boolean[@key='deleted'] = 'true')]
```

### Date Fields

JSON has no date type; dates are strings:

```xquery
for $event in collection()/fn:map
let $date := xs:dateTime($event/fn:string[@key='startTime'])
where $date > current-dateTime()
order by $date
return $event/fn:string[@key='title']/string()
```

## Joins

A query sees one container. Documents to be joined must be in the same container; distinguish them by name or content:

```xquery
for $order in collection()/fn:map[fn:string[@key='type'] = 'order']
let $customer := collection()/fn:map[fn:string[@key='type'] = 'customer']
                   [fn:string[@key='id'] = $order/fn:string[@key='customerId']]
order by $order/fn:string[@key='id']
return <result>
    <orderId>{ $order/fn:string[@key='id']/string() }</orderId>
    <customer>{ $customer/fn:string[@key='name']/string() }</customer>
    <total>{ $order/fn:number[@key='total']/string() }</total>
</result>
```

## Grouping and Aggregation

### Group By

```xquery
for $order in collection()/fn:map
group by $status := string($order/fn:string[@key='status'])
return <status name="{ $status }">
    <count>{ count($order) }</count>
    <total>{ sum($order/fn:number[@key='total'] ! xs:decimal(.)) }</total>
</status>
```

### Container-wide Totals

```xquery
let $orders := collection()/fn:map
return <summary>
    <totalOrders>{ count($orders) }</totalOrders>
    <totalRevenue>{ sum($orders/fn:number[@key='total'] ! xs:decimal(.)) }</totalRevenue>
    <averageOrder>{ avg($orders/fn:number[@key='total'] ! xs:decimal(.)) }</averageOrder>
</summary>
```

## Text Search

```xquery
(: Substring match on a text field :)
/fn:map[contains(lower-case(fn:string[@key='description']), 'wireless')]

(: Multiple terms :)
/fn:map[contains(fn:string[@key='content'], 'machine')]
       [contains(fn:string[@key='content'], 'learning')]
  /fn:string[@key='title']/string()
```

`contains()` is evaluated against each document's text. For indexed keyword search, declare a full-text index and use the full-text API; see [Full-Text Search](../full-text-search.md).

## Pagination

```xquery
let $page := 2
let $pageSize := 10
let $sorted := for $product in collection()/fn:map
               order by $product/fn:string[@key='name']
               return $product
return subsequence($sorted, ($page - 1) * $pageSize + 1, $pageSize)
```

## Output as JSON

### Back to the original shape

`xml-to-json()` converts the stored representation back to JSON text:

```xquery
xml-to-json(/fn:map)
```

### XQuery Maps

A query that returns a map yields its adaptive serialization (`map{"id":"u1",...}`), not JSON. Serialize explicitly for JSON text:

```xquery
serialize(
    map {
        "id": string(/fn:map/fn:string[@key='id']),
        "name": string(/fn:map/fn:string[@key='name'])
    },
    map { "method": "json" }
)
```

### One JSON Array for the Container

```xquery
serialize(
    array {
        for $product in collection()/fn:map
        where $product/fn:boolean[@key='inStock'] = 'true'
        order by $product/fn:string[@key='name']
        return map {
            "name": string($product/fn:string[@key='name']),
            "price": number($product/fn:number[@key='price'])
        }
    },
    map { "method": "json" }
)
```

## Best Practices

1. **Select members by key** — `fn:string[@key='status']`, or `fn:*[@key='status']` when the type varies
2. **Use typed comparisons** — Cast `number` values to `xs:decimal` or `xs:double` where precision or ordering matters
3. **Mind the evaluation shape** — Use `collection()` with an aggregate, `order by` or `group by` for one container-wide answer
4. **Filter before joining** — Reduce join cardinality
5. **Use `let` for reused expressions** — Avoid recomputation

## Next Steps

| Storage | Indexing | Functions |
|---------|----------|-----------|
| **[JSON Storage](json-storage.md)**<br>Storage options | **[JSON Indexing](json-indexing.md)**<br>Optimize query performance | **[Functions and Operators](../../language-reference/xpath/functions/index.md)**<br>XQuery functions |
