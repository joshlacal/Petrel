Reference atproto DPoP Client (Node)

This harness uses the official atproto OAuth client’s DPoP fetch wrapper to compare behavior against PetrelLoad.

Setup
- Requires Node 18+.
- From this folder:
  - npm install

Usage
- node index.mjs --base-url https://bsky.social \
  --endpoint app.bsky.actor.getProfile \
  --method GET \
  --requests 500 \
  --concurrency 25 \
  [--target-rps 50]

Notes
- This uses dpopFetchWrapper with an in-memory nonce store to match Petrel’s behavior.
- It prints success/failure counts, RPS, latency p50/p95/p99, and ratelimit header snapshots if present.

