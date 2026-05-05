# AeroBeat Vendor Mod.io Monetization, Entitlements, and S2S Coverage

**Date:** 2026-05-04  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Extend `aerobeat-vendor-modio` into the next truthful mod.io coverage family after the completed cook/platform slice by mapping and then, once clarified, wrapping the monetization / purchases / entitlements / S2S / partner-team provider surfaces without drifting into higher-level AeroBeat commerce policy, wallet workflow orchestration, or business-logic ownership.

---

## Overview

The source/multipart upload slice is complete, and the cook / cloud-cook / platform-management slice is now complete as well. That leaves the next remaining heavy family called out in the earlier handoff: monetization / purchases / entitlements / S2S / partner-team surfaces.

This family is the riskiest one yet, because it is where vendor endpoint wrapping starts to brush directly against product policy, purchase lifecycle decisions, entitlement semantics, refund/revocation interpretation, account/business relationships, and server-to-server integration boundaries. Before coder work begins, we need the same pre-slice ambiguity pass used successfully on the previous heavy slices: identify the exact documented endpoint map, separate clean thin-wrapper surfaces from endpoints that imply broader business-policy ownership, and convert every real boundary question into a short Derrick decision memo with options and recommendations.

The default posture remains docs-first and seam-preserving. If the refreshed official corpus shows documented request/response surfaces that can still be wrapped as thin vendor-local operations, they can become the next execution slice. If some endpoints require AeroBeat-side commerce policy or broader orchestration choices, those need to be called out explicitly before implementation instead of being smuggled into this adapter.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Last session handoff memory | `/home/derrick/.openclaw/workspace/memory/2026-05-03.md` |
| `REF-02` | Completed upload pipeline slice | `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md` |
| `REF-03` | Completed cook/platform slice | `.plans/2026-05-04-aerobeat-vendor-modio-cook-and-platform-coverage.md` |
| `REF-04` | Prior remaining-coverage umbrella plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-05` | Current mod.io REST research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-06` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-07` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-08` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-09` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-10` | Current implementation | `src/` |
| `REF-11` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the monetization / entitlements / S2S / partner-team family

