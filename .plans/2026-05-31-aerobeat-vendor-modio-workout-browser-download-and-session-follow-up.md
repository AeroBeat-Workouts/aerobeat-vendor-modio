# AeroBeat Vendor mod.io Workout Browser Download + Session Follow-Up

**Date:** 2026-05-31  
**Status:** In Progress  
**Last Updated:** 2026-05-31 18:19 EDT  
**Blocked Reason:** None  
**Agent:** `main`

---

## Goal

Fix the missing subscribe CTA in public workout details, redesign the detail panel into a right-docked slideout with a prominent bottom CTA, audit mod.io token lifetime/configurability, and determine/implement the safest truthful first step for downloading workout files from the subscribed/public browser.

---

## Overview

The Workout Browser proving surface is now substantially functional: workouts visually render, details can be opened, subscriptions can be created, and subscribed workouts appear correctly. Derrick’s latest review narrows the next slice into one UI correctness bug, one UI refinement, one authentication-policy audit, and one capability expansion. This is a healthy place to do another focused plan rather than broadening the previous slices in prose.

The first correctness bug is straightforward: the public-catalog detail panel is not showing the subscribe call to action even though the same athlete can successfully subscribe and later see the workout under Subscribed. That strongly suggests a local detail-panel state/CTA selection bug rather than a missing provider seam. We already know subscribe works; now the public-detail view needs to surface the right action consistently.

The second seam is presentation. Derrick wants the detail panel to stop behaving like a small floating popup and instead become a large right-side slideout anchored to the viewport, with a large bottom CTA. That is a legitimate layout improvement and fits the browser’s operator UX much better.

The third seam is session policy. The local official docs mirror already shows that mod.io access-token lifetimes are part of auth requests for some auth routes and that max lifetimes differ by auth method. We should audit the exact limits and whether email-code auth exposes configurable expiry in our current seam or only via other auth routes/admin settings. Derrick needs a practical answer: can we make athlete sessions last much longer, and if so where is that configured.

The fourth seam is downloads. The mod.io docs clearly expose modfile download data (`binary_url`, `date_expires`) and note that some games require download initiation via the API with expiring verification hashes. That means download is likely feasible, but the implementation details matter: whether the two dummy workouts actually have live modfiles/zip archives, whether the current wrapper already exposes enough normalized file/download info, and whether the testbed should use a file picker or an explicit path input first. We should audit the seam before promising the exact UX, but a Download action belongs in scope if the underlying modfile/download data is present.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Latest completed visual/browser baseline | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/archive/2026-05-31-aerobeat-vendor-modio-workout-browser-visual-regressions.md` |
| `REF-02` | Current Workout Browser scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/workout_browser.tscn` |
| `REF-03` | Current Workout Browser controller | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_workout_browser_testbed.gd` |
| `REF-04` | Current provider facade | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/AeroModIOManager.gd` |
| `REF-05` | Current adapter seam | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/modio_vendor_adapter.gd` |
| `REF-06` | Local mod.io auth docs mirror | `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/` |
| `REF-07` | Local mod.io schema/docs showing modfile download fields | `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/get-user-mods.api.mdx` and related modfile schema/docs |
| `REF-08` | Screenshot showing current detail panel state | `/workspace/.temp/nerve-uploads/2026/05/31/image-fd3c9a2c.png` |

---

## Tasks

### Task 1: Audit the public-detail CTA gap, token lifetime/configurability, and download seam

**Bead ID:** `oc-il80`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Audit four things: (1) why the public-catalog detail view is not showing the subscribe CTA even though subscription itself works, (2) whether mod.io token expiration is configurable through our current email-code auth seam, through other public auth routes, or through mod.io admin settings/docs, (3) what the truthful max/likely token lifetime is for the auth methods relevant to AeroBeat, and (4) whether the current wrapper/testbed seam has enough modfile/download data to support a first Download action for workouts, including whether the two known dummy workouts appear to have live modfiles/download info. Update the plan with concise findings and exact coder recommendations, then close the bead when done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-download-and-session-follow-up.md`

**Status:** ✅ Complete

