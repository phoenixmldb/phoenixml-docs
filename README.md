# PhoenixML Documentation

XPath, XSLT, and XQuery documentation for .NET developers.

Built with [Crucible](https://github.com/phoenixmldb/crucible), powered by the PhoenixmlDb XSLT 4.0 engine.

## Building

```bash
# Install Crucible (or run from source)
dotnet run --project ../crucible/src/Crucible.Cli -- build --timing
```

## Structure

```
docs/
├── index.md                    # Home
├── xml-foundations/             # XML essentials for JSON developers
│   ├── xml-vs-json.md
│   ├── document-structure.md
│   ├── xdm.md
│   └── namespaces.md
├── xpath/                      # XPath query language
│   ├── path-expressions.md
│   ├── functions.md
│   ├── operators.md
│   └── data-types.md
├── xslt/                       # XSLT transformations
│   ├── first-transform.md
│   ├── template-matching.md
│   ├── instructions.md
│   └── output-methods.md
└── xquery/                     # XQuery language
    ├── flwor.md
    ├── constructors.md
    ├── functions-modules.md
    └── xquery-vs-xslt.md
```
