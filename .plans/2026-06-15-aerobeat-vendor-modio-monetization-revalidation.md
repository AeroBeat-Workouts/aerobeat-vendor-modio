# AeroBeat Vendor Mod.io Monetization Revalidation

**Date:** 2026-06-15  
**Status:** In Progress  
**Last Updated:** 2026-06-15 12:33 EDT  
**Blocked Reason:** None  
**Agent:** `Cookie`

---

## Goal

Re-validate the mod.io monetization API surface in `aerobeat-vendor-modio` using Derrick’s newly approved test-server access, prove which monetization routes now work with our current credentials/config, and update the `/.testbed/` Godot project so the exercised monetization lanes are truthful and easy to rerun.

---

## Overview

We already did one monetization validation wave in this repo on 2026-05-17. That earlier work established that the adapter broadly wraps the relevant monetization REST surface and that the main gaps were in harness/config truth, not missing adapter routes. It also showed two concrete bearer monetization reads working (`GET /games/{game-id}/monetization/token-packs` and `GET /me/purchased`) while other lanes were blocked by setup state such as missing `owned_mod_id`, `paid_mod_id`, `service_token`, `monetization_team_id`, or write payload inputs.

Today’s plan assumes Danny’s mod.io approval changes the practical test posture: we should not start by adding speculative wrapper breadth. We should start by re-auditing the currently shipped monetization routes, then exercise them in a simple staircase from lowest-risk read lanes to guarded write lanes, and only then change the `/.testbed/` surfaces where reality has moved. The key question is not just “do the endpoints exist in code?” but “which exact monetization lanes are now operational with our approved test-server access, and does the repo/testbed tell the truth about that?”

The `/.testbed/` update should also get more deliberate. Right now the paid-mods scene is a lightweight launcher that delegates to the scene runner/harness. For this slice, we should decide whether that remains sufficient or whether it now needs a more explicit monetization-oriented UX/reporting layer: endpoint grouping, prerequisite warnings, buttons/toggles for guarded flows, and clearer output that separates bearer reads, owned-mod reads, guarded buyer writes, and S2S/history checks.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Previous monetization validation source of truth | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/archive/2026-05-17-aerobeat-vendor-modio-paid-mods-test-server-validation.md` |
| `REF-02` | Current repo contract and monetization README coverage | `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |
| `REF-03` | Current adapter monetization route implementation | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/modio_vendor_adapter.gd` |
| `REF-04` | Current paid-mod harness runtime | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_live_harness.gd` |
| `REF-05` | Current harness option parsing + summaries | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_live_harness_lib.gd` |
| `REF-06` | Current testbed scene runner grouping | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_scene_runner.gd` |
| `REF-07` | Current paid-mods testbed scene | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scenes/paid_mods_testbed.tscn` |
| `REF-08` | Current paid-mods testbed controller | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/modio_paid_mods_testbed.gd` |
| `REF-09` | Current local monetization matrix doc | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/docs/modio-paid-mods-test-server-matrix.md` |
| `REF-10` | Prior memory summary of what was proven and what remained missing | `memory/2026-05-17.md` |

---

## Endpoint Exercise Matrix

### Phase A — Bearer monetization reads

These remain the correct first live checks. In the shipped harness and adapter, all three are explicitly bearer-authenticated and do **not** depend on any extra monetization-specific license key beyond normal runtime auth.

1. `GET /games/{game-id}/monetization/token-packs`
2. `GET /me/wallets`
3. `GET /me/purchased`

**Repo-local truth:**
- `build_game_token_packs_request(...)` is hard-wired to `auth_mode: "bearer"` (`REF-03`).
- `build_user_wallet_request(...)` and `build_user_purchased_request(...)` also resolve to bearer mode (`REF-03`).
- So Danny’s statement is consistent with this phase **if** we read it as “no extra licensing/config beyond the normal approved test-user auth/runtime facts.”

**Simple exercise:** obtain or reuse the approved bearer access token for DerrickBarra on the test user host (`https://u-71104.test.mod.io/v1`), then run the paid-mods harness and capture whether each endpoint returns real data, empty-but-valid data, or a provider/business-rule failure.

