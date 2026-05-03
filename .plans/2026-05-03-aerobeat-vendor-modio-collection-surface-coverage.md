# AeroBeat Vendor Mod.io Collection Surface Coverage

**Date:** 2026-05-03  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue the push toward 100 percent mod.io REST coverage by implementing the next coherent vendor-local batch after the truth audit: collection discovery/read plus the nearest collection-adjacent community surfaces that still fit cleanly inside `aerobeat-vendor-modio`.

---

## Overview

The repo’s current wrapped surface is now truth-locked for the implemented slice: auth/session, mod browse/detail/files/stats, subscriptions, ratings/reporting, dependencies, mod comments, guides, and guide comments have all been audited against the refreshed local official corpus. That means we can resume net-new coverage work without dragging known drift forward.

The next coherent uncovered family appears to be **collections**. They sit adjacent to the now-complete guide/comment seam, are fully represented in the local official mod.io corpus, and materially advance overall REST coverage. But collections also carry some nearby edges that can easily drift out of the vendor-adapter boundary: follow/subscription-to-all-mods behavior, manage-mods flows, and any collection action that implicitly pulls install/download/orchestration policy into AeroBeat. So this slice should start with a research pass that explicitly separates safe vendor-local collection surfaces from the edges that should still wait.

The current best candidate is a batch centered on collection read/discovery and, if the docs remain cleanly parallel, collection comments and possibly collection ratings where those stay provider-local and do not imply downloader/install orchestration. The plan below preserves the usual workflow: research from the refreshed official local corpus first, then coder, QA, and independent audit, with exact doc-truth checks at each step.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current doc-truth audit plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-doc-truth-and-repo-audit.md` |
| `REF-02` | Latest guide/comment expansion plan | `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md` |
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

### Task 1: Research the next coherent collection-centered batch

**Bead ID:** `oc-77f`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapped surface plus the refreshed official local mod.io corpus to define the next coherent collection-centered endpoint batch after guides/comments. Produce an execution-ready recommendation that explicitly separates safe vendor-local collection read/comment/rating surfaces from any collection follow/subscribe/manage-mods/authoring edges that would pull downloader/install/orchestration or product policy into this repo. Update the plan with what actually happened and close the bead with a concrete target list.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if notes need updating

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md`
- optional research note(s) if needed

**Status:** ✅ Complete

**Results:** Re-read `REF-01` through `REF-08` with the refreshed local official corpus anchored in `modio-docs`, then sanity-checked nearby behavior pressure in `modio-sdk` and `modio-unity`. Recommendation: the next coherent batch should be a **collection discovery/read + collection comments + collection rating** slice, with collection-mod membership read included only as a read-only adjacency to complete the collection detail seam. Exact endpoints to add now: `GET /games/{game-id}/collections`, `GET /games/{game-id}/collections/{collection-id}`, `GET /games/{game-id}/collections/{collection-id}/mods`, `GET /games/{game-id}/collections/{collection-id}/comments`, `GET /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `POST /games/{game-id}/collections/{collection-id}/comments`, `PUT /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `DELETE /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `POST /games/{game-id}/collections/{collection-id}/comments/{comment-id}/karma`, and `POST /games/{game-id}/collections/{collection-id}/compatibility`.

Query shaping to add now:
- add `ModioListingQuery.ENDPOINT_COLLECTIONS`, `ENDPOINT_COLLECTION_MODS`, and `ENDPOINT_COLLECTION_COMMENTS`
- `collections` query should mirror the guide-capability pattern, allowing only doc-backed filters/sorts the repo can truthfully support: `id`, `game_id`, `status`, `visible`, `submitted_by`, `name_id`, `date_added`, `date_updated`, `date_live`, `tags`, and collection-safe `_sort`
- recommended allowed collection sorts from the docs/schema surface: `name`, `date_live`, `date_updated`, `submitted_by`, `downloads_today`, `downloads_total`, `followers_total`, `ratings_positive_30_days`
- `collection_comments` query should mirror mod/guide comments: `id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, `content`; keep unrelated browse filters out
- `collection_mods` query should reuse the existing mod browse capability set instead of inventing a new partial mod filter surface
- do **not** pull `/me/collections` or `/me/following/collections` into this batch; those are account-state surfaces, not the cleanest next vendor-local seam

Normalization/fixture/test target list for the coder:
- add collection normalizers parallel to guides where shapes overlap but preserve collection-specific fields (`limit_number_mods`, `filesize`, `filesize_uncompressed`, `platforms`, `stats.followers_total`, `stats.ratings_positive_30_days`, logo/thumbs, and collection tags/category)
- normalize collection comments through the existing shared comment path, but stamp a distinct `resource_type` such as `collection_comment`
- add a small collection-mod normalizer path that reuses existing mod object normalization for the returned list items
- add collection rating response normalization parallel to `normalize_add_mod_rating_response`
- fixtures likely needed: `collections.json`, `collection_detail.json`, `collection_mods.json`, `collection_comments_list.json`, `collection_comment_detail.json`, `collection_comment_created.json`, `collection_comment_updated.json`, `collection_comment_karma_updated.json`, `add_collection_rating_success.json`, plus at least one collection-comment error fixture for restricted comments or deleted-comment karma
- tests should mirror the existing guide/mod comment coverage: request-path + method assertions, endpoint-specific query filtering assertions, normalization assertions for collection stats/platforms/tags/logo fields, comment threading/flags assertions, `204` delete normalization reuse, and add-collection-rating success normalization

