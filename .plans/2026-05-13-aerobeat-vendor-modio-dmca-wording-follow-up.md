# AeroBeat Vendor mod.io DMCA Wording Follow-up

**Date:** 2026-05-13  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Update `aerobeat-vendor-modio` docs so they accurately distinguish provider capability from AeroBeat’s current working legal/product assumptions around DMCA, paid workouts, checkout, entitlements, and monetization posture.

---

## Overview

The `aerobeat-docs` audit and wording pass is done. That pass concluded the main remaining adjacent-repo hotspot is `aerobeat-vendor-modio`, especially its `README.md` and `docs/modio-monetization-follow-up-2026-05-04.md`. The problem is not core technical drift in the adapter; it is wording drift. Some sections can read as if direct checkout, purchased-state, entitlement sync, and related monetization seams are already product-approved or legally settled for AeroBeat, when the safer and more truthful posture is: these are provider capabilities and current working integration options, while the final paid-workout / DMCA / safe-harbor posture is still pending firmer provider legal confirmation.

This repo should keep documenting the vendor seam truthfully. It should not pretend the provider cannot do things it can do. But it also should not accidentally imply that AeroBeat has already received final legal clearance to expose every provider capability in the intended way. The right outcome is a wording cleanup that preserves technical truth while becoming more legally humble and product-boundary-aware.

This is a docs-only truth-alignment pass. No runtime/API behavior, tests, or seam ownership should change unless QA finds a wording-coupled problem.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Adjacent-repo recommendation from the completed docs audit | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/.plans/2026-05-13-aerobeat-modio-dmca-doc-audit.md` |
| `REF-02` | Current vendor repo README | `README.md` |
| `REF-03` | Current monetization follow-up note | `docs/modio-monetization-follow-up-2026-05-04.md` |
| `REF-04` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-05` | Current AeroBeat docs wording after DMCA softening | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/v1-ugc-submission-and-review-policy.md` |
| `REF-06` | Current moderation / DMCA wording after DMCA softening | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/gdd/user-content/policing-content.md` |
| `REF-07` | Current account / entitlement wording after DMCA softening | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/account-identity-and-entitlements.md` |

---

## Tasks

### Task 1: Audit the vendor repo wording hotspots and define the exact rewrite posture

**Bead ID:** `oc-uyjs`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the bead on start. Audit `README.md`, `docs/modio-monetization-follow-up-2026-05-04.md`, and any directly adjacent wording needed for coherence. Produce an execution-ready summary of exactly where the repo currently sounds too settled about checkout, entitlements, paid workouts, DMCA, or legal posture. Distinguish what should stay as provider capability truth versus what should be softened into current working assumption or pending legal confirmation. Update the active plan with exact findings and recommended file changes.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-13-aerobeat-vendor-modio-dmca-wording-follow-up.md`
- docs TBD

**Status:** ✅ Complete

**Results:** Task 1 audit complete. Main finding: this repo is already mostly honest about **provider seam breadth**, but a few monetization/legal passages still read more settled than the current AeroBeat posture in `REF-05`, `REF-06`, and `REF-07` allows.

Execution-ready rewrite posture for Task 2:

1. **Provider capability that should stay stated plainly**
   - `README.md` should keep direct, literal statements where it is simply inventorying wrapped provider routes/capabilities: `GET /me/wallets`, `GET /me/purchased`, `POST /me/entitlements`, monetization-team routes, checkout route presence, and related transport/normalization behavior (`REF-02`, `REF-04`).
   - `docs/modio-seam-plan.md` should keep plain docs-first statements about request builders, auth/header rules, validated request fields, route drift, and route deferrals such as `/me/iap/*/sync` (`REF-04`).
   - `docs/modio-monetization-follow-up-2026-05-04.md` can keep plain evidence claims when they are source-backed provider observations, e.g. direct mod.io wallet/checkout docs exist and `/me/iap/*/sync` is present in guide/SDK/Unity evidence even though the mirrored REST corpus is incomplete (`REF-03`).

