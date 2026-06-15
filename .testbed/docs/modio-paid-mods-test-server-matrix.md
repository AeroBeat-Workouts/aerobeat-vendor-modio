# mod.io paid-mods test-server QA matrix

> Current testbed truth: the paid-mods scene and `--paid-mods` CLI harness now surface this matrix in four explicit groups — bearer reads, owned-mod read, guarded buyer writes, and S2S/history reads — including prerequisite gaps and the open question around the current `service_token` assumption for S2S/history.

_Date:_ 2026-05-17  
_Repo:_ `aerobeat-vendor-modio`  
_Target:_ `test` environment via `.testbed/scripts/modio_live_harness.gd` on commit `a02ad49` baseline, with one QA harness parse fix applied locally before execution.

## Exact commands run

```bash
git rev-parse --short HEAD

godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json
# failed before execution because res://scripts/modio_live_harness.gd had GDScript parse errors

godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json
# rerun after the minimal parse fix

godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Local config state observed during QA

- `.testbed/configs/modio.local.cfg` exists.
- `.testbed/configs/modio.session.local.cfg` does **not** exist.
- Stable `test` tuple has the public baseline fields populated (`game_id`, `api_key`, default test base URL resolution succeeded).
- Stable paid/S2S fields needed for deeper paid validation were blank in the local cfg used for this run:
  - `service_token`
  - `monetization_team_id`
  - `owned_mod_id`
  - `paid_mod_id`
- No session-local paid payload inputs were available for this run:
  - `entitlements_payload_json`
  - `checkout_payload_json`
  - `s2s_filters_json`
  - `s2s_transaction_id`

## Repo-side QA blocker found and fixed

The first paid-mods harness run failed before any network request because Godot 4.6 rejected three local-variable declarations in `.testbed/scripts/modio_live_harness.gd` that relied on type inference from Variant-typed values:

- `owned_mod_id`
- `transaction_id`
- `mod_id`

Minimum fix applied: add explicit `: String` annotations to those three locals. After the fix:

- the harness parsed and executed successfully
- the full GUT suite passed: `98/98`

## Endpoint matrix

| Order | Endpoint / harness check | Result | Evidence / reason |
| --- | --- | --- | --- |
| 0 | `GET /ping` | **PASS** | HTTP `200`; message `Everything is okay!` |
| 0 | `GET /games/{game-id}` | **PASS** | HTTP `200`; game `12962`, `AeroBeat`, status `0` |
| 0 | `GET /games/{game-id}/mods` | **PASS** | HTTP `200`; request executed successfully, but returned `result_total = 0`, so no public mod child drill-down was possible |
| 1 | `GET /games/{game-id}/monetization/token-packs` | **SKIP — missing setup/input** | Harness skip reason: `Skipped because no access token is configured in session config` |
| 1 | `GET /me/wallets` | **SKIP — missing setup/input** | Harness skip reason: `Skipped because no access token is configured in session config` |
| 1 | `GET /me/purchased` | **SKIP — missing setup/input** | Harness skip reason: `Skipped because no access token is configured in session config` |
| 2 | `GET /games/{game-id}/mods/{owned_mod_id}/monetization/team` | **SKIP — missing setup/input** | The bearer-token lane was unavailable because `.testbed/configs/modio.session.local.cfg` was absent. Stable `owned_mod_id` / `paid_mod_id` were also blank, so this route lacked both a user token and a concrete paid mod id. Harness-reported reason during this run: `Skipped because no access token is configured in session config`. |
| 3 | `GET /s2s/monetization-teams/{monetization-team-id}/transactions` | **SKIP — missing setup/input** | Harness skip reason: `Skipped because no service_token is configured in stable config` |
| 3 | `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}` | **SKIP — missing setup/input** | Harness skip reason: `Skipped because no service_token is configured in stable config` |
| 4 | `POST /me/entitlements` | **SKIP — missing setup/input** | Not attempted because explicit ephemeral session payloads were not present and `--allow-paid-writes` was correctly left off for the default QA pass. Harness reason in this run: `Skipped unless --allow-paid-writes is explicitly enabled`. Under the observed config state, even with the flag this route would still have been blocked by missing access token and missing `entitlements_payload_json`. |
| 4 | `POST /games/{game-id}/mods/{paid_mod_id}/checkout` | **SKIP — missing setup/input** | Not attempted because explicit ephemeral session payloads were not present and `--allow-paid-writes` was correctly left off for the default QA pass. Harness reason in this run: `Skipped unless --allow-paid-writes is explicitly enabled`. Under the observed config state, even with the flag this route would still have been blocked by missing access token, missing `checkout_payload_json`, and blank `paid_mod_id`. |
| 5 | `POST /games/{game-id}/mods/{mod-id}/monetization/team` | **SKIP — out of default matrix** | Intentionally excluded from the default QA pass per plan. Audit truth note: the harness currently keeps this lane as a placeholder even when `--allow-paid-team-write` is passed; it does **not** execute the write yet. |
| 5 | `POST /s2s/transactions/intent`, `POST /s2s/transactions/commit`, `POST /s2s/transactions/clawback` | **SKIP — out of default matrix** | Intentionally excluded from the default QA pass per plan. Audit truth note: the harness currently keeps this lane as a placeholder even when `--allow-paid-s2s-writes` is passed; it does **not** execute these writes yet. |
| 5 | `DELETE /s2s/connections/{portal-id}` | **NOT RUN — deliberately excluded** | Remains outside the default QA pass because it is destructive and was not added to the default matrix. |

## Raw harness result highlights

Successful public baseline from the executed `--paid-mods --json` run:

- `environment`: `test`
- `host_kind`: `api`
- `base_url`: `https://g-12962.modapi.io/v1`
- `ok`: `true`
- `paid_mods`: `true`
- `ping`: `200`
- `game`: `200`
- `mods`: `200` with `response_result_total = 0`
- `terms`: `200`

Paid-mods-specific outcome summary from the same run:

- **passed:** none of the paid endpoints themselves, because the local paid/test-user/service-token prerequisites were absent
- **skipped for missing setup/input:** token packs, wallets, purchased, owned monetization-team read, S2S transactions list, S2S transaction detail
- **skipped because explicit ephemeral write inputs were not available / not enabled:** entitlements, checkout
- **skipped by design/out of default pass:** monetization-team write, S2S write trio, destructive disconnect

## QA conclusion

This QA pass verified two important truths:

1. The repo needed a small real harness fix before any paid-mods execution could happen under Godot 4.6.
2. After that fix, the harness truthfully reports the current machine/setup gap instead of pretending paid coverage exists.

The repo is now in a good state for an **audit of truthfulness**, but it is **not yet a credential-complete paid-mods validation** on this machine because the required session and service-token inputs were absent for the executed run.
