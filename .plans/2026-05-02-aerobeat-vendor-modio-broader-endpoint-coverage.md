# AeroBeat Vendor Mod.io Broader Endpoint Coverage

**Date:** 2026-05-02  
**Status:** Draft  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue pushing `aerobeat-vendor-modio` toward full mod.io coverage by expanding the wrapped endpoint surface in a controlled, docs-verified way while preserving the repo’s vendor-adapter-only boundary.

---

## Overview

The current repo now has a solid foundation: wrapped auth/session flows, browse/detail, subscribed state, transport hardening, transport integration-style tests, and metadata-only download/cache helpers. The next highest-value move toward “100% coverage” is broader endpoint surface coverage inside the vendor repo itself.

This slice should stay grounded in the current official mod.io docs and the pinned local mod.io references. The research pass should identify the next coherent set of endpoints to add as a batch rather than sprinkling one-offs. Likely candidates include richer user-state, ratings/reactions/reporting edges where relevant, media/file-related metadata helpers, statistics/admin-adjacent read surfaces that are safe for this repo, and any remaining public/game/user read endpoints that fit the vendor adapter role without drifting into AeroBeat policy or orchestration.

The coder should then implement the chosen endpoint batch, with fixture-driven tests and transport-level coverage where useful. QA and audit should again verify exact parity against the official current docs so each slice incrementally reduces uncertainty instead of growing unverified surface area.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active broader-coverage plan | `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md` |
| `REF-02` | Download/cache slice | `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md` |
| `REF-03` | Live transport slice | `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md` |
| `REF-04` | Coverage expansion slice | `.plans/2026-05-02-aerobeat-vendor-modio-coverage-expansion.md` |
| `REF-05` | REST wrapper slice | `.plans/2026-05-02-aerobeat-vendor-modio-rest-wrapper.md` |
| `REF-06` | Current mod.io API research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-07` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-08` | Official local mod.io refs | `/home/derrick/.openclaw/workspace/projects/modio/` |
| `REF-09` | Current implementation/tests | `src/`, `.testbed/tests/` |

---

## Tasks

### Task 1: Research the next coherent endpoint batch

