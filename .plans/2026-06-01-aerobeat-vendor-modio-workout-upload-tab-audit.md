# AeroBeat Vendor mod.io Workout Upload Tab Audit

**Date:** 2026-06-01
**Status:** In Progress
**Last Updated:** 2026-06-01 13:57 EDT
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

### Task 5: Refine the Upload Workout tab layout and viewport fit

**Bead ID:** `oc-gu2z`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-gu2z` on start with `bd update oc-gu2z --status in_progress --json`. Refine the `Upload Workout` tab UI per Derrick's review. Reduce vertical space by placing these rows side by side, similar to the existing `Workout Name | Name ID` layout: (a) `Summary | Description`, (b) `Metadata | Tags`, and (c) `Workout Logo | Workout ZIP`. Ensure the upload action remains reachable inside the viewport; if layout compression alone is not enough, add vertical scrolling to the Upload Workout tab UI. Preserve the existing auth gating, staged upload truthfulness, and helper-driven seam. Update/add tests or validators if needed, run relevant validation, update this plan with what actually changed, commit and push by default, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`

**Status:** ✅ Complete

**Results:** Refined the Upload Workout tab layout to reduce vertical space without touching the auth or backend seams. The form now keeps the existing `Workout Name | Name ID` row and adds the requested paired rows for `Summary | Description`, `Metadata | Tags`, and `Workout Logo | Workout ZIP`, while keeping `Version | Changelog` side by side as before. To make the primary action reliably reachable in viewport-limited test runs, the tab content now lives inside a dedicated vertical `ScrollContainer` (`UploadWorkoutScroll`) so the submit button and result/status region remain accessible even when the operator window is short.

The helper-driven staged upload contract is unchanged: the controller still gathers form data into `_state.upload_draft` and delegates submission through `_upload_flow.submit_workout(...)`, and the auth gating remains centralized in `_refresh_all_ui()` / `_on_upload_workout_pressed()`. Validation coverage was updated to assert the new scroll container and the three paired rows in the upload tab surface. Coder-owned validation passed with `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_modio_workout_browser_testbed.gd -gexit`.

---

### Task 6: QA the Upload Workout tab layout refinement

**Bead ID:** `oc-co2m`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-co2m` on start with `bd update oc-co2m --status in_progress --json`. Verify the Upload Workout tab layout refinement: the requested side-by-side rows are present, the upload action is reachable within the viewport, vertical scrolling exists if needed, and auth gating/validation/staged upload truthfulness did not regress. Run relevant validators/tests, record QA findings in this plan, commit and push by default if QA-sized fixes are needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`

**Status:** ✅ Complete

**Results:** QA passed without needing a fix. The requested paired rows are present in the Upload Workout tab surface and verified by both code inspection and automation: `UploadWorkoutSummaryDescriptionRow` contains `Summary | Description`, `UploadWorkoutMetadataTagsRow` contains `Metadata | Tags`, and `UploadWorkoutFileRow` contains `Workout Logo | Workout ZIP`. The controller also now wraps the tab body in a real vertical `UploadWorkoutScroll` container, and the scene validators/QA checks assert that scroll container plus the three paired rows exist.

Viewport behavior is truthful rather than cosmetic. Focused Godot QA in a constrained `960x540` host confirmed the submit action is not always initially visible, but the `UploadWorkoutScroll` container exposes an active vertical scrollbar (`max=791`, `page=352` in the probe) and scrolling to the bottom brings `UploadWorkoutSubmitButton` fully into view. That satisfies Derrick’s requirement that the action remain reachable inside the viewport and that scrolling only exist when it is genuinely needed.

Regression coverage stayed green for the auth/helper seam. Signed-out state still disables the `Upload Workout` tab and submit button, the intro/status copy still describes athlete sign-in and the staged draft → ZIP upload → optional publish contract truthfully, and the controller still delegates through the reusable upload helper instead of rebuilding the backend flow locally. QA reran: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and the targeted GUT pass for `res://tests/test_modio_workout_upload_flow.gd` plus `res://tests/test_modio_workout_browser_testbed.gd`. All passed. One existing non-failing GUT leak/resources-at-exit warning remains in the test environment, but it did not affect results and no upload-tab defect was found in this QA slice.

---

### Task 7: Audit the Upload Workout tab layout refinement

**Bead ID:** `oc-ygla`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-ygla` on start with `bd update oc-ygla --status in_progress --json`. Independently audit the Upload Workout tab layout refinement for truthfulness, viewport usability, and regression-free behavior. Verify the requested side-by-side row layout landed, confirm the upload action is reachable and vertical scrolling exists if needed, verify the UI still delegates through the helper-driven seam, and ensure validation evidence supports the claim. Update this plan with the final audit verdict, commit and push by default if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`

**Status:** ✅ Complete

**Results:** Independent audit passed without needing an audit-sized fix. The requested side-by-side rows are present in the real controller-built UI: `UploadWorkoutSummaryDescriptionRow` contains the `Summary` line edit and `Description` text box, `UploadWorkoutMetadataTagsRow` contains `Metadata KVP` and `Tags`, and `UploadWorkoutFileRow` contains the `Workout Logo` and `Workout ZIP` file controls. The controller also wraps the Upload Workout body in a dedicated `UploadWorkoutScroll` `ScrollContainer`, so the primary action is not stranded below the viewport when the host window is short.

I independently rechecked the viewport usability claim with a constrained `960x540` headless probe against the live scene. In that state, the upload scroll region reports `max=791`, `page=352`, and an active visible vertical scrollbar; the submit button starts below the visible region at `y=847`, then becomes visible at `y=408` after scrolling to the bottom. That confirms the refinement is truthful: compression alone does not fully keep the button in-frame at a short height, but the added vertical scrolling makes the action reachable as requested.

The auth/helper seam did not regress. `.testbed/scripts/modio_workout_browser_testbed.gd` still disables the Upload Workout tab and submit button when `_state.is_authenticated()` is false, and `_on_upload_workout_pressed()` still hard-stops with an auth message if invoked while signed out. The controller remains a thin client over `src/modio_workout_upload_flow.gd`: it reads form state into `_state.upload_draft` and delegates the staged create-draft → upload-modfile → optional publish flow through `_upload_flow.submit_workout(_manager, _state.upload_draft)` instead of rebuilding request sequencing locally.

Validation evidence supports the claim. I reran `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and the targeted GUT pass for `res://tests/test_modio_workout_upload_flow.gd` plus `res://tests/test_modio_workout_browser_testbed.gd`; all passed. The targeted browser test and validators assert the new scroll container, the three paired rows, auth gating, and helper delegation. The only remaining warning is the known non-failing GUT leak/resources-at-exit warning in the browser test environment, which did not fail this audit slice.

---

### Task 8: Research mod.io metadata vs tags semantics for truthful workout-upload UI copy

**Bead ID:** `oc-3gwz`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-3gwz` on start with `bd update oc-3gwz --status in_progress --json`. Research the exact semantics of mod.io mod authoring `metadata` / `metadata_kvp` versus `tags` using current online mod.io API references plus the local repo/docs. Determine which field should carry AeroBeat taxonomy values like `feature`, `difficulty`, and `genre`; determine what `metadata` is actually intended for in mod authoring beyond just being key/value pairs; and identify whether the current Upload Workout tab examples/copy are misleading. Update this plan with a docs-backed answer and concrete UI wording/example recommendations, then close the bead with a clear reason. Do not implement the UI change yet; research and plan only.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`

**Status:** ✅ Complete

