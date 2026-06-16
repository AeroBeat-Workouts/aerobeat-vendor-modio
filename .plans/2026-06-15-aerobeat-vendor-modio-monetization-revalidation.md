# AeroBeat Vendor Mod.io Monetization Revalidation

**Date:** 2026-06-15  
**Status:** Blocked  
**Last Updated:** 2026-06-16 11:08 EDT  
**Blocked Reason:** Remaining live paid lanes still need truthful buyer payload JSON plus S2S team/transaction inputs; current S2S `service_token` requirement is still only an implementation assumption under test.  
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

### Task 5: Rerun bearer monetization checks with provided OAuth tokens

**Bead ID:** `aerobeat-vendor-modio-te4`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Use the newly supplied OAuth tokens to rerun the bearer monetization checks truthfully. Prefer the corrected auth context and test only what is now genuinely unblocked: `/me`, `/me/wallets`, `/me/purchased`, plus any other monetization-adjacent bearer read that can be exercised without inventing missing game-scoped inputs. If the `g-1325.test.mod.io` API key is still missing, treat the game-scoped rerun as partially blocked rather than guessing. Update the plan with exact results, note which local ignored config files were touched, commit/push only if tracked repo docs/plan change, then close the bead with `bd close <bead-id> --reason "OAuth-token bearer rerun completed" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/configs/`
- `.plans/`
- `.testbed/docs/`

**Files Created/Deleted/Modified:**
- `.testbed/configs/modio.local.cfg`
- `.testbed/configs/modio.session.local.cfg`
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`

**Status:** ✅ Complete

**Results:** Reran the bearer monetization lane directly with the newly supplied OAuth tokens and updated both the active plan and `REF-09` with exact live responses. For the local ignored config, changed only what this rerun actually needed: `.testbed/configs/modio.local.cfg` now uses `game_id=1325` on the approved `https://u-71104.test.mod.io/v1` host with the supplied `u-71104` API key, and `.testbed/configs/modio.session.local.cfg` now carries the supplied `AeroBeat Test Harness - test.mod.io` bearer token for `user_id=71104`.

With that corrected auth context, the previously blocked `/me*` bearer lane is now genuinely working. Direct `curl` verification showed:
- `GET /me` → `200` with DerrickBarra user payload (`id=71104`, `monetization_status=49`)
- `GET /me/purchased` → `200` with a valid empty list (`result_total=0`)
- `GET /me/wallets?game_id=1325` → `200` with a valid wallet payload (`type=standard_mio`, `currency=mio`, `balance=0`, `game_id=1325`)

Two comparison calls also mattered. First, `GET /me/wallets` with **no** `game_id` returned `404 / error_ref 14001`, and `GET /me/wallets?game_id=12962` returned the same `404 / error_ref 14001`, so the old `12962` context is no longer truthful for this bearer lane. Second, the separate supplied OAuth token for `games-1325` produced the **same** successful `200` results as the `AeroBeat Test Harness - test.mod.io` token on `/me`, `/me/purchased`, and `/me/wallets?game_id=1325`; for the tested user-host bearer reads, the client/token choice did not change the outcome.

The game-scoped rerun remains only **partially** unblocked. We now have live evidence that `1325` is the working wallet game context for `/me/wallets`, but we still do **not** have the missing `g-1325.test.mod.io` API key, so it would be guesswork to claim full revalidation of game-host bearer routes like token-packs. No code changes were required; the tracked updates were documentation only (`REF-09` and this plan), and the ignored local cfg files were the only secret-bearing files touched.

---

### Task 6: Rerun game-host monetization checks with `g-1325` API key

**Bead ID:** `aerobeat-vendor-modio-fbs`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Use the supplied AeroBeat `g-1325.test.mod.io` API key plus the already-proven OAuth bearer context to rerun the remaining game-host monetization checks truthfully. Focus on game-scoped monetization reads such as token packs and any other now-unblocked monetization-adjacent read that depends on the correct `g-1325` host/key context. Do not invent missing mod-specific or write payload inputs. Update the plan and matrix doc with exact results, note any ignored local config touched, commit/push only if tracked docs/plan change, then close the bead with `bd close <bead-id> --reason "Game-host monetization rerun completed" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/configs/`
- `.plans/`
- `.testbed/docs/`

**Files Created/Deleted/Modified:**
- `.testbed/configs/modio.local.cfg`
- `.testbed/configs/modio.session.local.cfg`
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`

**Status:** ✅ Complete

**Results:** Reran the remaining game-host monetization checks directly against `https://g-1325.test.mod.io/v1` using the supplied `g-1325` game API key and the already-proven OAuth bearer context, then updated `REF-09` with the exact live responses. For ignored local config, switched only `.testbed/configs/modio.local.cfg` to the truthful game-host tuple for this slice: `game_id=1325`, `api_key=<provided g-1325 key>`, `base_url=https://g-1325.test.mod.io/v1`. `.testbed/configs/modio.session.local.cfg` was not newly populated beyond reusing the existing bearer token for `user_id=71104`.

