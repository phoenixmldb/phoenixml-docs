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

> **This example does not produce useful output on 1.8.0.** `ft:score` returns `0.0` for every
> node on this release, so the ordering is arbitrary and every `<score>` is `0`. The shape is
> correct; the scores are not yet.

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

compiles but behaves exactly as if the `using` clause were absent: diacritics are always folded,
no glob expansion happens, no synonym is added, and **the analyzer's own stop-word handling is
unaffected by what you wrote**. Treat these four as accepted-but-inert until the underlying
analyzer is wired up.

> **`using no stop words` does not give you exact phrase matching.** The analyzer removes stop
> words regardless, and the option does not stop it. Measured on 1.8.0, `. contains text 'walrus
> carpenter'` matches `<p>the walrus and the carpenter</p>` **with and without**
> `using no stop words` — identical results. If you reach for this option to make a phrase
> position-exact against the source text, it will silently not do that. See
> [why the two phrase matchers differ](../../phoenixmldb/full-text-search.md#why-the-two-disagree-about-a-phrase).

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
//doc[. contains text ("database" ftand ftnot "relational")]
```

**`ftnot` is a unary prefix, not a binary infix.** Writing `("database" ftnot "relational")`
is a parse error — `XPST0003: mismatched input 'ftnot' expecting ')'`. Combine it with `ftand`
as above.

---

## Full-Text Functions

These are ordinary functions in `http://www.w3.org/2007/xpath-full-text` — unlike `contains text`,
they use normal function-call syntax.

> **These are PhoenixmlDb's own functions, not standard ones.** The W3C Full Text specification
> defines the `contains text` *clause*; it does not define any functions in that namespace. The
> URI and the `ft` prefix are this library's choice (`FunctionNamespaces.Ft`), so do not expect
> another XQuery processor to provide `ft:score` or `ft:stem`, and do not read the `w3.org` URI as
> a portability guarantee. The namespace they live in may change.

> **You must declare the prefix. The engine does not bind `ft`.**
> It binds `phx` and the container's `DefaultNamespaces`, and nothing else. Without a prolog every
> call below fails at compile time with `XPST0081: Unbound namespace prefix: ft`:
>
> ```xquery
> declare namespace ft = "http://www.w3.org/2007/xpath-full-text";
> ```
>
> Every example in this section assumes that declaration. Whether the engine should bind `ft` by
> default, as it does `phx`, is an open question — design 07 D6 settles `phx` and `dbxml`, not
> `ft`.

**Provenance.** The examples in this section were **not** covered by this page's original sample
verification. They were re-verified against engine `4231a6b` with `PhoenixmlDb.XQuery` 1.8.0 on
2026-09-14, and the signatures and outputs below are what that run produced.

### ft:stem()

```
ft:stem($term as xs:string) as xs:string
ft:stem($term as xs:string, $language as xs:string) as xs:string
```

```xquery
ft:stem("running", "en")   (: "run" :)
```

### ft:tokenize()

```
ft:tokenize($text as xs:string?) as xs:string*
ft:tokenize($text as xs:string?, $language as xs:string) as xs:string*
```

Breaks text into tokens **using the same analyzer `contains text` uses** — which is what makes it
useful: it shows you the stream your phrase queries are actually matched against.

```xquery
ft:tokenize("Hello, world! This is a test.")
(: ("hello", "world", "test") :)
```

**Tokens are lower-cased, and stop words are dropped.** `This`, `is` and `a` do not survive. If a
phrase query is matching more than you expect, running the text through `ft:tokenize` will usually
show you why — see
[why the two phrase matchers differ](../../phoenixmldb/full-text-search.md#why-the-two-disagree-about-a-phrase).

### ft:is-stop-word()

```
ft:is-stop-word($word as xs:string) as xs:boolean
```

**One argument, not two.** A two-argument call fails with `XPST0017: Unknown function:
is-stop-word#2`.

Observed on 1.8.0: it returns `false` for every input tried, including `"the"`, `"a"` and `"of"` —
words the analyzer demonstrably *does* remove. **This function and the analyzer do not currently
agree**, so do not use it to predict what `ft:tokenize` or `contains text` will do.

**On 1.8.0 this is a wiring bug, not a difference of configuration.** The two paths select
different built-in analyzers by accident: `ft:is-stop-word` analyzes with stemming off, which
picks an analyzer that has no stop-word filter at all, so every word produces a token and the
answer is always `false`. `contains text` and `ft:tokenize` run with stemming on, which picks the
English analyzer, and that one does remove stop words.

### ft:score()

```
ft:score($node as node()) as xs:double
```

Takes **one argument** — the node — not the node and a search term.

> **Scores are `0.0` on 1.8.0.** `ft:score` returns `0.0` even immediately after a matching
> `contains text` on the same node, so a `where $score > 0` filter returns nothing at all. Treat
> scoring as not working on this release. Raised for triage; not a documentation defect.

### ft:thesaurus-lookup()

```
ft:thesaurus-lookup($term as xs:string) as xs:string*
ft:thesaurus-lookup($term as xs:string, $relationship as xs:string) as xs:string*
```

**The term comes first.** An earlier revision of this page documented
`ft:thesaurus-lookup($thesaurus, $term)`, taking a thesaurus file as the first argument. Called
that way it returns an empty sequence.

---

## Practical Examples

> **Every example in this section that uses `ft:score` is shape-correct and does not work on
> 1.8.0.** Scores come back `0.0` for every node, so an `order by` on them is arbitrary and a
> `where $score > 0` filter returns **nothing at all**. They are kept because the query shape is
> right and will start working when scoring does. Each also needs the
> `declare namespace ft = "http://www.w3.org/2007/xpath-full-text";` prolog shown above.

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
