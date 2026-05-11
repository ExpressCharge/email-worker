# expresscharge-email-worker — project notes for Claude

This is the Cloudflare Workers email service for ExpressCharge. It receives
HMAC-signed POST /send requests from the web app and forwards them through
Cloudflare Email Service to verified senders.

## Project overview

- **Runtime:** Cloudflare Workers (requires Workers Paid plan — Email Service
  is in public beta on paid only).
- **Authoring:** TypeScript, bundled by Wrangler.
- **Dependencies:** `wrangler` only (no npm runtime deps; uses
  `nodejs_compat` for crypto).
- **State:** one KV namespace (`EMAIL_NONCE_DEDUP`) for nonce dedup +
  per-recipient rate-limit counters. Single namespace with prefixed keys.

## Config split (read this before deploying)

The committed `wrangler.jsonc` uses **placeholder KV namespace IDs**
(`00000…`/`11111…`). Real IDs live in `wrangler.local.jsonc` (gitignored).
`bin/deploy.sh` merges them at deploy time via `jq`.

To set up locally:

1. Copy `wrangler.example.jsonc` to `wrangler.local.jsonc` and fill in the
   real production + preview KV namespace IDs from your Cloudflare account.
2. `wrangler kv namespace create EMAIL_NONCE_DEDUP` (and `--preview`) to
   provision them if they don't exist.

Worker **secrets** (`POLARIS_SECRET_A`, `POLARIS_SECRET_B`) are NOT in
GitHub or the repo — they're set directly on Cloudflare via
`wrangler secret put NAME` (one-time per environment).

## Key commands

- `npx wrangler dev` — local dev (uses preview KV namespace)
- `npx wrangler deploy --dry-run` — validate without deploying
- `bin/deploy.sh` — production deploy (merges wrangler.local.jsonc, then
  `wrangler deploy`)
- `bin/deploy.sh --env staging` — deploy to staging worker

## Local CI fallback

When GitHub Actions is unavailable, the CI workflow's jobs reproduce
locally as:

| CI job        | Local equivalent                          |
|---------------|-------------------------------------------|
| `typecheck`   | `npx tsc --noEmit`                        |
| `build`       | `npx wrangler deploy --dry-run`           |
| `secrets-scan`| `gitleaks detect --no-banner`             |

The `deploy.yml` workflow is **not** locally runnable without
`CLOUDFLARE_API_TOKEN` — manual deploys use `bin/deploy.sh`.

## HMAC request authentication

Every `/send` request must be signed with one of `POLARIS_SECRET_A` or
`POLARIS_SECRET_B` (paired for rotation). Timestamp must be within
`TS_WINDOW_MS` (5 min) and the nonce must not already be in KV (replay
protection). See `src/index.ts` for the verifier.

## Brand-naming note

The env-var names `POLARIS_SECRET_A` / `POLARIS_SECRET_B` are historical
(this worker originated under the Polaris brand). Renaming requires
coordinated changes in the web app's email client too — out of scope for
now. Keep the names stable.
