# AeroBeat Vendor Mod.io IAP Sync Drift Resolution

**Date:** 2026-05-04  
**Status:** Stale  
**Agent:** Chip 🐱‍💻

---

## Goal

Resolve the remaining `/me/iap/*/sync` drift clearly enough to decide whether any sync endpoints can be wrapped truthfully in `aerobeat-vendor-modio`, and if so, in what exact documented-or-source-qualified form.

---

## Overview

The clean REST-backed monetization slices are now in good shape: wallets, purchased, entitlements, checkout, and documented monetization S2S all landed through coder → QA → audit. The biggest remaining monetization-family gap is the IAP sync set, where the routes appear real in official guides, SDKs, and Unity references, but are not cleanly mirrored as normal REST endpoint pages in the local `modio-docs` endpoint corpus.

That means this is no longer a normal “just implement the documented REST pages” slice. It is a drift-resolution slice. Before coder work starts, we need to pin down exactly which sync routes are evidenced by which official sources, where field-name or request-shape drift exists, what confidence level each route deserves, and whether Derrick wants any of them wrapped before mod.io confirms them more cleanly in the REST reference.

The default posture is still the same: don’t guess, don’t blur source quality, and don’t claim REST-page parity where it does not exist. If we proceed, the wrapper and docs must make the drift explicit.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Completed monetization reads slice | `.plans/2026-05-04-aerobeat-vendor-modio-monetization-entitlements-and-s2s.md` |
| `REF-02` | Completed checkout + S2S slice | `.plans/2026-05-04-aerobeat-vendor-modio-checkout-sync-and-s2s.md` |
| `REF-03` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-04` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-05` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-06` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-07` | Monetization follow-up note | `docs/modio-monetization-follow-up-2026-05-04.md` |
| `REF-08` | Current implementation | `src/` |
| `REF-09` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research and classify the IAP sync drift

