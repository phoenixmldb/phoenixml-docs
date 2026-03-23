---
title: Prolog and Declarations
description: "XQuery prolog — module declarations, namespace imports, options, and configuration"
sort: 11
---

# Prolog and Declarations

Every XQuery file begins with an optional **prolog** — a header section that sets up the execution environment before the main query body runs. The prolog declares namespaces, imports modules, defines variables and functions, and configures serialization.

If you are coming from C#, the prolog is a combination of `using` directives, assembly-level attributes, `.csproj` properties, and global configuration — all in one place at the top of the file.

## Contents

- [What the Prolog Is](#what-the-prolog-is)
- [Version Declaration](#version-declaration)
- [Module Declaration](#module-declaration)
- [Namespace Declarations](#namespace-declarations)
- [Imports](#imports)
- [Variable Declarations](#variable-declarations)
- [Option Declarations](#option-declarations)
- [Environment Settings](#environment-settings)
- [Declaration Order](#declaration-order)
- [Main Module vs Library Module](#main-module-vs-library-module)
- [Complete Example](#complete-example)

---

## What the Prolog Is

An XQuery file has two parts:

1. **Prolog** — declarations that configure the environment (optional)
2. **Body** — the expression that produces results (required in main modules)

```xquery
(: === PROLOG === :)
xquery version "4.0";
declare namespace app = "http://example.com/app";
import module namespace util = "http://example.com/util" at "util.xqm";
declare variable $config := map { "debug": true() };

(: === BODY === :)
<result>{ util:process(collection("data"), $config) }</result>
```

**C# parallel:**
```csharp
// === "Prolog" in C# ===
using System;                           // namespace import
using MyApp.Utilities;                  // module import
// assembly attributes, global usings, etc.

// === "Body" in C# ===
public class Program
{
    static void Main() { /* ... */ }    // the executable part
}
```

The prolog is not just syntactic sugar. It controls fundamental behaviors: how namespaces resolve, what modules are available, how output is serialized, how empty sequences sort, and more.

---

## Version Declaration

The version declaration must be the very first thing in the file (before any comments or whitespace):

```xquery
xquery version "4.0";
```

This tells the processor which version of the XQuery specification to use. Common values:

| Version | Notes |
|---------|-------|
| `"1.0"` | Original XQuery (2007) |
| `"3.0"` | Maps, arrays, try/catch, group by (2014) |
| `"3.1"` | JSON support, arrow operator, string constructors (2017) |
| `"4.0"` | Latest — enhanced maps/arrays, `otherwise`, `for member` (2024) |

You can also specify the encoding:

```xquery
xquery version "4.0" encoding "UTF-8";
```

**C# parallel:**
```csharp
// C# language version in .csproj
<PropertyGroup>
    <LangVersion>12.0</LangVersion>
</PropertyGroup>
```

If you omit the version declaration, the processor uses its default version (typically the latest it supports).

---

## Module Declaration

A **module declaration** turns an XQuery file into a library module — a reusable package of functions and variables that other queries can import. Library modules have no body expression; they only provide declarations.

```xquery
module namespace util = "http://example.com/util";

(: This file is now a library module.
   It can only contain function and variable declarations.
   It cannot have a query body. :)

declare function util:format-date($date as xs:date) as xs:string {
  format-date($date, "[MNn] [D], [Y]")
};

declare function util:truncate($text as xs:string, $max as xs:integer) as xs:string {
  if (string-length($text) > $max)
  then concat(substring($text, 1, $max - 3), "...")
  else $text
};
```

The `module namespace` declaration binds a prefix (`util`) to a namespace URI (`http://example.com/util`). Every function and variable in the module must use this namespace prefix.

**C# parallel:**
```csharp
// A C# class library (reusable, no Main method)
namespace Example.Util;

public static class StringHelpers
{
    public static string Truncate(string text, int max) =>
        text.Length > max ? text[..(max - 3)] + "..." : text;
}
```

---

## Namespace Declarations

Namespaces prevent name collisions, just like C# namespaces. XQuery provides several ways to declare them.

### Explicit Namespace Declaration

```xquery
declare namespace app = "http://example.com/app";
declare namespace hr = "http://example.com/hr";

(: Now use the prefixes in the query :)
//hr:employee[hr:department = "Engineering"]
```

### Default Element Namespace

Sets the namespace for element names that have no prefix:

```xquery
declare default element namespace "http://www.w3.org/1999/xhtml";

(: These unprefixed elements are now in the XHTML namespace :)
<html>
  <head><title>Page</title></head>
  <body><p>Content</p></body>
</html>
```

Without this declaration, unprefixed elements are in no namespace.

### Default Function Namespace

Sets the namespace for unqualified function calls:

```xquery
declare default function namespace "http://example.com/app";

(: Calls http://example.com/app:process(), not fn:process() :)
process($data)
```

By default, the function namespace is `http://www.w3.org/2005/xpath-functions` (the `fn` namespace), so unqualified function calls like `count()`, `string()`, `contains()` resolve to the standard XPath functions.

### Pre-Declared Namespaces

These namespaces are always available without declaring them:

| Prefix | Namespace URI | Purpose |
|--------|---------------|---------|
| `fn` | `http://www.w3.org/2005/xpath-functions` | Standard functions: `fn:count()`, `fn:string()` |
| `xs` | `http://www.w3.org/2001/XMLSchema` | Schema types: `xs:integer`, `xs:string`, `xs:date` |
| `xsi` | `http://www.w3.org/2001/XMLSchema-instance` | Schema instance attributes |
| `xml` | `http://www.w3.org/XML/1998/namespace` | `xml:lang`, `xml:space` |
| `math` | `http://www.w3.org/2005/xpath-functions/math` | Math functions: `math:pi()`, `math:sqrt()` |
| `map` | `http://www.w3.org/2005/xpath-functions/map` | Map functions: `map:keys()`, `map:merge()` |
| `array` | `http://www.w3.org/2005/xpath-functions/array` | Array functions: `array:size()`, `array:join()` |
| `local` | `http://www.w3.org/2005/xquery-local-functions` | Local functions in main modules |

**C# parallel:**
```csharp
// Pre-declared namespaces are like C#'s implicit global usings
// In .NET 6+, these are available without explicit "using":
// System, System.Collections.Generic, System.Linq, System.Threading.Tasks, etc.
```

---

## Imports

### Module Import

Imports functions and variables from a library module:

```xquery
import module namespace util = "http://example.com/util" at "util.xqm";
import module namespace db = "http://example.com/db" at "lib/database.xqm";
```

The `at` clause specifies the physical location of the module file. Some processors can resolve modules by namespace URI alone (using a catalog or repository), making the `at` clause optional.

After importing, you can use the module's functions and variables:

```xquery
import module namespace str = "http://example.com/strings" at "strings.xqm";

str:capitalize("hello world")
(: Result: "Hello World" :)
```

### Importing Modules with Annotated Declarations

When a library module uses `%public` and `%private` annotations, only the `%public` (or unannotated, which defaults to public) declarations are visible to the importer:

```xquery
(: strings.xqm :)
module namespace str = "http://example.com/strings";

declare %public function str:capitalize($text as xs:string) as xs:string {
  str:apply-case-rule($text, "upper")
};

declare %private function str:apply-case-rule($text as xs:string, $rule as xs:string) as xs:string {
  (: internal implementation — not visible to importers :)
  ...
};
```

```xquery
(: main.xq :)
import module namespace str = "http://example.com/strings" at "strings.xqm";

str:capitalize("hello")         (: OK — %public :)
(: str:apply-case-rule(...)     ERROR — %private, not accessible :)
```

**C# parallel:**
```csharp
// C# project reference + using
// In .csproj: <ProjectReference Include="../Util/Util.csproj" />
using Example.Util;

StringHelpers.Capitalize("hello world");
```

### Multiple Module Locations

A single namespace can be implemented across multiple files:

```xquery
import module namespace util = "http://example.com/util"
  at "util-strings.xqm", "util-dates.xqm", "util-numbers.xqm";
```

### Schema Import

Imports an XML Schema for type-aware processing:

```xquery
import schema namespace tns = "http://example.com/orders" at "orders.xsd";

(: Now you can use schema-defined types :)
declare variable $order as schema-element(tns:order) := doc("order.xml")/tns:order;
```

Schema imports enable the processor to validate data against the schema and use schema-defined types in type annotations.

**C# parallel:**
```csharp
// Like generating C# classes from an XSD with xsd.exe or XmlSchemaClassGenerator
// xsd.exe /c orders.xsd
// Then using the generated types for strongly-typed access
```

---

## Variable Declarations

### Simple Variable

```xquery
declare variable $app-name := "Customer Portal";
declare variable $max-results := 100;
declare variable $debug := false();
```

### Typed Variable

Adding a type annotation provides compile-time checking:

```xquery
declare variable $count as xs:integer := 0;
declare variable $rate as xs:decimal := 0.085;
declare variable $start-date as xs:date := xs:date("2025-01-01");
```

**C# parallel:**
```csharp
const string AppName = "Customer Portal";
const int MaxResults = 100;
static readonly DateTime StartDate = new DateTime(2025, 1, 1);
```

### External Variables

External variables are declared in the query but their values are provided by the calling environment (a .NET application, a command-line tool, or a database engine):

```xquery
(: Declared in the query — no default value :)
declare variable $user-id as xs:string external;
declare variable $page as xs:integer external;

(: Declared with a default value — the caller may override it :)
declare variable $page-size as xs:integer external := 25;
```

The caller provides the values:

```csharp
// C# — setting external variables before execution
var engine = new XQueryEngine();
engine.SetVariable("user-id", userId);
engine.SetVariable("page", currentPage);
// page-size not set — defaults to 25

var results = await engine.ExecuteAsync(query);
```

**C# parallel:**
```csharp
// External variables are like method parameters or configuration values
public static IEnumerable<Order> GetOrders(string userId, int page, int pageSize = 25)
{
    // userId and page are required; pageSize has a default
}
```

### Annotations on Declarations

Variable and function declarations can carry **annotations** that control visibility and convey metadata. Annotations are prefixed with `%` and appear before the `variable` or `function` keyword:

```xquery
(: Visibility annotations :)
declare %public variable $api-version := "2.0";
declare %private variable $internal-key := "abc123";

(: Function annotations :)
declare %public function local:get-data() { collection("data") };
declare %private function local:validate($x) { ... };
```

The two built-in annotations are:

| Annotation | Meaning | Default |
|------------|---------|---------|
| `%public` | Visible to importing modules | Yes (functions and variables are public by default) |
| `%private` | Hidden from importing modules | No |

Processors and frameworks may define additional annotations. For example, REST API frameworks often use annotations like `%rest:path("/endpoint")` and `%rest:GET` to bind XQuery functions to HTTP routes.

**C# parallel:**
```csharp
// Annotations are like C# access modifiers + attributes
public static string ApiVersion = "2.0";         // %public
private static string InternalKey = "abc123";     // %private

[HttpGet("/endpoint")]                            // %rest:path, %rest:GET
public IActionResult GetData() { ... }
```

### Complex Variable Values

Variables can hold any XQuery value — sequences, maps, arrays, XML nodes:

```xquery
declare variable $config := map {
  "database": "production",
  "max-connections": 10,
  "features": ["search", "export", "notifications"]
};

declare variable $template :=
  <email>
    <from>noreply@example.com</from>
    <subject/>
    <body/>
  </email>;

declare variable $valid-statuses := ("active", "pending", "suspended");
```

---

## Option Declarations

Option declarations configure the processor's behavior, most commonly serialization (how results are output).

### Serialization Options

Serialization options control the format of the query's output. They use the `output` namespace:

```xquery
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Output as indented XML :)
declare option output:method "xml";
declare option output:indent "yes";
declare option output:encoding "UTF-8";
```

```xquery
(: Output as HTML5 :)
declare option output:method "html";
declare option output:html-version "5";
declare option output:indent "yes";
```

```xquery
(: Output as JSON :)
declare option output:method "json";
declare option output:indent "yes";
```

```xquery
(: Output as plain text :)
declare option output:method "text";
```

**JSON serialization** is a common use case — output XQuery maps and arrays as JSON:

```xquery
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:indent "yes";

map {
  "users": array {
    for $u in collection("users")/user
    return map {
      "id": string($u/@id),
      "name": string($u/name),
      "email": string($u/email)
    }
  }
}
```

This query produces formatted JSON output directly, combining XQuery's data querying with JSON serialization.

Common serialization options:

| Option | Values | Default | Purpose |
|--------|--------|---------|---------|
| `output:method` | `xml`, `html`, `xhtml`, `text`, `json`, `adaptive` | `xml` | Output format |
| `output:indent` | `yes`, `no` | `no` | Pretty-print output |
| `output:encoding` | `UTF-8`, `ISO-8859-1`, etc. | `UTF-8` | Character encoding |
| `output:omit-xml-declaration` | `yes`, `no` | `no` | Include `<?xml ... ?>` header |
| `output:standalone` | `yes`, `no`, `omit` | `omit` | Standalone attribute in XML declaration |
| `output:media-type` | MIME type string | varies by method | Content type hint |

**C# parallel:**
```csharp
// Serialization settings in C#
var settings = new XmlWriterSettings
{
    Indent = true,
    Encoding = Encoding.UTF8,
    OmitXmlDeclaration = false
};

// Or for JSON:
var options = new JsonSerializerOptions
{
    WriteIndented = true,
    Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
};
```

---

## Environment Settings

These declarations control the processor's behavior for the entire module.

### Construction Mode

Controls whether type annotations are preserved on copied nodes:

```xquery
declare construction preserve;  (: keep original type annotations :)
declare construction strip;     (: remove type annotations — default :)
```

### Ordering Mode

Controls whether the processor is required to maintain document order:

```xquery
declare ordering ordered;      (: maintain document order — default :)
declare ordering unordered;    (: processor may reorder for optimization :)
```

Using `unordered` can improve performance when you do not care about result order (for example, when counting or aggregating).

### Empty Order

Controls where empty sequences sort in `order by` clauses:

```xquery
declare default order empty greatest;  (: empty sorts last in ascending :)
declare default order empty least;     (: empty sorts first in ascending — default :)
```

```xquery
(: Practical impact :)
for $emp in //employee
order by $emp/middle-name  (: some employees have no middle name :)
return $emp/name

(: With "empty greatest": employees without middle names sort last :)
(: With "empty least": employees without middle names sort first :)
```

**C# parallel:**
```csharp
// C# LINQ equivalent
employees.OrderBy(e => e.MiddleName ?? "")       // empty least
employees.OrderBy(e => e.MiddleName ?? "\uFFFF")  // empty greatest
```

### Boundary Space

Controls how whitespace between constructors is handled:

```xquery
declare boundary-space preserve;  (: keep whitespace between expressions :)
declare boundary-space strip;     (: remove boundary whitespace — default :)
```

```xquery
(: With boundary-space preserve: :)
<name>{ $first } { $last }</name>
(: Result: <name>John Smith</name>  (space between first and last is preserved) :)

(: With boundary-space strip: :)
<name>{ $first }{ $last }</name>
(: Result: <name>JohnSmith</name>  (you must add space explicitly) :)
```

### Copy Namespaces

Controls namespace handling when nodes are copied:

```xquery
declare copy-namespaces preserve, inherit;    (: default :)
declare copy-namespaces no-preserve, inherit;
declare copy-namespaces preserve, no-inherit;
declare copy-namespaces no-preserve, no-inherit;
```

- **preserve** / **no-preserve** — whether in-scope namespaces from the original node are copied
- **inherit** / **no-inherit** — whether the copied node inherits namespaces from its new parent

### Base URI

Sets the base URI for resolving relative URIs in `doc()`, `collection()`, and other functions:

```xquery
declare base-uri "https://data.example.com/";

doc("customers.xml")  (: resolves to https://data.example.com/customers.xml :)
```

### Default Collation

Sets the default collation for string comparisons and sorting:

```xquery
declare default collation "http://www.w3.org/2013/collation/UCA?lang=en;strength=secondary";
```

Collations control how strings are compared — whether case matters, how accented characters sort, and language-specific ordering rules.

**C# parallel:**
```csharp
// C# culture-specific comparison
var comparer = StringComparer.Create(new CultureInfo("en-US"), ignoreCase: true);
names.OrderBy(n => n, comparer);
```

---

## Declaration Order

Declarations in the prolog must follow a specific order. While not all categories are required, those that are present must appear in this sequence:

```xquery
(: 1. Version declaration (must be very first) :)
xquery version "4.0";

(: 2. Module declaration (library modules only) :)
module namespace mylib = "http://example.com/mylib";

(: 3. Namespace declarations :)
declare namespace app = "http://example.com/app";
declare default element namespace "http://example.com/elements";

(: 4. Imports :)
import module namespace util = "http://example.com/util" at "util.xqm";
import schema namespace tns = "http://example.com/types" at "types.xsd";

(: 5. Environment settings :)
declare construction strip;
declare ordering ordered;
declare default order empty greatest;
declare boundary-space strip;
declare copy-namespaces preserve, inherit;
declare base-uri "https://example.com/data/";
declare default collation "http://www.w3.org/2013/collation/UCA?lang=en";

(: 6. Option declarations :)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:indent "yes";

(: 7. Variable declarations :)
declare variable $config := map { "debug": false() };
declare variable $input external;

(: 8. Function declarations :)
declare function local:process($data) { (: ... :) };

(: 9. Body expression (main modules only — not in library modules) :)
local:process(doc("data.xml"))
```

**C# parallel:**
```csharp
// C# has a similar convention (enforced by style rules, not the compiler):
// 1. File-level attributes
// 2. using directives
// 3. namespace declaration
// 4. class/struct declarations
// 5. Fields, then constructors, then methods
```

---

## Main Module vs Library Module

XQuery has two kinds of modules, and the prolog is what distinguishes them.

### Main Module

A main module has a **body expression** — the query that produces results. It is the entry point, like `Program.Main()` in C#:

```xquery
xquery version "4.0";
import module namespace util = "http://example.com/util" at "util.xqm";

declare variable $input external;

(: Body expression — this is what gets executed :)
<report generated="{ current-dateTime() }">
{
  for $item in $input//order
  return util:format-order($item)
}
</report>
```

### Library Module

A library module has a **module declaration** instead of a body. It provides functions and variables for other modules to import:

```xquery
xquery version "4.0";
module namespace util = "http://example.com/util";

declare function util:format-order($order as element(order)) as element(formatted-order) {
  <formatted-order id="{ $order/@id }">
    <customer>{ $order/customer/text() }</customer>
    <total>{ util:format-currency($order/total) }</total>
    <date>{ format-date(xs:date($order/date), "[MNn] [D], [Y]") }</date>
  </formatted-order>
};

declare function util:format-currency($amount as xs:decimal) as xs:string {
  concat("$", format-number($amount, "#,##0.00"))
};
```

**Key differences:**

| Aspect | Main Module | Library Module |
|--------|-------------|----------------|
| Has `module namespace` | No | Yes |
| Has a body expression | Yes (required) | No (forbidden) |
| Can be executed directly | Yes | No — must be imported |
| File extension (convention) | `.xq` or `.xquery` | `.xqm` |
| C# equivalent | `Program.cs` with `Main()` | Class library `.dll` |

---

## Complete Example

Here is a realistic main module prolog that uses most declaration types:

```xquery
xquery version "4.0";

(: Namespace declarations :)
declare namespace app = "http://example.com/crm";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Import utility modules :)
import module namespace str = "http://example.com/strings" at "lib/strings.xqm";
import module namespace fmt = "http://example.com/format" at "lib/format.xqm";

(: Environment settings :)
declare default order empty greatest;
declare default collation "http://www.w3.org/2013/collation/UCA?lang=en;strength=secondary";

(: Serialization options :)
declare option output:method "xml";
declare option output:indent "yes";
declare option output:encoding "UTF-8";

(: External variables — set by the calling application :)
declare variable $report-date as xs:date external := current-date();
declare variable $department as xs:string external;
declare variable $include-inactive as xs:boolean external := false();

(: Internal configuration :)
declare variable $config := map {
  "max-results": 500,
  "currency": "USD",
  "date-format": "[Y]-[M01]-[D01]"
};

(: Local functions :)
declare function local:get-employees($dept as xs:string) as element(employee)* {
  collection("employees")/employee[department = $dept]
    [if ($include-inactive) then true() else status = "active"]
};

declare function local:build-summary($employees as element(employee)*) as element(summary) {
  <summary>
    <total-count>{ count($employees) }</total-count>
    <avg-tenure>{
      avg(
        for $e in $employees
        return days-from-duration(current-date() - xs:date($e/hire-date))
      ) div 365
    }</avg-tenure>
    <departments>{ count(distinct-values($employees/department)) }</departments>
  </summary>
};

(: Body expression :)
let $employees := local:get-employees($department)
return
  <app:report date="{ format-date($report-date, $config?date-format) }">
    { local:build-summary($employees) }
    <employees>
    {
      for $emp in $employees
      order by $emp/last-name collation
        "http://www.w3.org/2013/collation/UCA?lang=en;strength=secondary"
      return
        <employee id="{ $emp/@id }">
          <name>{ str:title-case(concat($emp/first-name, " ", $emp/last-name)) }</name>
          <title>{ $emp/job-title/text() }</title>
          <hired>{ format-date(xs:date($emp/hire-date), "[MNn] [D], [Y]") }</hired>
          <salary>{ fmt:currency($emp/salary, $config?currency) }</salary>
        </employee>
    }
    </employees>
  </app:report>
```

**Running this from C#:**
```csharp
var engine = new XQueryEngine();
engine.SetVariable("department", "Engineering");
engine.SetVariable("report-date", DateTime.Now.ToString("yyyy-MM-dd"));
engine.SetVariable("include-inactive", false);

var report = await engine.ExecuteAsync(File.ReadAllText("employee-report.xq"));
Console.WriteLine(report);
```