**Bead ID:** `oc-pjz`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the current wrapped repo surface against the refreshed official local mod.io corpus and produce an execution-ready map for the next monetization / purchases / entitlements / S2S / partner-team family after the completed cook/platform slice. Identify the exact documented endpoints, group them into coherent provider-local slices, distinguish which ones still fit a thin vendor adapter seam, and turn every real pre-slice boundary or implementation-policy question into a simple Derrick decision memo with options and a recommendation. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise audit note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md`
- optional note(s)

**Status:** ✅ Complete → 🔄 Follow-up research in progress (`oc-bg1`)

**Results:** Pre-slice ambiguity audit completed against `REF-07` through `REF-10` and compared with the current wrapper/test surface. Derrick then requested a follow-up research pass before final monetization scope lock-in to double-check the `/me/iap/*/sync` corpus drift and to verify whether mod.io monetization can be used alongside releases on Steam / Apple App Store / Google Play / Meta Quest stores without conflicting with platform/store payment rules.

**Follow-up addendum (monetization/store-policy pass, `oc-bg1`):**
- Added concise repo-local note: `docs/modio-monetization-follow-up-2026-05-04.md`.
- **`/me/iap/*/sync` drift conclusion:** treat these endpoints as **real and likely supported in practice**, but **ambiguously documented in the mirrored REST corpus**.
  - High-confidence local evidence:
    - `REF-07/public/en-us/features/monetization/purchase-servers/modio-as-purchase-server.md` explicitly documents guide flows for `/me/iap/xboxlive/sync`, `/me/iap/psn/sync`, `/me/iap/steam/sync`, `/me/iap/meta/sync`, and `/me/iap/epicgames/sync`.
    - `REF-08/modio/modio/core/ModioDefaultRequestParameters.h` defines request params for `/me/iap/apple/sync`, `/me/iap/google/sync`, `/me/iap/epicgames/sync`, `/me/iap/meta/sync`, `/me/iap/psn/sync`, `/me/iap/steam/sync`, and `/me/iap/xboxlive/sync`.
    - `REF-09/Modio/API/Generated/Endpoints/` contains generated endpoints for the same set, including Apple and Google.
    - `REF-09/Unity/Platforms/MobilePurchasing/ModioMobileStoreService.cs` actively routes Unity IAP receipts to `SyncGoogleEntitlements(...)` and `SyncAppleEntitlement(...)`.
  - High-confidence drift finding:
    - `REF-07/public/en-us/restapi/docs/` does **not** contain matching `.api.mdx` pages for those `/me/iap/*/sync` routes.
  - Practical interpretation:
    - This looks like **upstream docs/reference incompleteness**, not fake/internal-only code paths and not repo-local invention.
    - Recommended handling: do **not** call them “unsupported”; call them **SDK-backed / guide-backed but incomplete in the mirrored REST reference**.
- **Intended monetization shape:** mod.io appears to support **both** of these patterns, depending on distribution context:
  1. **Platform-native IAP -> entitlement sync into mod.io** via `/me/iap/*/sync`.
  2. **Direct mod.io wallet / checkout** via `GET /me/wallets`, `GET /me/purchased`, and `POST /games/{game-id}/mods/{mod-id}/checkout`.
- **Platform-by-platform follow-up recommendation:**
  - **Steam** — medium-high confidence, strong local mod.io evidence. Treat as a realistic target for **Steam-native commerce with mod.io entitlement sync** (`/me/iap/steam/sync`). Direct mod.io checkout in a Steam-distributed build is not the default recommended path.
  - **Apple App Store** — high confidence on the broad billing constraint, using official Apple guideline/search evidence plus strong local mod.io/Unity evidence. Treat shipped iOS App Store builds as **Apple IAP first, then mod.io sync** (`/me/iap/apple/sync`), not direct mod.io wallet/checkout inside the app.
  - **Google Play** — high confidence, using official Google Play Payments policy plus strong local mod.io/Unity evidence. Treat Play builds as **Google Play Billing first, then mod.io sync** (`/me/iap/google/sync`), not direct mod.io wallet/checkout inside the app.
  - **Meta Quest store** — medium confidence, with strong local mod.io evidence and lighter official policy evidence than Apple/Google. Treat Meta Quest as a plausible **Meta add-on/IAP -> mod.io sync** target (`/me/iap/meta/sync`), while avoiding stronger legal/policy claims than the evidence supports.
- **Updated immediate slice recommendation:**
  - **Wrap now:** `GET /me/wallets` + `GET /me/purchased`.
  - **Optional next read helper:** `POST /me/entitlements` if Derrick wants non-consuming entitlement lookup without committing to store-specific sync writes.
  - **Defer one slice:** `POST /games/{game-id}/mods/{mod-id}/checkout` and all `/me/iap/*/sync` write wrappers until Derrick locks the initial store/distribution targets and whether AeroBeat needs platform-sync flows in this adapter right away.
  - Reason for deferral is **not** “these endpoints look fake”; the reason is that they are **real enough technically but no longer the cleanest first thin-wrapper slice** because they combine upstream doc drift with immediate store-specific product decisions.

**Exact next endpoint map after the completed cook/platform slice**

1. **Marketplace state + wallet read slice** — cleanest thin-wrapper candidate, fully backed by local REST endpoint pages.
   - `GET /me/wallets`
     - doc: `REF-07/public/en-us/restapi/docs/get-user-wallet.api.mdx`
     - required query when g-url is not used: `game_id`
     - response fields of interest: `type`, `payment_method_id`, `game_id`, `currency`, `balance`, `pending_balance`, `deficit`, `monetization_status`
     - important error refs: `900022`, `17034`, `900002`, `900007`, `900008`
   - `GET /me/purchased`
     - doc: `REF-07/public/en-us/restapi/docs/get-user-purchases.api.mdx`
     - filters: `id`, `game_id`, `status`, `visible`, `submitted_by`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `modfile`, `metadata_kvp`, `metadata_blob`, `tags`, `maturity_option`, `monetization_options`, `platform_status`, `platforms`
     - sort keys: `name`, `date_live`, `date_updated`, `submitted_by`, `downloads_today`, `downloads_total`, `subscribers_total`, `ratings_weighted_aggregate`
     - platform-targeting note: docs say the endpoint supports the platform header only when the parent game has cross-platform filtering enabled, and only when `game_id` is also supplied

2. **Purchase + entitlement client flow slice** — still thin-wrapper-compatible, but real product-scope decisions are required before write implementation.
   - `POST /games/{game-id}/mods/{mod-id}/checkout`
     - doc: `REF-07/public/en-us/restapi/docs/purchase.api.mdx`
     - headers: optional `X-Modio-Portal`, optional `X-Modio-Platform` and required for `psn`
     - required body: `idempotent_key`, `type`
     - conditional body fields: `display_amount`, `subscribe`, `psn_token`, `psn_env`, `psn_service_label`, `xbox_token`, `epicgames_token`, `epicgames_sandbox_id`, `payment_method_id`, `terms_accepted`, `refund_accepted`, `transaction_id`
     - checkout `type` values: `0` virtual token checkout, `1` sku checkout, `2` unified checkout, `3` unified intent, `4` unified commit
     - notable error refs that materially affect scope: `900074`, `900014`, `900020`, `900021`, `900034`, `900035`, `900049`, `900051`, `900055`, `900061`, `900064`, `900098`
   - `POST /me/entitlements`
     - doc: `REF-07/public/en-us/restapi/docs/get-user-entitlements.api.mdx`
     - required header: `X-Modio-Portal`
     - optional/conditional header: `X-Modio-Platform`, required for `psn`
     - body shape varies by portal: `game_id`, `psn_token`, `psn_env`, `psn_service_label`, `xbox_token`, `epicgames_token`, `epicgames_sandbox_id`
     - returns minimal rows `{ sku_id, entitlement_type }`
     - important error refs: `11069`, `900098`, `900054`, `14001`
   - **Guide-documented + SDK-backed entitlement-sync surfaces with local corpus drift**
     - The official guide `REF-07/public/en-us/features/monetization/purchase-servers/modio-as-purchase-server.md` and official SDKs (`REF-08`, `REF-09`) clearly reference these endpoints, but the refreshed local `modio-docs` mirror does **not** contain matching `public/en-us/restapi/docs/*.api.mdx` pages for them.
     - Paths evidenced by the official SDKs:
       - `POST /me/iap/apple/sync`
       - `POST /me/iap/epicgames/sync`
       - `POST /me/iap/google/sync`
       - `POST /me/iap/meta/sync`
       - `POST /me/iap/psn/sync`
       - `POST /me/iap/steam/sync`
       - `POST /me/iap/xboxlive/sync`
     - This is upstream corpus drift, not repo drift. It should be documented explicitly if/when wrapped.

3. **Partner-team / creator monetization team slice** — transport is straightforward, but ownership/payout policy is a real boundary.
   - `GET /games/{game-id}/mods/{mod-id}/monetization/team`
     - doc: `REF-07/public/en-us/restapi/docs/get-users-in-mod-monetization-team.api.mdx`
     - response fields: `id`, `name_id`, `username`, `monetization_status`, `monetization_options`, `split`
     - notable errors: `900023`, `900022`
   - `POST /games/{game-id}/mods/{mod-id}/monetization/team`
     - doc: `REF-07/public/en-us/restapi/docs/create-mod-monetization-team.api.mdx`
     - body is `multipart/form-data` with `users[]` objects containing required `id` and `split`
     - notable errors: `900023`, `900003`, `900008`, `900024`, `900025`, `900026`, `900029`

4. **Studio purchase-server / service-token S2S slice** — documented, but not a good default fit for a game-facing vendor adapter unless Derrick explicitly wants that architecture.
   - `POST /s2s/transactions/intent`
     - doc: `REF-07/public/en-us/restapi/docs/s-2-s-transaction-intent.api.mdx`
     - headers: required `X-Modio-Delegation-Token`, optional `X-Modio-Idempotent-Key`
     - body: required `sku`, `portal`; optional `gateway_uuid`
   - `POST /s2s/transactions/commit`
     - doc: `REF-07/public/en-us/restapi/docs/s-2-s-transaction-commit.api.mdx`
     - header: optional `X-Modio-Idempotent-Key`
     - body: required `transaction_id`; optional `clawback_uuid`
   - `POST /s2s/transactions/clawback`
     - doc: `REF-07/public/en-us/restapi/docs/s-2-s-transaction-clawback.api.mdx`
     - body: required `refund_reason`, `portal`, and one of `transaction_id` or `gateway_uuid`; optional `clawback_uuid`
     - doc/schema drift: `gateway_uuid` is described as alpha-dash/UUID but typed as integer in the page schema
   - `GET /s2s/monetization-teams/{monetization-team-id}/transactions`
     - doc: `REF-07/public/en-us/restapi/docs/get-monetization-transactions.api.mdx`
     - documented filters: `transaction_type`, `monetization_type`, `buyer`, `clawback_uuid`, `gateway_uuid`, `line_items`, `created_at_start`
   - `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`
     - doc: `REF-07/public/en-us/restapi/docs/get-monetization-transaction.api.mdx`
   - `DELETE /s2s/connections/{portal-id}`
     - doc: `REF-07/public/en-us/restapi/docs/s-2-s-disconnect-user.api.mdx`
     - purpose: disconnect a mod.io user from a linked studio user

5. **Already-completed prerequisite in current repo**
   - `GET /games/{game-id}/monetization/token-packs` is already wrapped and is the natural dependency immediately before wallet / purchases / entitlements.

**Recommended natural execution order once decisions are locked**
- First implementable slice: `GET /me/wallets` + `GET /me/purchased`
- Second slice: `/checkout` plus the entitlement flow Derrick explicitly wants
- Third slice: partner-team only if AeroBeat actually wants creator payout-team visibility/management here
- Separate server-owned slice or separate module: `/s2s/*`

**Exact pre-slice questions Derrick should answer**

### 1. Which purchase-server model does AeroBeat actually want this vendor repo to support?
- **Plain-English:** mod.io supports two different commerce architectures: mod.io can consume platform entitlements for us, or AeroBeat can run its own purchase server and talk to the S2S APIs directly.
- **Why it matters technically:** this decides whether the next slice is a user-token game-client wrapper (`/me/*`, `/checkout`) or a service-token backend integration (`/s2s/*`) with delegation tokens, idempotency persistence, clawbacks, and transaction reconciliation.
- **Options:**
  1. Support only mod.io-as-purchase-server flows in this repo.
  2. Support both mod.io-as-purchase-server and studio-as-purchase-server flows in this repo.
  3. Keep this repo client/game-facing and move S2S to a separate server-side adapter.
- **Recommended option:** **3**.

### 2. Do we want to treat the guide-only entitlement sync endpoints as in-scope now despite missing local REST endpoint pages?
- **Plain-English:** the official guide and official SDKs clearly use `/me/iap/*/sync`, but the refreshed `modio-docs` REST endpoint directory does not currently contain matching `.api.mdx` pages for those routes.
- **Why it matters technically:** the repo goal has been strict docs-first parity. Wrapping these endpoints now means accepting guide+SDK-backed coverage even though the mirrored REST-page corpus is incomplete.
- **Options:**
  1. Exclude `/me/iap/*/sync` for now and only implement REST-page-backed endpoints.
  2. Include `/me/iap/*/sync` now, using the conceptual guide plus official SDK request shapes as source of truth and documenting the corpus drift.
  3. Include only the portals AeroBeat actually ships first, and defer the rest.
- **Recommended option:** **1** for the immediate next slice, then **3** later if AeroBeat actually needs platform entitlement sync in this adapter.

### 3. Which checkout modes are actually required in AeroBeat’s product surface?
- **Plain-English:** the single `/checkout` endpoint actually contains several different product behaviors: token-wallet spend, external SKU purchase, unified payment intent, unified payment commit, and terms/refund acceptance flows.
- **Why it matters technically:** request validation, required body fields, idempotency handling, UI contract, and QA flows all depend on which `type` values we intend to support.
- **Options:**
  1. Support only `type=0` virtual-token wallet purchases first.
  2. Support `type=0` plus `type=1` portal-SKU purchases.
  3. Support all documented types `0-4` from the start.
- **Recommended option:** **1** unless Derrick explicitly wants external-SKU or unified/USD checkout right now.

### 4. Does AeroBeat want creator payout-team management in this adapter, or only read-only visibility?
- **Plain-English:** the monetization-team endpoints are not about a buyer purchasing mods; they are about who gets paid and what percentage split they receive.
- **Why it matters technically:** `POST /monetization/team` is a business-policy/admin action with irreversible org/payout implications that goes beyond a neutral game-client wrapper.
- **Options:**
  1. Exclude partner-team endpoints entirely from this repo.
  2. Include only `GET /games/{game-id}/mods/{mod-id}/monetization/team`.
  3. Include both GET and POST team-management endpoints.
- **Recommended option:** **2** at most, and only if AeroBeat has an immediate product need to inspect creator splits.

### 5. Should this repo own wallet/deficit semantics only as raw transport, or should it normalize them into AeroBeat commerce meaning?
- **Plain-English:** wallet responses include `pending_balance`, `deficit`, and `monetization_status`, which already have clear vendor meaning.
- **Why it matters technically:** if the adapter starts interpreting deficit/debt or approval state, it stops being a thin vendor seam and becomes product-policy code.
- **Options:**
  1. Return raw vendor fields only and let higher layers decide what they mean.
  2. Add normalized AeroBeat convenience flags in the vendor layer.
- **Recommended option:** **1**.

**What can be handled during coder → QA → audit without asking Derrick**
- Exact query serialization for `GET /me/purchased` filters and sort keys.
- Exact request-shape validation for `game_id`, `X-Modio-Portal`, `X-Modio-Platform`, `idempotent_key`, and per-portal token fields.
- Preserving raw wallet fields like `pending_balance`, `deficit`, and `monetization_status` without interpreting them.
- Preserving raw pay/transaction objects and error refs without inventing higher-level commerce state machines.
- Documenting corpus drift where `/me/iap/*/sync` appears in guides/SDKs but lacks local REST `.api.mdx` pages.
- Keeping `/s2s/*` out of the game-facing adapter unless Derrick explicitly expands scope.

**Net recommendation from research**
- The clean next slice is `GET /me/wallets` + `GET /me/purchased`.
- The next decision-gated slice is `/checkout` plus whatever entitlement flow Derrick explicitly wants.
- The S2S slice should not start in this repo by default.
- The partner-team write endpoint should not start without an explicit product/admin use-case.
- Upstream corpus drift exists around `/me/iap/*/sync`, and the repo should document that rather than pretending the REST mirror is complete.

---

### Task 2: Implement the next approved monetization-family slice

**Bead ID:** `oc-13x`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the next approved monetization-family mod.io slice exactly as defined by the research and Derrick’s decision lock-in. For this slice, wrap only the clean REST-page-backed endpoints `GET /me/wallets`, `GET /me/purchased`, and `POST /me/entitlements`. Preserve exact request/path/header/body semantics from the refreshed official REST docs, keep the wrapper thin, add only minimal provider-local helpers, extend tests/fixtures/docs, update the plan with exact results and any deliberate deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `src/models/modio_listing_query.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/fixtures/wallet.json`
- `.testbed/tests/fixtures/purchased.json`
- `.testbed/tests/fixtures/entitlements.json`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md`

