# AeroBeat Vendor Mod.io Bootstrap

**Date:** 2026-05-02  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Bootstrap `aerobeat-vendor-modio` as a clean AeroBeat vendor-adapter repo with the expected package metadata, GodotEnv `.testbed` workflow, README cleanup, initial adapter-oriented source layout, and a first implementation-ready seam plan for mod.io auth/listing/download integration.

---

## Overview

Derrick approved the initial bootstrap items for the newly created `aerobeat-vendor-modio` repo. This repo is intended to be the provider-specific adapter seam behind `aerobeat-tool-api`, not a product repo and not the AeroBeat-facing singleton itself. The bootstrap should therefore optimize for a reusable Godot package shape, a clear vendor-adapter README, a stable place for future provider interfaces/transport code, and a local `.testbed/` workbench that matches the existing AeroBeat GodotEnv workflow.

This first slice should stay modest. We are not trying to fully implement mod.io integration yet. We are establishing the repo identity, source layout, dependency posture, and the first documented seam for auth/listing/download work so later implementation can proceed cleanly without re-litigating repo shape.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active bootstrap plan | `.plans/2026-05-02-aerobeat-vendor-modio-bootstrap.md` |
| `REF-02` | Existing repo state and root license | `.` |
| `REF-03` | Tool repo example for package/testbed shape | `../aerobeat-tool-api` |
| `REF-04` | UGC API manager topology decision | `../aerobeat-docs/docs/architecture/ugc-api-manager-topology.md` |
| `REF-05` | UGC hybrid integration architecture | `../aerobeat-docs/docs/architecture/ugc-hybrid-integration-architecture.md` |
| `REF-06` | Workflow guidance for repo templates and GodotEnv | `../aerobeat-docs/docs/architecture/workflow.md` |

---

## Tasks

### Task 1: Bootstrap repo metadata, testbed, and initial adapter layout

**Bead ID:** `oc-6z0`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Bootstrap the repo with the approved initial scaffold: add `plugin.cfg`, clean up `README.md` so it clearly describes the vendor-adapter role, create a GodotEnv-compatible `.testbed/` setup if missing, add an initial source layout oriented around a provider adapter seam, and add a first implementation-ready seam plan for mod.io auth / listing / download integration. Keep the code/doc shape minimal but real; do not implement full network behavior yet unless required for the scaffold. Update the active plan with what actually happened, run any repo-local validation that makes sense, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `plugin.cfg`
- `README.md`
- `.gitignore`
- `.testbed/addons.jsonc`
- `.testbed/project.godot`
- `.testbed/addons/.editorconfig`
- `.testbed/src` (symlink)
- `.testbed/tests/validate_scaffold.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `src/modio_vendor_adapter.gd`
- `src/models/modio_client_config.gd`
- `src/models/modio_listing_query.gd`
- `src/models/modio_download_request.gd`
- `src/network/modio_http_transport.gd`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-02-aerobeat-vendor-modio-bootstrap.md`

**Status:** ✅ Complete

**Results:** Bootstrapped the repo as a reusable Godot package with a new `plugin.cfg`, a rewritten README that positions this repo as the provider-specific mod.io adapter behind `aerobeat-tool-api`, a minimal but real `.testbed/` workbench (`addons.jsonc`, `project.godot`, `src` symlink bridge, scaffold validation script, and a first GUT test), and an implementation-ready `src/` seam built around `ModioVendorAdapter`, provider-local request/config DTOs, and a transport helper. Added `docs/modio-seam-plan.md` to document the next auth/listing/download slices without prematurely implementing live network behavior. Validation run: `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` and `godot --headless --path .testbed --import`. Commit/push: `e34ca37` (`Bootstrap mod.io vendor adapter scaffold`). Validated against `REF-03` through `REF-06` while keeping provider-specific concerns local to this repo.

---

### Task 2: QA the bootstrap scaffold

**Bead ID:** `oc-dev`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify that the new bootstrap scaffold matches the vendor-adapter role: correct package metadata, clear README, sensible `.testbed` workflow, and an initial adapter-oriented source layout that does not blur into `aerobeat-tool-api`. Make only minimum necessary fixes, rerun validation, update the active plan, commit/push if changes were made, and close the bead with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- bootstrap scaffold files under repo root / `src/` / `.testbed/`
- `.plans/2026-05-02-aerobeat-vendor-modio-bootstrap.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Audit the bootstrap scaffold

**Bead ID:** `oc-nvz`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the bootstrap scaffold. Confirm the repo now looks like a proper AeroBeat vendor adapter package, that the source layout and docs keep vendor-specific concerns local to this repo, and that the new seam plan is implementation-ready without overcommitting to premature structure. Make only minimum necessary fixes, rerun validation, update the active plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- bootstrap scaffold files under repo root / `src/` / `.testbed/`
- `.plans/2026-05-02-aerobeat-vendor-modio-bootstrap.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⏳ In Progress

**What We Built:** Coder bootstrap complete: reusable package metadata, vendor-adapter README, GodotEnv-compatible `.testbed/` workbench, initial adapter-oriented `src/` seam, and a first mod.io seam plan doc. QA and audit are still pending.

**Reference Check:** `REF-03` informed the package/testbed shape; `REF-04` and `REF-05` informed the repo-role boundary and adapter seam; `REF-06` informed the GodotEnv/testbed workflow and versioning posture.

**Commits:**
- `e34ca37` - Bootstrap mod.io vendor adapter scaffold

**Lessons Learned:** The smallest useful scaffold here is request-shape and seam documentation, not live HTTP behavior. A tiny headless validation script gives immediate repo-local confidence even before GodotEnv dependencies are restored.

---

*Completed on 2026-05-02*
