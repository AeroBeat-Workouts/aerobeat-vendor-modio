# mod.io paid-mods test-server QA matrix

> Current truth from the 2026-06-15 revalidation pass: the approved `u-71104.test.mod.io` bearer `/me*` lane works with a real OAuth token, and the later `g-1325.test.mod.io` rerun finally proved the game-host token-pack lane too. The remaining unproven monetization lanes are still the owned-mod read, guarded buyer writes, and S2S/history reads because this repo slice still lacks truthful mod/team/payload inputs and the official Godot harness path still fails parse on current HEAD.

_Date:_ 2026-06-15  
_Repo:_ `aerobeat-vendor-modio`  
_Target:_ approved test user host `https://u-71104.test.mod.io/v1` with supplied facts:

- `username`: `DerrickBarra`
- `user_id`: `71104`
- `api_key`: provided and used locally in ignored cfg only
- `api_path`: `https://u-71104.test.mod.io/v1`

## OAuth bearer rerun (Task 5, 2026-06-15)

This follow-up rerun used the newly supplied OAuth bearer tokens instead of the earlier blank-token session config. I updated only the ignored local cfg files needed for the rerun:

- `.testbed/configs/modio.local.cfg`
  - `game_id="1325"`
  - `api_key="<provided u-71104 api key>"`
  - `base_url="https://u-71104.test.mod.io/v1"`
- `.testbed/configs/modio.session.local.cfg`
  - `access_token="<AeroBeat Test Harness - test.mod.io OAuth token>"`
  - `user_id="71104"`

The second supplied OAuth token for `games-1325` was **not** needed for the local rerun config, but it was used in direct comparison calls below. On the tested bearer endpoints, both tokens produced the same live results against the approved `u-71104.test.mod.io` host.

### Exact bearer rerun commands

```bash
# user-host token
curl -sS -D - -A 'curl/8.5.0' \
  -H "Authorization: Bearer <AeroBeat Test Harness token>" \
  -H 'Accept: application/json' \
  'https://u-71104.test.mod.io/v1/me?api_key=<u-71104 api key>'

curl -sS -D - -A 'curl/8.5.0' \
  -H "Authorization: Bearer <AeroBeat Test Harness token>" \
  -H 'Accept: application/json' \
  'https://u-71104.test.mod.io/v1/me/purchased?api_key=<u-71104 api key>'

curl -sS -D - -A 'curl/8.5.0' \
  -H "Authorization: Bearer <AeroBeat Test Harness token>" \
  -H 'Accept: application/json' \
  'https://u-71104.test.mod.io/v1/me/wallets?api_key=<u-71104 api key>&game_id=1325'

# comparison with the second supplied token for games-1325
curl -sS -D - -A 'curl/8.5.0' \
  -H "Authorization: Bearer <games-1325 token>" \
  -H 'Accept: application/json' \
  'https://u-71104.test.mod.io/v1/me?api_key=<u-71104 api key>'
```

### OAuth bearer rerun results

| Endpoint | Token(s) tested | Result | Exact evidence |
| --- | --- | --- | --- |
| `GET /me` | `AeroBeat Test Harness - test.mod.io`, `games-1325` | **PASS** | Both tokens returned `200` with the same user profile for `id=71104`, `username="DerrickBarra"`, and `monetization_status=49`. |
| `GET /me/purchased` | `AeroBeat Test Harness - test.mod.io`, `games-1325` | **PASS (empty)** | Both tokens returned `200` with `{"data":[],"result_count":0,...,"result_total":0}`. This is a valid empty bearer result, not an auth failure. |
| `GET /me/wallets?game_id=1325` | `AeroBeat Test Harness - test.mod.io`, `games-1325` | **PASS** | Both tokens returned `200` with wallet payload `{"type":"standard_mio","currency":"mio",...,"balance":0,"pending_balance":0,"deficit":0,"monetization_status":49,"game_id":1325}`. |
| `GET /me/wallets` (no `game_id`) | `AeroBeat Test Harness - test.mod.io` | **FAIL — provider/business response** | Returned `404`, `error_ref 14001`, `The requested resource could not be found.` |
| `GET /me/wallets?game_id=12962` | `AeroBeat Test Harness - test.mod.io` | **FAIL — stale/incorrect game context** | Returned `404`, `error_ref 14001`, `The requested resource could not be found.` |

### OAuth bearer rerun interpretation

