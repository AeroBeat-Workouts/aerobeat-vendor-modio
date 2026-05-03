# AeroBeat Vendor Mod.io Collection Subscription Coverage

**Date:** 2026-05-03  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue the push toward 100 percent mod.io REST coverage by implementing the dedicated collection subscribe/unsubscribe slice, while keeping the repo in thin-plus-provider-local-helper mode and surfacing any install/orchestration boundary decisions before implementation if the docs require them.

---

## Overview

We completed the low-decision social-mutation batch separately so collection subscribe/unsubscribe could be handled as its own slice. That separation matters because collection subscription is not just another social toggle: it sits closest to install/update/orchestration behavior, bulk mod subscription semantics, and any future AeroBeat interpretation of collection-driven state.

Derrick still wants literal 100 percent API coverage, but the rule is now explicit: ask up front for real decisions when a slice needs them, and otherwise keep executing automatically. This plan therefore starts with a research pass against the refreshed local official corpus to determine whether collection subscribe/unsubscribe can remain a thin vendor wrapper with small provider-local helpers, or whether the docs expose semantics that require a human boundary decision before code starts.

If the docs are sufficiently clear, the preferred implementation mode remains: raw request/response coverage first, plus only the smallest provider-local helpers needed to keep the seam truthful and ergonomic without leaking AeroBeat install policy into the vendor layer.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Social mutation slice plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-social-mutation-coverage.md` |
| `REF-02` | Umbrella remaining-coverage plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-03` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-04` | Current README scope | `README.md` |
| `REF-05` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-06` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-07` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-08` | Current implementation | `src/` |
| `REF-09` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the collection subscription slice

**Bead ID:** `oc-5ra`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the refreshed local official mod.io corpus and define the dedicated collection subscribe/unsubscribe slice. Confirm exact documented routes, methods, auth requirements, body/query rules, response semantics, and whether the docs imply install/orchestration semantics that require a Derrick decision before implementation. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-subscription-coverage.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Reviewed `REF-05` through `REF-07` first, then checked the current seam in `REF-03`, `REF-04`, and `REF-08`/`REF-09`. Recommended a dedicated **collection subscription write slice** covering exactly two authenticated vendor routes: `POST /games/{game-id}/collections/{collection-id}/subscriptions` and `DELETE /games/{game-id}/collections/{collection-id}/subscriptions`.

Exact findings:
- **Subscribe to collection mods**
  - Route/method: `POST /games/{game-id}/collections/{collection-id}/subscriptions`
  - Auth: authenticated user required (`RequireUserIsAuthenticated` in `modio-sdk`; `RequireAuthentication()` in `modio-unity`)
  - Body/query: REST docs show **no request body** and no documented query parameters
  - Response: `200 OK` with a returned `Mod Collection Object`
  - Notable documented errors: generic `400 Bad Request` invalid parameters and `403 Forbidden` when the authenticated user lacks permission to subscribe to the collection
- **Unsubscribe from collection mods**
  - Route/method: `DELETE /games/{game-id}/collections/{collection-id}/subscriptions`
  - Auth: authenticated user required
  - Body/query: REST docs show **no request body** and no documented query parameters
  - Response: `200 OK` with a returned `Mod Collection Object`
  - Notable documented errors: generic `400 Bad Request` invalid parameters and `403 Forbidden` when the authenticated user lacks permission to unsubscribe from the collection

Cross-corpus implementation notes:
- The refreshed REST docs in `REF-05` are explicit that both routes are bodyless and return a `Mod Collection Object` on success.
- The generated Unity endpoints in `REF-07` match the REST docs exactly on path/method/auth and also model no request body.
- The C++ SDK in `REF-06` uses the same routes but adds **SDK-local orchestration semantics** around them:
  - `SubscribeToModCollectionAsync(...)` docs say it **does not automatically trigger installation**; callers should run `FetchExternalUpdatesAsync` after success to initiate install/update work.
  - `UnsubscribeFromModCollectionAsync(...)` docs say local SDK state may mark collection mods for uninstall when no other local users remain subscribed.
  - Internal SDK code also appends an undocumented `include_dependencies` query parameter on subscribe, but that parameter is **not present in the refreshed REST docs or generated Unity endpoint**. Treat this as upstream corpus drift / SDK-local behavior, not part of the documented REST contract for this repo.
- The broader SDK mod-management loop files (`ProcessNextModInUserCollection`, `ProcessNextModInServerCollection`) confirm that subscription state can drive install/update/uninstall orchestration in the full SDK, but those are higher-level plugin/runtime behaviors, not evidence that this vendor adapter should own install policy.

Provider-local helper recommendation for coder:
- Reuse the existing bearer-authenticated write request path used by other authenticated writes.
- Add one small collection-subscription response normalizer parallel to the existing collection-follow normalizer so the seam can preserve `status_code`, `location` if present, and normalized collection data from the returned `Mod Collection Object` for both subscribe and unsubscribe.
- Do **not** invent local install/uninstall orchestration in this repo. If useful, document that higher layers / runtime integrations may need a later sync-orchestration step, but keep this slice as raw REST coverage only.
- Do **not** add an `include_dependencies` input unless Derrick explicitly wants SDK-parity-over-REST behavior; it is not part of the refreshed documented REST surface.

Derrick decisions needed before implementation:
- **None, if we keep the slice as a thin REST wrapper.** The docs do imply downstream install/orchestration semantics in the full SDK/plugin stack, but they do not force this repo to implement that policy. The truthful implementation boundary is: add the two REST routes now, return the normalized collection object, and leave install/update/uninstall orchestration to higher layers or future explicitly scoped work.

---

### Task 2: Implement the agreed collection subscription slice

**Bead ID:** `oc-7yo`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched collection subscribe/unsubscribe slice using the refreshed local official corpus as source of truth. Keep the seam thin-plus-provider-local-helper only where needed, stay vendor-local, update fixtures/tests/docs/plan, run repo-local validation, commit and push by default, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-subscription-coverage.md`

**Status:** ✅ Complete

**Results:** Implemented the dedicated collection subscription write slice from `REF-05` through `REF-07` without widening scope beyond the thin REST seam requested in `REF-01`/`REF-02`. Added bearer-only request builders for `POST /games/{game-id}/collections/{collection-id}/subscriptions` and `DELETE /games/{game-id}/collections/{collection-id}/subscriptions`, plus the smallest provider-local normalization helper needed to return the documented `Mod Collection Object` and preserve any `Location` header without importing SDK-local install/update/uninstall orchestration or undocumented `include_dependencies` behavior. Updated adapter and transport tests to cover request shape, auth mode, empty body behavior, and normalized collection responses using the existing `collection_detail.json` fixture, then refreshed `README.md` and `docs/modio-seam-plan.md` so the documented seam matches the implementation. Validation ran successfully with `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (44/44 tests passing). Commit/push and bead closure follow in this coder handoff.

---

### Task 3: QA the collection subscription slice

**Bead ID:** `oc-5r0`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the collection subscribe/unsubscribe slice against the refreshed local official corpus. Confirm request shapes, auth mode, response handling, tests, and seam docs are truthful and that vendor-local boundaries remain intact. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-subscription-coverage.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the collection subscription slice

**Bead ID:** `oc-3ko`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the collection subscribe/unsubscribe slice against the refreshed local official corpus. Confirm the added coverage is accurate, docs are truthful, and the seam still avoids AeroBeat install-policy leakage beyond the agreed provider-local helper level. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-subscription-coverage.md`

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

*Completed on 2026-05-03*