**Status:** ⏳ Pending → 🚧 In Progress → ✅ Complete

**Results:** Implemented the approved thin-wrapper monetization-user slice only:
- `GET /me/wallets`
  - added `build_user_wallet_request(...)`
  - enforces the documented `game_id` requirement unless the caller is using a g-url host
  - normalizes only raw wallet/provider fields (`type`, `payment_method_id`, `game_id`, `currency`, `balance`, `pending_balance`, `deficit`, `monetization_status`)
- `GET /me/purchased`
  - added `build_user_purchased_request(...)`
  - extended `ModioListingQuery` with the endpoint-specific `platforms` filter plus the purchased-mod `_sort` allowlist
  - preserves only the documented purchased-mod filters and auto-injects configured `game_id` only when platform targeting is in play and the caller omitted it
  - reuses raw mod-list normalization so purchased responses keep vendor monetization fields such as `price`, `tax`, and `skus`
- `POST /me/entitlements`
  - added `build_user_entitlements_request(...)`
  - preserves the required `X-Modio-Portal` header, validates only the documented body fields, and enforces the PSN-only `X-Modio-Platform` + `psn_token` requirements
  - normalizes only the minimal entitlement row shape (`sku_id`, `entitlement_type`)

Tests/fixtures/docs updated to prove the exact request/query/header/body semantics and raw-response stance:
- added fixtures for wallet, purchased-mod, and entitlement payloads
- extended vendor-adapter tests to cover successful request construction, docs-gated sort/filter behavior, validation errors, and normalization
- updated `README.md` and `docs/modio-seam-plan.md` to record the new endpoints and the intentional monetization deferrals

