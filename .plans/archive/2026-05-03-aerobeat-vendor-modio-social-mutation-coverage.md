# AeroBeat Vendor Mod.io Social Mutation Coverage

**Date:** 2026-05-03  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue the push toward 100 percent mod.io REST coverage by implementing the lowest-decision deferred family next: write-side social mutation surfaces, while keeping the repo in thin-plus-provider-local-helper mode and avoiding AeroBeat product-policy leakage.

---

## Overview

We finished the clean vendor-local read/auth/community families and the final gap audit showed the remaining uncovered surfaces are deferred by boundary choice rather than accidental omission. Derrick still wants literal 100 percent API coverage, so the remaining work now needs to be ordered by lowest decision pressure first and escalated only when a slice genuinely needs a human call.

The next best batch is social mutation. These endpoints are still state-changing, but they are far less infrastructural than uploads, platform management, collection-subscribe install behavior, or monetization/S2S. They are good candidates for the agreed implementation mode: thin wrappers plus small provider-local helpers where the official docs make request/response handling awkward, but no AeroBeat product semantics.

This plan starts with a research pass because even “simple” mutation endpoints can differ in auth requirements, body shape, or response semantics, and we want those decisions resolved before coder work starts. If the docs expose a natural split between user-social mutation and collection-social mutation, the research task should surface that before implementation.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Umbrella remaining-coverage + final-audit plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-02` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-03` | Current README scope | `README.md` |
| `REF-04` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-05` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-06` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-07` | Current implementation | `src/` |
| `REF-08` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the social mutation slice

**Bead ID:** `oc-v16`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the refreshed local official mod.io corpus and define the next coherent social-mutation batch for this repo. Confirm exact documented routes, methods, auth requirements, body/query rules, response semantics, and any provider-local helper needs. Explicitly call out whether user follow/unfollow, mute/unmute, and collection follow/unfollow belong in one batch or should be split. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-social-mutation-coverage.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Reviewed `REF-04` through `REF-06` first, then checked the current seam in `REF-02`, `REF-03`, and `REF-07`/`REF-08`. Recommended the next coherent implementation batch as one combined **social-mutation write slice** covering all six low-decision account/community mutations: `POST /users/{user-id}/following`, `DELETE /users/{user-id}/following/{target-user-id}`, `POST /users/{user-id}/mute`, `DELETE /users/{user-id}/mute`, `POST /games/{game-id}/collections/{collection-id}/followers`, and `DELETE /games/{game-id}/collections/{collection-id}/followers`.

Exact findings:
- **User follow**
  - Route/method: `POST /users/{user-id}/following`
  - Auth: authenticated user required (`RequireUserIsAuthenticated` in `modio-sdk`; `RequireAuthentication()` in `modio-unity`)
  - Body/query: form-encoded body with required `user_id`; no query params documented
  - Response: `204 No Content`
  - Notable documented errors: `11134` already followed, `11130` banned user, `11131` deleted user, `17000` not found
- **User unfollow**
  - Route/method: `DELETE /users/{user-id}/following/{target-user-id}`
  - Auth: authenticated user required
  - Body/query: no body, no query params documented
  - Response: `204 No Content`
  - Notable documented errors: `15005` target not currently followed
- **Mute user**
  - Route/method: `POST /users/{user-id}/mute`
  - Auth: authenticated user required
  - Body/query: no body, no query params documented
  - Response: `204 No Content`
  - Notable documented errors: `17039` cannot mute self, `17000` user not found
- **Unmute user**
  - Route/method: `DELETE /users/{user-id}/mute`
  - Auth: authenticated user required
  - Body/query: no body, no query params documented
  - Response: `204 No Content`
  - Notable documented errors: `17000` user not found
- **Follow collection**
  - Route/method: `POST /games/{game-id}/collections/{collection-id}/followers`
  - Auth: authenticated user required
  - Body/query: no body, no query params documented
  - Response: returns a `Mod Collection Object`; `201 Created` when newly followed and `200 OK` when already followed
- **Unfollow collection**
  - Route/method: `DELETE /games/{game-id}/collections/{collection-id}/followers`
  - Auth: authenticated user required
  - Body/query: no body, no query params documented
  - Response: `204 No Content`

Provider-local helper needs for implementation:
- Reuse bearer-auth form request construction already used by subscription/report writes.
- Add one small collection-follow write normalizer parallel to `normalize_subscription_write_response(...)` so the seam can preserve `already_followed := (status_code == 200)`, `location`, and normalized collection data from the returned `Mod Collection Object`.
- Reuse the existing 204/no-body normalization pattern already used by `normalize_comment_delete_response(...)` for unfollow/mute/unmute/unfollow-collection, or factor a tiny generic no-content write helper if the coder wants to remove duplication.
- User follow needs one tiny provider-local request helper/body builder because the official contract redundantly requires `user_id` in the form body while also embedding the acting user in the path. No AeroBeat decision is needed; this is a pure provider quirk.

Batching recommendation:
- Keep **user follow/unfollow + mute/unmute + collection follow/unfollow in one batch**. They are all low-decision authenticated social/account-state writes, all fit the existing thin vendor seam, and the only asymmetry is collection-follow returning an object on `200/201` instead of `204`. That asymmetry is small enough to handle with one additional helper instead of splitting the slice.
- If someone wants the absolute smallest first PR, the only reasonable split is `user-social writes` first and `collection follow/unfollow` second, but that is not required by the docs or by seam complexity.

Derrick decisions needed before implementation:
- **None.** The official corpus is specific enough to implement this slice without a product-policy call, as long as collection subscribe/unsubscribe remains deferred separately because that surface pulls install/orchestration behavior into scope.

---

### Task 2: Implement the agreed social mutation slice

**Bead ID:** `oc-62e`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched social-mutation slice using the refreshed local official corpus as source of truth. Keep the seam thin-plus-provider-local-helper only where needed, stay vendor-local, update fixtures/tests/docs/plan, run repo-local validation, commit and push by default, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `docs/modio-seam-plan.md`
- `README.md`
- `.plans/2026-05-03-aerobeat-vendor-modio-social-mutation-coverage.md`

**Status:** ✅ Complete

**Results:** Implemented the combined social-mutation write slice exactly as researched from `REF-04` through `REF-06`, staying vendor-local and leaving collection subscribe/unsubscribe deferred. Added bearer-only request builders for `POST /users/{user-id}/following`, `DELETE /users/{user-id}/following/{target-user-id}`, `POST /users/{user-id}/mute`, `DELETE /users/{user-id}/mute`, `POST /games/{game-id}/collections/{collection-id}/followers`, and `DELETE /games/{game-id}/collections/{collection-id}/followers`. Added the minimum follow-user body helper for the required redundant `user_id` form field, reused a shared no-content write normalizer for the 204 routes, and added a collection-follow write normalizer that preserves `already_followed := (status_code == 200)`, `location`, and normalized collection data. Updated repo docs/tests/plan and ran repo-local validation successfully before commit/push.

---

### Task 3: QA the social mutation slice

**Bead ID:** `oc-b7r`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the social-mutation slice against the refreshed local official corpus. Confirm request shapes, auth mode, response handling, tests, and seam docs are truthful and that vendor-local boundaries remain intact. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-social-mutation-coverage.md`

