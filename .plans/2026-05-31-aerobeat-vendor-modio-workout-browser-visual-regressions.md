# AeroBeat Vendor mod.io Workout Browser Visual Regression Follow-Up

**Date:** 2026-05-31  
**Status:** In Progress  
**Last Updated:** 2026-05-31 15:58 EDT  
**Blocked Reason:** None  
**Agent:** `main`

---

## Goal

Fix the Workout Browser visual regression where public results are reported as loaded but do not render as clickable workout cards, and clean up the testbed warning spam shown during scene usage.

---

## Overview

The previous follow-up slice correctly fixed auto-fetch, reopen persistence, and top-level layout, but Derrick’s manual review exposed that the browser is still not visually usable: the UI reports `Loaded public (2 result(s)).` and the pagination/status line confirms `Page 1 of 1 · showing 2 of 2`, yet the workout area remains blank. That means the data fetch and state summary paths are working, but the actual card-rendering path is failing or collapsing. This is a tighter, more focused seam than the prior provider/debug work: now the likely bug is in the browser presentation layer rather than the mod.io request layer.

The warnings screenshot also gives us a bounded cleanup pass. Several warnings are not random runtime failures; they point to code hygiene issues in the testbed scripts: duplicate local constants that shadow globally registered `class_name` types, a local parameter named `name` shadowing `Node.name`, and an unused `text` parameter in `_placeholder_texture()`. Those warnings may not fully explain the blank browser, but they are polluting the proving surface and should be cleaned up while we are already touching the controller.

This follow-up should stay narrowly scoped to the rendering path and warning cleanup. We should not re-open larger product questions or widen scope beyond making the public/browser cards actually appear and trimming the noisy warnings that Derrick surfaced.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Recently completed follow-up baseline | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/archive/2026-05-31-aerobeat-vendor-modio-workout-browser-follow-up.md` |
| `REF-02` | Current Workout Browser scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/workout_browser.tscn` |
| `REF-03` | Current Workout Browser controller | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_workout_browser_testbed.gd` |
| `REF-04` | Current session-config helper | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_session_config_store.gd` |
| `REF-05` | Warning-producing env loader / globals seam | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_env_loader.gd` |
| `REF-06` | Global class registration source: manager/config/query/state classes | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/` and `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/` |
| `REF-07` | Screenshot 1: loaded-public but blank browser area | `/workspace/.temp/nerve-uploads/2026/05/31/image-a9d96869.png` |
| `REF-08` | Screenshot 2: warning list during scene usage | `/workspace/.temp/nerve-uploads/2026/05/31/image-dfc87f45.png` |

---

## Tasks

### Task 1: Audit the blank-browser rendering regression and warning sources

**Bead ID:** `oc-ylar`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Audit why the Workout Browser reports that public results are loaded but does not visually populate clickable workout cards. Use the current scene/controller code, screenshot evidence, and local runtime seams to determine whether the issue is card population logic, cleared children, zero-sized/hidden containers, tab/content visibility, async thumbnail/card assembly, or another presentation-layer bug. Also trace the warning lines shown in Derrick’s screenshot and identify which are caused by duplicate local constants for globally registered `class_name` types versus local naming/unused-parameter issues. Update the plan with concrete findings and exact coder recommendations, then close the bead when done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-visual-regressions.md`

**Status:** ✅ Complete

**Results:** The blank-browser regression is a presentation/layout bug, not a data-fetch/population failure. `_fetch_listing()` successfully normalizes and stores the public listing, and `_update_listing_ui()` does add card nodes into `PublicCardsGrid` (`grid.add_child(_build_mod_card(...))` in `modio_workout_browser_testbed.gd`). A headless scene inspection with injected fake listing data confirmed `PublicCardsGrid` reaches `get_child_count() == 2`, but its parent `ScrollContainer` ends up with `size=(460, 0)` and the listing-browser root VBox only `size=(460, 31)`. The cards exist, but the viewport that should show them collapses to zero height. The likely fix seam is `_listing_browser()` in `REF-03`: its returned root container never opts into vertical expansion, so only the controls/pagination strip stays visible while the card area is clipped away. This matches `REF-07` exactly: status and pagination render truthfully while the card region looks blank.

Warning audit from `REF-08`: the warnings are real but mostly hygiene-level parser warnings, not the cause of the blank browser. Exact sources:
- `modio_workout_browser_testbed.gd:3-8` locally preloads `AeroModIOManager`, `ModioClientConfig`, `ModioListingQuery`, `ModioEnvLoader`, `ModioSessionConfigStore`, and `ModioWorkoutBrowserState`, each of which is also globally registered via `class_name`; Godot warns that the local constants shadow the global classes.
- `modio_env_loader.gd:4` locally preloads `ModioClientConfig`, shadowing the global `class_name ModioClientConfig`.
- `modio_session_config_store.gd:4` locally preloads `ModioEnvLoader`, shadowing the global `class_name ModioEnvLoader`.
- `modio_workout_browser_testbed.gd:449` uses a local parameter named `name` in `_listing_controls(name: String, ...)`, which shadows the built-in `Node.name` property because the script extends `Control`.
- `modio_workout_browser_testbed.gd:1023` declares `_placeholder_texture(text: String)` but never uses `text`; that is the unused-parameter warning from the screenshot.

Exact coder recommendations:
1. Fix the blank browser in `REF-03` by giving the listing-browser container and/or its scroll viewport explicit vertical expansion so the card grid gets non-zero height at runtime. Verify with a scene-level test that a populated listing yields visible grid/card height, not just non-empty data.
2. Add or extend a focused test in `.testbed/tests/test_modio_workout_browser_testbed.gd` that injects listing data, calls `_update_listing_ui("public")`, and asserts both `PublicCardsGrid.get_child_count() > 0` and a non-zero visible height on the listing viewport/container after a couple of frames.
3. Remove duplicate preload constants where the target script already has `class_name`; use the global class names directly in the browser/state/env/session helper scripts instead of redefining same-name constants.
4. Rename `_listing_controls(name: String, ...)` to a non-shadowing parameter such as `control_name` or `panel_name`.
5. Rename `_placeholder_texture(text: String)` to `_placeholder_texture(_text: String)` if the label stays intentionally unused, or actually render the placeholder label into the image if the text is meant to matter.

---

### Task 2: Implement the browser-card rendering fix and warning cleanup

**Bead ID:** `oc-eb3w`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Fix the Workout Browser so loaded public/workout/subscribed results actually render as visible clickable cards in the browser area. Also clean up the warning spam Derrick surfaced, including duplicate local constants that shadow global `class_name` registrations and the local naming/unused-parameter warnings, without widening scope. Update tests/validation/docs/plan, commit/push by default, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/workout_browser.tscn`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/scripts/modio_env_loader.gd`
- `.testbed/scripts/modio_session_config_store.gd`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-visual-regressions.md`

