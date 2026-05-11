#!/usr/bin/env bash
# Deploy the email worker to Cloudflare.
#
# Merges wrangler.local.jsonc (gitignored, contains real KV namespace IDs)
# over the committed wrangler.jsonc, then invokes `wrangler deploy` against
# the merged config. The merged file is written to wrangler.ci.jsonc and
# cleaned up afterwards.
#
# Usage:
#   bin/deploy.sh                    # production
#   bin/deploy.sh --env staging      # named environment
#
# CI uses the same script with env vars set instead of wrangler.local.jsonc:
#   PRODUCTION_KV_NAMESPACE_ID=... PREVIEW_KV_NAMESPACE_ID=... bin/deploy.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

OUT="wrangler.ci.jsonc"
trap 'rm -f "$OUT"' EXIT

if [[ -f wrangler.local.jsonc ]]; then
  # Strip // comments from both files (jq doesn't tolerate them), merge, write.
  jq -s '.[0] * .[1]' \
    <(sed 's://.*$::' wrangler.jsonc) \
    <(sed 's://.*$::' wrangler.local.jsonc) > "$OUT"
elif [[ -n "${PRODUCTION_KV_NAMESPACE_ID:-}" && -n "${PREVIEW_KV_NAMESPACE_ID:-}" ]]; then
  sed 's://.*$::' wrangler.jsonc \
    | jq --arg pid "$PRODUCTION_KV_NAMESPACE_ID" \
         --arg vid "$PREVIEW_KV_NAMESPACE_ID" \
      '.kv_namespaces[0].id = $pid | .kv_namespaces[0].preview_id = $vid' \
    > "$OUT"
else
  echo "deploy.sh: need wrangler.local.jsonc or PRODUCTION_KV_NAMESPACE_ID + PREVIEW_KV_NAMESPACE_ID" >&2
  exit 1
fi

npx wrangler deploy --config "$OUT" "$@"
