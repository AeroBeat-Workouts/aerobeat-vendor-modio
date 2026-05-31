# AeroBeat Vendor mod.io Workout Browser Testbed

**Date:** 2026-05-31
**Status:** In Progress
**Last Updated:** 2026-05-31 12:47 EDT
**Blocked Reason:** None
**Agent:** `main`

---

## Goal

Create a new `.testbed/` default scene named `Workout Browser` that can authenticate an AeroBeat athlete against mod.io, switch between test/live server targets, and expose profile, browse, and subscribed-workout views from the existing vendor-modio seam.

---

## Overview

`aerobeat-vendor-modio` already has a strong provider seam and a hidden `.testbed/` Godot project, but the current proving surface is split into separate function-group scenes (`public_catalog`, `authenticated_user`, `safe_write`, `paid_mods`) and the README explicitly says there is intentionally no index scene. Derrick's new request intentionally changes that posture: instead of isolated proving scenes, we would add a new operator-facing exploratory UI that becomes the default `.testbed` entrypoint.

The repo appears technically ready for this in terms of backend coverage. The adapter already wraps the main reads we need for this experience: authenticated user profile (`GET /me`), public workout browse (`GET /games/{game-id}/mods`), and subscribed workouts (`GET /me/subscribed`). The main design risk is not missing REST coverage; it is aligning the testbed UX with the real mod.io auth model, deciding how much stateful workflow belongs in a vendor testbed scene, and defining what "Workout Browser" should prove versus what should remain in separate dedicated harnesses.

Derrick has now clarified the intended direction for this scene. The auth flow should use real mod.io auth rather than a fake username/password façade. The new Workout Browser scene is expected to become the meaningful operator-facing proving surface, while the current focused scenes remain valuable as smoke-test entrypoints. The browser scope is also now explicit: search + sort, tags/filters, pagination, thumbnail/name cards, a detail popup with close affordance, and subscribe/unsubscribe calls to action depending on the active browser mode. Public connection controls should expose the three key environment values in the scene UI - Server (`Test | Live`, default `Test`), Game ID, and API Key - prefilled to AeroBeat test-server defaults but editable as needed.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Repo boundary and current testbed posture | `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |
| `REF-02` | Current `.testbed` default main scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/project.godot` |
| `REF-03` | Existing authenticated-user scene scaffold | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/authenticated_user_testbed.tscn` |
| `REF-04` | Existing authenticated-user scene script | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_authenticated_user_testbed.gd` |
| `REF-05` | Existing scene-runner grouping and readiness logic | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_scene_runner.gd` |
| `REF-06` | Existing env/config loader for test/live selection and tokens | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_env_loader.gd` |
| `REF-07` | Existing provider manager/facade entrypoint | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/AeroModIOManager.gd` |
| `REF-08` | Existing mod.io auth request builders | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/modio_vendor_adapter.gd` |
| `REF-09` | Prior paid/authenticated harness plan showing current auth assumptions | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-17-aerobeat-vendor-modio-paid-mods-test-server-validation.md` |

---

## Tasks

### Task 1: Audit the current vendor-modio `.testbed` scene architecture against the requested Workout Browser flow

**Bead ID:** `oc-bnhy`
**SubAgent:** `primary` (for `research`)
**Role:** `research`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Audit the existing `.testbed` scenes, scene-runner flow, env/config handling, and adapter coverage against the proposed Workout Browser UX. Produce a gap analysis covering auth model fit, test/live switching, scene ownership/boundary changes, state flow, and missing browse/profile/subscription UI helpers. Update the plan with a concrete architecture recommendation and close the bead when done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/scenes/`
- `.testbed/scripts/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-testbed.md`

**Status:** ✅ Complete

**Results:** Architecture audit complete. The existing vendor seam already covers the approved data lanes: public browse (`build_listing_request`), athlete profile (`build_authenticated_user_request`), athlete subscriptions (`build_user_subscriptions_request`), subscribe/unsubscribe writes, wallet (`build_user_wallet_request`), purchased history (`build_user_purchased_request`), auth email request/exchange, and payment-method-id normalization on wallet / checkout payloads. The main gap is not endpoint coverage; it is that the current `.testbed` only exposes four tiny single-button smoke scenes, has no writable session-config helper, no UI state controller, no reusable async request/pagination helper, and no default-scene/browser shell for the now-approved Workout Browser flow.

#### Task 1 Architecture Audit Findings

