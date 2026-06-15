# mod.io paid-mods test-server QA matrix

> Current truth from the 2026-06-15 revalidation pass: Derrick’s approved `u-71104.test.mod.io` user-host tuple is real and reachable, bearer-only `/me/*` monetization reads still require an access token beyond `api_key` + `api_path`, and the supplied facts were not enough to truthfully execute the game-scoped or S2S-scoped monetization lanes without inventing missing inputs.

_Date:_ 2026-06-15  
_Repo:_ `aerobeat-vendor-modio`  
_Target:_ approved test user host `https://u-71104.test.mod.io/v1` with supplied facts:

- `username`: `DerrickBarra`
- `user_id`: `71104`
- `api_key`: provided and used locally in ignored cfg only
- `api_path`: `https://u-71104.test.mod.io/v1`

## Exact commands run

```bash
git rev-parse --short HEAD

# local-only ignored config creation for this QA pass
cat > .testbed/configs/modio.local.cfg <<'EOF'
[modio]
default_environment="test"
accept_language="en-US"
host_kind="api"

[modio.test]
game_id="12962"
api_key="<provided test-server api_key>"
base_url="https://u-71104.test.mod.io/v1"
service_token=""
portal=""
platform=""
monetization_team_id=""
owned_mod_id=""
paid_mod_id=""
EOF

cat > .testbed/configs/modio.session.local.cfg <<'EOF'
[modio]
environment="test"

[modio.test]
access_token=""
user_id="71104"
entitlements_payload_json=""
checkout_payload_json=""
s2s_filters_json=""
s2s_transaction_id=""
EOF

# direct preflight + staircase evidence
curl -sS 'https://u-71104.test.mod.io/v1/ping?api_key=<api_key>'
curl -sS 'https://u-71104.test.mod.io/v1/games?api_key=<api_key>&_limit=5'
curl -sS 'https://u-71104.test.mod.io/v1/games/12962/monetization/token-packs?api_key=<api_key>'
curl -sS 'https://u-71104.test.mod.io/v1/me/wallets?api_key=<api_key>&game_id=12962'
curl -sS 'https://u-71104.test.mod.io/v1/me/purchased?api_key=<api_key>&game_id=12962'
curl -sS 'https://u-71104.test.mod.io/v1/me?api_key=<api_key>'

# adjacent host-shape sanity checks while isolating the game-id/host issue
curl -sS 'https://api.test.mod.io/v1/games/12962?api_key=<api_key>'
curl -sS 'https://g-12962.test.mod.io/v1/games/12962?api_key=<api_key>'
curl -sS 'https://g-12962.modapi.io/v1/games/12962?api_key=<api_key>'

# current harness execution attempt on HEAD
 godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json
```

## Local config state used for this QA run

Created local-only ignored files:

- `.testbed/configs/modio.local.cfg`
- `.testbed/configs/modio.session.local.cfg`

Configured locally for this run:

- `base_url = https://u-71104.test.mod.io/v1`
- `user_id = 71104`
- `game_id = 12962` (carried forward from the repo’s prior known AeroBeat testbed tuple so the existing game-scoped routes could be exercised honestly if still valid)
- `api_key = <provided test-server api_key>`

Left intentionally blank because no truthful value was provided for this run:

- `access_token`
- `service_token`
- `monetization_team_id`
- `owned_mod_id`
- `paid_mod_id`
- `entitlements_payload_json`
- `checkout_payload_json`
- `s2s_filters_json`
- `s2s_transaction_id`

## Repo-side blocker encountered

The current HEAD (`dbec118`) did **not** allow the paid-mods Godot harness to run successfully during this QA pass.

Observed failure:

- `godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json`
- Godot reported repeated parse failures while loading `ModioVendorAdapter` from `res://src/modio_vendor_adapter.gd`, which then caused `modio_live_harness.gd` itself to fail parse/load.
- This is a **repo/runtime bug**, not a provider-side monetization response.

Because the harness could not execute on the current checkout, the endpoint staircase evidence below was gathered directly with `curl` against the approved test-server tuple.

## Preflight evidence

| Check | Result | Evidence |
| --- | --- | --- |
| `GET /ping` on `https://u-71104.test.mod.io/v1` | **PASS** | `200`, body `{"code":200,"success":true,"message":"Everything is okay!"}` |
| `GET /games` on `https://u-71104.test.mod.io/v1` | **PASS but empty** | `200`, body `{"data":[],"result_count":0,...,"result_total":0}` |
| `GET /games/12962` on `https://u-71104.test.mod.io/v1` | **FAIL — provider/business response** | `404`, `error_ref 14000`, `The requested game id could not be found.` |
| `GET /games/12962` on `https://api.test.mod.io/v1` | **FAIL — provider/business response** | `404`, `error_ref 14000`, `The requested game id could not be found.` |
| `GET /games/12962` on `https://g-12962.test.mod.io/v1` | **FAIL — provider/business response** | `404`, `error_ref 14000`, `The requested game id could not be found.` |
| `GET /games/12962` on old prior host `https://g-12962.modapi.io/v1` | **FAIL — stale tuple** | `401`, `error_ref 11002`, `Invalid credentials.` |

