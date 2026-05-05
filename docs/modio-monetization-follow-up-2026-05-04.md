# mod.io monetization follow-up — 2026-05-04

## Scope

Focused follow-up on:
- `/me/iap/*/sync` endpoint drift
- whether mod.io wallet / checkout is realistic on Steam, Apple App Store, Google Play, and Meta Quest
- what to wrap now vs defer

## Key findings

### 1. `/me/iap/*/sync` is real in official code, but the mirrored REST corpus is incomplete

**High-confidence / high-quality local evidence**
- `modio-docs/public/en-us/features/monetization/purchase-servers/modio-as-purchase-server.md` explicitly documents these guide endpoints:
  - `/me/iap/xboxlive/sync`
  - `/me/iap/psn/sync`
  - `/me/iap/steam/sync`
  - `/me/iap/meta/sync`
  - `/me/iap/epicgames/sync`
- `modio-sdk/modio/modio/core/ModioDefaultRequestParameters.h` defines request params for:
  - `/me/iap/apple/sync`
  - `/me/iap/google/sync`
  - `/me/iap/epicgames/sync`
  - `/me/iap/meta/sync`
  - `/me/iap/psn/sync`
  - `/me/iap/steam/sync`
  - `/me/iap/xboxlive/sync`
- `modio-unity/Modio/API/Generated/Endpoints/` includes generated endpoint classes for the same set, including Apple and Google.
- `modio-unity/Unity/Platforms/MobilePurchasing/ModioMobileStoreService.cs` actively routes Unity IAP receipts to:
  - `SyncGoogleEntitlements(...)`
  - `SyncAppleEntitlement(...)`

**High-confidence drift finding**
- The mirrored REST endpoint corpus under `modio-docs/public/en-us/restapi/docs/` does **not** include matching `.api.mdx` pages for `/me/iap/apple/sync`, `/me/iap/google/sync`, `/me/iap/meta/sync`, `/me/iap/steam/sync`, `/me/iap/xboxlive/sync`, `/me/iap/psn/sync`, or `/me/iap/epicgames/sync`.
- So these endpoints look **officially used and supported in practice**, but **incompletely represented in the mirrored REST reference**.

### 2. The intended product shape appears to be both flows, but for different distribution contexts

**High-confidence local evidence**
- `purchase.api.mdx`, `get-user-wallet.api.mdx`, and `get-user-purchases.api.mdx` clearly support direct mod.io wallet / checkout flows.
- `modio-as-purchase-server.md` clearly describes platform entitlement sync into mod.io wallet/inventory through `/me/iap/*/sync`.

**Interpretation**
- mod.io appears to support **both**:
  1. **platform-IAP entitlement sync into mod.io** for store/platform-native purchases
  2. **direct mod.io wallet / checkout** for distributions where mod.io can be the effective purchase layer

### 1b. Route-by-route drift resolution snapshot

- `POST /me/iap/xboxlive/sync`
  - Source quality: guide-backed, SDK-backed, Unity-backed; not REST-page-backed
  - Best-known shape: bearer auth + form body `xbox_token`
  - Drift: no field-name drift found; guide adds a real URL-encoding caveat for the token
- `POST /me/iap/psn/sync`
  - Source quality: guide-backed, SDK-backed, Unity-backed; not REST-page-backed
  - Best-known shape: disputed
  - Drift: guide uses `psn_token` / `psn_env` / `psn_service_label`, while SDK + Unity use `auth_code` / `env` / `service_label`; guide also makes PS4/PS5 platform targeting an explicit header concern
- `POST /me/iap/steam/sync`
  - Source quality: guide-backed, SDK-backed, Unity-backed; not REST-page-backed
  - Best-known shape: bearer auth, empty body
  - Drift: none found beyond missing REST page
- `POST /me/iap/meta/sync`
  - Source quality: guide-backed, SDK-backed, Unity-backed; not REST-page-backed
  - Best-known shape: disputed
  - Drift: guide uses form `meta_device` + `meta_user_id`; SDK uses form `device` + `user_id`; Unity currently sends `device` + `user_id` as query params on the POST
- `POST /me/iap/epicgames/sync`
  - Source quality: guide-backed, SDK-route-backed, Unity-backed; not REST-page-backed
  - Best-known shape: bearer auth + form body `epicgames_token` + `epicgames_sandbox_id`
  - Drift: C++ SDK route constant exists, but the public monetization switch treats Epic as unsupported; Unity endpoint docstring is PSN-copied noise