**Results:** Research completed against both the current online mod.io docs and the local AeroBeat/repo trail. **Documented mod.io facts:** (1) `POST /games/:game-id/mods/:mod-id/tags` is for a mod's profile tags, and mod.io explicitly says you may only add tags allowed by the parent game's `tag_options`; those game tag groups can be public, hidden-for-filtering, or locked, and the filtering docs/examples treat `tags` as a first-class browse field. (2) `POST /games/:game-id/mods/:mod-id/metadatakvp` is for **searchable key-value metadata**; mod.io says it is useful to define how a mod works or other information needed to display/manage the mod, gives gameplay-property examples like gravity and fire rate, and explicitly recommends the upload tool define/submit that metadata **behind the scenes** because invalid values may cause problems. (3) The mod create/edit surface also exposes repeated `metadata[]` parts for profile authoring plus optional `metadata_blob`, so the word `metadata` is overloaded in mod.io; in this Upload Workout tab the current `Metadata KVP` field maps to the searchable KVP form, not to `metadata_blob`.

**Local AeroBeat facts:** `aerobeat-docs/docs/architecture/modio-tag-mapping.md` already locks the public AeroBeat storefront taxonomy to `feature`, `difficulty`, and `genre`, with `trust_state` hidden/admin-only. The prior live-harness evidence in the repo plan trail also confirms the current sandbox game exposes those tag groups and that valid mod tag writes used raw tag values like `boxing`, `easy`, and `edm` — not `feature=boxing` style pairs. That means AeroBeat taxonomy values belong in **mod.io tags**, not in `metadata_kvp`. More specifically: `feature` should be a single public tag value, `difficulty` should be a single public tag value, and `genre` may be multi-select; the per-mod payload should carry the allowed tag values themselves while the grouping/category comes from the game's configured `tag_options`.

**Docs-backed interpretation / AeroBeat recommendation:** mod.io `metadata_kvp` should be treated as structured implementation or operational metadata, not as the primary athlete-facing taxonomy surface. The docs support using it for mod behavior/configuration and for internal display/management/search, but they do **not** present it as the normal public browse taxonomy mechanism. For AeroBeat, that makes `metadata_kvp` a better home for hidden/provider-side structured fields only if we truly need them (for example tool-generated identifiers or controlled workflow data), while `feature`, `difficulty`, and `genre` should stay in tags. The docs are somewhat ambiguous about the exact expected delimiter convention inside the authored string values because the REST prose says key-value pairs while different local tests/examples use both `key:value` and `key=value`; the important docs-stable semantic point is that this field is KVP metadata for behavior/management, not public taxonomy.

**Current Upload Workout tab copy is misleading in two ways.** First, the placeholder `difficulty=intermediate` under `Metadata KVP` teaches the wrong bucket: `difficulty` is an AeroBeat public taxonomy value and should be a tag, not metadata. Second, the optional tags placeholder `cardio, endurance` does not match the currently locked AeroBeat public taxonomy groups/values; the local mapping doc and sandbox evidence point toward values such as `boxing`, `easy|medium|hard|pro`, and approved genres like `edm`, not generic freeform descriptors. The current copy also risks implying that creators should hand-author freeform provider metadata, even though mod.io recommends upload tools submit that metadata behind the scenes.

**Concrete UI wording/example recommendations (research only; not implemented here):**
- Rename or relabel the taxonomy-facing field away from generic freeform `Tags (optional, comma-separated)` toward something like **`Discovery Tags (required/optional, selected from the game's configured taxonomy)`**.
- If the UI must stay text-first temporarily, use truthful example copy such as **`boxing, medium, edm`** and add helper text like **`Use allowed mod.io tag values from the game's Feature / Difficulty / Genre groups. Do not type feature= or difficulty= here.`**
- Stronger recommendation: replace the freeform taxonomy text box with grouped controls sourced from `GET /games/{game-id}/tags` / game `tag_options` so the operator picks `feature`, `difficulty`, and `genre` values explicitly instead of guessing valid strings.
- Reword the metadata field to make its role narrower and less taxonomy-like, e.g. **`Advanced Metadata KVP (provider-side structured fields; one key=value per line)`** with helper text like **`Use only for structured mod behavior/management data when needed. Public workout discovery values like feature, difficulty, and genre belong in Tags.`**
- If AeroBeat does not currently need creator-authored KVP at all, best recommendation is to hide/collapse this field in the first-pass upload form and let the tool populate any required metadata behind the scenes.
- Remove the current `coach=...` style public-facing example unless AeroBeat explicitly decides that coach metadata should live in mod.io KVP; the current docs/mapping trail does not justify it as public upload guidance.

Bottom line: **AeroBeat taxonomy belongs in mod.io tags; `metadata_kvp` is for structured searchable metadata about how the mod works or how the tool/provider manages it; and the current upload-form placeholders should be revised because they currently teach the wrong separation.**


### Task 9: Add truthful metadata examples and seed device-hardware metadata for upload testing

**Bead ID:** `oc-8yyp`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Pending final execution approval. In `aerobeat-vendor-modio`, refine the Upload Workout testbed so metadata remains present for vendor-seam testing, but with truthful example content instead of guessed taxonomy. Seed a fake testbed metadata example including `aerobeat_version=1.0.0`, and wire in a path for hardware-derived metadata from `aerobeat-tool-device-detection` via a dedicated extension/helper there that can transform detected-device JSON into metadata KVP pairs suitable for upload testing. After updating `aerobeat-tool-device-detection`, refresh the dependency in `aerobeat-vendor-modio` using the canonical `godotenv-sync` script/workflow rather than the vanilla `godotenv` CLI, to avoid noise/UID issues. Preserve the current helper-driven upload seam and keep taxonomy in Tags rather than Metadata KVP.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`
- `../aerobeat-tool-device-detection/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/addons.jsonc`
- `.testbed/scripts/modio_workout_browser_state.gd`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`
- `../aerobeat-tool-device-detection/src/AeroDeviceDetectionModioMetadata.gd`
- `../aerobeat-tool-device-detection/.testbed/tests/test_device_detection_contract.gd`

**Status:** ✅ Complete

**Results:** Implemented the coder slice across both repos without changing the existing helper-driven upload seam or auth gating. In `aerobeat-tool-device-detection`, I added `src/AeroDeviceDetectionModioMetadata.gd`, a dedicated helper that converts either detected-device dictionaries or JSON strings into normalized mod.io upload metadata KVP pairs, plus contract coverage in `.testbed/tests/test_device_detection_contract.gd`. The helper intentionally keeps only stable/useful hardware fields for upload testing: `device_profile`, `device_platform`, `device_os_name`, `device_os_version`, `device_cpu_name`, `device_gpu_vendor`, `device_gpu_name`, `device_rendering_method`, `device_display_server`, `device_screen_width`, `device_screen_height`, and `device_memory_gb`. It deliberately excludes noisy/ephemeral/privacy-heavy fields such as `vendor_id`, `device_name`, `model_name`, `renderer_name`, runtime `tags`, nested `metadata`, request/meta timestamps, and other raw response scaffolding.

In `aerobeat-vendor-modio`, the Upload Workout testbed now seeds truthful metadata instead of guessed taxonomy. The seeded metadata examples are: `aerobeat_version=1.0.0`, `upload_surface=modio_workout_browser_testbed`, `upload_flow=staged_draft_then_modfile`, plus deterministic device-derived KVP lines generated through the new helper from a fixed Surface Pro 8-style upload fixture. Public taxonomy stayed in Tags instead of Metadata KVP: the draft/tag defaults and field copy now use `boxing, easy, edm`, matching the current AeroBeat `feature` / `difficulty` / `genre` truth from `REF-07`. The testbed continues to delegate submissions through `_upload_flow.submit_workout(_manager, _state.upload_draft)` rather than rebuilding backend request orchestration in the controller.

