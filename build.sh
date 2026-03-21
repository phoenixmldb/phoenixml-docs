#!/bin/bash
# Build script for PhoenixML documentation
# Generates API reference from .NET XML docs, then builds the full site with Crucible.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_GENERATOR="$SCRIPT_DIR/api/ApiDocGenerator"
XSLT_STYLESHEET="$SCRIPT_DIR/api/dotnet-docs-to-crucible.xslt"
DOCS_DIR="$SCRIPT_DIR/docs"
INTERMEDIATE="$SCRIPT_DIR/.intermediate"
OUTPUT="${1:-$SCRIPT_DIR/dist}"

# .NET XML documentation sources
XMLDOC_DIR="${XMLDOC_DIR:-../phoenixml/TempTestRunner/bin/Debug/net10.0}"

# Internal namespaces to exclude from API docs
EXCLUDE_NS="PhoenixmlDb.Core.Storage"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.Xdm.Serialization"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.XQuery.Ast"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.XQuery.Analysis"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.XQuery.Execution"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.XQuery.Optimizer"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.XQuery.Parser.Grammar"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.XQuery.Functions"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.Xslt.Ast"
EXCLUDE_NS="$EXCLUDE_NS,PhoenixmlDb.Xslt.Engine"

TOTAL_START=$(date +%s%N)
echo "=== PhoenixmlDb Documentation Build ==="

# Step 1: Parse Markdown docs into intermediate XML
echo ""
echo "--- Parsing Markdown ---"
STEP_START=$(date +%s%N)
rm -rf "$INTERMEDIATE" "$OUTPUT"
dotnet crucible \
  build --stage ParseOnly \
  -s "$DOCS_DIR" -o "$INTERMEDIATE" \
  --title "PhoenixmlDb Documentation" \
  2>&1
STEP_END=$(date +%s%N)
echo "  $(( (STEP_END - STEP_START) / 1000000 ))ms"

# Step 2: Generate API reference XML (assemblies processed in parallel)
echo ""
echo "--- Generating API reference ---"
STEP_START=$(date +%s%N)
dotnet run --no-build --project "$API_GENERATOR" -- \
  "$XSLT_STYLESHEET" \
  "$INTERMEDIATE" \
  "$XMLDOC_DIR" \
  --exclude-namespaces "$EXCLUDE_NS" \
  2>&1
STEP_END=$(date +%s%N)
echo "  $(( (STEP_END - STEP_START) / 1000000 ))ms"

# Step 3: Update site manifest with API pages
echo ""
echo "--- Updating manifest ---"
STEP_START=$(date +%s%N)
python3 "$SCRIPT_DIR/api/update-manifest.py" "$INTERMEDIATE"
STEP_END=$(date +%s%N)
echo "  $(( (STEP_END - STEP_START) / 1000000 ))ms"

# Step 4: Transform to HTML
echo ""
echo "--- Transforming to HTML ---"
STEP_START=$(date +%s%N)
dotnet crucible \
  build --stage TransformOnly \
  -s "$INTERMEDIATE" -o "$OUTPUT" \
  --timing \
  2>&1
STEP_END=$(date +%s%N)
echo "  $(( (STEP_END - STEP_START) / 1000000 ))ms"

# Cleanup
rm -rf "$INTERMEDIATE"

TOTAL_END=$(date +%s%N)
page_count=$(find "$OUTPUT" -name "*.html" | wc -l)
total_seconds=$(( (TOTAL_END - TOTAL_START) / 1000000000 ))
echo ""
echo "=== $page_count pages built in ${total_seconds}s ==="
