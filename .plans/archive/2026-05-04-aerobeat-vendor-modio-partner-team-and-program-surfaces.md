# AeroBeat Vendor Mod.io Partner Team and Program Surfaces

**Date:** 2026-05-04  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Extend `aerobeat-vendor-modio` into the next confirmed monetization REST surface after the drift-blocked IAP sync family by mapping and then, once clarified, wrapping the remaining partner-team / partner-program / creator-monetization surfaces that are actually backed by the official REST corpus.

---

## Overview

The clean monetization read/query slice is complete, and the documented checkout + monetization S2S slice is complete as well. The `/me/iap/*/sync` family is now explicitly blocked by docs drift: the routes appear real in guides/SDK/Unity, but they are not currently mirrored as normal REST endpoint pages, and Derrick’s standing rule is not to guess around missing REST confirmation.

That leaves the next normal slice as the remaining confirmed monetization REST surfaces, especially the partner-team / creator-monetization endpoints that were intentionally deferred while checkout and S2S were landed. This family still needs a proper pre-slice ambiguity pass because some of the routes are more business/admin-flavored than buyer-side commerce, and we need to confirm exactly which ones are clean vendor-wrapper work versus which ones imply broader partner-program policy or organization-management behavior.

The intended approach stays the same: use the refreshed REST corpus first, isolate only the confirmed routes, identify real pre-slice boundary questions, and then execute coder → QA → audit once Derrick locks the subset.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Completed monetization reads slice | `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md` |
| `REF-02` | Completed checkout + S2S slice | `.plans/2026-05-04-aerobeat-vendor-modio-checkout-sync-and-s2s.md` |
| `REF-03` | IAP sync drift resolution slice | `.plans/2026-05-04-aerobeat-vendor-modio-iap-sync-drift-resolution.md` |
| `REF-04` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-05` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-06` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-07` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-08` | Current implementation | `src/` |
| `REF-09` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research confirmed partner-team / partner-program REST surfaces

**Bead ID:** `oc-ek4`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the remaining monetization wrapper surface against the refreshed local official REST corpus and produce an execution-ready map for the next partner-team / partner-program / creator-monetization family. Identify the exact confirmed REST-backed endpoints, separate clean vendor-wrapper work from broader admin/policy surfaces, and turn any real pre-slice choices into a simple Derrick decision memo. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise audit note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-partner-team-and-program-surfaces.md`
- optional note(s)

**Status:** ✅ Complete

**Results:**
- Compared the remaining monetization/partner wrapper surface in `REF-08` against the refreshed official REST endpoint corpus in `REF-05`, then checked `REF-06` and `REF-07` for confirmation and drift.
- Confirmed that the current vendor repo already wraps the plain mod-team read route `GET /games/{game-id}/mods/{mod-id}/team` (doc: `REF-05/public/en-us/restapi/docs/get-mod-team-members.api.mdx`; implementation evidence: `src/modio_vendor_adapter.gd` plus existing mod-team fixtures/tests).
- Confirmed that the only additional normal REST endpoint pages in the partner-team / creator-monetization family are:
  - `GET /games/{game-id}/mods/{mod-id}/monetization/team`
    - doc: `REF-05/public/en-us/restapi/docs/get-users-in-mod-monetization-team.api.mdx`
    - request: bearer-authenticated `GET`, path ids only, no request body
    - response fields: `id`, `name_id`, `username`, `monetization_status`, `monetization_options`, `split`
    - notable errors: `900023`, `900022`
  - `POST /games/{game-id}/mods/{mod-id}/monetization/team`
    - doc: `REF-05/public/en-us/restapi/docs/create-mod-monetization-team.api.mdx`
    - request: bearer-authenticated `multipart/form-data`
    - body: `users[]` entries with required `id` and `split`
    - response fields: same monetization-team account shape as the GET route
    - notable errors: `900023`, `900003`, `900008`, `900024`, `900025`, `900026`, `900029`
- Confirmed there are **no separate partner-program administration/moderation REST endpoint pages** in the refreshed local REST corpus for application queues, approvals, requirements, org membership, or creator-program policy management. In the official docs, Partner Program appears as:
  - product/admin guidance under `features/monetization/partner-program.md`
  - a capability bit exposed through existing game/user payload fields such as `monetization_options` (`PARTNER_PROGRAM = 4`)
  - related monetization/team identifiers already embedded in existing read objects like `Game Object.monetization_teams[]`
  These are schema/feature-signal surfaces, not new standalone wrapper endpoints.
- Thin-wrapper vs broader-scope split:
  - **Clean thin-wrapper work:** `GET /games/{game-id}/mods/{mod-id}/monetization/team` is a straightforward docs-backed read seam and fits the vendor adapter cleanly if AeroBeat needs creator-split visibility.
  - **Decision-gated admin/policy work:** `POST /games/{game-id}/mods/{mod-id}/monetization/team` is REST-backed, but it changes payout membership/splits and triggers creator-wallet / approval / payment-system policy. It is technically wrappable, but it is not a neutral buyer-commerce seam.
  - **Out of current REST-backed scope:** broader Partner Program workflow/admin surfaces (applications, approvals, requirements tuning, moderation queues, org policy) because the local official REST corpus does not expose standalone endpoint pages for them.
- Derrick decision memo:
  1. **Option A:** implement only `GET /games/{game-id}/mods/{mod-id}/monetization/team` next.
     - Best fit if AeroBeat wants honest vendor coverage without importing payout-admin behavior.
  2. **Option B:** implement both GET and POST monetization-team routes.
     - Valid only if this repo is explicitly allowed to own creator payout split management.
  3. **Option C:** defer the whole family.
     - Best if AeroBeat does not presently need creator-team visibility at all.
  - **Recommendation:** Option A. It is the cleanest confirmed next subset: fully REST-backed, thin, and useful without smuggling partner-program policy/org workflow into the adapter.
- No extra docs note was added: the plan now carries the exact boundary cleanly, and adding a second audit note would duplicate that context more than help it.

---

### Task 2: Implement the next approved partner-team/program subset

**Bead ID:** `oc-ees`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved partner-team/program mod.io subset exactly as defined by the research and Derrick’s decision lock-in. Because these routes are confirmed in the REST API, implement both `GET /games/{game-id}/mods/{mod-id}/monetization/team` and `POST /games/{game-id}/mods/{mod-id}/monetization/team`. Preserve exact request/path/header/body semantics from the refreshed official REST docs, keep the wrapper thin, extend tests/fixtures/docs, update the plan with exact results and deliberate deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `.testbed/tests/fixtures/mod_monetization_team.json`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-04-aerobeat-vendor-modio-partner-team-and-program-surfaces.md`