Validation evidence:
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- result: `55` tests passed, `0` failed

Deliberately deferred for later monetization follow-up slices:
- `POST /games/{game-id}/mods/{mod-id}/checkout`
- guide/SDK-backed but REST-mirror-drifted `/me/iap/*/sync` wrappers
- partner-team endpoints
- documented `/s2s/*` endpoints

Additional decision lock-in preserved in code/docs:
- documented REST endpoints belong in this vendor repo even when they are S2S/server-side surfaces; keep the API honest about caller model
- because `/me/iap/*/sync` is not cleanly represented in the mirrored REST corpus, do not guess — handle only what is confirmed in the REST API for this slice
- raw vendor wallet/monetization data should be returned without AeroBeat-specific convenience semantics

---

### Task 3: QA the monetization-family slice

**Bead ID:** `oc-92o`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest monetization-family implementation against the refreshed official local mod.io corpus. Confirm request shapes, transport behavior, fixtures, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md`

**Status:** ⏳ Pending → ✅ Complete

**Results:** Independently re-verified the monetization-user slice against `REF-07` through `REF-10` and found no implementation drift requiring code changes. Exact QA findings:
- `GET /me/wallets` matches the refreshed REST docs exactly: request method/path are `GET /me/wallets`, auth stays bearer-only, and the wrapper preserves the documented `game_id` rule by requiring it unless the caller is using a g-url host. Response normalization stays intentionally raw and limited to the documented wallet fields: `type`, `payment_method_id`, `game_id`, `currency`, `balance`, `pending_balance`, `deficit`, and `monetization_status`.
- `GET /me/purchased` matches the refreshed REST docs exactly: request method/path are `GET /me/purchased`, auth stays bearer-only, query serialization is limited to the documented purchased-mod filters (`id`, `game_id`, `status`, `visible`, `submitted_by`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `modfile`, `metadata_kvp`, `metadata_blob`, `tags`, `maturity_option`, `monetization_options`, `platform_status`, `platforms`) plus paging and the documented `_sort` allowlist (`name`, `date_live`, `date_updated`, `submitted_by`, `downloads_today`, `downloads_total`, `subscribers_total`, `ratings_weighted_aggregate`).
- The purchased-mod platform caveat is preserved exactly: because this repo forwards configured `X-Modio-Platform` headers through the shared config, `build_user_purchased_request(...)` injects configured `game_id` only when platform targeting is in play and the caller omitted it, matching the docs note that platform-targeted purchased reads must also include `game_id`.
- `POST /me/entitlements` matches the refreshed REST docs exactly: request method/path are `POST /me/entitlements`, content type stays `application/x-www-form-urlencoded`, `X-Modio-Portal` is required, and the wrapper validates only the documented request-body fields (`game_id`, `psn_token`, `psn_env`, `psn_service_label`, `xbox_token`, `epicgames_token`, `epicgames_sandbox_id`).
- The PSN-specific entitlement requirements are preserved exactly: `X-Modio-Platform` is enforced only when `portal == psn`, `psn_token` is required for PSN requests, and `psn_env` / `psn_service_label` stay integer-only when supplied. The wrapper does not invent Apple/Google/Meta/Steam sync fields on this REST-page-backed route.
- Re-checked response-shape boundaries and found no AeroBeat convenience leakage: wallets stay raw provider wallets, purchased results reuse the raw mod-object normalization so monetization fields like `price`, `tax`, and `skus` remain intact, and entitlements normalize only the minimal documented row shape (`sku_id`, `entitlement_type`).
- Re-checked seam exclusions and found no leaked `/me/iap/*/sync`, checkout, partner-team, or `/s2s/*` wrappers in `src/`; the only mentions are deliberate documentation/plan deferrals that explain why those surfaces remain out of scope for this slice.
- Re-checked `README.md`, `docs/modio-seam-plan.md`, and this plan and found the documentation truthful: the repo claims only `GET /me/wallets`, `GET /me/purchased`, and `POST /me/entitlements` for this monetization-user slice, explicitly records the intentional deferral of checkout plus the drifted `/me/iap/*/sync` family, and does not overclaim entitlement-sync support.

Validation evidence:
- `godot --headless --path .testbed --import`
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- result: `55` tests passed, `0` failed (`1869` asserts)

Fixes made:
- none required

---

### Task 4: Audit the monetization-family slice

**Bead ID:** `oc-b71`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest monetization-family implementation against the refreshed official local mod.io corpus and the repo seam plan. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and clearly documents anything deferred to later policy-heavy surfaces. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md`