The core blocker from earlier slices is now closed: `GET /games/1325/monetization/token-packs` returned `200` with a live six-pack payload (`result_total=6`) containing `200 Pack`, `500 Pack`, `1000 Pack`, `2000 Pack`, `5000 Pack`, and `10000 Pack` on `portal="web"` with prices `199/499/999/1999/4999/9999` and amounts `200/500/1000/2000/5000/10000`. Preflight also proved the game host itself cleanly: `GET /ping` returned `200 Everything is okay!`, and `GET /games/1325` returned `200` with live AeroBeat game detail (`name="AeroBeat"`, `name_id="aerobeat"`, `monetization_options=771`) plus monetization-team references in the game payload.

A comparison call mattered here: the same token-pack route also returned the same `200` / `result_total=6` payload **without** the bearer header when called on the corrected `g-1325` host with the supplied game API key. So the truthful separation is now explicit: bearer is still required for the user-host `/me*` monetization lane proven in Task 5, but the game-host token-pack read was actually blocked by the wrong host/key context, not by missing bearer auth. No other monetization-adjacent game-host reads became testable without inventing inputs: owned-mod monetization-team read still lacks a truthful `owned_mod_id` / `paid_mod_id`, guarded buyer writes still lack payload JSON, and S2S/history still lacks truthful team/transaction inputs.

The official harness path remains separately blocked by the same repo/runtime bug already documented earlier in the plan and matrix: `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` still fails on current HEAD because Godot cannot parse global class `ModioVendorAdapter` from `res://src/modio_vendor_adapter.gd`. So this rerun’s endpoint evidence was again gathered directly with `curl`, not via a successful harness execution.

---

### Task 7: Fix `ModioVendorAdapter` harness parse/load break

**Bead ID:** `aerobeat-vendor-modio-8a9`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Diagnose and fix the current repo-side harness failure where `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` fails because Godot cannot parse/load global class `ModioVendorAdapter` from `res://src/modio_vendor_adapter.gd`. Keep the fix narrow and truthful: repair the harness/runtime path or class-loading issue without widening monetization scope. Run the relevant validation to prove the harness path works again, update the plan with exact results, commit/push by default, and close the bead with `bd close <bead-id> --reason "ModioVendorAdapter harness break fixed" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/src` (restored symlink bridge)
- `.testbed/modio_env_loader.gd` (new root bridge symlink)
- `.testbed/modio_live_harness_lib.gd` (new root bridge symlink)
- `.testbed/scripts/modio_live_harness.gd`
- `.testbed/scripts/modio_live_harness_lib.gd`
- `.testbed/scripts/modio_collection_eligibility_harness.gd`
- `.testbed/scripts/modio_final_easy_wins_harness.gd`
- `.testbed/scripts/modio_unlocked_family_harness.gd`
- `.testbed/scripts/modio_workout_browser_testbed.gd`
- `.testbed/tests/test_modio_live_harness.gd`
- `.testbed/tests/test_modio_env_loader.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_aero_modio_manager.gd`
- `.testbed/tests/test_modio_workout_upload_flow.gd`
- `.testbed/tests/validate_scaffold.gd`
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`

**Status:** ✅ Complete

**Results:** Root cause was not a syntax/runtime bug inside `src/modio_vendor_adapter.gd` itself. The `.testbed` project had lost its historical root-path bridge (`.testbed/src`), but Godot’s `.testbed` class cache still resolved `ModioVendorAdapter`, `ModioClientConfig`, `ModioListingQuery`, and `ModioHttpTransport` at `res://src/...`. That made the harness parse fail immediately when the testbed tried to resolve the global classes from missing `res://src/*` paths. After restoring only `.testbed/src`, the next truthful failure exposed the second half of the seam: the testbed scripts were mixing the bridge path family (`res://src/...`) with addon/sibling paths (`res://addons/aerobeat-vendor-modio/src/...`, `res://scripts/modio_env_loader.gd`, `res://scripts/modio_live_harness_lib.gd`), which caused duplicate global-class registration/hide errors (`Class "ModioVendorAdapter" hides a global script class.`, same for `ModioClientConfig`, `ModioListingQuery`, `ModioHttpTransport`, and `ModioEnvLoader`).

The narrow fix was to restore a single canonical testbed path family and leave monetization scope unchanged: restored `.testbed/src` as the repo-root bridge symlink, added root bridge symlinks for `.testbed/modio_env_loader.gd` and `.testbed/modio_live_harness_lib.gd`, and normalized the touched `.testbed/scripts/*` + `.testbed/tests/*` loaders to use `res://src/...`, `res://modio_env_loader.gd`, and `res://modio_live_harness_lib.gd` consistently instead of addon-path preloads.

