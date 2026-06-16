# mod.io paid-mods test-server QA matrix

> Current truth from the 2026-06-16 continuation pass: the approved `u-71104.test.mod.io` bearer `/me*` lane works with a real OAuth token, the `g-1325.test.mod.io` rerun proved the game-host token-pack lane, the direct owned-mod read `GET /games/1325/mods/16364/monetization/team` is now also proven on the live paid fixture, and the restored Godot harness path reproduces those already-proven read results from the in-repo `--paid-mods` flow. The guarded buyer-write lane has now been split truthfully by input state: `POST /me/entitlements` remains intentionally deferred and locally blocked because `entitlements_payload_json` is still blank, while `POST /games/1325/mods/16364/checkout` progressed through one real `type=0` live attempt after a first local cfg JSON-escaping mistake. That live checkout used no `X-Modio-Portal` header, reached provider business validation, and failed with `422 / error_ref 900035 / The displayed price does not match the price of the given mod.` S2S/history reads remain unproven. One implementation nuance remains: the harness currently groups token-packs inside an access-token-gated paid-mods read lane even though the earlier direct game-host comparison proved `GET /games/1325/monetization/token-packs` also succeeds without bearer on `g-1325` once the host/key tuple is correct, and it still models S2S/history behind `service_token` as an implementation assumption rather than a proven provider fact.

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
- At that point in the day, the official Godot harness route was still blocked by the repo parse bug fixed later in Task 7, so Task 6 itself still relied on direct `curl` evidence rather than a successful `godot --headless ... --paid-mods` pass.

## Harness rerun (Task 8, 2026-06-15)

After Task 7 restored the `.testbed` bridge/class-loading path, I reran the monetization matrix through the real in-repo harness using the existing ignored local config exactly as requested:

```bash
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json
```

### Harness rerun results

| Harness check | Result | Exact evidence |
| --- | --- | --- |
| `paid_token_packs` | **PASS** | `200`, `result_total=6`, `selected_token_pack_id=1`. The harness reproduced the already-proven live token-pack read from `https://g-1325.test.mod.io/v1`. Its current summary only exposes count + selected id + `skus`, and the returned `skus` were blank strings, so the richer pack names/prices still come from the earlier direct `curl` proof above. |
| `paid_wallet` | **PASS** | `200` with wallet payload `type="standard_mio"`, `currency="mio"`, `balance=0`, `pending_balance=0`, `deficit=0`, `monetization_status=49`, `game_id="1325.0"`. This reproduces the already-proven `/me/wallets?game_id=1325` lane through the harness itself. |
| `paid_purchased` | **PASS (empty)** | `200`, `result_total=0`, empty `sample_mod_names`. This reproduces the earlier valid-empty purchased result through the harness itself. |
| `paid_monetization_team` | **SKIP** | Harness skip reason: `owned_mod_id or paid_mod_id is not configured in stable config; this route still needs a concrete paid mod id`. This matches the documented blocker. |
| `paid_entitlements` | **SKIP** | Harness skip reason: `Skipped unless --allow-paid-writes is explicitly enabled; payload JSON and paid_mod_id remain required even after opting in`. This matches the documented blocker. |
| `paid_checkout` | **SKIP** | Same guarded-write skip reason as entitlements. |
| `paid_s2s_transactions` | **SKIP** | Harness skip reason: no `service_token` and no `monetization_team_id`; the harness still models this lane behind `service_token`. This matches the documented open question/blocker. |
| `paid_s2s_transaction` | **SKIP** | Same S2S prerequisite gap as the list read. |

### Harness rerun interpretation

- The restored in-repo harness path is now genuinely working again: the exact `godot --headless ... --paid-mods --json` command completed successfully and exited `0`.
- The harness now reproduces the previously proven monetization read results that have truthful inputs in local ignored config:
  - token packs on `g-1325`
  - wallet on `game_id=1325`
  - purchased paid mods as a valid empty result
- The still-blocked lanes are unchanged and truthful:
  - owned-mod monetization team still lacks `owned_mod_id` / `paid_mod_id`
  - guarded buyer writes still lack opt-in plus payload JSON / paid mod id
  - S2S/history still lacks `service_token`, `monetization_team_id`, and any truthful transaction input
- The harness output materially matches the documented matrix on pass/skip state, prerequisite boundaries, and the S2S open question.
- Important nuance: the harness still *models* token-packs inside its access-token-gated `paid_bearer_reads` group. That matches current implementation and current harness output, but it is slightly stricter than the earlier direct game-host proof, which showed token-packs also succeed on `g-1325` without bearer once the host/key tuple is correct.

## Owned paid-mod id discovery (Task 10, 2026-06-15)