**Status:** ✅ Complete

**Results:** Implemented the narrow browser-layout fix in `REF-03` by giving the listing-browser root container explicit vertical expansion and naming the generated browser root/scroll nodes so the viewport seam is testable. The public/workout/subscribed listing browser now keeps a non-zero scroll viewport height, so populated card grids render as visible clickable cards instead of being clipped away at runtime. Cleaned the warning seam without widening scope: removed redundant same-name preload constants that shadow globally registered `class_name` types in `modio_workout_browser_testbed.gd`, `modio_env_loader.gd`, and `modio_session_config_store.gd`; renamed `_listing_controls(name: String, ...)` to `_listing_controls(control_name: String, ...)`; and resolved the unused placeholder-text warning by renaming the parameter to `_text`. Added a focused regression test in `.testbed/tests/test_modio_workout_browser_testbed.gd` that injects public listing data, updates the listing UI, and asserts both card count and non-zero listing/card viewport height after frames settle. Validation run: `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` all passed. Note: the QA scene-output script still emits an existing ObjectDB/resource-leak warning on exit even though it returns success; that pre-existing warning was left out of scope for this bead.

---

### Task 3: QA the visual/browser fix against Derrick’s screenshots

**Bead ID:** `oc-6blh`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Verify that when the public catalog says workouts are loaded, the browser actually shows visible clickable cards for them. Confirm the warning spam seen in Derrick’s screenshot is either removed or materially reduced to only legitimate residual warnings, and rerun validation/tests. Fix minimum QA defects if needed, commit/push by default, update the plan, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-visual-regressions.md`

**Status:** ✅ Complete

**Results:** QA reran the repo validation surface and the browser-facing proving seam after coder commit `0b9efaa` (`Fix workout browser listing viewport regression`). Validation passed with: `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. A focused scene-level QA probe against `res://scenes/workout_browser.tscn` with the repo’s local testbed config confirmed the public catalog path is no longer lying visually: `public_result_count=2`, `card_count=2`, `page_text="Page 1 of 1 · showing 2 of 2"`, scroll viewport height `603`, first card height `402`, and the first visible CTA button reads `Open Details` with `disabled=false`. That verifies the browser now shows visible, clickable cards instead of the blank area from `REF-07`. Warning cleanup outcome: the screenshot’s parser-warning spam from same-name `class_name` shadowing, the shadowing `name` parameter, and the unused placeholder-text parameter no longer appeared in the validation/scene runs. Residual warnings were limited to two pre-existing/non-blocking seams outside this bead’s visual regression scope: (1) `qa_verify_scene_output_updates.gd` still emits the known ObjectDB/resource-in-use warnings on exit, which the coder already called out as pre-existing and out-of-scope, and (2) GUT still prints one `Float/Int comparison` test-framework warning during `test_modio_vendor_adapter.gd`; this is not a browser-scene parser warning and did not correspond to a failed assertion or new regression in the touched browser files. Auditor follow-up later corrected one QA overstatement: the full live harness with stored-session auth was **not** reproducible as passing in the local config because the saved `/me` token now returns 401, so authenticated live-harness success should not be treated as part of this bead’s proof.

---

### Task 4: Audit the final visual/browser fix for truthfulness and completion