Dependency refresh was performed with the canonical safe workflow Derrick requested: after pushing `aerobeat-tool-device-detection` `main`, I ran `python3 /home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed` (not the vanilla `godotenv` CLI) so the vendor testbed reinstalled the new addon cleanly and scrubbed UID noise as part of the same pass. Validation run for this coder slice: in `aerobeat-tool-device-detection`, `godot --headless --path .testbed --import` and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`; in `aerobeat-vendor-modio`, `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and targeted GUT for `res://tests/test_modio_workout_upload_flow.gd` plus `res://tests/test_modio_workout_browser_testbed.gd`. All passed; the existing non-failing ObjectDB/resource-at-exit warning still appears in the vendor GUT environment.

---

### Task 10: QA truthful upload metadata seeding and device-derived metadata path

**Bead ID:** `oc-7yf6`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-7yf6` on start with `bd update oc-7yf6 --status in_progress --json`. Verify that the Upload Workout testbed now uses truthful seeded metadata examples, that taxonomy remains in Tags rather than Metadata KVP, that the device-derived metadata path is wired correctly from `aerobeat-tool-device-detection`, and that the dependency refresh used `godotenv-sync` rather than vanilla `godotenv`. Run relevant validation/tests, update this plan with QA findings, commit/push by default only if QA-sized fixes are needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`
- `../aerobeat-tool-device-detection/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`
- `../aerobeat-tool-device-detection/`

**Status:** ✅ Complete

**Results:** QA found one real cross-repo defect and fixed it before closing the slice. The core product claims in `aerobeat-vendor-modio` are true: the Upload Workout testbed seeds truthful metadata examples including `aerobeat_version=1.0.0`, `upload_surface=modio_workout_browser_testbed`, and `upload_flow=staged_draft_then_modfile`; the default/example tags remain taxonomy values in tag space (`boxing, easy, edm`) rather than being taught through `metadata_kvp`; and the browser testbed still delegates device-derived metadata seeding through `AeroDeviceDetectionModioMetadata.build_metadata_kvp_pairs(...)` instead of hardcoding the device KVP list locally. The helper output is also truthfully scoped: only stable/useful hardware fields are emitted (`profile`, platform/OS, CPU, GPU vendor/name, rendering method, display server, screen width/height, memory), while noisy or privacy-heavy fields such as `vendor_id`, `device_name`, `model_name`, `renderer_name`, runtime `tags`, nested runtime `metadata`, and request/meta timestamps stay excluded. The taxonomy source-of-truth in `aerobeat-docs/docs/architecture/modio-tag-mapping.md` still matches the seeded tag example and does not leak into KVP metadata.

The QA-sized defect was in the upstream helper packaging/validation seam, not the vendor UI. Running the full `aerobeat-tool-device-detection` GUT suite exposed that `src/AeroDeviceDetectionModioMetadata.gd` registered a global `class_name` that collided with a stale addon-class cache path in the testbed, which broke the new static helper tests even though the helper logic itself was correct. I removed the unused global class registration in `aerobeat-tool-device-detection/src/AeroDeviceDetectionModioMetadata.gd`, committed/pushed that repo (`9d13c89` - `Avoid global class collision in modio metadata helper`), then refreshed the vendor testbed dependency with the requested canonical workflow: `python3 /home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed`. That gives QA direct evidence that this slice used `godotenv-sync` rather than vanilla `godotenv`, and the refreshed installed addon copy in `.testbed/addons/aerobeat-tool-device-detection/` now matches the fixed upstream helper.

Post-fix validation passed in both repos. In `aerobeat-tool-device-detection`, `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` passed all 11 tests, including the metadata helper contract checks. In `aerobeat-vendor-modio`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and the targeted GUT pass for `res://tests/test_modio_workout_upload_flow.gd` plus `res://tests/test_modio_workout_browser_testbed.gd` all passed after the dependency refresh. The only remaining notes are the known non-failing vendor-side ObjectDB/resources-at-exit warnings during headless QA; no upload auth, tags, helper wiring, or metadata regression remained after the fix.

---

### Task 11: Audit truthful upload metadata seeding and device-derived metadata path

**Bead ID:** `oc-2hld`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-2hld` on start with `bd update oc-2hld --status in_progress --json`. Independently audit the seeded metadata examples and device-derived metadata path for truthfulness and cross-repo seam correctness. Verify that metadata examples are truthful, tags remain taxonomy-only, device JSON is normalized into metadata KVPs through the intended helper seam, and validation evidence supports the claim. Update this plan with the final audit verdict, commit/push by default only if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`
- `../aerobeat-tool-device-detection/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`
- `../aerobeat-tool-device-detection/`

**Status:** ✅ Complete

**Results:** Independent audit passed without needing an additional audit-sized fix. The seeded upload metadata defaults in `.testbed/scripts/modio_workout_browser_testbed.gd` are truthful and match the approved intent: `_default_upload_metadata_text()` always starts with `aerobeat_version=1.0.0`, `upload_surface=modio_workout_browser_testbed`, and `upload_flow=staged_draft_then_modfile`, then appends deterministic device-derived KVP lines from `AeroDeviceDetectionModioMetadata.build_metadata_kvp_pairs(UPLOAD_METADATA_DEVICE_SEED)`. Rechecking the real seeded fixture confirms the intended Surface Pro 8-style values are present in metadata space, including `device_profile=surface_pro_8_upload_fixture`, `device_platform=windows`, `device_os_name=Windows`, `device_os_version=11`, `device_cpu_name=11th Gen Intel(R) Core(TM) i7-1185G7`, `device_gpu_vendor=Intel`, `device_gpu_name=Intel Iris Xe Graphics`, `device_rendering_method=forward_plus`, `device_display_server=windows`, `device_screen_width=2880`, `device_screen_height=1920`, and `device_memory_gb=16`.

Tags also remain taxonomy-only and aligned with the AeroBeat taxonomy source of truth. The upload UI now labels tags as `taxonomy/discovery`, seeds the default/example tag string as `boxing, easy, edm`, and keeps those values in tag space rather than teaching them through `metadata_kvp`. That matches `/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/modio-tag-mapping.md`, which defines public launch taxonomy around `feature`, `difficulty`, and `genre`, with `boxing`, `easy|medium|hard|pro`, and approved genres such as `edm` living in mod.io tags instead of provider metadata KVP fields.

The cross-repo helper seam is real and correctly scoped. `aerobeat-vendor-modio` preloads `res://addons/aerobeat-tool-device-detection/src/AeroDeviceDetectionModioMetadata.gd` and uses `AeroDeviceDetectionModioMetadata.build_metadata_kvp_pairs(...)` directly when constructing the seeded metadata text, so device JSON normalization is not duplicated locally. In `aerobeat-tool-device-detection/src/AeroDeviceDetectionModioMetadata.gd`, the helper normalizes either response dictionaries or JSON strings through the existing device-detection normalization seam and intentionally emits only the approved stable/useful fields: `profile`, platform/OS, CPU, GPU vendor/name, rendering method, display server, screen width/height, and memory. It intentionally excludes the noisy/privacy-heavy/raw fields called out in the plan goals, including `vendor_id`, `device_name`, `model_name`, `renderer_name`, runtime `tags`, nested `metadata`, and request/meta timestamps.

