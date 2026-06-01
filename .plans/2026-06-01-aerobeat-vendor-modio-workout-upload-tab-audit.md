# AeroBeat Vendor mod.io Workout Upload Tab Audit

**Date:** 2026-06-01
**Status:** Complete
**Last Updated:** 2026-06-01 08:15 EDT
**Blocked Reason:** None
**Agent:** `chip`

---

## Goal

Audit the existing default `aerobeat-vendor-modio` testbed scene so we can plan a truthful, low-regression new tab for creating and uploading workouts that requires athlete sign-in.

---

## Overview

Derrick wants to extend the current default AeroBeat mod.io proving surface with a new top-level tab dedicated to workout creation and upload. Because upload is an authenticated mutation flow, the plan needs to start from what the current testbed already does well: connection setup, email-code athlete auth, public browsing, subscribed-workout views, and existing scene/test structure.

This slice is intentionally an audit-first planning pass. Before proposing implementation tasks, we need to inspect the current scene hierarchy, controller script, any vendor/API seams already present for mod creation or modfile upload, and the current validation coverage around the default scene. The output of this audit should be a grounded execution plan that identifies reusable seams, missing provider support, UI insertion points, auth gating requirements, and likely test updates.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current default workout browser scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/workout_browser.tscn` |
| `REF-02` | Current workout browser controller | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_workout_browser_testbed.gd` |
| `REF-03` | Current workout browser state helper | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_workout_browser_state.gd` |
| `REF-04` | Repo vendor facade | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/AeroModIOManager.gd` |
| `REF-05` | Repo adapter seam | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/modio_vendor_adapter.gd` |
| `REF-06` | Current scene/test validation coverage | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/tests/` |
| `REF-07` | Prior completed browser testbed baseline | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/archive/2026-05-31-aerobeat-vendor-modio-workout-browser-download-and-session-follow-up.md` |

---

## Tasks

### Task 1: Audit the current default scene and provider seam for an authenticated workout upload tab

**Bead ID:** `oc-b4zn`
**SubAgent:** `primary` (for `research`)
**Role:** `research`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Audit the current default workout browser testbed scene and its supporting scripts/provider seam with one planning question in mind: what is the safest, most truthful way to add a new top-level tab for creating and uploading workouts that requires athlete sign-in? Inspect the scene hierarchy, controller/state flow, auth/session gating, existing mod creation or modfile upload support in the provider/adapter layer, and the current tests/validators that would need coverage updates. Update the plan with concrete findings about reusable UI/state seams, missing backend/provider support, exact insertion points for the new tab, likely validation/test impact, and recommended next execution tasks. Close the bead when done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`

**Status:** ✅ Complete

**Results:** Audit completed. The current `workout_browser.tscn` is only a thin root scene; the real surface is assembled in `modio_workout_browser_testbed.gd`, which means the safest insertion point is to extend `_build_ui()` / `_tab_container` with one more browser-level tab rather than editing a deep authored scene tree. The current browser tab order is `Public Catalog`, `Profile`, `Workout Browser`, `Subscribed Workouts`, keyed by `BROWSER_TAB_*` constants plus `ModioWorkoutBrowserState.TAB_*` strings. Auth gating already exists centrally in `_refresh_all_ui()` and `_fetch_listing()`: profile/workout/subscribed tabs are disabled unless `_state.is_authenticated()`, and unauthenticated actions show truthful copy instead of silently failing. That is the strongest reusable seam for a new upload surface - add a new `TAB_UPLOAD` state constant and browser-tab index, disable it when no athlete bearer exists, and reuse the existing auth/session status copy rather than inventing a second auth model.

Provider capability is better than the current testbed UI suggests. `AeroModIOManager` is already a generic facade over adapter builders/normalizers, and `modio_vendor_adapter.gd` already exposes the full write path needed for workout authoring: `build_add_mod_request`, `build_update_mod_request`, `build_add_modfile_request`, `build_update_modfile_request`, `build_create_multipart_upload_session_request`, multipart part upload/complete/delete helpers, `build_add_mod_media_request`, and authenticated readbacks like `build_user_mods_request` / `build_user_modfiles_request`. Existing harnesses prove the intended product truth: safe-write/live scripts create a draft mod first, then upload a build, then publish/update visibility in a later request. That means the new UI should not pretend mod creation and file upload are a single backend primitive. The most truthful first implementation is a guided two-step or staged single-tab flow: create draft workout metadata + required logo first, then upload the workout ZIP as a modfile, then optionally publish/update the mod.

