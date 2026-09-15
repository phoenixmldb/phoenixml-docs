# SUPERSEDED — do not implement this file

> **Superseded 2026-09-15 by the namespace-consolidation design**, `endpointsystems/phoenixml`
> @ `c05d3fb`, `docs/superpowers/specs/2026-09-15-namespace-consolidation-design.md`.
>
> **`ft` is being retired, not bound.** All six extension functions move to `phx` →
> `https://schemas.phoenixml.dev/2026/functions`, predeclared by the XQuery library:
> `phx:metadata`, `phx:stem`, `phx:tokenize`, `phx:score`, `phx:is-stop-word`,
> `phx:thesaurus-lookup`. The W3C URI goes with it.
>
> **Everything below is therefore dead**, including the `//ft:x` warning — there will be no `ft`
> binding to collide with a document prefix. Kept only so that anyone who finds the branch sees
> why it is not to be acted on.
>
> Retained from below and still true: the **W3C facts**. The portability warning now published on
> `full-text.md` remains correct about the old URI and simply stops applying to ours once the
> functions move.

---

# Pending: the engine binds `ft` (UNRELEASED — SUPERSEDED)

**Not published.** Outside `docs/`, the only tree `build.sh` reads, so nothing here reaches
phoenixml.dev.

**Status: engine commit `e1464e7` on `origin/main`, UNRELEASED.** The engine version is still
`1.0.0-preview.1` and nothing has been published. Reviewed twice, full sweep on the exact tree,
revert check.

**The pages are correct as they stand and must not change yet.** With `PhoenixmlDb.XQuery` 1.8.0
— which is what is installable — the `declare namespace ft = …` prolog **is** required, and
`docs/language-reference/xquery/full-text.md` says so. That becomes stale only when a release
carries `e1464e7`.

Pre-release anchor, if a page must publish first: **"the engine at or after commit `e1464e7`,
built from source."**

Sources of truth at `e1464e7`: `RELEASES.md` "Querying" under 1.0.0-preview.1, and design 07 D8.

## What changes

- **Every query path** — per-document, index plan-once, spanning — has `ft` in scope.
  `ft:tokenize`, `ft:stem`, `ft:is-stop-word`, `ft:thesaurus-lookup` and `ft:score` need **no
  prolog**.
- **`ft` is resolved from the library, not hard-coded.** It binds to whatever namespace the
  XQuery library puts its `ft:` functions in — `http://www.w3.org/2007/xpath-full-text` with the
  pinned XQuery 1.8.0. **If the functions move (design 07 D7), the binding follows.**
- **Precedence matches `phx`:** a container's `ContainerOptions.DefaultNamespaces` binding for
  `ft` wins, and a query's own `declare namespace ft = …` overrides both.
- **`dbxml` is still not bound** (D6).
- **Validation:** `CreateContainerAsync` accepts `ft` bound to any non-empty string and rejects
  an empty URI.

## The behaviour change to warn about — this one is silent

**A container whose stored documents use `ft` as their own prefix.** Verified by probe:

```xquery
(: documents containing <ft:x xmlns:ft="urn:mine"/> :)
count(//ft:x)
```

| | result |
|---|---|
| before `e1464e7` | **`XPST0081`** — unbound prefix |
| at/after `e1464e7` | **`0`** — `ft` resolves to the full-text function namespace |

**An error becomes a wrong answer.** A query that used to fail loudly now returns a plausible
count of zero, and nothing says why. The remedy is to bind `ft` in that container's
`DefaultNamespaces`, which then wins.

Same exposure `phx` already has. It belongs on the page and not only in release notes, because
the people affected chose a two-letter prefix for their own documents and have no reason to read
our release notes about it.

## W3C facts — already correct on the page

Raw-text verified independently on both sides:

- The URI is the **W3C's**.
- The **`ft` prefix, and putting callable functions in that namespace, are the library's choice.**
- **Neither Full Text spec uses `ft`**, and neither defines callable functions there.

Design 07 D7/D8 and the engine code comment now say the same.
