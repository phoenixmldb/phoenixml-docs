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

# .NET XML documentation sources. By default these come from api/EngineDocs,
# which restores the pinned engine packages so their PhoenixmlDb.*.xml land in
# one directory (see that csproj). Override XMLDOC_DIR to document a local
# engine build instead of the published one.
ENGINE_DOCS="$SCRIPT_DIR/api/EngineDocs"
XMLDOC_DIR_DEFAULT="$ENGINE_DOCS/bin/Debug/net10.0"
XMLDOC_DIR="${XMLDOC_DIR:-$XMLDOC_DIR_DEFAULT}"

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

# Step 0: Restore local .NET tools (crucible) pinned in dotnet-tools.json
echo ""
echo "--- Restoring tools ---"
STEP_START=$(date +%s%N)
dotnet tool restore
STEP_END=$(date +%s%N)
echo "  $(( (STEP_END - STEP_START) / 1000000 ))ms"

# The API-reference step (Step 2) consumes the engines' generated XML docs.
# Restore them from the pinned packages, then verify they arrived: a silently
# empty /api/ section is the failure this guards against.
echo ""
echo "--- Restoring API XML docs ---"
if [ "$XMLDOC_DIR" = "$XMLDOC_DIR_DEFAULT" ]; then
  dotnet build --nologo -v quiet "$ENGINE_DOCS" >/dev/null
  echo "  from the pinned engine packages (api/EngineDocs)"
else
  echo "  XMLDOC_DIR override: $XMLDOC_DIR"
fi
# Xdm was folded into the Core assembly, so there is no separate PhoenixmlDb.Xdm.xml.
EXPECTED_DOCS=(PhoenixmlDb.Core.xml PhoenixmlDb.XQuery.xml PhoenixmlDb.Xslt.xml)

if [ ! -d "$XMLDOC_DIR" ]; then
  echo "ERROR: XMLDOC_DIR not found: $XMLDOC_DIR" >&2
  echo "  Expected api/EngineDocs to produce it. Run 'dotnet build api/EngineDocs'," >&2
  echo "  or set XMLDOC_DIR to a directory containing PhoenixmlDb.*.xml." >&2
  exit 1
fi

_missing=()
for _d in "${EXPECTED_DOCS[@]}"; do
  [ -s "$XMLDOC_DIR/$_d" ] || _missing+=("$_d")
done
if [ ${#_missing[@]} -gt 0 ]; then
  echo "ERROR: missing or empty API XML docs in $XMLDOC_DIR:" >&2
  printf '    %s\n' "${_missing[@]}" >&2
  echo "  The package for a missing one may not ship XML docs. Check the version" >&2
  echo "  pinned in api/EngineDocs/EngineDocs.csproj." >&2
  exit 1
fi

echo "  present"

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
# --no-build below: build it here explicitly. A fresh checkout has no binary,
# and without this the step either fails outright or silently runs a stale one.
dotnet build --nologo -v quiet "$API_GENERATOR" >/dev/null
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