**Reusable pieces already in repo**
- `src/AeroModIOManager.gd` is the right seam root for the scene: it already owns config, adapter, transport, and one-call `execute_adapter_request(...)` dispatch.
- `src/modio_vendor_adapter.gd` already exposes the exact backend calls the scene needs for this slice: `build_email_security_code_request`, `build_auth_exchange_request`, `build_authenticated_user_request`, `build_listing_request`, `build_user_subscriptions_request`, `build_subscribe_request`, `build_unsubscribe_request`, `build_user_wallet_request`, and `build_user_purchased_request`.
- `src/models/modio_listing_query.gd` already gives the browser most of its request-shaping surface for search / sort / tags / pagination. The coder should reuse it instead of hand-building query strings.
- `src/modio_vendor_adapter.gd` already normalizes useful card/detail fields (`name`, `name_id`, `summary`, `description_plaintext`, `logo`, `media`, `stats`, `price`, `tax`, `tags`, `metadata_kvp`, `skus`) plus wallet `payment_method_id` and purchased-history rows.
- `.testbed/scripts/modio_env_loader.gd` already resolves `test|live`, stable-vs-session config layering, and the canonical config paths. That should remain the source of truth for reading initial values.
- `.testbed/scripts/modio_live_harness_lib.gd` contains reusable response-summary patterns for mods, subscriptions, wallet, purchased history, and auth/user reads. It is a good source for view-model shaping or extraction into a smaller UI-oriented helper.
- Existing scenes (`public_catalog`, `authenticated_user`, `safe_write`, `paid_mods`) are structurally simple and should stay as smoke-test entrypoints rather than be expanded into the new browser UX.

**Concrete gaps / seams the coder will need to build**
- No `.testbed` script currently persists auth or environment edits back into `.testbed/configs/modio.session.local.cfg`; `ModioEnvLoader` only reads config. A small save helper is required for token persistence, selected environment, and possibly cached `user_id` / disclosure metadata.
- No scene currently performs asynchronous request orchestration, error-state handling, busy/idle state, or stale-request cancellation. The browser needs a real controller/service seam for that.
- No current scene owns shared state for server target, credentials, auth session, active tab, selected workout, current browse query, or page cursors/offsets.
- No helper currently converts normalized mod payloads into UI-ready card/detail models (thumbnail URL choice, CTA eligibility, public vs athlete-only badges, pagination labels, empty states).
- No helper exists for the two-step email auth UX (`emailrequest` then `emailexchange`) or for surfacing terms/auth failures in the scene.
- No helper exists for optimistic subscribe/unsubscribe state updates. The subscribed view requirement ("remove immediately after unsubscribe") will need a local list mutation seam separate from the raw transport call.
- No existing validation script knows about a new default scene or richer node tree; `validate_modio_testbed_scenes.gd` only checks the four old smoke scenes.
- README / `.testbed` docs still say there is intentionally no index scene and that `authenticated_user_testbed.tscn` is the default main scene. Those docs must be updated alongside the scene change.

**Recommended exact scene/script split**
- New default scene: `.testbed/scenes/workout_browser.tscn` as the operator-facing proving surface.
- New main controller: `.testbed/scripts/modio_workout_browser_testbed.gd` owning tab/view switching, button wiring, async task lifecycle, and top-level state.
- New focused support helper: `.testbed/scripts/modio_workout_browser_state.gd` (or similarly named RefCounted/resource) to hold selected env, editable connection fields, auth/session info, browse query params, pagination offsets, selected mod, and cached athlete/public datasets.
- New config persistence helper: `.testbed/scripts/modio_session_config_store.gd` to read/write `.testbed/configs/modio.session.local.cfg` and expose the exact storage path for the UI disclosure copy.
- Optional but likely worth it: a tiny `.testbed/scripts/modio_workout_browser_presenter.gd` or extraction from `modio_live_harness_lib.gd` for card/detail/profile summaries so the main controller does not become a formatting dump.
- Keep `public_catalog_testbed.tscn`, `authenticated_user_testbed.tscn`, `safe_write_testbed.tscn`, and `paid_mods_testbed.tscn` unchanged except for any navigation/default-scene references and smoke-test validation updates.

**Scope-fit conclusions for implementation**
- Public browsing without athlete login is already supported by the current seam as soon as `game_id + api_key` are present; the new scene can truthfully enable browse controls before auth.
- Athlete-only areas should gate on `manager.has_access_token()` / successful `/me` fetch and then expose profile, subscribed workouts, wallet, and purchased history.
- The approved profile scope is feasible without payment-method CRUD: wallet normalization already exposes `payment_method_id`, but there is no scene/helper for editing payment methods and the plan should continue to forbid inventing that UX.
- The browser/detail UI can stay vendor-honest by showing provider data and CTA state only; purchase/checkout/payment CRUD should remain out of scope for this slice.

---

### Task 2: Implement the Workout Browser scene, auth controls, server selector, and default-scene wiring

