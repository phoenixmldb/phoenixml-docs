---
title: STE-Informed Style Guide
description: The prose ruleset for the language-reference docs, and how to run the checker
sort: 1
---

# Contributing: STE-Informed Style Guide

This guide governs prose in `docs/language-reference/`. It applies an
STE-informed clarity level, not strict ASD-STE100 conformance. Follow it for
every new or rewritten page.

## Why STE-informed, not strict STE

Strict Simplified Technical English bans all analogy and restricts vocabulary
to an approved dictionary. Our readers are developers. A well-placed
comparison to C#, LINQ, or Razor speeds comprehension. We keep the readability
rules of STE and quarantine the analogies into labeled callouts instead of
banning them. See "The quarantined-analogy rule" below.

## 1. The ruleset

Apply these rules to every sentence you write in prose:

1. Keep descriptive sentences to 25 words or fewer.
2. Keep procedural and instruction sentences to 20 words or fewer.
3. State one idea per sentence.
4. Write in active voice. Use present tense by default.
5. Use one approved term per concept. The word-list names the canonical term.
6. Include articles (a, an, the). Do not drop them for terseness.
7. Avoid idioms, slang, metaphors, and clever phrasing in prose.
8. State a caution or limitation before the step or feature it qualifies.
9. Keep list structure parallel and consistent.

### Before / after: sentence length and voice

BEFORE (from the old `xquery/conditionals.md`), 26 words, two ideas fused:

```text
This is the biggest mental shift for C# developers: every `if` is an
expression, not a statement, and it always produces a value that flows into
the result.
```

AFTER, split into three short sentences:

```text
In XQuery, every `if` is an expression, not a statement. It always produces
a value. That value flows into the result.
```

### Before / after: banned words

BEFORE (from the old `xquery/flwor-advanced.md`), using a banned word:

```text
This page covers the clauses that make FLWOR a genuinely powerful,
full-featured query tool.
```

The banned word `powerful` asserts a quality instead of naming a capability.
AFTER:

```text
This page covers the FLWOR clauses that group, sort, and window query
results.
```

### Before / after: terminology

BEFORE (from the old `xpath/data-types.md`), using a banned variant term:

```text
XPath does not convert a string to a number automatically in every context.
```

The word `convert` is a banned variant of the canonical term `transform`.
AFTER:

```text
XPath does not transform a string to a number automatically in every
context.
```

## 2. The quarantined-analogy rule

Developer analogies stay useful, but instructional prose must not carry them
inline. Move each analogy into a labeled callout: a blockquote that starts
with `For C# developers:` or `For .NET developers:`.

### Before

From the old `xslt/first-transform.md`, an analogy woven into the claim:

```text
If you've written Razor views, this should feel familiar — it's a template
with embedded expressions. The difference is that the "expressions" are
XPath, and the matching is automatic.
```

This sentence is conversational, runs long, and blends the analogy into a
claim about XSLT itself. A reader with no Razor background gets no separate,
skippable path through the paragraph.

### After

The instructional paragraph now stands on its own:

An XSLT stylesheet pairs a template with match patterns. The template holds
literal output. The match patterns select input nodes and fill embedded
XPath expressions with their values.

The analogy moves into a labeled, skippable callout placed right after it:

> For C# developers: a stylesheet resembles a Razor view. Both mix literal
> output with embedded expressions. XSLT's expressions are XPath, and its
> pattern matching runs automatically against the input tree.

### Why the checker treats callouts differently

The checker suppresses banned-word and terminology checks inside a callout
blockquote once its first line matches an entry in `callout_prefixes`
(`tools/ste-wordlist.yaml`). A callout may use looser, more conversational
language than the surrounding prose, because it is opt-in and clearly
labeled. Sentence-length, passive-voice, and gerund-lead checks still run
inside a callout.

## 3. The exemption list

The checker skips these regions entirely; write them however best serves the
reader:

- YAML front-matter (the `---` block at the top of each file).
- Fenced code blocks (` ``` `).
- Inline code spans (`` `like this` ``).
- XPath and XSLT syntax shown outside fenced blocks.
- Tables, including function-signature tables.
- Link URLs (the checker strips a Markdown link to its visible text).

Established multi-word technical names keep their form. This applies even
when a component word ends in "-ing". "Path Expressions" and "Template
Matching" are not gerund-lead violations.

## 4. Running the checker

Run the checker from the `phoenixml-docs/` directory:

```bash
python3 tools/ste_check.py docs/language-reference/xslt/first-transform.md
```

Check several files or a whole directory tree with shell globs:

```bash
python3 tools/ste_check.py docs/language-reference/xquery/*.md
```

### Reading findings

Each finding prints on one line:

```
path:line: [SEVERITY] code: message
```

For example:

```
docs/language-reference/xpath/data-types.md:65: [ERROR] sentence-length: sentence has 27 words (max 25): "..."
```

`path` and `line` locate the offending text. `SEVERITY` is `ERROR` or `WARN`.
`code` names the check: `sentence-length`, `banned-word`, `terminology`,
`placeholder`, `passive-voice`, or `gerund-lead`. `message` explains the
problem and, for banned words and terminology, names the replacement.

### Error vs. warning severity

ERROR findings fail the build: sentence-length, banned-word, terminology, and
placeholder. Fix every ERROR finding before you commit a page.

WARN findings do not fail the build by default: passive-voice and
gerund-lead. These are heuristics with known false positives. Read each one,
rewrite where it genuinely helps, and leave it where the heuristic misfired.

### Exit codes and `--strict`

The checker exits 0 when a file has zero ERROR findings and exits 1
otherwise. Pass `--strict` to also fail on WARN findings:

```bash
python3 tools/ste_check.py --strict docs/language-reference/xslt/index.md
```

Do not use `--strict` for routine authoring. Use it only when you want a
zero-warning pass on a specific page.

## 5. Proposing a word-list change

The word-list lives at `tools/ste-wordlist.yaml`. It defines the banned
words, the canonical term per concept, the callout prefixes, and the passive-
voice allowlist.

To propose a new banned word or a new canonical term:

1. Open `tools/ste-wordlist.yaml`.
2. Add the entry under `banned` (with a suggested replacement) or under
   `terminology` (with the canonical term and its variants).
3. Re-run the checker against a representative set of pages to confirm the
   change does not introduce a flood of new findings.
4. Note the word-list change in your PR or commit message, with the reason
   for the addition.

Keep the list small and evidence-based. Add an entry only after you observe
the term causing real inconsistency across pages, not in anticipation of a
future page.