**Bead ID:** `oc-0rb`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform a focused drift-resolution audit for `/me/iap/*/sync` surfaces. Classify each route by official source quality (REST-page-backed, guide-backed, SDK-backed, Unity-backed), enumerate field-name or request-shape drift, identify what can and cannot be wrapped truthfully right now, and turn all remaining pre-slice choices into a simple Derrick decision memo. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise sync-specific note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-iap-sync-drift-resolution.md`
- `docs/modio-monetization-follow-up-2026-05-04.md`

**Status:** ✅ Complete

**Results:** Focused local-corpus audit completed against `REF-04` through `REF-07`.

**Exact candidate routes found**
- No `/me/iap/*/sync` route is currently **REST-page-backed** in `modio-docs/public/en-us/restapi/docs/*.api.mdx`.
- The local official corpus nevertheless evidences these seven candidate routes:
  - `POST /me/iap/apple/sync`
  - `POST /me/iap/epicgames/sync`
  - `POST /me/iap/google/sync`
  - `POST /me/iap/meta/sync`
  - `POST /me/iap/psn/sync`
  - `POST /me/iap/steam/sync`
  - `POST /me/iap/xboxlive/sync`

**Route-by-route source quality + best-known request shape**

| Route | Source quality in local official corpus | Best-known request shape | Real drift / caveats | Truthful wrapper status today |
| --- | --- | --- | --- | --- |
| `POST /me/iap/xboxlive/sync` | guide-backed, SDK-backed, Unity-backed; **not** REST-page-backed | Bearer auth; `application/x-www-form-urlencoded`; body `xbox_token` | Guide adds a real transport caveat: URL-encode the token to avoid `422` | Safe only under an explicit non-REST exception policy; not safe to claim docs-first REST parity |
| `POST /me/iap/psn/sync` | guide-backed, SDK-backed, Unity-backed; **not** REST-page-backed | Guide: bearer auth + platform targeting header, body `psn_token`, optional `psn_env`, `psn_service_label`; SDK/Unity: body `auth_code`, optional `env`, `service_label` | Highest field drift in the set. Guide and code disagree on field names. SDK validator accepts either `psn_token` or `auth_code`, but request emission serializes `auth_code`. Guide also says PS4/PS5 targeting should be done via platform header, defaulting to PS5 if omitted. | Should stay deferred unless Derrick explicitly chooses a source-priority/aliasing policy |
| `POST /me/iap/steam/sync` | guide-backed, SDK-backed, Unity-backed; **not** REST-page-backed | Bearer auth; empty body; POST transport only | No material body-field drift found | Best candidate for a future non-REST pilot, but still not REST-page-backed |
| `POST /me/iap/meta/sync` | guide-backed, SDK-backed, Unity-backed; **not** REST-page-backed | Guide: form body `meta_device`, `meta_user_id`; SDK: form body `device`, `user_id`; Unity: POST with `device` + `user_id` sent as query parameters | Meaningful body-shape drift across guide vs SDK vs Unity | Should stay deferred unless Derrick explicitly accepts code-over-guide drift |
| `POST /me/iap/epicgames/sync` | guide-backed, SDK-route-backed, Unity-backed; **not** REST-page-backed | Bearer auth; `application/x-www-form-urlencoded`; body `epicgames_token`, `epicgames_sandbox_id` | Guide and Unity request object agree on field names, but the C++ SDK only exposes a route constant; the public monetization switch currently treats Epic as unsupported. Unity endpoint docstring is accidentally PSN-copied noise. | Possible only under a guide+Unity exception policy; not a clean docs+SDK parity candidate |
| `POST /me/iap/google/sync` | SDK-backed, Unity-backed; **not** guide-backed and not REST-page-backed | Bearer auth; `application/x-www-form-urlencoded`; body `receipt` | No local guide page found. Evidence is code-first only. | Possible only under an SDK/Unity exception policy |
| `POST /me/iap/apple/sync` | SDK-route-backed, Unity-backed; **not** guide-backed and not REST-page-backed | Bearer auth; `application/x-www-form-urlencoded`; body `receipt` | Weakest official-code shape among the “real” routes: Unity actively uses it, but the C++ SDK only defines the route constant and the public monetization switch treats Apple as unsupported. | Should stay deferred unless Derrick explicitly accepts Unity-led evidence |

**Real policy choices Derrick would need to make before any implementation slice**
1. **REST-only default:** keep all seven routes out of scope until mod.io ships matching REST endpoint pages. This is the current best fit for “no guessing.”
2. **Conservative non-REST exception:** allow only routes with no meaningful shape drift and strong multi-source evidence. In practice that means `steam` first, with `xboxlive` as the next-strongest option.
3. **Broader code-backed exception:** also allow code-first routes like `google`, or guide+Unity routes like `epicgames`, while documenting that they are not REST-page-backed.
4. **Alias/normalization policy decision for drifted routes:** decide whether the wrapper may intentionally accept multiple field spellings / transport variants for `psn` and `meta`, or whether it must choose one exact upstream interpretation and reject the rest.

**Recommendation**
- Default recommendation remains **wrap none right now** under Derrick’s current REST-only posture.
- If Derrick wants a deliberately non-REST pilot anyway, the best next subset is:
  1. `POST /me/iap/steam/sync`
  2. `POST /me/iap/xboxlive/sync`
- Keep `psn`, `meta`, `apple`, `google`, and `epicgames` out of the first pilot because each still needs an explicit evidence-policy choice beyond “docs-first REST parity.”

---

### Task 2: Implement the next approved sync subset

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the next approved `/me/iap/*/sync` subset exactly as defined by the research and Derrick’s decision lock-in. Keep source quality explicit, preserve exact request/path/header/body semantics from the strongest official source available for each included route, document drift honestly, extend tests/fixtures/docs, update the plan with exact results and deliberate deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-iap-sync-drift-resolution.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: QA the approved sync subset

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest sync implementation against the strongest official source available for each included route. Confirm request shapes, transport behavior, docs, and drift disclosures are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-iap-sync-drift-resolution.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the approved sync subset

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest sync implementation against the strongest official source available for each included route and the repo seam plan. Confirm the added coverage is accurate, source-quality-honest, and clearly scoped. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-iap-sync-drift-resolution.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Drift-blocked / Deferred

**What We Built:** Completed the drift-resolution audit for `/me/iap/*/sync` and classified the entire family by source quality, request-shape drift, and wrapper readiness. No sync endpoint implementation was started because none of the seven routes are cleanly REST-page-backed in the local corpus.

**Reference Check:** Verified against the local docs mirror, official monetization guide content, SDK request definitions, and Unity-generated endpoints; the family remains blocked specifically by missing REST-page parity rather than missing repo work.

**Commits:**
- None. Research/plan/docs update only.

**Lessons Learned:** The sync family looks real in practice, but until mod.io clarifies the REST contract for non-Unity clients, it should be treated as a research/escalation frontier instead of normal wrapper coverage.

---

*Completed on 2026-05-04*