**Bead ID:** `oc-i9an`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently truth-check the visual/browser regression fix. Verify that loaded results really render as visible selectable cards, that the warning cleanup is real, and that the change did not silently re-break the prior public-fetch/session/layout work. Update the plan with the final audit verdict, commit/push any minimum audit fixes, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-visual-regressions.md`

**Status:** ✅ Complete

**Results:** Independent audit confirmed the fix is real and the bead is done, with one documentation correction to the QA handoff. Diff review of coder commit `0b9efaa` showed the browser-layout seam was fixed narrowly by giving the listing browser root/scroll viewport explicit expansion and by naming those nodes for testability, while the warning cleanup removed the same-name `class_name` shadowing preloads plus the `name`/unused-parameter warnings without widening scope. Audit validation reran `godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd`, `godot --headless --path .testbed --script res://tests/qa_verify_scene_output_updates.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`; all passed. A separate ad-hoc auditor scene probe (not the checked-in regression test) instantiated `res://scenes/workout_browser.tscn`, injected two public results, called `_update_listing_ui("public")`, and measured `card_count=2`, `scroll_size_y=603`, `scroll_rect_y=603`, `first_card_size_y=298`, plus a visible enabled `Open Details` button. That independently proves the browser now renders visible selectable cards instead of only reporting loaded state.

Warning cleanup also held up under audit: the parser-warning seam from `REF-08` no longer reproduced in the touched browser/env/session scripts, and file review confirmed the shadowing preloads were removed from `modio_workout_browser_testbed.gd`, `modio_env_loader.gd`, and `modio_session_config_store.gd`, `_listing_controls(name: String, ...)` became `_listing_controls(control_name: String, ...)`, and `_placeholder_texture(text: String)` became `_placeholder_texture(_text: String)`. Remaining warnings were accurately classifiable as pre-existing/out-of-scope rather than ignored: `qa_verify_scene_output_updates.gd` still exits with the known ObjectDB/resource-in-use warning despite returning success, and GUT still reports one unrelated `Float/Int comparison` framework warning during `test_modio_vendor_adapter.gd`.

For the prior public/session/layout seam, the audit split the proof by behavior: public-fetch still passes via `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --json --public-only` (all public reads `ok`), session restore still passes via `test_ready_restores_saved_email_without_wiping_session_values`, and layout still passes via the scene validation plus the independent viewport/card probe. One QA claim needed correction: the full live harness with stored-session auth does **not** currently pass in this local config because `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --json` now returns a 401 on `/me` (`error_ref 11005`, invalid/revoked/malformed access token) and exits non-zero. That failure appears to be environment/session-token drift rather than a regression from this UI/layout change because the failing seam is remote auth validity, while the touched code and restored-session unit path still behave correctly. No audit-sized product defect was found in the fix itself, so no code changes were required.

---

## Open Questions / Gaps To Resolve Before Execution

1. **Browser rendering root cause:** resolved for the research pass. The cards are being created and added to the correct grid; the visible failure is that the listing browser viewport/container collapses to zero height, clipping the populated grid away.
2. **Warning cleanup scope:** resolved for the touched seam. The screenshot warnings are legitimate parser warnings from local same-name preloads, a `name` parameter that shadows `Node.name`, and one intentionally-unused `text` parameter. They should be cleaned in the browser/env/session helper scripts only; no repo-wide warning sweep is needed.
3. **Residual warning tolerance:** if any warnings remain after the coder pass, they should be explicitly called out as outside this seam rather than bundled into this fix.

## Research Findings Snapshot

- `Loaded public (2 result(s)).` plus `Page 1 of 1 · showing 2 of 2` is truthful state, not a lying status label.
- `PublicCardsGrid` is populated; the failure is the collapsed card viewport.
- The blank-browser issue is **not** primarily caused by wrong-parent insertion, immediate clearing, or async thumbnail failure.
- The screenshot warnings are real, but they are secondary hygiene issues and not the root cause of the blank results area.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Fixed the workout-browser visual regression so loaded public/workout/subscribed results render as visible selectable cards again, and cleaned the screenshoted parser-warning seam in the touched browser/env/session helper scripts.

**Reference Check:** `REF-07` is now satisfied: independent audit confirmed the loaded-public state also renders a non-zero-height browser viewport with visible cards and an enabled `Open Details` CTA, rather than a blank clipped area. `REF-08` is satisfied for the targeted warning seam: the same-name `class_name` shadowing warnings plus the `name`/unused-`text` parser warnings no longer reproduce. Remaining warnings were reviewed and accurately classified as pre-existing/out-of-scope (`qa_verify_scene_output_updates.gd` ObjectDB/resource-in-use exit warning and one unrelated GUT `Float/Int comparison` framework warning).

**Commits:**
- `0b9efaa` - Fix workout browser listing viewport regression

**Lessons Learned:** For UI regressions, “data loaded” is not enough proof. The audit needs a visible-viewport assertion or scene probe so populated-but-clipped content cannot masquerade as a working browser. Also, QA notes should distinguish product regressions from environment drift; the stored auth token in the local session config expired, so the full live harness no longer proves authenticated reads even though the UI/session code path itself still does.

---

*Completed on 2026-05-31*