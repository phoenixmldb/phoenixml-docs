---
title: A converter that tells you what it lost
description: Building a Word-to-Markdown tool where the semantic layer is a stylesheet you can read, and every conversion is measured
sort: 1
---

# A converter that tells you what it lost

*10 September 2026*

Point a Word-to-Markdown tool at a folder of real business documents and you have almost
certainly indexed something incomplete without knowing it. Many, if not most Word documents found in the wild, are 
incredibly messy. Writing reactive code isnt' going to cut it - imagine having to try and anticipate:
- a callout in a text box
- a customer name inside a content control
- a table whose rows sit behind a legacy wrapper format. 

The output looks like a document, but how are you going to guarantee you captured it all? 

It's bad enough for a person to read an incomplete file - if they know it's incomplete, they'll be able to pick up on it. But it's a an entirely different problem altogether putting an incomplete output into a retrieval index, quietly degrading answers that got left out.

`docmd` is our Word-to-Markdown converter, and it makes two choices most converters do not.

## Convert with a Stylesheet - Not Code

`docmd`'s entire semantic layer leverages one **XSLT 3.0** transform and helps us translate
scenarios like:

- a paragraph format used as a heading
- how a Word list becomes a Markdown list
- which stretch of text is actually bold or italic

That last one sounds trivial and is not. Word stores text in *runs* — fragments that share
formatting — and it splits them constantly, at spell-check boundaries, at revision marks, mid
word. One visually continuous bold phrase routinely arrives as three separate runs, and
`<w:b w:val="0"/>` means **not** bold rather than bold, because these are toggles against an
inherited style rather than flags. Get that wrong and `**Safety Review**` comes out as
`**Safety****Review**`.


Another added benefit is, you can export ours, customize it to your needs, and get the Markdown you're looking for, like this:

```
$ docmd --print-stylesheet > mine.xslt
$ # edit it
$ docmd report.docx --stylesheet mine.xslt
```

`--print-stylesheet` emits the copy that *actually ran*, so you edit what executed rather than
reconstructing it from a repository at whatever version you happen to have. There is no
compiled-in behaviour to reverse-engineer and no plugin API to learn: the extension point is the
implementation.

In an era where people go completely out of their way to avoid using 'legacy' tools, it's good to remember that these tools exist for very good reasons. XSLT was literally built for parsing data - from flat files, to CSV, EDI and even JSON, XSLT provides a powerful tool to transform data from one type to another. Data and document conversion is pattern matching over a heterogeneous tree, which
is exactly the problem XSLT was designed for.

Think of the recursive code you'd have to write in C# what we built here in just a handful of lines of XSLT:

```xml
<xsl:template match="w:p[@docmd:heading-source and @docmd:heading-source ne 'None']" priority="3">
  <md:heading level="{xs:integer(@docmd:outline-level) + 1}" slug="{@docmd:slug}">
    <md:text><xsl:value-of select="docmd:visible-text(.)"/></md:text>
  </md:heading>
</xsl:template>
```

Priorities give you an override system for nothing. A user's style map lands at priority 4 and
beats every inference below it, so mapping a style to `para` demotes a heading deliberately —
and that took a number, not dispatch code.

Grouping is the other lever. Word stores no list nesting at all: every item is a top-level
paragraph carrying a numbering id and a level. Rebuilding a nested list is `for-each-group
group-adjacent` over the numbering key and a recursive named template that rebuilds depth from
`ilvl`. That is a dozen lines. The equivalent state machine is not.

Note that we're not even emitting Markdown with our XSLT; instead, it emits a small semantic vocabulary —
`md:heading`, `md:para`, `md:list` — and a C# serialiser turns that into text. Markdown is
whitespace-significant and context-sensitive: whether `_` starts emphasis depends on what is
adjacent, whether four spaces begin a code block depends on column position. Expressing that in
XSLT means fighting the one thing XSLT **is worst at**, in the file where you are trying to express
document semantics. So the stylesheet answers *what this is*, the serialiser answers *how it is
written*, and every escaping rule lives in one place. 

Instead, we build a Markdown document as XML, like this:

```xml
<md:document xmlns:md="https://phoenixml.dev/docmd/md">
  <md:heading level="1" slug="vent-inspection">
    <md:text>Vent Inspection</md:text>
  </md:heading>
  <md:para>
    <md:text>Torque to </md:text>
    <md:strong><md:text>40 Nm</md:text></md:strong>
    <md:text> before sealing.</md:text>
  </md:para>
  <md:list ordered="false">
    <md:item><md:para><md:text>Disconnect power</md:text></md:para></md:item>
    <md:item><md:para><md:text>Remove the panel</md:text></md:para></md:item>
  </md:list>
</md:document>
```

The serialiser turns it into:

```markdown
# Vent Inspection

Torque to **40 Nm** before sealing.

- Disconnect power
- Remove the panel
```

Notice `slug="vent-inspection"` and `ordered="false"` — the stylesheet has already decided the
hard things, and the serialiser only has to write them down.

## Every conversion is measured

`docmd` compares the words a reader can see in the `.docx` against the words recovered from its
own finished Markdown — recovered with a Markdown parser. That detail is the
design - if our escaping is wrong, an asterisk we failed to escape reads back as markup and the
word beside it goes missing. Our own code does not get a vote on whether our own output is
correct.

