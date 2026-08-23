# AI daily quota semantics

- Failed Gemini transport/upstream calls do not consume daily quota.
- Successful responses commit the pending quota write before being returned.
- A quota-store write failure fails closed.
- The current optional Cloudflare KV implementation is not an atomic counter; concurrent successful requests can race.
- Strict concurrency enforcement requires a separately reviewed atomic storage migration (for example Durable Objects).

No Production binding or deployment is changed by this document.
