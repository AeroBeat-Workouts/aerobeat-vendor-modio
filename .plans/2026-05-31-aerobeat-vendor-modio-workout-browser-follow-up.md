# AeroBeat Vendor mod.io Workout Browser Follow-Up

**Date:** 2026-05-31  
**Status:** In Progress  
**Last Updated:** 2026-05-31 15:12 EDT  
**Blocked Reason:** None  
**Agent:** `main`

---

## Goal

Fix the missing public-catalog workouts in the new Workout Browser scene, improve the scene layout with top-level Connection/Auth/Browser tabs, persist/reload athlete email + auth session values across scene reopen, and determine whether mod.io supports athlete username/display-name changes so we can either implement or explicitly defer that capability truthfully.

---

## Overview

The first Workout Browser plan landed the new proving surface successfully, but Derrick’s manual review exposed a functional regression and a UX improvement seam. The major correctness issue is that the public catalog is not showing the two expected AeroBeat test-server workouts even though the scene otherwise works and athlete auth succeeds. That makes the next slice less about inventing new features and more about truth-checking the query/UI state path against the real provider data so the browser is actually useful.

The second seam is layout. Right now too much vertical space is consumed by connection/auth/browser controls living together. Moving to three top-level global tabs — `Connection`, `Auth`, and `Browser` — should give the browser area more room without changing the underlying provider boundaries. This is a UI architecture refinement, not a scope expansion.

The third seam is athlete naming. Derrick wants a fast yes/no answer on whether mod.io exposes a supported way for an athlete to change their public/display name through the public REST/API seam we currently have. A quick local-docs pass did not surface an obvious public "edit current user/profile" REST page, so we should treat that as an explicit audit item rather than assuming the capability exists. If no official route exists in the public API, the testbed should stay honest, avoid inventing profile-edit UI, and simply report the capability as unavailable through our current REST access even if mod.io may support profile edits elsewhere on the website.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Existing follow-up baseline from the landed Workout Browser scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/archive/2026-05-31-aerobeat-vendor-modio-workout-browser-testbed.md` |
| `REF-02` | Current default `.testbed` project entrypoint | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/project.godot` |
| `REF-03` | Current Workout Browser scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/workout_browser.tscn` |
| `REF-04` | Current Workout Browser controller | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_workout_browser_testbed.gd` |
| `REF-05` | Current env/config loader | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_env_loader.gd` |
| `REF-06` | Existing provider manager facade | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/AeroModIOManager.gd` |
| `REF-07` | Existing adapter request builders / browse seam | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/modio_vendor_adapter.gd` |
| `REF-08` | mod.io docs corpus for user/account capability audit | `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/` |

---

## Tasks

### Task 1: Audit the missing public-catalog workout visibility, auth persistence gap, and athlete-name capability

**Bead ID:** `oc-jl1i`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Audit why the new Workout Browser scene is not showing the two expected public AeroBeat test-server workouts in the catalog even though public browse should work. Use the existing scene/controller/query/config code plus the provider seam to determine whether the issue is query shaping, pagination/filter defaults, visibility/status assumptions, environment mismatch, or UI rendering. Also audit why athlete email/auth session values are not being restored when the scene is closed and reopened even though persistence was intended. Finally, audit the official mod.io docs/wrapper seam for athlete username/display-name change capability and report a clear yes/no on whether a supported public REST route exists through our current access. Update the plan with a concrete findings summary and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-follow-up.md`

**Status:** ✅ Complete

**Results:** Research audit completed.
- **Public catalog finding:** the provider/query seam is already returning the two expected test workouts on the test environment with the current public browse route (`GET /games/{game_id}/mods`). Live check against `https://g-1325.test.mod.io/v1/games/1325/mods?api_key=...&_limit=9&_offset=0` returned exactly two public results — `oc-meid collection seed 1 1778103465` (mod `16165`) and `oc-4wr sandbox pagination sample 1778082871` (mod `16112`) — both `status=1` and `visible=1`. The code path for public fetch is not auto-triggered on scene load/reload; `_load_initial_state()` only hydrates config/session state and rebuilds the manager, while `_fetch_listing(TAB_PUBLIC)` currently runs only from explicit UI actions like **Apply & Refresh Public** (`REF-04`). So this is **not** query shaping, pagination, visibility, or env mismatch; it is an **initial-load / reload UX gap** in the scene controller.
- **Persistence finding:** the session store works, but the browser only persists a partial auth state. Email is kept only in memory (`state.email`) and is never written by `ModioSessionConfigStore.save_session_values()`. The exchange path writes only `access_token`, and the `/me` refresh path writes `access_token` + `user_id`; `_load_initial_state()` reads back only config-derived `access_token` + `user_id`. Result: token/user id can survive, but the athlete email is excluded by design and profile/wallet/purchase data are not rehydrated on reopen unless the operator refreshes again (`REF-04`).
- **Athlete-name capability finding:** **No — not through our current public REST seam.** The local mod.io docs mirror exposes `GET /me` (`get-authenticated-user.api.mdx`) but no public `PATCH/PUT/POST /me` or other current-user profile-edit endpoint, and this repo’s adapter only implements authenticated-user read coverage, not profile mutation (`REF-07`, `REF-08`). For design purposes the truthful answer is that athlete username/public display-name changes are **not supported through our current REST access**.
- **Coder-pass recommendation:** (1) auto-fetch the public catalog after initial state load / defaults reload when public browse credentials are already present, so the expected workouts appear immediately on scene open; (2) persist and restore the athlete email explicitly in the session config, and decide whether reopen should also auto-hydrate `/me` + wallet + purchases when a stored token exists or at minimum surface that only token/user-id persistence is guaranteed; (3) keep any athlete-name UI read-only / informational unless a different supported seam is introduced later.