**Bead ID:** `oc-cny`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapped surface plus the current official mod.io docs and pinned local references to define the next coherent endpoint batch that best advances toward full coverage. Produce a concrete target list of additional endpoints, required request/response normalization, fixture shapes, and integration-style tests. Keep the recommendation constrained to what belongs in a vendor adapter repo and explicitly call out anything that should wait because it would introduce downloader/install/policy/orchestration responsibilities. Update the active plan with what actually happened and close the bead with an execution-ready recommendation.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` (if notes need updating)

**Files Created/Deleted/Modified:**
- `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md`
- optional notes/docs if needed

**Status:** ✅ Complete

**Results:** Researched the current repo surface against the local official `modio-docs` REST mirror first, then cross-checked `modio-sdk` and `modio-unity` only where current docs left client-behavior ambiguities. Recommendation: the next coherent batch should be a **mod detail engagement + user feedback slice**, not comments, uploads, collections, purchases, or install orchestration. The highest-value doc-grounded additions that still fit a vendor adapter are: `GET /games/{game-id}/mods/{mod-id}/files/{file-id}` for direct single-file re-resolution, `GET /games/{game-id}/mods/{mod-id}/stats` for standalone fresh stats, `GET /me/ratings` for authenticated user rating state, `POST /games/{game-id}/mods/{mod-id}/ratings` for positive/negative mod ratings, and `POST /report` for raw report submission. This batch stays inside the provider seam, materially improves what a future AeroBeat mod-details/library surface can know and do, and avoids dragging in downloader/install/AeroBeat trust-policy responsibilities.

Execution-ready recommendation for Task 2:

- **Recommended batch definition**
  - Add a focused engagement/reporting slice around a mod details screen and authenticated user state:
    - `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`
    - `GET /games/{game-id}/mods/{mod-id}/stats`
    - `GET /me/ratings`
    - `POST /games/{game-id}/mods/{mod-id}/ratings`
    - `POST /report`
  - Keep this batch provider-native and thin:
    - request builders
    - response normalization
    - fixture-driven transport/integration-style tests
    - small policy helpers only where the docs expose provider bitfields or required request constraints
  - Do **not** implement comment threads, upload/edit/delete surfaces, purchase/entitlement handling, or any download/install workflow in this slice.

- **Why this is the best next batch**
  - The repo already covers browse/detail/subscriptions/dependencies/download metadata/transport. What it still lacks is a clean seam for **user sentiment and moderation actions** tied to a mod, plus the missing direct file/stats detail endpoints that complement the current artifact/cache work.
  - `GET /me/ratings` is specifically called out in the official SDK/plugin flows as part of user sync state, which makes it a better next addition than wider but less immediately relevant surfaces like collections or guides.
  - `POST /report` is especially important because the official report docs explicitly say displayed content needs to be reportable; the vendor repo should own the raw submission contract even if higher-level product UX/policy lives elsewhere.
  - `GET /games/{game-id}/mods/{mod-id}/files/{file-id}` is a natural follow-on to the current artifact/cache slice because it gives the adapter a direct way to re-resolve a specific `modfile.id` instead of only browsing the file list.

- **Concrete endpoint targets**
  - **`GET /games/{game-id}/mods/{mod-id}/files/{file-id}`**
    - Add `build_modfile_request(mod_id, file_id)`.
    - Reuse the existing public-read auth/header/base-URL rules.
    - Normalize with the current `_normalize_modfile_object(...)` path so single-file and list-item shapes stay identical.
    - Add an artifact-resolution helper path that can resolve a record directly from a single modfile payload, since the current download/cache work already treats `modfile.id` as canonical artifact identity.
  - **`GET /games/{game-id}/mods/{mod-id}/stats`**
    - Add `build_mod_stats_request(mod_id)`.
    - Normalize through the existing stats-object shape, but as a top-level standalone normalized stats payload instead of only nested inside `Mod Object`.
    - Add a small helper for `date_expires` freshness semantics (for example `has_expiry`, `is_stale`) if useful, but keep it provider-local and docs-derived.
  - **`GET /me/ratings`**
    - Add `build_user_ratings_request(...)` using bearer auth only.
    - Support the current official filters documented on the endpoint:
      - `game_id`
      - `mod_id`
      - `rating`
      - `resource_type`
      - `date_added`
      - plus shared paging fields `_offset` / `_limit`
    - Default/recommend `resource_type=mods` in repo-local helpers, but preserve the raw field instead of assuming mods forever because the official docs expose `collections` too.
    - Reuse page helpers from the existing list normalization.
  - **`POST /games/{game-id}/mods/{mod-id}/ratings`**
    - Add `build_add_mod_rating_request(mod_id, rating)` with form-encoded bearer-authenticated body.
    - Keep the accepted repo-local rating API constrained to the current endpoint prose + SDK behavior: `1` positive, `-1` negative.
    - Normalize the success payload as the same lightweight message shape already used for logout/report-style responses.
    - Add structured error mapping for documented rating-specific refs:
      - `15028` already rated
      - `15043` revert/remove target does not exist
    - Important docs note to preserve in code/tests: the official endpoint prose and SDK filters describe `-1` / `1`, while the current `Rating Object` schema text in the docs appears inconsistent. Preserve the raw provider value and document that the request semantics are grounded in the endpoint docs + official SDKs.
  - **`POST /report`**
    - Add `build_submit_report_request(resource, id, type, summary, options={})` with bearer auth and form encoding.
    - Support the current documented body fields:
      - required: `resource`, `id`, `type`, `summary`
      - optional: `name`, `contact`, `reason`, `platforms`, `game_name_id`
    - Do not silently invent higher-level report categorization; just preserve the provider enums and normalize the success message/error envelope.
    - Preserve the current docs behavior that `platforms` may be inferred from `X-Modio-Platform` if the header is present and the field is omitted; do not force-send both unless explicitly requested.
    - Add structured error mapping for documented refs:
      - `15029` reporting access revoked
      - `15030` resource not reportable right now
      - `14000` target resource not found

- **Normalization and helper targets**
  - **Ratings normalization**
    - Add `normalize_user_ratings_response(...)` returning paged normalized rating entries.
    - Normalize each rating to include at least:
      - `game_id`
      - `mod_id` (preserve even if docs mark older forms deprecated elsewhere)
      - `resource_type`
      - `resource_id`
      - `rating`
      - derived `is_positive` / `is_negative`
      - `date_added`
    - Preserve raw provider truth where docs are awkward instead of over-normalizing to AeroBeat semantics.
  - **Standalone stats normalization**
    - Add `normalize_mod_stats_response(...)` using the current Mod Stats Object fields already familiar from nested mod stats:
      - `mod_id`
      - popularity/download/subscriber totals
      - ratings totals/percent/weighted aggregate/display text
      - `date_expires`
    - Optional derived helper fields should stay small and docs-based only.
  - **Message/report normalization**
    - Reuse or generalize the current lightweight `code/message/success` message normalization so logout, add-rating, and report submission share the same provider-local shape.
  - **Community policy interpretation**
    - Extend game-level policy helpers to interpret the `community_options` bitfield enough for this slice, especially:
      - comments enabled
      - guides enabled
      - **negative ratings enabled** (`256`)
    - Use this only to expose provider capability metadata, not to impose AeroBeat product policy.

- **Fixture shapes to add**
  - `modfile_detail.json`
    - single modfile payload aligned with current official docs, including `download.binary_url`, `download.date_expires`, `filehash.md5`, and doc-valid `platforms` values.
  - `mod_stats.json`
    - single mod-stats payload with `ratings_*`, download/subscriber counts, popularity, and `date_expires`.
  - `user_ratings.json`
    - paged list response with a few rating entries showing current authenticated user state across at least two mods.
    - Include both positive and negative examples if the fixture game’s `community_options` allows negative ratings.
    - Preserve `resource_type` and `resource_id` even if the repo initially only targets mod ratings.
  - `add_mod_rating_success.json`
    - lightweight message payload like `{ code: 201, message: ... }`.
  - `rating_already_exists_error.json`
    - documented `15028` case.
  - `rating_revert_missing_error.json`
    - documented `15043` case, even if the initial wrapper does not expose a “clear rating” helper yet; keep the transport/error mapping ready.
  - `report_success.json`
    - lightweight message payload like `{ code: 201, message: ... }`.
  - `report_permission_error.json`
    - documented `15029` case.
  - `report_unavailable_error.json`
    - documented `15030` case.
  - `report_not_found_error.json`
    - documented `14000` case.

- **Tests to add**
  - Request-builder tests for:
    - single-modfile path assembly
    - mod-stats path assembly
    - user-ratings query gating + bearer auth
    - add-rating form body + bearer auth
    - report form body + bearer auth + optional platform/report-reason fields
  - Transport/integration-style tests for:
    - executed `GET /games/{game-id}/mods/{mod-id}/files/{file-id}` URL/header assembly
    - executed `GET /games/{game-id}/mods/{mod-id}/stats`
    - executed `GET /me/ratings` with paged filters
    - executed `POST /games/{game-id}/mods/{mod-id}/ratings`
    - executed `POST /report`
  - Normalization tests for:
    - single modfile payload matching list-item normalization
    - mod stats payload and freshness field handling
    - user ratings list paging + `is_positive` / `is_negative` derivation
    - add-rating/report success payloads using shared message normalization
    - rating/report error refs categorized correctly
  - Policy/helper tests for:
    - `community_options` negative-ratings capability exposure
    - report request leaving `platforms` unset when omitted and relying on configured `X-Modio-Platform`

- **Things that should explicitly wait**
  - **Comments** (`get/add/edit/delete mod comments`, karma, thread ordering): large surface, more pagination/filter complexity, and bigger UX/policy implications than this next batch needs.
  - **Collections / guides / follow / social surfaces**: valid future vendor coverage, but not the best next move for AeroBeat’s current mod-centric seam.
  - **Uploads / mod creation / modfile creation / media / metadata / dependency writes**: these would drag the repo toward authoring workflows and multipart orchestration instead of strengthening the currently missing consumer-side seam.
  - **Purchases / wallet / entitlements / marketplace**: important but introduce monetization/ownership policy responsibilities that are a worse next step than ratings/reporting.
  - **Downloader/install/enable-disable/offline sync behavior**: explicitly out of scope for this vendor adapter recommendation.
  - **Report-dialog UX, terms-link presentation, moderation queues, and AeroBeat-specific abuse policy**: the repo should only own the raw provider request/response seam here, not the product workflow around it.
  - **Rating removal/neutral semantics** beyond the current positive/negative set: the endpoint docs and schema presentation are awkward enough that the safest next slice is to support documented positive/negative submission and preserve transport errors, while leaving any “clear rating” abstraction for a later docs-verified pass.

Execution-ready recommendation: Task 2 should implement the five-endpoint **mod detail engagement + user feedback** batch above, update README / seam docs to describe the new boundaries, add fixture-driven tests for request shaping + normalization + endpoint-specific errors, and keep all new behavior strictly provider-native.

---

### Task 2: Implement the next endpoint batch and tests

**Bead ID:** `oc-bvk`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched next endpoint batch using current official mod.io docs and pinned local references as source of truth. Expand wrapper coverage, request shaping, normalization, fixtures, and tests while keeping vendor concerns local to this repo. Update README/docs/seam plan as needed, update the active plan with what actually happened, run repo-local validation/tests, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md`