Validation after the fix:
- `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` ✅ now parses/loads and exits `0` on current local config. Exact live summary included successful public/auth checks (`ping`, `game`, `mods`, `mod_detail`, `mod_files`, `mod_file_detail`, `mod_stats`, `mod_dependants`, `mod_tags`, `mod_metadata_kvp`, `mod_team`, `mod_dependencies`, `terms`, `me`, `me_games`, `me_mods`, `me_files`, `me_subscribed`, `me_ratings`, `me_collections`, `me_following_collections`, `me_followers`, `me_muted_users`, `user_followers`, `user_following`, `user_collections`) plus the paid-mods overview on `base_url=https://g-1325.test.mod.io/v1`.
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅ still passes after the path normalization.

This fixes the real repo-side harness break described in `REF-09` without widening any paid-mod behavior claims. Any remaining broader testbed/runtime issues now need to be evaluated separately from this resolved bridge/path-class-loading bug.

---

### Task 8: Rerun monetization matrix through restored Godot harness

**Bead ID:** `aerobeat-vendor-modio-vni`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Using the now-restored Godot harness path and the existing local ignored config, rerun the monetization matrix through `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` and any closely related truthful harness commands needed to verify the restored in-repo path. Record which previously proven monetization results now reproduce through the harness itself, what still remains blocked by missing real inputs, and whether the harness output matches the documented matrix. Update the plan and matrix doc with exact results, commit/push only if tracked docs/plan change, and close the bead with `bd close <bead-id> --reason "Godot harness monetization rerun completed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`

**Status:** ✅ Complete

**Results:** Reran the restored in-repo harness exactly as requested with the existing ignored local config: `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json`. The command now completed successfully and exited `0`, which proves the restored Godot harness path itself is working again on current HEAD.

The harness reproduced the monetization read results that already had truthful local inputs:
- `paid_token_packs` → `200`, `result_total=6`, `selected_token_pack_id=1` on `base_url=https://g-1325.test.mod.io/v1`
- `paid_wallet` → `200` with `type=standard_mio`, `currency=mio`, `balance=0`, `pending_balance=0`, `deficit=0`, `monetization_status=49`, `game_id="1325.0"`
- `paid_purchased` → `200` with a valid empty result set (`result_total=0`)

The harness also truthfully kept the still-blocked lanes separate from those proven reads:
- `paid_monetization_team` skipped because `owned_mod_id` / `paid_mod_id` is still missing in stable config
- `paid_entitlements` and `paid_checkout` skipped because buyer writes remain behind `--allow-paid-writes` and still lack truthful payload JSON / paid mod id
- `paid_s2s_transactions` and `paid_s2s_transaction` skipped because `service_token` and `monetization_team_id` are still missing, and the harness still models this lane behind `service_token`

The matrix doc was updated with the exact harness rerun evidence. The main comparison result is: the harness output now matches the documented matrix on which routes pass, which ones skip, and why; the only meaningful implementation nuance is that the harness still groups token-packs inside an access-token-gated paid-mods read lane even though the earlier direct game-host comparison already proved token-packs also succeed on `g-1325` without bearer once the host/key tuple is correct. No local-only config values were changed for this task.

---

### Task 9: Plan deeper monetization lanes after harness rerun

**Bead ID:** `aerobeat-vendor-modio-coi`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. After the harness rerun results are available, convert the remaining unproven deeper monetization lanes into a narrow next-step execution plan. Focus only on the real remaining scope: owned-mod monetization-team read, guarded buyer writes, and S2S/history reads. Identify the exact missing prerequisites for each lane and recommend the safest execution order. Update the active plan with the deeper-lane proposal, then close the bead with `bd close <bead-id> --reason "Deeper monetization lane plan completed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`

**Status:** ✅ Complete

**Results:** Converted the remaining deeper lanes into a narrow next-slice plan grounded only in what the direct endpoint proofs and restored harness now actually establish.

Exact remaining prerequisites, kept separate by type:
- **Owned-mod monetization-team read (`GET /games/{game-id}/mods/{owned_mod_id}/monetization/team`)**
  - **Request-shape / resource prerequisites:** one truthful paid mod id that is both on `game_id=1325` and administered by the authenticated DerrickBarra test user (`owned_mod_id` or `paid_mod_id`); keep this as a concrete route-path input, not a vague “monetization setup” bucket.
  - **Auth / license assumptions:** no new monetization-specific key was proven necessary beyond the already working bearer lane; use the same real access-token context already proven for `/me*` plus the truthful `g-1325` game context already proven for game-host reads.
- **Guarded buyer writes (`POST /me/entitlements`, `POST /games/{game-id}/mods/{paid_mod_id}/checkout`)**
  - **Request-shape / payload prerequisites:**
    - entitlements: a truthful `entitlements_payload_json` for the intended portal/platform, including any portal-specific token fields the adapter validates
    - checkout: a truthful `checkout_payload_json` with at least checkout `type`, `idempotent_key`, and the concrete paid mod id (`paid_mod_id` or `checkout_payload_json.mod_id`), plus any portal-specific fields the selected checkout type requires
    - explicit operator opt-in via `--allow-paid-writes`
  - **Auth / license assumptions:** the already proven bearer access-token lane is still the correct auth starting point; nothing in today’s evidence proves any extra monetization license key beyond that.