Interpretation:

- The supplied approved tuple is definitely a real reachable **user-host**.
- The prior repo-era `game_id=12962` tuple does **not** currently resolve as a valid game-scoped target with the newly supplied approval facts.
- So game-scoped monetization routes were blocked by **missing/invalid target-game context**, not just by the harness.

## Staircase result matrix

| Phase | Endpoint | Result | Exact evidence / reason |
| --- | --- | --- | --- |
| A | `GET /games/{game-id}/monetization/token-packs` | **BLOCKED — supplied game-scoped target did not resolve** | Direct call to `https://u-71104.test.mod.io/v1/games/12962/monetization/token-packs?api_key=<api_key>` returned `404`, `error_ref 14000`, `The requested game id could not be found.` This did **not** prove a bearer-token rejection; it proved the provided run facts did not expose a valid game-scoped target for this route. |
| A | `GET /me/wallets` | **FAIL — provider auth rejection** | Direct call to `https://u-71104.test.mod.io/v1/me/wallets?api_key=<api_key>&game_id=12962` returned `401`, `error_ref 11005`, `The supplied access token has either been revoked, has expired or is malformed. Please generate a new one.` |
| A | `GET /me/purchased` | **FAIL — provider auth rejection** | Direct call to `https://u-71104.test.mod.io/v1/me/purchased?api_key=<api_key>&game_id=12962` returned `401`, `error_ref 11005`, `The supplied access token has either been revoked, has expired or is malformed. Please generate a new one.` |
| A (supporting auth check) | `GET /me` | **FAIL — provider auth rejection** | Direct call to `https://u-71104.test.mod.io/v1/me?api_key=<api_key>` returned the same `401`, `error_ref 11005` bearer-token error. This confirms the current approval facts do **not** replace bearer access-token auth for `/me/*` monetization reads. |
| B | `GET /games/{game-id}/mods/{owned_mod_id}/monetization/team` | **SKIP — missing local config input** | No truthful `owned_mod_id` / `paid_mod_id` was available, and the run also lacked an `access_token`. Because `/games/12962` itself did not resolve on the supplied tuple, this route had no valid game+mod target to test. |
| C | `POST /me/entitlements` | **SKIP — missing local config input** | Not attempted. No `access_token` and no `entitlements_payload_json` were available. Per instruction, no write payload was invented. |
| C | `POST /games/{game-id}/mods/{paid_mod_id}/checkout` | **SKIP — missing local config input** | Not attempted. No `access_token`, no `paid_mod_id`, and no `checkout_payload_json` were available. Per instruction, no write payload was invented. |
| D | `GET /s2s/monetization-teams/{monetization-team-id}/transactions` | **SKIP — missing local config input** | Not attempted. No truthful `monetization_team_id` was available. The current repo/harness also still models this lane behind `service_token`, and today’s facts did not include one. |
| D | `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}` | **SKIP — missing local config input** | Not attempted. No truthful `monetization_team_id` or `transaction_id` was available, and the current implementation also expects `service_token`. |

## Main conclusion

Danny’s statement is **not yet fully validated by this run** because the supplied facts were insufficient to execute the full staircase end-to-end.

What this run **did** prove:

1. The approved `u-71104.test.mod.io` user-host tuple is real and reachable.
2. `api_key + api_path` alone are **not enough** for bearer `/me/*` monetization reads today; mod.io still returns `401 / error_ref 11005` until a real bearer `access_token` is supplied.
3. The supplied facts did **not** expose a valid game-scoped target for `GET /games/{game-id}/monetization/token-packs` or downstream owned-mod routes. The carried-forward `game_id=12962` now returned `14000 game id could not be found` across the reachable test hosts checked during this run.
4. The repo also currently has a real harness/runtime blocker on HEAD: `modio_live_harness.gd` could not run because `res://src/modio_vendor_adapter.gd` failed parse as a global class.

What remains **unproven** after this run:

- whether a valid bearer `access_token` plus the correct game/mod ids would make the bearer and owned-mod monetization reads succeed immediately under the new approval
- whether S2S history still truly needs `service_token`, because this run never had a truthful `monetization_team_id` / `transaction_id` pair to test that hypothesis directly

## QA verdict for this slice

This was a **truthful partial staircase execution**:

- Phase A produced real provider evidence for the `/me/*` bearer lane.
- The game-scoped Phase A token-pack route was blocked by missing/invalid target-game context under the supplied facts.
- Phases B, C, and D remained blocked by missing local inputs that the instructions correctly forbade inventing.
- The checkout itself also currently contains a separate repo bug in the Godot harness path.