There are real backend/form constraints the UI must surface up front. On create, `_normalize_mod_authoring_fields(fields, true)` requires `name`, `logo`, and `metadata_kvp`; `build_add_mod_request` is bearer-only. `build_add_modfile_request` requires exactly one of `filedata` or `upload_id`; the simple first path is `filedata` with a local ZIP path, not multipart-session orchestration. The adapter/transport accept either raw multipart part dictionaries or plain filesystem-path strings, and the current repo's own tests/harnesses use simple `"@/tmp/..."` path-style values for logo/build uploads. So the safest operator UI is explicit local file picking/path entry for both logo and workout ZIP, reusing the existing first-pass download UX pattern (`LineEdit` + `Browse…` + `FileDialog`) instead of jumping straight to chunked multipart uploads. Multipart session controls should stay out of the first tab unless a large-file requirement or platform limitation forces them, because they would add substantial state and validation complexity that the current default scene does not otherwise need.

State/UI seam findings: `ModioWorkoutBrowserState` is currently browse-centric and only tracks auth/session, listings, selected mod detail state, and per-tab queries. It has no draft-authoring fields, validation error buckets, upload-progress fields, or created-mod/modfile identifiers. Derrick clarified the preferred architecture: do **not** fake the staged authoring flow purely inside the testbed. Instead, add a dedicated upload helper under repo-root `/src/` that owns the create-draft → upload-modfile → optional publish sequencing and request-shaping, then let the testbed controller act as a thin UI client over that helper. That keeps the authoring contract reusable, easier to test, and aligned with the real project surface instead of hiding logic in `.testbed/`. `ModioWorkoutBrowserState` should therefore stay mostly browse/session-focused, with only enough upload-facing UI state to drive form fields, local validation presentation, and progress/result display. Reusing the existing `_set_status()` top banner for high-level progress is still good, but the upload tab will need its own local status/progress text because creation, file upload, and publish are multi-step mutations. Also note that `_persist_session_state()` only saves auth/session/tab restore info today; draft form persistence should be opt-in and probably skipped for the first slice to avoid storing local filesystem paths or partially authored content in the session config.

Validation/test impact is clear and bounded. Because the scene is script-built, `validate_modio_testbed_scenes.gd` and `qa_verify_scene_output_updates.gd` will need new browser-tab title/count assertions and probably a smoke assertion that the upload panel exists and is auth-gated/disabled when signed out. `test_modio_workout_browser_testbed.gd` will need new focused coverage for: upload tab visibility/disabled state, initial field defaults, truthful validation when logo/metadata/zip are missing, and the controller's interaction with the new upload helper. The dedicated `/src/` helper should also get its own unit coverage for create→upload→publish sequencing, required field normalization, and failure propagation. Provider-layer coverage is already strong in `test_modio_vendor_adapter.gd`, `test_modio_http_transport.gd`, and related harnesses, so the new low-level tests should target the dedicated upload helper rather than re-testing raw adapter builders everywhere.

Recommended next execution tasks: (1) add a coder slice that introduces a repo-root `/src/` upload helper responsible for staged workout authoring orchestration over the existing adapter seam; (2) add helper-level tests for required metadata/logo/ZIP validation, request sequencing, and truthful error handling; (3) add `TAB_UPLOAD`/`BROWSER_TAB_UPLOAD_INDEX` in the testbed controller and build an auth-gated `Upload Workout` tab that calls the helper rather than embedding the backend flow locally; (4) add controller tests + scene QA validation for the new tab and auth gating; (5) run existing validators plus focused helper/controller upload tests before any live harness work; and (6) only after the local flow is stable, consider a follow-up QA/audit slice against a disposable sandbox workout using the existing safe-write/live harness patterns.

### Task 2: Implement the reusable upload helper and auth-gated Upload Workout tab

**Bead ID:** `oc-cu2r`
**SubAgent:** `primary` (for `coder`)
**Role:** `coder`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-cu2r` on start with `bd update oc-cu2r --status in_progress --json`. Implement the approved architecture for workout uploads. Add a dedicated repo-root `/src/` helper that owns the staged mod.io authoring flow for workouts: create draft mod, upload workout ZIP as modfile, and optionally update/publish the mod using the existing adapter/facade seam. Keep this helper reusable and testable; do not bury the orchestration solely in `.testbed/`. Then add a new auth-gated top-level `Upload Workout` tab to the default testbed browser scene/controller that acts as a thin UI client over that helper. Reuse the existing explicit local path + browse UX pattern for required logo and ZIP inputs, keep the UI truthful about required athlete sign-in and staged authoring, and avoid introducing multipart-session complexity in this first slice unless the existing seam forces it. Update/add focused tests and validators, run all relevant repo validation, update this plan with what actually changed, commit and push by default, then close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `src/`
- `tests/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/scripts/modio_workout_browser_state.gd`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_workout_upload_flow.gd`
- `src/modio_workout_upload_flow.gd`

