# AeroBeat Vendor Mod.io User and Social Surface Coverage

**Date:** 2026-05-03  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue the push toward 100 percent mod.io REST coverage by implementing the next coherent vendor-local batch after collections: user/profile and adjacent social/account-state surfaces that fit cleanly inside `aerobeat-vendor-modio` without dragging in product-policy or install-orchestration responsibilities.

---

## Overview

The repo now has a truth-locked base across auth/session, mod browse/detail/files/stats, subscriptions, ratings/reporting, dependencies, mod comments, guides, guide comments, and the new collection slice. That gives us enough foundation to keep expanding horizontally across the official REST corpus while preserving a strict vendor-adapter boundary.

A likely next uncovered family is **user/profile and social/account-state surfaces**: provider-native user lookups, follower/following reads, user collections, muted-user/account-adjacent reads, and similar social/profile endpoints that are first-class in the docs but still belong inside the provider seam rather than AeroBeat gameplay/UI contracts. The risk is that some of these endpoints sit next to moderation, write-side social mutation, or other account-state behaviors that may deserve a separate policy decision. So the first task is to research the family carefully and define the safe next batch before we implement anything.

As usual, the slice should use the refreshed official local corpus first, then pass through coder → QA → audit automatically unless ambiguity or a human-decision boundary appears.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current collection slice plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md` |
| `REF-02` | Current doc-truth audit plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-doc-truth-and-repo-audit.md` |
| `REF-03` | Current research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-04` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-05` | Corpus completeness note | `docs/modio-rest-corpus-completeness-2026-05-03.md` |
| `REF-06` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-07` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-08` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-09` | Current implementation | `src/` |
| `REF-10` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the next coherent user/social batch

**Bead ID:** `oc-2zh`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapped surface plus the refreshed official local mod.io corpus to define the next coherent user/profile/social/account-state endpoint batch after collections. Produce an execution-ready recommendation that explicitly separates safe vendor-local read/profile/social surfaces from moderation, write-side social mutation, or other edges that should stay out of scope for this repo right now. Update the plan with what actually happened and close the bead with a concrete target list.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if notes need updating

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-user-and-social-surface-coverage.md`
- optional research note(s) if needed

**Status:** ✅ Complete

**Results:** Reviewed `REF-01` through `REF-10` against the refreshed local official corpus. Recommended the next coherent batch as **read-only user/profile/social/account-state coverage** centered on paged user lists and collection lists that reuse existing adapter primitives without introducing policy-heavy mutation behavior. Add now: `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, and `GET /me/following/collections` (docs in `REF-06`; Unity generated refs in `REF-08`). Query shaping should stay intentionally narrow: pagination only (`_limit`, `_offset`) plus public-vs-auth header handling; do **not** expose generic search/sort filters here because the local Unity-generated endpoint filters for these routes only inherit page index/page size. Reuse `_normalize_user_object`, `_normalize_collection_object`, and `_normalize_list_payload`; add only thin endpoint-specific request/response wrappers and fixtures/tests covering public follower/following reads, authenticated muted/follower/collection reads, and auth enforcement. Keep out of scope for this slice: write-side social mutation (`mute`, `unmute`, follow/unfollow), moderation/reporting edges, user-owned mods/files/purchases/subscriptions/wallet/entitlement surfaces, and any undocumented `/me/following` style expansion not present in the local docs mirror. No repo-local implementation was performed in this research task.

---

### Task 2: Implement the agreed user/social batch

**Bead ID:** `oc-rtr`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched next user/profile/social/account-state mod.io coverage slice using the refreshed official local corpus as source of truth. Expand request builders, endpoint-aware query shaping, normalization helpers, fixtures, tests, and seam docs while keeping vendor concerns local to this repo. Update the plan with what actually happened, run repo-local validation, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-user-and-social-surface-coverage.md`

**Status:** ✅ Complete

**Results:** Implemented the researched read-only user/profile/social/account-state batch against `REF-06`, `REF-07`, and `REF-08` while keeping the scope exactly on the approved seven endpoints and preserving vendor-local boundaries. Added thin request builders in `src/modio_vendor_adapter.gd` for `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, and `GET /me/following/collections`, plus matching normalization wrappers that intentionally reuse the existing `_normalize_user_object`, `_normalize_collection_object`, and shared `_normalize_list_payload` primitives instead of inventing new DTO seams.

Query shaping was kept intentionally narrow per the doc-truth recommendation: `src/models/modio_listing_query.gd` now exposes dedicated pagination-only endpoint gates for this slice so these seven routes serialize only `_limit` and `_offset`, even if callers populate unrelated shared filter fields. No write-side social mutation, moderation/reporting expansion, broader account inventory/workflow surfaces, or undocumented `/me/following` read was added.

Fixture/test/doc coverage was updated with the minimum truthful additions: a new `user_social_users.json` fixture, request-builder assertions in `.testbed/tests/test_modio_vendor_adapter.gd`, executed-URL assertions in `.testbed/tests/test_modio_http_transport.gd`, and README/seam-plan updates describing the new surface plus the pagination-only stance for these routes.

Validation evidence:
- Command: `/home/derrick/.local/bin/godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Result: `33/33` tests passed, `985` asserts, exit code `0`
- Notes: `3` pre-existing float/int comparison warnings remained; no new failures.

---

### Task 3: QA the user/social batch

**Bead ID:** `oc-8em`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the newly added user/profile/social/account-state surface against the refreshed official local mod.io corpus, not model memory. Confirm request shapes, normalization, fixtures, and tests match the docs and that vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-user-and-social-surface-coverage.md`

**Status:** ✅ Complete

**Results:** Independently re-verified the seven added routes against the refreshed local official corpus, primarily `REF-06` (mod.io docs) and `REF-08` (generated Unity endpoints), with spot checks against `REF-07`. Paths, normalization reuse, pagination-only query shaping, README/seam-plan truthfulness, and vendor-local boundaries all held. One seam drift was found in the three `/users/{user-id}/followers|following|collections` builders: they were hard-coded as API-key-only reads, while the research note for this task called for public-vs-auth header handling and the Unity-generated corpus marks the follower/following variants as authenticated reads. Fixed those builders to use bearer headers when a token is present while preserving GET-time API-key fallback for public callers, which keeps the wrapper truthful to both the docs-visible public paths and the authenticated Unity usage. Updated request-builder + transport tests accordingly and reran repo-local validation.

Validation evidence:
- Command: `/home/derrick/.local/bin/godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Result: `33/33` tests passed, `1007` asserts, exit code `0`
- Notes: the same `3` pre-existing float/int comparison warnings remained; no new warnings/failures were introduced.

---

### Task 4: Audit the user/social batch

**Bead ID:** `oc-68f`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the newly added user/profile/social/account-state surface against the refreshed official local mod.io corpus. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and materially advances the repo toward fuller mod.io coverage. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-user-and-social-surface-coverage.md`

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
