# AeroBeat Vendor Mod.io Test Sandbox Validation

**Date:** 2026-05-06  
**Status:** Draft  
**Agent:** Chip 🐱‍💻

---

## Goal

Update the private `test.mod.io` credentials in `aerobeat-vendor-modio` and run a safe validation session that proves the current REST harness behaves correctly against the real mod.io sandbox before we move upward into `aerobeat-tool-api`.

---

## Overview

Yesterday we finished the thin-adapter REST wrapper coverage plus the first hidden `.testbed` config loader and safe headless harness. The immediate gap was that the local `test` environment was not a real sandbox at all — it was still pointed at the same live AeroBeat tuple as `live`, which made the default safety posture misleading.

Today’s first step is to correct that split by wiring the real `test.mod.io` tuple into the ignored local config file. Once that is done, the right next move is not broad feature work; it is a short, explicit verification pass that exercises the harness in increasing confidence layers: public unauthenticated reads first, then authenticated `/me` only if the sandbox credentials/session model support it, then a targeted review of what this sandbox can and cannot tell us about the generated REST surface.

The key design question for today has now shifted in our favor. Derrick confirmed the mod.io testing portal can generate a real test-server game for AeroBeat, which means the sandbox should be capable of exercising the same functional surface area as the live server while keeping development safely isolated from the hidden production project. So this session should treat `test.mod.io` as the primary development lane and explicitly measure the sandbox’s value against our actual goals: transport correctness, path correctness, auth behavior, pagination/serialization shape, and how much of the generated REST surface we can validate there before lifting behavior into higher-layer AeroBeat services.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Yesterday’s env/harness completion plan | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-live-env-and-harness.md` |
| `REF-02` | Local private sandbox/live config | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.local.cfg` |
| `REF-03` | Optional local session config | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.session.local.cfg` |
| `REF-04` | Safe headless harness | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio_live_harness.gd` |
| `REF-05` | Harness library/planning logic | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio_live_harness_lib.gd` |
| `REF-06` | Repo usage/docs | `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |

---

## Tasks

### Task 1: Correct the local sandbox credentials split

**Bead ID:** `Pending`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Update the ignored `.testbed/modio.local.cfg` so `[modio.test]` uses the real `test.mod.io` tuple Derrick provided today while `[modio.live]` remains the current hidden live AeroBeat tuple. Do not commit secrets. Update this plan with what changed and any caveats, then close the bead.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/modio.local.cfg`
- `.plans/2026-05-06-aerobeat-vendor-modio-test-sandbox-validation.md`

**Status:** ✅ Complete

**Results:** Updated the ignored local `.testbed/modio.local.cfg` so `[modio.test]` now targets the real AeroBeat sandbox game on `test.mod.io` using the corrected tuple Derrick supplied (`game_id=1325`, `base_url=https://g-1325.test.mod.io/v1`) while leaving `[modio.live]` unchanged. This finally makes the repo’s explicit `test`/`live` split truthful in practice rather than just by config label. New session assumption: the test server is intended to support the same functional mod.io surface as live for development purposes, so routine vendor-adapter validation should prefer `test.mod.io` and reserve live for exceptional parity checks or post-sandbox confirmation only.

---

### Task 2: Run the safe sandbox harness and capture what it proves

**Bead ID:** `oc-5tm`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Run the existing safe headless harness against the corrected `test` environment, starting with the public/read-only path. If authenticated `/me` is possible with the current sandbox setup, test it separately and document exactly what additional local session/token material is required. Record the exact commands, outputs, failures, and what parts of the vendor REST surface this does and does not validate. Update the plan with evidence and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/` only if local runtime artifacts are unavoidable and ignored

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-test-sandbox-validation.md`

**Status:** ✅ Complete

**Results:** QA ran the README-documented safe harness against the corrected `test` sandbox and captured both the public-only path and the auth-gated `/me` eligibility check.

Evidence / exact commands:

