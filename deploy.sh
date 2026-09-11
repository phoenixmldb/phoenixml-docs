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
# Requires Cloudflare credentials: either CLOUDFLARE_API_TOKEN (a Pages-edit-scoped
# token) in the environment, or an interactive `wrangler login` session.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Auth: either a Pages-edit API token in the environment, or an interactive
# `wrangler login` session. Both are valid to wrangler; this check only refuses
# to start a deploy that would fail at the last step for lack of credentials.
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  if ! wrangler whoami >/dev/null 2>&1; then
    echo "ERROR: no Cloudflare credentials." >&2
    echo "  Either export CLOUDFLARE_API_TOKEN (a Pages-edit token)," >&2
    echo "  or run: wrangler login" >&2
    exit 1
  fi
  echo "Authenticating with the stored wrangler OAuth session."
fi

# Full build (includes generated API reference).
"$SCRIPT_DIR/build.sh"


echo ""
echo "--- Deploying to Cloudflare Pages ---"
wrangler pages deploy dist/ --project-name=phoenixml-dev --commit-dirty=true
