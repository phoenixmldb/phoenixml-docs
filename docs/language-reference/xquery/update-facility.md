---
title: Update Facility
description: XQuery Update — insert, delete, replace, rename, and transform expressions
sort: 7
---

# Update Facility

XQuery was originally a read-only language. The Update Facility (XUF) adds the ability to modify XML data while preserving XQuery's functional semantics. Updates don't happen immediately — they're collected into a **Pending Update List** and applied atomically at the end.

If you're coming from C#, think of it as a combination of Entity Framework's change tracking (modifications are staged, then flushed) and LINQ to XML's mutation methods (`Add`, `Remove`, `ReplaceWith`).

## Contents

- [Why Update Facility Exists](#why-update-facility-exists)
- [insert](#insert)
- [delete](#delete)
- [replace node](#replace-node)
- [replace value of node](#replace-value-of-node)
- [rename](#rename)
- [Transform Expression](#transform-expression)
- [Pending Update Lists](#pending-update-lists)
- [Combining Updates](#combining-updates)
- [Use Cases](#use-cases)

---

## Why Update Facility Exists

Standard XQuery expressions are side-effect-free. They read data and produce results without changing anything. This is by design — it enables optimization, parallelism, and predictable behavior.

But real applications need to modify data. The Update Facility solves this by adding update expressions that look like imperative mutations but behave functionally:

1. Update expressions generate **pending update lists** (PULs), not immediate changes
2. Multiple updates are collected together
3. All updates are applied **atomically** after the expression completes
4. If any update conflicts, the entire batch fails

This is fundamentally different from C#'s immediate mutation model:

```csharp
// C# — immediate mutation
element.Add(new XElement("child", "value"));  // document changed NOW
element.SetValue("new");                       // changed again NOW
```

```xquery
(: XQuery Update — deferred mutation :)
insert node <child>value</child> into $element,  (: staged :)
replace value of node $element with "new"         (: staged :)
(: Both applied atomically after expression completes :)
```

---

## insert

Adds new nodes to an existing document.

### Insert into (as a child)

```xquery
insert node <status>active</status> into //customer[@id = "C001"]
```

This adds `<status>active</status>` as the last child of the matching customer element.

**C# parallel:**
```csharp
customer.Add(new XElement("status", "active"));
```

### Insert as first or last child

Control the position among existing children:

```xquery
(: Add as the first child :)
insert node <priority>high</priority> as first into //order[@id = "O100"]

(: Add as the last child :)
insert node <notes>Expedited shipping requested</notes> as last into //order[@id = "O100"]
```

**C# parallel:**
```csharp
order.AddFirst(new XElement("priority", "high"));   // as first
order.Add(new XElement("notes", "Expedited"));       // as last
```

### Insert before or after a sibling

```xquery
(: Add a new item before the total :)
insert node <line-item product="WIDGET" qty="2" unit-price="9.99"/>
  before //order[@id = "O100"]/total

(: Add a note after the shipping address :)
insert node <delivery-note>Leave at back door</delivery-note>
  after //order[@id = "O100"]/shipping-address
```

**C# parallel:**
```csharp
total.AddBeforeSelf(new XElement("line-item", ...));
shippingAddress.AddAfterSelf(new XElement("delivery-note", "Leave at back door"));
```

### Insert multiple nodes

```xquery
insert nodes (
  <tag>electronics</tag>,
  <tag>wireless</tag>,
  <tag>bluetooth</tag>
) into //product[@id = "P200"]
```

### Insert attributes

```xquery
insert node attribute verified { "true" } into //order[@id = "O100"]
```

After this update, the order element gains a `verified="true"` attribute.

### Practical Example: Add Audit Trail

```xquery
for $order in //orders/order[@status = "pending"]
return insert node
  <audit-entry>
    <action>reviewed</action>
    <by>system</by>
    <timestamp>{ current-dateTime() }</timestamp>
  </audit-entry>
  as last into $order
```

---

## delete

Removes nodes from a document.

### Delete a single node

```xquery
delete node //product[@id = "P999"]
```

**C# parallel:**
```csharp
product.Remove();
```

### Delete multiple nodes

```xquery
(: Delete all discontinued products :)
delete nodes //product[@discontinued = "true"]

(: Delete all comments from a document :)
delete nodes //comment()

(: Delete all empty elements :)
delete nodes //*[not(node()) and not(@*)]
```

### Delete attributes

```xquery
(: Remove the "internal" attribute from all products :)
delete node //product/@internal
```

### Practical Example: Data Cleanup

```xquery
(: Remove all products with no orders in the last year :)
let $cutoff := current-date() - xs:yearMonthDuration("P1Y")
let $active-product-ids := distinct-values(
  //orders/order[xs:date(@date) > $cutoff]/line-item/@product-id
)

for $product in //products/product
where not($product/@id = $active-product-ids)
return delete node $product
```

---

## replace node

Replaces an entire node (element, attribute, text, etc.) with a new node.

```xquery
(: Replace an element with a completely new one :)
replace node //product[@id = "P100"]/price
  with <price currency="USD">29.99</price>
```

The old `<price>` element is removed and the new one takes its place.

**C# parallel:**
```csharp
price.ReplaceWith(new XElement("price",
    new XAttribute("currency", "USD"),
    "29.99"
));
```

### Replace with multiple nodes

```xquery
(: Replace a single summary element with detailed breakdown :)
replace node //order/summary
  with (
    <subtotal>{ $subtotal }</subtotal>,
    <tax>{ $tax }</tax>,
    <shipping>{ $shipping }</shipping>,
    <total>{ $subtotal + $tax + $shipping }</total>
  )
```

### Replace an attribute

```xquery
replace node //order[@id = "O100"]/@status
  with attribute status { "shipped" }
```

---

## replace value of node

Changes the text content of an element or the value of an attribute **without replacing the node itself**. The node keeps its name, attributes (for elements), and identity — only the value changes.

### Replace element content

```xquery
replace value of node //product[@id = "P100"]/price with "34.99"
```

Before: `<price currency="USD">29.99</price>`
After: `<price currency="USD">34.99</price>`

The element name and attributes are preserved. Only the text content changes.

**C# parallel:**
```csharp
price.SetValue("34.99");
```

### Replace attribute value

```xquery
replace value of node //order[@id = "O100"]/@status with "shipped"
```

Before: `<order id="O100" status="pending">`
After: `<order id="O100" status="shipped">`

### Difference from replace node

```xquery
(: replace node — swaps the entire element :)
replace node //product/price
  with <price currency="EUR">34.99</price>
(: Old element gone. New element has different attributes. :)

(: replace value of node — changes only the text :)
replace value of node //product/price with "34.99"
(: Same element, same attributes, new text content. :)
```

Use `replace value of node` when you want to update content but keep the node's structure. Use `replace node` when you need to change the node's name, attributes, or structure.

### Practical Example: Batch Price Update

```xquery
for $product in //products/product
let $old-price := xs:decimal($product/price)
let $new-price := round($old-price * 1.05, 2)  (: 5% increase :)
return replace value of node $product/price with string($new-price)
```

---

## rename

Changes the name of an element or attribute without affecting its content, children, or attributes.

```xquery
(: Rename an element :)
rename node //product/desc as "description"
```

Before: `<desc>A fine widget</desc>`
After: `<description>A fine widget</description>`

### Rename with a QName

For namespaced names, use `QName()`:

```xquery
rename node //item as QName("http://example.com/schema", "product")
```

### Rename an attribute

```xquery
rename node //product/@cat as "category"
```

Before: `<product cat="tools">`
After: `<product category="tools">`

### Practical Example: Schema Migration

```xquery
(: Migrate from old element names to new ones :)
for $node in //customerRecord
return rename node $node as "customer",

for $node in //customerRecord/firstName
return rename node $node as "first-name",

for $node in //customerRecord/lastName
return rename node $node as "last-name",

for $node in //customerRecord/emailAddr
return rename node $node as "email"
```

---

## Transform Expression

The transform expression (also called copy-modify-return) creates a **modified copy** of a node without changing the original. This is XQuery Update's immutable approach — essential when you need to return modified data without side effects.

```xquery
copy $order := //order[@id = "O100"]
modify (
  replace value of node $order/status with "shipped",
  insert node <shipped-date>{ current-date() }</shipped-date> as last into $order
)
return $order
```

The original order in the database is unchanged. The expression returns a new, modified copy.

**C# parallel:** Immutable record `with` expressions:
```csharp
var updated = order with {
    Status = "shipped",
    ShippedDate = DateTime.Now.ToString("yyyy-MM-dd")
};
```

### How It Works

1. `copy` creates a deep copy of the node and binds it to a variable
2. `modify` applies update expressions to the copy
3. `return` returns the modified copy
4. The original is never touched

### Multiple Copy Variables

You can copy multiple nodes:

```xquery
copy $order := //order[@id = "O100"]
copy $customer := //customer[@id = $order/@customer-id]
modify (
  replace value of node $order/status with "confirmed",
  insert node <confirmed-by>{ $customer/name/text() }</confirmed-by> into $order
)
return $order
```

### Practical Example: Document Patching

```xquery
(: Apply a set of patches to a configuration document :)
declare function local:apply-patches(
  $config as element(config),
  $patches as element(patch)*
) as element(config) {
  if (empty($patches)) then $config
  else
    let $patch := $patches[1]
    let $patched := copy $c := $config
      modify (
        typeswitch ($patch)
          case element(set) return
            if (exists($c//*[local-name() = $patch/@target]))
            then replace value of node $c//*[local-name() = $patch/@target]
                 with $patch/text()
            else insert node element { $patch/@target } { $patch/text() }
                 into $c
          case element(remove) return
            delete node $c//*[local-name() = $patch/@target]
          default return ()
      )
      return $c
    return local:apply-patches($patched, subsequence($patches, 2))
};

(: Usage :)
local:apply-patches(
  //config,
  (
    <set target="log-level">DEBUG</set>,
    <set target="max-connections">200</set>,
    <remove target="deprecated-feature"/>
  )
)
```

### Transform for JSON Output

Transform is useful for sanitizing XML before converting to JSON:

```xquery
for $user in //users/user
return copy $safe := $user
  modify (
    delete node $safe/password-hash,
    delete node $safe/ssn,
    delete node $safe/internal-notes
  )
  return map {
    "id": string($safe/@id),
    "name": string($safe/name),
    "email": string($safe/email),
    "role": string($safe/@role)
  }
```

---

## Pending Update Lists

Understanding Pending Update Lists (PULs) is essential for writing correct update queries.

### How PULs Work

1. Each update expression (`insert`, `delete`, `replace`, `rename`) generates a pending update
2. Updates are collected into a PUL — they don't execute immediately
3. After the entire query evaluates, the PUL is applied atomically
4. If there are conflicts, the entire PUL is rejected

### Conflict Rules

Certain combinations of updates on the same node conflict:

```xquery
(: CONFLICT — two replace on the same node :)
replace value of node $order/status with "shipped",
replace value of node $order/status with "delivered"
(: Error: conflicting updates on the same node :)
```

```xquery
(: OK — updates on different nodes :)
replace value of node $order/status with "shipped",
replace value of node $order/total with "150.00"
(: Fine: different target nodes :)
```

```xquery
(: OK — insert and replace on the same parent :)
insert node <note>Updated</note> into $order,
replace value of node $order/status with "shipped"
(: Fine: insert adds a child, replace modifies a different child :)
```

### Ordering

Updates in a PUL have no guaranteed order of application. Write updates that don't depend on each other's execution order:

```xquery
(: Don't do this — depends on ordering :)
insert node <total>0</total> into $order,
replace value of node $order/total with string($calculated-total)
(: The total might not exist yet when replace runs :)

(: Do this instead :)
insert node <total>{ $calculated-total }</total> into $order
(: Single update, no ordering dependency :)
```

---

## Combining Updates

### Multiple Updates in a FLWOR

A FLWOR expression can return multiple updates:

```xquery
for $product in //products/product
where xs:decimal($product/price) > 100
return (
  replace value of node $product/@category with "premium",
  insert node <premium-since>{ current-date() }</premium-since> into $product
)
```

Each iteration contributes updates to the PUL. All updates across all iterations are applied atomically.

### Updates from Different Sources

```xquery
(: Update orders and inventory in one query :)
for $order in //orders/order[@status = "approved"]
let $items := $order/line-item
return (
  (: Update order status :)
  replace value of node $order/@status with "shipped",
  insert node <ship-date>{ current-date() }</ship-date> into $order,

  (: Update inventory :)
  for $item in $items
  let $product := //products/product[@id = $item/@product-id]
  let $new-stock := xs:integer($product/stock) - xs:integer($item/@qty)
  return replace value of node $product/stock with string($new-stock)
)
```

### Conditional Updates

```xquery
for $customer in //customers/customer
return (
  (: Always update last-checked :)
  if (exists($customer/@last-checked)) then
    replace value of node $customer/@last-checked
      with string(current-dateTime())
  else
    insert node attribute last-checked { current-dateTime() }
      into $customer
  ,
  (: Conditionally add a warning :)
  if (xs:decimal($customer/balance) < 0 and not(exists($customer/warning))) then
    insert node <warning>Negative balance</warning> into $customer
  else
    ()
)
```

---

## Use Cases

### Data Migration

Restructure documents when your schema evolves:

```xquery
(: Migrate from flat address to structured address :)
for $customer in //customers/customer[address-line]
let $parts := tokenize($customer/address-line, ",\s*")
return (
  insert node <address>
    <street>{ $parts[1] }</street>
    <city>{ $parts[2] }</city>
    <state>{ $parts[3] }</state>
    <zip>{ $parts[4] }</zip>
  </address> into $customer,
  delete node $customer/address-line
)
```

### Document Patching

Apply partial updates received from an API:

```xquery
declare function local:apply-json-patch(
  $target as element(),
  $patch as map(*)
) as element() {
  copy $t := $target
  modify (
    for $key in map:keys($patch)
    let $value := $patch($key)
    let $existing := $t/*[local-name() = $key]
    return
      if (exists($existing)) then
        replace value of node $existing with string($value)
      else
        insert node element { $key } { string($value) } into $t
  )
  return $t
};

(: Usage: apply a partial update :)
local:apply-json-patch(
  //product[@id = "P100"],
  map { "price": "34.99", "stock": "150", "updated": "2026-03-19" }
)
```

### Batch Processing

Process large collections with updates:

```xquery
(: Normalize all phone numbers in the database :)
for $phone in //customer/phone
let $digits := replace($phone/text(), "[^0-9]", "")
let $formatted := concat(
  "(", substring($digits, 1, 3), ") ",
  substring($digits, 4, 3), "-",
  substring($digits, 7, 4)
)
where $phone/text() ne $formatted
return replace value of node $phone with $formatted
```

### ETL Pipeline

Extract data from one format, transform, and load into another:

```xquery
(: Read CSV-like XML, validate, and insert into structured collection :)
for $row in doc("import.xml")//row
let $name := normalize-space($row/field[@name = "name"])
let $email := normalize-space($row/field[@name = "email"])
let $amount := $row/field[@name = "amount"]
where $name ne "" and $email ne "" and $amount castable as xs:decimal
return insert node
  <customer>
    <name>{ $name }</name>
    <email>{ $email }</email>
    <balance>{ xs:decimal($amount) }</balance>
    <imported>{ current-dateTime() }</imported>
  </customer>
  into doc("customers.xml")/customers
```

### C# Comparison: Full Update Workflow

Here's a side-by-side comparison of a complete update scenario:

**XQuery Update:**
```xquery
(: Find overdue orders and update their status :)
let $today := current-date()
for $order in //orders/order[@status = "pending"]
let $due := xs:date($order/@due-date)
where $due < $today
return (
  replace value of node $order/@status with "overdue",
  insert node <overdue-notice sent="{ $today }">
    <days-late>{ days-from-duration($today - $due) }</days-late>
  </overdue-notice> as last into $order
)
```

**C# with LINQ to XML:**
```csharp
var today = DateTime.Now;
var overdueOrders = doc.Descendants("order")
    .Where(o => o.Attribute("status")?.Value == "pending"
        && DateTime.Parse(o.Attribute("due-date")?.Value ?? "") < today);

foreach (var order in overdueOrders.ToList())
{
    order.SetAttributeValue("status", "overdue");
    var daysLate = (today - DateTime.Parse(order.Attribute("due-date").Value)).Days;
    order.Add(new XElement("overdue-notice",
        new XAttribute("sent", today.ToString("yyyy-MM-dd")),
        new XElement("days-late", daysLate)
    ));
}
doc.Save("orders.xml");
```

The XQuery version is more concise, and the atomic application of the PUL means you don't have to worry about partial failures — either all overdue orders are updated, or none are.
