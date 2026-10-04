---
title: JSON Storage
description: How JSON documents are stored, the XML mapping, and storage options
sort: 1
---

# JSON Storage

This guide covers how JSON documents are stored, the options that apply, and what is and is not available.

## Storing JSON Documents

### Basic Storage

JSON goes through the same `PutDocumentAsync` as XML:

```csharp
var container = await db.OpenOrCreateContainerAsync("data");

// Store a JSON string (detected from the leading '{' or '[')
await container.PutDocumentAsync("doc.json", jsonString);

// Store from an object
var user = new { Name = "Alice", Age = 30 };
await container.PutDocumentAsync("user.json", JsonSerializer.Serialize(user));

// Force JSON handling regardless of content
await container.PutDocumentAsync("doc.json", jsonString,
    new DocumentOptions { ContentType = ContentType.Json });
```

The document name's extension plays no part in detection.

### Storage Options

The options are the ordinary `DocumentOptions`:

| Property | Effect for JSON |
|----------|-----------------|
| `ContentType` | `ContentType.Json` forces JSON parsing; `null` (default) detects from the content |
| `Overwrite` | `false` throws `DocumentExistsException` if the name exists (default `true`) |
| `Metadata` | Metadata written with the document |

There are no JSON-specific storage options.

### What Is Stored

The JSON is converted to its `fn:json-to-xml` XML representation (namespace `http://www.w3.org/2005/xpath-functions`) and only that is stored:

```csharp
await container.PutDocumentAsync("user.json", """
    {
        "name": "Alice",
        "score": 95.5
    }
    """);

var doc = await container.GetDocumentAsync("user.json");
Console.WriteLine(doc!.ContentType);            // Json
Console.WriteLine(await doc.GetContentAsync());
// <?xml version="1.0" encoding="utf-8"?><map xmlns="http://www.w3.org/2005/xpath-functions"><string key="name">Alice</string><number key="score">95.5</number></map>

// Back to JSON text
await foreach (var json in container.QueryAsync(
    "xml-to-json(/fn:map)", variables: null, documentNameFilter: n => n == "user.json"))
    Console.WriteLine(json);                     // {"name":"Alice","score":95.5}
```

The original text, including its whitespace, is not preserved. `SizeBytes` reports the UTF-8 length of the JSON as submitted. See [JSON Support](index.md#json-to-xml-mapping) for the full mapping.

## JSON Validation

### Syntax

Content handled as JSON is parsed with `System.Text.Json`. Malformed JSON throws `System.Text.Json.JsonException` and nothing is written:

```csharp
try
{
    await container.PutDocumentAsync("bad.json", """{"id": 1,""");
}
catch (JsonException ex)
{
    Console.WriteLine(ex.Message);
}
```

### Schema Validation

There is no JSON Schema validation. Validate in your application before calling `PutDocumentAsync` if you need it.

## Indexing JSON

Indexes are declared on `ContainerOptions.Indexes` when the container is created and apply to the XML representation. See [JSON Indexing](json-indexing.md) for what path patterns can and cannot address in JSON documents.

```csharp
db.EnableIndexing();

var data = await db.CreateContainerAsync("data", opts =>
    opts.Indexes.AddFullTextIndex());   // every element's text
```

## Bulk Import

There are no JSON import helpers. Store many documents with `PutDocumentsAsync`, which commits up to 1,000 documents per LMDB write transaction:

```csharp
// One document per line of an NDJSON file
var inputs = File.ReadLines("data.ndjson")
    .Where(line => line.Length > 0)
    .Select((line, i) => new DocumentInput($"record-{i}.json", line));

int count = await container.PutDocumentsAsync(inputs);
Console.WriteLine($"Imported {count} documents");
```

## JSON Document Metadata

Metadata works exactly as for XML documents:

```csharp
await container.PutDocumentAsync("user.json", json);
await container.SetMetadataAsync("user.json", "source", "api");

// Query by metadata (phx prefix is predeclared)
await foreach (var name in container.QueryAsync(
    "/fn:map[phx:metadata(., 'source') = 'api']/fn:string[@key='name']/string()"))
{
    Console.WriteLine(name);
}
```

## Migration from Other Formats

### From CSV

```csharp
// Convert CSV rows to JSON documents
using var reader = new StreamReader("data.csv");
using var csv = new CsvReader(reader, CultureInfo.InvariantCulture);

int index = 0;
var inputs = new List<DocumentInput>();
foreach (var record in csv.GetRecords<dynamic>())
{
    inputs.Add(new DocumentInput($"row-{index++}.json", JsonSerializer.Serialize(record)));
}

await container.PutDocumentsAsync(inputs);
```

(`CsvReader` is from the third-party CsvHelper library.)

## Best Practices

1. **Consistent naming** — Use a `.json` extension so documents are recognisable in listings
2. **Index deliberately** — Path patterns address element names, not JSON keys; see [JSON Indexing](json-indexing.md)
3. **Validate before storing** — There is no schema validation on write
4. **Batch imports** — Use `PutDocumentsAsync` for large datasets
5. **Convert on the way out** — Use `xml-to-json()` when callers need JSON text

## Next Steps

| Queries | Indexing | Performance |
|---------|----------|-------------|
| **[JSON Queries](json-queries.md)**<br>Query patterns for JSON | **[JSON Indexing](json-indexing.md)**<br>Full indexing through XML | **[Performance Tuning](../performance-tuning.md)**<br>Optimization tips |