- **S2S/history reads (`GET /s2s/monetization-teams/{monetization-team-id}/transactions` and detail by transaction id)**
  - **Request-shape / resource prerequisites:** truthful `monetization_team_id`; for the detail route, a truthful `transaction_id` either supplied directly or harvested from the list response.
  - **Auth / license assumptions:** the adapter/harness still require `service_token`, but that remains an implementation assumption rather than a provider fact proven by today’s reruns. This lane therefore needs a deliberate auth-truth check, not a blind continuation.

Recommended safest execution order for the next slice:
1. **Owned-mod monetization-team read first** — read-only and blocked by only one new factual input (the real owned paid-mod id).
2. **S2S/history list read second** — still read-only, but explicitly treat `service_token` as an assumption under test rather than an unquestioned requirement.
3. **S2S/history detail read third** — only if the list read succeeds or yields a truthful transaction id.
4. **Entitlements write fourth** — first guarded buyer write because it can validate request shape and portal-specific payload handling without immediately invoking checkout.
5. **Checkout write last** — most operationally sensitive lane; only run after the prior read lanes and entitlements payload path are already behaving truthfully.

Harness/docs adjustments to make before or during that deeper-lane slice:
- **Keep prerequisite categories explicit in the truth surface.** The current plan/harness/doc wording should continue separating route-path/payload facts (`owned_mod_id`, `paid_mod_id`, payload JSON, `transaction_id`) from auth assumptions (`access_token`, possible `service_token`).
- **Add a small write-preflight step before executing buyer writes.** The harness already validates payload shape through adapter builders; the next slice should surface those validation errors clearly before any real POST attempt so missing portal/type fields do not get misread as provider-side monetization failures.
- **Document S2S as an assumption-under-test, not settled truth.** `REF-09` and the harness overview already say this in spirit; keep that wording intact during execution so a missing `service_token` is not conflated with proof that mod.io requires one.
- **Optionally note the token-pack auth nuance when touching paid-mod docs again.** It is outside the deeper-lane execution scope itself, but the current harness grouping is stricter than the direct `g-1325` proof because token-packs succeeded there without bearer once the host/key tuple was correct.

No deeper lane was executed in this task; this was planning only.
---

### Task 10: Identify owned paid mod id for monetization-team read

**Bead ID:** `aerobeat-vendor-modio-7fy`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Identify one truthful owned paid mod id on `game_id=1325` that DerrickBarra can administer, so the next deeper monetization lane (`GET /games/{game-id}/mods/{owned_mod_id}/monetization/team`) can be exercised. Use already-proven auth and game-host context where useful, prefer direct evidence over assumptions, and do not start the monetization-team read yet unless needed only to verify the mod id itself. Update the active plan with the exact identifier discovery result and any remaining blocker, then close the bead with `bd close <bead-id> --reason "Owned paid mod id identified" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md` (if needed)

**Status:** ✅ Complete

**Results:** Checked the proven `g-1325` + bearer context directly without widening into writes or the deeper `/monetization/team` read. The exact discovery result was a blocker, not an id: `GET /games/1325/mods?submitted_by=71104&status=1&_limit=100` returned `200` with `result_total=2` (`mod_id`s `16165` and `16112`), and both rows had `monetization_options=0`, `price=0`, and `stock=0`. `GET /games/1325/mods?submitted_by=71104&status=3&_limit=100` returned `200` with `result_total=52`; every returned row also had `monetization_options=0`, `price=0`, and `stock=0`. As a supporting authenticated inventory check, `GET /me/mods?api_key=<g-1325 key>&_limit=100` on `https://u-71104.test.mod.io/v1` returned `200` with `result_total=54`, and zero rows had `price>0`, `monetization_options>0`, or non-empty `skus`. Combined with the already-proven `GET /me/purchased` valid-empty result, today’s truthful discovery is: there is currently **no owned/administered paid mod id** available for DerrickBarra on `game_id=1325`, so the next deeper read remains blocked by missing provider-side paid-mod fixture data rather than by a repo wrapper gap. No monetization-team read was executed in this task.

---

### Task 11: Create paid workout fixture on test server

**Bead ID:** `aerobeat-vendor-modio-l3x`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Create one truthful paid workout fixture on the test server through the REST-backed mod authoring path. Keep the scope narrow: create or reuse the minimum workout mod fixture, attach the required workout content/file as needed, and update it into a paid state using the mod authoring fields the adapter already supports (`price`, `monetization_options`, and related mod fields) rather than inventing a new flow. Capture the resulting mod id and exact request path used, update the active plan with exact results and blockers, commit/push any tracked repo changes by default, and close the bead with `bd close <bead-id> --reason "Paid workout fixture created" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`
- `.testbed/configs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`
- `.testbed/configs/modio.local.cfg`
- `.testbed/configs/modio.session.local.cfg`