### Phase B — Owned paid-mod creator read

4. `GET /games/{game-id}/mods/{owned_mod_id}/monetization/team`

**Repo-local truth:** this route is also bearer-authenticated in the adapter (`REF-03`). The extra thing it needs is not another license key; it needs a concrete paid mod id that the authenticated user can actually administer.

**Important distinction:** `owned_mod_id` / `paid_mod_id` are currently treated in repo config as long-lived config inputs, but semantically they are just route-path business inputs. Danny’s statement weakens the idea that they are “special setup,” but it does **not** remove the need to supply a real mod id per request/run.

**Simple exercise:** after Phase A succeeds, identify the owned paid mod for DerrickBarra and run this route with that concrete mod id. If the harness still requires a prefilled `owned_mod_id`, that is a repo ergonomics assumption, not proof of a provider-side requirement.

### Phase C — Guarded buyer-side monetization writes

5. `POST /me/entitlements`
6. `POST /games/{game-id}/mods/{paid_mod_id}/checkout`

**Repo-local truth:** both routes are already wrapped and remain intentionally guarded in the harness. They do **not** inherently require extra licensing/config keys beyond approved bearer auth, but they still inherently require per-request business payloads.

**Still-required per-request inputs:**
- entitlements: portal-specific payload fields, and for some portals platform/token fields (`REF-03`)
- checkout: concrete paid mod id, checkout type/body, and portal/platform-specific fields (`REF-03`)

**Simple exercise:** keep these behind explicit opt-in. Use the smallest truthful payloads available for today’s portal. Treat missing payload JSON as a harness/runtime input gap, not as evidence that mod.io requires extra licensing.

### Phase D — Server-side / monetization history reads

7. `GET /s2s/monetization-teams/{monetization-team-id}/transactions`
8. `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`

**Repo-local truth:** the shipped adapter keeps these on a distinct service-token auth model, not the bearer-user auth model. `service_token` and `monetization_team_id` are explicit validation requirements in the current code (`REF-03`).

**Interpretation:** Danny’s statement is potentially consistent for the bearer/buyer lanes above, but it is **not yet consistent with the repo’s current S2S/history assumption**. Until live evidence proves otherwise, this phase should be treated as a separate hypothesis check, not bundled with the normal approved user-host auth lane.

**Simple exercise:** only attempt this after the bearer phases. First verify whether mod.io expects these history reads to work from today’s approved user/test-server setup alone. If not, keep the repo’s current service-token lane assumption in place and record that Danny’s statement did not generalize to S2S history reads.

### Explicitly deferred unless today’s execution proves we need them

9. `POST /games/{game-id}/mods/{mod-id}/monetization/team`
10. `POST /s2s/transactions/intent`
11. `POST /s2s/transactions/commit`
12. `POST /s2s/transactions/clawback`
13. `DELETE /s2s/connections/{portal-id}`

These stay out of the default first pass because they are either heavier writes, sensitive server-side flows, or destructive/provider-ops style routes. If the staircase shows we need one of them next, we should add it with a fresh narrow task rather than quietly widening scope.

---

## Planned `/.testbed/` Godot Changes

The likely `/.testbed/` change set for this slice is:

- keep the paid-mods scene as the dedicated monetization entrypoint, but make it more explicit about the route groups it runs
- improve scene/runtime output so it clearly reports:
  - bearer read checks
  - owned-mod read checks
  - guarded buyer-write checks
  - S2S/history checks
  - precise missing-prerequisite reasons
- update the scene runner and/or paid-mods controller if the current single `Run Checks` UX is too opaque for monetization-specific reruns
- update harness help/docs so the `--paid-mods` path and any new monetization route grouping are consistent between CLI output, scene output, and README/docs
- only add new config keys if today’s validation proves they are genuinely required for truthful reruns

The preferred bias is still thin wrappers and truthful testbed ergonomics, not a giant bespoke monetization dashboard.

---

## Tasks

### Task 1: Re-audit the monetization surface against today’s approval

