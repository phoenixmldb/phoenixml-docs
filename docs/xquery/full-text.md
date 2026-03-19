---
title: Full-Text Search
description: "XQuery Full-Text — ft:contains, match options, scoring, and search expressions"
sort: 10
---

# Full-Text Search

XQuery's built-in `contains()` function does exact substring matching — it finds `"data"` inside `"database"` but cannot search linguistically. Full-Text Search adds the features you would expect from a real search engine: stemming, case-insensitive matching, diacritics normalization, stop words, wildcards, proximity search, and relevance scoring.

If you have used Lucene.NET, Elasticsearch, or SQL Server's `CONTAINS` / `FREETEXT` predicates, XQuery Full-Text solves the same problems but is integrated directly into the query language — no separate index API or raw SQL strings needed.

## Contents

- [Why Full-Text in XQuery](#why-full-text-in-xquery)
- [ft:contains — The Basic Predicate](#ftcontains--the-basic-predicate)
- [Match Options](#match-options)
- [Search Modes](#search-modes)
- [Logical Combinations](#logical-combinations)
- [Positional Filters](#positional-filters)
- [Full-Text Functions](#full-text-functions)
- [Scoring and Relevance](#scoring-and-relevance)
- [Practical Examples](#practical-examples)

---

## Why Full-Text in XQuery

Consider a document library with thousands of articles. A user searches for `"running"`. With standard XQuery:

```xquery
(: Standard contains() — exact substring match :)
//article[contains(description, "running")]
```

This misses articles containing `"run"`, `"runs"`, or `"ran"`. It is also case-sensitive, so `"Running"` at the start of a sentence is missed. And there is no way to rank results by relevance.

**C# parallel — the same problem exists:**
```csharp
// C# exact match — same limitations
var results = articles.Where(a => a.Description.Contains("running"));
// Misses "run", "runs", "ran", case-sensitive
```

In C#, you solve this by adding a full-text search library (Lucene.NET, SQL Server Full-Text Search, or Elasticsearch). In XQuery, Full-Text Search is a W3C standard extension built into the language itself.

Full-Text Search gives you:

| Feature | Standard `contains()` | Full-Text Search |
|---------|----------------------|------------------|
| Substring matching | Yes | Yes |
| Case insensitive | No (must use `lower-case()`) | Yes (default) |
| Stemming | No | Yes (`"running"` matches `"run"`) |
| Diacritics | No | Yes (`"cafe"` matches `"cafe"`) |
| Wildcards | No | Yes (`"data*"` matches `"database"`) |
| Stop words | No | Yes (ignore `"the"`, `"a"`, `"an"`) |
| Proximity | No | Yes (`"xml"` near `"database"`) |
| Scoring/ranking | No | Yes |
| Phrase search | No | Yes |
| Thesaurus | No | Yes |

---

## ft:contains — The Basic Predicate

`ft:contains` is the entry point for full-text search. It takes a node (the content to search) and a search expression (what to look for):

```xquery
(: Search the description element for "database" :)
//book[ft:contains(description, "database")]
```

```xquery
(: Search ALL text content of the book element :)
//book[ft:contains(., "xml query")]
```

```xquery
(: Search with match options :)
//book[ft:contains(title, "xml" using stemming using case insensitive)]
```

The first argument is the node whose text content is searched. Using `.` searches all descendant text. The second argument is a full-text selection — a search expression that can include match options.

**C# parallel:**
```csharp
// SQL Server full-text search via Entity Framework
var books = context.Books
    .Where(b => EF.Functions.Contains(b.Description, "database"));

// Lucene.NET
var query = new QueryParser("description", analyzer).Parse("database");
var results = searcher.Search(query, 100);
```

### Searching Multiple Fields

```xquery
(: Search title OR description :)
//book[ft:contains(title, "xml") or ft:contains(description, "xml")]

(: Search all text content of the entire book element :)
//book[ft:contains(., "xml")]
```

### Using ft:contains in FLWOR Expressions

```xquery
for $article in //article
where ft:contains($article/body, "machine learning")
order by ft:score($article/body, "machine learning") descending
return
  <result>
    <title>{ $article/title/text() }</title>
    <score>{ ft:score($article/body, "machine learning") }</score>
  </result>
```

---

## Match Options

Match options follow the search term and control how matching is performed. You can combine multiple options with successive `using` clauses.

### Language

Specifies the language for stemming and stop word processing:

```xquery
//article[ft:contains(., "running" using language "en")]
```

Language affects stemming rules (English stemming is different from German stemming), stop word lists, and tokenization. Common language codes: `"en"` (English), `"de"` (German), `"fr"` (French), `"es"` (Spanish).

### Stemming

Stemming reduces words to their root form so that morphological variants match:

```xquery
(: Without stemming — only matches literal "running" :)
//article[ft:contains(., "running")]

(: With stemming — matches "run", "runs", "running", "ran" :)
//article[ft:contains(., "running" using stemming)]
```

| Search Term | Matches (with stemming) |
|-------------|------------------------|
| `"running"` | run, runs, running, ran |
| `"databases"` | database, databases |
| `"better"` | better, good, best (language-dependent) |
| `"analyzing"` | analyze, analyzes, analyzing, analysis |

**C# parallel:**
```csharp
// Lucene.NET with stemming analyzer
var analyzer = new EnglishAnalyzer(LuceneVersion.LUCENE_48);
// "running" query now matches "run", "runs", "ran"
```

### Case Sensitivity

By default, full-text matching is case insensitive. You can override this:

```xquery
(: Default: case insensitive — matches "XML", "xml", "Xml" :)
//doc[ft:contains(title, "xml")]

(: Explicit case insensitive (same as default) :)
//doc[ft:contains(title, "xml" using case insensitive)]

(: Case sensitive — only matches exact case :)
//doc[ft:contains(title, "XML" using case sensitive)]
```

### Diacritics

By default, full-text matching is diacritics insensitive, so accented characters match their unaccented equivalents:

```xquery
(: Diacritics insensitive (default) — "cafe" matches "cafe" :)
//restaurant[ft:contains(name, "cafe")]

(: Diacritics sensitive — "cafe" does NOT match "cafe" :)
//restaurant[ft:contains(name, "cafe" using diacritics sensitive)]
```

| Search | Diacritics Insensitive (default) | Diacritics Sensitive |
|--------|----------------------------------|---------------------|
| `"cafe"` | cafe, cafe, CAFE | cafe, CAFE only |
| `"resume"` | resume, resume, resume | resume only |
| `"nino"` | nino, nino | nino only |

### Wildcards

Enables glob-style wildcards within search terms:

```xquery
(: Matches "database", "datatype", "dataset", "data-driven" :)
//doc[ft:contains(., "data*" using wildcards)]

(: Matches "analyze", "analyse" (British vs American spelling) :)
//doc[ft:contains(., "analy?e" using wildcards)]
```

| Wildcard | Meaning | Example |
|----------|---------|---------|
| `*` | Zero or more characters | `"data*"` matches `"database"`, `"datatype"` |
| `?` | Exactly one character | `"te?t"` matches `"test"`, `"text"` |
| `\*` | Literal asterisk | `"5\*5"` matches `"5*5"` |

**C# parallel:**
```csharp
// SQL Server
var results = context.Documents
    .Where(d => EF.Functions.Contains(d.Content, "\"data*\""));

// Lucene.NET
var query = new WildcardQuery(new Term("content", "data*"));
```

### Stop Words

Stop words are common words (like "the", "a", "is", "and") that are ignored during search to improve relevance:

```xquery
(: Use an explicit stop word list :)
//doc[ft:contains(., "the art of war"
  using stop words ("the", "a", "an", "of", "is", "and", "or", "in"))]
(: Actually searches for: "art", "war" :)

(: Use the default stop word list for the language :)
//doc[ft:contains(., "the art of war"
  using stop words default
  using language "en")]
```

Without stop words, a search for `"the art of war"` might rank documents with many occurrences of `"the"` highly. With stop words, only the meaningful terms `"art"` and `"war"` contribute to matching and scoring.

### Thesaurus

A thesaurus expands search terms to include synonyms:

```xquery
(: "fast" also matches "quick", "rapid", "speedy" :)
//doc[ft:contains(., "fast"
  using thesaurus at "thesaurus.xml")]

(: With a specific relationship type :)
//doc[ft:contains(., "car"
  using thesaurus at "thesaurus.xml" relationship "synonym")]
```

The thesaurus is an XML file mapping terms to their synonyms:

```xml
<thesaurus xmlns="http://www.w3.org/2007/full-text-thesaurus">
  <entry>
    <term>fast</term>
    <synonym>quick</synonym>
    <synonym>rapid</synonym>
    <synonym>speedy</synonym>
  </entry>
  <entry>
    <term>car</term>
    <synonym>automobile</synonym>
    <synonym>vehicle</synonym>
  </entry>
</thesaurus>
```

### Combining Match Options

Options are composable. Combine as many as you need:

```xquery
//article[ft:contains(body, "running"
  using stemming
  using case insensitive
  using wildcards
  using stop words default
  using language "en")]
```

---

## Search Modes

Search modes control how multi-word search strings are interpreted.

### any word

Matches documents containing **any** of the specified words. This is the most lenient mode — the equivalent of an `OR` search:

```xquery
(: Matches documents containing "xml" OR "json" OR "yaml" :)
//doc[ft:contains(., "xml json yaml" using mode any word)]
```

**C# parallel:**
```csharp
// Lucene.NET default behavior with OR operator
var query = parser.Parse("xml json yaml"); // default: OR between terms

// SQL Server FREETEXT — similar to "any word" + stemming
var results = context.Documents
    .Where(d => EF.Functions.FreeText(d.Content, "xml json yaml"));
```

### all words

Matches documents containing **all** of the specified words, but not necessarily as a phrase or in order:

```xquery
(: Matches documents containing "xml" AND "database" AND "query" :)
//doc[ft:contains(., "xml database query" using mode all words)]
```

The document `"This query language processes XML and stores results in a database"` would match because all three words appear somewhere in the text.

**C# parallel:**
```csharp
// SQL Server CONTAINS with AND
var results = context.Documents
    .Where(d => EF.Functions.Contains(d.Content, "\"xml\" AND \"database\" AND \"query\""));
```

### phrase

Matches the exact phrase — all words must appear consecutively in order:

```xquery
(: Only matches the literal phrase "xml database" :)
//doc[ft:contains(., "xml database" using mode phrase)]
```

This is the most restrictive mode. The document must contain the exact sequence `"xml database"` as consecutive words.

**C# parallel:**
```csharp
// SQL Server CONTAINS with phrase
var results = context.Documents
    .Where(d => EF.Functions.Contains(d.Content, "\"xml database\""));
```

### Comparison Table

| Mode | Search: `"xml database query"` | Matches |
|------|-------------------------------|---------|
| `any word` | Any of: xml, database, query | "This xml file..." |
| `all words` | All of: xml, database, query | "The xml query uses a database" |
| `phrase` | Exact phrase | "...xml database query language..." |

---

## Logical Combinations

Full-text search expressions support `ftand`, `ftor`, and `ftnot` for combining search conditions. These operate at the full-text level (not the XPath level), so they apply within a single `ft:contains` call.

### ftand — Both Terms Required

```xquery
(: Document must contain both "xml" and "database" :)
//doc[ft:contains(., "xml" ftand "database")]
```

This is different from `all words` mode because each operand can be its own search expression with independent options:

```xquery
(: "xml" with stemming AND "database" with wildcards :)
//doc[ft:contains(.,
  ("xml" using stemming) ftand ("data*" using wildcards)
)]
```

### ftor — Either Term Matches

```xquery
(: Document contains "xml" or "json" (or both) :)
//doc[ft:contains(., "xml" ftor "json")]

(: Three-way OR :)
//doc[ft:contains(., "xml" ftor "json" ftor "yaml")]
```

### ftnot — Exclude Terms

```xquery
(: Contains "database" but NOT "relational" :)
//doc[ft:contains(., "database" ftnot "relational")]

(: NoSQL documents: contain "database" but not "sql" or "relational" :)
//doc[ft:contains(., "database" ftnot ("sql" ftor "relational"))]
```

### Complex Combinations

```xquery
(: (xml AND database) OR (json AND nosql), but NOT tutorial :)
//doc[ft:contains(.,
  (("xml" ftand "database") ftor ("json" ftand "nosql"))
  ftnot "tutorial"
)]
```

**C# parallel:**
```csharp
// SQL Server CONTAINS with complex logic
var results = context.Documents.Where(d =>
    EF.Functions.Contains(d.Content,
        "(\"xml\" AND \"database\") OR (\"json\" AND \"nosql\") AND NOT \"tutorial\""));

// Lucene.NET with BooleanQuery
var query = new BooleanQuery();
query.Add(xmlAndDb, Occur.SHOULD);
query.Add(jsonAndNosql, Occur.SHOULD);
query.Add(tutorial, Occur.MUST_NOT);
```

---

## Positional Filters

Positional filters constrain where and how search terms appear relative to each other.

### ordered

Terms must appear in the specified order (but not necessarily consecutively):

```xquery
(: "introduction" must appear before "conclusion" :)
//doc[ft:contains(., "introduction" ftand "conclusion" ordered)]
```

A document with `"Introduction ... several pages ... Conclusion"` matches. A document where `"Conclusion"` appears before `"Introduction"` does not.

### window

Terms must appear within a specified number of tokens (words) of each other:

```xquery
(: "xml" and "database" within 5 words of each other :)
//doc[ft:contains(., "xml" ftand "database" window 5 words)]
```

The sentence `"XML is a popular database format"` matches (4 words between). The sentence `"XML was designed in the 1990s and is now used by every major database vendor"` does not (too many words between).

### distance

Similar to `window`, but specifies the minimum and maximum distance:

```xquery
(: "xml" and "schema" between 1 and 3 words apart :)
//doc[ft:contains(., "xml" ftand "schema" distance at most 3 words)]
```

### at start / at end / entire content

Constrain where in the text the match must occur:

```xquery
(: Title must START with "Introduction" :)
//doc[ft:contains(title, "Introduction" at start)]

(: Title must END with "Guide" :)
//doc[ft:contains(title, "Guide" at end)]

(: Title must be exactly "User Guide" (entire content) :)
//doc[ft:contains(title, "User Guide" entire content)]
```

### Combining Positional Filters

```xquery
(: "xml" then "query" in order, within 3 words :)
//doc[ft:contains(.,
  "xml" ftand "query"
  ordered
  window 3 words
)]
```

**C# parallel:**
```csharp
// SQL Server CONTAINS with NEAR
var results = context.Documents.Where(d =>
    EF.Functions.Contains(d.Content, "NEAR((xml, query), 3, TRUE)"));
// TRUE = ordered, 3 = max distance
```

---

## Full-Text Functions

Beyond `ft:contains`, the Full-Text specification provides utility functions.

### ft:score()

Returns a relevance score (between 0.0 and 1.0) for how well a node matches a search expression:

```xquery
for $article in //article
let $score := ft:score($article/body, "machine learning")
where $score > 0
order by $score descending
return
  <result score="{ $score }">
    <title>{ $article/title/text() }</title>
  </result>
```

Scoring considers term frequency (how often the term appears), document length, and the specificity of the match.

### ft:tokenize()

Breaks text into tokens (words) according to full-text tokenization rules:

```xquery
ft:tokenize("Hello, world! This is a test.")
(: Result: ("Hello", "world", "This", "is", "a", "test") :)

ft:tokenize("C# is great", "en")
(: Result: ("C#", "is", "great") :)
```

**C# parallel:**
```csharp
// Lucene.NET tokenization
var tokenStream = analyzer.GetTokenStream("field", "Hello, world! This is a test.");
```

### ft:stem()

Returns the stem of a word for a given language:

```xquery
ft:stem("running", "en")   (: Result: "run" :)
ft:stem("databases", "en")  (: Result: "databas" :)
ft:stem("better", "en")     (: Result: "better" or "good" depending on stemmer :)
```

### ft:is-stop-word()

Tests whether a word is a stop word in a given language:

```xquery
ft:is-stop-word("the", "en")   (: Result: true() :)
ft:is-stop-word("xml", "en")   (: Result: false() :)
```

### ft:thesaurus-lookup()

Looks up synonyms in a thesaurus:

```xquery
ft:thesaurus-lookup("thesaurus.xml", "fast")
(: Result: ("quick", "rapid", "speedy") :)
```

---

## Scoring and Relevance

Scoring lets you rank search results by relevance, just like a web search engine returns the most relevant pages first.

### Basic Relevance Ranking

```xquery
for $doc in collection("articles")
let $score := ft:score($doc, "xquery full text search")
where $score > 0
order by $score descending
return
  <result relevance="{ round($score * 100) }%">
    <title>{ $doc//title/text() }</title>
    <excerpt>{ substring($doc//body, 1, 200) }</excerpt>
  </result>
```

### Boosting Specific Fields

You can weight matches in different fields by combining scores:

```xquery
for $article in collection("articles")
let $title-score := ft:score($article/title, "xquery") * 3  (: title matches worth 3x :)
let $body-score := ft:score($article/body, "xquery")
let $total-score := $title-score + $body-score
where $total-score > 0
order by $total-score descending
return
  <result score="{ round($total-score * 100) div 100 }">
    <title>{ $article/title/text() }</title>
  </result>
```

**C# parallel:**
```csharp
// Lucene.NET field boosting
var titleQuery = new TermQuery(new Term("title", "xquery")) { Boost = 3.0f };
var bodyQuery = new TermQuery(new Term("body", "xquery"));
var combined = new BooleanQuery();
combined.Add(titleQuery, Occur.SHOULD);
combined.Add(bodyQuery, Occur.SHOULD);
```

### Pagination with Scoring

```xquery
let $page := 1
let $page-size := 10
let $all-results :=
  for $doc in collection("articles")
  let $score := ft:score($doc, "xquery tutorial")
  where $score > 0
  order by $score descending
  return
    <result score="{ $score }">
      <title>{ $doc//title/text() }</title>
    </result>
return
  <page number="{ $page }" total="{ count($all-results) }">
    { subsequence($all-results, ($page - 1) * $page-size + 1, $page-size) }
  </page>
```

---

## Practical Examples

### Document Search System

A complete document search with faceted results:

```xquery
declare variable $query external;  (: search query from user :)
declare variable $category external;  (: optional category filter :)

let $results :=
  for $doc in collection("documents")
  let $score := ft:score($doc, $query using stemming using language "en")
  where $score > 0
  where if ($category) then $doc/@category = $category else true()
  order by $score descending
  return $doc

let $categories :=
  for $cat in distinct-values($results/@category)
  let $count := count($results[@category = $cat])
  order by $count descending
  return <facet name="{ $cat }" count="{ $count }"/>

return
  <search-results query="{ $query }" total="{ count($results) }">
    <facets>{ $categories }</facets>
    <results>
    {
      for $doc at $pos in subsequence($results, 1, 20)
      return
        <result rank="{ $pos }">
          <title>{ $doc//title/text() }</title>
          <category>{ string($doc/@category) }</category>
          <score>{ ft:score($doc, $query) }</score>
        </result>
    }
    </results>
  </search-results>
```

### Content Management — Search and Highlight

```xquery
declare function local:search-articles(
  $terms as xs:string,
  $max-results as xs:integer
) as element(results) {
  let $matches :=
    for $article in collection("cms")/article
    where ft:contains($article/body, $terms
      using stemming
      using case insensitive
      using stop words default
      using language "en")
    let $score := ft:score($article/body, $terms)
    order by $score descending
    return $article
  return
    <results total="{ count($matches) }">
    {
      for $m in subsequence($matches, 1, $max-results)
      return
        <article id="{ $m/@id }">
          <title>{ $m/title/text() }</title>
          <author>{ $m/metadata/author/text() }</author>
          <date>{ string($m/metadata/date) }</date>
          <snippet>{ substring(string($m/body), 1, 300) }...</snippet>
        </article>
    }
    </results>
};

local:search-articles("machine learning neural networks", 10)
```

### Log Analysis

Search application logs for error patterns:

```xquery
(: Find error log entries mentioning timeout or connection issues :)
for $entry in collection("logs")/log-entry
where ft:contains($entry/message,
  ("timeout" ftor "connection refused" ftor "connection reset")
  ftnot "expected"
  using case insensitive)
where xs:dateTime($entry/@timestamp) > current-dateTime() - xs:dayTimeDuration("P1D")
order by xs:dateTime($entry/@timestamp) descending
return
  <alert>
    <time>{ string($entry/@timestamp) }</time>
    <level>{ string($entry/@level) }</level>
    <message>{ $entry/message/text() }</message>
    <source>{ $entry/source/text() }</source>
  </alert>
```

### Multi-Language Search

```xquery
(: Search with language-appropriate stemming :)
declare function local:search(
  $collection as xs:string,
  $terms as xs:string,
  $lang as xs:string
) as element()* {
  for $doc in collection($collection)
  where ft:contains($doc, $terms
    using stemming
    using language $lang
    using stop words default)
  let $score := ft:score($doc, $terms)
  order by $score descending
  return $doc
};

(: English search — "running" matches "run" :)
local:search("articles-en", "running databases", "en")

(: German search — "Datenbanken" matches "Datenbank" :)
local:search("articles-de", "Datenbanken", "de")
```

### C# Integration — Running Full-Text Queries

```csharp
// Running full-text XQuery from a .NET application
var engine = new XQueryEngine();
engine.SetVariable("query", userSearchInput);
engine.SetVariable("category", selectedCategory ?? "");

string xquery = @"
    declare variable $query external;
    declare variable $category external;

    for $doc in collection('articles')
    let $score := ft:score($doc, $query using stemming using language 'en')
    where $score > 0
    where if ($category != '') then $doc/@category = $category else true()
    order by $score descending
    return
      <result>
        <title>{ $doc//title/text() }</title>
        <score>{ $score }</score>
      </result>
";

var results = await engine.ExecuteAsync(xquery);

// Map results to C# objects
var searchResults = results.Select(r => new SearchResult
{
    Title = r.Element("title")?.Value,
    Score = double.Parse(r.Element("score")?.Value ?? "0")
}).ToList();
```
