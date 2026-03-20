#!/bin/bash
# Build script for PhoenixML documentation
# Generates API reference from .NET XML docs, then builds the full site with Crucible.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CRUCIBLE_CLI="../crucible/src/Crucible.Cli"
API_GENERATOR="$SCRIPT_DIR/api/ApiDocGenerator"
XSLT_STYLESHEET="$SCRIPT_DIR/api/dotnet-docs-to-crucible.xslt"
DOCS_DIR="$SCRIPT_DIR/docs"
INTERMEDIATE="$SCRIPT_DIR/.intermediate"
OUTPUT="${1:-$SCRIPT_DIR/dist}"

# .NET XML documentation sources (from monorepo build output)
XMLDOC_DIR="../phoenixml/TempTestRunner/bin/Debug/net10.0"

echo "=== PhoenixML Documentation Build ==="

# Step 1: Parse Markdown docs into intermediate XML
echo ""
echo "--- Step 1: Parsing Markdown documentation ---"
rm -rf "$INTERMEDIATE" "$OUTPUT"
dotnet run --no-restore --project "$CRUCIBLE_CLI" -- \
  build --stage ParseOnly \
  -s "$DOCS_DIR" -o "$INTERMEDIATE" \
  --title "PhoenixML Documentation" \
  2>&1

# Step 2: Generate API reference XML using XSLT
echo ""
echo "--- Step 2: Generating API reference from .NET XML docs ---"
dotnet run --no-restore --project "$API_GENERATOR" -- \
  "$XSLT_STYLESHEET" \
  "$INTERMEDIATE" \
  "$XMLDOC_DIR" \
  2>&1

# Step 3: Update site manifest with API pages
echo ""
echo "--- Step 3: Updating site manifest ---"
python3 "$SCRIPT_DIR/api/update-manifest.py" "$INTERMEDIATE"

# Step 4: Transform combined intermediate to HTML
echo ""
echo "--- Step 4: Transforming to HTML ---"
dotnet run --no-restore --project "$CRUCIBLE_CLI" -- \
  build --stage TransformOnly \
  -s "$INTERMEDIATE" -o "$OUTPUT" \
  --timing \
  2>&1

# Cleanup
rm -rf "$INTERMEDIATE"

echo ""
page_count=$(find "$OUTPUT" -name "*.html" | wc -l)
echo "=== Build complete: $page_count pages in $OUTPUT ==="
