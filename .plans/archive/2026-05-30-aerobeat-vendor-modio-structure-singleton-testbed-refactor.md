# AeroBeat Vendor mod.io Structure + Singleton + Testbed Refactor

**Date:** 2026-05-30  
**Status:** Complete  
**Last Updated:** 2026-05-30 15:59 EDT  
**Blocked Reason:** None  
**Agent:** `main`

---

## Goal

Refactor `aerobeat-vendor-modio` so its package layout and runtime entry pattern match the current AeroBeat repo conventions, then add one or more `.testbed` scenes that visually prove the mod.io functionality against the AeroBeat test mod.io server.

---

## Overview

This plan starts from a structure audit. Right now `aerobeat-vendor-modio` already follows the basic GodotEnv package shape (`src/`, `.testbed/`, tests, plugin metadata), but it does **not** currently look like the newer AeroBeat repos that expose a clear singleton/runtime entrypoint plus a more scene-driven `.testbed` proving surface.

The current mod.io repo is still heavily centered on a single large provider adapter (`src/modio_vendor_adapter.gd`) plus several command-line style harness scripts in `.testbed/`. That is useful for coverage, but it is structurally different from newer repos like `aerobeat-tool-api`, `aerobeat-tool-settings`, and `aerobeat-vendor-godot-video`, which more clearly separate: public entry seam, supporting classes, and visual/manual proving surfaces.

The refactor should keep the repo honest about its boundary: this repo is still the **vendor-specific mod.io layer**, not the public AeroBeat-facing API contract. So the singleton/pattern choice needs to match other AeroBeat repos **without accidentally promoting this repo into the wrong layer**.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current mod.io repo README and source layout | `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |
| `REF-02` | Current mod.io repo live/dev harness direction | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-project-and-dev-testing-path.md` |
| `REF-03` | Vendor template baseline | `/workspace/projects/aerobeat/aerobeat-template-vendor/` |
| `REF-04` | Example vendor repo with cleaner testbed scene layout | `/workspace/projects/aerobeat/aerobeat-vendor-godot-video/README.md` |
| `REF-05` | Example AeroBeat singleton/autoload tool pattern | `/workspace/projects/aerobeat/aerobeat-tool-api/src/AeroToolManager.gd` |
| `REF-06` | Example layered singleton facade delegating to internal manager | `/workspace/projects/aerobeat/aerobeat-tool-settings/src/AeroToolManager.gd` |

---

## Initial Audit Notes

### Current `aerobeat-vendor-modio`
- Good: already has `src/`, `.testbed/`, `tests`, `plugin.cfg`, `README.md`, GodotEnv addon manifest.
- Good: already has live test environment support and real test-server harness scripts.
- Gap: package entry surface is centered on `src/modio_vendor_adapter.gd` rather than a clearer repo-level runtime/service facade.
- Gap: `.testbed/` is mostly script-driven harnesses; it does not yet have a clear visual scene-based proving surface like other newer repos.
- Gap: current `src/` layout is shallow and provider-heavy (`models/`, `network/`, one large adapter) rather than obviously split into public seam vs internal pieces.

### Comparison signals from other AeroBeat repos
- `aerobeat-vendor-godot-video` is the closest structure/layout reference for this refactor.
- `aerobeat-tool-api` and `aerobeat-tool-settings` are still useful singleton-pattern references, but not the primary layout target.
- `aerobeat-vendor-godot-video` adds a cleaner public seam plus `.testbed/scenes/` and `.testbed/scripts/` for visual proving.
- The vendor template gives the minimum package skeleton, but `modio` has already outgrown that baseline.

### Polyrepo name-clash audit note
A quick sweep shows `AeroToolManager` still exists as a real published source name in multiple owning repos beyond the template repos, including:
- `aerobeat-tool-api` → `AeroApiManager`
- `aerobeat-tool-settings` → `AeroSettingsManager`
- `aerobeat-tool-content-authoring` → `AeroContentManager`
- `aerobeat-tool-camera-gesture-control` → `AeroCameraGestureControlManager`
- `aerobeat-tool-gaussian-splat-loader` → `AeroGaussianSplatLoader`