To unblock the next read-only monetization lane, I checked whether DerrickBarra currently has any truthful paid mod on `game_id=1325` that he can administer, using the already-proven bearer + `g-1325` context but without calling `/monetization/team` yet.

| Discovery check | Result | Exact evidence |
| --- | --- | --- |
| `GET /games/1325/mods?submitted_by=71104&status=1&_limit=100` | **PASS — no paid ids** | `200`, `result_total=2`, rows `16165` and `16112`; both returned `monetization_options=0`, `price=0`, `stock=0`. |
| `GET /games/1325/mods?submitted_by=71104&status=3&_limit=100` | **PASS — no paid ids** | `200`, `result_total=52`; every returned row had `monetization_options=0`, `price=0`, `stock=0`. |
| `GET /me/mods?_limit=100` on `https://u-71104.test.mod.io/v1` | **PASS — supporting inventory read, no paid ids** | `200`, `result_total=54`; zero rows had `price>0`, `monetization_options>0`, or non-empty `skus`. |
| `GET /me/purchased` | **PASS (empty) — supporting buyer inventory read** | Already proven earlier in this matrix: `200`, `result_total=0`. |

### Task 10 interpretation

- No truthful owned/administered paid mod id was discoverable for DerrickBarra on `game_id=1325` during this pass.
- The blocker is now narrower and more honest: the next lane is not blocked by a missing local placeholder alone; it is blocked because the current test-server fixture set does not expose any paid mod in DerrickBarra’s administered inventory.
- I did **not** call `GET /games/{game-id}/mods/{owned_mod_id}/monetization/team` in this discovery step because no truthful `owned_mod_id` / `paid_mod_id` was found to supply.

## Paid workout fixture creation (Task 11, 2026-06-15)

To unblock the deeper monetization lanes honestly, I created a new disposable workout fixture directly through the REST-backed authoring path on `https://g-1325.test.mod.io/v1` using the existing bearer context for `DerrickBarra`.

| Step | Result | Exact evidence |
| --- | --- | --- |
| `POST /games/1325/mods` | **PASS** | `201`, created draft/public mod `16364` (`name_id="oc-paid-workout-fixture-20260615"`) with `community_options=131072`, `price=0`, `monetization_options=0`, and the uploaded logo present. |
| `POST /games/1325/mods/16364/files` | **PASS** | `201`, created modfile `23257` (`filename="paid-workout-0tnj.zip"`, `version="1.0.0"`, md5 `b8f6cd8a6ab49fe8e04b858ecfd5fe8f`). |
| First `POST /games/1325/mods/16364` paid-state attempt with `status=1`, `visible=1`, `summary`, `price=500`, `monetization_options=2` | **FAIL — provider prerequisite surfaced** | `404`, `error_ref 900022`, `Monetization team could not be found.` The same response still left the mod published at `status=1`, but `price` and `monetization_options` remained `0`. |
| `POST /games/1325/mods/16364/monetization/team` as multipart | **FAIL — request-shape truth surfaced** | `415`, `error_ref 13006`, `Incorrect Content-Type header in request, must be application/x-www-form-urlencoded`. |
| `POST /games/1325/mods/16364/monetization/team` as `application/x-www-form-urlencoded` with `users[0][id]=71104` and `users[0][split]=100` | **PASS** | `200`, returned one monetization-team account row for `id=71104`, `username="DerrickBarra"`, `monetization_status=49`, `monetization_options=1`, `split=100`. |
| Second `POST /games/1325/mods/16364` paid-state attempt with `status=1`, `visible=1`, `summary`, `price=500`, `monetization_options=2` | **PASS** | `200`, returned mod `16364` with `price=500`, `monetization_options=2`, and the uploaded modfile still attached. |
| `GET /games/1325/mods/16364` | **PASS — final verification** | `200`, confirmed final fixture state `status=1`, `visible=1`, `price=500`, `monetization_options=2`, `modfile.id=23257`, `name_id="oc-paid-workout-fixture-20260615"`. |

### Task 11 interpretation

- The paid workout fixture was **actually created**. The truthful paid fixture is mod **`16364`** on `game_id=1325`.
- The exact blocker that prevented the first paid-state update was provider-side and concrete: the mod needed a monetization-team row before `price` + `monetization_options` updates would succeed.
- The live server also exposed a request-shape nuance worth keeping explicit: despite the repo currently documenting the create route as multipart, this test-server route rejected multipart and required `application/x-www-form-urlencoded` for the `users[0][id]` / `users[0][split]` body.
- The resulting fixture is now suitable for the next deeper monetization lanes because it has a truthful owned paid mod id plus a truthful mod monetization team.

## Owned-mod read + S2S readiness pass (Task 13, 2026-06-16)

For this continuation slice I touched only ignored local stable config to let the current harness/runtime path resolve the truthful paid fixture directly:

