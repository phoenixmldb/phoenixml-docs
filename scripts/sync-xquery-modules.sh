#!/usr/bin/env bash
# Copies the modules of one xquery-modules release tag into static/modules/<version>/,
# which the site serves at https://phoenixml.dev/modules/<version>/<file> (.xqm and .xsl).
# A published version is never changed: the script refuses to write an existing version.
#
#   scripts/sync-xquery-modules.sh v1.0.0
set -euo pipefail
tag="${1:?usage: $0 <tag, for example v1.0.0>}"
version="${tag#v}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$root/static/modules/$version"
if [ -e "$dest" ]; then
  echo "static/modules/$version exists; a published version does not change." >&2
  exit 1
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" https://github.com/phoenixmldb/xquery-modules.git "$work/src"
mkdir -p "$dest"
cp "$work/src/modules/"*.xqm "$dest/"
# XSLT stylesheet modules, when the release has them (from 1.1.0). They import
# each other by relative path, so they share the folder with the XQuery modules.
if [ -d "$work/src/xslt" ]; then cp "$work/src/xslt/"*.xsl "$dest/"; fi
ls "$dest"
