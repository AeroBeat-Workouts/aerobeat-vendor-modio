# AeroBeat Vendor mod.io Workout Browser Visual Regression Follow-Up

**Date:** 2026-05-31  
**Status:** In Progress  
**Last Updated:** 2026-05-31 15:32 EDT  
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

**Status:** ⏳ Pending

**Results:** Not started.

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

**Status:** ⏳ Pending

**Results:** Not started.

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

**Status:** ⚠️ Partial

**What We Built:** Completed the research/audit pass for the visual regression. The current evidence says the browser already fetches and populates cards, but the listing viewport collapses to zero height, so the populated grid is clipped out of view. Also isolated the exact parser-warning sources in the browser/env/session helper scripts.

**Reference Check:** `REF-07` is explained by the zero-height listing viewport despite non-empty public results. `REF-08` is explained by legitimate parser warnings from same-name local preloads plus the `name`/unused-`text` parameter warnings in `REF-03`/`REF-04`/`REF-05`.

**Commits:**
- None yet.

**Lessons Learned:** A proving surface can have the right data/state transitions and still fail operator trust if the visible container collapses. Screenshot-driven review caught a layout regression that data/status assertions alone would miss.

---

*Completed on 2026-05-31*