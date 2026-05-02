# AeroBeat Vendor Mod.io Download and Cache Policy Helpers

**Date:** 2026-05-02  
**Status:** In Progress  
**Agent:** Chip 🐱💻

---

## Goal

Expand `aerobeat-vendor-modio` toward fuller mod.io coverage by implementing download-resolution and cache-policy helpers around modfile identity, expiring delivery URLs, dependency inclusion behavior, and canonical local cache metadata.

---

## Overview

The wrapper, fixture coverage, query gating, paging helpers, session handling, and live transport seam are now in a good audited state. The next highest-value mod.io-only slice is to harden how this repo models downloadable artifacts, especially because mod.io delivery URLs are expiring transport metadata rather than canonical identities.

This slice should stay fully inside `aerobeat-vendor-modio` and move the repo closer to comprehensive mod.io coverage by defining stable local download/cache semantics on top of current official mod.io behavior. That includes canonical file identity, cache keys, dependency inclusion flags, expiry awareness, local metadata shape, and tests around how the adapter resolves download requests without treating transient URLs as durable truth.

The work should continue to use current official mod.io docs as the primary source of truth, with the pinned local `projects/modio/` references as durable supporting references. Coder, QA, and auditor should each re-check current docs/reference behavior instead of trusting memory.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active download/cache plan | `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md` |
| `REF-02` | Current live transport slice | `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md` |
| `REF-03` | Current coverage expansion slice | `.plans/2026-05-02-aerobeat-vendor-modio-coverage-expansion.md` |
| `REF-04` | Current REST wrapper slice | `.plans/2026-05-02-aerobeat-vendor-modio-rest-wrapper.md` |
| `REF-05` | Current mod.io API research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-06` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-07` | Official local mod.io refs | `/home/derrick/.openclaw/workspace/projects/modio/` |
| `REF-08` | Current implementation/tests | `src/`, `.testbed/tests/` |

---

## Tasks

### Task 1: Research the download/cache coverage slice

