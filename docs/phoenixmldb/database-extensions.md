---
title: Database Extensions
description: Custom XQuery functions, dbxml:metadata(), and extension development
sort: 10
---

# Database Extensions

PhoenixmlDb extends XQuery with database-specific functions in the `dbxml:` namespace. These functions provide access to document metadata and database features directly from XQuery expressions.

## The dbxml: Namespace

The `dbxml:` namespace (`http://phoenixml.endpointsystems.com/dbxml`) follows the Berkeley DB XML convention for database extension functions. Declare it in your XQuery prolog:

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";
```

## dbxml:metadata($node, $key)

Retrieves a specific metadata value for the document containing the given node.

### Signature

```xquery
dbxml:metadata($node as node(), $key as xs:string) as item()?
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `$node` | `node()` | Any node belonging to the target document |
| `$key` | `xs:string` | The metadata key to retrieve |

### Return Type

`item()?` — The metadata value, or empty sequence if the key does not exist.

### System Metadata Keys

PhoenixmlDb provides built-in system metadata keys prefixed with `dbxml:`:

| Key | Type | Description |
|-----|------|-------------|
| `dbxml:name` | `xs:string` | Document name within its container |
| `dbxml:content-type` | `xs:string` | MIME content type (`application/xml`, `application/json`) |
| `dbxml:created` | `xs:string` | ISO 8601 creation timestamp |
| `dbxml:modified` | `xs:string` | ISO 8601 last-modified timestamp |
| `dbxml:size` | `xs:integer` | Document size in bytes |
| `dbxml:node-count` | `xs:integer` | Number of nodes in the document |

### Examples

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";

(: Get the document name :)
dbxml:metadata(., "dbxml:name")

(: Get a user-defined metadata value :)
dbxml:metadata(., "author")

(: Filter documents by metadata :)
for $doc in collection('products')
where dbxml:metadata($doc, "author") = "admin"
return $doc/product/name/text()

(: Use system metadata in results :)
for $doc in collection('orders')
return <info>
    <name>{dbxml:metadata($doc, "dbxml:name")}</name>
    <size>{dbxml:metadata($doc, "dbxml:size")}</size>
    <author>{dbxml:metadata($doc, "author")}</author>
</info>
```

## dbxml:metadata($node)

Retrieves all user metadata for the document containing the given node as an XQuery map.

### Signature

```xquery
dbxml:metadata($node as node()) as map(xs:string, item()?)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `$node` | `node()` | Any node belonging to the target document |

### Return Type

`map(xs:string, item()?)` — A map of all user-defined metadata key-value pairs.

### Examples

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";

(: Get all metadata as a map :)
let $meta := dbxml:metadata(.)
return map:keys($meta)

(: Iterate over metadata entries :)
let $meta := dbxml:metadata(.)
for $key in map:keys($meta)
return concat($key, " = ", $meta($key))
```

## Practical Examples

### Filtering by Metadata

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";

(: Find documents modified after a specific date :)
for $doc in collection('reports')
let $modified := dbxml:metadata($doc, "dbxml:modified")
where $modified > "2024-01-01T00:00:00Z"
return dbxml:metadata($doc, "dbxml:name")
```

### Combining Content and Metadata Queries

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";

(: Find large orders created by a specific user :)
for $doc in collection('orders')
let $order := $doc/order
where $order/total > 1000
  and dbxml:metadata($doc, "author") = "system"
order by xs:decimal($order/total) descending
return <result>
    <document>{dbxml:metadata($doc, "dbxml:name")}</document>
    <total>{$order/total/text()}</total>
    <created>{dbxml:metadata($doc, "dbxml:created")}</created>
</result>
```

### Metadata in FLWOR Expressions

```xquery
declare namespace dbxml = "http://phoenixml.endpointsystems.com/dbxml";

(: Group documents by author :)
for $doc in collection('articles')
let $author := dbxml:metadata($doc, "author")
group by $author
return <author name="{$author}">
    <count>{count($doc)}</count>
    <documents>{
        for $d in $doc
        return <doc>{dbxml:metadata($d, "dbxml:name")}</doc>
    }</documents>
</author>
```

## Custom C# Function Extensions

You can register custom XQuery functions from C# by extending the `XQueryFunction` base class.

### Writing a Custom Function

```csharp
using PhoenixmlDb.Core;
using PhoenixmlDb.Query.Ast;

public sealed class MyCustomFunction : XQueryFunction
{
    public override QName Name => new(
        FunctionNamespaces.Local, "my-function");

    public override XdmSequenceType ReturnType =>
        XdmSequenceType.String;

    public override IReadOnlyList<FunctionParameterDef> Parameters =>
    [
        new() {
            Name = new QName(NamespaceId.None, "input"),
            Type = XdmSequenceType.String
        }
    ];

    public override ValueTask<object?> InvokeAsync(
        IReadOnlyList<object?> arguments,
        ExecutionContext context)
    {
        var input = arguments[0]?.ToString() ?? "";
        return ValueTask.FromResult<object?>(
            input.ToUpperInvariant());
    }
}
```

### Registering the Function

```csharp
var library = FunctionLibrary.Standard;
library.Register(new MyCustomFunction());
```

### Using from XQuery

```xquery
declare namespace local = "http://www.w3.org/2005/xquery-local-functions";

local:my-function("hello")  (: "HELLO" :)
```

## Comparison with Berkeley DB XML

PhoenixmlDb's `dbxml:metadata()` function is inspired by Berkeley DB XML but with some differences:

| Feature | Berkeley DB XML | PhoenixmlDb |
|---------|----------------|-------------|
| Namespace URI | `http://www.sleepycat.com/2002/dbxml` | `http://phoenixml.endpointsystems.com/dbxml` |
| Metadata access | `dbxml:metadata('key')` | `dbxml:metadata($node, 'key')` |
| All metadata | Not available | `dbxml:metadata($node)` returns map |
| System keys | `dbxml:name` | `dbxml:name`, `dbxml:size`, etc. |
| Custom functions | Java-based | C#-based with `XQueryFunction` |