**Results:** Research audit completed with four concrete findings. **CTA bug:** the issue is local CTA-branch selection, not provider auth, not subscription failure, and not bad detail data. In `modio_workout_browser_testbed.gd`, `_open_detail(entry, context)` only shows `Subscribe` for `TAB_WORKOUT` and `Unsubscribe` for `TAB_SUBSCRIBED`; the default/public branch explicitly hides the CTA, while public cards call `Open Details` with `context = TAB_PUBLIC`. That means public detail can never render the subscribe action even though `_on_detail_action_pressed()` already knows how to call `build_subscribe_request()` and the broader flow has proven subscribe works on the same sample workout. **Coder recommendation:** move CTA derivation off the current tab string and onto capability/state such as `(authenticated && detail is subscribable && not already subscribed)`; for public details, show `Subscribe` when an athlete token exists, disable with truthful copy when unauthenticated, and continue showing `Unsubscribe` only for subscribed inventory.

**Token configurability/lifetime:** the current email-code seam is more configurable than the UI currently uses. `build_auth_exchange_request(security_code, date_expires := 0)` already supports an optional `date_expires` and sanitizes it to a common-year max, while the current controller hard-codes `[code, 0]`, so the testbed always requests the default expiry instead of a custom one. The mod.io intro docs say access tokens default to one common year and any access-token-returning auth endpoint may accept `date_expires`; if omitted, or if greater than one year / earlier than server time, it falls back to the one-year default. By contrast, the studio-website OAuth code flow documents a fixed `expires_in = 2592000` (~30 days) plus refresh tokens (~90 days), and the in-game guidance says no refresh tokens exist for the game-client auth routes, so expiry handling there is re-auth based. Admin/dashboard-side identity settings documented here cover things like OAuth applications, OpenID config, claim mappings, redirect URLs, secrets, and auth-provider wiring — not a separate dashboard knob that lengthens in-game bearer lifetimes beyond the endpoint-level rules. **Coder recommendation:** expose honest session copy: email-code already defaults to the longest documented direct in-game bearer lifetime (about one year) and can only be shortened/request-shaped, not extended beyond one year; do not imply a dashboard toggle can make it effectively permanent. If AeroBeat ever wants silent long-lived renewals, that points to a secure backend OAuth web/server flow with refresh-token handling, not the current pure in-game email-code seam.

**Likely/max truthful lifetimes for AeroBeat-relevant auth:** for the current email-code path, the truthful likely/max lifetime is ~1 common year by default and at most one year when `date_expires` is requested. For other public in-game auth routes, the wrapper and docs show mixed caps: Apple/GOG/Google/Steam/OpenID-style flows are week-capped in the adapter, while Oculus/PSN/Switch/Xbox/email-exchange are year-capped there; regardless, docs still instruct clients to expect revocation/expiry and re-auth on 401. For website/server OAuth token exchange, access tokens are fixed at ~30 days and refresh tokens at ~90 days. **Coder recommendation:** any UI/help text should distinguish `email code / in-game bearer` from `website OAuth with backend refresh tokens`; do not collapse them into one “token lasts X” statement.

**Download seam:** the wrapper already has enough normalized data for a first download action. `normalize_modfile_response()` / `normalize_modfiles_response()` preserve `download.binary_url`, `download.date_expires`, `filename`, `filehash.md5`, and `resolve_download_request_from_modfile()` + `build_download_request()` already turn that into a download request object while explicitly warning that mod.io `binary_url` values are expiring delivery URLs, not canonical permanent URLs. Live public reads against the current test sandbox still show real modfiles for both known browser fixtures: workout `16112` has modfile `22687` (`tmp-oc-4wr-build-5by3.zip`, md5 `d4e48a959c4c798157697c8839a601c3`) and workout `16165` has modfile `22742` (`oc-meid-build-1778103465-0p1u.zip`, md5 `517ab5a833165edda569dfe69e283bc4`), each with a fresh `download.binary_url` and far-future `date_expires`. Prior harness evidence in the repo plan archive already proved the sample workout download URL resolves through mod.io/CDN and yields the expected ZIP bytes. The missing seam is UI/file I/O, not provider data. The hidden `.testbed` Godot project does not currently have any `FileDialog` or download-save workflow, so a first pass is realistic but should stay simple: resolve a fresh modfile/download URL when details open or when Download is pressed, let the operator choose or paste a destination path, save bytes with `FileAccess`, and verify md5 if present. Because native file dialogs are awkward to automate in headless QA, the safest first slice is a visible path field plus optional browse button rather than making the feature depend entirely on interactive picker automation.