Dependency refresh evidence is also consistent with the claim. The active plan records the explicit `python3 /home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed` refresh step after the upstream helper fix, `.testbed/addons.jsonc` points this dependency at the upstream `aerobeat-tool-device-detection` repo, and the installed addon copy in `aerobeat-vendor-modio/.testbed/addons/aerobeat-tool-device-detection/src/AeroDeviceDetectionModioMetadata.gd` is byte-identical to the upstream source helper. I did not find contrary evidence that vanilla `godotenv` was used for this slice.

Validation evidence supports the final claim across both repos. I reran `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` in `aerobeat-tool-device-detection` (11/11 passing, including the metadata helper contract tests), plus `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and the targeted GUT pass for `res://tests/test_modio_workout_upload_flow.gd` + `res://tests/test_modio_workout_browser_testbed.gd` in `aerobeat-vendor-modio` (all passing). The vendor QA script still emits the known non-failing ObjectDB/resource-at-exit warning, but it did not fail the run and no truthfulness or seam regression was found in this audit slice.

---

### Task 12: Audit auth token lifetime configuration and regeneration behavior

**Bead ID:** `oc-f07m`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Pending final execution approval. In `aerobeat-vendor-modio`, audit the current auth/session token configuration and runtime behavior to determine why athlete sign-in appears to require a fresh token on each test run despite the intended one-year max duration. Inspect the testbed controller/state persistence, any token-expiry request parameters, local session persistence files, and relevant provider/adapter seams. Determine whether the issue is request TTL configuration, auth-code/token exchange behavior, state persistence not restoring the token, or some other expiration/reset bug. Update this plan with concrete findings and recommended fix slices before any implementation.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`

**Status:** ✅ Complete

**Results:** Research audit completed without code changes. The current email-code request path is already asking mod.io for the longest direct bearer lifetime this seam can truthfully request: `_on_exchange_code_pressed()` computes `requested_expiry = Time.get_unix_time_from_system() + AUTH_TOKEN_REQUEST_MAX_SECONDS`, where `AUTH_TOKEN_REQUEST_MAX_SECONDS = 31536000`, and `src/modio_vendor_adapter.gd` clamps `build_auth_exchange_request(..., date_expires)` through `_sanitize_requested_expiry(..., COMMON_YEAR_SECONDS)` before sending `POST /oauth/emailexchange`. That means the local request-TTL configuration is not the bug; the code is already requesting roughly one common year and the adapter test coverage asserts the clamp behavior.

Session persistence/restoration is also working, but it is intentionally thin and currently blind to real expiry. `_persist_session_state()` writes only `access_token`, `user_id`, `email`, `last_requested_email`, and `browser_tab` into `.testbed/configs/modio.session.local.cfg`, `ModioEnvLoader.build_client_config()` restores `access_token` + `user_id` from that file on startup, and `_restore_saved_runtime_state()` immediately attempts `/me` rehydration when a stored token exists. The current local session file proves the token is being persisted between runs, and neither startup nor refresh code auto-clears it. The real gap is observability + stale-token handling: `_on_exchange_code_pressed()` stores only `payload.access_token` and ignores `payload.date_expires`; `ModioWorkoutBrowserState` has no expiry field; `ModioSessionConfigStore` / `ModioEnvLoader` never persist or restore expiry metadata; and `_refresh_profile_data(..., restoring_saved_token=true)` treats a failed `/me` as “re-run email-code auth if this session is stale” without clearing/marking the token as expired. So the current behavior can feel like “needs a fresh token every run,” but the code audit says that is not caused by per-run local reset. It is more likely either (a) mod.io is returning/revoking a shorter-lived token than requested, or (b) an older token was minted before the one-year request path and now fails on restore, while the UI has no stored `date_expires` evidence to explain that truthfully.

Recommended fix slices only: (1) normalize and persist the auth-exchange expiry (`date_expires` / `expires_at`) alongside `access_token`, then restore it into browser state on startup; (2) make startup/auth UI explicitly expiry-aware so the scene can say “stored token expired at X” instead of generic stale-session copy; (3) on restore-time authenticated-read failure that is clearly auth-related, clear the persisted bearer/session keys or mark them invalid so the next run does not present a ghost-authenticated state; and (4) add focused tests covering expiry persistence, expiry-aware restore, and stale-token failure handling. Net verdict: not a request TTL bug, not a session-file write bug, and not a startup restore omission for the token itself; the likely root problem is provider-side token lifetime/invalidity combined with missing local expiry persistence and stale-token invalidation logic.

---

### Task 13: Persist auth expiry and handle stale athlete tokens cleanly

**Bead ID:** `oc-dwqe`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-dwqe` on start with `bd update oc-dwqe --status in_progress --json`. Implement the approved token-lifetime fix slice from Task 12’s findings. Persist the returned auth-exchange expiry (`date_expires` / equivalent) alongside the saved bearer/session data, restore it into browser state on startup, surface expiry-aware auth UI, and explicitly clear or invalidate stale saved auth when restore-time authenticated-read failure is clearly token-related. Add focused tests for expiry persistence, expiry-aware restore, and stale-token failure handling; run relevant validation; update this plan with what actually changed; commit and push by default; and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_state.gd`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_session_config_store.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`

**Status:** ✅ Complete

**Results:** Implemented the approved token-lifetime fix slice in the browser testbed without changing the provider seam. `ModioWorkoutBrowserState` now tracks `access_token_expires_at`, `_persist_session_state()` writes that expiry into the session config, `_load_initial_state()` restores it on startup, and the auth-state copy now reports either the saved expiry timestamp, the fact that expiry is unknown, or a truthful restore/invalidation note. The auth exchange path now normalizes the provider response through `normalize_access_token_response(...)` so the saved bearer token keeps the returned `date_expires` / `expires_at` metadata instead of dropping it on the floor.

Stale saved auth is now cleaned up explicitly in the two cases approved by Task 12. On startup, `_restore_saved_runtime_state()` clears persisted bearer data immediately when the saved expiry is already in the past, so the scene no longer presents a ghost-authenticated state for obviously expired tokens. During restore-time `/me` rehydration, `_refresh_profile_data(..., restoring_saved_token=true)` now detects clearly token-related auth failures (401/403 auth errors or provider-directed `should_clear_session`) and clears the persisted bearer token, expiry, and cached user ID while preserving saved email context for a clean re-auth flow. The clear-session button now also removes the saved expiry field.