That means this planning slice now explicitly accounts for two layers of work:
1. refactor `aerobeat-vendor-modio` to use a collision-safe repo-specific singleton name: `AeroModIOManager`
2. plan the follow-up rename/migration work for the other non-template polyrepos still exporting the generic `AeroToolManager` global, including their repo-owned testbed scenes/scripts/tests, dependent repos that import them, and docs repos that describe those public surfaces

### Likely refactor direction
- Replace the generic/public runtime-entry direction with a repo-specific singleton/facade named `AeroModIOManager`.
- Keep the provider implementation seam (`modio_vendor_adapter.gd` or its successor) behind that clearer repo-owned entry seam.
- Introduce a scene-driven `.testbed/scenes/` + `.testbed/scripts/` structure for manual verification against test.mod.io.
- Prefer one fully separate scene per mod.io function group so flows do not fight for UI space and each scene can own its own controls/results.
- No shared index/home scene is needed.
- Plan to retire the current script-runner harnesses as the primary proving path; the GDScript singleton + visual scenes should become the canonical proving surface.
- For cross-repo rename fallout, dependency refresh should use the canonical helper `godotenv-sync`, not vanilla `godotenv` CLI flows.

---

## Tasks

### Task 1: Audit all directly touched and indirectly affected repos

**Bead ID:** `oc-3cv9`, `aerobeat-tool-api-bs8`, `aerobeat-tool-settings-8ws`, `aerobeat-tool-content-authoring-i1y`, `aerobeat-tool-camera-gesture-control-dbr`, `aerobeat-tool-gaussian-splat-loader-rl0`, `oc-yxm`, `aerobeat-environment-community-ejt`, `aerobeat-input-camera-tracking-dki`, `aerobeat-docs-zfrf`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Claim the relevant bead for your assigned repo(s). Audit the current singleton/export name, testbed scene/script surface, repo-owned tests, dependent-repo fallout, and docs touchpoints. Produce a repair map that lists exactly what must be renamed, what will break, which downstream repos import it, which docs/repos describe it, and which Godot testbed scenes must be opened as validation targets. Do not implement yet.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/`
- `/workspace/projects/aerobeat/aerobeat-tool-api/`
- `/workspace/projects/aerobeat/aerobeat-tool-settings/`
- `/workspace/projects/aerobeat/aerobeat-tool-content-authoring/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-gesture-control/`
- `/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/`
- `/workspace/projects/aerobeat/aerobeat-assembly-community/`
- `/workspace/projects/aerobeat/aerobeat-environment-community/`
- `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/`
- `/workspace/projects/aerobeat/aerobeat-docs/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-30-aerobeat-vendor-modio-structure-singleton-testbed-refactor.md`

**Status:** ✅ Complete

**Results:** Audited the direct owner repos, downstream consumers, docs/templates, gaussian facade fallout, and environment-loader consumer drift. That audit map correctly drove the later implementation, QA, and audit slices.

---

### Task 2: Lock the `aerobeat-vendor-modio` target structure and singleton seam

**Bead ID:** `oc-3cv9`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Using `aerobeat-vendor-godot-video` as the primary layout reference, define the target `src/` shape and public seam for `aerobeat-vendor-modio`. Be explicit about the final `AeroModIOManager` singleton boundary, which files remain provider-internal, and which legacy script-runner harness pieces should be retired or folded into the new scene-driven proving surface.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/*`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md`

**Status:** ✅ Complete

**Results:** Implemented the mod.io owner-repo seam as `AeroModIOManager`, kept `ModioVendorAdapter` behind it, preserved the legacy harness path, updated docs, and validated the new facade plus additive-first structure. Landed in commit `6b9557b`.

---

### Task 3: Design the scene-per-function-group mod.io testbed

**Bead ID:** `oc-3cv9`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-02`, `REF-04`  
**Prompt:** Design the visual `.testbed` proving surface for mod.io as fully separate scenes per function group. Name each scene, describe its controls/results area, define which test-server credentials/env values it consumes, and state exactly what user-visible proof each scene provides. No shared index scene.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/project.godot`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/*`

**Status:** ✅ Complete

**Results:** Added separate scene entrypoints for `public_catalog`, `authenticated_user`, `safe_write`, and `paid_mods`. Desktop-control interaction was blocked on this Wayland host, so an approved scripted visible-window fallback confirmed that each scene’s output surface updates correctly after the run action. QA helper/test landed in commit `9822214`.

