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

# Step 0: Restore local .NET tools (crucible) pinned in dotnet-tools.json
echo ""
echo "--- Restoring tools ---"
STEP_START=$(date +%s%N)
dotnet tool restore
STEP_END=$(date +%s%N)
echo "  $(( (STEP_END - STEP_START) / 1000000 ))ms"

# Guard: the API-reference step (Step 2) consumes the engine's generated XML
# docs. Fail clearly here rather than emit an empty or stale /api/ section if
# they are absent, empty, or older than the engine source.
# Bypass the staleness check with ALLOW_STALE_API_DOCS=1.
echo ""
echo "--- Checking API XML docs ---"
EXPECTED_DOCS=(PhoenixmlDb.Core.xml PhoenixmlDb.Xdm.xml PhoenixmlDb.XQuery.xml PhoenixmlDb.Xslt.xml)

if [ ! -d "$XMLDOC_DIR" ]; then
  echo "ERROR: XMLDOC_DIR not found: $XMLDOC_DIR" >&2
  echo "  Build the engine test host with XML docs enabled (engine projects need" >&2
  echo "  <GenerateDocumentationFile>true</GenerateDocumentationFile>), or set" >&2
  echo "  XMLDOC_DIR to the directory containing PhoenixmlDb.*.xml." >&2
  exit 1
fi

_missing=()
for _d in "${EXPECTED_DOCS[@]}"; do
  [ -s "$XMLDOC_DIR/$_d" ] || _missing+=("$_d")
done
if [ ${#_missing[@]} -gt 0 ]; then
  echo "ERROR: missing or empty API XML docs in $XMLDOC_DIR:" >&2
  printf '    %s\n' "${_missing[@]}" >&2
  echo "  Rebuild the engine with <GenerateDocumentationFile>true</GenerateDocumentationFile>." >&2
  exit 1
fi

if [ "${ALLOW_STALE_API_DOCS:-0}" != "1" ]; then
  _newest_doc=$(find "$XMLDOC_DIR" -maxdepth 1 -name 'PhoenixmlDb.*.xml' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
  _src_dirs=()
  for _s in ../phoenixmldb-core/src ../phoenixmldb-xquery/src ../phoenixmldb-xslt/src; do
    [ -d "$_s" ] && _src_dirs+=("$_s")
  done
  if [ ${#_src_dirs[@]} -gt 0 ]; then
    _newer=$(find "${_src_dirs[@]}" -name '*.cs' -not -path '*/obj/*' -not -path '*/bin/*' -newer "$_newest_doc" -print -quit 2>/dev/null)
    if [ -n "$_newer" ]; then
      echo "ERROR: engine source is newer than the generated API XML docs — they are stale." >&2
      echo "    e.g. $_newer" >&2
      echo "  Rebuild the engine test host so PhoenixmlDb.*.xml regenerate, then re-run" >&2
      echo "  (or set ALLOW_STALE_API_DOCS=1 to bypass)." >&2
      exit 1
    fi
    echo "  present and current"
  else
    echo "  present; engine source not found alongside docs repo — skipping staleness check"
  fi
fi

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