Focused regression coverage was added for all requested seams: session-config persistence now asserts `access_token_expires_at` is saved, the browser scene test suite verifies startup restore of saved expiry metadata, startup invalidation of already-expired saved auth, and token-related stale-auth invalidation that preserves email while clearing bearer/session keys. Validation passed with `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd` plus `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (113/113 passing; one pre-existing non-failing Float/Int comparison warning remains in `test_modio_vendor_adapter.gd`).

---

### Task 14: QA auth expiry persistence and stale-token handling

**Bead ID:** `oc-tyxx`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-tyxx` on start with `bd update oc-tyxx --status in_progress --json`. Verify expiry metadata persistence, expiry-aware restore behavior, and clean invalidation of stale athlete auth without regressions. Run relevant validation/tests, update this plan with QA findings, commit/push by default only if QA-sized fixes are needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`

**Status:** ✅ Complete

**Results:** QA passed without needing a fix. The token-lifetime slice now behaves truthfully across the seams called out in Task 12. Expiry metadata is persisted alongside saved bearer/session data: `_persist_session_state()` writes `access_token_expires_at`, `ModioSessionConfigStore` preserves it in the session config, and focused session-store coverage asserts the value is saved and readable. On startup, `_load_initial_state()` restores that saved expiry into `ModioWorkoutBrowserState.access_token_expires_at`, and the auth UI now reports either the saved expiry timestamp, an explicit expired state, or the truthful fallback that the provider did not return expiry metadata.

The stale-auth handling claims are also true. If a saved token is already obviously expired, `_restore_saved_runtime_state()` clears the persisted bearer/session keys before attempting profile rehydration, preventing ghost-authenticated startup state; the browser test suite verifies both the in-memory state reset and the cleared config entries. For restore-time token-related failures, `_refresh_profile_data(..., restoring_saved_token=true)` identifies clear auth rejection cases and invalidates only the saved bearer/session keys (`access_token`, `access_token_expires_at`, `user_id`) while preserving `email` and `last_requested_email` so the athlete can re-run email-code auth cleanly. The UI/copy stays truthful about the max requested lifetime and the actual saved expiry.

Regression coverage stayed green. QA reran `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, the focused GUT pass for `res://tests/test_modio_session_config_store.gd` + `res://tests/test_modio_workout_browser_testbed.gd`, and the full `addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite. All passed. The only remaining note is the pre-existing non-failing Float/Int comparison warning in `test_modio_vendor_adapter.gd`, plus the known non-failing ObjectDB/resources-at-exit warning from the scene QA harness; neither is introduced by this auth-expiry slice.

---

### Task 15: Audit auth expiry persistence and stale-token handling

**Bead ID:** `oc-n32x`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-n32x` on start with `bd update oc-n32x --status in_progress --json`. Independently audit the auth expiry persistence and stale-token invalidation behavior against Task 12’s approved findings. Verify returned expiry is persisted/restored, invalid saved auth is cleared truthfully on restore failure, and validation evidence supports the claim. Update this plan with the final audit verdict, commit/push by default only if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`

**Status:** ✅ Complete

**Results:** Independent audit passed after one audit-sized validation-seam fix. The implementation itself was already correct against Task 12’s findings: `_on_exchange_code_pressed()` now normalizes/stores the returned auth expiry, `_persist_session_state()` writes `access_token_expires_at`, `_load_initial_state()` restores it into `ModioWorkoutBrowserState`, and the auth-state copy truthfully distinguishes known expiry, already-expired saved auth, and the provider-did-not-return-expiry case. The stale-auth behavior is also correct in code: `_restore_saved_runtime_state()` pre-clears obviously expired saved auth before any `/me` restore attempt, and `_refresh_profile_data(..., restoring_saved_token=true)` invalidates only `access_token`, `access_token_expires_at`, and `user_id` on clearly token-related restore failure while preserving `email` and `last_requested_email` for clean re-auth.

The audit-sized gap was in evidence, not behavior: the browser tests covered helper-level invalidation but did not execute the real restore-time `/me` rejection path end to end. I fixed that by adding a narrow test-only manager-factory seam in `.testbed/scripts/modio_workout_browser_testbed.gd` and a new regression test that boots the scene with a saved future-dated token, forces `build_authenticated_user_request` to fail with a token-auth rejection during startup restore, and verifies that the scene clears persisted bearer/session keys while preserving email context and truthful auth copy. After the fix, audit validation passed with `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, the focused GUT pass for `res://tests/test_modio_session_config_store.gd` + `res://tests/test_modio_workout_browser_testbed.gd`, and the full `addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite (`114/114` passing, with the same pre-existing non-failing Float/Int warning in `test_modio_vendor_adapter.gd` and the known browser-test ObjectDB/resources-at-exit warning).

---


### Task 16: Diagnose create-draft upload failure and clean warning noise

**Bead ID:** `oc-mwzf`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-mwzf` on start with `bd update oc-mwzf --status in_progress --json`. Investigate the newly reported testbed issues: (1) Upload Workout currently fails at `create_draft_failed` while trying to upload a dummy workout ZIP, and the UI does not expose the underlying validation/server reason clearly enough; (2) there is a small warning cleanup to fix around `ModioWorkoutUploadFlow` having the same name as a global class in `modio_workout_upload_flow.gd`; and (3) Derrick's screenshot confirms the latest provider-returned token expiry is about 90 days, not one year, so make sure any related auth copy/error handling remains truthful. Identify and fix the create-draft failure if it is a local issue, or at minimum surface the real validation/server error clearly in the UI and testbed diagnostics. Remove the warning noise cleanly, add/update focused tests, run relevant validation, update this plan with what actually changed, commit and push by default, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/`
- `src/`

**Status:** ✅ Complete

**Results:** Reproduced the failing `create_draft_failed` seam directly against the configured **test** mod.io host with a disposable curl probe after Godot's headless HTTP path hit a local SSL initialization failure in this sandbox. The real provider-side validation error was not vague at all once surfaced: `Validation Failed. Please see below to fix invalid input:` with nested field details showing **`summary` is required**, **`metadata_blob` must be a string**, and the chosen dummy **logo image dimensions were invalid**. A second disposable probe confirmed the local fix path: when the request included a real summary, `metadata_blob="{}"`, and a readable `512x288+` logo, draft creation succeeded (`201`) and the temporary test mod was deleted immediately afterward. That means the failure was partly local-product truthfulness debt, not just opaque provider behavior: the upload helper/UI were letting operators walk into a known-invalid create-draft request and then collapsing the returned field errors into overly vague copy.

---

### Task 17: QA create-draft failure diagnostics and warning cleanup

**Bead ID:** `oc-28pm`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-28pm` on start with `bd update oc-28pm --status in_progress --json`. Verify the Upload Workout create-draft failure diagnostics and warning cleanup. Confirm the reported `create_draft_failed` path is either fixed or surfaced truthfully with the real validation/server reason, confirm the `ModioWorkoutUploadFlow` warning is gone, rerun relevant validation/tests, update this plan with QA findings, commit/push by default only if QA-sized fixes are needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`

**Status:** ✅ Complete

**Results:** QA passed without needing a follow-up fix. The root-cause surfacing is now truthful at both seams. In `src/modio_workout_upload_flow.gd`, `prepare_submission()` blocks the locally knowable invalid create-draft cases before any network call: missing `summary`, empty `metadata_kvp`, missing/nonexistent logo or ZIP paths, unreadable logo files, non-`.zip` workout archives, and logo images smaller than `512x288`. The helper also seeds a sane default `metadata_blob` of `{}` when the field is omitted or blank. When provider-side create-draft validation still fails, `_response_error_message()` now preserves the upstream top-level message, flattens nested field details, and appends `error_ref`, so the returned failure is specific instead of collapsing to a vague `create_draft_failed` label.

The browser surface reflects that truth instead of hiding it. `.testbed/scripts/modio_workout_browser_testbed.gd` now tells the operator up front that mod.io expects a summary, readable `512x288+` logo, and string metadata before draft creation will pass; failed uploads save the full result into `_state.raw_debug_sections["upload_attempt"]`; and the result panel shows the failed stage plus the concrete provider/local reason. Focused browser coverage proves that path with explicit assertions for `Failed Step: create_draft`, nested `summary` and `metadata_blob` field messages, and `error_ref=13009` in the rendered result text.