**Status:** ✅ Complete

**Results:** Created one truthful paid workout fixture on the approved `g-1325` test server through the REST-backed authoring path. The resulting paid mod id is **`16364`** and the uploaded modfile id is **`23257`**. The exact route sequence that succeeded was:
1. `POST /games/1325/mods` with bearer auth + game API key, multipart draft fields (`name`, `name_id`, `summary`, `description`, `metadata[]`, `metadata_blob`, `community_options`) and a truthful 640x360 PNG logo → `201`, created mod `16364`.
2. `POST /games/1325/mods/16364/files` with bearer auth + game API key, multipart `filedata` ZIP plus `version`/`changelog` → `201`, created modfile `23257`.
3. First paid-state attempt: `POST /games/1325/mods/16364` with multipart `status=1`, `visible=1`, `summary`, `price=500`, `monetization_options=2` → **`404 error_ref 900022` / `Monetization team could not be found.`** Important truth: this still published the mod to public status `1`, but left `price=0` and `monetization_options=0`.
4. Provider-guided unblock: `POST /games/1325/mods/16364/monetization/team` with bearer auth + game API key and one self-owned team member split (`users[0][id]=71104`, `users[0][split]=100`). A first multipart attempt returned **`415 error_ref 13006`** (`Incorrect Content-Type header in request, must be application/x-www-form-urlencoded`). Retrying the same documented indexed `users[...]` fields as `application/x-www-form-urlencoded` succeeded with `200` and returned DerrickBarra as the sole monetization-team member.
5. Second paid-state attempt: `POST /games/1325/mods/16364` with multipart `status=1`, `visible=1`, `summary`, `price=500`, `monetization_options=2` → `200`, and the returned mod detail now showed `price=500`, `monetization_options=2`, and the uploaded modfile attached.
6. Verification read: `GET /games/1325/mods/16364` → `200`, confirming the final paid fixture state.

Tracked repo changes for this task are documentation-only: this plan plus the monetization matrix doc now capture the truthful request path, the intermediate blocker, and the final fixture state. Local-only config was reused/touched in the ignored files `.testbed/configs/modio.local.cfg` and `.testbed/configs/modio.session.local.cfg`; no secrets were added to tracked files.

---

## Continuation Slice — 2026-06-16 Remaining Paid-Lane API Execution

### Task 12: Preflight remaining-lane runtime inputs and launch order

**Bead ID:** `aerobeat-vendor-modio-e50`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Do a narrow preflight for the remaining paid-lane API calls only. Verify the current local ignored config/runtime inputs needed for (1) owned-mod monetization-team read on mod `16364`, (2) S2S/history list/detail, (3) entitlements write, and (4) checkout write. Distinguish between route-path facts, payload JSON, and auth-token assumptions. Do not execute the deeper calls yet unless a call is strictly needed to confirm a prerequisite. Update the active plan with the exact readiness state and recommended execution order for today, then close the bead with `bd close <bead-id> --reason "Remaining-lane preflight completed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md` (if truth updates are needed)

**Status:** ✅ Complete

**Results:** Preflight stayed narrow and used only current repo code plus the ignored local cfg files.

Current ignored local config state verified directly:
- `.testbed/configs/modio.local.cfg`: `game_id=1325`, `api_key=<present>`, `base_url=https://g-1325.test.mod.io/v1`, `service_token=""`, `portal=""`, `platform=""`, `monetization_team_id=""`, `owned_mod_id=""`, `paid_mod_id=""`
- `.testbed/configs/modio.session.local.cfg`: `access_token=<present>`, `user_id=71104`, `s2s_transaction_id=""`, `entitlements_payload_json=""`, `checkout_payload_json=""`, `s2s_filters_json=""`, delegation/idempotent S2S write fields blank

Exact readiness by remaining lane:
- **Owned-mod monetization-team read on mod `16364`**
  - **Route-path facts:** game id `1325` is already present in stable cfg; the truthful paid mod id is known from prior evidence as `16364`.
  - **Current local runtime state:** bearer access token is already present; current stable cfg does **not** yet carry `owned_mod_id` or `paid_mod_id`, so the harness/scene-config path still reports this lane as blocked.
  - **Auth-token assumptions:** current adapter route is bearer-authenticated only (`GET /games/{game-id}/mods/{mod-id}/monetization/team`); no `service_token` assumption is involved here.
  - **Readiness:** **one local route-input tweak away**. This can run either by setting `owned_mod_id=16364` (and optionally `paid_mod_id=16364`) in ignored stable cfg, or by passing `16364` explicitly to the adapter/request builder outside the config-driven harness path.