2. **Wording that should be softened into current working assumption / intended workflow**
   - `README.md` long implementation narrative: the checkout sentence that frames direct mod.io checkout as a **current non-store / web / PC seam** reads too final. Rewrite it as a current working integration assumption for some distribution contexts, not as a locked AeroBeat product/legal conclusion (`REF-02`, `REF-07`).
   - `docs/modio-monetization-follow-up-2026-05-04.md` section **“The intended product shape appears to be both flows, but for different distribution contexts”** is the largest hotspot. Keep the provider observation, but reframe AeroBeat’s usage as the current intended interpretation of the evidence rather than settled product truth (`REF-03`, `REF-07`).
   - `docs/modio-monetization-follow-up-2026-05-04.md` platform practicality conclusions should read as present planning guidance, not permanent policy. Steam and the final bottom-line summary are the most settled-sounding spots; Apple/Google are already closer to the right cautious tone (`REF-03`).
   - `docs/modio-monetization-follow-up-2026-05-04.md` bottom-line wording that mod.io wallet/checkout is **primarily web/self-hosted / non-store-controlled distribution territory** should become “best current reading / safer current assumption” language (`REF-03`, `REF-07`).
   - `docs/modio-seam-plan.md` bullet saying direct mod.io checkout is **explicitly documented as non-store / web / PC-only for now** should be softened the same way. The adapter can preserve the REST contract without sounding like AeroBeat has fully settled the permitted paid-workout checkout surface (`REF-04`, `REF-07`).

3. **Wording that should explicitly mention pending legal/provider confirmation**
   - Any sentence that could be read as “AeroBeat can rely on mod.io paid-workout ownership/checkout as legally settled” should explicitly point back to the unresolved posture in `REF-05`, `REF-06`, and especially `REF-07`: the current provider-backed premium workflow is still pending firmer provider/legal confirmation.
   - `README.md` checkout narrative should add a short qualifier that the adapter exposes the provider route truthfully while AeroBeat’s paid-workout / DMCA / safe-harbor posture remains under confirmation (`REF-02`, `REF-07`).
   - `docs/modio-seam-plan.md` direct-checkout stance bullet should explicitly note that this is not a final legal conclusion and should stay revisitable if provider guidance comes back narrower (`REF-04`, `REF-07`).
   - `docs/modio-monetization-follow-up-2026-05-04.md` recommendation/bottom-line section should explicitly separate: provider capability exists; store-compliant sync is the safer current assumption; final paid-workout/provider legal sufficiency is still pending confirmation (`REF-03`, `REF-07`).

4. **Exact wording hotspots by file**
   - `README.md`
     - The earlier **Important v1 boundary** language is already good and should mostly be preserved.
     - The main hotspot is the **Current implementation scope** narrative sentence that says checkout is a current non-store / web / PC seam; that sentence sounds more settled than the AeroBeat-side docs do.
   - `docs/modio-monetization-follow-up-2026-05-04.md`
     - **Section 2** (“The intended product shape appears to be both flows...”) is the biggest hotspot.
     - **Steam practicality** and the **Bottom line** section are the next most settled-sounding.
     - Apple/Google wording is comparatively safer because it already uses “treat as” / “safer assumption,” but it still needs to remain visibly provisional rather than sounding like final legal doctrine.
   - `docs/modio-seam-plan.md`
     - Seam-boundary language is mostly good.
     - The main hotspot is the **Query/auth stance** bullet that presently states direct checkout is **non-store / web / PC-only for now** as though the product/legal posture is already decided.

5. **Minimum file set and section focus for Task 2**
   - `README.md`
     - Focus only on the **Important v1 boundary** carry-through wording if needed for consistency, plus the **Current implementation scope** narrative paragraph covering checkout / monetization-user coverage.
   - `docs/modio-monetization-follow-up-2026-05-04.md`
     - Focus only on **Section 2 interpretation**, **Platform practicality** conclusion sentences, **Recommendation**, and **Bottom line**.
   - `docs/modio-seam-plan.md`
     - Focus only on the **Query/auth stance** direct-checkout bullet, with a small seam-boundary consistency touch-up only if required.