- `POST /me/iap/google/sync`
  - Source quality: SDK-backed, Unity-backed; not guide-backed and not REST-page-backed
  - Best-known shape: bearer auth + form body `receipt`
  - Drift: code-first evidence only in the local corpus
- `POST /me/iap/apple/sync`
  - Source quality: SDK-route-backed, Unity-backed; not guide-backed and not REST-page-backed
  - Best-known shape: bearer auth + form body `receipt`
  - Drift: Unity actively uses it, but the C++ SDK only defines the route constant and treats Apple as unsupported in the public monetization switch

Practical conclusion from the drift audit:
- **REST-only certainty:** wrap none.
- **If Derrick allows a non-REST pilot anyway:** `steam` first, `xboxlive` second.
- Keep `psn`, `meta`, `apple`, `google`, and `epicgames` out of the first sync slice until he explicitly chooses how much non-REST / code-first evidence is acceptable.

### 3. Platform practicality

#### Steam
- **Confidence:** medium-high
- **Source quality:** strong local mod.io evidence; supportive official Steam documentation snippets
- mod.io explicitly documents `/me/iap/steam/sync` in the guide and ships SDK support.
- Steam officially supports in-game microtransactions.
- Practical conclusion: Steam looks like a realistic target for **platform purchase -> mod.io entitlement sync**.
- Direct mod.io wallet/checkout may still be possible in some PC contexts, but for a Steam-distributed build the safer assumption is to prefer the **Steam-native commerce path**, with mod.io consuming or reflecting entitlements.

#### Apple App Store
- **Confidence:** high for the broad restriction, medium for edge-case exceptions
- **Source quality:** official Apple guideline/search evidence + strong local Unity/mod.io integration evidence
- Apple requires in-app purchase for digital goods/services in App Store apps.
- mod.io Unity code includes Apple receipt sync via `/me/iap/apple/sync`, which strongly suggests the intended compliant pattern is **Apple IAP first, then sync the entitlement into mod.io**.
- Practical conclusion: treat **direct mod.io wallet/checkout inside an App Store-distributed iOS app as not the default safe path**. Treat Apple as **platform-IAP sync only** unless a later legal/product review identifies a very specific allowed carve-out.

#### Google Play
- **Confidence:** high
- **Source quality:** official Google Play Payments policy + strong local Unity/mod.io integration evidence
- Google Play policy explicitly requires Google Play Billing for digital goods/features in Play-distributed apps.
- mod.io Unity code includes Google receipt sync via `/me/iap/google/sync`, which strongly suggests the intended compliant pattern is **Google Play Billing first, then sync into mod.io**.
- Practical conclusion: for a Google Play build, treat mod.io wallet/checkout as **not the primary in-app payment path**. Use **Google Play IAP entitlement sync**.

#### Meta Quest store
- **Confidence:** medium
- **Source quality:** strong local mod.io evidence; lighter official policy evidence than Apple/Google
- mod.io explicitly documents `/me/iap/meta/sync` and requires `meta_device` + `meta_user_id`.
- Meta official add-ons docs/snippets show durable/consumable/subscription IAP and entitlement consumption/refund behavior.
- Practical conclusion: Meta Quest looks realistic for **Meta add-on / IAP entitlement sync into mod.io**.
- Caveat: policy conclusions are less directly evidenced here than Apple/Google, so phrase this as an implementation fit rather than a hard legal statement.

## Recommendation

### Wrap now
- `GET /me/wallets`
- `GET /me/purchased`
- optionally `POST /me/entitlements` as a read/query helper if Derrick wants a non-consuming entitlement lookup surface

### Defer for a later, platform-aware slice
- `POST /games/{game-id}/mods/{mod-id}/checkout`
- all `/me/iap/*/sync` write wrappers

### Why defer `/me/iap/*/sync` even though they look real?
- They appear real enough to trust technically.
- But they are not cleanly represented in the mirrored REST corpus.
- They also force an immediate product decision about which store portals AeroBeat will actually ship on first.
- So they are better treated as the **next slice after wallet/purchases reads**, not the very next thin-wrapper slice.

## Bottom line

- Treat `/me/iap/*/sync` as **official enough to plan for**, but **not the cleanest first wrapper slice**.
- Treat mod.io wallet/checkout as primarily **web/self-hosted / non-store-controlled distribution** territory.
- For major app stores, the safer assumption is **platform-native billing + entitlement sync into mod.io**, not direct mod.io checkout inside the shipped store app.
