---
title: docmd CLI
description: Convert Microsoft Word documents to Markdown for retrieval indexes and human reading
sort: 4
version: 0.1.0
---

# docmd CLI

`docmd` converts Microsoft Word documents to Markdown — for retrieval indexes, documentation
pipelines, or simply to read them somewhere other than Word. It is built on the PhoenixmlDb XSLT
engine, and its entire semantic layer is an XSLT 3.0 stylesheet you can print, edit and hand back.

## Installation

```bash
dotnet tool install -g Docmd.Cli
```

After installation, the `docmd` command is available globally.

## Usage

```
docmd <input.docx> [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output directory (default: `.`) |
| `--style-map <file>` | Map house styles to Markdown constructs (YAML) |
| `--stylesheet <file>` | Run your own stylesheet instead of the built-in one |
| `--print-stylesheet` | Write the built-in stylesheet to stdout and exit |
| `--asset-base-url <url>` | Emit remote URLs for images while writing them locally |
| `--img-dir <name>` | Image folder name (default: `img`) |
| `--no-images` | Omit images entirely |
| `--flavour <name>` | `gfm` or `commonmark` (default: `gfm`) |
| `--front-matter <mode>` | `yaml` or `none` (default: `yaml`) |
| `-h, --help` | Show usage |
| `-V, --version` | Show the version |

Accepts `.docx`, `.docm`, `.dotx` and `.dotm`. Word 97-2003 `.doc` is a different, binary
format — re-save it as `.docx` first.

## What it produces

```bash
docmd report.docx -o out/
```

```markdown
---
title: Q3 Safety Review
author: A. Whitfield
created: '2026-04-11'
source: report.docx
sha256: 41ae9591…aefd
---

# Q3 Safety Review

The vent assembly is compliant with **AS9110** and *AS9100D*.

- First item
- Second item
  - Nested child
```

YAML frontmatter carries the document's properties and a SHA-256 of the source file, so a
converted corpus can be traced back to what produced it.

## Recovering structure, not extracting text

Nothing in OOXML says "this is a heading." Word offers several hints and real documents use all
of them, so `docmd` resolves headings through explicit outline level, the style's own level, the
style's inherited level, the style name, and finally direct formatting — recording which rule
fired so the decision is auditable rather than magic.

Lists are rebuilt from `numId` and `ilvl`, including nesting, because Word stores no nesting of
its own: every list item is a top-level paragraph carrying a number and a level.

That matters most for retrieval. Heading structure decides chunk boundaries — a missed heading
merges two chunks, a false positive shatters a paragraph.

## It reports what it could not read

Every conversion is measured. `docmd` compares the words a reader can see in the `.docx` against
the words a Markdown parser recovers from its own output, and reports any that did not survive,
naming the structure responsible:

```
! 2 of 3754 words did not survive conversion (99.9 % kept).
!   missing 'Here' near "the Discount List Click Here Click 'Add' to use"
!   one of them sits inside <drawing>.
!   one of them sits inside <txbxContent>.
```

Silent when nothing was lost, which on the reference corpus is most documents. A tool that warns
about healthy documents is a tool whose warnings get ignored.

## Deterministic output

The same input, version and options produce byte-identical Markdown: LF endings everywhere,
culture-invariant formatting, no timestamps, UTF-8 without a BOM. A corpus conversion is
reviewable in a diff.

## Customising the output

Two escape hatches, in increasing order of effort.

A **style map** tells `docmd` what your template's own styles mean, in YAML:

```yaml
CautionNote:   { as: blockquote, prefix: "Caution: " }
ProcedureStep: { as: ordered-list-item }
PartNumber:    { as: inline-code }
```

```bash
docmd report.docx --style-map house-styles.yaml
```

Keys match a `w:styleId` or the style name Word shows, whichever you have. Because a map fails
silently by nature — a misspelled id simply never matches — `docmd` reports both entries that
matched nothing and styles worth mapping.

When that is not enough, replace the transform:

```bash
docmd --print-stylesheet > mine.xslt
docmd report.docx --stylesheet mine.xslt
```

`--print-stylesheet` emits the stylesheet that really ran, so you edit what executed rather than
reconstructing it. It is one readable file of XSLT 3.0 and it is meant to be read.

## Source and limitations

[github.com/phoenixmldb/docmd](https://github.com/phoenixmldb/docmd) — Apache-2.0.

What is knowingly dropped, how large a document gets before conversion slows, and the measured
text-coverage figures are published in the repository's
[`docs/limitations.md`](https://github.com/phoenixmldb/docmd/blob/main/docs/limitations.md).

Not yet implemented, each failing with a clear message rather than doing nothing quietly:
`-r`/`--recursive`, `docmd audit`, `--review`, `--strict`, `--report` and `--revisions`.
