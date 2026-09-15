---
title: Database Extensions
description: Custom XQuery functions, phx:metadata(), and extension development
sort: 10
---

# Database Extensions

PhoenixmlDb extends XQuery with database-specific functions in the `phx:` namespace. These functions provide access to document metadata and database features directly from XQuery expressions.

## The phx: Namespace

The engine's extension functions live in `https://schemas.phoenixml.dev/2026/db`, and the engine
binds the prefix **`phx`** to it on every query path. You do not declare it:

```xquery
phx:metadata($node, 'dbxml:name')
```

A container's `ContainerOptions.DefaultNamespaces` bindings are also in scope, and a query's own
`declare namespace` overrides either.

> **`dbxml` is not bound, and `dbxml:` means something different here.**
> The engine binds only `phx` for functions. `dbxml` is reserved for the metadata namespace
> (`https://schemas.phoenixml.dev/2026/meta`) in Core's namespace registry.
>
> The `dbxml:` you see on the metadata **keys** below is a **literal key prefix** matched by the
> metadata provider — not a namespace prefix. It is a plain part of the key string, so it works
> whether or not `dbxml` is bound as a prefix. Two different things share the spelling; only one
> of them is a namespace.

## phx:metadata($node, $key)

Retrieves a specific metadata value for the document containing the given node.

### Signature

```xquery
phx:metadata($node as node(), $key as xs:string) as item()?
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `$node` | `node()` | Any node belonging to the target document |
| `$key` | `xs:string` | The metadata key to retrieve |

### Return Type

`item()?` — The metadata value, or empty sequence if the key does not exist.

### System Metadata Keys

PhoenixmlDb provides built-in system metadata keys carrying a literal `dbxml:` prefix. These are
**key strings**, not namespace-qualified names — pass them as ordinary strings:

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
(: Get the document name :)
phx:metadata(., "dbxml:name")

(: Get a user-defined metadata value :)
phx:metadata(., "author")

(: Filter documents by metadata :)
for $doc in collection('products')
where phx:metadata($doc, "author") = "admin"
return $doc/product/name/text()

(: Use system metadata in results :)
for $doc in collection('orders')
return <info>
    <name>{phx:metadata($doc, "dbxml:name")}</name>
    <size>{phx:metadata($doc, "dbxml:size")}</size>
    <author>{phx:metadata($doc, "author")}</author>
</info>
```

## phx:metadata($node)

Retrieves all user metadata for the document containing the given node as an XQuery map.

### Signature

```xquery
phx:metadata($node as node()) as map(xs:string, item()?)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `$node` | `node()` | Any node belonging to the target document |

### Return Type

`map(xs:string, item()?)` — A map of all user-defined metadata key-value pairs.

### Examples

```xquery
(: Get all metadata as a map :)
let $meta := phx:metadata(.)
return map:keys($meta)

(: Iterate over metadata entries :)
let $meta := phx:metadata(.)
for $key in map:keys($meta)
return concat($key, " = ", $meta($key))
```

## Practical Examples

### Filtering by Metadata

```xquery
(: Find documents modified after a specific date :)
for $doc in collection('reports')
let $modified := phx:metadata($doc, "dbxml:modified")
where $modified > "2024-01-01T00:00:00Z"
return phx:metadata($doc, "dbxml:name")
```

### Combining Content and Metadata Queries

```xquery
(: Find large orders created by a specific user :)
for $doc in collection('orders')
let $order := $doc/order
where $order/total > 1000
  and phx:metadata($doc, "author") = "system"
order by xs:decimal($order/total) descending
return <result>
    <document>{phx:metadata($doc, "dbxml:name")}</document>
    <total>{$order/total/text()}</total>
    <created>{phx:metadata($doc, "dbxml:created")}</created>
</result>
```

### Metadata in FLWOR Expressions

```xquery
(: Group documents by author :)
for $doc in collection('articles')
let $author := phx:metadata($doc, "author")
group by $author
return <author name="{$author}">
    <count>{count($doc)}</count>
    <documents>{
        for $d in $doc
        return <doc>{phx:metadata($d, "dbxml:name")}</doc>
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

PhoenixmlDb's `phx:metadata()` function is inspired by Berkeley DB XML but with some differences:

| Feature | Berkeley DB XML | PhoenixmlDb |
|---------|----------------|-------------|
| Namespace URI | `http://www.sleepycat.com/2002/dbxml` | `https://schemas.phoenixml.dev/2026/db` |
| Function prefix | `dbxml`, declared by the query | **`phx`**, bound by the engine |
| Metadata access | `dbxml:metadata('key')` | `phx:metadata($node, 'key')` |
| All metadata | Not available | `phx:metadata($node)` returns map |
| System keys | `dbxml:name` | `dbxml:name`, `dbxml:size`, etc. — a literal key prefix, not a namespace |
| Custom functions | Java-based | C#-based with `XQueryFunction` |

The system-key spelling is the one piece of Berkeley DB XML's convention that carries over
verbatim. The function prefix does not: `dbxml` is reserved for the metadata namespace here, so
functions are `phx:`.