```bash
godot --headless --path .testbed --script res://modio_live_harness.gd -- --help
python3 - <<'PY'
import configparser, os
p='.testbed/modio.session.local.cfg'
print({'exists': os.path.exists(p)})
if os.path.exists(p):
    cp=configparser.ConfigParser()
    cp.read(p)
    out={'environment': cp.get('modio','environment',fallback='').strip(), 'host_kind': cp.get('modio','host_kind',fallback='').strip()}
    for env in ('test','live'):
        sec=f'modio.{env}'
        out[f'{env}_has_access_token']=bool(cp.get(sec,'access_token',fallback='').strip()) if cp.has_section(sec) else False
        out[f'{env}_has_user_id']=bool(cp.get(sec,'user_id',fallback='').strip()) if cp.has_section(sec) else False
    print(out)
PY
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --public-only --json
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json
python3 - <<'PY'
import configparser, json, urllib.request, urllib.parse

def clean(s):
    s=s.strip()
    if len(s)>=2 and s[0]==s[-1]=='\"':
        s=s[1:-1]
    return s
cfg=configparser.ConfigParser(interpolation=None)
cfg.read('.testbed/modio.local.cfg')
base=clean(cfg.get('modio.test','base_url')).rstrip('/')
game_id=clean(cfg.get('modio.test','game_id'))
api_key=clean(cfg.get('modio.test','api_key'))
for label, path in [('game', f'/games/{game_id}'), ('mods', f'/games/{game_id}/mods?_limit=3')]:
    sep='&' if '?' in path else '?'
    url=f"{base}{path}{sep}api_key="+urllib.parse.quote(api_key)
    req=urllib.request.Request(url, headers={'Accept':'application/json'})
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(label, resp.status)
PY
```

Observed outputs:

- `--help` printed the expected safe harness usage and confirmed the non-destructive check list: `GET /ping`, `GET /games/{game-id}`, `GET /games/{game-id}/mods`, optional `GET /me`.
- Session-config probe printed `{'exists': False}`. There is currently no local `.testbed/modio.session.local.cfg`, so no sandbox access token is available on this machine for `/me`.
- Public-only harness run returned HTTP `200` for all three public checks against `https://g-1325.test.mod.io/v1` and reported:
  - `ping`: `message = "Everything is okay!"`
  - `game`: `status = ok`, but summary fields came back as `id = 0`, `name = ""`, `status = -1`
  - `mods`: `status = ok`, `result_count = 0`, `result_offset = 0`, `result_total = 0`, `sample_mod_names = []`, and server-reported `result_limit = 100`
  - `/me`: skipped with `reason = "Skipped by --public-only"`
- Second harness run without `--public-only` also stayed green overall, but `/me` was still skipped with `reason = "No access token configured in session config"`.
- A follow-up raw Python `urllib` sanity check failed with `HTTP Error 403: Forbidden`, so it did **not** provide a usable out-of-band confirmation of the response body shape. That failure is recorded as additional evidence that the Godot harness path is the repo’s intended validation surface right now.

What this validation **does** prove (REF-04/REF-05/REF-06):

- the corrected local `test` tuple resolves and reaches the real AeroBeat sandbox host on `test.mod.io`
- the safe headless harness executes end-to-end from the hidden `.testbed` project without requiring code edits
- public/read-only transport for `GET /ping`, `GET /games/{game-id}`, and `GET /games/{game-id}/mods` returns successful HTTP responses in the sandbox
- the harness’s auth gate behaves as designed: `/me` is only attempted when `.testbed/modio.session.local.cfg` contains an `access_token`

What this validation **does not** prove yet:

- authenticated `/me` behavior was **not exercised** in this QA pass
- no create/update/delete/upload/subscription flows were exercised; this remains read-only coverage only
- no proof yet that the game-detail summary extraction is semantically correct, because the harness reported HTTP `200` while surfacing empty game fields (`id/name/status`); that likely needs a follow-up check against the adapter/harness parsing path before treating `GET /games/{game-id}` normalization as fully validated
- no proof yet that `_limit=3` is being honored end-to-end for mod listings, because the sandbox response echoed `result_limit = 100`
- no proof yet for bearer-authenticated reads beyond the harness’s skip-path logic, and no proof at all yet for service-token / S2S routes, monetization, uploads, or write-side REST surfaces

`/me` requirements for a future sandbox pass:

- create the ignored file `.testbed/modio.session.local.cfg` from `REF-03`
- add a non-empty `[modio.test] access_token="..."`
- optional but supported: `[modio.test] user_id="..."`
- optional environment selectors (`[modio] environment`, `[modio] host_kind`) can stay blank unless a local override is desired

No secrets were committed or copied into the plan.

Follow-up local config prep after this QA pass: created the ignored `.testbed/modio.session.local.cfg` with the provided `user_id` values for both `test` and `live`, recorded the user-host API paths only as local comments/reference text, and later inserted the manually created mod.io OAuth Access secrets as temporary local `access_token` values for a direct harness experiment. Important current-model caveat: the session config does not yet have its own `base_url` field, and `ModioClientConfig.resolve_base_url()` prefers the stable env `base_url` when present, so these user-host references do not by themselves switch the harness onto the `u-...` hosts.

