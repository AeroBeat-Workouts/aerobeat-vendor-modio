# AeroBeat Vendor Mod.io Comments and Discussion Coverage

**Date:** 2026-05-02  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Expand `aerobeat-vendor-modio` toward fuller mod.io coverage by implementing the next coherent vendor-adapter batch around comments, discussion, and moderation-adjacent user feedback surfaces that belong in this repo.

---

## Overview

The repo already covers a meaningful mod.io surface: auth/session, browse/detail, subscriptions, transport hardening, dependency/cache metadata helpers, and the ratings/report/stats/file-detail batch. The next coherent user-facing API slice that still fits cleanly inside the vendor adapter boundary is comments/discussion/moderation-adjacent surfaces.

This pass should remain grounded in the current official mod.io docs and the pinned local `projects/modio/` references. The goal is to expand wrapper coverage for discussion-related endpoints that are still vendor-local concerns without yet drifting into full creator authoring flows, downloader/install logic, monetization, or AeroBeat moderation-policy orchestration. As usual, the coder, QA, and auditor should all verify the current API shape against official references rather than model memory.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active comments/discussion plan | `.plans/2026-05-02-aerobeat-vendor-modio-comments-and-discussion-coverage.md` |
| `REF-02` | Broader endpoint coverage slice | `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md` |
| `REF-03` | Download/cache slice | `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md` |
| `REF-04` | Live transport slice | `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md` |
| `REF-05` | Current mod.io API research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-06` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-07` | Official local mod.io refs | `/home/derrick/.openclaw/workspace/projects/modio/` |
| `REF-08` | Current implementation/tests | `src/`, `.testbed/tests/` |

---

## Tasks

### Task 1: Research the next coherent comments/discussion endpoint batch

**Bead ID:** `oc-eea`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapped surface plus the current official mod.io docs and pinned local references to define the next coherent endpoint batch around comments, discussion, and moderation-adjacent user feedback. Produce a concrete target list of endpoints, request/response normalization, fixture shapes, and tests. Keep the recommendation constrained to what belongs in a vendor adapter repo and explicitly call out anything that should wait because it would introduce downloader/install/orchestration/AeroBeat policy responsibilities. Update the active plan with what actually happened and close the bead with an execution-ready recommendation.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` (if notes need updating)

**Files Created/Deleted/Modified:**
- `.plans/2026-05-02-aerobeat-vendor-modio-comments-and-discussion-coverage.md`
- optional notes/docs if needed

**Status:** ✅ Complete

**Results:** Reviewed the current wrapped surface in `src/` and `.testbed/tests/`, then re-checked the current official local `modio-docs` mirror first and used `modio-sdk` / `modio-unity` only as secondary sanity references. The next coherent batch should be **threaded mod comments**, because the current official docs do not expose a separate mod discussion endpoint; the discussion surface for mods is the comment thread model (`reply_id` + `thread_position`). The execution-ready target list is:

- **Endpoints to add now**
  - `GET /games/{game-id}/mods/{mod-id}/comments`
  - `GET /games/{game-id}/mods/{mod-id}/comments/{comment-id}`
  - `POST /games/{game-id}/mods/{mod-id}/comments`
  - `PUT /games/{game-id}/mods/{mod-id}/comments/{comment-id}`
  - `DELETE /games/{game-id}/mods/{mod-id}/comments/{comment-id}`
  - `POST /games/{game-id}/mods/{mod-id}/comments/{comment-id}/karma`
- **Request shaping / query serialization**
  - Add comment-list request builders plus one endpoint capability mode for comment filters.
  - Support the current documented comment filters on the list endpoint: `id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, and `content`, plus existing shared paging inputs.
  - Preserve endpoint-aware serialization instead of leaking browse/subscription/rating-only fields into comments.
  - For comment creation, send required `content` and optional `reply_id` as form-encoded body fields.
  - For comment edit, send required `content` as a form-encoded body field.
  - For comment karma, send required `karma` with only the documented `1` / `-1` values.
- **Normalization to add**
  - Add `normalize_comments_response(...)`, `normalize_comment_response(...)`, `normalize_comment_write_response(...)` for create/edit/karma success, and `normalize_comment_delete_response(...)` for `204 No Content`.
  - Normalize the Comment Object into a vendor-local seam that preserves the provider contract while adding only light convenience fields:
    - raw/documented fields: `id`, `game_id`, deprecated `mod_id`, `resource_id`, `resource_ownership`, `user`, `date_added`, `reply_id`, `thread_position`, `karma`, deprecated `karma_guest`, `content`, `options`
    - derived convenience fields that still stay provider-local: `is_reply`, `thread_depth` (segment count from `thread_position`), `is_pinned`, `is_locked`, `option_flags`, and `resource_type="mod_comment"`
  - Reuse the existing normalized user/page helpers so comment lists inherit the same `result_count` / `result_offset` / `result_limit` / `result_total` page block already used elsewhere.
  - Extend capability interpretation with a mod-local comment policy helper from `mod.community_options`, not just the existing game-level helper, so higher layers can see whether a mod has comments enabled without re-decoding provider bits upstream.
- **Fixtures to add**
  - `comments_list.json` with a mixed thread: top-level comment, nested reply, third-level reply, pinned/locked option coverage, and non-zero `result_total` pagination.
  - `comment_detail.json` for single-comment reads.
  - `comment_created.json`, `comment_updated.json`, and `comment_karma_updated.json` (or one shared success fixture if the payload shape is identical and tests stay readable).
  - `comment_restricted_error.json` for the documented restricted-comments failure path.
  - `comment_karma_deleted_error.json` for documented deleted-comment karma rejection (`15090`).
  - `comment_karma_conflict_error.json` / `comment_karma_forbidden_error.json` for the documented karma failure variants (`15055`, `15059`, `15095`) if transport error mapping is extended in the same pass.