- `.testbed/configs/modio.local.cfg`
  - `owned_mod_id="16364"`
  - `paid_mod_id="16364"`
- `.testbed/configs/modio.session.local.cfg`
  - unchanged for this task; bearer `access_token` remained present, while `s2s_filters_json` and `s2s_transaction_id` remained blank

### Exact owned-mod read request context

```bash
curl -sS -D - -A 'curl/8.5.0' \
  -H 'Accept: application/json' \
  -H 'Authorization: Bearer <existing OAuth token>' \
  'https://g-1325.test.mod.io/v1/games/1325/mods/16364/monetization/team?api_key=<g-1325 api key>'
```

Local prerequisite state at the moment of this call:

- `base_url=https://g-1325.test.mod.io/v1`
- `game_id=1325`
- `owned_mod_id=16364`
- `paid_mod_id=16364`
- `api_key` present
- bearer `access_token` present
- `service_token` blank
- `monetization_team_id` blank
- `s2s_filters_json` blank
- `s2s_transaction_id` blank

### Task 13 result matrix

| Step | Result | Exact evidence |
| --- | --- | --- |
| `GET /games/1325/mods/16364/monetization/team` | **PASS** | `200`, body `{"data":[{"id":71104,"name_id":"derrickbarra","username":"DerrickBarra","monetization_status":49,"monetization_options":1,"split":100}],"result_count":1,...,"result_total":1}`. Exact owned-mod monetization-team read is now proven on the live fixture. |
| `GET /s2s/monetization-teams/{monetization-team-id}/transactions` | **NOT RUNNABLE — local prerequisite gap** | I did **not** issue this call because current local runtime state still leaves `service_token=""`, `monetization_team_id=""`, and `s2s_filters_json=""`. Under the current adapter/harness implementation, the list route still requires both a truthful team path input and the current service-token assumption. |
| `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}` | **NOT RUNNABLE — local prerequisite gap** | I did **not** issue this call because the list route never became runnable and current local runtime state still leaves `s2s_transaction_id=""`. No truthful transaction id surfaced from the owned-mod read. |

### Harness cross-check after setting `owned_mod_id`

The restored in-repo harness now reproduces the same read-side split on current HEAD:

```bash
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json
```

Relevant harness evidence from that run:

- `paid_monetization_team` → `status="ok"`, `status_code=200`, `response_result_total=1`, `usernames=["DerrickBarra"]`, `splits=[100]`
- `paid_s2s_transactions` → `status="skipped"` with reason `Skipped because no service_token is configured in stable config; no monetization_team_id is configured in stable config or s2s_filters_json; current harness still models this lane behind service_token, which remains an open question to verify`
- `paid_s2s_transaction` → same skipped reason as the list route

### Task 13 interpretation

- The owned-mod monetization-team read is now **directly proven** against the truthful paid fixture `16364`.
- No new `monetization_team_id` or transaction id surfaced from that read, so it did not unblock S2S detail.
- S2S history is still blocked by **local prerequisite gaps**, not by a newly observed provider response. The important split remains:
  - missing path facts: `monetization_team_id`, `transaction_id`
  - current harness/adapter assumption still under test: `service_token`
- Because the instruction explicitly forbade inventing S2S path facts or payloads, stopping after the owned-mod read was the truthful outcome for this slice.

## Guarded buyer-write preflight (Task 14, 2026-06-16)

For this slice I kept the now-proven paid fixture context in place and used the restored harness path with explicit opt-in so the repo’s own write-preflight surface would speak first:

```bash
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --allow-paid-writes --json
```

Relevant local runtime state at execution time:

- `base_url=https://g-1325.test.mod.io/v1`
- `game_id=1325`
- `owned_mod_id=16364`
- `paid_mod_id=16364`
- `api_key` present
- bearer `access_token` present
- `entitlements_payload_json=""`
- `checkout_payload_json=""`
- `service_token` blank
- `monetization_team_id` blank

### Task 14 result matrix

| Step | Result | Exact evidence |
| --- | --- | --- |
| `POST /me/entitlements` preflight/attempt | **NOT RUNNABLE — missing payload JSON** | Harness result `paid_entitlements` → `status="skipped"`, reason `Skipped because entitlements_payload_json is empty in the session config`. No adapter validation error surfaced and no live provider request was issued because execution stopped before request building/network submission. |
| `POST /games/1325/mods/16364/checkout` preflight/attempt | **NOT RUNNABLE — missing payload JSON** | Harness result `paid_checkout` → `status="skipped"`, reason `Skipped because checkout_payload_json is empty in the session config`. No adapter validation error surfaced and no live provider request was issued because execution stopped before request building/network submission. |
| buyer-write route-group overview | **BLOCKED** | Harness `paid_buyer_writes` group remained `status="blocked"` with missing prerequisites `entitlements_payload_json in .testbed/configs/modio.session.local.cfg; checkout_payload_json in .testbed/configs/modio.session.local.cfg`. |

