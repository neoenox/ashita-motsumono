# Gemini proxy deployment

The Worker fails closed unless store verification and entitlement signing are configured.

## Required secrets

- `GEMINI_API_KEY`
- `ENTITLEMENT_SIGNING_SECRET` — cryptographically random, at least 32 bytes
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`

The Google service account must have purchase read/acknowledge access for the app in Play Console. Product IDs and package/bundle IDs in `wrangler.toml` must match the stores. `IOS_BUNDLE_ID` is mandatory: iOS receipts are rejected with a server error when it is missing or empty.

## Optional configuration

- `AI_DAILY_LIMIT` — maximum `/analyze` requests per purchase identity per UTC day (integer, default `200`, minimum `1`). Requires one of the quota bindings below; without any binding no daily counting happens and only the per-minute rate limiters apply.
- `AI_QUOTA_COUNTER` — Durable Object binding (`QuotaCounter` class, enabled in `wrangler.toml`). Each `/analyze` request atomically reserves one unit per `quota:${receiptHash}:${UTC date}` key before calling Gemini and releases it again when the upstream call fails, so failures do not consume quota. The reserve is a serialized check-and-increment inside a single Durable Object instance per purchase identity, so concurrent requests can never exceed `AI_DAILY_LIMIT` (issue #211). Requires a Workers Paid plan; if the counter is unreachable, requests fail closed with `503 Daily rate limit is temporarily unavailable`.
- `AI_DAILY_QUOTA` — optional KV namespace fallback for local dev/tests where Durable Objects are unavailable. Same reserve/release flow over the same key shape (TTL 48h), but KV `get`→`put` stays eventually consistent, so concurrent requests can briefly exceed the limit; prefer the DO binding in production. See the commented-out `kv_namespaces` block in `wrangler.toml`.

## Routes

- `POST /entitlements/verify` verifies a Google Play or App Store purchase. For the AI product it returns a short-lived signed token.
- `POST /analyze` requires that token in `Authorization: Bearer ...`.
- `GET /health` returns non-sensitive health metadata. The root path is not routed.

Both POST routes use Cloudflare Rate Limiting bindings. Keep namespace IDs unique within the Cloudflare account. Requests are rejected when the JSON body, decoded image size, MIME type, timezone, purchase identity, or token is invalid. Gemini is called with the API key in the `x-goog-api-key` header, upstream failures return a generic JSON error instead of Google's response body (upstream 429s stay 429), and upstream calls time out at ~55s so the client's 60s limit never sees a hanging request.