Additional direct auth experiment after the initial QA pass:

```bash
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env live --json
```

Observed result:
- both `test` and `live` still succeeded for `ping`, `game`, and `mods`
- both `test` and `live` failed `/me` with HTTP `401` and mod.io auth error `11005`
- returned message: `The supplied access token has either been revoked, has expired or is malformed. Please generate a new one.`

Current interpretation: the values shown by the mod.io **OAuth Access** UI as `Client Secret` are **not** directly usable as bearer access tokens for the current `/me` harness path, or at minimum they are not accepted by mod.io as such in this context. So we still need a real user access token generated by one of the supported auth/token-exchange flows before `/me` can be considered validated.

---

### Task 3: Decide the best validation posture for the rest of vendor-modio and the move into tool-api

**Bead ID:** `oc-40s`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Audit today’s sandbox findings and answer the practical question: which checks are worth keeping in `test.mod.io`, which should stay reserved for the hidden live AeroBeat project, and what minimum confidence threshold should we require before lifting mod.io behavior into `aerobeat-tool-api`? Update the plan with a concrete recommendation matrix and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-test-sandbox-validation.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Research mod.io OAuth Access client secrets versus real bearer-token issuance

**Bead ID:** `oc-c5g`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-c5g` on start. Research what the mod.io OAuth Access UI actually creates, whether its displayed `Client Secret` is supposed to be used directly as a bearer token, and which documented flow(s) produce the real user access token required for `/me`. Use local mod.io docs first. Summarize the intended production auth shape for AeroBeat as well as the fastest safe dev/testing path to obtain a real token for the harness. Update the active plan with evidence and close the bead with a clear reason when done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- local notes/docs only if strictly needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-test-sandbox-validation.md`

**Status:** ✅ Complete

**Results:** Local mod.io docs were sufficient; no web escalation was needed.

Evidence consulted:
- `REF-06` repo README, which defines the harness contract: `/me` is only attempted when `.testbed/modio.session.local.cfg` contains a user `access_token`, not a client secret.
- `/workspace/projects/modio/modio-docs/public/en-us/features/authentication/studio-website.md`
- `/workspace/projects/modio/modio-docs/public/en-us/features/authentication/s2s.md`
- `/workspace/projects/modio/modio-docs/public/en-us/features/authentication/overview.md`
- `/workspace/projects/modio/modio-docs/public/en-us/features/authentication/custom-sso-game.md`
- `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/get-authenticated-user.api.mdx`
- `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/exchange-email-security-code.api.mdx`
- `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/authenticate-via-openid.api.mdx`
- `/workspace/projects/modio/modio-docs/public/en-us/restapi/docs/schemas/access-token-object.schema.mdx`

What the mod.io OAuth Access / OAuth applications UI actually creates:
- It creates OAuth client credentials (`client_id`, `client_secret`) for the game, not a ready-to-use user bearer token.
- Those credentials are documented for two server-side token exchange families:
  - **Studio Website Login**: standard OAuth 2.0 authorization-code flow where the secure backend exchanges a temporary `code` for a user `access_token` and `refresh_token` via `POST /oauth/token`.
  - **S2S**: `client_credentials` flow where the secure backend exchanges the same class of credentials for a **service token** via `POST /oauth/token`.
- Both docs explicitly say the `client_secret` must stay on a secure backend and must not be exposed to users or frontend/client runtimes.

Conclusion on the current failed harness experiment:
- The displayed **Client Secret is not supposed to be used directly as the Bearer token for `GET /me`**.
- That matches the observed harness failure (`401`, `error_ref 11005`) when the secret was placed in the session config as though it were a user token.
- The real `/me` token is the **`access_token` returned by a supported user-auth flow**, i.e. one of:
  - email request/exchange (`/oauth/emailrequest` -> `/oauth/emailexchange`)
  - platform SSO auth endpoints (`/external/steamauth`, `/external/xboxauth`, etc.)
  - premium OpenID/custom-SSO auth (`/external/openidauth`)
  - website OAuth authorization-code exchange (`/oauth/token` with `grant_type=authorization_code`) when using mod.io as the identity provider for a studio website
- `GET /me` itself is a user-auth endpoint. The docs describe it as using the authenticated user context; S2S-only flows yield service tokens for backend APIs, not the normal client-side `/me` harness path.

