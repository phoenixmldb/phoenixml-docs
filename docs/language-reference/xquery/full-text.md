---
title: Full-Text Search
description: "XQuery and XPath Full Text 3.0 — the contains text expression, match options, positional filters, scores and the phx: functions"
sort: 10
---

# Full-Text Search

XQuery's built-in `contains()` function does exact substring matching. It finds `"data"` inside
`"database"` but cannot search by words. XQuery and XPath Full Text 3.0 adds word-based matching:
stemming, case and diacritics options, stop words, thesauri, positional filters and relevance
scores, evaluated as part of the query.

PhoenixmlDb.XQuery implements all of the Full Text 3.0 grammar and passes the 672 applicable cases
of the W3C Full Text test suite (XQFTTS 1.0.4). The analyzer is built in: the library has no Lucene
dependency.

## contains text

`contains text` is an expression, not a function: the nodes or strings to search on the left, then
the full-text selection (what to look for) on the right.

```xquery
(: Search the description element for "database" :)
//book[description contains text "database"]

(: Search all text of the book element :)
//book[. contains text "xml query"]

(: With match options :)
//book[title contains text "xml" using stemming using case insensitive]
```

A string of several words is a phrase: the words must be adjacent and in order.
`"the walrus and the carpenter" contains text "walrus carpenter"` is false.

The search term can be computed. Put the expression in braces:

```xquery
declare variable $query external;
//article[body contains text { $query }]
```

`any`, `all`, `any word`, `all words` and `phrase` after the term choose how its words combine:

```xquery
<b>machine learning</b> contains text { "learning machine" } all words   (: true :)
```

### Tokens and element boundaries