### Task 14 interpretation

- The guarded buyer-write lane is still blocked by **missing session payload JSON**, not by bearer auth, not by missing paid mod id, not by adapter field validation, and not by a live provider/business response.
- Because both payload inputs were blank, the truthful result was to stop before fake execution. No POST to `/me/entitlements` or `/games/1325/mods/16364/checkout` was attempted.
- No new transaction id, order id, checkout object id, or entitlement object id surfaced from this task.
- The next real step for this lane is not “retry harder”; it is to supply truthful `entitlements_payload_json` and `checkout_payload_json` in ignored local session config and then rerun the same guarded path.

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

## 2026-06-16 checkout-first direct mod.io attempt on paid fixture `16364`

This continuation slice kept **entitlements deferred** and exercised only the first truthful direct checkout lane for the desktop/web-distributed AeroBeat scenario.

### Outcome split by layer

1. **Local validation failure (first pass only)**
   - The first ignored-session-config injection for `checkout_payload_json` was over-escaped.
   - `ModioEnvLoader` reported:
     - `Parse JSON failed. Error at line 0: Unexpected character`
     - `Expected modio.test.checkout_payload_json to contain a JSON object`
   - Because of that local cfg encoding bug, the first harness pass truthfully treated checkout as config-empty and reported:
     - `paid_checkout` → `status="skipped"`
     - reason: `Skipped because checkout_payload_json is empty in the session config`
   - **No checkout request was built or sent in that first pass.**

2. **Adapter / harness behavior (second pass, after fixing local cfg encoding)**
   - Restored harness path used successfully:
     ```bash
     godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --allow-paid-writes --json
     ```
   - Exact session payload injected for the live checkout attempt:
     ```json
     {"mod_id":"16364","fields":{"idempotent_key":"checkout-890ddbfc-8b19-4af3-b8dc-aa859330b81c","type":0,"display_amount":499}}
     ```
   - Exact request shape built by the adapter and prepared by the transport:
     - method: `POST`
     - url: `https://g-1325.test.mod.io/v1/games/1325/mods/16364/checkout`
     - headers:
       - `Authorization: Bearer <present access_token>`
       - `Accept-Language: en-US`
       - `Content-Type: application/x-www-form-urlencoded`
       - **no `X-Modio-Portal` header**
     - body: `display_amount=499&idempotent_key=checkout-890ddbfc-8b19-4af3-b8dc-aa859330b81c&type=0`
   - Harness-side companion truth in the same run:
     - `paid_entitlements` remained `skipped` because `entitlements_payload_json` is still blank by design for this slice.
     - `paid_wallet` still showed `balance=0`, consistent with the checkout not completing.

3. **Live provider response (second pass)**
   - `paid_checkout` → `status="failed"`, `status_code=422`
   - provider `error_ref=900035`
   - provider message: `The displayed price does not match the price of the given mod.`
   - **No checkout object id, transaction id, order id, payment URL, or redirect URL was returned.**

### What this proves

- The restored Godot harness path can now execute the guarded checkout lane truthfully.
- Direct checkout **without** an `X-Modio-Portal` header is at least **request-viable** for the current desktop/web scenario, because the live request reached provider business validation instead of failing on missing/invalid portal wiring.
- The current blocker is **not** missing local auth, missing mod-id wiring, or adapter validation.
- The current blocker **is** the provider-side `display_amount` / checkout-price contract for this `type=0` attempt.

### Current best reading of the remaining blocker

The research-driven first guess was:
- paid mod price: `500` tokens
- token-pack display amount candidate: `499`
- checkout mode: `type=0`

This live result shows that `display_amount=499` is **not** accepted by the provider for the attempted checkout, even though the token-pack browse lane made that value look like the best first candidate. So that assumption is now **partially falsified** for actual checkout submission and should be refined before the next guarded attempt.

### Practical QA verdict for this slice

- **Exact payload attempted:** `{"mod_id":"16364","fields":{"idempotent_key":"checkout-890ddbfc-8b19-4af3-b8dc-aa859330b81c","type":0,"display_amount":499}}`
- **Exact live result:** `422 / error_ref 900035 / The displayed price does not match the price of the given mod.`
- **Direct web checkout without portal header viable?** Yes at the **request-routing / provider-validation** level; still **not yet proven successful end-to-end**.
- **What still blocks full checkout validation?** Determining the provider-accepted `display_amount` semantics/value for this direct type-`0` lane, then rerunning with a fresh idempotent key.