**Bead ID:** `oc-wk0`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapper plus official mod.io docs and pinned local references to define the next highest-value download/cache helper slice. Produce a concrete implementation target list for canonical file identity, cache keys, expiry awareness, dependency inclusion behavior, local metadata shape, and integration-style tests around download resolution. Update the active plan with what actually happened and close the bead with an execution-ready recommendation.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md`

**Status:** ✅ Complete

**Results:** Researched the current repo surface against the local official `modio-docs` mirror first, then cross-checked `modio-sdk` and `modio-unity` only where workflow expectations mattered. Recommendation: the next highest-value slice should be a **dependency-aware download resolution + cache metadata helper layer**, not a downloader and not AeroBeat-side install orchestration. The repo already resolves a single `ModioDownloadRequest` from a modfile, but it still lacks a stable artifact identity model, game-level download-policy interpretation, dependency resolution semantics, and local cache metadata that can survive expiring `binary_url` values.

Execution-ready implementation target list for Task 2:

- **Highest-value slice definition**
  - Add a vendor-local helper layer that resolves one or more downloadable mod artifacts from:
    - `GET /games/{game-id}/mods/{mod-id}` current `modfile`
    - `GET /games/{game-id}/mods/{mod-id}/files`
    - `GET /games/{game-id}/mods/{mod-id}/dependencies`
  - Keep this slice metadata-only: no file downloads, no install orchestration, no AeroBeat trust policy.
  - Treat the helper output as the authoritative repo-local description of *what file artifact this is*, *whether the current delivery URL is reusable right now*, and *which dependency semantics produced the artifact set*.

- **Canonical file identity**
  - Use **provider + game_id + mod_id + modfile.id** as the stable canonical artifact identity.
  - `modfile.id` is the provider’s concrete released file identity; `filehash.md5` is an integrity field, not the primary identity.
  - Do **not** use `download.binary_url`, `filename`, or `version` as identity keys:
    - docs explicitly say `binary_url` may contain an expiring verification hash and saved/reused URLs will not work reliably in that mode
    - `filename` and `version` are descriptive metadata, not guaranteed unique identifiers
  - Extend the current download model/helper output to carry `game_id` explicitly so cache identity is self-contained and not implicit in config.
  - Preserve `filehash.md5`, `filename`, `version`, `filesize`, and `filesize_uncompressed` as integrity/display metadata attached to the canonical identity.

- **Cache keys**
  - Introduce a stable cache key derived from canonical identity only, e.g. `modio:{game_id}:{mod_id}:{file_id}`.
  - Keep delivery-URL state out of the stable cache key.
  - If a second key is needed for short-lived in-memory delivery resolution, make it explicitly ephemeral (for example by pairing the stable artifact key with `date_expires`), but do not let it replace the durable artifact key.
  - Content-addressable integrity can be layered later via `filehash.md5`, but MD5 should remain a verification attribute unless/until the repo explicitly adopts content-addressed storage.

- **Expiry awareness for expiring delivery URLs**
  - Interpret `download.binary_url` and `download.date_expires` as transport metadata only.
  - Add derived helper flags such as:
    - `is_delivery_url_expiring`
    - `delivery_expires_at`
    - `resolved_at`
    - `is_delivery_url_expired`
    - `requires_fresh_resolution`
  - Harden behavior with `GET /games/{game-id}` `api_access_options` bitwise rules:
    - `DOWNLOADS (2)` disabled => direct download URLs are verification-hash-based and should be treated as especially transient
    - `AUTHORISED_DOWNLOADS (4)` => delivery requires bearer token
    - `PAID_DOWNLOADS (8)` => delivery requires bearer token plus ownership/entitlement
  - Add derived policy fields from `api_access_options`, e.g. `allows_direct_downloads`, `requires_authenticated_download`, and `requires_entitlement_download`.
  - Even when `date_expires` is missing or zero, keep `binary_url` non-canonical. The docs only ever justify it as a delivery URL, never as a stable file locator.

- **Dependency-inclusion semantics**
  - Add wrapper support for `GET /games/{game-id}/mods/{mod-id}/dependencies` and normalize its response, including `dependency_depth`, embedded `modfile`, and other nested mod fields needed for download resolution.
  - Always send the `recursive` query parameter explicitly because the docs warn the default behavior will change in a future API version.
  - Model dependency resolution policy as an explicit local enum/flag, for example:
    - `none`
    - `immediate_only`
    - `recursive`
    - `subscription_include_dependencies`
  - Keep `POST /games/{game-id}/mods/{mod-id}/subscribe` `include_dependencies` behavior distinct from dependency-read behavior:
    - `include_dependencies` is a subscription-write option
    - dependency-read helpers should separately record whether the resolved artifact set came from direct dependency enumeration
  - Preserve the fact that the docs say the dependencies endpoint returns all dependencies regardless of status, visibility, or platform support. This repo should annotate that risk, not silently pretend the dependency list is already install-safe.
  - Normalize `GET /games/{game-id}` `dependency_option` so the helper can expose the game’s dependency policy alongside per-mod `dependencies` booleans.

- **Local metadata shape**
  - Add a vendor-local normalized metadata dictionary/model for a resolved artifact, roughly shaped like:
    - `provider`, `game_id`, `mod_id`, `file_id`, `artifact_key`
    - `filename`, `version`, `filehash_md5`, `filesize`, `filesize_uncompressed`, `metadata_blob`
    - `source` block describing whether this came from `mod_detail`, `modfiles`, or `dependencies`
    - `delivery` block with `binary_url`, `date_expires`, `resolved_at`, expiry flags, and auth/entitlement requirements
    - `dependency` block with `policy`, `is_dependency`, `parent_mod_id`, `dependency_depth`, and whether the set was recursive
    - `game_policy` block derived from `api_access_options` and `dependency_option`
  - Keep this shape provider-native and cache-policy oriented; do not map it into AeroBeat-global content identity yet.
  - Prefer additive metadata over throwing away raw provider truth that higher layers may need later.

- **Integration-style tests around download resolution**
  - Add fixture-driven tests that resolve artifact metadata from:
    - mod detail `modfile`
    - explicit modfiles list item
    - dependency list item with embedded `modfile`
  - Add tests that lock in:
    - stable artifact key ignores `binary_url`
    - `binary_url` is always marked non-canonical
    - expired `date_expires` forces `requires_fresh_resolution`
    - `api_access_options` bit flags change derived download-policy fields correctly
    - dependency resolution preserves `dependency_depth` and requested recursive mode
    - duplicate artifacts are deduped by canonical identity, not by URL or filename
    - missing required download fields (`modfile.id`, `download.binary_url`, `filehash.md5` where expected for integrity) produce a clear partial/invalid result instead of a fake-success cache record
  - Add a targeted test for the documented future-risk behavior by asserting the dependency request always serializes `recursive=true|false` explicitly.

Exact response fields / constraints to add or harden next:

- From `GET /games/{game-id}`:
  - harden `api_access_options`
  - add `dependency_option`
  - keep `platforms` available for future platform-aware download selection
- From `GET /games/{game-id}/mods/{mod-id}` and `GET /games/{game-id}/mods/{mod-id}/files` modfile payloads:
  - require/use `id`, `mod_id`, `filename`, `version`, `filesize`, `filesize_uncompressed`, `metadata_blob`
  - harden `filehash.md5`
  - harden `download.binary_url` and `download.date_expires`
  - preserve `platforms[].platform` and `platforms[].status`
- From `GET /games/{game-id}/mods/{mod-id}/dependencies`:
  - add `dependency_depth`
  - normalize embedded `modfile` so dependency artifacts can be resolved without inventing another endpoint hop
  - explicitly serialize `recursive` and document its max depth of 5 when `true`
- From `POST /games/{game-id}/mods/{mod-id}/subscribe`:
  - preserve `include_dependencies` as a boolean form field only when requested
  - do not conflate subscribe-write semantics with dependency-read semantics

Docs ambiguities / risks to carry forward:

- The dependencies endpoint warns that default recursion will change in a future API version; always serialize `recursive` explicitly.
- The docs say `recursive=true` returns dependencies of dependencies up to max depth 5, but they do not clearly state whether `include_dependencies` on subscribe is only immediate or fully recursive.
- The dependencies endpoint returns all dependencies irrespective of status, visibility, or platform support. That means a download-resolution helper can describe dependency artifacts, but should not imply those artifacts are already safe or eligible to install.
- The download docs explain expiring hashed URLs and the `api_access_options` bits, but they do not document a guaranteed TTL strategy. Refresh policy must therefore be conservative and driven by `date_expires` when present.
- The current repo fixtures use `STEAM` inside mod/modfile `platforms[].platform`, but the official platform enums in the docs list target platforms like `WINDOWS`, `MAC`, `LINUX`, console/mobile targets, etc.; `steam` is a portal concern, not a documented platform enum. Download/cache tests should switch to doc-valid platform values so we do not lock invalid provider data into the seam.

Execution-ready recommendation: Task 2 should implement a vendor-local **artifact resolution and cache metadata helper** around current modfile + dependency payloads, plus the dependency endpoint wrapper/normalizer and integration-style tests described above. That gives this repo the highest-value remaining confidence boost around download semantics while still stopping short of actual downloading, install orchestration, or `aerobeat-tool-api` mapping.

---

### Task 2: Implement download/cache helpers and tests

**Bead ID:** `oc-e0v`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the agreed download/cache helper slice using current official mod.io docs and pinned local references as source of truth. Add a dependency-aware artifact resolution + cache metadata helper layer, wrap and normalize `GET /games/{game-id}/mods/{mod-id}/dependencies`, harden game/modfile download-policy fields, and add integration-style tests around stable artifact identity, expiring delivery URLs, dependency semantics, and cache metadata without implementing actual downloading. Update README/docs/seam plan as needed, update the active plan with what actually happened, run repo-local validation/tests, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `.testbed/tests/fixtures/game.json`
- `.testbed/tests/fixtures/mod_detail.json`
- `.testbed/tests/fixtures/modfiles.json`
- `.testbed/tests/fixtures/dependencies_recursive.json`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md`

