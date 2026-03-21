---
title: Formatting Functions
description: XPath number formatting, date formatting, serialization, and URI handling
sort: 11
---

# Formatting Functions

These functions convert values to formatted strings for display. If you've used C#'s `ToString()` format strings, these serve the same purpose with XPath's own picture string syntax.

---

## Number Formatting

### format-integer()

Formats an integer using a picture string.

**Signature:** `format-integer($value as xs:integer?, $picture as xs:string) as xs:string`

```xpath
format-integer(42, "001")                => "042"        (: zero-padded :)
format-integer(1234567, "#,###")         => "1,234,567"  (: thousands separator :)
format-integer(3, "Ww")                  => "Three"      (: words :)
format-integer(3, "w")                   => "three"      (: words, lowercase :)
format-integer(4, "I")                   => "IV"         (: roman numerals :)
format-integer(4, "i")                   => "iv"         (: roman numerals, lowercase :)
format-integer(1, "A")                   => "A"          (: alphabetic :)
format-integer(3, "a")                   => "c"          (: alphabetic, lowercase :)
format-integer(1, "01;")                 => "1st"        (: ordinal :)
```

**C# equivalent:** `42.ToString("000")` — but C# can't do words, roman numerals, or ordinals natively.

---

### format-number()

Formats a decimal number using a picture string and optional decimal format.

**Signature:** `format-number($value as xs:numeric?, $picture as xs:string, $decimal-format as xs:string?) as xs:string`

```xpath
format-number(1234.5, "#,##0.00")        => "1,234.50"
format-number(0.5, "0%")                  => "50%"
format-number(-42, "#;(#)")               => "(42)"  (: accounting format :)
format-number(1234.5, "#.###,00", "eu")   => "1.234,50" (: European format :)
```

**Picture string syntax:**

| Symbol | Meaning |
|--------|---------|
| `0` | Required digit (zero-padded) |
| `#` | Optional digit |
| `.` | Decimal separator |
| `,` | Grouping separator |
| `%` | Multiply by 100, show percent |
| `;` | Separates positive and negative patterns |

**C# equivalent:** `1234.5.ToString("#,##0.00")` — the picture string syntax is similar but not identical.

---

## Date/Time Formatting

See [Date and Time Functions](date-time.md#formatting) for `format-date()`, `format-dateTime()`, and `format-time()`.

---

## Serialization

### serialize()

Converts a node or value to its serialized string form (XML, JSON, HTML, or text).

**Signature:** `serialize($value as item()*, $params as item()?) as xs:string`

```xpath
serialize(<order><item>Widget</item></order>)
=> '<order><item>Widget</item></order>'

serialize(map { "name": "Alice", "age": 30 },
  map { "method": "json", "indent": true() })
=> '{
  "name": "Alice",
  "age": 30
}'
```

**C# equivalent:** `element.ToString()` for XML, `JsonSerializer.Serialize()` for JSON.

**Use cases:**
- Embedding XML as a string in another format
- Producing JSON output from an XSLT transformation
- Debugging — see the actual serialized form of a value

---

## URI Functions

### parse-html()

Parses an HTML string into an XDM document. New in XPath 4.0.

**Signature:** `parse-html($html as xs:string) as document-node()`

```xpath
parse-html("<p>Hello <b>world</b></p>")//b   => "world"
```

**C# equivalent:** Using an HTML parser library like `HtmlAgilityPack`.

**Why this matters:** XPath 4.0 can now work with HTML content directly, making it useful for web scraping and content extraction scenarios.

---

## Environment

### environment-variable()

Returns the value of a system environment variable. New in XPath 4.0.

**Signature:** `environment-variable($name as xs:string) as xs:string?`

```xpath
environment-variable("HOME")   => "/home/user"
environment-variable("PATH")   => "/usr/bin:..."
```

**C# equivalent:** `Environment.GetEnvironmentVariable("HOME")`

**Note:** Availability depends on the host environment and security policy.

---

### available-environment-variables()

Returns the names of all available environment variables. New in XPath 4.0.

---

### default-language()

Returns the default language of the evaluation environment. New in XPath 4.0.

```xpath
default-language()   => "en"
```

---

## Error Handling

### error()

Raises a dynamic error. The XPath equivalent of throwing an exception.

**Signature:** `error($code as xs:QName?, $description as xs:string?, $value as item()*) as none`

```xpath
error()                                          (: generic error :)
error(xs:QName("err:INVALID"), "Bad input")     (: with code and message :)

(: Common pattern — validate before processing :)
if (//price < 0)
then error(xs:QName("err:NEG"), "Negative price found")
else sum(//price)
```

**C# equivalent:** `throw new InvalidOperationException("Bad input")`

---

### trace()

Outputs a value to the trace log and returns it unchanged. Useful for debugging XPath expressions.

**Signature:** `trace($value as item()*, $label as xs:string?) as item()*`

```xpath
trace(//book[1]/price, "first book price")
(: outputs "first book price: 39.99" to trace output, returns 39.99 :)
```

**C# equivalent:** `Debug.WriteLine($"first book price: {price}")` — but `trace()` is inline in the expression, which is more convenient for debugging complex XPath.