**Bead ID:** `aerobeat-vendor-modio-vl6`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-09`, `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Re-audit the currently shipped monetization surface in light of Derrick’s note that Danny from mod.io approved test-server monetization access and said no additional API license keys or configuration should be required for these REST endpoints. Confirm the exact monetization routes we should exercise today, grouped into bearer reads, owned-mod reads, guarded buyer writes, and S2S/history reads. Call out where the repo currently assumes more config than Danny’s statement implies, and recommend the exact exercise order for today. Update the plan with what you found, then close the bead with `bd close <bead-id> --reason "Monetization re-audit completed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md` (if truth updates are needed)

**Status:** ✅ Complete

**Results:** Re-audit completed against the current adapter, harness, scene runner, README, and the prior 2026-05-17 matrix. The exact exercise set for today stays narrow and correct: bearer reads (`GET /games/{game-id}/monetization/token-packs`, `GET /me/wallets`, `GET /me/purchased`), owned-mod read (`GET /games/{game-id}/mods/{owned_mod_id}/monetization/team`), guarded buyer writes (`POST /me/entitlements`, `POST /games/{game-id}/mods/{paid_mod_id}/checkout`), and S2S/history reads (`GET /s2s/monetization-teams/{monetization-team-id}/transactions`, `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`).

Danny’s statement appears **partially consistent** with the repo’s current assumptions. For the bearer monetization read lane, the repo should not assume any extra licensing/API-key provisioning beyond the supplied user/test-server auth facts. But several current inputs are still inherently required because they are request-shape or resource-identity facts rather than extra licensing: `owned_mod_id` / `paid_mod_id` for mod-specific routes, checkout/entitlements payload JSON for guarded buyer writes, and `transaction_id` for the S2S detail read. The one likely over-assumption that remains worth actively testing is the S2S lane: the adapter/harness currently model S2S history strictly behind `service_token`, which may or may not still be necessary under Danny’s wording and should be proven instead of assumed.

Recommended execution order for today:
1. Bearer monetization reads first using the supplied test-server/API path facts.
2. Owned paid-mod read second, once we confirm or supply a concrete paid/owned mod id.
3. Guarded entitlements/checkout only when explicit payload inputs exist.
4. S2S/history reads last, specifically as a truth test of whether `service_token` is still genuinely required or whether the repo is carrying stale assumptions.

No wrapper-breadth expansion was justified by the re-audit. The next real work is the `/.testbed/` monetization UX/reporting update so these route groups and prerequisite boundaries are clearer before QA executes the staircase.

---

### Task 2: Update the `/.testbed/` monetization routes and reporting surface

**Bead ID:** `aerobeat-vendor-modio-536`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Update the `/.testbed/` Godot project so the monetization entrypoint matches today’s approved exercise matrix. Keep the UX/testbed thin but clearer: make the paid-mods route grouping visible, improve prerequisite/skip reporting, and wire any minimal scene-runner/harness/controller updates needed so Derrick can rerun monetization checks intentionally instead of guessing what `Run Checks` covers. Do not add speculative breadth; only change the scene, scripts, config loaders, and docs required to reflect the actual monetization routes we are testing. Run relevant repo-local validation, commit/push by default, update the plan with exact changes, and close the bead with `bd close <bead-id> --reason "Testbed monetization route update completed" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/paid_mods_testbed.tscn`
- `.testbed/scripts/modio_paid_mods_testbed.gd`
- `.testbed/scripts/modio_scene_runner.gd`
- `.testbed/scripts/modio_live_harness.gd`
- `.testbed/scripts/modio_live_harness_lib.gd`
- `.testbed/tests/test_modio_live_harness.gd`
- `.testbed/tests/qa_verify_scene_output_updates.gd`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`
- `README.md`
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`

**Status:** ✅ Complete

**Results:** Updated the paid-mods entrypoint to show the approved four-group monetization matrix explicitly instead of a vague paid-mods bucket: bearer reads, owned-mod read, guarded buyer writes, and S2S/history reads. The paid-mods scene now explains that scope up front, `Run Checks` prints grouped route coverage with prerequisite gaps and the S2S/service-token open question, and the shared scene runner stays thin by reading the local cfg files directly instead of growing a dashboard. On the CLI side, `modio_live_harness.gd` now emits the same grouped monetization overview in human output and uses more truthful skip reasons for owned-mod reads, buyer-write opt-in, and S2S/history prerequisites.