**Bead ID:** `oc-pfv1`
**SubAgent:** `primary` (for `coder`)
**Role:** `coder`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved Workout Browser `.testbed` scene and supporting scripts. Add the agreed auth UI, test/live target controls, profile view, workout-browser view, and subscribed-workouts view using the existing provider seam where possible. Keep the implementation truthful to mod.io auth and repo boundaries, update `.testbed/project.godot` so the new scene is the default when approved, preserve existing dedicated scenes unless the plan explicitly decides otherwise, add tests/validation, update README docs, commit/push by default, then close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/project.godot`
- `.testbed/scenes/workout_browser.tscn`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/scripts/modio_workout_browser_state.gd`
- `.testbed/scripts/modio_session_config_store.gd`
- `.testbed/tests/validate_modio_testbed_scenes.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/tests/test_modio_session_config_store.gd`
- `README.md`
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-testbed.md`

**Status:** ✅ Complete

**Results:** Implemented the new default `.testbed/scenes/workout_browser.tscn` entrypoint and switched `.testbed/project.godot` to launch it by default. The new controller builds an operator-facing UI with editable `Test|Live` server selection, editable Game ID + API Key fields prefilled from local config, public catalog browsing without athlete auth, the approved two-step email-code auth flow (`emailrequest` → `emailexchange`), profile/wallet/purchase summary, athlete-only workout browsing, and subscribed-workout management with immediate local removal after successful unsubscribe. Supporting helpers now persist `access_token` + `user_id` back into `.testbed/configs/modio.session.local.cfg`, hold shared browser/query state, and disclose the stable/session config paths directly in the UI. Validation/docs were updated so the Workout Browser scene is treated as the new default proving surface while the four older scenes remain focused smoke-test entrypoints. Repo-local validation passed for import, scene validation, scene-output QA, and the full GUT suite (`102/102` passing). Validated against `REF-01` through `REF-08`.
---

### Task 3: QA the Workout Browser scene in the `.testbed` project

**Bead ID:** `oc-skna`
**SubAgent:** `primary` (for `qa`)
**Role:** `qa`
**References:** `REF-02`, `REF-03`, `REF-05`, `REF-06`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Verify the Workout Browser scene in the real `.testbed` Godot project. Confirm the default scene opens correctly, auth/server controls behave as designed, profile/workout/subscription views switch and populate truthfully, and all documented skip/failure states are clear. Run the repo's relevant validation/tests, record exact behavior and any gaps, update the plan, commit/push any minimum QA fixes if needed, then close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-testbed.md`

**Status:** ✅ Complete

**Results:** QA exercised the real `.testbed` project plus repo-local validation. Confirmed `.testbed/project.godot` now defaults to `res://scenes/workout_browser.tscn`; the runtime scene exposes editable `Test|Live`, Game ID, and API Key controls; the auth panel truthfully describes the real `emailrequest → emailexchange` flow; athlete-only Profile / Workout Browser / Subscribed tabs hard-disable when no access token is present and show clear unauthenticated copy (`Athlete-only tabs require an access token from the email-code auth flow.` / `Authenticate to inspect the athlete profile, wallet, and purchase history.`); the UI discloses stable vs session config storage paths; public browsing loaded successfully from local test-server config without athlete auth; authenticated runtime checks loaded profile + wallet + purchase history, including `payment_method_id`; workout browse loaded and exposed Subscribe CTA; subscribed-workout fetches returned a clear empty state for the current local account. QA found one real runtime defect: opening the detail popup for entries whose normalized `metadata_kvp` was an Array caused a GDScript type error because `_detail_bbcode()` incorrectly typed that field as `Dictionary`. Fixed by teaching the detail renderer to accept both dictionary- and array-shaped metadata entries and by expanding `qa_verify_scene_output_updates.gd` to open detail popups for public / workout / subscribed contexts using fixture-backed data so this regression is now covered. Post-fix validation passed: `godot --headless --path .testbed --import`, `res://tests/validate_scaffold.gd`, `res://tests/validate_modio_testbed_scenes.gd`, `res://tests/qa_verify_scene_output_updates.gd`, and the full GUT suite (`102/102` passing). Coder baseline remained `aee74a2`; QA fix commit added after this pass.

---

### Task 4: Audit the final scene, docs, and boundary honesty

**Bead ID:** `oc-hmu7`
**SubAgent:** `primary` (for `auditor`)
**Role:** `auditor`
**References:** `REF-01`, `REF-02`, `REF-05`, `REF-06`, `REF-07`, `REF-08`
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently truth-check the Workout Browser implementation against this plan. Verify that auth behavior matches the real supported mod.io flow, the scene defaulting change is documented, browse/subscribed/profile surfaces map to the actual wrapped endpoints, and the testbed did not silently widen vendor-repo scope beyond what was approved. Update the plan with the final audit verdict, commit/push any minimum audit fixes, then close the bead when done.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `README.md`
- `.plans/2026-05-31-aerobeat-vendor-modio-workout-browser-testbed.md`

