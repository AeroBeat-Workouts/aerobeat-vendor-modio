# AeroBeat Vendor Mod.io Adjacent Comment Surfaces

**Date:** 2026-05-02  
**Status:** Stale  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue pushing `aerobeat-vendor-modio` toward fuller mod.io coverage by implementing the next coherent batch of adjacent comment-style surfaces beyond mod comments, while preserving the repo’s vendor-adapter-only boundary.

---

## Overview

The repo now covers a substantial mod-focused surface: auth/session, browse/detail, subscriptions, ratings/report/stats, dependency/cache metadata helpers, live transport hardening, and threaded mod comments. The next coherent step is to extend that same comment/discussion pattern to the nearest adjacent surfaces that mod.io exposes, likely guide and collection comment flows or similar user-facing read/write feedback surfaces that still belong inside a provider adapter.

As with prior slices, the research pass should choose the next coherent batch from the current official mod.io docs and pinned local mod.io references rather than assuming symmetry from the mod comment endpoints. The implementation should expand request builders, normalization, fixtures, and tests only for surfaces that remain squarely vendor-local. Anything that would drag the repo into creator authoring orchestration, moderation workflow policy, downloader/install behavior, or monetization should be explicitly deferred.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active adjacent-comment plan | `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md` |
| `REF-02` | Mod comment coverage slice | `.plans/2026-05-02-aerobeat-vendor-modio-comments-and-discussion-coverage.md` |
| `REF-03` | Broader endpoint coverage slice | `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md` |
| `REF-04` | Download/cache slice | `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md` |
| `REF-05` | Live transport slice | `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md` |
| `REF-06` | Current mod.io API research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-07` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-08` | Official local mod.io refs | `/home/derrick/.openclaw/workspace/projects/modio/` |
| `REF-09` | Current implementation/tests | `src/`, `.testbed/tests/` |

---

## Tasks

### Task 1: Research the next coherent adjacent comment-surface batch

**Bead ID:** `oc-4jg`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapped surface plus the current official mod.io docs and pinned local references to define the next coherent adjacent comment-style endpoint batch beyond mod comments. Produce a concrete target list of endpoints, request/response normalization, fixture shapes, and tests. Keep the recommendation constrained to what belongs in a vendor adapter repo and explicitly call out anything that should wait because it would introduce downloader/install/orchestration/AeroBeat policy responsibilities. Update the active plan with what actually happened and close the bead with an execution-ready recommendation.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` (if notes need updating)

**Files Created/Deleted/Modified:**
- `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md`
- optional notes/docs if needed

**Status:** ✅ Complete

**Results:** Reviewed the current wrapped surface in `src/` and `.testbed/tests/`, re-read the current local official `modio-docs` REST mirror as primary truth, and used `modio-sdk` / `modio-unity` only as secondary sanity references. The next coherent adjacent batch beyond the now-complete **mod comments** slice should be **guide discovery/read + guide comments**, not collection comments.

Why this is the next coherent batch:
- The repo already exposes game-level community policy helpers for `allows_guides` and `allows_guide_comments`, so guides are already part of the visible mod.io seam.
- The official guide objects expose `community_options` with `ALLOWS_COMMENTS (2048)` plus `stats.comments_total`, which makes guide read coverage the natural parent surface for guide comments.
- Implementing guide comments without at least guide list/detail would force higher layers to source guide ids and comment availability from somewhere else, which would make the seam awkward.
- Collections are farther from the current seam because they pull in follow/subscribe-to-all-mods/report/manage-mods behaviors that quickly drift toward downloader/install/orchestration responsibilities.

Execution-ready recommendation:

- **Endpoints to add now as one coherent batch**
  - Guide read/discovery:
    - `GET /games/{game-id}/guides`
    - `GET /games/{game-id}/guides/{guide-id}`
  - Guide comments:
    - `GET /games/{game-id}/guides/{guide-id}/comments`
    - `GET /games/{game-id}/guides/{guide-id}/comments/{comment-id}`
    - `POST /games/{game-id}/guides/{guide-id}/comments`
    - `PUT /games/{game-id}/guides/{guide-id}/comments/{comment-id}`
    - `DELETE /games/{game-id}/guides/{guide-id}/comments/{comment-id}`
    - `POST /games/{game-id}/guides/{guide-id}/comments/{comment-id}/karma`

- **Guide request shaping / query serialization**
  - Add endpoint capability modes for guide list queries and guide comment list queries.
  - For `GET /games/{game-id}/guides`, support the current documented guide filters: `id`, `game_id`, `status`, `submitted_by`, `submitted_by_display_name`, `date_added`, `date_updated`, `date_live`, `name_id`, and `tags`, plus the shared paging/sort inputs already used elsewhere.
  - Allow the current documented guide sort keys: `name`, `date_live`, `date_updated`, `submitted_by`, `visits_today`, `visits_total`, `comments_total`.
  - For `GET /games/{game-id}/guides/{guide-id}/comments`, support the current documented comment filters: `id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, and `content`, plus shared paging inputs.
  - For comment create, send required `content` and optional `reply_id` as `application/x-www-form-urlencoded`.
  - For comment edit, send required `content` as `application/x-www-form-urlencoded`.
  - For comment karma, send required `karma` with only the documented `1` / `-1` values.