**Status:** ✅ Complete

**Results:** Implemented the researched five-endpoint batch against the current local official references: `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`, `GET /games/{game-id}/mods/{mod-id}/stats`, `GET /me/ratings`, `POST /games/{game-id}/mods/{mod-id}/ratings`, and `POST /report`. Added endpoint-aware request builders, extended `ModioListingQuery` with user-rating filters, added shared message normalization plus standalone mod-stats and user-rating normalization, exposed game `community_options` capability interpretation for negative-ratings awareness, and kept all provider-specific behavior inside this repo. Added new fixtures plus request-shape/transport/normalization/error tests for the batch, including conflict handling for rating edge cases and report submission errors. Updated README and seam-plan docs to describe the wider provider seam and the rating/report contract caveat that the wrapper preserves raw provider rating integers instead of inventing a cleaner enum. Repo-local validation passed with `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Commit/push details appended in Final Results after landing.

---

### Task 3: QA the expanded endpoint surface

**Bead ID:** `oc-bp2`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the expanded endpoint surface against the current official mod.io docs and pinned local references, not memory. Confirm request shapes, normalization, fixtures, and tests match the current docs and that vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the expanded endpoint surface

**Bead ID:** `oc-dck`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the expanded endpoint surface against the current official mod.io docs and pinned local references. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and materially advances the repo toward fuller mod.io coverage. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-broader-endpoint-coverage.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** The coder pass landed a coherent mod-detail engagement + user-feedback batch for the vendor adapter: single-modfile reads, standalone mod stats, authenticated user ratings reads, mod rating writes, and raw report submission. The implementation added endpoint-aware request builders, user-rating query support, shared message normalization for logout/rating/report responses, standalone mod-stats normalization, paged user-rating normalization, game community-policy interpretation for negative-rating capability awareness, new fixtures, and transport/adapter tests that exercise final encoded request shapes and endpoint-specific error handling.

**Reference Check:** Task 2 was implemented against `REF-01` through `REF-09`, using the local official `modio-docs` REST mirror as source of truth first and cross-checking the pinned SDK/plugin refs where the rating/report contracts were uneven. The landed seam deliberately preserves raw provider rating integers (`1` / `-1`) instead of inventing a stricter local enum, and keeps report/rating/provider capability concerns isolated to this repo.

**Commits:**
- `af4bc6b` - Add mod.io ratings report and stats endpoint batch

**Lessons Learned:** The mod.io docs are broadly current, but ratings remain a good example of where the generated docs, response examples, and client refs do not line up perfectly. Preserving provider truth in the seam while adding small convenience derivations (`is_positive`, `is_negative`, `sentiment`, `community_policy`) keeps the wrapper honest and easier to audit.

---

*Completed on 2026-05-02*