**Status:** ⏳ Pending → 🚧 In Progress → ✅ Complete

**Results:** Implemented the exact approved REST-backed monetization-team slice:
- `GET /games/{game-id}/mods/{mod-id}/monetization/team`
- `POST /games/{game-id}/mods/{mod-id}/monetization/team`

Exact implementation details:
- added bearer-authenticated request builders `build_mod_monetization_team_request(...)` and `build_create_mod_monetization_team_request(...)`
- kept the read seam thin: normalized only the documented monetization-team account fields `id`, `name_id`, `username`, `monetization_status`, `monetization_options`, and `split`
- kept the write seam thin and docs-first: preserved the REST-page `multipart/form-data` contract while serializing the nested `users` array as indexed keys `users[0][id]`, `users[0][split]`, etc., matching the documented object-array shape without adding workflow helpers
- validated only directly documented/body-contract-safe constraints in the adapter: required `users`, required per-item `id`/`split`, positive user ids, max 5 users, and split-total `100`

Observed corpus drift handled explicitly instead of guessed over:
- refreshed REST docs describe the create route as `multipart/form-data`
- generated Unity code currently sends `application/x-www-form-urlencoded` for the same route, but still expands the nested body into indexed `users[{i}][id]` / `users[{i}][split]` keys
- implementation decision: follow the REST pages for transport/content-type semantics and reuse the indexed-key encoding because it is the only cross-corpus shape that cleanly matches the documented nested request body

Validation evidence:
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`60/60` tests passed; one pre-existing GUT float/int comparison warning remained in the broader suite)

Deliberate deferrals preserved:
- no broader partner-program admin/policy/org workflow helpers
- no payout-policy abstraction above the raw REST contract
- no extra monetization endpoints beyond the two confirmed REST-backed mod monetization-team routes Derrick approved for this slice

---

### Task 3: QA the approved partner-team/program subset

**Bead ID:** `oc-dit`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest partner-team/program implementation against the refreshed official REST corpus. Confirm request shapes, transport behavior, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-partner-team-and-program-surfaces.md`

**Status:** ⏳ Pending → ✅ Complete

**Results:** Independent QA pass completed against `REF-05` first, with `REF-06` and `REF-07` used only to evaluate the known corpus drift.
- Verified the adapter wraps exactly the two approved REST-backed routes and nothing broader:
  - `GET /games/{game-id}/mods/{mod-id}/monetization/team`
  - `POST /games/{game-id}/mods/{mod-id}/monetization/team`
- Confirmed request semantics match the refreshed REST endpoint pages:
  - GET stays bearer-authenticated, path ids only, no request body, and does not leak `api_key` query auth
  - POST stays bearer-authenticated and `multipart/form-data` in the vendor seam, with the documented nested `users[]` request represented as indexed form keys (`users[0][id]`, `users[0][split]`, ...)
- Confirmed GET normalization is truthful to the documented monetization-team account fields only: `id`, `name_id`, `username`, `monetization_status`, `monetization_options`, and `split`
- Re-checked the transport/body drift across corpora:
  - `REF-05` REST page explicitly documents `multipart/form-data`
  - `REF-07` Unity/generated client still uses `application/x-www-form-urlencoded` for this route, but encodes the nested request as indexed keys
  - QA conclusion: the current implementation is the correct docs-first compromise. Keeping REST `multipart/form-data` while preserving indexed nested keys is the narrowest truthful wrapper because it honors the refreshed endpoint page transport contract without inventing a wrapper-local body shape
- Confirmed seam boundaries stayed clean:
  - no partner-program/org admin helpers
  - no payout-policy abstraction
  - no broader creator workflow logic beyond the raw two-route REST seam
- No implementation drift was found, so no code/test/doc fix beyond this QA plan update was required.

Validation evidence:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`60/60` tests passed; one pre-existing GUT float/int comparison warning remains outside this slice)

Files changed during QA:
- `.plans/2026-05-04-aerobeat-vendor-modio-partner-team-and-program-surfaces.md`

Commits:
- none (QA found no code drift to fix)

Auditor focus:
- sanity-check the docs-first decision to keep POST as `multipart/form-data` despite Unity's current `application/x-www-form-urlencoded` drift
- verify the indexed nested key encoding remains the only documented-shape-compatible compromise
- confirm no hidden partner-program workflow helpers were added elsewhere outside the touched adapter/tests/docs slice

---

### Task 4: Audit the approved partner-team/program subset

**Bead ID:** `oc-3kb`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest partner-team/program implementation against the refreshed official REST corpus and the repo seam plan. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and clearly documents anything deferred. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-partner-team-and-program-surfaces.md`

