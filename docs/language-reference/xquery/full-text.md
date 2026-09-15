---
title: Full-Text Search
description: "XQuery Full-Text — the contains text clause, match options, and ft: functions"
sort: 10
---

# Full-Text Search

XQuery's built-in `contains()` function does exact substring matching. It finds `"data"` inside `"database"` but cannot search linguistically. XQuery Full Text adds language-aware matching: stemming, case-insensitive matching, and relevance scoring, evaluated as part of the query itself.

> **Important — verify before relying on this page.** This page was corrected against the engine on `main` as of 2026-09-14. Two things are worth knowing before you use any of it:
>
> 1. **The entry point is the `contains text` clause, not a function.** Earlier revisions of this page described a `ft:contains($node, "term")` function call. That function does not exist — compiling a query that calls it fails with `Unknown function: contains#2`. The real syntax is the W3C XQuery Full Text `contains text` clause shown below.
> 2. **`contains text` fails at query-compile time before `PhoenixmlDb.XQuery` 1.8.0.** On earlier releases every `contains text` query — with or without match options — throws a `NullReferenceException` from `PhoenixmlDb.XQuery.Analysis.SchemaFeatureChecker.VisitStepExpression`, before the query runs. A plain, non-full-text predicate compiles and runs fine, so the failure is specific to `contains text`. Tracked as [`phoenixmldb-xquery#15`](https://github.com/phoenixmldb/phoenixmldb-xquery/issues/15) and fixed in **1.8.0**, which the engine now pins. On 1.8.0 and later the clause compiles and evaluates; verified by running the examples on this page through the published `xquery4` 1.8.0 tool.

## contains text — The Basic Clause

`contains text` is an XQuery expression, not a function: an operand (the node or nodes to search) on the left, the clause, then a full-text selection (what to look for) on the right.

```xquery
(: Search the description element for "database" :)
//book[description contains text "database"]
```

```xquery
(: Search ALL text content of the book element :)
//book[. contains text "xml query"]
```

```xquery
(: Search with match options :)
//book[title contains text "xml" using stemming using case insensitive]
```

### Searching Multiple Fields

```xquery
(: Search title OR description :)
//book[title contains text "xml" or description contains text "xml"]
```

### Using contains text in FLWOR Expressions

```xquery
for $article in //article
where $article/body contains text "machine learning"
order by ft:score($article/body) descending
return
  <result>
    <title>{ $article/title/text() }</title>
    <score>{ ft:score($article/body) }</score>
  </result>
```

`ft:score` takes the node, not the search term — see [ft:score()](#ftscore), below, for why.

---

## Match Options

Match options follow the search string and control how matching is performed, combined with successive `using` clauses. The grammar accepts more options than the engine currently acts on — each subsection below says which.

### Language

```xquery
//article[. contains text "running" using language "en"]
```

Affects stemming rules and tokenization. **Functional.**

### Stemming

```xquery
(: Without stemming — only matches literal "running" :)
//article[. contains text "running"]

(: With stemming — matches "run", "runs", "running", "ran" :)
//article[. contains text "running" using stemming]
```

**Functional.**

### Case Sensitivity

```xquery
(: Default: case insensitive — matches "XML", "xml", "Xml" :)
//doc[title contains text "xml"]

(: Case sensitive — only matches exact case :)
//doc[title contains text "XML" using case sensitive]
```

**Functional.**

### Diacritics, Wildcards, Stop Words, and Thesaurus — parsed, not applied

The grammar also accepts `using diacritics sensitive`/`insensitive`, `using wildcards`/`no wildcards`, `using stop words (...)`/`using no stop words`, and `using thesaurus "file"`. All four parse without error and are carried into the query's AST — but none of them currently reach the analyzer that does the actual matching. A query like:

```xquery
//doc[name contains text "cafe" using diacritics sensitive]
//doc[. contains text "data" using wildcards]
//doc[. contains text "the art of war" using stop words ("the", "of")]
//doc[. contains text "fast" using thesaurus "thesaurus.xml"]
```

compiles (modulo the `contains text` defect above) but behaves exactly as if the `using` clause were absent: diacritics are always folded, no glob expansion happens, no term is excluded as a stop word, and no synonym is added. Treat these four as accepted-but-inert until the underlying analyzer is wired up.

Two syntax forms that look plausible are not supported at all — they fail to parse:

- **There is no `using stop words default`.** The only stop-word forms the grammar accepts are an explicit list (`using stop words ("the", "a", "an")`) or `using no stop words`. There is no keyword for "use the language's built-in list" — and per above, even the explicit-list and no-stop-words forms don't currently change matching.
- **There is no `using thesaurus at "file" relationship "type"`.** The grammar accepts exactly one string literal: `using thesaurus "thesaurus.xml"`. `at` and `relationship` are not part of it.

### Combining Match Options

Options are composable at the grammar level:

```xquery
//article[body contains text "running"
  using stemming
  using case insensitive
  using language "en"]
```

---

## Positional Filters

Positional filters constrain where and how search terms appear relative to each other, and follow the full-text selection (not the match options):

```xquery
(: "introduction" must appear before "conclusion" :)
//doc[. contains text ("introduction" ftand "conclusion") ordered]

(: "xml" and "database" within 5 words of each other :)
//doc[. contains text ("xml" ftand "database") window 5 words]
```

The grammar also defines `distance N words`, `same sentence`, `same paragraph`, `at start`, `at end`, and `entire content`. As with the match options above, this page has not verified which of these actually change matching versus parse-and-ignore — the `contains text` compile failure blocks testing all of them the same way. Confirm behavior against your own build before depending on a specific filter.

---

## Logical Combinations

`ftand`, `ftor`, and `ftnot` combine search conditions inside a single full-text selection — they are not XPath's `and`/`or`, and don't need a repeated `contains text`:

```xquery
(: Document must contain both "xml" and "database" :)
//doc[. contains text ("xml" ftand "database")]

(: Document contains "xml" or "json" :)
//doc[. contains text ("xml" ftor "json")]

(: Contains "database" but NOT "relational" :)
//doc[. contains text ("database" ftnot "relational")]
```

---

## Full-Text Functions

These are ordinary functions in the `http://www.w3.org/2007/xpath-full-text` namespace (conventionally bound to `ft:`) — unlike `contains text`, they use normal function-call syntax.

### ft:score()

```
ft:score($node as node()) as xs:double
```

Takes **one argument** — the node — not the node and a search term. It returns the relevance score from the *most recent `contains text` evaluation* against that node, so call it after (or within the same FLWOR iteration as) a `contains text` clause that evaluated the same node — as in the FLWOR example above. Calling it with a node that was never evaluated by `contains text` returns `0.0`.

### ft:tokenize()

```
ft:tokenize($text as xs:string?) as xs:string*
ft:tokenize($text as xs:string?, $language as xs:string) as xs:string*
```

Breaks text into tokens using the full-text analyzer — useful for understanding how a string will be indexed or matched.

```xquery
ft:tokenize("Hello, world! This is a test.")
(: ("Hello", "world", "This", "is", "a", "test") :)
```

### ft:stem()

```
ft:stem($term as xs:string) as xs:string
ft:stem($term as xs:string, $language as xs:string) as xs:string
```

```xquery
ft:stem("running", "en")   (: "run" :)
```

### ft:is-stop-word()

```
ft:is-stop-word($term as xs:string, $language as xs:string) as xs:boolean
```

Tests whether a word is a stop word for a given language — implemented independently of the (currently inert) `using stop words` match option above.

### ft:thesaurus-lookup()

```
ft:thesaurus-lookup($thesaurus as xs:string, $term as xs:string) as xs:string*
```

---

## Practical Examples

### Document Search with Scoring

```xquery
declare variable $query external;

for $doc in collection("documents")
where $doc contains text { $query } using stemming using language "en"
let $score := ft:score($doc)
where $score > 0
order by $score descending
return
  <result score="{ $score }">
    <title>{ $doc//title/text() }</title>
  </result>
```

Note the `{ $query }` form: a full-text selection can be a computed string (`{ expr }`), not only a string literal, so the search term can come from a variable.

### Content Management — Search and Highlight

```xquery
declare function local:search-articles(
  $terms as xs:string,
  $max-results as xs:integer
) as element(results) {
  let $matches :=
    for $article in collection("cms")/article
    where $article/body contains text { $terms } using stemming using case insensitive using language "en"
    let $score := ft:score($article/body)
    order by $score descending
    return $article
  return
    <results total="{ count($matches) }">
    {
      for $m in subsequence($matches, 1, $max-results)
      return
        <article id="{ $m/@id }">
          <title>{ $m/title/text() }</title>
        </article>
    }
    </results>
};

local:search-articles("machine learning neural networks", 10)
```

### Multi-Language Search

```xquery
declare function local:search(
  $collection as xs:string,
  $terms as xs:string,
  $lang as xs:string
) as element()* {
  for $doc in collection($collection)
  where $doc contains text { $terms } using stemming using language { $lang }
  let $score := ft:score($doc)
  order by $score descending
  return $doc
};

(: English search — "running" matches "run" :)
local:search("articles-en", "running databases", "en")
```

---

## Full-text index acceleration

On 1.8.0 and later, `contains text` evaluates by scanning; it does not consult PhoenixmlDb's Lucene-backed full-text index. That index exists (see [Full-Text Search](../../phoenixmldb/full-text-search.md) in the PhoenixmlDb section) but is reached through `IndexManager.SearchFullText`, a separate C# entry point — not through this XQuery clause. Accelerating `contains text` with that index is planned but not built, and has a documented prerequisite: the index matches phrases more strictly than `contains text` itself does, so using it as a naive candidate source would silently drop matches the scanning evaluator would otherwise confirm.

## See also

- [PhoenixmlDb Full-Text Search](../../phoenixmldb/full-text-search.md) — the Lucene-backed index this page's `contains text` does not (yet) use
