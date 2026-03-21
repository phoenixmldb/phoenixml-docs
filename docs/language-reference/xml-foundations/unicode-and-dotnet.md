---
title: Unicode and .NET Requirements
description: ICU globalization requirements, Unicode normalization, collation, and platform setup for PhoenixmlDb
sort: 6
---

# Unicode and .NET Requirements

XML technologies rely heavily on Unicode — for character encoding, string normalization, collation (sorting), and regular expression character classes. Getting this right in .NET requires understanding how .NET handles globalization, and specifically why PhoenixmlDb requires ICU.

This isn't just academic. Incorrect Unicode handling causes:
- `normalize-unicode()` returning wrong results or throwing errors
- Collation-based sorting producing incorrect order
- Regular expression character classes (`\p{L}`, `\p{N}`) not matching expected characters
- String comparisons failing for non-ASCII text

## Contents

- [Why Unicode Matters for XML](#why-unicode-matters-for-xml)
- [.NET Globalization Modes](#net-globalization-modes)
- [ICU Requirement](#icu-requirement)
- [Platform Setup](#platform-setup)
- [Unicode Normalization](#unicode-normalization)
- [Collation](#collation)
- [Regular Expressions](#regular-expressions)
- [Common Issues and Solutions](#common-issues-and-solutions)

---

## Why Unicode Matters for XML

XML was designed for Unicode from the start. The XML specification requires:

- All XML processors must support UTF-8 and UTF-16
- Element and attribute names can contain Unicode characters (not just ASCII)
- The `xml:lang` attribute specifies content language
- XPath/XQuery string functions operate on Unicode codepoints
- Collation determines sort order for different languages

XPath 3.1/4.0 has dedicated Unicode functions:

```xpath
normalize-unicode("café", "NFC")     (: Unicode normalization :)
compare("straße", "strasse", "http://www.w3.org/2013/collation/UCA?lang=de")
characters("café")                    (: split into grapheme clusters :)
codepoint("é")                       (: Unicode codepoint value :)
upper-case("straße")                 (: "STRASSE" — language-aware :)
```

These functions depend on the Unicode Character Database (UCD) and locale-aware collation data. In .NET, this data comes from ICU.

---

## .NET Globalization Modes

.NET has two globalization modes:

### ICU Mode (Required)

Uses the **International Components for Unicode (ICU)** library for:
- Unicode normalization (NFC, NFD, NFKC, NFKD)
- Locale-aware string comparison and sorting
- Case conversion with language-specific rules
- Regular expression character classes
- Calendar and number formatting

ICU is the same library used by Chrome, Node.js, Java, and most other platforms. It provides correct, standards-compliant Unicode behavior.

### Invariant Globalization Mode (Not Compatible)

When `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` is set or `<InvariantGlobalization>true</InvariantGlobalization>` is in your project file, .NET uses a minimal, ordinal-only globalization implementation:

- No locale-aware sorting
- No Unicode normalization beyond basic case folding
- Simplified regex character classes
- Faster but incorrect for many internationalization scenarios

**PhoenixmlDb does not work correctly in invariant mode.** The XPath/XQuery functions that depend on Unicode behavior will produce wrong results or throw exceptions.

---

## ICU Requirement

PhoenixmlDb requires ICU-based globalization. This is configured in `Directory.Build.props`:

```xml
<PropertyGroup>
  <InvariantGlobalization>false</InvariantGlobalization>
</PropertyGroup>
```

**Critical:** The environment variable `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` takes precedence over the project setting. If this variable is set to `1` in your environment (common in Docker images), PhoenixmlDb will silently produce incorrect results.

### What Breaks Without ICU

| Function | With ICU | Without ICU |
|----------|----------|-------------|
| `normalize-unicode("café", "NFC")` | Correctly normalized string | May throw or return incorrect result |
| `compare("ä", "ae", $german-collation)` | Language-correct comparison | Ordinal comparison (wrong for German) |
| `upper-case("straße")` | `"STRASSE"` (correct) | `"STRASSE"` or `"STRAẞE"` (may vary) |
| `matches("café", "\p{L}+")` | `true` (all letters) | May not recognize `é` as a letter |
| `collation-key($string)` | Locale-aware key | Throws or returns ordinal key |
| `default-language()` | System locale | May return empty or "iv" |

### Checking Your Configuration

In your .NET application:

```csharp
// Check if ICU is available
Console.WriteLine($"Globalization mode: {System.Globalization.CultureInfo.CurrentCulture.Name}");
Console.WriteLine($"ICU version: {System.Globalization.CultureInfo.CurrentCulture.CompareInfo}");

// This will throw in invariant mode:
try
{
    "café".Normalize(System.Text.NormalizationForm.FormD);
    Console.WriteLine("ICU: Available");
}
catch (PlatformNotSupportedException)
{
    Console.WriteLine("ICU: NOT available — invariant mode!");
}
```

---

## Platform Setup

### Windows

ICU is included with Windows 10+ and .NET 5+. No additional setup needed.

```xml
<!-- Directory.Build.props — this is all you need -->
<InvariantGlobalization>false</InvariantGlobalization>
```

### Linux

Most Linux distributions include ICU. If you're using a minimal container image, you may need to install it:

**Debian/Ubuntu:**
```bash
apt-get install -y libicu-dev
```

**Alpine Linux:**
```bash
apk add icu-libs
```

**Important for Docker:** Many minimal .NET Docker images (especially Alpine-based) set `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` by default. You must either:

1. Unset the variable:
   ```dockerfile
   ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
   ```

2. Or install ICU and unset:
   ```dockerfile
   FROM mcr.microsoft.com/dotnet/runtime:10.0-alpine
   RUN apk add --no-cache icu-libs
   ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
   ```

3. Or use the non-Alpine images (which include ICU by default):
   ```dockerfile
   FROM mcr.microsoft.com/dotnet/runtime:10.0
   # ICU included, no extra setup needed
   ```

### macOS

ICU is included with macOS. No additional setup needed.

### CI/CD Pipelines

If your CI runs on minimal containers, ensure ICU is available:

**GitHub Actions:**
```yaml
- name: Install ICU (if needed)
  run: |
    if [ -f /etc/alpine-release ]; then
      apk add --no-cache icu-libs
    fi
  env:
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT: false
```

---

## Unicode Normalization

### What It Is

The same character can be represented multiple ways in Unicode:

- `é` as a single codepoint: U+00E9 (precomposed)
- `é` as two codepoints: U+0065 (e) + U+0301 (combining accent) (decomposed)

Both look identical on screen, but they're different byte sequences. If you compare them without normalization, they won't match.

### Normalization Forms

| Form | Name | Use |
|------|------|-----|
| NFC | Canonical Composition | Default for most use. Precomposes characters. |
| NFD | Canonical Decomposition | Decomposes characters. Useful for stripping accents. |
| NFKC | Compatibility Composition | NFC + resolves compatibility characters (e.g., ﬁ → fi) |
| NFKD | Compatibility Decomposition | NFD + resolves compatibility characters |

### In XPath

```xpath
normalize-unicode("café")              (: NFC — default :)
normalize-unicode("café", "NFD")       (: decomposed form :)
normalize-unicode("ﬁle", "NFKC")      (: "file" — compatibility normalization :)
```

### In .NET

```csharp
"café".Normalize(NormalizationForm.FormC);   // NFC
"café".Normalize(NormalizationForm.FormD);   // NFD
```

### When to Normalize

- **Comparing strings** from different sources (user input vs database)
- **Indexing** text for search
- **Hashing** strings (different normalizations produce different hashes)
- **Storing** text in a database (choose one form and stick with it — NFC is standard)

---

## Collation

Collation determines how strings are compared and sorted. It's language-dependent:

| Language | Sort Order | Why |
|----------|------------|-----|
| English | a, b, c, ... z | Alphabetical |
| German | ä sorts with a | ä is a variant of a |
| Swedish | ä sorts after z | ä is a separate letter |
| Spanish | ñ sorts between n and o | ñ is a separate letter |

### In XPath/XSLT

```xpath
(: Default collation — usually Unicode Collation Algorithm :)
sort(("ä", "z", "a"))
(: Depends on collation — could be "a, ä, z" or "a, z, ä" :)

(: Explicit German collation :)
sort(("ä", "z", "a"), "http://www.w3.org/2013/collation/UCA?lang=de")
(: "a, ä, z" — German rules :)

(: Explicit Swedish collation :)
sort(("ä", "z", "a"), "http://www.w3.org/2013/collation/UCA?lang=sv")
(: "a, z, ä" — Swedish rules :)
```

In XSLT sorting:

```xml
<xsl:sort select="name" collation="http://www.w3.org/2013/collation/UCA?lang=de"/>
```

### In .NET

```csharp
// Default comparison (culture-dependent)
string.Compare("ä", "z", StringComparison.CurrentCulture);

// German comparison
var german = new CultureInfo("de-DE");
string.Compare("ä", "z", false, german);   // ä before z

// Swedish comparison
var swedish = new CultureInfo("sv-SE");
string.Compare("ä", "z", false, swedish);  // ä after z
```

### Collation in PhoenixmlDb

PhoenixmlDb supports the W3C Unicode Collation Algorithm (UCA) with language parameters:

```
http://www.w3.org/2013/collation/UCA?lang=en
http://www.w3.org/2013/collation/UCA?lang=de&strength=secondary
```

**Strength levels:**
| Level | Ignores | Example |
|-------|---------|---------|
| Primary | Case + accents | a = á = A |
| Secondary | Case only | a = A ≠ á |
| Tertiary (default) | Nothing | a ≠ A ≠ á |

---

## Regular Expressions

XPath/XQuery regex uses Unicode character classes:

```xpath
matches("café123", "\p{L}+")    (: matches "café" — Unicode letters :)
matches("café123", "\p{N}+")    (: matches "123" — Unicode numbers :)
matches("café", "\p{Ll}+")      (: matches "caf" — lowercase letters :)
matches("Ω", "\p{Lu}")          (: true — uppercase Greek letter :)
```

**In invariant mode**, `\p{L}` may not recognize all Unicode letters — it might miss accented characters, non-Latin scripts, or characters added in recent Unicode versions.

### XPath vs .NET Regex Differences

| Feature | XPath Regex | .NET Regex |
|---------|-------------|------------|
| Syntax base | XML Schema regex | Perl-compatible |
| Anchoring | Implicit full match | Partial match unless `^...$` |
| Character classes | `\p{L}`, `\p{Lu}`, `\p{IsGreek}` | Same (with ICU) |
| Backreferences in match | Not supported | Supported |
| Backreferences in replace | `$1`, `$2` | `$1`, `$2` |
| Named groups | Not supported | `(?<name>...)` |
| Lookahead/lookbehind | Not supported | Supported |
| Flags | `i`, `m`, `s`, `x` | `RegexOptions` enum |

The most important difference: **XPath `matches()` tests the entire string by default.** `matches("hello world", "hello")` is `false` because "hello" doesn't match the whole string. You need `matches("hello world", ".*hello.*")` or `contains()` instead.

---

## Common Issues and Solutions

### Issue: normalize-unicode() Throws PlatformNotSupportedException

**Cause:** Invariant globalization mode is active.

**Fix:**
```bash
# Check for the environment variable
echo $DOTNET_SYSTEM_GLOBALIZATION_INVARIANT

# Unset it
unset DOTNET_SYSTEM_GLOBALIZATION_INVARIANT
# Or in .env / Docker:
DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
```

### Issue: Sorting Produces Wrong Order for Non-English Text

**Cause:** Default collation is ordinal (invariant mode) or wrong locale.

**Fix:** Specify the collation explicitly:
```xml
<xsl:sort select="name" collation="http://www.w3.org/2013/collation/UCA?lang=de"/>
```

### Issue: String Comparison Fails for Accented Characters

**Cause:** Comparing strings with different Unicode normalization forms.

**Fix:** Normalize before comparing:
```xpath
normalize-unicode($a, "NFC") = normalize-unicode($b, "NFC")
```

### Issue: Docker Container Silently Breaks Unicode

**Cause:** Alpine-based images default to invariant mode.

**Fix:** Use the standard (non-Alpine) images, or install ICU:
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0
# ICU included — no DOTNET_SYSTEM_GLOBALIZATION_INVARIANT needed
```

### Issue: Tests Pass Locally But Fail in CI

**Cause:** CI environment has different globalization settings.

**Fix:** Add to your test project:
```xml
<PropertyGroup>
  <InvariantGlobalization>false</InvariantGlobalization>
</PropertyGroup>
```

And ensure CI has ICU installed.

### Verifying Your Environment

Run this quick check to confirm everything is configured correctly:

```csharp
using System.Globalization;
using System.Text;

// 1. Check ICU availability
Console.WriteLine($"Culture: {CultureInfo.CurrentCulture.Name}");

// 2. Check normalization
var nfc = "café".Normalize(NormalizationForm.FormC);
var nfd = "café".Normalize(NormalizationForm.FormD);
Console.WriteLine($"NFC length: {nfc.Length}, NFD length: {nfd.Length}");
Console.WriteLine($"NFC == NFD (ordinal): {nfc == nfd}");
Console.WriteLine($"NFC == NFD (normalized): {string.Compare(nfc, nfd, CultureInfo.InvariantCulture, CompareOptions.None) == 0}");

// 3. Check collation
var german = new CultureInfo("de-DE");
var result = string.Compare("ä", "b", false, german);
Console.WriteLine($"German: ä vs b = {result} (should be < 0)");
```

If any of these fail or throw, your environment needs ICU configuration.