Also updated the harness help text, README, and the paid-mods matrix doc so the documented behavior matches the current entrypoint surface. Added/updated truth-surface tests for the new monetization overview and paid-mods scene output expectations. Validation: a custom headless paid-mods scene smoke run (`godot --headless --path .testbed --script /tmp/validate_paid_mods_scene.gd`) passed and confirmed the new grouped report text end-to-end. Broader existing repo checks are still blocked in this checkout by pre-existing testbed infrastructure issues outside this slice (missing `addons/gut/*` resources for GUT and longstanding global-class parse failures in unrelated broader testbed scripts like `modio_workout_browser_testbed.gd` / `modio_env_loader.gd`).

---

### Task 3: Run the monetization endpoint staircase on the approved test server

**Bead ID:** `aerobeat-vendor-modio-1iu`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-04`, `REF-05`, `REF-07`, `REF-08`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Execute the monetization endpoint staircase against the approved mod.io test server and record exact results. Run the phases in order: (A) bearer monetization reads, (B) owned-mod monetization-team read, (C) guarded entitlements/checkout only when the required payload inputs exist, and (D) S2S/history reads. Treat Danny’s statement as a testable hypothesis: verify whether current credentials/config are enough without any new monetization-specific licensing/provisioning, and separate true provider/business-rule failures from local config gaps and repo bugs. Capture endpoint-by-endpoint evidence, update the plan and matrix doc, commit/push only if repo changes were required, then close the bead with `bd close <bead-id> --reason "Monetization endpoint staircase executed" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/docs/`
- `.plans/`
- `.testbed/configs/` (local ignored cfg only)

**Files Created/Deleted/Modified:**
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/configs/modio.local.cfg` (local ignored)
- `.testbed/configs/modio.session.local.cfg` (local ignored)

**Status:** ✅ Complete

**Results:** Executed the monetization staircase as far as today’s truthful inputs allowed and updated the matrix doc with exact endpoint evidence. Created the minimum ignored local cfg needed for QA using Derrick’s supplied facts: `base_url=https://u-71104.test.mod.io/v1`, `user_id=71104`, the provided `api_key`, and the carried-forward prior repo `game_id=12962` only so the existing game-scoped routes could be tested honestly if still valid. Left `access_token`, `service_token`, `monetization_team_id`, `owned_mod_id`, `paid_mod_id`, `entitlements_payload_json`, `checkout_payload_json`, `s2s_filters_json`, and `s2s_transaction_id` blank because no truthful values were supplied.

Two distinct truths came out of the run. First, the approved user-host tuple is real: `GET /ping` on `https://u-71104.test.mod.io/v1` returned `200 Everything is okay!`. Second, the supplied facts are **not sufficient by themselves** to execute the whole paid staircase. Direct provider calls proved that `/me/*` monetization routes still need a real bearer access token beyond `api_key + api_path`: `GET /me`, `GET /me/wallets`, and `GET /me/purchased` all returned `401 / error_ref 11005` (`The supplied access token has either been revoked, has expired or is malformed`). That directly answers the “bearer reads without extra setup” hypothesis for the `/me/*` lane: no new monetization-specific license key was shown to be required, but a normal bearer access token still absolutely is.

For the game-scoped bearer lane, the run exposed a different blocker. The carried-forward prior tuple `game_id=12962` no longer resolved under the supplied approval facts: `GET /games/12962` and `GET /games/12962/monetization/token-packs` returned `404 / error_ref 14000` (`The requested game id could not be found`) on the approved `u-71104.test.mod.io` host, and the same game id also failed on adjacent test host shapes checked during isolation. So token-packs did not fail for lack of a bearer token in this run; they failed because the supplied facts did not expose a working game-scoped target. That same missing game/mod context prevented a truthful owned-mod monetization-team read.

Guarded buyer writes and S2S/history reads were left unexecuted for truthful reasons only: no `access_token`, no write payload JSON, no `paid_mod_id`, no `monetization_team_id`, and no `transaction_id`. The instructions explicitly forbade inventing these values. The separate open question around whether S2S history still needs `service_token` therefore remains unresolved by live evidence from this pass.