---

### Task 4: Plan the four true singleton class-name renames in owning repos

**Bead ID:** `aerobeat-tool-api-bs8`, `aerobeat-tool-settings-8ws`, `aerobeat-tool-content-authoring-i1y`, `aerobeat-tool-camera-gesture-control-dbr`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-05`, `REF-06`  
**Prompt:** For each owning repo that truly exports `class_name AeroToolManager`, produce the exact rename/migration map to its repo-specific singleton name. Separate file-path rename, `class_name` rename, and any autoload/node-name fallout. Include source-file renames, `.gd.uid` expectations, testbed scene/script/test updates, README/doc touchpoints, stale-reference grep gates, and any compatibility shims that might be needed.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-api/`
- `/workspace/projects/aerobeat/aerobeat-tool-settings/`
- `/workspace/projects/aerobeat/aerobeat-tool-content-authoring/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-gesture-control/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/*/src/*`
- `/workspace/projects/aerobeat/*/.testbed/*`
- `/workspace/projects/aerobeat/*/README.md`
- `/workspace/projects/aerobeat/*/plugin.cfg`

**Status:** ✅ Complete

**Results:** Completed the four true singleton renames and validated them in their owner repos: `aerobeat-tool-api` (`854a85e`), `aerobeat-tool-settings` (`4ef6799`), `aerobeat-tool-content-authoring` (`50d09b1`), and `aerobeat-tool-camera-gesture-control` (`114a11a`).

---

### Task 5: Plan gaussian-splat facade/path cleanup as a paired owner+consumer rollout

**Bead ID:** `aerobeat-tool-gaussian-splat-loader-rl0`, `oc-yxm`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-04`  
**Prompt:** Treat `aerobeat-tool-gaussian-splat-loader` separately from the four true singleton renames. Lock the final public-surface story first: whether `AeroGaussianSplatManager` remains the public runtime class and whether the generic `src/AeroToolManager.gd` facade is renamed, shimmed, or removed. Then produce the paired migration plan for the owner repo and its confirmed checked-in downstream consumer `aerobeat-assembly-community`, including file-path/ext_resource fallout, UI text fallout, compatibility-shim decisions, and the exact refresh/validation order.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/`
- `/workspace/projects/aerobeat/aerobeat-assembly-community/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/src/*`
- `/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/.testbed/*`
- `/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/README.md`
- `/workspace/projects/aerobeat/aerobeat-assembly-community/scenes/tests/environment_contract_test_scene.tscn`
- `/workspace/projects/aerobeat/aerobeat-assembly-community/src/environment_contract_test_scene.gd`

**Status:** ✅ Complete

**Results:** Removed the obsolete gaussian wrapper while keeping `AeroGaussianSplatManager` as the public/runtime class (`9085f56`), and repaired the confirmed downstream assembly consumer plus addon-stack fallout in `aerobeat-assembly-community` (`32f63a5`).

---

### Task 6: Plan downstream repair work in dependent repos

**Bead ID:** `oc-yxm`, `aerobeat-environment-community-ejt`, `aerobeat-input-camera-tracking-dki`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-04`  
**Prompt:** Start with confirmed checked-in downstream consumers. Treat `aerobeat-assembly-community` as the primary direct consumer for gaussian facade/path fallout. Keep `aerobeat-environment-community` or `aerobeat-input-camera-tracking` as direct-touch repos only if checked-in singleton/path refs are found beyond addon mounting; otherwise downgrade them to validation-only fallout. Prefer repo-owned refresh helpers first, then `godotenv-sync` where appropriate. Explicitly record that `aerobeat-assembly-community` currently has a Beads identity mismatch so execution prompts must either resolve that first or consistently use the approved workaround.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-assembly-community/`
- `/workspace/projects/aerobeat/aerobeat-environment-community/`
- `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/*/.testbed/addons.jsonc`
- `/workspace/projects/aerobeat/*/.testbed/project.godot`
- `/workspace/projects/aerobeat/*/.testbed/scenes/*`
- `/workspace/projects/aerobeat/*/.testbed/scripts/*`

**Status:** ✅ Complete