**Status:** ✅ Complete

**Results:** Implemented the coder slice end-to-end. Added repo-root `src/modio_workout_upload_flow.gd`, a reusable/testable helper that validates operator input, normalizes local logo + ZIP paths into documented mod.io multipart payloads, and owns the staged create-draft → upload-modfile → optional publish orchestration through `AeroModIOManager`/`modio_vendor_adapter.gd` instead of hiding that contract inside `.testbed/`. The helper surfaces truthful validation/auth failures, stops on the first failed stage, and returns structured step results for UI consumers and tests.

The default browser controller now exposes a new auth-gated top-level `Upload Workout` tab. The new tab reuses the existing explicit local path UX pattern (`LineEdit` + `Browse…` + filesystem `FileDialog`) for required logo and workout ZIP selection, keeps athlete-auth truth visible in the intro copy and disabled state, and acts only as a thin client over the reusable helper. `ModioWorkoutBrowserState` gained the minimal upload-form/result state needed to drive this UI without widening session persistence into local-path draft storage.

Focused validation was added at both seams: `test_modio_workout_upload_flow.gd` covers request sequencing, required validation, and failure short-circuiting; `test_modio_workout_browser_testbed.gd` now covers upload-tab auth gating plus helper invocation/reporting; and the existing scene validators/QA scripts now assert the new upload controls and top-level tab. Coder-owned validation passed with `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

---

### Task 3: QA the reusable upload helper and Upload Workout tab

**Bead ID:** `oc-5gtt`
**SubAgent:** `primary` (for `qa`)
**Role:** `qa`
**References:** `REF-01`, `REF-02`, `REF-04`, `REF-05`, `REF-06`, `REF-07`
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-5gtt` on start with `bd update oc-5gtt --status in_progress --json`. Verify the new reusable upload helper and auth-gated `Upload Workout` tab behave truthfully and do not regress the existing browser scene. Run the relevant validators/tests, confirm signed-out users cannot use athlete-only upload flows, confirm required field validation is truthful, and confirm the staged create → upload → optional publish contract is reflected accurately in the UI and implementation. Update this plan with QA findings, commit and push by default if you make QA-sized fixes, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`
- `tests/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`
- `tests/`

**Status:** ✅ Complete

**Results:** QA verified the implementation without needing a fix. The reusable seam claim is true in the default browser surface: the testbed preloads `src/modio_workout_upload_flow.gd`, stores it in `_upload_flow`, and the upload button delegates to `_upload_flow.submit_workout(_manager, _state.upload_draft)` rather than rebuilding `build_add_mod_request` / `build_add_modfile_request` / `build_update_mod_request` sequencing locally in the controller. Signed-out behavior is truthful at both the UI and handler layers: the `Upload Workout` browser tab starts disabled when no bearer token is present, the submit button is disabled, the upload intro/status copy explains that athlete sign-in is required, and `_on_upload_workout_pressed()` still hard-stops with an auth failure if invoked programmatically while signed out. Required field validation is also truthful in the helper: `prepare_submission()` blocks missing `name`, empty `metadata_kvp`, missing logo paths, missing ZIP paths, nonexistent files, and non-`.zip` workout archives before any network call runs.

The staged authoring contract is reflected accurately in both implementation and operator copy. `submit_workout()` performs `create_draft` first, `upload_modfile` second, and `publish_mod` only when `publish_after_upload` is enabled; failures short-circuit at the first broken stage and the success message distinguishes draft-only completion from published completion. The upload tab copy matches that contract instead of implying a single backend primitive. Regression coverage stayed green across both the focused upload/browser checks and the broader browser scene surface: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, the targeted GUT pass for `test_modio_workout_upload_flow.gd` + `test_modio_workout_browser_testbed.gd`, and the full `addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite all passed. The only note worth handing to audit is a pre-existing Godot/GUT warning in `test_modio_vendor_adapter.gd` (`Float/Int comparison. Got FLOAT but expected INT`); it did not fail the suite and is outside this upload-tab QA slice.

---