**Status:** ⏳ Pending → ✅ Complete

**Results:** Independent audit completed against `REF-07` through `REF-10` plus the locked boundary rules. Exact audit findings:
- `GET /me/wallets` remains doc-correct: method/path are `GET /me/wallets`, auth stays bearer-only, and `build_user_wallet_request(...)` preserves the documented `game_id` requirement by validating that `game_id` must resolve either from the call or from configured g-url context. Wallet normalization stays intentionally raw and limited to the documented fields `type`, `payment_method_id`, `game_id`, `currency`, `balance`, `pending_balance`, `deficit`, and `monetization_status`.
- `GET /me/purchased` remains doc-correct: method/path are `GET /me/purchased`, auth stays bearer-only, query support is limited to the documented purchased-mod filters/sorts captured from `REF-08`, and the adapter preserves the platform-targeting caveat truthfully by auto-injecting configured `game_id` only when a configured `X-Modio-Platform` header is in play and the caller omitted `game_id`.
- `POST /me/entitlements` was almost correct but had one real drift: when platform targeting was supplied via shared adapter config instead of the per-call `platform` argument, `_normalize_user_entitlements_fields(...)` erased the configured `X-Modio-Platform` header before PSN validation. That meant a config-driven PSN entitlement request could incorrectly fail local validation even though the shared config already carried the documented platform target.
- Minimum fix applied: `_normalize_user_entitlements_fields(...)` now falls back to `_config.platform` before deciding whether `X-Modio-Platform` is absent. This preserves the documented PSN rule exactly while staying aligned with the repo’s shared-header behavior.
- Added regression coverage to prove both paths: explicit PSN platform targeting still passes, and config-driven PSN platform targeting now also passes without requiring a redundant explicit `platform` argument.
- Re-checked seam boundaries and found no leaked `/me/iap/*/sync`, checkout, partner-team, or `/s2s/*` wrappers in `src/`; those surfaces remain documented deferrals only.
- Re-checked `README.md`, `docs/modio-seam-plan.md`, and this plan after the fix and found them still truthful: the repo claims only `GET /me/wallets`, `GET /me/purchased`, and `POST /me/entitlements` for this slice and does not overclaim entitlement-sync support.