**Status:** ✅ Complete

**Results:** Implemented the metadata-only artifact/cache helper slice directly inside `ModioVendorAdapter` using the current local official `modio-docs` mirror as source of truth for `api_access_options`, `dependency_option`, `recursive` dependency semantics, and platform enums. The adapter now exposes `build_dependencies_request(...)`, `normalize_dependencies_response(...)`, `interpret_game_download_policy(...)`, artifact-key/cache-key helpers, dependency-aware artifact resolution from mod detail/modfiles/dependencies payloads, and dedupe helpers keyed by `provider + game_id + mod_id + modfile.id`. The implementation deliberately keeps `binary_url` as transient delivery metadata only, derives cacheability/partiality from identity + integrity + delivery fields, and records dependency/game-policy blocks without introducing any downloader or install orchestration. Fixtures were updated to fix doc drift by replacing the invalid `STEAM` platform enum with doc-valid values and by adding `dependency_option` plus a recursive dependencies fixture. Repo-local validation passed via `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

---

### Task 3: QA against official download/cache behavior

**Bead ID:** `oc-c8c`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the download/cache helper behavior and tests against the current official mod.io docs and pinned local references, not memory. Confirm canonical identity, expiry handling, dependency flags, game-level download policy interpretation, and local cache metadata semantics reflect current documented behavior while vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/tests/fixtures/game.json`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md`

**Status:** ✅ Complete

**Results:** Independently re-verified the metadata-only download/cache slice against the local official `modio-docs` REST mirror first, then cross-checked the audited dependency/download response shapes against the pinned `modio-sdk` and `modio-unity` refs. Confirmed the implementation still keeps dependency reads explicit (`recursive=true|false` always serialized), preserves the docs-defined recursive semantics and `dependency_depth`, derives stable artifact/cache identity from `provider + game_id + mod_id + modfile.id` instead of `binary_url`, interprets `api_access_options` / `dependency_option` into repo-local policy metadata without adding downloader/install orchestration, and keeps all vendor concerns inside this repo. Found one concrete fixture drift against the current Game Object docs: `.testbed/tests/fixtures/game.json` still used non-current `stats` keys plus a boolean `theme.dark`. Applied the minimum fix by updating that fixture to the current documented `Game Stats Object` and theme shape and by extending the adapter test to lock those fields in. Re-ran repo-local validation successfully with `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (20/20 tests passed, 319 asserts). No downloader, install orchestration, AeroBeat trust/policy logic, or cross-repo vendor leakage was introduced.

---

### Task 4: Audit against official download/cache behavior

**Bead ID:** `oc-kwd`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the download/cache helper behavior and tests against the current official mod.io docs and pinned local references. Confirm the implementation is accurate, implementation-ready, and still isolated as a vendor adapter seam. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-download-and-cache-policy.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Research, coder implementation, and QA verification are complete for the metadata-only slice. `ModioVendorAdapter` now covers dependency request building/normalization, game download-policy interpretation, canonical artifact/cache identity, dependency-aware artifact resolution, expiry/cacheability metadata, and fixture-backed dedupe/partiality tests. Independent auditor verification is still pending.

**Reference Check:** Task 1, Task 2, and Task 3 re-validated behavior against the local official `modio-docs` mirror first, with the pinned `modio-sdk` and `modio-unity` repos used only as supporting workflow references. QA also corrected one remaining fixture drift against the current documented `Game Object` stats/theme shape while preserving the earlier platform-enum and explicit dependency-recursion coverage.

**Commits:**
- Pending

**Lessons Learned:** The main remaining risk is no longer basic request construction; it is making sure higher layers do not accidentally promote transient delivery metadata into durable product identity or skip explicit dependency/download-policy checks that the vendor seam now exposes.

---

*Updated on 2026-05-02*