- **S2S/history list + detail**
  - **Route-path facts:** list needs a truthful `monetization_team_id`; detail additionally needs a truthful `transaction_id` (or a successful list response that yields one). The current ignored cfg provides neither: stable `monetization_team_id` is blank, `s2s_filters_json` is blank, and `s2s_transaction_id` is blank.
  - **Payload JSON facts:** optional list filters would come from `s2s_filters_json`; current session cfg leaves that empty.
  - **Auth-token assumptions:** the current adapter/harness still require `service_token` for both history routes, and current stable cfg leaves `service_token` blank. That remains an implementation assumption/open question, not a provider fact proven by this preflight.
  - **Readiness:** **not ready**. Missing both the selected team path input and the current implementation’s service-token assumption; detail is additionally blocked on transaction discovery/id.
- **Entitlements write**
  - **Route-path facts:** no mod id is needed; the route is `POST /me/entitlements`.
  - **Payload JSON facts:** current session cfg leaves `entitlements_payload_json` blank. The harness/loader expect a JSON object with top-level `portal` / optional `platform` and nested raw request `fields`. Adapter validation then requires `X-Modio-Portal`, plus the documented portal-specific body fields (`psn_token`, `xbox_token`, or `epicgames_token` + `epicgames_sandbox_id` when those portals are chosen). `game_id` is still required unless relying on g-host behavior.
  - **Auth-token assumptions:** bearer access token is already present; no service-token assumption applies.
  - **Readiness:** **blocked only on truthful payload JSON selection**.
- **Checkout write**
  - **Route-path facts:** needs the paid mod id in the request path. Current ignored stable cfg leaves `paid_mod_id` blank, and current session cfg leaves `checkout_payload_json` blank, so there is no current local source for `mod_id`.
  - **Payload JSON facts:** the harness/loader expect top-level `portal` / optional `platform` / optional `mod_id` plus nested raw request `fields`. Adapter validation always requires `idempotent_key` and `type`, then type-specific fields (`display_amount` for type `0`; `payment_method_id` + `terms_accepted` + `refund_accepted` for types `2`/`3`; `transaction_id` for type `4`) plus any portal-specific token fields.
  - **Auth-token assumptions:** bearer access token is already present; no service-token assumption applies.
  - **Readiness:** **blocked on both truthful mod-id wiring and truthful payload JSON**. Setting stable `paid_mod_id=16364` would remove the route-path gap, but the write would still remain blocked until a real checkout payload is supplied.

Recommended execution order for **today’s actual readiness state**:
1. **Owned-mod monetization-team read first** — lowest-risk and closest to runnable; set `owned_mod_id=16364` (and preferably `paid_mod_id=16364`) locally, then execute `GET /games/1325/mods/16364/monetization/team`.
2. **Entitlements write preflight/attempt second** — bearer auth is already present, so the only missing piece is a truthful `entitlements_payload_json`.
3. **Checkout write preflight/attempt third** — after entitlements payload shape is settled, add `paid_mod_id=16364` or `checkout_payload_json.mod_id` plus the checkout payload and run this last among the buyer-write pair.
4. **S2S/history list fourth** — leave it until after the buyer lanes because it is currently the least ready lane: missing selected team input and still carrying the unresolved `service_token` implementation assumption.
5. **S2S/history detail fifth** — only after the list call succeeds or a truthful `transaction_id` is otherwise available.

This slightly changes the practical launch order from the earlier generic “read-only before writes” bias: today, the buyer-write lanes are actually closer to executable than S2S because bearer auth is already present while S2S still lacks both path inputs and the current service-token prerequisite. No matrix-doc truth change was needed from this preflight alone; the tracked update for this task is the plan.

---

### Task 13: Execute owned-mod monetization-team read and S2S/history reads

**Bead ID:** `aerobeat-vendor-modio-nzo`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Using the truthful current fixture and config, execute the next read-only deeper monetization lanes in order: (1) `GET /games/1325/mods/16364/monetization/team`, (2) S2S/history list, and (3) S2S/history detail if and only if the list call yields a truthful transaction id or otherwise unblocks the detail route. Record exact request context and endpoint-by-endpoint results, clearly separating provider/business-rule responses from local prerequisite gaps. Update the active plan and matrix doc, commit/push only if tracked docs/plan changes were required, then close the bead with `bd close <bead-id> --reason "Owned-mod and S2S read lanes executed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`
- `.testbed/configs/` (local ignored cfg only if touched)

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`
- `.testbed/configs/modio.local.cfg` (local ignored, touched to set `owned_mod_id=16364` and `paid_mod_id=16364`)
- `.testbed/configs/modio.session.local.cfg` (local ignored, unchanged)

**Status:** ✅ Complete

**Results:** Executed the next read-only deeper lanes with the truthful current paid fixture and updated the ignored stable config only enough to let the harness/runtime path resolve the owned paid mod: `.testbed/configs/modio.local.cfg` now sets `owned_mod_id=16364` and `paid_mod_id=16364` while leaving `service_token` and `monetization_team_id` blank. The direct owned-mod request used the already-proven `g-1325` game-host tuple plus bearer auth: `GET https://g-1325.test.mod.io/v1/games/1325/mods/16364/monetization/team?api_key=<g-1325 api key>` with `Authorization: Bearer <present access token>`. It returned **`200`** with one monetization-team row: `id=71104`, `name_id="derrickbarra"`, `username="DerrickBarra"`, `monetization_status=49`, `monetization_options=1`, `split=100` (`result_total=1`). No new `monetization_team_id` or transaction id surfaced from that read.