---

### Task 2: Implement the catalog fix, auth persistence, and top-level Connection/Auth/Browser tab layout

**Bead ID:** `oc-ofbq`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Fix the public-catalog issue so the expected AeroBeat test-server workouts surface correctly in the Workout Browser scene. Also fix auth persistence so athlete email plus the intended reusable session values are restored when the test scene is closed and reopened. Rework the scene layout so the top-level UI is organized into global tabs `Connection`, `Auth`, and `Browser`, with the browser section gaining more vertical room while preserving the approved provider/auth boundaries. If the research task confirms a supported athlete name-change route, implement it truthfully; otherwise keep the UI honest and document the unsupported/deferred state. Update tests/docs/plan, commit/push by default, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/workout_browser.tscn`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/scripts/modio_workout_browser_state.gd`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `README.md`
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-follow-up.md`

**Status:** ✅ Complete

**Results:** Coder pass completed and kept the scope bounded to the approved follow-up. Implemented the controller-side auto-fetch so the public catalog now loads automatically on scene open/reload when valid public config already exists, which surfaces the expected two test-server workouts without requiring the operator to press a manual refresh button. Reworked the scene into top-level `Connection`, `Auth`, and `Browser` tabs while preserving the existing inner browser sub-tabs and provider/auth boundaries. Persisted/restored athlete email plus reusable browser/auth session values in `modio.session.local.cfg`, and upgraded reopen behavior so a stored token now attempts a truthful `/me` + wallet + purchase-history rehydration; when that auto-refresh fails, the auth panel now says so explicitly instead of pretending the richer session is restored. The scene also stays honest that athlete username/public display-name editing is deferred/read-only because the current public REST seam does not support it. Updated scene validation + QA smoke coverage, expanded the session-store test to cover email/browser-tab persistence, updated README + this plan, and ran `validate_modio_testbed_scenes.gd`, `qa_verify_scene_output_updates.gd`, and the full GUT suite successfully.

---

### Task 3: QA the follow-up scene behavior against Derrick’s manual review feedback

**Bead ID:** `oc-t7rc`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Verify the follow-up Workout Browser behavior end-to-end. Confirm the expected test-server public workouts appear in the catalog, the new Connection/Auth/Browser layout gives the browser more vertical room, auth still works truthfully, and any athlete-name capability is implemented only if backed by the official seam. Run relevant validation/tests, record exact behavior, fix minimum QA defects if needed, commit/push by default, update the plan, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-follow-up.md`

**Status:** ⏳ Pending

**Results:** Not started.

---

### Task 4: Audit the final follow-up scene for truthfulness and scope discipline

**Bead ID:** `oc-k065`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently truth-check the follow-up Workout Browser changes against this plan. Verify the public-catalog fix actually surfaces the intended workouts, the global tab redesign is present, auth/browse boundaries remain honest, and no unsupported athlete-name edit UI was invented if the official public API does not support it. Update the plan with the final audit verdict, commit/push any minimum audit fixes, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `README.md`
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-follow-up.md`

**Status:** ⏳ Pending

**Results:** Not started.

---

## Resolved Research Notes

1. **Why the two workouts are missing:** resolved. The public REST query already returns both expected test-server workouts on page 1 with the current env/config. The gap is that the scene does not auto-run the public fetch on open/reload, so the catalog stays empty until the operator presses an explicit fetch action.
2. **Auth persistence gap:** resolved. Persistence is partial by design today: `access_token` and later `user_id` are written/read, but athlete email is never stored, and reopen does not auto-hydrate `/me`/wallet/purchases from the stored token.
3. **Athlete name-change capability:** resolved. No supported public REST route was found in the local mod.io docs mirror or current adapter coverage for changing the authenticated athlete’s username/public display name.
4. **Browser sub-tab layout inside the new top-level Browser tab:** still an implementation choice for the coder pass, but it is now bounded: keep the existing profile/workout/subscribed separation while avoiding any invented profile-edit capability.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Research plus coder implementation are now complete for the follow-up slice. The Workout Browser scene now auto-loads the public catalog when saved public config is already present, reorganizes the top-level UI into `Connection` / `Auth` / `Browser`, persists/restores athlete email with the reusable auth/browser session values, and attempts a truthful reopen rehydration of `/me` + wallet + purchase history from a stored token while explicitly warning when that restore fails. Unsupported athlete username/display-name editing remains out of scope and is presented only as deferred/read-only.

**Reference Check:** `REF-03`, `REF-04`, `REF-05`, `REF-07`, and `REF-08` were checked during implementation. The final coder-pass behavior matches the research findings: the fix is controller UX + persistence/layout work, not a provider browse change, and no unsupported profile-edit mutation was invented.

**Commits:**
- Pending coder commit/push in this bead handoff.

**Lessons Learned:** The biggest win here was treating reopen behavior as a truthfulness problem, not just a storage problem: persisting a token is not enough if the scene implies a richer restored athlete session than it actually rehydrates.

---

*Completed on 2026-05-31*