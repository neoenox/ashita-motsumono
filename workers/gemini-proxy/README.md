# Gemini proxy deployment

The Worker fails closed unless store verification and entitlement signing are configured.

## Required secrets

- `GEMINI_API_KEY`
- `ENTITLEMENT_SIGNING_SECRET` — cryptographically random, at least 32 bytes
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`

The Google service account must have purchase read/acknowledge access for the app in Play Console. Product IDs and package/bundle IDs in `wrangler.toml` must match the stores.

## Routes

- `POST /entitlements/verify` verifies a Google Play or App Store purchase. For the AI product it returns a short-lived signed token.
- `POST /analyze` requires that token in `Authorization: Bearer ...`.
- `GET /health` returns non-sensitive health metadata.

Both POST routes use Cloudflare Rate Limiting bindings. Keep namespace IDs unique within the Cloudflare account. Requests are rejected when the JSON body, decoded image size, MIME type, purchase identity, or token is invalid.