S2S/history list was **not truthfully runnable after the owned-mod read**. Current local runtime state still leaves `service_token=""`, `monetization_team_id=""`, `s2s_filters_json=""`, and `s2s_transaction_id=""`. Under the current adapter/harness implementation (`REF-03` through `REF-05`), that means the list route remains blocked by both a missing path input and the current service-token assumption, and the detail route remains additionally blocked by the absence of any truthful transaction id. I therefore did **not** invent a team id from broader game payloads and did **not** issue either S2S HTTP call directly.

As a harness cross-check after setting the owned/paid mod ids, `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` now also reproduces this same split cleanly on current HEAD: `paid_monetization_team` passes with `200` / one `DerrickBarra` row / `split=100`, while both `paid_s2s_transactions` and `paid_s2s_transaction` stay skipped with the exact reason that no `service_token` and no `monetization_team_id` are configured and that the harness still models this lane behind `service_token` as an open question rather than proven provider fact.

---

### Task 14: Execute guarded buyer-write preflight and attempts

**Bead ID:** `aerobeat-vendor-modio-juh`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. After the read-only deeper lanes are complete, run the guarded buyer-write lane in the safest order: entitlements preflight/attempt first, checkout last. Use only truthful payload JSON and the explicit opt-in write path; do not invent portal/type fields or silently widen scope. Surface adapter validation failures separately from live provider responses. Update the active plan and matrix doc with exact results, commit/push only if tracked docs/plan changes were required, then close the bead with `bd close <bead-id> --reason "Guarded buyer-write lane executed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/docs/`
- `.testbed/configs/` (local ignored cfg only if touched)

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`
- `.testbed/docs/modio-paid-mods-test-server-matrix.md`
- `.testbed/configs/modio.local.cfg` (local ignored, if touched)
- `.testbed/configs/modio.session.local.cfg` (local ignored, if touched)

**Status:** ✅ Complete

**Results:** Executed the guarded buyer-write lane only as far as the current truthful ignored local config allows, using the restored Godot harness path with explicit opt-in: `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --allow-paid-writes --json`.

Exact entitlements preflight/attempt result:
- Harness/runtime input state at execution time: bearer `access_token` present, `owned_mod_id=16364`, `paid_mod_id=16364`, but `entitlements_payload_json=""` in `.testbed/configs/modio.session.local.cfg`.
- Exact harness result: `paid_entitlements` → `status="skipped"`, reason `Skipped because entitlements_payload_json is empty in the session config`.
- Lane classification: **blocked by missing payload JSON**, not by adapter validation and not by a live provider response.
- Live HTTP attempt: **none issued truthfully**. Because the payload JSON was blank, execution stopped before adapter request-building or network submission.

Exact checkout preflight/attempt result:
- Harness/runtime input state at execution time: bearer `access_token` present and paid mod path input available (`paid_mod_id=16364`), but `checkout_payload_json=""` in `.testbed/configs/modio.session.local.cfg`.
- Exact harness result: `paid_checkout` → `status="skipped"`, reason `Skipped because checkout_payload_json is empty in the session config`.
- Lane classification: **blocked by missing payload JSON**, not by adapter validation and not by a live provider response.
- Live HTTP attempt: **none issued truthfully**. Because the payload JSON was blank, execution stopped before adapter request-building or network submission.

Additional exact harness overview evidence from the same `--allow-paid-writes` run:
- `paid_buyer_writes` route group stayed `status="blocked"` with missing prerequisites `entitlements_payload_json in .testbed/configs/modio.session.local.cfg; checkout_payload_json in .testbed/configs/modio.session.local.cfg`.
- The owned-mod read remained proven in the same run: `paid_monetization_team` → `200`, `response_result_total=1`, `usernames=["DerrickBarra"]`, `splits=[100]`.

Newly surfaced transaction/order ids or blockers:
- **No new transaction id, order id, or checkout/entitlement object id surfaced** because neither buyer-write lane reached a live provider request.
- The only truthful blockers for this task were the still-blank `entitlements_payload_json` and `checkout_payload_json` session inputs.

---

### Task 15: Independently audit the remaining paid-lane truth surface

**Bead ID:** `aerobeat-vendor-modio-rya`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-09`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start with `bd update <bead-id> --status in_progress --json`. Independently audit the continuation-slice results for the remaining paid lanes. Verify that the owned-mod read, any S2S/history evidence, and any entitlements/checkout results are documented truthfully; make sure local prerequisite gaps, adapter validation failures, and live provider responses are not conflated. Make only minimal truth fixes if needed, update the active plan with the audit verdict, and close the bead with `bd close <bead-id> --reason "Remaining paid-lane audit completed" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-06-15-aerobeat-vendor-modio-monetization-revalidation.md`

