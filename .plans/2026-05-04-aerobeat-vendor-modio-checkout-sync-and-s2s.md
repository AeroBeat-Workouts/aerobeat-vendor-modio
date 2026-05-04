# AeroBeat Vendor Mod.io Checkout, Sync, and S2S Coverage

**Date:** 2026-05-04
**Status:** In Progress
**Agent:** Chip 🐱‍💻

---

## Goal

Extend `aerobeat-vendor-modio` into the next truthful monetization family after the completed wallet/purchased/entitlements slice by mapping and then, once clarified, wrapping checkout, entitlement-sync, and documented S2S provider surfaces without drifting into hidden AeroBeat commerce policy or undocumented contract guesses.

---

## Overview

The clean REST-backed monetization read/query slice is now complete: `GET /me/wallets`, `GET /me/purchased`, and `POST /me/entitlements` landed and passed coder → QA → audit. The next remaining monetization family is the heavier write/integration set: checkout, the guide/SDK-backed but REST-mirror-drifted `/me/iap/*/sync` routes, and the documented `/s2s/*` server-side transaction surfaces.

This family needs the same ambiguity-clearing pass as the earlier heavy slices, but with extra care because it mixes three different levels of certainty and caller model: (1) clearly REST-documented checkout writes, (2) sync endpoints that appear strongly supported in guides/SDKs/Unity but are incompletely represented in the local REST endpoint corpus, and (3) clearly documented S2S endpoints that belong in this vendor repo but must stay explicitly honest about their server-side trust model.

The default posture remains: wrap what is truthfully documented, document drift explicitly, and avoid guessing. Before coder work starts, we need the exact endpoint map, the remaining boundary/product questions, and a concrete recommendation for which subset should become the immediate next implementation slice.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Last session handoff memory | `/home/derrick/.openclaw/workspace/memory/2026-05-03.md` |
| `REF-02` | Completed wallet/purchased/entitlements slice | `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md` |
| `REF-03` | Completed cook/platform slice | `.plans/2026-05-04-aerobeat-vendor-modio-cook-and-platform-coverage.md` |
| `REF-04` | Prior remaining-coverage umbrella plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-05` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-06` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-07` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-08` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-09` | Current implementation | `src/` |
| `REF-10` | Current fixture/test corpus | `.testbed/tests/` |
| `REF-11` | Monetization follow-up note | `docs/modio-monetization-follow-up-2026-05-04.md` |

---

## Tasks

### Task 1: Research checkout / sync / S2S family and lock the next subset

**Bead ID:** `oc-2h7`
**SubAgent:** `primary`
**Role:** `research`
**References:** `REF-01` through `REF-11`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the remaining monetization wrapper surface against the refreshed local official corpus and produce an execution-ready map for the next checkout / entitlement-sync / S2S family. Distinguish clearly REST-backed checkout/S2S surfaces from guide/SDK/Unity-backed but REST-mirror-drifted sync endpoints, identify every real pre-slice decision Derrick still needs to make, and recommend the exact next subset to implement immediately. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise audit note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-checkout-sync-and-s2s.md`
- optional note(s)

**Status:** ✅ Complete

**Results:**

Derrick decision lock-in (2026-05-04):
- checkout breadth: wrap all documented checkout modes `0..4`
- direct mod.io checkout policy: non-store / web / PC-only for now
- drifted `/me/iap/*/sync` routes: exclude until they are clearly confirmed in the REST API
- Apple/Google sync interest noted, but currently deferred under the REST-only rule
- PSN sync naming preference if/when revisited later: guide names only
- monetization S2S caller model: same repo, explicit server-side/service-token surface
- S2S subset: all five documented monetization `/s2s/*` endpoints
- `monetization-team-id` source: explicit config

Immediate implementation-ready subset from these decisions:
- `POST /games/{game-id}/mods/{mod-id}/checkout`
- `POST /s2s/transactions/intent`
- `POST /s2s/transactions/commit`
- `POST /s2s/transactions/clawback`
- `GET /s2s/monetization-teams/{monetization-team-id}/transactions`
- `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`

