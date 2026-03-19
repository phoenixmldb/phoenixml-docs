---
title: Crucible
description: Static documentation generator — Markdown to XML to XSLT to HTML
sort: 3
---

# Crucible

Crucible is a static documentation generator that transforms Markdown into HTML through an XML intermediate representation and XSLT 4.0 transformation. It's built with the PhoenixmlDb XSLT engine — the same documentation site you're reading was built with Crucible.

## Installation

```bash
dotnet tool install -g Crucible.Cli
```

## Quick Start

```bash
# Create a new documentation project
crucible init

# Build the site
crucible build

# View the result
open dist/index.html
```

That's it. `crucible init` creates a `crucible.yaml` config file and a starter `docs/index.md`. `crucible build` generates a complete static site in `dist/`.

## How It Works

```
Markdown (.md) → Parse → XML (intermediate) → XSLT Transform → HTML (static site)
```

1. **Parse**: Markdown files with YAML frontmatter are parsed, transformed into an XML intermediate representation, and a site manifest is built from the directory structure.
2. **Transform**: XSLT stylesheets transform each XML document into HTML, generating navigation, SEO metadata, and a sitemap.
3. **Output**: A complete static site ready for deployment to Cloudflare Pages, GitHub Pages, Netlify, or any static hosting.

## Commands

### crucible init

Scaffolds a new documentation project in the current directory.

```bash
crucible init
crucible init --force    # Overwrite existing crucible.yaml
```

Creates:
- `crucible.yaml` — site configuration with commented defaults
- `docs/index.md` — starter homepage with example frontmatter

### crucible build

Builds the documentation site.

```bash
crucible build [options]
```

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--source <dir>` | `-s` | Source directory containing `.md` files | `./docs` |
| `--output <dir>` | `-o` | Output directory for generated site | `./dist` |
| `--theme <dir>` | `-t` | Custom theme directory | built-in default |
| `--base-url <url>` | | Base URL for links and sitemap | `/` |
| `--title <title>` | | Site title | from root `index.md` |
| `--stage <stage>` | | Build stage: `Full`, `ParseOnly`, `TransformOnly` | `Full` |
| `--clean` | | Delete output directory before building | |
| `--include-drafts` | | Include pages marked `draft: true` | |
| `--strict` | | Treat warnings as errors | |
| `--verbose` | `-v` | Verbose output | |
| `--timing` | | Show per-stage timing | |
| `--help` | `-h` | Show help | |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error (bad arguments, missing source directory) |
| 2 | Parse error (invalid Markdown or YAML) |
| 3 | Transform error (XSLT failure) |

## Configuration

### crucible.yaml

The optional configuration file. CLI flags override config values.

```yaml
# Site metadata
title: My Documentation
base-url: /

# Directories
source: ./docs
output: ./dist

# Custom theme (uncomment to use)
# theme: ./my-theme

# Extensions
# extensions:
#   - Crucible.Extensions.Mermaid
```

All fields have sensible defaults. The config file is never required — you can run `crucible build` with just a `docs/` directory.

## Writing Documentation

### Directory Structure

Your documentation is a directory of Markdown files. The directory structure becomes the site navigation:

```
docs/
├── index.md                    → Homepage
├── getting-started/
│   ├── index.md                → Section landing page
│   ├── installation.md         → Getting Started > Installation
│   └── quick-start.md          → Getting Started > Quick Start
├── guides/
│   ├── authentication.md       → Guides > Authentication
│   └── deployment.md           → Guides > Deployment
└── reference/
    └── api.md                  → Reference > API
```

- **Files** become pages
- **Directories** become navigation sections
- **`index.md`** in a directory provides the section title (if present)
- Directories without `index.md` use the directory name (title-cased) as the section title

### YAML Frontmatter

Every Markdown file starts with YAML frontmatter:

```markdown
---
title: Installation
description: How to install the project
sort: 1
updated: 2026-03-15
tags:
  - getting-started
  - setup
---

# Installation

Your content here...
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | **yes** | Page title (used in navigation, `<title>`, Open Graph) |
| `description` | string | no | Page description (used in `<meta>` and search results) |
| `sort` | integer | no | Sort order within the section (sorted pages come first, then alphabetical) |
| `updated` | date | no | Last updated date (used in sitemap `<lastmod>`) |
| `tags` | string[] | no | Tags for categorization |
| `draft` | bool | no | If `true`, excluded from build (unless `--include-drafts`) |
| `template` | string | no | Override XSLT template for this page |

### Markdown Features

Crucible supports standard Markdown with these extensions:

**Fenced code blocks** with language syntax:
````markdown
```csharp
var x = 42;
```
````

**Tables** (GFM pipe tables):
```markdown
| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |
```