**Status:** ✅ Complete

**Results:** Independent audit passed with plan-only truth updates. `REF-09` and the current harness/adapter code already tell the truth about the continuation-slice outcomes: the owned-mod read is genuinely proven on mod `16364` (`200`, one `DerrickBarra` row, `split=100`); the S2S/history reads were not truthfully runnable because the local ignored runtime still lacked `service_token`, `monetization_team_id`, `s2s_filters_json`, and any `s2s_transaction_id`; and the guarded buyer-write lane was exercised only through the restored `--allow-paid-writes` harness path, where both write routes stopped as config-level skips because `entitlements_payload_json` and `checkout_payload_json` were blank. No adapter validation error and no live buyer-write POST were evidenced for this slice. No matrix-doc text changes were needed because it already separates local prerequisite gaps from provider responses and from the adapter’s still-unproven `service_token` assumption.

---

## Final Results

**Status:** ⚠️ Partial / Blocked

**What We Built:** A truthful 2026-06-15/2026-06-16 monetization revalidation record that now covers all currently runnable paid-mod proof layers for this slice: the user-host bearer lane on `https://u-71104.test.mod.io/v1`, the game-host token-pack lane on `https://g-1325.test.mod.io/v1`, the restored in-repo Godot harness path reproducing those already-proven monetization reads from the real `--paid-mods` flow, the live owned-mod monetization-team read on paid fixture mod **`16364`**, and the guarded buyer-write preflight showing why no live buyer-write POST could truthfully run yet. The fixture remains mod **`16364`** with modfile **`23257`**, and its truthful paid state required creating a mod monetization team before the `price` + `monetization_options` update would stick.

**Reference Check:** `REF-03`, `REF-04`, `REF-05`, `REF-07`, `REF-08`, and `REF-09` were cross-checked across the audit, OAuth rerun, game-host rerun, harness repair, final harness rerun, paid-fixture creation, and the remaining-paid-lane continuation audit. The repo/testbed truth is now: `/me`, `/me/purchased`, and `/me/wallets?game_id=1325` work on the approved user host with a real bearer token; `GET /games/1325/monetization/token-packs` works on the approved game host with the supplied `g-1325` API key and also succeeded in the comparison call without bearer; `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json` reproduces token packs, wallet, purchased, and the owned-mod monetization-team read successfully when the truthful local fixture inputs are present; `GET /games/1325/mods/16364/monetization/team` is proven with one `DerrickBarra` row at `split=100`; the guarded buyer-write lane with `--allow-paid-writes` still stops before adapter validation or live HTTP when `entitlements_payload_json` and `checkout_payload_json` are blank; and S2S/history remains blocked on missing `monetization_team_id` / transaction inputs plus the still-unproven `service_token` implementation assumption.

**Commits:**
- `7d97f39` - docs: record monetization staircase revalidation
- `65a621e` - docs: record OAuth bearer monetization rerun
- `10ab2e6` - docs: record game-host monetization rerun
- `aa0e39e` - fix: restore testbed harness class path bridges
- `a25a8b7` - docs: record paid-mods harness rerun
- `b93ac5c` - docs: record truthful paid workout fixture

**Lessons Learned:** The main hidden bugbears were context drift, path-family drift, and one live request-shape mismatch on the monetization-team create route. For truthful future reruns we should keep the lanes sharply separated: user-host `/me*` monetization reads require a real bearer token; game-host token packs require the correct `g-1325` host/key tuple and are now proven; and paid-mod creation on this server currently needs a creator monetization-team row before `price` + `monetization_options` updates stop failing with `900022`. Separately, the `.testbed` workbench depends on its root bridge paths staying intact and used consistently; mixing `res://src/...` globals with direct addon/sibling script paths is what turned a missing bridge into the misleading `ModioVendorAdapter` parse/load failure.

**Stopping Point:** The continuation slice is now fully audited. The owned paid-mod read is proven on the live fixture (`GET /games/1325/mods/16364/monetization/team` → `200`, one `DerrickBarra` row, `split=100`), the guarded buyer-write lane was exercised only to truthful config-level skips under `--allow-paid-writes`, and S2S/history remains unrun for explicit missing local/runtime prerequisites rather than provider failure.

**Next Slice:** The current slice is complete, but the remaining live paid lanes are blocked on external inputs. Provide truthful `entitlements_payload_json` and `checkout_payload_json` to attempt the buyer-write POSTs; provide a truthful `monetization_team_id` plus either a falsified/confirmed auth path for the current `service_token` assumption or an actual configured `service_token` before retrying S2S/history; and provide a truthful `transaction_id` (directly or via a successful history-list response) before the S2S detail read.

---

*Updated through 2026-06-16 11:08 EDT*