Explicitly deferred for now:
- all drifted `/me/iap/*/sync` routes pending clearer REST API confirmation from mod.io
- partner-team / partner-program work

Research completed against the strongest local official corpus with this source-quality order: refreshed REST endpoint pages in `REF-06` first, then official guide docs in `REF-06`, then official SDK request definitions in `REF-07`, then official Unity references in `REF-08`.

#### Endpoint map

**A. Checkout — clean REST-backed**

- `POST /games/{game-id}/mods/{mod-id}/checkout`
  - Primary source: `modio-docs/public/en-us/restapi/docs/purchase.api.mdx` (`REF-06`)
  - Confidence: high
  - Notes:
    - One endpoint, but it actually contains multiple checkout modes via `type`:
      - `0` = virtual token checkout
      - `1` = SKU checkout
      - `2` = unified checkout (intent + commit)
      - `3` = unified intent
      - `4` = unified commit
    - Header/body complexity is mode-sensitive and portal-sensitive.
    - `X-Modio-Portal` is documented for `steam`, `xboxlive`, `psn`, and `epicgames`.
    - `X-Modio-Platform` is documented as required when portal is `psn`.
    - Portal/mode-specific body fields include `psn_token`, `psn_env`, `psn_service_label`, `xbox_token`, `epicgames_token`, `epicgames_sandbox_id`, `payment_method_id`, `terms_accepted`, `refund_accepted`, and `transaction_id`.

**B. Drifted entitlement sync — official, but not clean REST-page-backed**

No matching `.api.mdx` endpoint pages were found in the refreshed local REST corpus for any `/me/iap/*/sync` route. These should therefore be treated as drifted non-REST-page-backed surfaces, even when they are strongly supported elsewhere.

**Guide-backed exact routes**
- `POST /me/iap/xboxlive/sync`
- `POST /me/iap/psn/sync`
- `POST /me/iap/steam/sync`
- `POST /me/iap/meta/sync`
- `POST /me/iap/epicgames/sync`
  - Primary source: `modio-docs/public/en-us/features/monetization/purchase-servers/modio-as-purchase-server.md` (`REF-06`)
  - Confidence: medium-high
  - Notes:
    - These are explicitly documented in the official monetization guide.
    - The guide includes request bodies and a shared fulfillment-shaped response (`wallet.balance` + `data[]`).
    - They are also corroborated by SDK/Unity generated endpoints.

**SDK/Unity-backed only in the local corpus**
- `POST /me/iap/apple/sync`
- `POST /me/iap/google/sync`
  - Primary sources:
    - `modio-sdk/modio/modio/core/ModioDefaultRequestParameters.h` (`REF-07`)
    - `modio-unity/Modio/API/Generated/Endpoints/SyncAppleEntitlement.cs` (`REF-08`)
    - `modio-unity/Modio/API/Generated/Endpoints/SyncGoogleEntitlements.cs` (`REF-08`)
    - request objects under `modio-unity/Modio/API/Generated/Definitions/RequestObjects/` (`REF-08`)
  - Confidence: medium
  - Notes:
    - Apple/Google do not appear in the monetization guide section that documents the other sync routes.
    - The SDK and Unity code strongly indicate real routes with a `receipt` body field.
    - Because they are not REST-page-backed and not guide-documented in the local corpus, they are the highest-ambiguity members of this family.

**Known drift inside the drifted family**
- PSN request fields drift between sources:
  - guide: `psn_token`, `psn_env`, `psn_service_label`
  - Unity request object: `auth_code`, `env`, `service_label`
- Apple/Google body shape is only clearly visible in Unity request objects (`receipt`).
- This family must therefore be wrapped, if at all, as explicitly drifted and source-qualified rather than presented as clean REST-reference parity.

**C. Documented monetization S2S — clean REST-backed**

- `POST /s2s/transactions/intent`
  - REST page: `restapi/docs/s-2-s-transaction-intent.api.mdx`
- `POST /s2s/transactions/commit`
  - REST page: `restapi/docs/s-2-s-transaction-commit.api.mdx`