- **Normalization to add**
  - Guide responses:
    - `normalize_guides_response(...)`
    - `normalize_guide_response(...)`
  - Guide object normalization should preserve the provider fields and only add light seam-local helpers:
    - raw/documented fields: `id`, `game_id`, `game_name`, `logo`, `user`, `date_added`, `date_updated`, `date_live`, `status`, `url`, `name`, `name_id`, `summary`, `description`, `community_options`, `tags`, `stats`
    - derived convenience fields: `allows_comments`, `comments_total`, `visits_today`, `visits_total`, `resource_type="guide"`
  - Guide comment responses:
    - `normalize_guide_comments_response(...)`
    - `normalize_guide_comment_response(...)`
    - `normalize_guide_comment_write_response(...)`
    - `normalize_guide_comment_delete_response(...)`
  - Reuse the existing normalized comment shape already introduced for mod comments, but set a guide-specific resource marker such as `resource_type="guide_comment"` and preserve the documented raw fields (`id`, `game_id`, deprecated `mod_id`, `resource_id`, `resource_ownership`, `user`, `date_added`, `reply_id`, `thread_position`, `karma`, deprecated `karma_guest`, `content`, `options`).
  - Reuse the existing derived helpers from the mod comment slice where they still fit: `is_reply`, `thread_depth`, `is_pinned`, `is_locked`, `option_flags`.

- **Fixtures to add**
  - Guide fixtures:
    - `guides_list.json` with multiple guides, mixed `community_options`, tags, and populated stats including `comments_total`
    - `guide_detail.json`
  - Guide comment fixtures:
    - `guide_comments_list.json` with a threaded comment tree including top-level, reply, third-level reply, and pinned/locked option coverage
    - `guide_comment_detail.json`
    - `guide_comment_created.json`
    - `guide_comment_updated.json`
    - `guide_comment_karma_updated.json`
  - Error fixtures:
    - `guide_comment_restricted_error.json` for restricted comments / revoked comment access
    - `guide_comment_karma_deleted_error.json` for documented deleted-comment karma rejection (`15090`)
    - `guide_comment_karma_forbidden_error.json` for current documented guide-comment karma failures including `11006`, `15055`, `15059`, and the guide-specific `19045` downvote-disabled case
    - `guide_comment_delete_forbidden_error.json` for documented delete restriction (`19027`)

- **Tests to add**
  - Builder tests for all eight endpoints above.
  - Query-gating tests proving guide list filters/sorts serialize only on guide endpoints and guide-comment filters serialize only on guide-comment endpoints.
  - Auth tests confirming read endpoints stay public/api-key compatible while guide comment writes require bearer auth.
  - Normalization tests for guide list/detail payloads, `allows_comments` derivation from guide `community_options`, and stats extraction.
  - Comment normalization tests reusing the mod-comment seam expectations but asserting guide-specific resource markers.
  - Transport/body tests for final encoded URLs and form bodies for add/edit/karma writes plus bare delete behavior.
  - Error-normalization tests for the documented guide-comment failures above, especially the guide-specific `19045` downvote-disabled condition and `19027` delete restriction.

- **What should wait / stay out of scope for this repo right now**
  - **Guide authoring flows** (`POST /games/{game-id}/guides`, guide edit/delete) should wait. They are closer to creator CMS/editor responsibilities than to the current consumer/vendor seam.
  - **Guide tags endpoints** can wait unless guide browse parity is needed immediately; they are adjacent but not necessary for the first guide-comments slice.
  - **Collection comments** should wait until the repo intentionally takes on collection read surfaces. Collections are comment-adjacent in the REST docs, but the broader collection surface brings in collection follow/subscribe/report/manage-mods concerns.
  - **Collection subscribe/unsubscribe/follow flows** should definitely wait, because the official SDK explicitly ties collection subscription state to mod installation/uninstallation behavior. That crosses the vendor adapter into downloader/install/orchestration/AeroBeat policy.
  - Any rules-engine interpretation, moderation queue tooling, creator workflow UX, or AeroBeat-specific decisions about how guides/comments should appear or be gated should remain outside this repo.

---

### Task 2: Implement the adjacent comment-surface batch and tests