- The newly supplied OAuth bearer tokens unblocked the `/me` bearer lane exactly as hoped.
- The corrected bearer context is: approved user host `https://u-71104.test.mod.io/v1`, the supplied `u-71104` API key, and a real bearer token. Under that context, `/me`, `/me/purchased`, and `/me/wallets?game_id=1325` all work.
- The `games-1325` token did **not** change the observed behavior on these tested bearer reads versus the `AeroBeat Test Harness - test.mod.io` token.
- The stale prior `game_id=12962` is no longer the truthful wallet context for this bearer lane. `1325` is the working wallet game context evidenced by the live response.
- At this point in the day, full game-scoped bearer rerun was still blocked only by the missing `g-1325.test.mod.io` API key. Task 6 below closes that gap.

## Game-host rerun (Task 6, 2026-06-15)

This follow-up rerun switched the ignored stable config to the supplied AeroBeat game host facts and reused the already-proven bearer session context without inventing any new mod/team ids or write payloads.

Local-only config touched for this rerun:

- `.testbed/configs/modio.local.cfg`
  - `game_id="1325"`
  - `api_key="<provided g-1325 api key>"`
  - `base_url="https://g-1325.test.mod.io/v1"`
- `.testbed/configs/modio.session.local.cfg`
  - reused the existing `access_token` for `user_id="71104"`
  - no new payload/team/mod ids were added

### Exact game-host rerun commands

```bash
# preflight
curl -sS -D - -A 'curl/8.5.0' \
  -H 'Accept: application/json' \
  'https://g-1325.test.mod.io/v1/ping?api_key=<g-1325 api key>'

curl -sS -D - -A 'curl/8.5.0' \
  -H 'Accept: application/json' \
  'https://g-1325.test.mod.io/v1/games/1325?api_key=<g-1325 api key>'

# target monetization read with the already-proven bearer context
curl -sS -D - -A 'curl/8.5.0' \
  -H 'Accept: application/json' \
  -H 'Authorization: Bearer <existing OAuth token>' \
  'https://g-1325.test.mod.io/v1/games/1325/monetization/token-packs?api_key=<g-1325 api key>'

# comparison call without bearer to isolate whether this route actually depends on bearer on g-host
curl -sS -D - -A 'curl/8.5.0' \
  -H 'Accept: application/json' \
  'https://g-1325.test.mod.io/v1/games/1325/monetization/token-packs?api_key=<g-1325 api key>'
```

### Game-host rerun results

| Endpoint | Auth context tested | Result | Exact evidence |
| --- | --- | --- | --- |
| `GET /ping` on `https://g-1325.test.mod.io/v1` | game API key | **PASS** | `200`, body `{"code":200,"success":true,"message":"Everything is okay!"}` |
| `GET /games/1325` on `https://g-1325.test.mod.io/v1` | game API key | **PASS** | `200` with live AeroBeat game payload for `id=1325`, `name="AeroBeat"`, `name_id="aerobeat"`, `monetization_options=771`, and `monetization_teams=[{"team_id":1213641596,"gateway":"tilia"},{"team_id":1364052727,"gateway":"airwallex"}]`. |
| `GET /games/1325/monetization/token-packs` on `https://g-1325.test.mod.io/v1` | game API key + bearer | **PASS** | `200` with `result_total=6` and six live token packs: `200 Pack`, `500 Pack`, `1000 Pack`, `2000 Pack`, `5000 Pack`, `10000 Pack` (`portal="web"`, prices `199/499/999/1999/4999/9999`, amounts `200/500/1000/2000/5000/10000`). |
| `GET /games/1325/monetization/token-packs` on `https://g-1325.test.mod.io/v1` | game API key only (no bearer) | **PASS** | Returned the same `200` payload and `result_total=6` as the bearer call. On this route, the correct game-host/key tuple was the real blocker in earlier slices; bearer was not required for the observed success once the host/key were corrected. |

### Game-host rerun interpretation

- Task 6 successfully revalidated the remaining game-host monetization read that was previously blocked by the wrong host/key context: `GET /games/1325/monetization/token-packs` is now **proven working** on `https://g-1325.test.mod.io/v1`.
- The correct game host itself is also now directly proven by `GET /games/1325`.
- The live token-pack payload shows six configured web packs and removes the earlier ambiguity that came from testing against stale `12962` / user-host context.
- The comparison call without bearer matters: for this exact token-pack route on the corrected g-host, the response succeeded with the game API key alone. So the truthful separation is:
  - user-host `/me*` monetization reads still require bearer auth;
  - game-host token-pack read is now proven on the game host and did **not** require bearer in the observed successful call.
- No other monetization-adjacent game-host reads became testable without inventing missing inputs. Owned-mod monetization-team read still needs a truthful `owned_mod_id` / `paid_mod_id`, guarded buyer writes still need payloads, and S2S/history still needs team/transaction inputs.
- The official Godot harness route is still blocked by the same repo parse bug on current HEAD, so this rerun also relied on direct `curl` evidence rather than a successful `godot --headless ... --paid-mods` pass.

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