- `POST /s2s/transactions/clawback`
  - REST page: `restapi/docs/s-2-s-transaction-clawback.api.mdx`
- `GET /s2s/monetization-teams/{monetization-team-id}/transactions`
  - REST page: `restapi/docs/get-monetization-transactions.api.mdx`
- `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`
  - REST page: `restapi/docs/get-monetization-transaction.api.mdx`
  - Primary source: `REF-06`
  - Confidence: high for path existence and core request/response shapes
  - Notes:
    - These are clearly within the documented monetization S2S family and belong in this vendor repo if implemented.
    - Caller model must stay explicit: these are server-side / service-token surfaces, not ordinary bearer-user endpoints.

**Important adjacent prerequisite, but not part of the `/s2s/*` path family itself**
- `POST /me/s2s/oauth/token`
  - REST-backed and already represented in the repo seam.
  - This is a prerequisite for user delegation token workflows, not one of the target `/s2s/*` paths for this slice.

**D. Optional partner-team overlap**

- Recommendation: **exclude partner-program / partner-team work from this slice.**
- Source reviewed: `modio-docs/public/en-us/features/monetization/partner-program.md` (`REF-06`)
- Reason:
  - It is a creator eligibility/admin program surface.
  - It does not tightly overlap the checkout / entitlement-sync / transaction-processing family.
  - Pulling it in now would broaden the slice into moderation/admin policy instead of purchase mechanics.

#### Pre-slice decision memos Derrick should answer before implementation

**1. What is the first checkout breadth we actually want?**
- Plain-English: the checkout endpoint is one route, but it really hides several product flows. We should not pretend “checkout” is one simple thing.
- Why it matters technically: request validation, headers, required fields, tests, and naming all change depending on `type` and portal.
- Options:
  1. Wrap only checkout `type=0` (virtual token checkout) first.
  2. Wrap checkout `type=0` and `type=1` first.
  3. Wrap all documented checkout modes `0..4` in one slice.
- Recommended option: **Option 1.** Start with `type=0` only. It is the narrowest truthful REST-backed subset and avoids prematurely baking in unified-checkout and portal-token policy.

**2. In AeroBeat product terms, where is direct mod.io checkout actually allowed to exist?**
- Plain-English: direct mod.io wallet checkout looks viable in some distributions, but store-native billing is the safer/default assumption for Apple/Google and probably other store-controlled environments.
- Why it matters technically: it changes whether checkout wrappers are first-class gameplay surfaces or niche/server/web/PC-only seams.
- Options:
  1. Treat direct checkout as non-store / web / PC-only for now.
  2. Allow direct checkout on all portals unless blocked later.
  3. Defer checkout entirely until product/channel policy is locked.
- Recommended option: **Option 1.** Treat direct checkout as non-store-controlled distribution territory for the first slice.

**3. Should the drifted `/me/iap/*/sync` routes be in scope at all before REST-page parity exists?**
- Plain-English: these routes look official, but the local REST mirror does not cleanly expose them as endpoint pages.
- Why it matters technically: this determines whether the vendor seam may include non-REST-page-backed routes that are still guide/SDK/Unity-confirmed.
- Options:
  1. Exclude all sync routes until REST pages appear.
  2. Include only the guide-backed sync routes and mark them as drifted.
  3. Include every SDK/Unity-confirmed sync route.
- Recommended option: **Option 2.** Include only the guide-backed routes first, with explicit drift notes and source-quality labeling.

**4. Do Apple and Google sync belong in the same first sync slice?**
- Plain-English: Apple and Google are real enough in SDK/Unity, but they are the least cleanly documented members of the family in the local corpus.
- Why it matters technically: they would force the repo to lean on lower-priority sources and present a less certain contract.
- Options:
  1. Include Apple + Google with the other sync routes now.
  2. Defer Apple + Google until stronger official docs are present or a product need forces them in.
- Recommended option: **Option 2.** Defer Apple and Google from the first sync slice.

