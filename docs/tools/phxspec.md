---
title: phxspec CLI
description: Command-line XSpec runner — execute XSpec test suites for XSLT with no JVM and no Saxon
sort: 4
version: 1.0.0
---

# phxspec CLI

The `phxspec` command runs [XSpec](https://github.com/xspec/xspec) test suites against the
PhoenixmlDb XSLT engine. XSpec is a behaviour-driven test framework for XSLT, XQuery and
Schematron. It is maintained by the XSpec project, not by Phoenixml.

XSpec normally runs on Saxon under a Java runtime. `phxspec` embeds the XSpec compiler
stylesheets and runs them on the PhoenixmlDb engine instead. You need neither a JVM nor Saxon.

## Installation

```bash
dotnet tool install -g PhoenixmlDb.XSpec.Cli
```

The tool installs the `phxspec` command. Check the installed version with
`dotnet tool list --global`.

## Usage

```
phxspec <suite.xspec> [suite2.xspec ...]
phxspec --census <path> [path ...]
```

### Running one suite

Pass one or more `.xspec` files. The tool compiles each suite, runs it, and reports each
assertion.

```bash
phxspec test/my-stylesheet.xspec
```

### Sweeping many suites

The `--census` form sweeps a directory tree or a list of files. It prints a Markdown report to
standard output. The report has four sections: a summary, a pick-list grouped by error code, the
skipped suites, and per-suite detail.

```bash
phxspec --census test/ > census.md
```

Each path is either a directory or a single `.xspec` file. A directory is swept recursively for
`*.xspec`.

### Options

| Option | Description |
|--------|-------------|
| `--census <path>...` | Sweep suites and print a Markdown census to standard output |

### Environment variables

| Variable | Description |
|----------|-------------|
| `PHXSPEC_SUITE_TIMEOUT_SECONDS` | Time limit per suite. The default is 300. A suite that overruns is reported as `PHXSPEC-TIMEOUT`, and the sweep continues. |

## Exit codes

The single-suite form and the `--census` form use different exit codes.

Single-suite form:

| Code | Meaning |
|------|---------|
| 0 | Every suite ran to completion with no failing tests |
| 1 | At least one suite ran to completion and had failing tests |
| 2 | A suite failed to compile, failed to run, or its report could not be read |

`--census` form:

| Code | Meaning |
|------|---------|
| 0 | The sweep ran and the census was printed |
| 2 | A given path does not exist, or no `*.xspec` suites were found |

## Reading a census

A census reports the **stage** each suite reached, not only whether its assertions passed. The
stages are `Compile`, `Run`, `Assess`, `Complete` and `Skipped`.

Only `Complete` means the suite ran end to end. A suite that stops at `Compile` or `Run` reports
no assertion counts at all.

> **Caution:** a rising count of failing assertions does not always mean a regression. When a
> suite that previously stopped early begins to complete, its assertions join the totals for the
> first time. Compare the `Complete` count and the passing count together, and compare per suite
> rather than in aggregate.

## Suites this tool skips

`phxspec` runs XSLT suites. It reports Schematron and XQuery suites as skipped.

## Related pages

- [xslt CLI](xslt-cli.md) — run a stylesheet directly
- [Tools](index.md) — the full tool list