**Status:** ✅ Complete

**Results:** Independent audit passed with no further code defects found. Truth-check confirmed the scene and docs stay honest about the real mod.io email-code auth flow (`POST /oauth/emailrequest` → `POST /oauth/emailexchange`) and do not imply username/password login. The new default-scene switch is real in `.testbed/project.godot`, is validated by `.testbed/tests/validate_modio_testbed_scenes.gd`, and is documented in `README.md`. Public browse remains gated only by editable `game_id + api_key` and routes through `build_listing_request` (`GET /games/{game-id}/mods`), while athlete-only Profile / Workout Browser / Subscribed tabs stay disabled without an access token and route through the already wrapped authenticated seams: `/me`, `/me/subscribed`, `/me/wallets`, `/me/purchased`, plus subscribe/unsubscribe writes. The profile surface shows wallet and purchased-history readouts, including `payment_method_id`, but does not invent payment-method CRUD or broader checkout UX, which remains explicitly documented as wider adapter capability rather than this scene's scope. QA's `metadata_kvp` popup fix is present in `.testbed/scripts/modio_workout_browser_testbed.gd` and covered by the expanded `.testbed/tests/qa_verify_scene_output_updates.gd` detail-open checks. Audit reran import, scaffold validation, scene validation, scene-output QA, and the full GUT suite (`102/102` passing). Final audit record committed after plan update.

---

## Open Questions / Gaps To Resolve Before Execution

### Locked by Derrick

1. **Scene-boundary change:** approved. Workout Browser becomes the meaningful default proving surface, while the older focused scenes stay in the repo as smoke-test entrypoints.
2. **Workout browser scope:** approved as full browse UX for this testbed slice: search + sort, tags/filters, pagination, image + workout name cards, selection detail popup, close `X`, and bottom CTA.
3. **Subscribed workouts semantics:** approved as interactive. Reuse the same pagination pattern as the main browser, and when unsubscribe succeeds, remove the workout from the subscribed-workouts list immediately.
4. **Server/game targeting:** approved. Expose the three public-connection controls directly in the scene UI: Server (`Test | Live`, default `Test`), Game ID, and API Key. Prefill them to AeroBeat test-server defaults, but keep them editable so they can be changed as needed.
5. **Real mod.io auth:** approved. Do not fake local username/password auth.

### Remaining execution-sensitive decisions

1. **Paid-workout visibility in this scene:** Derrick wants the scene to expose the available paid-workout REST-facing readouts even before full provider-side paid enablement is working end-to-end for AeroBeat. The Profile area should therefore gain wallet info (`GET /me/wallets`) and purchased-workout history (`GET /me/purchased`) views, using the existing wrapped read seams and clearly labeling any provider-blocked write/purchase steps.
2. **Payment-method display posture:** follow-up audit against the local official mod.io REST corpus plus official monetization docs did not find any official athlete-facing REST route for adding/updating/removing saved payment methods. The best current model assumption is that mod.io/provider-side saved payment state may exist behind the scenes and be referenced through `payment_method_id`, but public REST only exposes that identifier/state indirectly rather than full card details or profile-side CRUD. The scene should therefore display the saved `payment_method_id` when present, but should not promise or implement payment-method CRUD or detailed card-data exposure.
3. **UI copy around auth + persistence:** implementation should use the unified email-code auth flow and write the resulting token into the existing session-local config workflow so it can be reused by later scene/harness runs. The user-visible UI should also make it clear where the token is stored/retrieved.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The repo now ships a default `.testbed` Workout Browser scene that truthfully exercises mod.io public browse plus athlete-only profile/subscription reads through the existing vendor seam, with editable `Test|Live` + `game_id` + `api_key` controls, real email-code auth, session persistence, and subscribed-workout management.

**Reference Check:** `REF-01` through `REF-08` were satisfied. Audit confirmed: (1) auth copy and behavior match the real email-code flow rather than inventing username/password auth; (2) the default-scene change is live in `project.godot`, validated by test, and documented in `README.md`; (3) public vs athlete-only gates match the wrapped endpoint/auth/config requirements; and (4) wallet / purchased / `payment_method_id` exposure stays inside the approved read-only scope without silently adding payment-method CRUD or broader checkout flows.

**Commits:**
- `aee74a2` - Add default mod.io workout browser testbed
- `e0caa59` - Fix workout browser detail metadata rendering
- `(current HEAD at audit close)` - Record workout browser audit verdict

**Lessons Learned:** The seam already had the needed provider coverage; the hard part was keeping the new proving surface honest about what is public, what requires athlete auth, and what remains wider adapter capability instead of approved product UX.

---

*Completed on 2026-05-31*