A repo/runtime issue also surfaced while attempting to use the official harness path: on current HEAD (`dbec118` during this run), `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` failed because Godot could not parse global class `ModioVendorAdapter` from `res://src/modio_vendor_adapter.gd`. That is a repo bug distinct from provider responses, so the endpoint evidence for this QA pass was gathered directly with `curl` and recorded in `REF-09`. No tracked code changes were made beyond the documentation/plan updates for this task.

---

### Task 4: Independently audit truthfulness of the monetization result

**Bead ID:** `aerobeat-vendor-modio-zoq`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Independently audit the final monetization revalidation result. Verify that the endpoint matrix matches the code, the `/.testbed/` monetization entrypoint tells the truth about what it runs, skip/failure reasons correctly distinguish repo issues from provider/setup/business-rule responses, and any interpretation of Danny’s approval is evidence-backed rather than wishful. Make only minimal truth fixes if needed, update the plan with the audit verdict, commit/push by default, and close the bead with `bd close <bead-id> --reason "Monetization audit completed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`

**Status:** ✅ Complete

**Results:** Independent audit passed with one minimal tracked change: this plan now records the audit verdict exactly. No truth fixes were needed in `README.md` or `.testbed/docs/modio-paid-mods-test-server-matrix.md` because the current matrix, README, and harness code already line up on the materially important points.

Audit conclusions:
- The endpoint grouping in the repo is accurate and matches the current code surface in `REF-03` plus the current scene/harness truth surfaces in `REF-04` and `REF-05`: bearer reads (`GET /games/{game-id}/monetization/token-packs`, `GET /me/wallets`, `GET /me/purchased`), owned-mod read (`GET /games/{game-id}/mods/{mod-id}/monetization/team`), guarded buyer writes (`POST /me/entitlements`, `POST /games/{game-id}/mods/{mod-id}/checkout`), and S2S/history reads (`GET /s2s/monetization-teams/{monetization-team-id}/transactions`, detail by transaction id).
- The QA conclusions are truthful as written in `REF-09`: `/me/*` bearer reads still require a real access token beyond `api_key + api_path`; the game-scoped monetization lane was not proven because the supplied `game_id=12962` target returned `14000 game id could not be found` on the approved host; owned-mod read and guarded writes were skipped for concrete missing prerequisites rather than hand-waved; and S2S/service-token necessity remains unresolved because today’s pass never had truthful team/transaction inputs to falsify or confirm the current harness assumption.
- The repo-bug claim is also truthful and independently reproduced on current HEAD: `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` fails before execution because Godot cannot parse global class `ModioVendorAdapter` from `res://src/modio_vendor_adapter.gd`, which cascades into multiple parse errors in `modio_live_harness.gd`. That is a repo/runtime failure distinct from provider/auth results.

No broader scope changes were justified by the audit.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** A truthful 2026-06-15 monetization revalidation record for the approved test-user host, including exact provider responses for the reachable bearer lane, explicit separation of provider auth failures vs. missing local business inputs, and documentation of the current Godot harness parse blocker on HEAD.

**Reference Check:** `REF-03`, `REF-04`, `REF-05`, `REF-07`, `REF-08`, and `REF-09` were independently cross-checked in the final audit. The matrix doc and README remain truthful to the code and evidence: `/me/*` monetization reads still need a bearer access token, the supplied facts did not expose a valid game-scoped target for token-packs/owned-mod reads, owned-mod read and buyer-write gaps were caused by real missing prerequisites, and S2S history remains unproven because truthful team/transaction inputs were unavailable.

**Commits:**
- `7d97f39` - docs: record monetization staircase revalidation
- `HEAD` - docs: record monetization audit verdict

**Lessons Learned:** The approved `u-71104.test.mod.io` tuple is real, but it is not by itself a complete rerun package for the whole paid staircase. We still need a valid bearer token for `/me/*`, a correct current game/mod context for game-scoped monetization routes, and better repo truth around the current `ModioVendorAdapter` parse failure before the Godot harness can be trusted as the first execution path again.

---

*Drafted on 2026-06-15*