The warning cleanup is also verified. The controller preload alias is now `ModioWorkoutUploadFlowScript` instead of `ModioWorkoutUploadFlow`, so it no longer collides with the helper’s `class_name ModioWorkoutUploadFlow`. Fresh headless import/validation runs did not emit the prior duplicate-name warning. Auth/token copy also remains truthful: the auth panel and saved-token restore note say we request the longest direct expiry we can ask for, but recent observed provider-returned bearer expiries in this testbed have been closer to ~90 days rather than a guaranteed year.

QA reran: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, the focused GUT pass for `res://tests/test_modio_workout_upload_flow.gd` + `res://tests/test_modio_workout_browser_testbed.gd`, and the full `addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite. All passed (`117/117`). The only remaining warnings were the known non-failing scene-harness ObjectDB/resources-at-exit warning and the pre-existing full-suite Float/Int comparison warning in `test_modio_vendor_adapter.gd`; neither is introduced by this upload-diagnostics slice.

---

### Task 18: Audit create-draft failure diagnostics and warning cleanup

**Bead ID:** `oc-tpkt`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-tpkt` on start with `bd update oc-tpkt --status in_progress --json`. Independently audit the reported Upload Workout `create_draft_failed` issue and the warning cleanup. Verify the failure is either fixed or surfaced truthfully with the underlying reason, verify the warning is removed, verify evidence supports the claim, update this plan with the final audit verdict, commit/push by default only if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`

**Status:** ✅ Complete

**Results:** Independent audit passed without needing an audit-sized fix. The reported `create_draft_failed` seam is now either prevented locally or surfaced truthfully with the real provider reason. In `src/modio_workout_upload_flow.gd`, `prepare_submission()` now blocks the locally knowable invalid draft-create cases before any network call: missing `summary`, empty `metadata_kvp`, missing/nonexistent logo or ZIP paths, unreadable logo files, non-`.zip` workout archives, and logo images smaller than `512x288`. The helper also defaults a blank/omitted `metadata_blob` to `{}`, matching the provider requirement that the field be a string when sent.

When provider-side create-draft validation still fails, the failure no longer collapses into opaque `create_draft_failed` copy. The helper’s `_response_error_message()` preserves the upstream top-level message, flattens nested field details, and appends `error_ref`, while `.testbed/scripts/modio_workout_browser_testbed.gd` renders the failed step plus the concrete failure reason in the Upload Workout result panel. The focused browser/UI test locks that in by asserting `Failed Step: create_draft`, the nested `summary` message, the nested `metadata_blob` message, and `error_ref=13009` all appear in the rendered result text.

The warning cleanup is also verified. The controller preload alias is `ModioWorkoutUploadFlowScript`, so it no longer collides with the helper’s global `class_name ModioWorkoutUploadFlow`, and fresh import/test runs in this audit did not emit the prior duplicate-name warning. Auth/token copy also remains truthful: the auth panel and saved-token restore note still say we request the longest direct expiry we can ask for, but recent observed provider-returned bearer expiries in this testbed have been closer to `~90 days` rather than a guaranteed year.

Fresh validation evidence supports the claim. I reran `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, the targeted GUT pass for `res://tests/test_modio_workout_upload_flow.gd` plus `res://tests/test_modio_workout_browser_testbed.gd`, and the full `addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite. All passed (`117/117`). The only remaining warnings were the known non-failing scene-harness ObjectDB/resources-at-exit warning and the pre-existing full-suite Float/Int comparison warning in `test_modio_vendor_adapter.gd`; neither is introduced by this upload-diagnostics slice.

---

### Task 12: Diagnose create-draft failure and tighten upload/auth truthfulness

**Bead ID:** `oc-mwzf`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-mwzf` on start with `bd update oc-mwzf --status in_progress --json`. Investigate Derrick's newly reported upload/auth polish issues: Upload Workout currently fails at `create_draft_failed` while trying to upload a dummy workout ZIP and the UI hides the underlying provider reason too much; there is a warning around `ModioWorkoutUploadFlow` colliding with the global class of `modio_workout_upload_flow.gd`; and the latest provider-returned token expiry screenshot shows about 90 days, so auth copy/error handling must stay truthful rather than promising a year. Identify the real root cause of the create-draft failure, fix any local issues you can, at minimum surface the real validation/server error clearly in the UI/diagnostics, remove the global-name warning cleanly, add/update focused tests, run relevant validation, update this plan with what actually changed, commit/push by default, and close bead `oc-mwzf` with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_workout_upload_flow.gd`
- `src/modio_workout_upload_flow.gd`

**Status:** ✅ Complete

**Results:** Reproduced the failing `create_draft_failed` seam directly against the configured **test** mod.io host with a disposable curl probe after Godot's headless HTTP path hit a local SSL initialization failure in this sandbox. The real provider-side validation error was not vague at all once surfaced: `Validation Failed. Please see below to fix invalid input:` with nested field details showing **`summary` is required**, **`metadata_blob` must be a string**, and the chosen dummy **logo image dimensions were invalid**. A second disposable probe confirmed the local fix path: when the request included a real summary, `metadata_blob="{}"`, and a readable `512x288+` logo, draft creation succeeded (`201`) and the temporary test mod was deleted immediately afterward. That means the failure was partly local-product truthfulness debt, not just opaque provider behavior: the upload helper/UI were letting operators walk into a known-invalid create-draft request and then collapsing the returned field errors into overly vague copy.

I fixed the local seam accordingly. `src/modio_workout_upload_flow.gd` now enforces the provider-required summary before any network call, auto-seeds a safe default `metadata_blob` of `{}` when the operator does not provide one, and locally validates that the chosen logo is a readable image with at least `512x288` resolution before attempting draft creation. On the diagnostics side, the helper now preserves nested provider field errors and `error_ref` values in the returned message instead of dropping them on the floor, and the Upload Workout result panel now prints the failed stage plus the concrete failure reason so the UI/debug view shows the real mod.io complaint rather than just `create_draft_failed`. The controller also saves the full upload attempt result into `raw_debug_sections["upload_attempt"]` for easier operator inspection.

The warning cleanup is also done: `.testbed/scripts/modio_workout_browser_testbed.gd` no longer defines a preload constant named `ModioWorkoutUploadFlow`, which had been shadowing the actual global class name from `src/modio_workout_upload_flow.gd`; the preload alias is now `ModioWorkoutUploadFlowScript`, removing the duplicate-global-name warning cleanly without changing the helper seam. Auth copy was tightened to match the screenshot evidence: the profile/auth explanatory text and saved-token restore note no longer promise a one-year session; they now explain that we request the longest direct expiry we can ask for, but the latest observed provider-returned bearer in this testbed was closer to **~90 days**, and the actual saved expiry shown to the operator is the source of truth.

Focused coverage was updated to lock the fixes in place. `test_modio_workout_upload_flow.gd` now uses real generated PNGs for logo validation, covers summary-required validation, small-logo rejection, default `metadata_blob` seeding, and server-field-error propagation for create-draft failures. `test_modio_workout_browser_testbed.gd` now verifies that failed staged uploads surface the failed step plus the nested provider field reasons in the result panel and that the full upload attempt lands in debug state. Validation passed with `godot --headless --path .testbed --import`, targeted GUT for `res://tests/test_modio_workout_upload_flow.gd` plus `res://tests/test_modio_workout_browser_testbed.gd`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, and `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`. The existing non-failing ObjectDB/resources-at-exit warning remains in the headless test environment and is unrelated to this slice.

---
### Task 19: Refactor upload error summarization into the manager seam