Tokens follow the Unicode word boundaries (UAX #29). Tokens do not cross element tags, except where
a letter or digit touches the tag on both sides: `<p><b>p</b>rototypes</p> contains text
"prototypes"` is true. A paragraph ends at an element tag. A sentence ends at `.`, `!`, `?` and at the
end of a paragraph.

The same rule joins words across a tag: in `<d><p>xml</p><p>database</p></d>` the token is
`xmldatabase`, so `contains text ("xml" ftand "database")` is false. Put space between the words.
In a query, the default `declare boundary-space strip` removes the space between two constructed
elements; write the space inside an element, `<p>xml </p><p> database</p>`.

---

## Match options

Match options follow the search term, one `using` clause for each option. An option can also apply
to one primary only: `("dog" using stemming) ftand "cat"`.

The defaults are those of Full Text 3.0 Appendix C:

| Option | Default | Other values |
|---|---|---|
| Stemming | `no stemming` | `using stemming` |
| Case | `case insensitive` | `case sensitive`, `lowercase`, `uppercase` |
| Diacritics | `diacritics insensitive` | `diacritics sensitive` |
| Stop words | `no stop words` | `stop words ("a", …)`, `stop words at "uri"`, `stop words default`, with `union` and `except` |
| Wildcards | `no wildcards` | `using wildcards` |
| Thesaurus | `no thesaurus` | `thesaurus at "uri" relationship "…" N levels`, `thesaurus default`, `thesaurus ( … )` |
| Language | none | `language "en"` |

### Stemming

```xquery
"running" contains text "run"                   (: false: no stemming by default :)
"running" contains text "run" using stemming    (: true :)
```

The stemmer is Porter (1980), for English.

### Case and diacritics

```xquery
"XML" contains text "xml"                                 (: true :)
"XML" contains text "xml" using case sensitive            (: false :)
"café" contains text "cafe"                               (: true :)
"café" contains text "cafe" using diacritics sensitive    (: false :)
```

### Wildcards

```xquery
"database" contains text "data.*" using wildcards         (: true :)
```

`.` matches one character; `.*`, `.+`, `.?` and `.{n,m}` match a number of characters.

### Stop words

Stop words apply to the **query** only (Full Text 3.0 §3.4.7). A stop word in the search term
matches any one token of the text, and the text keeps all its tokens:

```xquery
"the walrus and the carpenter" contains text "the"                                   (: true :)
"the walrus and the carpenter" contains text "walrus the the carpenter"
    using stop words default                                                          (: true :)
"the art of war" contains text "art the war" using stop words ("the")                (: true :)
```

`stop words default` uses the host's default list (see [Stop word lists and thesauri](#stop-word-lists-and-thesauri)),
else the built-in English list.

### Thesaurus

```xquery
//doc[. contains text "fast" using thesaurus at "urn:example:thesaurus" relationship "UF"]
```

A thesaurus `at "uri"` comes from the host. With no resource for the URI the query gives FTST0018.

### Defaults for a whole module

`declare ft-option` in the prolog sets the default options of every `contains text` in the module:

```xquery
declare ft-option using stemming;
"running" contains text "run"     (: true :)
```

### Extension options

`using option prefix:name "value"` names an implementation option. The prefix must be declared
(else XPST0081). Options in a namespace the processor does not know are ignored, as the
specification requires.

---

## Logical combinations

`ftand`, `ftor`, `not in` and `ftnot` combine selections inside one `contains text`:

```xquery
//doc[. contains text ("xml" ftand "database")]
//doc[. contains text ("xml" ftor "json")]
//doc[. contains text ("database" ftand ftnot "relational")]
//doc[. contains text ("mexico" not in "new mexico")]
```

`ftnot` is a unary prefix: `("database" ftnot "relational")` is a syntax error (XPST0003). Combine
it with `ftand`.

## Cardinality and weight

```xquery
"a b a" contains text "a" occurs at least 2 times                    (: true :)
//doc[. contains text ("xml" weight {0.8}) ftor ("json" weight {0.2})]
```

`occurs exactly N times`, `at least`, `at most` and `from N to M times` are available. A weight must be
between -1000 and 1000; outside it the query gives FTDY0016.

## Positional filters

Positional filters follow the selection, in any combination:

```xquery
(: "introduction", then "conclusion" :)
//doc[. contains text ("introduction" ftand "conclusion") ordered]

(: inside a window of 5 words :)
//doc[. contains text ("xml" ftand "database") window 5 words]

(: at most 3 words between them :)
//doc[. contains text ("xml" ftand "database") distance at most 3 words]

//doc[. contains text ("xml" ftand "database") same sentence]
//doc[. contains text ("xml" ftand "database") different paragraph]
//doc[title contains text "introduction" at start]
//doc[title contains text "summary" at end]
//doc[code contains text "xml" entire content]
```

`window N words` matches only words that are inside N words of each other: `"xml a b database"`
matches `window 5 words`, and `"xml a b c d e f database"` does not.

`same paragraph` and `different paragraph` use the paragraphs of the [token rules](#tokens-and-element-boundaries):
`<d><p>xml </p><p> database</p></d>` matches `("xml" ftand "database") different paragraph`.

## Ignoring content

`without content` leaves out the text of the nodes that an expression selects. The expression is
evaluated outside the searched node, so refer to the node by a variable:

```xquery
for $a in //article
where $a contains text "xml" without content $a//footnote
return $a/title
```

## Extension selections

`(# prefix:name #) { … }` wraps a selection. The prefix must be declared (else XPST0081). A pragma
that the processor does not know is ignored, and the selection is evaluated as written:

```xquery
declare namespace ex = "urn:example";
<a>xml</a> contains text (# ex:fuzzy #) { "xml" }    (: true :)
```

---

## Scores

`score` variables give the relevance of each match, a value between 0 and 1:

```xquery
for $article score $s in //article[body contains text "machine learning"]
order by $s descending
return <result score="{ $s }">{ $article/title/text() }</result>
```

```xquery
let score $s := $doc contains text "xml"
return $s
```

Over `(<p>xml xml</p>, <p>xml</p>)`, the scores are `0.667` and `0.5`.

---

## Stop word lists and thesauri

A stop word list `at "uri"` and a thesaurus `at "uri"` come from the host, through
`IFullTextResourceResolver` (`QueryEngine.FullTextResources`):

```csharp
using PhoenixmlDb.XQuery.FullText;

var resources = new FullTextResources()
    .AddStopWords("urn:example:stop", ["the", "a", "an"])
    .AddThesaurus("urn:example:thesaurus", FullTextThesaurus.Load(XDocument.Load("thesaurus.xml")));
resources.StopWordsByDefault = ["the", "a", "an", "of"];   // for "using stop words default"

var engine = new QueryEngine { FullTextResources = resources };
```

`FullTextThesaurus` loads the W3C test format and its own format. With no resource for a URI, a stop
word list gives FTST0008 and a thesaurus gives FTST0018.

## Errors

The errors that the specification names: FTST0008, FTST0009, FTST0013, FTST0018, FTST0019, FTDY0016,
FTDY0017, FTDY0020 and XQST0089, plus XPST0003, XPTY0004 and XPST0081 where they apply.

---

## The phx: functions

These functions are in `https://schemas.phoenixml.dev/2026/functions`, with the prefix `phx`, which
every query has without a declaration. **No other XQuery processor provides them.**

### phx:stem()

```
phx:stem($term as xs:string) as xs:string
phx:stem($term as xs:string, $language as xs:string) as xs:string
```

```xquery
phx:stem("running", "en")   (: "run" :)
```

### phx:tokenize()

```
phx:tokenize($text as xs:string?) as xs:string*
phx:tokenize($text as xs:string?, $language as xs:string) as xs:string*
```

Gives the tokens of a full-text **index**: lower case, with stop words removed.

```xquery
phx:tokenize("Hello, world! This is a test.")   (: ("hello", "world", "test") :)
```

`contains text` keeps stop words in the text, so these tokens are not the tokens that a
`contains text` phrase is matched against.

### phx:is-stop-word()

```
phx:is-stop-word($word as xs:string) as xs:boolean
```

True for a word in the built-in English stop word list: `phx:is-stop-word("the")` is true,
`phx:is-stop-word("walrus")` is false.

### phx:score()

```
phx:score($node as node()) as xs:double
```

The score of the last `contains text` match on the node. It is `0` for a node that no `contains text`
matched. A `score` variable gives the same value with standard syntax.

```xquery
for $p in (<p>xml</p>, <p>json</p>)
where $p contains text "xml"
return phx:score($p)    (: 0.5 :)
```

### phx:thesaurus-lookup()

```
phx:thesaurus-lookup($term as xs:string) as xs:string*
phx:thesaurus-lookup($term as xs:string, $relationship as xs:string) as xs:string*
```

The term comes first. `phx:thesaurus-lookup("fast")` gives `("quick", "rapid", "swift", "speedy")`
from the built-in list.

---

## For hosts

- **Analyzers.** `IFullTextAnalyzer` and `FullTextAnalyzerRegistry` (`QueryEngine.FullTextAnalyzers`)
  let a host register an analyzer for a language. `contains text`, `phx:tokenize` and `phx:stem`
  use the registry, and `FullTextEngine.Analyze(text, options, registry)` lets an index use the same
  one.
- **Index candidates.** `IFullTextCandidateSource` (`QueryEngine.FullTextCandidates`) lets an index
  rule out items so that the evaluator does not read them. `contains text` skips only the items that the source rules out,
  so the results do not change. The source must give at least the candidates that the evaluator
  matches. `FullTextAnalysisOptions.FoldDiacritics` makes index tokens that find the candidates of
  a diacritics-insensitive query.

## See also

- [PhoenixmlDb Full-Text Search](../../phoenixmldb/full-text-search.md) — the full-text index of the
  database
- [W3C XQuery and XPath Full Text 3.0](https://www.w3.org/TR/xpath-full-text-30/)