Cross-reference note for Task 2: when softening paid-workout/checkout wording, mirror the humility already used in `REF-05`, `REF-06`, and `REF-07`—especially the distinction between the **current operational posture** and a **not-yet-settled DMCA / safe-harbor / provider-guidance conclusion**.

---

### Task 2: Apply the wording cleanup in `aerobeat-vendor-modio`

**Bead ID:** `oc-wlt2`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the bead on start. Update the identified wording hotspots so the repo clearly distinguishes provider capability from AeroBeat’s current working legal/product posture. Keep the technical seam truthful. Do not weaken or misstate actual wrapped provider capability; instead, avoid implying final legal/product approval where it is still pending. Run appropriate repo-local docs/validation checks, commit/push by default, and update the plan with exact file changes and results.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-13-aerobeat-vendor-modio-dmca-wording-follow-up.md`
- `README.md`
- `docs/modio-monetization-follow-up-2026-05-04.md`
- adjacent docs only if minimum necessary for coherence

**Status:** ✅ Complete

**Results:** Updated the minimum required wording hotspots in `README.md`, `docs/modio-monetization-follow-up-2026-05-04.md`, and `docs/modio-seam-plan.md` to match the Task 1 posture. Exact outcomes: (1) `README.md` now keeps `POST /games/{game-id}/mods/{mod-id}/checkout` plainly documented as wrapped provider capability while reframing direct checkout as a current working fit for some non-store-controlled contexts rather than a settled AeroBeat product/legal conclusion, and it now explicitly says the paid-workout / DMCA / safe-harbor posture is still pending firmer confirmation (`REF-02`, `REF-07`); (2) `docs/modio-monetization-follow-up-2026-05-04.md` now reframes the “both flows” section as the best current reading of provider evidence, softens Steam/Apple/Google/Meta practical conclusions into present planning guidance, adds a recommendation posture note separating provider capability from AeroBeat product posture, and updates the bottom line to say wallet/checkout is a documented provider capability whose best current fit appears to be non-store-controlled contexts while the paid-workout legal sufficiency question remains open (`REF-03`, `REF-07`); (3) `docs/modio-seam-plan.md` now preserves the checkout REST contract while explicitly describing the AeroBeat-facing stance as a revisitable current assumption rather than a final legal/product ruling (`REF-04`, `REF-07`). Validation: `git diff --check -- README.md docs/modio-monetization-follow-up-2026-05-04.md docs/modio-seam-plan.md .plans/2026-05-13-aerobeat-vendor-modio-dmca-wording-follow-up.md` passed and the docs-only diff was reviewed before commit. A repo-wide `git diff --check` also surfaced a pre-existing trailing-whitespace issue in unrelated file `.plans/2026-05-05-aerobeat-vendor-modio-live-env-and-harness.md`. Commit/push completed on `main`.

---

### Task 3: QA/audit the final vendor wording pass

**Bead ID:** `oc-pfwe`  
**SubAgent:** `primary`  
**Role:** `qa` / `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the bead on start. Independently verify that the updated wording now reflects current provider capability truth without overstating AeroBeat’s paid-workout / DMCA / legal certainty. Confirm coherence with the latest `aerobeat-docs` wording, run any relevant validation, make only minimum necessary fixes, and close only if the final wording is technically honest and legally humble.

**Folders Created/Deleted/Modified:**
- `.plans/`
- touched docs only if minimum necessary fixes are required

**Files Created/Deleted/Modified:**
- `.plans/2026-05-13-aerobeat-vendor-modio-dmca-wording-follow-up.md`
- touched docs only if QA/audit requires fixes

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⏳ Pending

**What We Built:** Pending.

**Reference Check:** Pending.

**Commits:**
- Pending

**Lessons Learned:** Pending.

---

*Drafted on 2026-05-13*