---

### Task 2: Implement the public subscribe CTA fix, right-docked slideout, and approved token/download UI changes

**Bead ID:** `oc-kxqj`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Fix the public-catalog detail panel so it truthfully shows the subscribe CTA when the athlete can subscribe. Rework the detail panel into a large right-docked slideout anchored to the viewport with a prominent CTA at the bottom. If the research task confirms a safe/approved first-step download seam, add the Download action and path/file-picking UX in the agreed scope. Reflect the token-lifetime findings honestly in the UI/docs (for example, if email-code auth cannot be extended through our current seam, say so rather than implying that it can). Update tests/docs/plan, commit/push by default, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/workout_browser.tscn`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/tests/test_modio_workout_browser_testbed.gd`
- `README.md`
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-download-and-session-follow-up.md`

**Status:** ✅ Complete

**Results:** Implemented the coder slice in the Workout Browser controller/testbed docs/tests. The detail surface is now a large right-docked slideout anchored to the viewport instead of a centered popup. CTA logic no longer depends on the current browser-tab string: public detail now shows `Subscribe` when the workout has a valid mod id, disables that CTA with truthful auth-needed copy when the athlete is not authenticated, and flips to `Unsubscribe` when the item is already in subscribed state. The slideout also now includes a first-pass Download section with an explicit destination-path field, optional filesystem browse dialog, and a `Download ZIP` action that refreshes mod detail first, resolves a fresh expiring mod.io delivery URL from the current modfile, saves bytes with `FileAccess`, and md5-checks when the provider exposes a hash. Token-lifetime copy was tightened so the UI/README describe the email-code path honestly as the direct in-game bearer flow with about a one-year max rather than a permanent or dashboard-extendable session, and the exchange request now explicitly asks for the longest direct expiry this seam can truthfully request. Validation covered `validate_scaffold.gd`, `validate_modio_testbed_scenes.gd`, `qa_verify_scene_output_updates.gd`, the focused `test_modio_workout_browser_testbed.gd`, and the full GUT suite (`106/106` passing).

---

### Task 3: QA the subscribe CTA, slideout panel, and download/session behavior

**Bead ID:** `oc-x3ov`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Verify that the public-detail view now shows the subscribe CTA when appropriate, the new detail panel is right-docked and usable, and any download/token-lifetime messaging or actions behave truthfully. Confirm the subscribed-workout path still works and that no earlier browser/session regressions reappear. Run relevant validation/tests, fix minimum QA defects if needed, commit/push by default, update the plan, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-download-and-session-follow-up.md`

**Status:** ✅ Complete

**Results:** QA completed without finding a QA-sized defect. Automated validation passed end-to-end: `validate_scaffold.gd`, `validate_modio_testbed_scenes.gd`, `qa_verify_scene_output_updates.gd`, the focused `test_modio_workout_browser_testbed.gd` coverage embedded in the full GUT suite, and the full repo test run (`106/106` passing). A safe live harness pass against the configured mod.io test environment also succeeded for both public-only and authenticated sweeps: public browse still returned the two expected workout fixtures, public detail + modfile reads still exposed real file metadata (`16165` / `22742`, `oc-meid-build-1778103465-0p1u.zip`), authenticated `/me` and `/me/subscribed` reads still worked, and the subscribed listing still surfaced the expected workout instead of silently regressing.