Intended production auth shape for AeroBeat:
- **Game/client lane:** obtain a real **user access token** through the actual product auth flow (prefer platform SSO or custom OpenID SSO; email remains acceptable for testing only). Store only the returned user bearer token in the local harness session config when validating `/me`.
- **Backend/service lane:** if AeroBeat later needs monetization or other S2S routes, mint a separate **service token** from the OAuth client credentials on a secure backend using `grant_type=client_credentials`. Do not reuse that lane as the game-client `/me` token source.
- If AeroBeat adopts studio-owned identity, the documented premium production pattern is OpenID/custom SSO for in-game auth plus the related web flow for account-linking completeness.

Fastest safe dev/testing path for the harness right now:
1. Do **not** use the OAuth client secret directly in `.testbed/modio.session.local.cfg`.
2. Obtain a real user token through the lowest-friction documented user flow available to this project:
   - **fastest without extra platform setup:** email auth (`/oauth/emailrequest` then `/oauth/emailexchange`) against the AeroBeat test sandbox using the game `api_key`; copy only the returned `access_token` into `.testbed/modio.session.local.cfg`.
   - **closer to production if already available:** use the actual platform/OpenID auth lane and capture the returned mod.io `access_token` from that flow instead.
3. Re-run the safe harness with that returned user token to validate `/me`.

Recommended next step:
- Perform one explicit sandbox email-auth token acquisition for a throwaway/local test account, place the returned bearer `access_token` in the ignored session config, and rerun `godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json` to finally validate `/me` with a real user token. Once that works, treat the OAuth client credentials as backend/server credentials only unless a future website auth integration specifically needs the authorization-code flow.

---

### Task 5: Audit and fix `/me` response normalization in the harness/adapter

**Bead ID:** `oc-2cr`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-2cr` on start. Audit why the harness now gets HTTP 200 from `/me` with a real email-exchanged bearer token, but still surfaces empty normalized fields (`id = 0`, `name_id = ""`, `username = ""`). Inspect the raw payload shape, the adapter normalization path, and the harness summary extraction. If this is a code bug, make the minimum correct fix, add/adjust focused tests, rerun the relevant harness/tests, update the active plan with exact evidence/results, commit and push by default, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-test-sandbox-validation.md`
- `.testbed/modio_live_harness.gd`
- `.testbed/modio_live_harness_lib.gd`
- `.testbed/tests/test_modio_live_harness.gd`

**Status:** ✅ Complete

**Results:** Root cause was in the harness summary extraction, not in the adapter’s detail normalizers. The real sandbox `GET /games/{game-id}` and `GET /me` payloads are top-level JSON objects, but the harness was treating them like list endpoints and reading `response.payload.data`, which does not exist for those routes. That is why the transport correctly returned HTTP `200` while the harness surfaced empty fields (`id = 0`, `name_id = ""`, `username = ""`).

Exact raw-shape evidence from a direct Godot transport probe against the real test sandbox:

```bash
godot --headless --path .testbed --script /tmp/modio_probe.gd
```

Observed key facts:
- `game` returned `ok=true`, `status_code=200`, `has_data=false`, `id=1325`, `name="AeroBeat"`, `name_id="aerobeat"`, `status=0`
- `me` returned `ok=true`, `status_code=200`, `has_data=false`, `id=71104`, `name_id="derrickbarra"`, `username="DerrickBarra"`, `status=1`
- both payloads therefore match the existing adapter detail-normalization contract (`normalize_game_response(payload)` and `normalize_authenticated_user_response(payload)` expect a top-level object)

Minimum correct fix:
- moved the harness’s per-check detail summarization into reusable helpers in `REF-05`
- changed the harness to summarize `/games/{id}` and `/me` via the adapter normalizers on the top-level payload instead of trying to read `payload.data`
- kept list-endpoint summarization (`mods`) on the existing list-payload path
- added focused harness tests proving the summary helpers correctly read top-level detail fixtures for both `game.json` and `me.json`

Validation run after the fix:

```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json
```

Observed post-fix results:
- scaffold validation passed
- full fixture-driven suite passed: `88/88` tests
- real sandbox harness now reports the expected normalized detail fields:
  - `game`: `id = 1325`, `name = "AeroBeat"`, `status = 0`
  - `me`: `id = 71104`, `name_id = "derrickbarra"`, `username = "DerrickBarra"`

No secrets were committed. This closes the earlier false-negative interpretation that `/me` normalization itself was broken; the transport and adapter were already fine, and the bug was isolated to the safe harness summary layer.

---

## Final Results

**Status:** ⏳ Pending

**What We Built:** Pending.

**Reference Check:** Pending.

**Commits:**
- None yet.

**Lessons Learned:** Pending.

---

*Drafted on 2026-05-06*