**Bead ID:** `oc-zp6`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched adjacent comment-style endpoint batch using current official mod.io docs and pinned local references as source of truth. Expand wrapper coverage, request shaping, normalization, fixtures, and tests while keeping vendor concerns local to this repo. Update README/docs/seam plan as needed, update the active plan with what actually happened, run repo-local validation/tests, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md`

**Status:** ✅ Complete

**Results:** Implemented the researched guide discovery/read + guide comment batch in `src/modio_vendor_adapter.gd` and `src/models/modio_listing_query.gd` using the current local official `modio-docs` REST mirror as primary truth. Added endpoint-aware request builders for guide list/detail and guide comments, guide/guide-comment normalization helpers, new guide fixtures, and transport + adapter coverage in `.testbed/tests/`. Also updated `README.md` and `docs/modio-seam-plan.md` so the seam documentation reflects the newly wrapped guide surfaces and their documented filter/sort constraints. Repo-local validation passed via `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (27/27 tests passed). Landed in commit `fbc4acb` (`Add mod.io guide and guide comment coverage`) and pushed to `origin/main`.

---

### Task 3: QA the adjacent comment-surface batch

**Bead ID:** `oc-enp`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the expanded adjacent comment-style surface against the current official mod.io docs and pinned local references, not memory. Confirm request shapes, normalization, fixtures, and tests match the current docs and that vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md`

**Status:** ✅ Complete

**Results:** Independently re-verified the new guide discovery/read + guide comments batch against the current local official `modio-docs` REST mirror first, then sanity-checked the surrounding vendor seam against the pinned `modio-sdk` and `modio-unity` references. Confirmed the request paths/methods/bodies for guide list/detail and guide comment list/detail/create/update/delete/karma still match the current docs, and that guide-comment query gating correctly stays limited to the documented subset (`id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, `content` plus paging). Found two concrete gaps in the landed QA surface: guide list `_sort` accepted undocumented values instead of only the documented guide sort keys, and normalized guide objects were missing the planned guide-local convenience fields (`resource_type="guide"`, top-level `allows_comments`, and flattened `visits_today` / `visits_total` / `comments_total` derived from the documented stats payload). Applied the minimum fix in `src/models/modio_listing_query.gd`, `src/modio_vendor_adapter.gd`, and the focused guide request/normalization transport tests, then re-ran repo-local validation successfully with `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (27/27 tests passed, 706 asserts, 3 pre-existing float/int warnings). Vendor concerns remain local to this repo; no cross-repo policy/orchestration drift was introduced.

---

### Task 4: Audit the adjacent comment-surface batch

**Bead ID:** `oc-x2j`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the expanded adjacent comment-style surface against the current official mod.io docs and pinned local references. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and materially advances the repo toward fuller mod.io coverage. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md`

**Status:** ✅ Complete

**Results:** Performed an independent truth-check of the guide discovery/read + guide comments batch against the current local official `modio-docs` REST mirror first, then sanity-checked the surrounding contract against the pinned `modio-sdk` / `modio-unity` references. Confirmed the guide list/detail and guide comment list/detail/create/update/delete request builders still match the current docs, guide `_sort` remains restricted to the documented keys only, guide-comment query gating still matches the documented subset, and the guide/guide-comment normalization helpers still match the current Guide Object / Comment Object shapes while preserving the QA-added seam-local convenience fields (`resource_type`, `allows_comments`, flattened visit/comment counts). Found one remaining guide-specific drift in the error surface: the current official `POST /games/{game-id}/guides/{guide-id}/comments/{comment-id}/karma` docs use error ref `19045` for disabled guide downvotes, but the transport categorizer/tests only covered the mod-comment variant `15095`. Applied the minimum fix in `src/network/modio_http_transport.gd`, added a focused guide fixture + adapter/transport coverage, and re-ran repo-local validation successfully with `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (27/27 tests passed, 715 asserts, 3 pre-existing float/int warnings). Vendor concerns remain local to this repo and no unintended drift remains in the audited guide surface.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The repo now includes an audited guide discovery/read + guide comments slice on top of the existing mod.io vendor seam: guide list/detail request builders, guide comment list/detail/create/update/delete/karma request builders, documented guide/query gating, Guide Object / Comment Object normalization plus the intended seam-local convenience fields, and fixture-driven adapter/transport coverage derived from the current official docs.

**Reference Check:** Research, QA, and audit all used the current local official `modio-docs` REST mirror as the primary truth source, with `modio-sdk` and `modio-unity` used only as secondary sanity checks. Final audit confirmed the QA guide `_sort` / normalization fixes and added the remaining guide-specific karma error-ref coverage (`19045`) required by the current docs.

**Commits:**
- Pending final auditor commit/push for the `19045` guide-comment-karma audit fix and plan update.

**Lessons Learned:** The closest comment-adjacent REST surface is not automatically the best next seam slice. Collections are comment-adjacent in the API, but guides are the cleaner next batch because the repo already exposes guide-related game capability bits and collections pull harder on downloader/install/orchestration policy. The audit also showed that mod-vs-guide comment endpoints can differ in small but meaningful error-ref details even when their payload shapes are otherwise shared.

---

*Completed on 2026-05-02*
