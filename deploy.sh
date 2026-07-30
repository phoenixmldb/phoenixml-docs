#!/bin/bash
# Deploy phoenixml.dev to Cloudflare Pages.
#
# Runs the FULL build (build.sh: restore tools -> parse -> generate API
# reference from the engine's .NET XML docs -> transform), then publishes the
# resulting dist/ to Cloudflare Pages.
#
# IMPORTANT: always deploy via this script (or build.sh + wrangler), NOT a bare
# `dotnet crucible build -s ./docs`. The one-shot build skips the API-reference
# generation (~82 pages under /api/), producing an incomplete site.
#
# Requires CLOUDFLARE_API_TOKEN in the environment (a Pages-edit-scoped token).
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Full build (includes generated API reference).
"$SCRIPT_DIR/build.sh"

: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN (Pages-edit token) before deploying}"

echo ""
echo "--- Deploying to Cloudflare Pages ---"
wrangler pages deploy dist/ --project-name=phoenixml-dev --commit-dirty=true