**Status:** ✅ Complete

**Results:** Independent QA truth-check passed against the refreshed local official corpus in `REF-04` through `REF-06` and the repo implementation/tests/docs in `REF-02`, `REF-03`, `REF-07`, and `REF-08`. Verified all six write routes exactly:
- `POST /users/{user-id}/following` stays bearer-authenticated, uses form encoding, and includes the required redundant body field `user_id` for the target user.
- `DELETE /users/{user-id}/following/{target-user-id}` stays bearer-authenticated and bodyless, with `204 No Content` normalization reused through the shared no-content write helper.
- `POST /users/{user-id}/mute` and `DELETE /users/{user-id}/mute` stay bearer-authenticated, bodyless, and normalize through the same shared `204` helper.
- `POST /games/{game-id}/collections/{collection-id}/followers` stays bearer-authenticated, bodyless, preserves the returned normalized collection object, exposes `already_followed := (status_code == 200)`, and forwards any `Location` header.
- `DELETE /games/{game-id}/collections/{collection-id}/followers` stays bearer-authenticated, bodyless, and normalizes as `204 No Content`.

Also re-verified that README + seam docs are truthful about the social-mutation slice and that the vendor boundary is still intact: collection subscribe/unsubscribe remains deferred and unimplemented in this repo despite existing in the upstream SDK/Unity corpus. Repo-local validation passed unchanged via `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (44/44 tests passed, 1396 asserts). No implementation drift was found, so no code changes were required beyond recording QA findings in this plan.

---

### Task 4: Audit the social mutation slice

**Bead ID:** `oc-qvl`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the social-mutation slice against the refreshed local official corpus. Confirm the added coverage is accurate, docs are truthful, and the seam still avoids AeroBeat product-policy leakage. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-social-mutation-coverage.md`

**Status:** ✅ Complete

**Results:** Auditor truth-check passed against the refreshed local official corpus (`modio-docs`, `modio-sdk`, `modio-unity`) with no residual drift found in the social-mutation slice. Confirmed all 6 write routes match the corpus for path/method/auth mode: `POST /users/{user-id}/following`, `DELETE /users/{user-id}/following/{target-user-id}`, `POST /users/{user-id}/mute`, `DELETE /users/{user-id}/mute`, `POST /games/{game-id}/collections/{collection-id}/followers`, and `DELETE /games/{game-id}/collections/{collection-id}/followers` all stay form-encoded and bearer-authenticated. Confirmed follow-user preserves the documented redundant `user_id` body field for the target user. Confirmed the repo reuses a shared `204 No Content` normalization helper for unfollow/mute/unmute + collection unfollow, returning empty `data` without inventing payloads. Confirmed collection-follow truthfully preserves provider semantics by normalizing the returned collection object, surfacing `already_followed := (status == 200)`, and passing through `location`; the refreshed corpus still supports both `200` already-followed/no-op success and `201` created-style success handling. Confirmed README/docs remain truthful about the seam and that collection subscribe/unsubscribe remains explicitly deferred, preserving the vendor-local boundary. Repo-local validation rerun passed: `godot --headless --path .testbed --import`; `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`; `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` → 44/44 tests passed. No code/docs changes were necessary beyond this audit-plan status update.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Coder pass completed the full planned social-mutation vendor slice: bearer-only request builders plus response normalization for user follow/unfollow, mute/unmute, and collection follow/unfollow, with targeted transport/unit coverage and seam-doc updates.

**Reference Check:** Implementation matched `REF-04` through `REF-06` for route/method/auth/body/response truth: follow-user keeps the required form `user_id` field, user unfollow/mute/unmute plus collection unfollow normalize as `204 No Content`, and collection follow preserves `already_followed`, `location`, and normalized collection data across `200/201`.

**Commits:**
- `Add mod.io social mutation write coverage` (coder commit landed on `main`; see git history for exact hash)

**Lessons Learned:** This slice fit the repo cleanly once the asymmetry was treated as two tiny provider-local helpers instead of a broader abstraction: one for the redundant follow-user body, one for collection-follow write normalization.

---

*Completed on 2026-05-03*