### Task 4: Audit the upload helper and Upload Workout tab for truthfulness

**Bead ID:** `oc-a3zj`
**SubAgent:** `primary` (for `auditor`)
**Role:** `auditor`
**References:** `REF-01`, `REF-02`, `REF-04`, `REF-05`, `REF-06`, `REF-07`
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-a3zj` on start with `bd update oc-a3zj --status in_progress --json`. Independently truth-check the final implementation against this approved plan and the real mod.io seam. Verify that the new repo-root upload helper really owns the staged create/upload/publish orchestration, that the testbed is a thin client over that helper, that the `Upload Workout` tab is correctly auth-gated, and that validation/test evidence supports the claims. Update this plan with the final audit verdict, commit and push by default if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`
- `tests/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `src/`
- `tests/`

**Status:** ✅ Complete

**Results:** Independent audit passed after one audit-sized fix to the validation seam. The core implementation claims are true against the code and the documented mod.io write surface. The reusable repo-root helper in `src/modio_workout_upload_flow.gd` really owns the staged authoring contract: it validates operator fields up front, normalizes local logo/ZIP paths into the adapter’s documented multipart shapes, issues `build_add_mod_request` first, `build_add_modfile_request` second, and only performs `build_update_mod_request` for `status=1` / `visible=1` when `publish_after_upload` is enabled. Failure handling is truthful: auth is gated before writes, validation stops before network calls, and a failed modfile upload short-circuits before publish. That satisfies the plan’s requirement that the staged create/upload/publish orchestration live in repo-root `/src/` rather than being reconstructed ad hoc in the scene controller.

The default browser testbed is also a thin client over that helper rather than a duplicate backend seam. In `.testbed/scripts/modio_workout_browser_testbed.gd`, the controller preloads the helper once into `_upload_flow`, collects UI draft values into `_state.upload_draft`, and delegates submission through `_upload_flow.submit_workout(_manager, _state.upload_draft)`. The controller does not locally rebuild the create-mod / add-modfile / publish request sequence. The `Upload Workout` tab is truthfully auth-gated at both levels checked in the plan: `_refresh_all_ui()` disables the tab and submit button when no bearer token is present, while `_on_upload_workout_pressed()` still returns an explicit auth error if invoked while signed out. The tab copy and result text stay honest about this being a staged draft-upload-publish workflow, not a single opaque backend primitive.

The audit-sized defect was in the evidence, not the feature seam. Re-running the full GUT suite surfaced that `test_modio_workout_browser_testbed.gd` depended on the real repo session config path and could report inconsistent results depending on ambient operator state. I fixed that by letting `modio_workout_browser_testbed.gd` accept test-only config-path overrides and updating the browser testbed spec to use an isolated `user://` session file plus in-memory restored-state assertions. After that fix, the validation story matched the claims again: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, the focused GUT upload/browser pass, and the full `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite all passed. The only remaining note is the pre-existing non-failing GUT warning in `test_modio_vendor_adapter.gd` about a float/int comparison, which is outside this upload-tab slice.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The full coder → QA → auditor loop is now complete. The repo ships a reusable repo-root staged workout upload helper in `src/modio_workout_upload_flow.gd`, an auth-gated `Upload Workout` tab in the default browser testbed that consumes that helper as a thin client, and focused helper/controller/scene validation that now stays green both in targeted runs and across the full `.testbed` GUT suite.

**Reference Check:** `REF-01` through `REF-07` are satisfied. `REF-04`/`REF-05` remain the source of truth for the real mod.io write seam, and the audit confirmed the staged create → upload → optional publish orchestration lives in the reusable helper rather than being duplicated inside the testbed. `REF-01` through `REF-03` remain aligned with the browser-scene insertion, restored session behavior, and auth gating. `REF-06` now truthfully supports the claims after the audit fix isolated the browser testbed session-path dependency from ambient operator state.

**Commits:**
- `6212010` - `Add staged workout upload helper and testbed tab`
- `47ea25c` - `Record QA verification for workout upload tab`
- `(pending local commit)` - Audit fix for isolated testbed session config overrides and final audit plan update

**Lessons Learned:** The real risk in this slice was less about missing mod.io backend coverage and more about keeping the operator-facing surface honest. The staged authoring contract needed to live in one reusable seam and the validation needed to be isolated from local machine/session state. Audit caught that second part: even when the feature implementation was sound, brittle evidence can undermine the claim. Isolating config paths for the browser testbed made the full-suite proof as truthful as the upload helper itself.