Changed files:
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md`

Validation evidence:
- `godot --headless --path .testbed --import`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- result after fix: `55` tests passed, `0` failed (`1873` asserts)

Fixes made:
- preserved config-driven `X-Modio-Platform` handling for `POST /me/entitlements`
- added regression coverage for config-driven PSN entitlement requests

---

## Final Results

**Status:** ✅ Complete

**What We Built:** A clean REST-backed monetization-user slice for `GET /me/wallets`, `GET /me/purchased`, and `POST /me/entitlements`, plus independent QA and audit verification against the refreshed local mod.io REST corpus. The final audit found one config-driven PSN entitlement-header drift, applied the minimum fix, and added regression coverage without expanding scope into checkout, `/me/iap/*/sync`, partner-team, or `/s2s/*` surfaces.

**Reference Check:** Final implementation and audit findings were validated against `REF-07`, `REF-08`, `REF-09`, and cross-checked against adjacent SDK/Unity behavior in `REF-10` while preserving the locked boundary captured in `REF-11`.

**Commits:**
- `986bf22` - Add mod.io monetization user endpoints
- Audit fix commit on `main` - Honor config-driven PSN entitlement platform header

**Lessons Learned:** The REST-backed monetization-user slice stays clean when it is treated as three documented endpoints with strict request-shape gating. The sharp edge was not endpoint discovery but shared-header behavior: if platform targeting can come from shared config for purchased reads, entitlement validation must honor that same source of truth for PSN requests instead of requiring a redundant per-call override.

---

*Completed on 2026-05-04*