**Bead ID:** `oc-avk1`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-avk1` on start with `bd update oc-avk1 --status in_progress --json`. Refactor the current upload error summarization so the reusable provider error parsing/formatting lives in `AeroModIOManager` (or the manager seam it owns) instead of being private logic in `src/modio_workout_upload_flow.gd`. Keep workflow-stage context like `create_draft` / `upload_modfile` / `publish_mod` in the upload flow helper, but route the underlying provider error summarization through the manager seam so other callers can reuse it. Add/update focused tests, run relevant validation, update this plan with what actually changed, commit and push by default, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/tests/test_aero_modio_manager.gd`
- `.testbed/tests/test_modio_workout_upload_flow.gd`
- `src/AeroModIOManager.gd`
- `src/modio_workout_upload_flow.gd`

**Status:** ✅ Complete

**Results:** Refactored the provider-error parsing/formatting seam out of `src/modio_workout_upload_flow.gd` and into `src/AeroModIOManager.gd` so upload failures no longer depend on private helper-only formatting logic. `AeroModIOManager` now exposes `summarize_provider_error(response, fallback)`, which preserves the top-level provider message, flattens nested detail payloads from either `error.details` or `error.errors`, and appends `error_ref` when present. `src/modio_workout_upload_flow.gd` keeps ownership of workflow-stage labels like `create_draft`, `upload_modfile`, and `publish_mod`, but now routes all provider-facing error summarization through `manager.summarize_provider_error(...)` for both transport-level failures and normalized provider rejections.

Focused coverage was added at both seams. `test_aero_modio_manager.gd` now verifies nested-detail and `errors`-shape summarization directly on the manager seam, while `test_modio_workout_upload_flow.gd` adds a focused regression proving the upload flow delegates provider-error summarization back through the manager instead of formatting it privately. Coder validation passed with `godot --headless --path .testbed --import`, targeted GUT for `res://tests/test_aero_modio_manager.gd` plus `res://tests/test_modio_workout_upload_flow.gd`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, and `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`. The existing non-failing scene-harness ObjectDB/resources-at-exit warning still appears in the QA script and is unrelated to this refactor.

---

### Task 20: QA manager-level upload error summarization refactor

**Bead ID:** `oc-ru41`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-ru41` on start with `bd update oc-ru41 --status in_progress --json`. Verify the shared provider error summarization now lives in the manager seam, confirm workflow-stage labels remain accurate in the upload flow/UI, rerun relevant validation/tests, update this plan with QA findings, commit/push by default only if QA-sized fixes are needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/tests/`
- `src/`

**Status:** ✅ Complete

**Results:** QA passed without needing a follow-up fix. The reusable provider error summarization now truly lives in the manager seam: `src/AeroModIOManager.gd` exposes `summarize_provider_error(response, fallback)`, and focused manager coverage verifies that it preserves the top-level provider message, flattens nested `error.details` and `error.errors` payloads, and appends `error_ref` when present. The upload helper no longer owns that parsing privately; `src/modio_workout_upload_flow.gd` now delegates both transport-level and normalized provider-failure messaging through `manager.summarize_provider_error(...)`, and the focused upload-flow regression asserts that delegation path directly.

Workflow-stage ownership also stayed truthful after the refactor. The upload flow still owns the operator-facing stage labels `create_draft`, `upload_modfile`, and `publish_mod`, returns those labels in per-step results, and the browser surface still renders them accurately in the Upload Workout result panel when a staged failure occurs. Focused browser coverage remains green for that seam, including assertions that failed uploads show `Failed Step: create_draft` while still surfacing the underlying provider summary text generated by the manager seam.

Regression coverage stayed green across the targeted QA slice. I reran `godot --headless --path .testbed --import`, targeted GUT for `res://tests/test_aero_modio_manager.gd` + `res://tests/test_modio_workout_upload_flow.gd` + `res://tests/test_modio_workout_browser_testbed.gd`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, and `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`. All passed (`20/20` focused tests). The only remaining notes are the known non-failing scene QA harness ObjectDB/resources-at-exit warning after `qa_verify_scene_output_updates.gd`; no regression or seam break was found in this manager-level error-summarization refactor.

---

### Task 21: Audit manager-level upload error summarization refactor

**Bead ID:** `oc-cd7u`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-cd7u` on start with `bd update oc-cd7u --status in_progress --json`. Independently audit the manager-seam error summarization refactor. Verify reusable provider error summarization now lives in `AeroModIOManager` (or its owned manager seam), verify upload workflow-stage context remains in the workflow helper, rerun/inspect validation evidence, update this plan with the final audit verdict, commit/push by default only if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/tests/`
- `src/`

**Status:** ✅ Complete

**Results:** Independent audit passed without needing an audit-sized fix. The reusable provider error summarization now truly lives in the manager seam. In `src/AeroModIOManager.gd`, `summarize_provider_error(response, fallback)` owns the provider-facing formatting work: it preserves the top-level provider message, flattens nested payloads from either `error.details` or `error.errors`, and appends `error_ref` when present. The focused manager test coverage in `.testbed/tests/test_aero_modio_manager.gd` exercises both nested-detail and `errors`-shape payloads directly against that seam, which matches the refactor claim in Task 19.

The upload workflow helper still owns workflow-stage context rather than letting that leak into the manager seam. In `src/modio_workout_upload_flow.gd`, the staged labels `create_draft`, `upload_modfile`, and `publish_mod` are still introduced in `_execute_step(...)` / `submit_workout(...)`, recorded into per-step results, and surfaced back to UI consumers. The helper now delegates the underlying provider-failure wording through `manager.summarize_provider_error(...)` for both transport failures and normalized provider rejections, but it retains ownership of the stage-specific fallback text (`mod.io request failed during create_draft.`, `mod.io rejected upload_modfile.`, etc.). That keeps the split truthful: manager owns reusable provider summarization, helper owns workflow-stage meaning.

Validation evidence supports the claim. I reran `godot --headless --path .testbed --import`, targeted GUT for `res://tests/test_aero_modio_manager.gd` + `res://tests/test_modio_workout_upload_flow.gd` + `res://tests/test_modio_workout_browser_testbed.gd`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, and `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`. All passed (`20/20` focused tests). The browser/UI seam still reports stage-specific failure text such as `Failed Step: create_draft` while surfacing the provider summary generated by the manager seam, so the UI behavior remains truthful after the refactor. The only remaining notes are the known non-failing scene QA harness ObjectDB/resources-at-exit warning after `qa_verify_scene_output_updates.gd` and the pre-existing Float/Int comparison warning in `test_modio_vendor_adapter.gd`; neither is introduced by this refactor.

---
### Task 22: Fix test auth writing into the live session bucket

**Bead ID:** `oc-puff`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-06`  
**Prompt:** Pending final execution approval. In `aerobeat-vendor-modio`, fix the auth/session environment-bucket bug where athlete auth obtained through the Test server path is being persisted under the `modio.live` session section instead of `modio.test`. Audit the server-selector/environment state used at exchange/save time, ensure auth exchange persistence writes to the active environment bucket consistently, ensure restore/clear flows stay aligned with that same bucket, and add focused regression coverage proving a Test auth exchange does not leak into the Live session section. Preserve the recent expiry/stale-token behavior improvements while fixing the environment-bucket mismatch.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/scripts/modio_session_config_store.gd`
- `.testbed/tests/test_modio_session_config_store.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`

**Status:** ✅ Complete