When words go missing, `docmd` prints this to stderr and carries on converting:

```
! 2 of 3754 words did not survive conversion (99.9 % kept).
!   missing 'Here' near "the Discount List Click Here Click 'Add' to use"
!   one of them sits inside <drawing>.
!   one of them sits inside <txbxContent>.
```

Those last two lines are not read from a list of constructs we know we skip. We tried that, and
it went stale the moment the converter learned to read text boxes — it cheerfully reported
"docmd does not read text boxes" about text boxes it had just read correctly. So the structure
is read from the document instead: for each missing word, which elements are wrapping it. A
wrapper nobody has heard of names itself the first time it costs someone a word.

When nothing is lost it prints nothing at all, which on a corpus of real business documents is
most of the time. A tool that warns you about healthy documents is a tool whose warnings you
learn to ignore.

Across the corpus we develop against — 49 real business documents spanning 2008 to 2024 — that
warning now fires on six of them, and the total loss is twelve words.

They are worth naming, because "twelve words" invites the reasonable question of *which*. They
are things like a Windows path made almost entirely of backslashes, a SQL identifier carrying
commas and parentheses inside its name, and a URL that the author had truncated with an
ellipsis. Each is a tokenisation edge — a place where "what counts as one word" differs between
the document and the Markdown — rather than a construct `docmd` cannot read. No reader would
notice them. We publish them anyway, because the number is only worth anything if the residue
comes with it.

The full account lives in [docmd's limitations page](https://github.com/phoenixmldb/docmd/blob/main/docs/limitations.md), and it is a dated measurement against a fixed
corpus rather than a claim.

## What a stylesheet gets wrong, and why we chose it anyway

The single most useful thing we learned is this: **XSLT's built-in rules lose nothing.** Feed a
document to an empty stylesheet and every word comes out. Text is only lost when you *override*
those defaults — which every real stylesheet does, the moment it writes something like
`select="w:r | w:ins | w:hyperlink"`.

That line is a whitelist. It says *process runs, insertions and hyperlinks* — and by omission,
*ignore everything else*. Word has a lot of everything else.

Here is the same paragraph — the words `alpha beta` — wrapped in different Word constructs, run
through a **narrow whitelist** and through an **empty stylesheet**. This is the shape of the
choice, not a report card on `docmd` today; where it stands now is the paragraph after.

| the text is inside… | narrow whitelist | empty stylesheet (built-in rules) |
|---|---|---|
| an ordinary run | `alpha beta` | `alpha beta` |
| a content control | **(nothing)** | `alpha beta` |
| a field's cached result | **(nothing)** | `alpha beta` |
| a text box | **(nothing)** | `alpha beta` |
| a field *code* | `alpha beta` | `PAGE \* MERGEFORMAT alpha beta` |
| text deleted under track changes | `alpha beta` | `WRONG PRICEalpha beta` |

Two failure modes, and they are not equivalent. **The whitelist omits:** words a reader can see
go missing, because nothing named the wrapper holding them. **The permissive one invents:** it
emits a field's *instruction* as though it were content, and welds a price the author deleted
onto the sentence that replaced it.

The trade is not close. For a contract heading into a retrieval index, a missing sentence is
recoverable; a deleted price presented as current is not. So you keep the whitelist — and you
had better know what it is omitting.

Which is what the measurement in the previous section is for. Every construct in the middle
three rows was invisible to us until the coverage check reported words going missing and named
the element they were sitting in. Content controls, fields, smart tags, text boxes and Word's
legacy `w:customXml` wrapper around table rows were each found that way — not by reading the
specification, which we had read.

**All five are read now.** Widening the whitelist to reach them took the corpus from 27
documents converting perfectly to 43, and the last two rows of that table still hold: field
codes and deleted text stay out, deliberately.

The whitelist will never be complete — OOXML keeps growing, and the next document will contain
something nobody has heard of. The point is that it now says so.

## The performance bug worth remembering

`docmd` runs on our own [PhoenixmlDb.Xslt](https://github.com/phoenixmldb/phoenixmldb-xslt) engine, bringing the most recent standards to a long-neglected parsing engine, which gives us some interesting tradeoffs.

For example, one Word document took 124 seconds to parse, where comparable ones took merely two. The cause was a single match
pattern with two chained predicates:

```xml
<xsl:template match="w:p[A][B]"/>      <!-- 54.1 ms per paragraph -->
<xsl:template match="w:p[A and B]"/>   <!--  0.32 ms per paragraph -->
```

This may require some performance tweaking on our part, so we've filed a bug with ourselves to pore over for an upcoming release - hopefully, by the time you read this, we've already handled it. As we stretch into the long-tail of bugfixes in the parser, however, you can expect more solutions like this to come into the .NET Core ecosystem, though hopefully not just from us. 

Take a look at what we've put together, and feel free to reach out. If you're new to XSLT, we've built MCP servers for [XSLT](https://www.nuget.org/packages/xslt-mcp) and [XQuery](https://www.nuget.org/packages/xquery-mcp) on NuGet that can help you familiarize yourself (and your agent) with what we're putting together over here.