**Status:** ⏳ Pending → ✅ Complete

**Results:** Independent audit completed against `REF-05` first, with `REF-06` and `REF-07` used only to re-check known corpus drift and wrapper-truth boundaries.
- Truth-checked the exact wrapped routes and found the request line/auth semantics accurate to the refreshed REST pages:
  - `GET /games/{game-id}/mods/{mod-id}/monetization/team` stays bearer-authenticated, path ids only, no request body
  - `POST /games/{game-id}/mods/{mod-id}/monetization/team` stays bearer-authenticated and targets the exact documented path/method pair
- Reconfirmed GET normalization is intentionally limited to the documented monetization-team account fields only: `id`, `name_id`, `username`, `monetization_status`, `monetization_options`, and `split`. No extra wallet/user/admin fields leak into the normalized seam.
- Reconfirmed POST body semantics are truthful to the documented nested `users[]` object-array shape:
  - the adapter serializes `users[0][id]`, `users[0][split]`, `users[1][id]`, `users[1][split]`, etc.
  - this matches the generated SDK/Unity indexed-key expansion pattern while still representing the REST page's documented nested objects accurately at transport level
- Reconfirmed the docs-first drift choice is still the correct one:
  - `REF-05` documents `multipart/form-data`
  - `REF-06` / `REF-07` currently drift to `application/x-www-form-urlencoded` for create, but keep indexed nested keys for the `users[]` array
  - audit conclusion: keep the vendor seam on REST-documented `multipart/form-data`, while preserving indexed nested keys as the narrowest truthful encoding of the documented nested body
- Reconfirmed no hidden partner-program/admin workflow helpers leaked into the repo for this slice. The implementation remains a thin two-route vendor wrapper with no org management, payout-policy abstraction, creator-program queue handling, or approval workflow helpers.
- No implementation drift was found, so no code/test/doc fixes beyond this audit plan update were necessary.

Validation evidence:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`60/60` tests passed; one pre-existing GUT float/int comparison warning remains outside this slice)

Files changed during audit:
- `.plans/2026-05-04-aerobeat-vendor-modio-partner-team-and-program-surfaces.md`

Commits:
- none (audit found no implementation drift to fix)

---

## Final Results

**Status:** ✅ Complete

**What We Built:** A thin, docs-first wrapper for the remaining confirmed mod monetization-team REST seam in scope: bearer-authenticated `GET /games/{game-id}/mods/{mod-id}/monetization/team` plus bearer-authenticated `POST /games/{game-id}/mods/{mod-id}/monetization/team`, with response normalization limited to the documented monetization-team member fields and create-body serialization kept truthful to the documented nested `users[]` object array.

**Reference Check:** `REF-05` satisfied for both route definitions, auth model, documented response fields, and the create-route `multipart/form-data` contract. `REF-06` and `REF-07` were rechecked only for drift confirmation: they still support the indexed nested key encoding for `users[]`, but their create-route content-type label drifts from the refreshed REST pages. Final seam behavior intentionally follows `REF-05` for transport semantics while retaining the indexed nested key expansion because it is the narrowest encoding that still matches the documented nested request shape. `REF-04` satisfied: no broader partner-program/org admin helpers or payout-policy logic were added.

**Commits:**
- `743aaaa` - implement mod monetization-team wrapper slice

**Lessons Learned:** For this monetization-team family, the stable cross-corpus truth is the route + auth + nested user/split shape, not the generated-client content-type label. The safest vendor seam is to anchor transport semantics to the refreshed REST endpoint pages and use SDK/Unity only to confirm the concrete indexed form-key encoding needed to represent the documented nested request body without inventing wrapper-local abstractions.

---

*Completed on 2026-05-04*