**5. For PSN sync, which request field names are the truth we expose?**
- Plain-English: the guide and the Unity-generated request object disagree on field names.
- Why it matters technically: if we pick the wrong field names, the wrapper either becomes dishonest or silently diverges from the docs-first contract.
- Options:
  1. Expose only guide names: `psn_token`, `psn_env`, `psn_service_label`.
  2. Expose Unity names only: `auth_code`, `env`, `service_label`.
  3. Expose guide names as canonical and optionally accept Unity aliases internally later if ever needed.
- Recommended option: **Option 3**, with current implementation starting docs-first on the guide names only unless Derrick explicitly wants alias support.

**6. How should monetization S2S caller model be represented in this repo?**
- Plain-English: Derrick already locked that documented S2S endpoints belong here, but we still need to choose how explicit the API is about them being server-side/service-token calls.
- Why it matters technically: auth headers, helper naming, config shape, test fixtures, and misuse prevention all depend on this.
- Options:
  1. Put them in the same adapter with explicit service-token/server-side request builders and clearly separate caller-model docs.
  2. Split them into a separate sub-surface/module inside the repo.
  3. Reuse ordinary bearer-user request helpers and document the difference informally.
- Recommended option: **Option 1.** Same repo, but explicit service-token/server-side surface so the API stays honest.

**7. What exact S2S subset should ship first once S2S is approved?**
- Plain-English: the S2S family includes both write flows and reconciliation/history reads.
- Why it matters technically: the smallest coherent slice could be writes only, but history reads are also clean REST-backed and useful for audit/recovery.
- Options:
  1. `intent + commit` only.
  2. `intent + commit + clawback` only.
  3. All five documented monetization S2S endpoints together.
- Recommended option: **Option 3.** All five together. They are the cleanest fully REST-backed family in this plan and share the same caller model.

**8. How will `monetization-team-id` be supplied for the history endpoints?**
- Plain-English: the history reads are documented, but they need a monetization team id that is not implied by the game id.
- Why it matters technically: without a config decision, the history endpoints cannot be wrapped cleanly.
- Options:
  1. Add explicit config for `monetization_team_id` and require it for those requests.
  2. Defer history endpoints until the ID sourcing story exists.
  3. Try to infer it elsewhere.
- Recommended option: **Option 1.** Make it explicit config.

#### What is cleanly implementable immediately vs should still be deferred?

**Cleanly implementable immediately once Derrick answers the above scope questions**
- `POST /s2s/transactions/intent`
- `POST /s2s/transactions/commit`
- `POST /s2s/transactions/clawback`
- `GET /s2s/monetization-teams/{monetization-team-id}/transactions`
- `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`
- `POST /games/{game-id}/mods/{mod-id}/checkout` **if** Derrick narrows the first supported checkout mode set (recommended: `type=0` only first)
- Guide-backed sync routes **if** Derrick explicitly approves drifted non-REST-page-backed coverage:
  - `POST /me/iap/xboxlive/sync`
  - `POST /me/iap/psn/sync`
  - `POST /me/iap/steam/sync`
  - `POST /me/iap/meta/sync`
  - `POST /me/iap/epicgames/sync`

**Still recommended to defer**
- `POST /me/iap/apple/sync`
- `POST /me/iap/google/sync`
- checkout unified modes `type=2`, `type=3`, `type=4` until there is an explicit product need
- partner-program / partner-team work

#### Recommended next implementation subset

If Derrick wants the cleanest next coder slice after this audit, the strongest recommendation is:

1. **Implement the full five-endpoint monetization S2S family first** with explicit server-side caller modeling.
2. Then either:
   - **checkout `type=0` only**, or
   - the **five guide-backed sync routes** if the product priority is platform-store entitlement conversion.
3. Keep Apple/Google sync and broader checkout mode breadth deferred until explicitly chosen.

Updated findings align with `REF-05` and extend the earlier follow-up note in `REF-11`: checkout is REST-clean but internally multi-mode; `/me/iap/*/sync` is real but drifted; monetization `/s2s/*` is the cleanest next truthful family if we keep caller model explicit.

---