**Results:** Fixed the environment-bucket mismatch in the workout browser controller instead of relying on whichever stale `_state.environment` happened to be hanging around. The server selector now becomes the source of truth before auth request/exchange persistence, regular session saves, and clear-session writes; switching the selector also reloads the chosen environment bucket into runtime state so restore/clear/auth all stay aligned with the active bucket. I added `ModioSessionConfigStore.save_environment()` plus normalized environment handling so the selected bucket can be persisted without overwriting sibling bucket data. Focused regression coverage now proves a Test-path auth exchange writes only into `modio.test`, leaves `modio.live` untouched, and that clearing the Test bucket does not wipe the Live bucket. Existing expiry/stale-token behavior stayed intact; full validation passed with `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (`111/111` passing) and `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`.

---
### Task 23: QA auth environment-bucket persistence fix

**Bead ID:** `oc-lrvp`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-lrvp` on start with `bd update oc-lrvp --status in_progress --json`. Verify the Test-vs-Live auth session bucket fix. Confirm a Test auth exchange persists into `modio.test` rather than `modio.live`, confirm restore and clear flows stay aligned with the active environment bucket, rerun relevant validation/tests, update this plan with QA findings, commit/push by default only if QA-sized fixes are needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`

**Status:** ✅ Complete

**Results:** QA found and fixed one real QA-sized regression in the environment-bucket slice before closing. The core behavior claim is now verified: switching the server selector from Live to Test reloads the Test session bucket into runtime state, a Test auth exchange persists into `modio.test` (including `access_token`, `access_token_expires_at`, `user_id`, and saved email context), and the pre-existing Live bucket remains intact rather than being overwritten by the Test-path exchange. Focused browser coverage now proves that exact seam with a manager-factory stub that preserves the Live restore identity during startup and then returns the Test identity only for the Test-path exchange, so the assertion is checking the real bucket-routing behavior instead of test-induced restore noise.

QA also confirmed restore and clear flows stay aligned with the active environment bucket. While tightening that coverage, I found a small real bug: clearing the active bucket erased `access_token_expires_at`, but a later UI-driven session persist could write it back as `"0"` because `_persist_session_state()` always stringified the in-memory expiry integer. I fixed that by only persisting `access_token_expires_at` when it is a real positive timestamp, leaving it blank when the session has been cleared. After that fix, clearing the Test bucket removes its saved auth/expiry/user/email fields while leaving the Live bucket untouched, and the recent stale-token/expiry behavior still works as designed.

Validation rerun passed after the QA fix: targeted GUT for `res://tests/test_modio_session_config_store.gd` + `res://tests/test_modio_workout_browser_testbed.gd`, `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and the full `addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` suite (`123/123` passing). The only remaining warnings are the pre-existing non-failing Float/Int comparison warning in `test_modio_vendor_adapter.gd` and the known ObjectDB/resources-at-exit warning from the scene QA harness.

---

### Task 24: Audit auth environment-bucket persistence fix

**Bead ID:** `oc-aey3`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-aey3` on start with `bd update oc-aey3 --status in_progress --json`. Independently audit the Test-vs-Live auth session bucket fix. Verify auth exchange/save/restore/clear use the correct active environment bucket, inspect validation evidence, update this plan with the final audit verdict, commit/push by default only if an audit-sized fix is needed, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-01-aerobeat-vendor-modio-workout-upload-tab-audit.md`
- `.testbed/`
- `src/`

**Status:** ⏳ Pending

**Results:** Pending.

---
## Final Results

**Status:** ⚠️ Partial

**What We Built:** The default mod.io browser testbed still uses the reusable helper-driven `Upload Workout` tab and now also seeds truthful metadata for vendor-seam testing instead of guessed taxonomy examples. The new cross-repo seam is in place: `aerobeat-tool-device-detection` now exposes a dedicated helper that normalizes detected-device JSON into stable mod.io metadata KVP pairs, and `aerobeat-vendor-modio` consumes that helper in the upload testbed to prefill deterministic device-derived metadata alongside explicit seeded fields like `aerobeat_version=1.0.0`. Public AeroBeat taxonomy stays in Tags, with the seeded/default tag example set to `boxing, easy, edm` instead of the prior misleading metadata-first examples. The token-lifetime slice is now implemented, QA-verified, and audit-verified: saved auth expiry is persisted/restored, obviously expired auth is pre-cleared on startup, and restore-time token rejection clears invalid saved bearer state while preserving email context for re-auth. The upload-diagnostics follow-up also diagnosed the real `create_draft_failed` seam against the configured test host and tightened the upload flow so the UI/helper no longer hide or casually trigger known-invalid draft-create requests: summary is now required locally, `metadata_blob` defaults truthfully to `{}`, logo files are preflight-checked for readable `512x288+` dimensions, failed upload attempts surface nested mod.io field errors plus `error_ref`, the testbed warning-causing preload alias was cleaned up, and auth copy now reflects the latest observed provider-returned expiry being closer to ~90 days than a guaranteed year. Finally, the provider-error summarization refactor is now coder/QA/auditor verified: reusable provider error formatting lives in `AeroModIOManager`, while staged workflow context (`create_draft` / `upload_modfile` / `publish_mod`) remains in `modio_workout_upload_flow.gd` and the browser UI continues to report both pieces truthfully. The latest coder slice also fixes the Test-vs-Live auth session bucket mismatch by syncing auth/save/clear behavior to the active server selector and reloading the matching session bucket on environment changes; QA and auditor follow-up for that new slice is still pending in Tasks 23-24.

**Reference Check:** `REF-01` through `REF-07` remain the active source-of-truth set, now supplemented by the current online mod.io REST/docs pages for Add Mod Tags, Add/Get Mod KVP Metadata, Game Object `tag_options`, Mod Object, Edit Mod, and Filtering. This coder slice follows that guidance directly: `feature` / `difficulty` / `genre` remain tag-space concerns per `REF-07`, while `metadata_kvp` is kept for structured provider/tool metadata. The new device helper only emits stable/useful hardware fields and intentionally excludes privacy-heavy or noisy fields, matching the approved slice requirements.

**Commits:**
- `6212010` - `Add staged workout upload helper and testbed tab`
- `47ea25c` - `Record QA verification for workout upload tab`
- `4613612` - `Audit workout upload tab validation seam`
- `2bad34f` - `Refine workout upload tab layout`
- `dfa3f0f` - `Record audit verdict for upload layout refinement`
- `007251b` (`aerobeat-tool-device-detection`) - `Add mod.io upload metadata helper`
- `ea03fe3` (`aerobeat-vendor-modio`) - `Seed truthful upload metadata defaults`
- `9d13c89` (`aerobeat-tool-device-detection`) - `Avoid global class collision in modio metadata helper`
- `6287c46` - `Audit auth expiry restore validation seam`
- `abdfed7` - `Diagnose workout upload draft validation`
- `ec50648` - `Refactor upload error summaries into manager seam`
- `HEAD` - `Record audit verdict for manager-level error summarization`

**Lessons Learned:** For UI refinements like this, the risky part is not just visual parity; it is preserving behavioral truth. A denser form can still fail the real requirement if the action falls below the viewport or if the controller quietly starts owning backend orchestration again. The extra scrollbar probe was worth doing because it confirmed the design succeeds for the right reason: when compression is not enough, scrolling genuinely carries the operator to the action. The next truth check was semantic rather than spatial, and this follow-up proved why: a vague `create_draft_failed` label hid concrete provider requirements we could cheaply validate ourselves. When mod.io already tells us the exact invalid fields, the product should either preflight them locally or surface them verbatim enough for an operator to act on them.