**Results:** Confirmed `aerobeat-assembly-community` as the direct gaussian/environment-loader downstream consumer, repaired it, and then hardened `aerobeat-environment-loader` restore/validation coverage against manifest drift in commit `1ffddc3`.

---

### Task 7: Plan docs and template fallout for renamed singleton surfaces and the new mod.io testbed

**Bead ID:** `aerobeat-docs-zfrf`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Audit `aerobeat-docs` for architecture/API/repo-structure references that describe the old `AeroToolManager` naming or the pre-refactor mod.io surface. Include docs templates as source-of-truth fallout (`templates/tool/`) and explicitly separate source docs from generated site output. Lock the current template strategy to a human/agent-required post-clone rename step for now (not token replacement yet), and record whether `aerobeat-template-tool` and `aerobeat-template-vendor` need same-slice changes, trailing follow-up work, or an explicit defer note so future repos do not reintroduce the old naming/layout.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-docs/`
- `/workspace/projects/aerobeat/aerobeat-template-tool/`
- `/workspace/projects/aerobeat/aerobeat-template-vendor/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-docs/docs/*`
- `/workspace/projects/aerobeat/aerobeat-docs/templates/tool/**`
- `/workspace/projects/aerobeat/aerobeat-docs/.plans/*`
- `/workspace/projects/aerobeat/aerobeat-docs/README.md`
- `/workspace/projects/aerobeat/aerobeat-template-tool/src/*`

**Status:** ✅ Complete

**Results:** Updated docs/templates to teach repo-specific manager naming, post-clone rename guidance, and vendor-specific facade naming. Landed in `aerobeat-docs` (`8d084f1`), `aerobeat-template-tool` (`7efc190`), and `aerobeat-template-vendor` (`b8bba8e`), then fixed the final docs audit blocker in `aerobeat-docs` with `56c34f4`.

---

### Task 8: Define the validation matrix, including opening Godot testbed scenes without errors

**Bead ID:** `oc-3cv9`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-04`  
**Prompt:** Define the execution-time validation matrix for this refactor family. Use an owner-first, consumer-second refresh order. Include repo-local unit tests, singleton/autoload checks, `.gd.uid` expectations, post-rename stale-reference grep gates, repo-specific refresh helpers where they exist, and explicit Godot validation by exact scene path or test entrypoint. For scene-bearing repos, target scenes must open without load/parse/script errors; for scene-less repos, the `.testbed` project must import cleanly and the relevant headless/unit checks must pass.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-api/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-settings/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-content-authoring/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-gesture-control/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-assembly-community/scenes/`
- `/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/*/.testbed/project.godot`
- `/workspace/projects/aerobeat/*/.testbed/scenes/*`
- `/workspace/projects/aerobeat/*/.testbed/scripts/*`
- `/workspace/projects/aerobeat/*/.testbed/tests/*`
- `/workspace/projects/aerobeat/*/src/*.gd`
- `/workspace/projects/aerobeat/*/src/*.gd.uid`
- `/workspace/projects/aerobeat/*/README.md`

**Status:** ✅ Complete

**Results:** The validation matrix was exercised in practice across the rollout: owner-first refresh/import/test ordering, repo-specific helpers, exact scene opens, `.gd.uid` behavior, stale-reference sweeps, and docs builds where available. The final independent audit passed after the narrow docs blocker was repaired.

---

## Locked Decisions

1. Structure/layout parity target is primarily `aerobeat-vendor-godot-video`, with `aerobeat-tool-api` + `aerobeat-tool-settings` used only as singleton-pattern references.

2. The mod.io singleton/facade name should be `AeroModIOManager`.

3. Visual proving direction is one fully separate scene per mod.io function group.

4. No index/home scene is needed.

5. The mod.io migration should be additive first: add `AeroModIOManager` and the scene-based proving surface first, keep the existing headless harness/lib path until scene parity is proven, then retire old entrypoints later.

6. `AeroModIOManager` is a repo-local/vendor-facing facade for `aerobeat-vendor-modio`, not a replacement for the broader public AeroBeat-facing API layer owned by `aerobeat-tool-api`.

7. The four true `class_name AeroToolManager` renames should follow this mapping:
   - `aerobeat-tool-api` → `AeroApiManager`
   - `aerobeat-tool-settings` → `AeroSettingsManager`
   - `aerobeat-tool-content-authoring` → `AeroContentManager`
   - `aerobeat-tool-camera-gesture-control` → `AeroCameraGestureControlManager`

8. `aerobeat-tool-gaussian-splat-loader` is resolved as a facade/path cleanup, not a new singleton rename: `AeroGaussianSplatManager` stays the real public/runtime class, the generic `src/AeroToolManager.gd` wrapper should be removed, and downstream consumers must be repaired in the same rollout.

9. Cross-repo refactors must update repo-owned testbed scenes/scripts/tests plus only the dependent repos with confirmed checked-in imports or file-path consumers. Validation-only downstream repos should stay validation-only unless new evidence appears.

10. Dependency refresh/update work should prefer repo-owned restore/refresh helpers first, then `godotenv-sync` where appropriate, rather than assuming one identical refresh path for every repo.

11. Template repos should stop teaching `AeroToolManager` as an acceptable final state. For now, the rollout assumes a human/agent-required post-clone rename step after GitHub template generation rather than a token-replacement/bootstrap system.

12. `aerobeat-template-vendor` should teach the newer vendor-specific singleton/facade style and cleaner public-seam-vs-provider-implementation layout rather than remaining silent on repo-specific manager naming.

---

## Execution Gates

1. **Boundary gate:** lock that `AeroModIOManager` stays a repo-local/vendor-facing facade and does not silently become the generic downstream public API layer.
2. **Compatibility-shim gate:** do not remove old names/paths until there is either a zero-known-consumer check or an approved temporary shim path.
3. **Actual-consumer gate:** treat only confirmed checked-in runtime/file-path consumers as direct-touch rollout repos; keep others validation-only unless new evidence appears.
4. **Docs/site gate:** update source docs/templates and rebuild/validate docs as needed, but do not treat generated `site/` output as hand-edited source-of-truth work.
5. **Mod.io safe-write gate:** new mod.io scenes must preserve the current safe posture around unsupported paid/team/S2S write lanes and must not move secrets into committed scene resources or inspector defaults.
6. **Refresh-order gate:** owner repo refresh/import/test must pass before dependent repos are refreshed and validated.

---

## Final Results

**Status:** ✅ Complete

**What We Built:**
- Completed the singleton-refactor rollout across the in-scope AeroBeat repos.
- Added `AeroModIOManager` plus per-group mod.io testbed scenes while preserving the existing harness path during parity rollout.
- Removed the obsolete gaussian wrapper path and repaired the direct downstream assembly consumer.
- Updated docs/templates so future repos stop shipping generic `AeroToolManager` names as final state.
- Added fallback scene-output QA coverage and cleared the final docs audit blocker.

**Reference Check:**
- `REF-01` through `REF-06` informed the final repo structure, singleton boundary, vendor layout parity, and testbed proving-surface decisions.

**Commits:**
- `854a85e` - Rename AeroToolManager to AeroApiManager
- `4ef6799` - Rename AeroToolManager to AeroSettingsManager
- `50d09b1` - Rename AeroToolManager to AeroContentManager
- `114a11a` - Rename AeroToolManager to AeroCameraGestureControlManager
- `9085f56` - Remove gaussian wrapper shim
- `32f63a5` - Repair environment contract addon stack
- `1ffddc3` - Harden manifest drift validation
- `8d084f1` - Clarify tool manager naming guidance
- `7efc190` - Teach post-clone tool manager rename
- `b8bba8e` - Document vendor-specific facade naming
- `56c34f4` - docs: refresh stale repo structure references
- `6b9557b` - Add AeroModIOManager and scene-based modio testbed
- `9822214` - Add mod.io scene output QA script

**Lessons Learned:**
- The riskiest fallout was not the direct class renames; it was downstream consumer manifests, wrapper-path consumers, and stale source-of-truth docs.
- For this AeroBeat stack, additive-first vendor rollouts plus owner-first refresh/validation were the right shape.
- The desktop-control path on this Wayland host is not always a truthful UI-verification substrate for Godot scenes; keeping a narrow scripted fallback QA path was worthwhile.

---

*Completed on 2026-05-30*
