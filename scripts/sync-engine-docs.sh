#!/usr/bin/env bash
# Points the API reference at the latest PUBLISHED engine packages.
#
# api/EngineDocs restores the engine packages so their PhoenixmlDb.*.xml land in one directory,
# which build.sh reads as XMLDOC_DIR. So the API reference documents whatever versions that
# csproj pins — and nothing was bumping them at release time. The published API docs drifted
# behind the published engines silently, because a stale-but-valid pin builds perfectly.
#
# Run with no arguments to bump every engine to its latest published version:
#     ./scripts/sync-engine-docs.sh
#
# --check exits non-zero if any pin is behind, and changes nothing. That is the CI form.
#
# Deliberately reads nuget.org rather than the sibling repos: the API reference must document
# what a consumer can actually install. A version that exists only as a git tag is not that.
set -uo pipefail

cd "$(dirname "$0")/.."
PROJ="api/EngineDocs/EngineDocs.csproj"
[ -f "$PROJ" ] || { echo "sync-engine-docs: no $PROJ here" >&2; exit 2; }

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

behind=0
changed=0

for pkg in PhoenixmlDb.Core PhoenixmlDb.XQuery PhoenixmlDb.Xslt; do
  lower="$(echo "$pkg" | tr '[:upper:]' '[:lower:]')"
  latest="$(curl -fsS --compressed "https://api.nuget.org/v3-flatcontainer/${lower}/index.json" 2>/dev/null \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['versions'][-1])" 2>/dev/null)"
  if [ -z "$latest" ]; then
    echo "WARN  $pkg — could not read nuget.org; leaving the pin alone" >&2
    continue
  fi
  current="$(grep -oP "(?<=Include=\"$pkg\" Version=\")[^\"]+" "$PROJ" | head -1)"
  if [ -z "$current" ]; then
    echo "WARN  $pkg — not pinned in $PROJ" >&2
    continue
  fi

  if [ "$current" = "$latest" ]; then
    printf 'ok    %-22s %s\n' "$pkg" "$current"
    continue
  fi

  behind=1
  if [ "$check_only" = 1 ]; then
    printf 'BEHIND %-21s docs pin %s, published %s\n' "$pkg" "$current" "$latest"
  else
    sed -i "s|Include=\"$pkg\" Version=\"$current\"|Include=\"$pkg\" Version=\"$latest\"|" "$PROJ"
    printf 'bumped %-21s %s -> %s\n' "$pkg" "$current" "$latest"
    changed=1
  fi
done

if [ "$check_only" = 1 ] && [ "$behind" = 1 ]; then
  echo
  echo "API docs are behind the published engines. Run ./scripts/sync-engine-docs.sh and commit."
  exit 1
fi

[ "$changed" = 1 ] && echo && echo "Pins updated. Rebuild with ./build.sh to regenerate the API reference."
exit 0