**Admonitions** using custom container syntax:
```markdown
::: note
This is a note admonition.
:::

::: warning
Be careful with this setting.
:::

::: tip
Here's a helpful tip.
:::
```

Supported types: `note`, `warning`, `tip`, `important`, `caution`.

**Mermaid diagrams** (rendered client-side):
````markdown
```mermaid
graph LR; A-->B; B-->C;
```
````

### Internal Links

Link between documentation pages using relative or root-relative paths:

```markdown
<!-- Relative link (from current file's location) -->
See [Installation](../getting-started/installation.md)

<!-- Root-relative link (from docs/ root) -->
See [Installation](/getting-started/installation.md)
```

Crucible automatically rewrites `.md` links to `.html` in the output and warns about broken links.

## Features

### Search

Crucible generates a client-side search index during build. Search is powered by [Lunr.js](https://lunrjs.com/) — no server required. The search box appears in the sidebar and provides instant fuzzy search across all page titles, descriptions, headings, and content.

### SEO

Every generated page includes:
- `<title>` — page title + site title
- `<meta name="description">` — from frontmatter
- `<link rel="canonical">` — from base URL + page path
- Open Graph tags (`og:title`, `og:description`, `og:url`, `og:type`)
- `sitemap.xml` with `<lastmod>` dates

### Dark Mode

The default theme includes automatic dark mode that respects your system preference. A toggle button in the header lets you switch manually, and your preference is saved across pages.

### Navigation

Navigation is automatically generated from the directory structure:
- Sidebar with nested sections
- Active page highlighting
- Collapsible sections on mobile

### Responsive Design

The default theme is fully responsive. The sidebar collapses into a hamburger menu on mobile devices.

## Staged Builds

For debugging or advanced workflows, you can run individual stages:

```bash
# Stage 1: Parse Markdown → XML intermediate
crucible build --stage ParseOnly -o ./intermediate

# Inspect the XML output
cat intermediate/index.xml
cat intermediate/site-manifest.xml

# Stage 2: Transform XML → HTML
crucible build --stage TransformOnly -s ./intermediate -o ./dist
```

This is useful for:
- Inspecting the XML intermediate representation
- Debugging XSLT template issues
- Custom post-processing between stages

## Custom Themes

Create a directory with XSLT stylesheets and static assets:

```
my-theme/
├── page.xslt           # Main page transform
├── navigation.xslt     # Navigation component (optional)
├── sitemap.xslt         # Sitemap generator
├── css/
│   └── style.css
└── js/
    └── theme.js
```

Use with:

```bash
crucible build --theme ./my-theme
```

Or in `crucible.yaml`:

```yaml
theme: ./my-theme
```

The `page.xslt` receives these parameters:
- `$site-manifest-uri` — path to the site manifest XML
- `$base-url` — base URL prefix
- `$site-title` — site title
- `$current-path` — current page path (for navigation highlighting)

The input document follows the Crucible XML schema — see the [design spec](https://github.com/phoenixmldb/crucible) for element details.

## Extensions

Crucible supports extensions that hook into the Markdown-to-XML pipeline. The built-in Mermaid extension is an example — it intercepts fenced code blocks with `mermaid` language and emits a `<mermaid>` XML element instead of a `<code-block>`.

### Plugin Directory

Place extension DLLs in a `plugins/` directory next to your `crucible.yaml`. Crucible loads them automatically.

### Writing Extensions

Extensions implement `ICrucibleExtension` from the `Crucible.Core` NuGet package:

```csharp
using Crucible.Core.Extensions;
using Markdig.Syntax;

public class MyExtension : ICrucibleExtension
{
    public string Name => "My Extension";

    public bool CanProcess(Type markdigNodeType)
        => markdigNodeType == typeof(FencedCodeBlock);

    public bool ProcessNode(MarkdownObject node, XmlEmitterContext context)
    {
        // Write custom XML elements to context.Writer
        // Return true if you handled the node, false to use default processing
        return false;
    }

    public IEnumerable<CrucibleAsset> GetAssets()
    {
        // Return JS/CSS assets to include in the output
        yield break;
    }
}
```

## Deployment

### Cloudflare Pages

```yaml
# Build command
crucible build --base-url https://docs.example.com

# Output directory: dist
```

### GitHub Pages

```yaml
# .github/workflows/deploy.yml
name: Deploy Docs
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - run: dotnet tool install -g Crucible.Cli
      - run: crucible build --base-url /repo-name/
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist
  deploy:
    needs: build
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-pages@v4
```

### Netlify

```toml
# netlify.toml
[build]
  command = "dotnet tool install -g Crucible.Cli && crucible build"
  publish = "dist"
```

### Any Static Host

Crucible generates a self-contained `dist/` directory. Upload it anywhere that serves static files.