### Task 2: Implement the next approved checkout/sync/S2S subset

**Bead ID:** `oc-a04`
**SubAgent:** `primary`
**Role:** `coder`
**References:** `REF-01` through `REF-11`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved checkout/S2S mod.io subset exactly as defined by the research and Derrick’s decision lock-in. For this slice, implement the REST-backed `POST /games/{game-id}/mods/{mod-id}/checkout` surface across all documented checkout modes `0..4`, plus the full five documented monetization `/s2s/*` endpoints. Preserve exact request/path/header/body semantics from the strongest available official REST sources, keep the wrapper thin, document any corpus drift explicitly, extend tests/fixtures/docs, update the plan with exact results and any deliberate deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-checkout-sync-and-s2s.md`

**Status:** ⏳ Pending → 🚧 In Progress → ✅ Complete

**Results:** Implemented the approved REST-backed checkout + S2S subset in `src/modio_vendor_adapter.gd` and `src/models/modio_client_config.gd`:
- added `build_checkout_request(...)` for `POST /games/{game-id}/mods/{mod-id}/checkout` with docs-first validation across all documented modes `0..4`
- added server-side/service-token request builders for:
  - `POST /s2s/transactions/intent`
  - `POST /s2s/transactions/commit`
  - `POST /s2s/transactions/clawback`
  - `GET /s2s/monetization-teams/{monetization-team-id}/transactions`
  - `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`
- added distinct `service_token` and `monetization_team_id` config surfaces so S2S callers do not flow through the ordinary bearer-user helpers
- added response normalizers for checkout, S2S pay/commit/clawback responses, and S2S history/detail payloads
- added fixtures/tests covering request shapes, validation failures, service-token separation, and documented drift handling:
  - `.testbed/tests/test_modio_vendor_adapter.gd`
  - `.testbed/tests/fixtures/checkout_success.json`
  - `.testbed/tests/fixtures/s2s_pay_success.json`
  - `.testbed/tests/fixtures/s2s_refund_success.json`
  - `.testbed/tests/fixtures/s2s_transactions.json`
  - `.testbed/tests/fixtures/s2s_transaction.json`
- updated `README.md` and `docs/modio-seam-plan.md` so the seam description is honest about the newly added checkout/S2S coverage, the current direct-checkout policy stance (non-store / web / PC-only), and the remaining deliberate deferrals
- validation evidence:
  - `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` → `35/35 passed`, `57` tests total
  - `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` → `Scaffold validation passed`
- documented corpus drift handled explicitly instead of guessed over:
  - refreshed GET S2S history pages model filters under a request-body schema even though the transport shape is query-string based; this seam serializes them as query parameters
  - refreshed S2S list page labels the pagination envelope as `download`; this seam preserves that payload and also aliases it as `pagination`
  - refreshed clawback page types `gateway_uuid` as an integer while describing it as an alpha-dash identifier; this seam treats it as a string and records the drift
- deliberate deferrals preserved for this slice: drifted `/me/iap/*/sync` routes and partner-team / partner-program work remain excluded pending a cleaner docs-first REST contract

---

### Task 3: QA the checkout/sync/S2S subset

**Bead ID:** `oc-yya`
**SubAgent:** `primary`
**Role:** `qa`
**References:** `REF-01` through `REF-11`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest checkout/sync/S2S implementation against the strongest available official corpus. Confirm request shapes, transport behavior, fixtures, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-checkout-sync-and-s2s.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the checkout/sync/S2S subset

**Bead ID:** `oc-ehy`
**SubAgent:** `primary`
**Role:** `auditor`
**References:** `REF-01` through `REF-11`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest checkout/sync/S2S implementation against the strongest available official corpus and the repo seam plan. Confirm the added coverage is accurate, caller-model-honest, still isolated as a vendor adapter seam, and clearly documents any deferred or drifted surfaces. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-checkout-sync-and-s2s.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⏳ Pending

**What We Built:** Pending.

**Reference Check:** Pending.

**Commits:**
- Pending.

**Lessons Learned:** Pending.

---

*Completed on 2026-05-04*