Explicitly in scope now: vendor-local collection browse/detail/mod-membership read, threaded collection comments, collection comment karma, and collection thumbs-up/down compatibility rating submission. Explicitly out of scope for this repo right now: `POST/DELETE /games/{game-id}/collections/{collection-id}/followers`, `POST/DELETE /games/{game-id}/collections/{collection-id}/subscriptions`, `/me/collections`, `/me/following/collections`, `POST /games/{game-id}/collections`, `POST /games/{game-id}/collections/{collection-id}` edit/sync, `DELETE /games/{game-id}/collections/{collection-id}`, `DELETE /games/{game-id}/collections/{collection-id}/mods`, and any downstream downloader/install orchestration. The docs plus SDK/Unity references show those edges are where collection state starts coupling to followed-account state, subscribe-all behavior, and mod-management/install loops (`SubscribeToModCollectionOp`, `ProcessNextModInUserCollection`, `ProcessNextModInServerCollection`, Unity collection subscribe/unsubscribe UI), so they should wait for an explicit product-policy decision instead of being smuggled into this vendor adapter seam.

---

### Task 2: Implement the agreed collection-centered batch

**Bead ID:** `oc-geg`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched next collection-centered mod.io coverage slice using the refreshed official local corpus as source of truth. Expand request builders, endpoint-aware query shaping, normalization helpers, fixtures, tests, and seam docs while keeping vendor concerns local to this repo. Update the plan with what actually happened, run repo-local validation, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md`

**Status:** ✅ Complete

**Results:** Implemented the collection-centered slice against `REF-06`/`REF-07`/`REF-08` with a doc-truth correction from Task 1’s broader sketch: the shipped query surface now matches the refreshed official corpus instead of assuming extra browse symmetry. Added request builders in `src/modio_vendor_adapter.gd` for `GET /games/{game-id}/collections`, `GET /games/{game-id}/collections/{collection-id}`, `GET /games/{game-id}/collections/{collection-id}/mods`, `GET /games/{game-id}/collections/{collection-id}/comments`, `GET /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `POST /games/{game-id}/collections/{collection-id}/comments`, `PUT /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `DELETE /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `POST /games/{game-id}/collections/{collection-id}/comments/{comment-id}/karma`, and `POST /games/{game-id}/collections/{collection-id}/compatibility`.

Endpoint-aware query shaping was extended in `src/models/modio_listing_query.gd` with `ENDPOINT_COLLECTIONS`, `ENDPOINT_COLLECTION_MODS`, and `ENDPOINT_COLLECTION_COMMENTS`. Actual shipped filter/sort support is intentionally narrower than the earlier sketch where the refreshed corpus required it: collection lists now allow only doc-backed `id`, `status`, `mod_id`, `category`, `submitted_by`, `submitted_by_display_name`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `maturity_option`, `tags`, `tags-in`, `tags-not-in`, plus `_sort` in `{name,date_live,date_updated}`; collection-mod reads allow only paging plus `maturity_option`, `show_hidden_mods`, and `_sort` in `{name,date_live,date_updated,downloads_today,downloads_total,subscribers_total,mods_count_total}`; collection comments allow only `id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, and `content` plus paging.

Normalization/helpers added in `src/modio_vendor_adapter.gd`: collection list/detail normalization, collection stats normalization, string-array normalization for collection `platforms`/`tags`, collection comment normalization through the shared comment path with `resource_type = collection_comment`, collection-mod list normalization through existing mod normalization, and collection compatibility message normalization parallel to mod ratings. Fixture/test coverage was added in `.testbed/tests/test_modio_vendor_adapter.gd`, `.testbed/tests/test_modio_http_transport.gd`, and new fixtures under `.testbed/tests/fixtures/` for collection list/detail/comment/compatibility payloads. Docs were minimally updated in `README.md` and `docs/modio-seam-plan.md` to reflect the new supported surfaces and the endpoint-gated query stance.

Validation evidence:
- Command: `/home/derrick/.local/bin/godot --headless --path .testbed -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_modio_vendor_adapter.gd,res://tests/test_modio_http_transport.gd`
- Result: `30/30` tests passed, `893` asserts, exit code `0`
- Coverage included final encoded transport URLs/form bodies for the new collection requests plus fixture-driven normalization of collection objects, collection comments, and collection compatibility writes.

---

### Task 3: QA the collection-centered batch

**Bead ID:** `oc-7of`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the newly added collection-centered surface against the refreshed official local mod.io corpus, not model memory. Confirm request shapes, normalization, fixtures, and tests match the docs and that vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the collection-centered batch

**Bead ID:** `oc-xzh`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the newly added collection-centered surface against the refreshed official local mod.io corpus. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and materially advances the repo toward fuller mod.io coverage. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md`

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