- **Tests to add**
  - Builder tests for the six endpoints above, including auth mode differences: public/api-key reads for list/detail and bearer-only authenticated writes for add/edit/delete/karma.
  - Query-gating tests proving comment filters serialize and unrelated filters do not.
  - Normalization tests for comment list/detail payloads, option-flag decoding, reply/thread-depth derivation, and delete-success handling.
  - Transport tests for final encoded URLs and form bodies for add/edit/karma writes and the bare `DELETE` request.
  - Error-normalization tests for restricted comments plus documented karma edge cases, without inventing moderation semantics above the provider seam.
- **What should wait**
  - **Guide comments** and **collection comments** should wait even though the docs expose parallel endpoints, because this repo does not yet wrap guides or collections and pulling them in would widen the product surface beyond the current mod-focused seam.
  - Any higher-layer **report UI/legal-link flow**, moderation queue tooling, takedown thresholds, or rules-engine policy should wait; those are product/policy responsibilities, not vendor-adapter responsibilities.
  - Anything that turns `POST /report` “not working” reasons into downloader/install diagnosis or auto-remediation should wait because that crosses into AeroBeat downloader/install/orchestration policy.

The recommendation stays inside the vendor boundary: it adds raw mod.io comment transport/builders/normalization/tests, but does not take on AeroBeat UX, moderation operations, or install behavior.

---

### Task 2: Implement the comments/discussion batch and tests

**Bead ID:** `oc-70g`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched comments/discussion endpoint batch using current official mod.io docs and pinned local references as source of truth. Expand wrapper coverage, request shaping, normalization, fixtures, and tests while keeping vendor concerns local to this repo. Update README/docs/seam plan as needed, update the active plan with what actually happened, run repo-local validation/tests, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-comments-and-discussion-coverage.md`

**Status:** ✅ Complete

**Results:** Implemented the six threaded mod-comment endpoints in `src/modio_vendor_adapter.gd` using the current local `modio-docs` REST mirror as the source of truth, with public/api-key auth for list/detail and bearer-only writes for create/edit/delete/karma. Added comment-specific query gating in `src/models/modio_listing_query.gd` for `id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, and `content`, plus comment normalization that preserves the raw provider fields while adding only seam-local helpers (`is_reply`, `thread_depth`, `is_pinned`, `is_locked`, `option_flags`, `resource_type`). Extended `src/network/modio_http_transport.gd` to execute `PUT` requests and to normalize documented comment error cases (`40004`, `15055`, `15059`, `15090`, `15095`) without leaking moderation/product policy upstream. Added dedicated comment fixtures plus builder/normalization/transport/error tests in `.testbed/tests/`, updated `README.md` and `docs/modio-seam-plan.md` to reflect the new comment slice, and validated with `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` plus `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

---

### Task 3: QA the comments/discussion batch

**Bead ID:** `oc-eyr`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the expanded comments/discussion surface against the current official mod.io docs and pinned local references, not memory. Confirm request shapes, normalization, fixtures, and tests match the current docs and that vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/models/modio_listing_query.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `.plans/2026-05-02-aerobeat-vendor-modio-comments-and-discussion-coverage.md`

**Status:** ✅ Complete

**Results:** Independently re-verified the threaded mod comment batch against the current local official `modio-docs` REST mirror first, then cross-checked the comment request surface against the pinned `modio-sdk` and `modio-unity` refs. Confirmed list/detail/create/update/delete/karma request builders still match the current docs, comment normalization still preserves the raw provider fields while adding only the light repo-local helpers (`is_reply`, `thread_depth`, `is_pinned`, `is_locked`, `option_flags`, `resource_type`), and the `PUT` transport path remains correct and consistent with the documented `application/x-www-form-urlencoded` update body used elsewhere in this repo. Found one concrete docs mismatch in the comment query gating: `GET /games/{game-id}/mods/{mod-id}/comments` still documents the deprecated-but-supported `mod_id` filter, but `ModioListingQuery` was suppressing it for comment requests and the request/transport tests were locking that omission in. Applied the minimum fix by allowing `mod_id` for `ENDPOINT_MOD_COMMENTS` and extending the request/transport assertions to require it. Re-ran repo-local validation successfully with `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (24/24 tests passed, 573 asserts, 3 pre-existing float/int warnings). Vendor-specific behavior remains local to this repo and no cross-repo policy/orchestration concerns were introduced.

---

### Task 4: Audit the comments/discussion batch

**Bead ID:** `oc-4wv`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the expanded comments/discussion surface against the current official mod.io docs and pinned local references. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and materially advances the repo toward fuller mod.io coverage. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-comments-and-discussion-coverage.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Research-only completion for the next comments/discussion batch. The plan is now execution-ready for the coder pass: add the six mod-comment endpoints, comment-specific query gating, comment normalization/helpers, targeted fixtures, and transport/error tests.

**Reference Check:** The recommendation was grounded in the current official local `modio-docs` REST mirror first, with `modio-sdk` and `modio-unity` used only as secondary sanity checks for surrounding behavior. The key scope finding is that there is no separate mod discussion endpoint in the current docs; threaded mod comments are the discussion surface that belongs next in this repo.

**Commits:**
- Pending

**Lessons Learned:** The clean seam boundary here is narrower than “discussion” sounds at first glance. The right next slice is mod comments only; guide/collection comments, report UX/legal flows, moderation operations, and downloader/install-informed reporting all become broader product-surface or policy work too quickly.

---

*Completed on 2026-05-02*
