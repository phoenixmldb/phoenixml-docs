---
title: Reporting an engine bug
description: Narrow a problem to a small reproduction, then turn that reproduction into an XSpec test
sort: 1
version: 1.0.0
---

# Reporting an engine bug

This guide covers two jobs that share most of their work.

1. You found behaviour that looks wrong, and you want to report it.
2. You want a test that proves the behaviour, and that keeps proving it after a fix.

The first job produces a small reproduction. The second turns that reproduction into an
[XSpec](https://github.com/xspec/xspec) test. Do the first job even if you stop there. A
reproduction is the part of a report we cannot write for you.

## Before you start

Install the `xslt` tool and the `phxspec` runner.

```bash
dotnet tool install -g PhoenixmlDb.Xslt.Cli
dotnet tool install -g PhoenixmlDb.XSpec.Cli
```

Record the version you are running. The bug form asks for it.

```bash
xslt --version
```

## Part 1: narrow it to a small reproduction

### Step 1: reproduce it outside your application

Run the stylesheet directly with the `xslt` tool, against the smallest input that still shows the
problem.

```bash
xslt my-stylesheet.xsl input.xml
```

A problem that disappears here comes from how your application calls the engine, not from the
engine. That is still worth reporting, but it is a different report.

### Step 2: cut everything that does not change the outcome

Delete templates, imports, and input elements one at a time. Re-run after each deletion. Keep a
deletion when the problem still happens. Undo it when the problem goes away.

Stop when every remaining line is needed. A reproduction of ten lines is worth more than one of
two hundred, because it tells us where to look.

> **Caution:** cut the input as well as the stylesheet. A large input document often hides which
> node actually triggers the problem.

### Step 3: name what you expected

Write down what the engine did, and what you expected instead. If you know the relevant part of
the specification, say so. If you do not, describe the expected output. Either is enough.

Another processor's behaviour is also useful evidence. Say which processor and which version.

### Step 4: file the report

Open a bug report on the [issue tracker](https://github.com/phoenixmldb/.github/issues/new/choose).
The form asks for four things, and you now have all of them:

| Field | What you have |
|-------|---------------|
| What happened | The output or the error code from step 1 |
| What you expected instead | Your note from step 3 |
| Reproduction | The cut-down stylesheet and input from step 2 |
| Version | The output of `xslt --version` |

Paste the reproduction inline. Do not attach files or link a repository.

## Part 2: turn the reproduction into an XSpec test

XSpec is a behaviour-driven test framework for XSLT, XQuery and Schematron. The XSpec project
maintains it. Phoenixml ships a runner for it, so you need neither a JVM nor Saxon.

A test states the input, the call, and the expected result. Running it tells you whether the
behaviour is correct today, and tells us whether it stays correct later.

### Step 1: write the stylesheet under test

Save the stylesheet from Part 1. This example returns the length of a string.

```xml
<!-- length.xsl -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:my="urn:example:length" version="3.0" exclude-result-prefixes="#all">

  <xsl:template name="my:measure" as="xs:integer">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="string-length($text)"/>
  </xsl:template>

</xsl:stylesheet>
```

### Step 2: write the test

An XSpec suite is an XML document. `x:description` names the stylesheet under test. Each
`x:scenario` describes one situation. Each `x:expect` states one assertion.

```xml
<!-- length.xspec -->
<x:description xmlns:x="http://www.jenitennison.com/xslt/xspec"
  xmlns:my="urn:example:length" stylesheet="length.xsl">

  <x:scenario label="When measuring a four-character string">
    <x:call template="my:measure">
      <x:param name="text" select="'abcd'"/>
    </x:call>
    <x:expect label="the result is 4" select="4"/>
  </x:scenario>

</x:description>
```

`x:call` invokes a named template. Use `x:context` instead when you want to apply templates to a
node.

### Step 3: run it

```bash
phxspec length.xspec
```

The runner compiles the suite, runs it, and reports each assertion. It exits 0 when every
assertion passes, and 1 when an assertion fails.

### Step 4: make it fail first

Change the expected value to something you know is wrong, and run the suite again.

```xml
<x:expect label="the result is 4" select="5"/>
```

A test that has never failed has not been shown to test anything. Confirm the failure, then put
the correct value back.

> **Caution:** this step matters most when you are testing a bug. Write the test so it fails on
> the current engine and passes after the fix. A test written against broken behaviour locks the
> bug in place.

### Step 5: attach it to the report

Paste the suite into the bug report next to the reproduction. A report that arrives with a
failing XSpec test needs no further translation before someone can work on it.

## What we do with it

We run the reproduction, confirm the behaviour, and find the cause. We then add a test to the
engine's own suite so the behaviour cannot return. Your XSpec suite tells us what that test has
to assert.

## Credits

[XSpec](https://github.com/xspec/xspec) is an independent open-source project. It is not part of
Phoenixml. We ship a runner for it because it is the established way to test XSLT, and we would
rather support the existing framework than invent another one.

## Related pages

- [phxspec CLI](../tools/phxspec.md) — the runner, its options and its exit codes
- [xslt CLI](../tools/xslt-cli.md) — running a stylesheet directly
