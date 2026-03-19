---
title: String Functions
description: XPath string manipulation, searching, regex, Unicode, and URI functions
sort: 1
---

# String Functions

String functions are the most commonly used category in XPath. If you've worked with `System.String` methods in C#, most of these will feel familiar — with a few important differences around how XPath handles Unicode and sequences.

All string functions are in the default `fn:` namespace.

## Contents

- [Basic String Operations](#basic-string-operations)
- [Substring Operations](#substring-operations)
- [Searching and Testing](#searching-and-testing)
- [Case Conversion](#case-conversion)
- [Whitespace and Normalization](#whitespace-and-normalization)
- [Regular Expressions](#regular-expressions)
- [Unicode Functions](#unicode-functions)
- [URI Functions](#uri-functions)
- [Other String Functions](#other-string-functions)

---

## Basic String Operations

### string()

Converts a value to its string representation.

**Signature:** `string($value?) as xs:string`

```xpath
string(42)            => "42"
string(true())        => "true"
string(())            => ""        (: empty sequence becomes empty string :)
string(//price[1])    => "39.99"   (: string value of a node :)
```

**C# equivalent:** `.ToString()` or `Convert.ToString()`

**Note:** When called with no arguments, `string()` returns the string value of the context node — a common pattern in XSLT template matching.

---

### string-length()

Returns the number of characters in a string.

**Signature:** `string-length($value as xs:string?) as xs:integer`

```xpath
string-length("hello")           => 5
string-length("")                => 0
string-length("café")            => 4     (: counts characters, not bytes :)
string-length(//title)           => length of the title element's text
```

**C# equivalent:** `"hello".Length`

**Note:** XPath counts Unicode characters (codepoints), not bytes. This matches C#'s `string.Length` for most text, but differs for surrogate pairs.

---

### concat()

Joins two or more strings together. Unlike most XPath functions, `concat` accepts a variable number of arguments.

**Signature:** `concat($arg1 as xs:anyAtomicType?, $arg2 as xs:anyAtomicType?, ...) as xs:string`

```xpath
concat("hello", " ", "world")    => "hello world"
concat(//first-name, " ", //last-name) => "John Smith"
concat("Order #", @id)           => "Order #12345"
```

**C# equivalent:** `string.Concat()` or `$"hello {world}"`

**Note:** For joining a sequence with a separator, use `string-join()` instead.

---

### string-join()

Joins a sequence of strings with a separator.

**Signature:** `string-join($values as xs:anyAtomicType*, $separator as xs:string?) as xs:string`

```xpath
string-join(("a", "b", "c"), ", ")       => "a, b, c"
string-join(//item/name, " | ")          => "Widget | Gadget | Gizmo"
string-join(("a", "b", "c"))            => "abc"   (: no separator :)
string-join((), ", ")                    => ""      (: empty sequence :)
```

**C# equivalent:** `string.Join(", ", items)`

Given this XML:
```xml
<order>
  <item><name>Widget</name></item>
  <item><name>Gadget</name></item>
  <item><name>Gizmo</name></item>
</order>
```

```xpath
string-join(/order/item/name, ", ")   => "Widget, Gadget, Gizmo"
```

---

## Substring Operations

### substring()

Extracts a portion of a string. **Warning:** XPath uses 1-based indexing, not 0-based like C#.

**Signature:** `substring($value as xs:string?, $start as xs:double, $length as xs:double?) as xs:string`

```xpath
substring("hello world", 1, 5)   => "hello"    (: start at position 1, take 5 :)
substring("hello world", 7)      => "world"    (: start at position 7, take rest :)
substring("hello", 2, 3)         => "ell"
```

**C# equivalent:** `"hello world".Substring(0, 5)` — but remember C# is 0-based!

| XPath | C# | Result |
|-------|-----|--------|
| `substring("abcde", 1, 3)` | `"abcde".Substring(0, 3)` | `"abc"` |
| `substring("abcde", 3)` | `"abcde".Substring(2)` | `"cde"` |
| `substring("abcde", 2, 2)` | `"abcde".Substring(1, 2)` | `"bc"` |

---

### substring-before()

Returns the part of a string before the first occurrence of a search string.

**Signature:** `substring-before($value as xs:string?, $search as xs:string?) as xs:string`

```xpath
substring-before("2026-03-19", "-")    => "2026"
substring-before("hello world", " ")   => "hello"
substring-before("hello", "xyz")       => ""       (: not found :)
```

**C# equivalent:**
```csharp
var s = "2026-03-19";
s.Substring(0, s.IndexOf('-'))  // "2026"
```

---

### substring-after()

Returns the part of a string after the first occurrence of a search string.

**Signature:** `substring-after($value as xs:string?, $search as xs:string?) as xs:string`

```xpath
substring-after("2026-03-19", "-")     => "03-19"
substring-after("name=value", "=")     => "value"
substring-after("hello", "xyz")        => ""       (: not found :)
```

**C# equivalent:**
```csharp
var s = "2026-03-19";
s.Substring(s.IndexOf('-') + 1)  // "03-19"
```

**Practical example** — extracting a file extension:
```xpath
substring-after("report.pdf", ".")  => "pdf"
```

---

## Searching and Testing

### contains()

Tests whether a string contains a substring.

**Signature:** `contains($value as xs:string?, $search as xs:string?) as xs:boolean`

```xpath
contains("hello world", "world")   => true
contains("hello world", "xyz")     => false
contains("hello", "")              => true    (: empty string is always contained :)
```

**C# equivalent:** `"hello world".Contains("world")`

**Common XPath pattern** — filtering by content:
```xpath
//book[contains(title, "XML")]     (: books with "XML" in the title :)
```

---

### starts-with()

Tests whether a string starts with a prefix.

**Signature:** `starts-with($value as xs:string?, $prefix as xs:string?) as xs:boolean`

```xpath
starts-with("hello world", "hello")  => true
starts-with("hello world", "world")  => false
starts-with(@href, "http")           => true for external links
```

**C# equivalent:** `"hello".StartsWith("hello")`

**Practical example** — finding external links in a document:
```xpath
//link[starts-with(@href, "http")]
```

---

### ends-with()

Tests whether a string ends with a suffix.

**Signature:** `ends-with($value as xs:string?, $suffix as xs:string?) as xs:boolean`

```xpath
ends-with("report.pdf", ".pdf")   => true
ends-with("image.png", ".jpg")    => false
```

**C# equivalent:** `"report.pdf".EndsWith(".pdf")`

**Practical example** — finding all PDF links:
```xpath
//link[ends-with(@href, ".pdf")]
```

---

### contains-token()

Tests whether a whitespace-separated token list contains a specific token. This is useful for CSS-class-style attribute values.

**Signature:** `contains-token($value as xs:string?, $token as xs:string) as xs:boolean`

```xpath
contains-token("btn btn-primary active", "btn-primary")  => true
contains-token("btn btn-primary active", "btn")           => true
contains-token("btn btn-primary active", "bt")            => false (: partial match fails :)
```

**C# equivalent:** `"btn btn-primary".Split(' ').Contains("btn-primary")`

**Why this exists:** `contains("btn btn-primary", "btn")` returns true even for partial matches. `contains-token` requires a whole-token match.

---

## Case Conversion

### upper-case()

Converts a string to uppercase.

**Signature:** `upper-case($value as xs:string?) as xs:string`

```xpath
upper-case("hello")   => "HELLO"
upper-case("café")    => "CAFÉ"
upper-case("")        => ""
```

**C# equivalent:** `"hello".ToUpperInvariant()`

---

### lower-case()

Converts a string to lowercase.

**Signature:** `lower-case($value as xs:string?) as xs:string`

```xpath
lower-case("HELLO")   => "hello"
lower-case("XML")     => "xml"
```

**C# equivalent:** `"HELLO".ToLowerInvariant()`

**Practical example** — case-insensitive comparison:
```xpath
//book[lower-case(title) = "effective c#"]
```

---

## Whitespace and Normalization

### normalize-space()

Strips leading/trailing whitespace and collapses internal whitespace to single spaces.

**Signature:** `normalize-space($value as xs:string?) as xs:string`

```xpath
normalize-space("  hello   world  ")   => "hello world"
normalize-space("line1&#10;line2")     => "line1 line2"
normalize-space("")                    => ""
```

**C# equivalent:** `Regex.Replace(s.Trim(), @"\s+", " ")`

**Why this matters:** XML preserves whitespace in text nodes. When you read text from an XML document, it often contains newlines and indentation from the source file. `normalize-space()` cleans this up for display or comparison.

---

### normalize-unicode()

Applies Unicode normalization to a string.

**Signature:** `normalize-unicode($value as xs:string?, $form as xs:string?) as xs:string`

```xpath
normalize-unicode("café")            => "café" (NFC form — default)
normalize-unicode("café", "NFD")     => composed form
normalize-unicode("café", "NFKC")    => compatibility composition
```

**C# equivalent:** `"café".Normalize(NormalizationForm.FormC)`

**When you need this:** When comparing strings from different sources that may use different Unicode representations for the same character (e.g., `é` as a single codepoint vs. `e` + combining accent).

---

### translate()

Replaces individual characters, one-for-one. Not a search-and-replace — it's a character mapping.

**Signature:** `translate($value as xs:string?, $from as xs:string, $to as xs:string) as xs:string`

```xpath
translate("hello", "helo", "HELO")     => "HELLO"
translate("(555) 123-4567", "()-", "")  => "555 1234567"
translate("ABC", "ABC", "abc")         => "abc"
```

**C# equivalent:** Multiple `Replace()` calls, or `string.Create` with a character map.

**Practical example** — stripping punctuation from phone numbers:
```xpath
translate(@phone, "()- .", "")
```

**Note:** `translate()` maps characters 1:1. For pattern-based replacement, use `replace()` with regex.

---

## Regular Expressions

XPath uses the same regex syntax as XML Schema (which is close to but not identical to .NET's `System.Text.RegularExpressions`).

### matches()

Tests whether a string matches a regular expression.

**Signature:** `matches($value as xs:string?, $pattern as xs:string, $flags as xs:string?) as xs:boolean`

```xpath
matches("hello", "^h.*o$")            => true
matches("Hello", "hello", "i")        => true   (: case-insensitive :)
matches("2026-03-19", "\d{4}-\d{2}-\d{2}") => true
matches("abc123", "[0-9]+")           => true   (: contains digits :)
```

**Flags:**
| Flag | Meaning | C# Equivalent |
|------|---------|---------------|
| `i` | Case-insensitive | `RegexOptions.IgnoreCase` |
| `m` | Multiline (^ and $ match line boundaries) | `RegexOptions.Multiline` |
| `s` | Dot matches newlines | `RegexOptions.Singleline` |
| `x` | Allow whitespace and comments in pattern | `RegexOptions.IgnorePatternWhitespace` |

**C# equivalent:** `Regex.IsMatch("hello", "^h.*o$")`

**Practical example** — validating email-like patterns:
```xpath
//user[matches(email, "^[^@]+@[^@]+\.[^@]+$")]
```

---

### replace()

Replaces parts of a string matching a regex pattern.

**Signature:** `replace($value as xs:string?, $pattern as xs:string, $replacement as xs:string, $flags as xs:string?) as xs:string`

```xpath
replace("hello world", "world", "XPath")        => "hello XPath"
replace("2026-03-19", "(\d{4})-(\d{2})-(\d{2})", "$2/$3/$1")
                                                  => "03/19/2026"
replace("  hello  ", "^\s+|\s+$", "")            => "hello" (: trim :)
replace("aabbbcc", "(.)\1+", "$1")               => "abc"   (: collapse repeats :)
```

**C# equivalent:** `Regex.Replace("hello world", "world", "XPath")`

**Backreferences:** Use `$1`, `$2`, etc. in the replacement string to reference capture groups. This is the same as .NET's `$1` syntax.

**Practical example** — reformatting dates:
```xpath
replace(@date, "(\d{4})-(\d{2})-(\d{2})", "$3/$2/$1")
(: "2026-03-19" becomes "19/03/2026" :)
```

---

### tokenize()

Splits a string by a regex pattern, returning a sequence of tokens.

**Signature:** `tokenize($value as xs:string?, $pattern as xs:string?, $flags as xs:string?) as xs:string*`

```xpath
tokenize("a,b,c", ",")                     => ("a", "b", "c")
tokenize("one  two   three", "\s+")        => ("one", "two", "three")
tokenize("2026-03-19", "-")                => ("2026", "03", "19")
tokenize("path/to/file.txt", "/")          => ("path", "to", "file.txt")
```

**C# equivalent:** `"a,b,c".Split(',')` or `Regex.Split(s, pattern)`

**Zero-argument form** (XPath 3.1+): `tokenize($value)` splits on whitespace — equivalent to `normalize-space()` then split on spaces:

```xpath
tokenize("  hello   world  ")              => ("hello", "world")
```

**Practical example** — working with comma-separated values in attributes:
```xml
<product categories="electronics,gadgets,sale"/>
```
```xpath
tokenize(@categories, ",")   => ("electronics", "gadgets", "sale")
```

---

## Unicode Functions

These functions work at the codepoint level. Most are new in XPath 4.0.

### char()

Returns the character for a given Unicode codepoint. New in XPath 4.0.

**Signature:** `char($codepoint as xs:integer) as xs:string`

```xpath
char(65)       => "A"
char(8364)     => "€"
char(128522)   => "😊"
```

**C# equivalent:** `char.ConvertFromUtf32(65)`

---

### codepoint()

Returns the Unicode codepoint for the first character of a string. New in XPath 4.0.

**Signature:** `codepoint($char as xs:string) as xs:integer`

```xpath
codepoint("A")    => 65
codepoint("€")    => 8364
```

**C# equivalent:** `char.ConvertToUtf32("A", 0)`

---

### string-to-codepoints()

Returns the sequence of Unicode codepoints for all characters in a string.

**Signature:** `string-to-codepoints($value as xs:string?) as xs:integer*`

```xpath
string-to-codepoints("ABC")   => (65, 66, 67)
string-to-codepoints("")      => ()
```

**C# equivalent:** `"ABC".Select(c => (int)c)`

---

### codepoints-to-string()

Constructs a string from a sequence of Unicode codepoints.

**Signature:** `codepoints-to-string($codepoints as xs:integer*) as xs:string`

```xpath
codepoints-to-string((72, 101, 108, 108, 111))   => "Hello"
```

**C# equivalent:** `new string(codepoints.Select(c => (char)c).ToArray())`

---

### characters()

Splits a string into a sequence of individual characters. New in XPath 4.0.

**Signature:** `characters($value as xs:string) as xs:string*`

```xpath
characters("hello")   => ("h", "e", "l", "l", "o")
```

**C# equivalent:** `"hello".Select(c => c.ToString())`

---

### graphemes()

Splits a string into a sequence of grapheme clusters (user-perceived characters). New in XPath 4.0.

**Signature:** `graphemes($value as xs:string) as xs:string*`

```xpath
graphemes("café")      => ("c", "a", "f", "é")
```

**Why this exists:** Some characters that appear as one glyph are stored as multiple codepoints (e.g., `é` can be `e` + combining accent). `characters()` would split them; `graphemes()` keeps them together.

**C# equivalent:** `StringInfo.GetTextElementEnumerator(s)`

---

## URI Functions

### encode-for-uri()

Percent-encodes a string for use in a URI component.

**Signature:** `encode-for-uri($value as xs:string?) as xs:string`

```xpath
encode-for-uri("hello world")        => "hello%20world"
encode-for-uri("a/b?c=d")           => "a%2Fb%3Fc%3Dd"
encode-for-uri("100% done")          => "100%25%20done"
```

**C# equivalent:** `Uri.EscapeDataString("hello world")`

---

### iri-to-uri()

Converts an IRI (which may contain Unicode) to a valid URI.

**Signature:** `iri-to-uri($value as xs:string?) as xs:string`

```xpath
iri-to-uri("http://example.com/résumé")
  => "http://example.com/r%C3%A9sum%C3%A9"
```

**C# equivalent:** `Uri.EscapeUriString(iri)` (deprecated in .NET — use `Uri.TryCreate` instead)

---

### escape-html-uri()

Minimally escapes a URI for embedding in HTML, preserving existing percent-encoding.

**Signature:** `escape-html-uri($value as xs:string?) as xs:string`

```xpath
escape-html-uri("http://example.com/my page")
  => "http://example.com/my%20page"
```

**Note:** Unlike `encode-for-uri`, this only escapes characters that are not valid in URIs. It does not re-encode already-encoded characters.

---

### parse-uri()

Parses a URI string into a map of its components. New in XPath 4.0.

**Signature:** `parse-uri($uri as xs:string) as map(xs:string, xs:string?)`

```xpath
parse-uri("https://example.com:8080/path?q=1#frag")
  => map {
       "scheme": "https",
       "authority": "example.com:8080",
       "host": "example.com",
       "port": "8080",
       "path": "/path",
       "query": "q=1",
       "fragment": "frag"
     }
```

**C# equivalent:**
```csharp
var uri = new Uri("https://example.com:8080/path?q=1#frag");
// uri.Scheme, uri.Host, uri.Port, uri.PathAndQuery, uri.Fragment
```

---

### build-uri()

Constructs a URI from a map of components. New in XPath 4.0. The inverse of `parse-uri()`.

**Signature:** `build-uri($components as map(xs:string, xs:string?)) as xs:string`

```xpath
build-uri(map { "scheme": "https", "host": "example.com", "path": "/api/v2" })
  => "https://example.com/api/v2"
```

---

### resolve-uri()

Resolves a relative URI against a base URI.

**Signature:** `resolve-uri($relative as xs:string?, $base as xs:string?) as xs:anyURI?`

```xpath
resolve-uri("page.html", "https://example.com/docs/")
  => "https://example.com/docs/page.html"
resolve-uri("../images/logo.png", "https://example.com/docs/guide/")
  => "https://example.com/docs/images/logo.png"
```

**C# equivalent:** `new Uri(baseUri, relativeUri)`

---

## Other String Functions

### compare()

Compares two strings lexicographically, returning -1, 0, or 1.

**Signature:** `compare($s1 as xs:string?, $s2 as xs:string?, $collation as xs:string?) as xs:integer?`

```xpath
compare("apple", "banana")    => -1
compare("hello", "hello")     => 0
compare("zebra", "apple")     => 1
```

**C# equivalent:** `string.Compare("apple", "banana", StringComparison.Ordinal)`

The optional `$collation` parameter allows locale-aware comparison — useful for sorting names in different languages.

---

### codepoint-equal()

Compares two strings by Unicode codepoint, ignoring collation.

**Signature:** `codepoint-equal($s1 as xs:string?, $s2 as xs:string?) as xs:boolean?`

```xpath
codepoint-equal("hello", "hello")   => true
codepoint-equal("hello", "HELLO")   => false
```

**C# equivalent:** `string.Equals("hello", "hello", StringComparison.Ordinal)`

**When to use this:** When you want guaranteed binary comparison without any collation-dependent behavior. Faster than `compare()` when you only need equality.

---

### collation-key()

Returns a collation key for a string, allowing efficient repeated comparisons under a given collation.

**Signature:** `collation-key($value as xs:string, $collation as xs:string?) as xs:base64Binary`

**When to use this:** When sorting a large sequence — compute collation keys once, then compare keys instead of recomputing the collation for each comparison.

**C# equivalent:** `CompareInfo.GetSortKey(s)`
