---
title: Extensibility
description: "Extending XQuery with custom functions, modules, external functions, and .NET integration"
sort: 12
---

# Extensibility

Real projects outgrow the standard library quickly. You need domain-specific functions, integration with external systems, and custom processing logic. XQuery's extensibility model lets you build reusable libraries, declare functions whose implementation lives in the host environment, and integrate deeply with .NET applications.

If you have worked with C# extension methods, MEF/plugin systems, or `IServiceProvider` dependency injection, you already understand the motivation: make the language do what your application needs, not just what the specification committee anticipated.

## Contents

- [Why Extensibility Matters](#why-extensibility-matters)
- [User-Defined Functions](#user-defined-functions)
- [Library Modules](#library-modules)
- [External Functions](#external-functions)
- [.NET Integration with PhoenixmlDb](#net-integration-with-phoenixmldb)
- [Extension Namespaces](#extension-namespaces)
- [Database Integration](#database-integration)
- [Combining with Other .NET Libraries](#combining-with-other-net-libraries)
- [Practical Patterns](#practical-patterns)

---

## Why Extensibility Matters

Standard XQuery gives you powerful data querying and transformation. But consider what a real application needs:

- **Send an email** when an order exceeds a threshold
- **Call a REST API** to enrich customer data with external information
- **Validate** a document against business rules that change monthly
- **Format** output using company-specific templates
- **Log** query activity to an audit trail
- **Generate** PDF invoices from XML order data

None of these are in the XQuery specification. Extensibility bridges the gap between what XQuery provides and what your application requires.

**C# parallel:**
```csharp
// C# solves the same problem with extension methods, DI, and plugins
public static class OrderExtensions
{
    // Domain-specific logic added to existing types
    public static decimal CalculateTax(this Order order, string state) { /* ... */ }
    public static bool RequiresApproval(this Order order) => order.Total > 10_000m;
}

// Dependency injection — runtime-provided implementations
services.AddScoped<IEmailService, SmtpEmailService>();
services.AddScoped<IPaymentGateway, StripeGateway>();
```

XQuery achieves the same extensibility through user-defined functions, library modules, external functions, and host-environment integration.

---

## User-Defined Functions

This section provides a brief recap. For comprehensive coverage, see [Functions and Modules](functions-modules.md).

Functions are the basic unit of reuse in XQuery:

```xquery
declare function local:calculate-tax(
  $amount as xs:decimal,
  $state as xs:string
) as xs:decimal {
  let $rate := switch ($state)
    case "CA" return 0.0725
    case "NY" return 0.08
    case "TX" return 0.0625
    default return 0.05
  return round($amount * $rate, 2)
};

local:calculate-tax(199.99, "CA")
(: Result: 14.50 :)
```

Functions can be recursive, accept and return functions (higher-order), and work with any XQuery type — sequences, maps, arrays, and XML nodes.

---

## Library Modules

Library modules package functions into reusable units that any query can import. They are the XQuery equivalent of C# class libraries or NuGet packages.

### Creating a Module

A library module file starts with a `module namespace` declaration and contains only function and variable declarations — no body expression:

```xquery
(: file: lib/string-utils.xqm :)
module namespace str = "http://example.com/string-utils";

declare function str:title-case($text as xs:string) as xs:string {
  string-join(
    for $word in tokenize($text, "\s+")
    return concat(
      upper-case(substring($word, 1, 1)),
      lower-case(substring($word, 2))
    ),
    " "
  )
};

declare function str:slug($text as xs:string) as xs:string {
  replace(lower-case(normalize-space($text)), "[^a-z0-9]+", "-")
};

declare function str:truncate(
  $text as xs:string,
  $max as xs:integer
) as xs:string {
  if (string-length($text) <= $max) then $text
  else concat(substring($text, 1, $max - 3), "...")
};
```

**C# parallel:**
```csharp
// A class library project: StringUtils.cs
namespace Example.StringUtils;

public static class StringHelpers
{
    public static string TitleCase(string text) =>
        CultureInfo.CurrentCulture.TextInfo.ToTitleCase(text.ToLower());

    public static string Slug(string text) =>
        Regex.Replace(text.ToLower().Trim(), @"[^a-z0-9]+", "-");

    public static string Truncate(string text, int max) =>
        text.Length <= max ? text : text[..(max - 3)] + "...";
}
```

### Importing a Module

```xquery
import module namespace str = "http://example.com/string-utils" at "lib/string-utils.xqm";

str:title-case("hello world")  (: Result: "Hello World" :)
str:slug("My Blog Post!")       (: Result: "my-blog-post-" :)
```

### Module Location Resolution

The `at` clause specifies where the processor should find the module file. This can be:

- **A relative path** — resolved against the base URI of the importing module:
  ```xquery
  import module namespace util = "http://example.com/util" at "lib/util.xqm";
  ```
- **An absolute path** — a full file path or URL:
  ```xquery
  import module namespace util = "http://example.com/util"
    at "file:///opt/xquery-libs/util.xqm";
  ```
- **Omitted** — the processor resolves the module by namespace URI using a module repository or catalog:
  ```xquery
  import module namespace util = "http://example.com/util";
  (: The processor knows where to find this namespace :)
  ```

### Versioning with Namespaces

Use namespace URIs to version your modules:

```xquery
(: Version 1 :)
module namespace api-v1 = "http://example.com/api/v1";

(: Version 2 — new features, breaking changes :)
module namespace api-v2 = "http://example.com/api/v2";
```

Callers import the version they need:

```xquery
(: Legacy queries use v1 :)
import module namespace api = "http://example.com/api/v1" at "api-v1.xqm";

(: New queries use v2 :)
import module namespace api = "http://example.com/api/v2" at "api-v2.xqm";
```

### Building a Module Library

A realistic project might organize modules like this:

```
lib/
  string-utils.xqm      (: string manipulation :)
  date-utils.xqm         (: date formatting and parsing :)
  validation.xqm         (: business rule validation :)
  formatting.xqm         (: output formatting :)
  db/
    queries.xqm          (: common database queries :)
    indexes.xqm          (: index management :)
  api/
    rest-client.xqm      (: REST API helpers :)
    auth.xqm             (: authentication functions :)
```

```xquery
(: A main module importing several library modules :)
import module namespace str = "http://example.com/strings" at "lib/string-utils.xqm";
import module namespace dt = "http://example.com/dates" at "lib/date-utils.xqm";
import module namespace val = "http://example.com/validation" at "lib/validation.xqm";
import module namespace db = "http://example.com/db" at "lib/db/queries.xqm";
```

---

## External Functions

External functions are declared in XQuery but implemented by the host environment. The XQuery file specifies the function signature; the host (your .NET application) provides the actual code.

### Declaring External Functions

```xquery
(: Declare an external function — no body, just a signature :)
declare namespace app = "http://example.com/app";

declare function app:send-email(
  $to as xs:string,
  $subject as xs:string,
  $body as xs:string
) as xs:boolean external;

declare function app:log(
  $level as xs:string,
  $message as xs:string
) external;

declare function app:get-config(
  $key as xs:string
) as xs:string? external;
```

The `external` keyword tells the processor that the function body is not in XQuery — it will be provided at runtime by the host.

### Using External Functions

Once declared, external functions are called like any other function:

```xquery
declare namespace app = "http://example.com/app";
declare function app:send-email($to as xs:string, $subject as xs:string, $body as xs:string) as xs:boolean external;
declare function app:log($level as xs:string, $message as xs:string) external;

for $order in //order[total > 10000]
let $customer := //customer[@id = $order/customer-id]
let $email-sent := app:send-email(
  $customer/email,
  concat("Large order #", $order/@id, " requires approval"),
  concat("Order total: $", $order/total)
)
return (
  app:log("INFO", concat("Notification sent for order ", $order/@id, ": ", $email-sent)),
  <processed order-id="{ $order/@id }" notified="{ $email-sent }"/>
)
```

**C# parallel:**
```csharp
// External functions are like interface methods — declared but not implemented
// The host provides the implementation, similar to dependency injection
public interface INotificationService
{
    bool SendEmail(string to, string subject, string body);
    void Log(string level, string message);
    string? GetConfig(string key);
}

// At runtime, a concrete implementation is injected
services.AddScoped<INotificationService, SmtpNotificationService>();
```

---

## .NET Integration with PhoenixmlDb

PhoenixmlDb provides a .NET API for running XQuery from C# applications. This is how you connect the XQuery world to the .NET world.

### Setting External Variables from C#

Pass data from your .NET application into an XQuery query:

```csharp
var engine = new XQueryEngine();

// Simple types
engine.SetVariable("user-id", "U12345");
engine.SetVariable("page", 1);
engine.SetVariable("page-size", 25);
engine.SetVariable("include-archived", false);
engine.SetVariable("report-date", DateTime.Now.ToString("yyyy-MM-dd"));

// Execute the query
string xquery = File.ReadAllText("reports/user-orders.xq");
var result = await engine.ExecuteAsync(xquery);
```

The XQuery file declares matching external variables:

```xquery
declare variable $user-id as xs:string external;
declare variable $page as xs:integer external;
declare variable $page-size as xs:integer external := 25;
declare variable $include-archived as xs:boolean external := false();
declare variable $report-date as xs:date external;

for $order in collection("orders")/order[customer-id = $user-id]
where if ($include-archived) then true() else $order/status != "archived"
order by xs:date($order/date) descending
return $order
```

### Passing XML Documents

```csharp
// Load an XML document and pass it to the query
var xmlDoc = XDocument.Load("data/customers.xml");
engine.SetVariable("input", xmlDoc);

string xquery = @"
    declare variable $input external;
    for $c in $input//customer
    where $c/status = 'active'
    return $c/name/text()
";

var result = await engine.ExecuteAsync(xquery);
```

### Registering Extension Functions from .NET

Register C# methods as XQuery functions, making them callable from within queries:

```csharp
var engine = new XQueryEngine();

// Register a simple function
engine.RegisterFunction(
    "http://example.com/app",  // namespace URI
    "get-exchange-rate",       // local name
    (string fromCurrency, string toCurrency) =>
    {
        // Call an external API or database
        return GetExchangeRate(fromCurrency, toCurrency);
    }
);

// Register a function that sends email
engine.RegisterFunction(
    "http://example.com/app",
    "send-email",
    (string to, string subject, string body) =>
    {
        var client = new SmtpClient("smtp.example.com");
        var message = new MailMessage("noreply@example.com", to, subject, body);
        client.Send(message);
        return true;
    }
);

// Register a function that accesses configuration
engine.RegisterFunction(
    "http://example.com/app",
    "get-config",
    (string key) => Configuration[key]
);
```

Now XQuery can call these functions:

```xquery
declare namespace app = "http://example.com/app";
declare function app:get-exchange-rate($from as xs:string, $to as xs:string) as xs:decimal external;
declare function app:send-email($to as xs:string, $subject as xs:string, $body as xs:string) as xs:boolean external;
declare function app:get-config($key as xs:string) as xs:string? external;

let $rate := app:get-exchange-rate("USD", "EUR")
let $threshold := xs:decimal(app:get-config("order-alert-threshold"))

for $order in //order[total * $rate > $threshold]
return app:send-email(
  $order/customer/email,
  concat("Large order alert: #", $order/@id),
  concat("Total (EUR): ", round($order/total * $rate, 2))
)
```

### Reading Query Results Back into .NET Types

```csharp
var engine = new XQueryEngine();

string xquery = @"
    for $p in collection('products')/product
    where $p/price > 100
    order by $p/price descending
    return
      map {
        'id': string($p/@id),
        'name': $p/name/text(),
        'price': number($p/price),
        'category': $p/category/text()
      }
";

var results = await engine.ExecuteAsync(xquery);

// Map to C# objects
var products = results.Select(r => new Product
{
    Id = r["id"]?.ToString(),
    Name = r["name"]?.ToString(),
    Price = Convert.ToDecimal(r["price"]),
    Category = r["category"]?.ToString()
}).ToList();

// Or work with XML results directly
string xmlQuery = @"
    <products>{
      for $p in collection('products')/product
      where $p/price > 100
      return $p
    }</products>
";

var xmlResult = await engine.ExecuteAsync(xmlQuery);
var xdoc = XDocument.Parse(xmlResult.ToString());
```

### Using the XQuery Engine Programmatically

A complete example showing the engine lifecycle:

```csharp
public class OrderReportService
{
    private readonly XQueryEngine _engine;
    private readonly IConfiguration _config;

    public OrderReportService(XQueryEngine engine, IConfiguration config)
    {
        _engine = engine;
        _config = config;

        // Register extension functions once
        _engine.RegisterFunction("http://example.com/app", "format-currency",
            (decimal amount, string currency) =>
                amount.ToString("C", CultureInfo.GetCultureInfo(
                    currency == "EUR" ? "de-DE" : "en-US")));

        _engine.RegisterFunction("http://example.com/app", "current-user",
            () => Thread.CurrentPrincipal?.Identity?.Name ?? "anonymous");
    }

    public async Task<string> GenerateReportAsync(
        string department, DateTime startDate, DateTime endDate)
    {
        _engine.SetVariable("department", department);
        _engine.SetVariable("start-date", startDate.ToString("yyyy-MM-dd"));
        _engine.SetVariable("end-date", endDate.ToString("yyyy-MM-dd"));
        _engine.SetVariable("report-title",
            $"{department} Report: {startDate:MMM d} - {endDate:MMM d, yyyy}");

        string query = await File.ReadAllTextAsync("queries/department-report.xq");
        var result = await _engine.ExecuteAsync(query);
        return result.ToString();
    }
}
```

---

## Extension Namespaces

When creating extension functions, follow namespace conventions to avoid collisions and communicate intent:

```xquery
(: Application-specific extensions :)
declare namespace app = "http://yourcompany.com/app";

(: Domain-specific extensions :)
declare namespace crm = "http://yourcompany.com/crm";
declare namespace inv = "http://yourcompany.com/inventory";

(: Infrastructure extensions :)
declare namespace log = "http://yourcompany.com/logging";
declare namespace cache = "http://yourcompany.com/cache";
```

**Conventions:**
- Use your organization's domain in the namespace URI
- Group related functions under the same namespace
- Use meaningful prefixes that are short but descriptive
- Document your extension namespaces for other developers

**C# parallel:**
```csharp
// Same principle as C# namespace conventions
namespace YourCompany.App { /* ... */ }
namespace YourCompany.CRM { /* ... */ }
namespace YourCompany.Infrastructure.Logging { /* ... */ }
```

---

## Database Integration

PhoenixmlDb stores XML documents in collections. XQuery accesses them through `doc()` and `collection()`:

### Accessing Documents

```xquery
(: Load a single document by URI :)
let $config := doc("config.xml")

(: Query all documents in a collection :)
for $customer in collection("customers")/customer
where $customer/status = "active"
return $customer

(: Query across multiple collections :)
for $order in collection("orders")/order
let $customer := collection("customers")/customer[@id = $order/customer-id]
return
  <order-summary>
    <order-id>{ string($order/@id) }</order-id>
    <customer-name>{ $customer/name/text() }</customer-name>
    <total>{ $order/total/text() }</total>
  </order-summary>
```

### Managing Collections from .NET

```csharp
var db = new PhoenixmlDatabase("connection-string");

// Store documents
await db.StoreDocumentAsync("customers", "C001.xml", customerXml);
await db.StoreDocumentAsync("orders", "O5001.xml", orderXml);

// Run a query against stored collections
var engine = db.CreateQueryEngine();
string xquery = @"
    for $c in collection('customers')/customer
    where $c/total-orders > 10
    order by $c/total-orders descending
    return $c
";

var topCustomers = await engine.ExecuteAsync(xquery);
```

---

## Combining with Other .NET Libraries

XQuery results flow naturally into the rest of the .NET ecosystem.

### XQuery Results to System.Text.Json

```csharp
// Execute XQuery that returns maps (JSON-friendly)
string xquery = @"
    array {
      for $p in collection('products')/product
      return map {
        'id': string($p/@id),
        'name': $p/name/text(),
        'price': number($p/price)
      }
    }
";

var result = await engine.ExecuteAsync(xquery);

// Serialize to JSON
string json = JsonSerializer.Serialize(result, new JsonSerializerOptions
{
    WriteIndented = true
});
```

### XQuery Results to HttpClient

```csharp
// Build an API request payload from XQuery results
var payload = await engine.ExecuteAsync(@"
    <request>
      <orders>{
        for $o in collection('orders')/order[status = 'pending']
        return
          <order id='{ $o/@id }'>
            <total>{ $o/total/text() }</total>
          </order>
      }</orders>
    </request>
");

var httpClient = new HttpClient();
var content = new StringContent(payload.ToString(), Encoding.UTF8, "application/xml");
var response = await httpClient.PostAsync("https://api.example.com/process", content);
```

### XQuery with Entity Framework

```csharp
// Use XQuery to transform data that came from a relational database
var orders = await context.Orders
    .Where(o => o.Status == "shipped")
    .Select(o => new { o.Id, o.CustomerName, o.Total, o.ShipDate })
    .ToListAsync();

// Convert to XML for XQuery processing
var xml = new XElement("orders",
    orders.Select(o => new XElement("order",
        new XAttribute("id", o.Id),
        new XElement("customer", o.CustomerName),
        new XElement("total", o.Total),
        new XElement("ship-date", o.ShipDate?.ToString("yyyy-MM-dd") ?? "")
    )));

engine.SetVariable("input", xml.ToString());

string xquery = @"
    declare variable $input external;
    let $orders := parse-xml($input)/orders

    <shipping-report generated='{ current-dateTime() }'>
    {
      for $order in $orders/order
      group by $date := $order/ship-date
      order by $date descending
      return
        <day date='{ $date }' count='{ count($order) }'
             total='{ sum($order/total) }'/>
    }
    </shipping-report>
";

var report = await engine.ExecuteAsync(xquery);
```

---

## Practical Patterns

### Custom Validation Functions

Build domain-specific validation as a library module, then call it from queries or from .NET:

```xquery
(: file: lib/validation.xqm :)
module namespace val = "http://example.com/validation";

declare function val:validate-order($order as element(order)) as element(errors)? {
  let $errors := (
    if (not($order/customer-id))
    then <error field="customer-id">Customer ID is required</error>
    else (),

    if (not($order/items/item))
    then <error field="items">Order must have at least one item</error>
    else (),

    if (xs:decimal($order/total) <= 0)
    then <error field="total">Total must be positive</error>
    else (),

    for $item in $order/items/item
    where xs:integer($item/quantity) <= 0
    return <error field="item-{ $item/@sku }">
      Quantity must be positive for SKU { string($item/@sku) }
    </error>
  )
  return
    if (exists($errors))
    then <errors>{ $errors }</errors>
    else ()
};
```

```xquery
(: Main query using validation :)
import module namespace val = "http://example.com/validation" at "lib/validation.xqm";

for $order in collection("pending-orders")/order
let $errors := val:validate-order($order)
return
  if ($errors)
  then <rejected order-id="{ $order/@id }">{ $errors }</rejected>
  else <accepted order-id="{ $order/@id }"/>
```

### Data Enrichment — Calling External APIs

Use external functions to enrich XML data with information from external services:

```xquery
declare namespace geo = "http://example.com/geo";
declare function geo:geocode($address as xs:string) as element(location)? external;
declare function geo:distance($lat1 as xs:decimal, $lon1 as xs:decimal,
                               $lat2 as xs:decimal, $lon2 as xs:decimal) as xs:decimal external;

let $warehouse := geo:geocode("123 Warehouse Blvd, Chicago, IL")

for $customer in collection("customers")/customer
let $location := geo:geocode($customer/address/text())
let $dist := geo:distance(
  $warehouse/lat, $warehouse/lon,
  $location/lat, $location/lon
)
order by $dist
return
  <customer name="{ $customer/name/text() }"
            distance-miles="{ round($dist, 1) }"
            shipping-zone="{ if ($dist < 100) then 'local'
                             else if ($dist < 500) then 'regional'
                             else 'national' }"/>
```

The .NET application registers the `geo:geocode` and `geo:distance` functions using its own geocoding service.

### Report Generation

```xquery
declare namespace fmt = "http://example.com/format";
declare function fmt:currency($amount as xs:decimal) as xs:string external;

declare variable $report-date as xs:date external;

<report date="{ $report-date }">
  <summary>
  {
    let $orders := collection("orders")/order[xs:date(date) = $report-date]
    return (
      <total-orders>{ count($orders) }</total-orders>,
      <total-revenue>{ fmt:currency(sum($orders/total)) }</total-revenue>,
      <average-order>{ fmt:currency(avg($orders/total)) }</average-order>
    )
  }
  </summary>
  <by-category>
  {
    for $order in collection("orders")/order[xs:date(date) = $report-date]
    group by $cat := $order/category
    order by sum($order/total) descending
    return
      <category name="{ $cat }"
                orders="{ count($order) }"
                revenue="{ fmt:currency(sum($order/total)) }"/>
  }
  </by-category>
</report>
```

### ETL Pipeline — XQuery with .NET Processing

Combine XQuery transformation with .NET I/O and business logic:

```csharp
public class EtlPipeline
{
    private readonly XQueryEngine _engine;

    public async Task RunDailyImportAsync()
    {
        // 1. Extract — load source data
        string sourceXml = await File.ReadAllTextAsync("/data/daily-feed.xml");
        _engine.SetVariable("source", sourceXml);
        _engine.SetVariable("import-date", DateTime.Now.ToString("yyyy-MM-dd"));

        // 2. Transform — XQuery handles the heavy lifting
        string transformQuery = await File.ReadAllTextAsync("etl/transform.xq");
        var transformed = await _engine.ExecuteAsync(transformQuery);

        // 3. Validate — XQuery validation module
        _engine.SetVariable("data", transformed.ToString());
        string validateQuery = await File.ReadAllTextAsync("etl/validate.xq");
        var validation = await _engine.ExecuteAsync(validateQuery);

        if (validation.ToString().Contains("<errors>"))
        {
            await File.WriteAllTextAsync(
                $"/logs/validation-errors-{DateTime.Now:yyyyMMdd}.xml",
                validation.ToString());
            throw new InvalidDataException("Validation failed. See error log.");
        }

        // 4. Load — store in PhoenixmlDb
        var db = new PhoenixmlDatabase("connection-string");
        var docs = XDocument.Parse(transformed.ToString())
            .Descendants("record");

        foreach (var doc in docs)
        {
            string id = doc.Attribute("id")?.Value ?? Guid.NewGuid().ToString();
            await db.StoreDocumentAsync("imported-records", $"{id}.xml", doc.ToString());
        }
    }
}
```

The transformation query:

```xquery
(: file: etl/transform.xq :)
declare variable $source external;
declare variable $import-date as xs:date external;

let $feed := parse-xml($source)/feed

return
  <records imported="{ $import-date }">
  {
    for $item in $feed/item
    where $item/status != "deleted"
    return
      <record id="{ $item/@id }">
        <name>{ normalize-space($item/name) }</name>
        <category>{ lower-case($item/type) }</category>
        <price>{ round(xs:decimal($item/price), 2) }</price>
        <imported-on>{ $import-date }</imported-on>
      </record>
  }
  </records>
```