Targeted QA findings: the public-detail flow now truthfully exposes `Subscribe` when athlete auth is absent/present as appropriate, the right-docked slideout is present in-scene and usable via the validated detail controls, and subscribed detail still flips to `Unsubscribe` instead of hiding the CTA. Session copy is also truthful: the UI/README describe the email-code path as a revocable/re-authable direct in-game bearer session with roughly a one-year max request, not as a permanent login or dashboard-extended token. Download behavior also matches the required truth surface: the controller refreshes mod detail before save, resolves a fresh expiring delivery URL from the latest modfile metadata, requires a destination path (with explicit field + browse dialog support), writes bytes via `FileAccess`, md5-checks when metadata is present, disables Download when no modfile `binary_url` exists, and reports explicit failure messages for empty-path, missing-modfile, invalid-download-URL, refresh-failure, HTTP, write-open, and md5-mismatch cases.

---

### Task 4: Audit the final CTA/session/download follow-up for truthfulness and scope discipline

**Bead ID:** `oc-58iq`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently truth-check the completed follow-up. Verify that the public-detail subscribe CTA is genuinely fixed, the right-side slideout is present, the token-lifetime/configurability messaging matches the actual docs/seam, and any download action only promises what the current wrapper/modfile/download seam can really support. Update the plan with the final audit verdict, commit/push any minimum audit fixes, and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-download-and-session-follow-up.md`

**Status:** ⏳ Pending

**Results:** Not started.

---

## Resolved Research Findings

1. **Public subscribe CTA gap:** resolved. The bug is a local detail-panel branch in `_open_detail()`: `TAB_PUBLIC` falls into the default case that hides the action button entirely, while only `TAB_WORKOUT` gets `Subscribe` and `TAB_SUBSCRIBED` gets `Unsubscribe`.
2. **Token lifetime configurability:** resolved. The current email-code seam does support optional `date_expires`, but the controller currently passes `0`, so it always uses the documented default. The documented admin/auth setup pages do not expose a separate “make game bearer tokens live longer” dashboard setting beyond choosing other auth architectures.
3. **Download UX shape:** resolved enough for implementation planning. The `.testbed` project has no existing `FileDialog`/save flow, so a first pass should prefer a simple explicit destination-path workflow, with an optional browse button later if desired.
4. **Dummy workout modfiles:** resolved. The two current public browser fixtures both expose live modfiles and fresh `download.binary_url` metadata, so Download can be wired conditionally off real data rather than invented placeholders.

---

## Research Summary For Execution

- **CTA fix direction:** derive the detail CTA from subscription capability/auth state instead of the current browser-tab string, so public-detail views can still surface `Subscribe`.
- **Session truth:** the current email-code path already defaults to the longest documented direct in-game bearer lifetime (~1 year) and can be shortened/request-shaped but not extended beyond one year through the current public seam.
- **Alt auth truth:** website/backend OAuth flows are a different architecture with fixed ~30-day access tokens and refresh tokens, useful for silent renewals only when AeroBeat adds a secure backend.
- **Download truth:** the wrapper already carries enough file/download metadata for a first real Download button, but the UI should fetch/use fresh URLs, present save-path control honestly, and treat download URLs as expiring delivery URLs instead of durable stored links.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Coder implementation and QA are now complete for the public/detail CTA fix, right-docked slideout redesign, truthful session-lifetime copy, and first-pass ZIP download workflow. The remaining stage in the parent plan is the independent auditor pass.

**Reference Check:** `REF-02` and `REF-03` now reflect the new slideout/download UI and CTA logic, while `REF-05`, `REF-06`, and `REF-07` still anchor the truthful token/download behavior: download URLs are treated as fresh expiring delivery URLs, and the email-code path is described as roughly one-year-max direct bearer auth rather than a permanent-login seam. QA also revalidated no silent regressions against the public browse / subscribed / session reads by running the repo validators plus the safe live harness against the configured test environment.

**Commits:**
- `726bbd6` - Implement workout browser CTA and download follow-up
- Pending QA plan-update commit/push.

**Lessons Learned:** The provider seam was already strong enough; the real work was making the operator-facing UI respect capability truth. The most important discipline was deriving state from auth/subscription/download facts instead of from whichever tab happened to launch the detail view.

---

*Completed on 2026-05-31*