# AeroBeat Vendor mod.io Master REST API Exercise Plan

**Date:** 2026-05-06  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Systematically exercise the `aerobeat-vendor-modio` REST surface against the AeroBeat `test.mod.io` environment so we can catch and fix provider-seam bugs in this repo before lifting behavior into `aerobeat-tool-api`.

---

## Overview

This session proved the key foundations we needed before a broader endpoint sweep: the AeroBeat test sandbox is real, public read flows work, bearer-authenticated `/me` works via email-exchanged user token, the harness was repaired for detail-response normalization, and the mod-list `_limit` concern was traced to sandbox empty-list response behavior rather than a client-side query bug. That means the next phase can stop guessing and start exercising the wrapped surface in a disciplined way.

The right shape here is not “hit everything randomly.” We should sweep the vendor seam in risk-ordered slices so bugs stay attributable. Start with stable read-only public endpoints, then authenticated user reads, then low-risk authenticated writes in the sandbox, then authoring/update/delete flows, then optional higher-risk or special-token routes only if they are still in scope for near-term AeroBeat needs. Each slice should use the same coder → QA → auditor loop, record exact requests and normalization output, and leave behind focused tests whenever we fix a bug.

This plan is intentionally scoped to the **test server only**. Live parity checks can stay as selective confidence passes later, but the working assumption now is that routine provider-seam validation belongs on `test.mod.io`. Current sandbox constraint from Derrick: this test environment appears limited to a single test user account, so multi-user social assertions should be treated as partially verifiable or deferred rather than blocked on manual content creation. Likewise, platform/entitlement-style routes should be pulled forward only as AeroBeat actually needs them, with Steam expected to be the first real platform-specific lane for PC. The outcome we want is a hardening pass on `aerobeat-vendor-modio`: proven endpoint behavior, known unsupported gaps, reproducible harness recipes, and a clear confidence threshold for when `aerobeat-tool-api` can safely depend on this repo.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Vendor repo overview and wrapped surface list | `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |
| `REF-02` | Active sandbox validation plan and evidence so far | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-06-aerobeat-vendor-modio-test-sandbox-validation.md` |
| `REF-03` | Private stable sandbox/live config | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.local.cfg` |
| `REF-04` | Private session config with test user token | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.session.local.cfg` |
| `REF-05` | Safe harness entrypoint | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio_live_harness.gd` |
| `REF-06` | Harness support library | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio_live_harness_lib.gd` |
| `REF-07` | mod.io REST docs mirror | `/workspace/projects/modio/modio-docs` |

---

## Execution Strategy

### Sweep order

1. **Public read baseline**
   - `ping`, game detail, game tags/stats, public mod list/detail/files/stats/dependants/tags/metadata/team, public guides/collections/comments where applicable
2. **Authenticated user-read baseline**
   - `/me`, `/me/games`, `/me/mods`, `/me/files`, `/me/subscribed`, `/me/ratings`, `/me/collections`, `/me/followers`, `/me/users/muted`, `/me/following/collections`, wallet/purchased reads only if meaningful in sandbox
3. **Low-risk authenticated write flows**
   - subscribe/unsubscribe, ratings, follow/mute, collection follow/unfollow, comments on sandbox-owned content if safe
4. **Authoring + maintenance flows**
   - mod create/update/delete, modfile add/update/delete, tags / metadata KVP / dependencies maintenance, media ordering where safe, guide/collection authoring on sandbox-owned content
5. **Special-token / special-platform routes**
   - S2S, monetization, entitlements, checkout, platform-gated auth routes, only if still relevant after the earlier slices and only with the correct token type / portal requirements

### Confidence rules

A slice is not “done” just because HTTP returned 200 once. We want:
- request-shape confirmation
- response normalization confirmation
- at least one real sandbox execution where practical
- focused regression tests for any bug we fix
- QA re-run after repair
- auditor signoff on the actual outcome

### Recording rules

For every endpoint family we exercise, capture:
- exact command or harness entrypoint used
- whether auth was public / bearer / service token / platform-specific
- sandbox object IDs created or reused
- HTTP outcome + normalized summary
- whether behavior is fully validated, partially validated, blocked, or deferred
- any known doc/runtime drift between `test.mod.io` behavior and the wrapped contract

## Endpoint exercise matrix

Status legend used below:
- **Already validated** = exercised successfully against the real AeroBeat `test.mod.io` sandbox in `REF-02`
- **Planned** = should be exercised in the next execution slices with current repo/harness support
- **Blocked** = cannot be meaningfully exercised yet without additional sandbox material, auth shape, or environment capability
- **Deferred** = intentionally parked until lower-risk slices are complete or until AeroBeat actually needs the route family

### Slice A — public reads

| Endpoint family | Wrapped surface | Status | Auth / material prerequisites | Notes |
| --- | --- | --- | --- | --- |
| Service liveness | `GET /ping` | **Already validated** | Public `api_key`; no bearer token | Proven green in sandbox harness. Keep as the first smoke check before every larger sweep. |
| Game catalog/detail baseline | `GET /games`, `GET /games/{game-id}` | `GET /games/{game-id}` **Already validated**; `GET /games` **Planned** | Public `api_key`; known sandbox `game_id` | Game detail normalization is now proven after the harness fix. Broad catalog browse is still worth one explicit pass, but it is lower value than owned-content flows. |
| Game stats/taxonomy | `GET /games/{game-id}/stats`, `GET /games/{game-id}/tags`, `GET /games/{game-id}/guides/tags` | **Planned** | Public `api_key`; existing game data | Good low-risk coverage after the baseline reads. No new content creation required. |
| Token-pack browse | `GET /games/{game-id}/monetization/token-packs` | **Deferred** | Public `api_key`; token-pack data configured in sandbox game | Public read, but monetization setup is product-specific and not needed to harden the core browse seam first. |
| Public mod listing | `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/stats` | `GET /games/{game-id}/mods` **Already validated**; stats **Planned** | Public `api_key`; at least one publicly visible mod for richer assertions | Empty-list and non-empty-list pagination behavior are now both proven for `/mods`. Stats endpoint still needs its own pass. |
| Public mod detail + child reads | `GET /games/{game-id}/mods/{mod-id}`, `GET /games/{game-id}/mods/{mod-id}/files`, `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`, `GET /games/{game-id}/mods/{mod-id}/stats`, `GET /games/{game-id}/mods/{mod-id}/dependants`, `GET /games/{game-id}/mods/{mod-id}/tags`, `GET /games/{game-id}/mods/{mod-id}/metadatakvp`, `GET /games/{game-id}/mods/{mod-id}/team` | Detail **Already validated**; remainder **Planned** | Public `api_key`; published sample mod with at least one modfile; optional extra tags/metadata/team/dependency setup for richer assertions | Public detail is proven on sample mod `16112`. Remaining child routes should be exercised against that same owned sandbox artifact. |
| Public guides read family | `GET /games/{game-id}/guides`, `GET /games/{game-id}/guides/{guide-id}`, `GET /games/{game-id}/guides/{guide-id}/comments`, `GET /games/{game-id}/guides/{guide-id}/comments/{comment-id}` | **Blocked** | Public `api_key`; at least one sandbox guide, plus comment fixtures for nested reads | No known guide content exists yet in the sandbox. Create guide content later under authoring, then return here for public-read verification. |
| Public collections read family | `GET /games/{game-id}/collections`, `GET /games/{game-id}/collections/{collection-id}`, `GET /games/{game-id}/collections/{collection-id}/mods`, `GET /games/{game-id}/collections/{collection-id}/comments`, `GET /games/{game-id}/collections/{collection-id}/comments/{comment-id}`, `POST /games/{game-id}/collections/{collection-id}/compatibility` | Reads **Blocked**; compatibility write **Deferred** | Public `api_key`; at least one sandbox collection; comments/mod-membership data for nested reads | Same issue as guides: no sandbox collection corpus yet. Compatibility is useful later, but not before core collection create/read state exists. |
| Public mod comments read family | `GET /games/{game-id}/mods/{mod-id}/comments`, `GET /games/{game-id}/mods/{mod-id}/comments/{comment-id}` | **Blocked** | Public `api_key`; at least one public comment on an owned/public mod | Needs seeded comment data before it is meaningful. |

### Slice B — authenticated reads

| Endpoint family | Wrapped surface | Status | Auth / material prerequisites | Notes |
| --- | --- | --- | --- | --- |
| Authenticated identity baseline | `GET /me` | **Already validated** | Real sandbox user bearer token in ignored session config | This is the first authenticated smoke test and is already proven with email-exchanged sandbox bearer auth. |
| User-owned inventory reads | `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/subscribed`, `GET /me/ratings`, `GET /me/collections`, `GET /me/following/collections` | `/me/mods` **Already validated**; remainder **Planned** | Bearer token; owned/related artifacts (published mod, optional subscriptions/ratings/collections) | `/me/mods` is implicitly proven from the non-public/public sample-mod work. The rest should be exercised next because they stay in the same auth lane and use objects we can create ourselves. |
| User social/account-state reads | `GET /me/followers`, `GET /me/users/muted`, `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections` | **Planned** | Bearer token for `/me/*`; additional second user helpful for non-empty social assertions | Can run with empty-state assertions first, then enrich later if a second sandbox user is practical. |
| Wallet/purchase/entitlement-adjacent reads | `GET /me/wallets`, `GET /me/purchased`, `POST /me/entitlements` | **Deferred** | Bearer token; portal/platform headers and monetization setup depending on route | These are real wrapper surface, but they are not the fastest path to provider-seam confidence and may depend on store/portal setup. |
| Owned mod monetization-team read | `GET /games/{game-id}/mods/{mod-id}/monetization/team` | **Deferred** | Bearer token; owned mod; monetization-enabled sandbox configuration | Keep after core owned-content CRUD unless AeroBeat immediately needs rev-share flows. |
| Auth terms/agreement reads | `GET /authenticate/terms`, `GET /agreements/types/{agreement-type-id}/current`, `GET /agreements/versions/{agreement-version-id}` | **Planned** | Public or bearer-capable calls depending on route usage; known agreement type/version ids from first response | Low risk and valuable for auth-shape coverage, but still lower priority than `/me` plus inventory reads. |

### Slice C — low-risk writes

| Endpoint family | Wrapped surface | Status | Auth / material prerequisites | Notes |
| --- | --- | --- | --- | --- |
| Session/logout hygiene | `POST /oauth/logout` | **Planned** | Bearer token that can be safely invalidated/replaced | Best run at the tail of an auth session or with a disposable token so it does not interrupt the broader sweep. |
| Subscriptions | `POST /games/{game-id}/mods/{mod-id}/subscribe`, `DELETE /games/{game-id}/mods/{mod-id}/subscribe`, `POST /games/{game-id}/collections/{collection-id}/subscriptions`, `DELETE /games/{game-id}/collections/{collection-id}/subscriptions` | Mod subscribe/unsubscribe **Planned**; collection subscription **Blocked** | Bearer token; public mod for mod subscriptions; collection object for collection subscriptions | Mod subscription is the best next write because the sample published mod already exists. Collection subscription waits on collection creation. |
| Ratings + report | `GET /me/ratings`, `POST /games/{game-id}/mods/{mod-id}/ratings`, `POST /report` | **Planned** | Bearer token; public mod; safe test report target and clear moderation-safe reason text | Ratings are reversible/low-risk. Reporting should stay minimal and intentional so we do not spam moderation surfaces. |
| User social mutations | `POST /users/{user-id}/following`, `DELETE /users/{user-id}/following/{target-user-id}`, `POST /users/{user-id}/mute`, `DELETE /users/{user-id}/mute`, `POST /games/{game-id}/collections/{collection-id}/followers`, `DELETE /games/{game-id}/collections/{collection-id}/followers` | User follow/mute **Planned**; collection follow/unfollow **Blocked** | Bearer token; second sandbox user for meaningful follow/mute; collection object for collection follow | Empty/negative-path validation is possible, but real confidence wants a second sandbox user. |
| Comment authoring on owned content | `POST`/`PUT`/`DELETE`/karma on mod, guide, collection comments | Mod comments **Planned**; guide/collection comments **Blocked** | Bearer token; owned/public mod for mod comments; guide/collection objects for the others | Mod comments are a good bridge from low-risk writes into later public-read verification. |

### Slice D — authoring and maintenance

| Endpoint family | Wrapped surface | Status | Auth / material prerequisites | Notes |
| --- | --- | --- | --- | --- |
| Mod authoring CRUD | `POST /games/{game-id}/mods`, `POST /games/{game-id}/mods/{mod-id}`, `DELETE /games/{game-id}/mods/{mod-id}` | **Already validated** | Bearer token; valid logo asset; safe disposable mod naming/material | Disposable sandbox mods were created, updated, verified through authenticated `/me/mods` readback, and deleted cleanly in Task 8. |
| Modfile CRUD | `POST /games/{game-id}/mods/{mod-id}/files`, `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}`, `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` | **Already validated** | Bearer token; owned mod; disposable zip payload | Task 8 proved add + update + delete by replacing a first uploaded file with a second live file, then deleting the older file successfully before final mod cleanup. |
| Mod maintenance metadata | `POST`/`DELETE` tags, metadata KVP, dependencies; `GET` related readbacks | **Partially validated** | Bearer token; owned mod; optional second dependency mod for dependency flows | Earlier low-risk sweep already showed tag writes are sandbox-gated for this workout and metadata KVP add/read/delete succeeds. Task 8 additionally showed dependency add is currently blocked by sandbox game policy (`403`, error ref `15077`) even with a second disposable mod available, while cleanup delete remains a safe no-op. |
| Mod media/order maintenance | `POST /games/{game-id}/mods/{mod-id}/media`, `PUT /games/{game-id}/mods/{mod-id}/media/reorder`, `DELETE /games/{game-id}/mods/{mod-id}/media` | **Already validated** | Bearer token; owned mod; disposable image assets | Task 8 proved media add, follow-up add for a second server-side filename, reorder, and delete on a disposable owned mod, with final cleanup confirmed by mod deletion. |
| Mod team / monetization-team writes | `POST /games/{game-id}/mods/{mod-id}/monetization/team` | **Deferred** | Bearer token; owned mod; extra collaborator accounts and monetization-enabled sandbox | Too setup-heavy for the core hardening pass. |
| Guide authoring CRUD | `POST /games/{game-id}/guides`, `POST /games/{game-id}/guides/{guide-id}`, `DELETE /games/{game-id}/guides/{guide-id}` | **Planned** | Bearer token; owned/public mod context if guide content references mods; simple guide payload | This is the unlock step for guide public reads/comments. |
| Collection authoring CRUD | `POST /games/{game-id}/collections`, `POST /games/{game-id}/collections/{collection-id}`, `DELETE /games/{game-id}/collections/{collection-id}`, `DELETE /games/{game-id}/collections/{collection-id}/mods` | **Planned** | Bearer token; public/owned mods to place into collections; optional permanent-delete reason handling | This is the unlock step for collection reads, follows, and subscriptions. |

### Slice E — special-token / special-platform routes

| Endpoint family | Wrapped surface | Status | Auth / material prerequisites | Notes |
| --- | --- | --- | --- | --- |
| Email auth flow | `POST /oauth/emailrequest`, `POST /oauth/emailexchange` | **Already validated operationally** | Public `api_key`; reachable inbox for the test account; human-supplied security code | This is already the proven dev-token acquisition path for sandbox bearer auth, even though it is not part of the safe harness itself. |
| External/platform/OpenID auth | `POST /external/appleauth`, `discordauth`, `epicgamesauth`, `galaxyauth`, `googleauth`, `oculusauth`, `openidauth`, `psnauth`, `steamauth`, `switchauth`, `udtauth`, `xboxauth` | **Deferred** | Real upstream platform/OpenID credentials and often platform-specific test setup | Production-relevant, but not economical for the current hardening pass. Treat as later parity work. |
| Checkout + token packs + purchased monetization | `POST /games/{game-id}/mods/{mod-id}/checkout`, `GET /games/{game-id}/monetization/token-packs`, `GET /me/purchased` | **Deferred** | Bearer token; monetization-enabled sandbox data; portal/platform headers as required | Defer until AeroBeat actually needs purchase flow validation. |
| S2S monetization/transactions | `POST /s2s/transactions/intent`, `commit`, `clawback`; `DELETE /s2s/connections/{portal-id}`; `GET /s2s/monetization-teams/.../transactions...` | **Deferred** | Secure backend-held service token; portal/team IDs; server-side execution lane | Explicitly outside the game-client bearer harness lane. Needs separate backend-safe validation. |
| Platform/portal entitlement sync | `POST /me/entitlements` and other platform-gated monetization paths | **Deferred** | Bearer token plus required `X-Modio-Portal` / optional `X-Modio-Platform` headers and platform receipts/IDs | Useful later, but not for the first vendor seam confidence threshold. |

## Recommended execution order update

Refine the original sweep order to match what is now already proven in `REF-02`:

1. **Treat the validated baseline as done, not pending:** `GET /ping`, `GET /games/{game-id}`, `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/{mod-id}`, `GET /me`, and owner `GET /me/mods` are already proven on the real sandbox.
2. **Next: finish the owned-mod readback cluster** on the published sample mod (`files`, file detail, stats, tags, metadata KVP, team, dependants), because it reuses existing safe sandbox artifacts and should expose wrapper issues faster than creating brand-new route families.
3. **Then run low-risk owner writes on that same mod** (`subscribe`, `rating`, mod comments, tag/metadata/dependency maintenance) so every write can be verified immediately through the already-proven read paths.
4. **Then formalize disposable authoring cleanup passes** for mod delete and modfile update/delete, since create/update/upload have already been implicitly proven during sandbox setup work.
5. **Only after that, branch into guides and collections**: first create owned guide/collection content, then verify their public reads/comments/follows/subscriptions.
6. **Leave monetization, checkout, entitlements, S2S, and platform-auth routes deferred** unless AeroBeat’s immediate product plan forces them forward.

This ordering change keeps the next coder/QA/auditor loops on one owned sandbox artifact as long as possible, minimizes new setup churn, and converts earlier “baseline” tasks into acknowledged completed evidence instead of redoing them blindly.

---

## Tasks

### Task 1: Build the endpoint exercise matrix and execution backlog

**Bead ID:** `oc-q4q`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Build a concrete endpoint exercise matrix from the currently wrapped surface in `README.md`, grouped into execution slices for public reads, authenticated reads, low-risk writes, authoring/maintenance, and special-token routes. Mark each endpoint as planned/blocked/deferred and note the auth/material prerequisites for each family. Update this master plan with the exact matrix and recommended execution order, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`

**Status:** ✅ Complete

**Results:** Built and inserted a concrete endpoint exercise matrix derived from the wrapped README surface and reconciled it with the real sandbox evidence already captured in `REF-02`. The matrix now groups the surface into public reads, authenticated reads, low-risk writes, authoring/maintenance, and special-token/platform routes; marks each endpoint family as already validated, planned, blocked, or deferred; records the auth/material prerequisites for each family; and recommends a tighter execution order that starts from the already-proven baseline instead of redoing it blindly. Key execution-order change: treat the existing `/ping`, game detail, public mod list/detail, `/me`, and owner `/me/mods` validation as completed baseline evidence, then concentrate next passes on owned-mod child reads and reversible writes before branching into guides/collections or monetization/S2S work.

---

### Task 2: Implement and validate the public-read sweep

**Bead ID:** `oc-zqu`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Exercise the planned public-read endpoint family against the test sandbox, using existing sample sandbox content where available and creating only minimum safe sandbox content if required. Fix any provider-seam bugs you find, add focused regression tests, rerun validation, update this plan with exact evidence/results, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/` local runtime artifacts only as needed
- `src/` / tests as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- `.testbed/modio_live_harness.gd`
- `.testbed/modio_live_harness_lib.gd`
- `.testbed/tests/test_modio_live_harness.gd`

**Status:** ✅ Complete

**Results:** Extended the safe headless harness so the public-read sweep now automatically drills into the first public sandbox mod returned by `GET /games/{game-id}/mods` and exercises the owned sample-mod child-read cluster without any write behavior: `GET /games/{game-id}/mods/{mod-id}`, `GET /games/{game-id}/mods/{mod-id}/files`, derived first-file `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`, `GET /games/{game-id}/mods/{mod-id}/stats`, `GET /games/{game-id}/mods/{mod-id}/dependants`, `GET /games/{game-id}/mods/{mod-id}/tags`, `GET /games/{game-id}/mods/{mod-id}/metadatakvp`, `GET /games/{game-id}/mods/{mod-id}/team`, and adjacent low-risk `GET /games/{game-id}/mods/{mod-id}/dependencies`.

Code/test changes:
- updated `.testbed/modio_live_harness.gd` to auto-run the child-read sweep when the public mod listing yields at least one mod and to skip truthfully when no public mod/file exists
- expanded `.testbed/modio_live_harness_lib.gd` with normalized summary helpers for mod detail, file list/detail, stats, dependants, tags, metadata KVP, team, dependencies, and the parent listing’s selected mod id
- added focused fixture-driven regression coverage in `.testbed/tests/test_modio_live_harness.gd` for the new summaries and the selected mod/file id extraction path

Local validation evidence:
```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Observed result: scaffold validation passed and the full fixture-driven suite passed at `90/90` tests.

Real sandbox validation evidence on the existing sample mod from `REF-02`:
```bash
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --public-only --json
```
Observed `test.mod.io` results against `https://g-1325.test.mod.io/v1`:
- `mods` selected public sample mod `16112` (`oc-4wr sandbox pagination sample 1778082871`)
- `mod_detail` returned HTTP `200` with `id=16112`, `status=1`, `visible=1`
- `mod_files` returned HTTP `200` with one file and normalized `selected_file_id=22687`
- `mod_file_detail` returned HTTP `200` with `id=22687`, `filename="tmp-oc-4wr-build-5by3.zip"`, `version="0.0.1"`, `filesize=198`
- `mod_dependants` returned HTTP `200` with an empty list (`result_total=0`)
- `mod_tags` returned HTTP `200` with an empty list (`result_total=0`, server echo `result_limit=100`)
- `mod_metadata_kvp` returned HTTP `200` with an empty list (`result_total=0`)
- `mod_team` returned HTTP `200` with one visible team member and normalized `usernames=["DerrickBarra"]`
- `mod_dependencies` returned HTTP `200` with an empty list (`result_total=0`, server echo `result_limit=100`)

Additional targeted probe for stats:
```bash
godot --headless --path .testbed --script /tmp/modio_oc_zqu_stats_probe.gd
```
Observed result: `GET /games/1325/mods/16112/stats` returned HTTP `200`, but the raw payload itself already contained zeroed counters and `mod_id = 0`; the adapter normalization matched that raw shape exactly. So there was **no adapter seam bug to fix** for stats in this slice — the current caveat is a sandbox-side response/data characteristic for this newly created sample mod, not a client-side parsing failure.

Net outcome for this coder slice: the owned sample-mod child-read cluster is now reproducible through the repo’s safe harness, file-detail selection uses normalized integer ids instead of raw float-ish JSON ids, the target public endpoints above are exercised successfully on the real AeroBeat test sandbox, and the remaining oddities are documented as current `test.mod.io` response behavior rather than wrapper breakage.

---

### Task 3: QA and audit the public-read sweep

**Bead ID:** `oc-zis`  
**SubAgent:** `primary`  
**Role:** `qa` then `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the public-read sweep, rerun the relevant harness/tests/probes, confirm endpoint outcomes and request shaping, make only minimum necessary QA fixes if required, then perform an independent audit against the plan and close only when the slice is actually done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- code/tests only if minimum fix is needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- code/tests only if needed

**Status:** ✅ Complete

**Results:** QA independently reran the public-read sweep on the real AeroBeat `test.mod.io` sandbox and audited the coder slice against the current harness/test code. No QA code fix was required.

Independent validation evidence:
```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --public-only --json
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json
godot --headless --path .testbed --script /tmp/modio_oc_zis_probe.gd
```

Observed results:
- scaffold validation passed
- full fixture-driven suite passed at `90/90` tests
- public harness run stayed green and exercised the owned sample-mod child-read cluster from the first listed public sandbox mod `16112`
- authenticated harness run also stayed green and preserved the already-validated `/me` identity fields (`id = 71104`, `name_id = "derrickbarra"`, `username = "DerrickBarra"`)

Confirmed public endpoint outcomes from the harness:
- `GET /games/1325/mods?_limit=3&_offset=0` -> HTTP `200`, selected mod `16112`, `response_result_limit = 3`, `response_result_total = 1`
- `GET /games/1325/mods/16112` -> HTTP `200`, `status = 1`, `visible = 1`
- `GET /games/1325/mods/16112/files?_limit=5&_offset=0` -> HTTP `200`, selected file `22687`, `response_result_limit = 5`, `response_result_total = 1`
- `GET /games/1325/mods/16112/files/22687` -> HTTP `200`, `filename = "tmp-oc-4wr-build-5by3.zip"`, `version = "0.0.1"`, `filesize = 198`
- `GET /games/1325/mods/16112/stats` -> HTTP `200`, but the raw payload still reports zeroed counters and `mod_id = 0`; QA confirmed that this is coming from the sandbox payload itself rather than from harness/adapter normalization drift
- `GET /games/1325/mods/16112/dependants?_limit=5&_offset=0` -> HTTP `200`, empty list
- `GET /games/1325/mods/16112/tags?_limit=5&_offset=0` -> HTTP `200`, empty list, server echo `response_result_limit = 100`
- `GET /games/1325/mods/16112/metadatakvp?_limit=5&_offset=0` -> HTTP `200`, empty list
- `GET /games/1325/mods/16112/team?_limit=5&_offset=0` -> HTTP `200`, one visible member, normalized `usernames = ["DerrickBarra"]`
- `GET /games/1325/mods/16112/dependencies?recursive=false` -> HTTP `200`, empty list, `recursive_requested = false`

Independent request-shape truth check from the direct transport probe (`/tmp/modio_oc_zis_probe.gd`):
- `/games/1325/mods` prepared with `_limit = "3"`, `_offset = "0"`, `api_key`
- `/games/1325/mods/16112/files` prepared with `_limit = "5"`, `_offset = "0"`, `api_key`
- `/games/1325/mods/16112/tags` prepared with `_limit = "5"`, `_offset = "0"`, `api_key`
- `/games/1325/mods/16112/team` prepared with `_limit = "5"`, `_offset = "0"`, `api_key`
- `/games/1325/mods/16112/dependencies` prepared with `recursive=false` plus `api_key`

QA/audit conclusion: this slice is actually done. The safe harness reproducibly covers the public-read sweep and the owned sample-mod child-read cluster on `test.mod.io`, the request shaping matches the intended browse/child-read flow, file/detail id extraction is stable, and the remaining oddities (`mod_stats.mod_id = 0`, some empty-list `result_limit = 100` echoes) are current sandbox response characteristics rather than provider-seam bugs in this repo.

---

### Task 4: Implement and validate the authenticated user-read sweep

**Bead ID:** `oc-e0j`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Exercise the authenticated bearer-token user-read surface against the test sandbox, starting with `/me`-adjacent endpoints and expanding through user inventory/profile/social reads that are relevant and meaningful in the sandbox. Fix any provider-seam bugs you find, add focused regression tests, rerun validation, update this plan with exact evidence/results, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/` local runtime artifacts only as needed
- `src/` / tests as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- `.testbed/modio_live_harness.gd`
- `.testbed/modio_live_harness_lib.gd`
- `.testbed/tests/test_modio_live_harness.gd`
- `README.md`

**Status:** ✅ Complete

**Results:** Extended the safe headless harness so the authenticated bearer-token user-read slice is now repeatable instead of living only in one-off manual probing. The harness now always includes `GET /authenticate/terms`, and when a sandbox `access_token` is present it drills through `GET /me`, `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/subscribed`, `GET /me/ratings`, `GET /me/collections`, `GET /me/following/collections`, `GET /me/followers`, `GET /me/users/muted`, plus derived `GET /users/{me-id}/followers`, `GET /users/{me-id}/following`, and `GET /users/{me-id}/collections`. I also added fixture-driven regression coverage for the new summary helpers and updated the README harness docs to match the broader safe sweep.

Code/test/doc changes in this coder pass:
- updated `.testbed/modio_live_harness.gd` to run the public auth-terms check and the authenticated user-read sweep automatically after `/me` succeeds
- expanded `.testbed/modio_live_harness_lib.gd` with summary helpers for terms, user games/mods/files/subscriptions/ratings/collections/followed collections, and user/social list responses
- added focused fixture-backed regression assertions in `.testbed/tests/test_modio_live_harness.gd` for the new authenticated summaries
- refreshed `README.md` so the documented safe harness behavior matches the real non-destructive sweep

Validation evidence:
```bash
godot --headless --path .testbed -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_modio_live_harness.gd -gexit
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json
```

Observed authenticated sandbox results on `https://g-1325.test.mod.io/v1`:
- `GET /authenticate/terms` -> HTTP `200`; required links included `privacy` and `terms`
- `GET /me` -> HTTP `200`; normalized identity stayed `id = 71104`, `name_id = "derrickbarra"`, `username = "DerrickBarra"`
- `GET /me/games` -> HTTP `200`; `result_total = 1`; first game `1325 / "AeroBeat"`
- `GET /me/mods` -> HTTP `200`; `result_total = 1`; first mod `16112 / "oc-4wr sandbox pagination sample 1778082871"`
- `GET /me/files` -> HTTP `200`; `result_total = 1`; first file `22687 / "tmp-oc-4wr-build-5by3.zip" / version "0.0.1"`
- `GET /me/subscribed` -> HTTP `200`; empty list
- `GET /me/ratings` -> HTTP `200`; empty list
- `GET /me/collections` -> HTTP `200`; empty list
- `GET /me/following/collections` -> HTTP `200`; empty list
- `GET /me/followers` -> HTTP `200`; empty list
- `GET /me/users/muted` -> HTTP `200`; empty list
- `GET /users/71104/followers` -> HTTP `200`; empty list
- `GET /users/71104/following` -> HTTP `200`; empty list
- `GET /users/71104/collections` -> HTTP `200`; empty list

Request-shape notes from the direct probe and harness output:
- every authenticated list read prepared bearer-authenticated requests with `_limit = "5"` and `_offset = "0"`
- `GET /me/ratings` also carried the adapter defaults `resource_type = "mods"` and `game_id = "1325"`
- the empty social/collection lists echoed `response_result_limit = 100` from the sandbox even though the request asked for `5`; this matches the earlier empty-list quirk seen elsewhere and is a provider response characteristic, not a repo-side shaping bug
- the test-sandbox `GET /authenticate/terms` payload exposes buttons/links but not agreement type/version ids, so I stopped agreement automation at terms coverage instead of inventing brittle lookup logic

Net outcome for this coder slice: the authenticated user-read baseline is now proven and scripted on the real AeroBeat test sandbox, no provider-seam code bug was uncovered in this slice, and the repo has repeatable harness + regression coverage for future QA/audit passes.

---

### Task 5: QA and audit the authenticated user-read sweep

**Bead ID:** `oc-5p7`  
**SubAgent:** `primary`  
**Role:** `qa` then `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the authenticated user-read sweep, rerun the relevant harness/tests/probes, confirm endpoint outcomes and request shaping, make only minimum necessary QA fixes if required, then perform an independent audit against the plan and close only when the slice is actually done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- code/tests only if minimum fix is needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- code/tests only if needed

**Status:** ✅ Complete

**Results:** QA independently reran the authenticated user-read sweep on the real AeroBeat `test.mod.io` sandbox and audited the coder slice against the current harness, adapter tests, and direct prepared-request truth checks. No QA code fix was required.

Independent validation evidence:
```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --json
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --public-only --json
godot --headless --path .testbed --script /tmp/modio_oc_e0j_probe.gd
godot --headless --path .testbed --script /tmp/modio_oc_5p7_probe.gd
```

Observed results:
- scaffold validation passed
- full fixture-driven suite passed at `91/91` tests
- authenticated harness run stayed green and preserved the previously validated public baseline while also keeping the bearer-authenticated user-read slice green end-to-end
- public-only harness run still stayed green and truthfully skipped the auth-only checks under `--public-only`
- direct raw-payload probe (`/tmp/modio_oc_e0j_probe.gd`) confirmed the sandbox response bodies backing the harness summaries
- direct prepared-request probe (`/tmp/modio_oc_5p7_probe.gd`) confirmed the intended auth modes, paths, and query shaping before transport execution

Confirmed authenticated endpoint outcomes from the harness / direct payload probe:
- `GET /authenticate/terms` -> HTTP `200`; required links included `privacy` and `terms`; buttons included `agree` and `disagree`
- `GET /me` -> HTTP `200`; normalized identity stayed `id = 71104`, `name_id = "derrickbarra"`, `username = "DerrickBarra"`
- `GET /me/games?_limit=5&_offset=0` -> HTTP `200`; `result_total = 1`; first game `1325 / "AeroBeat" / "aerobeat"`
- `GET /me/mods?_limit=5&_offset=0` -> HTTP `200`; `result_total = 1`; first mod `16112 / "oc-4wr sandbox pagination sample 1778082871"`
- `GET /me/files?_limit=5&_offset=0` -> HTTP `200`; `result_total = 1`; first file `22687 / "tmp-oc-4wr-build-5by3.zip" / version "0.0.1"`
- `GET /me/subscribed?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 5`
- `GET /me/ratings?_limit=5&_offset=0&game_id=1325&resource_type=mods` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /me/collections?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /me/following/collections?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /me/followers?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /me/users/muted?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /users/71104/followers?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /users/71104/following?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`
- `GET /users/71104/collections?_limit=5&_offset=0` -> HTTP `200`; empty list with server echo `result_limit = 100`

Independent request-shape truth check from the prepared-request probe (`/tmp/modio_oc_5p7_probe.gd`):
- `GET /authenticate/terms` prepared as `auth_mode = api_key_query` with `api_key` in query
- `GET /me/games` prepared as `auth_mode = bearer` with `_limit = "5"`, `_offset = "0"`
- `GET /me/mods` prepared as `auth_mode = bearer` with `_limit = "5"`, `_offset = "0"`
- `GET /me/files` prepared as `auth_mode = bearer` with `_limit = "5"`, `_offset = "0"`
- `GET /me/subscribed` prepared as `auth_mode = bearer` with `_limit = "5"`, `_offset = "0"`
- `GET /me/ratings` prepared as `auth_mode = bearer` with `_limit = "5"`, `_offset = "0"`, `game_id = "1325"`, `resource_type = "mods"`
- `GET /me/collections`, `GET /me/following/collections`, `GET /me/followers`, and `GET /me/users/muted` all prepared as bearer-authenticated requests with `_limit = "5"`, `_offset = "0"`
- `GET /users/71104/followers`, `GET /users/71104/following`, and `GET /users/71104/collections` prepared as public/api-key-fallback reads with `_limit = "5"`, `_offset = "0"`

QA/audit conclusion: this slice is actually done. The safe harness reproducibly covers the authenticated user-read baseline on `test.mod.io`, the direct payload probe matches the harness summaries, and the prepared-request truth check confirms the intended auth split and query shaping. The only remaining oddity is the now-familiar sandbox behavior where several empty authenticated list endpoints echo `result_limit = 100` despite a requested `_limit = 5`; QA confirmed that as a provider response characteristic rather than a repo-side request-shaping bug.

---

### Task 6: Implement and validate the low-risk authenticated write sweep

**Bead ID:** `oc-vrf`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Exercise the low-risk authenticated write endpoints that are safe to use in the test sandbox, such as subscriptions, ratings, comments on sandbox-owned content, and simple social/account-state writes where supported. Keep changes minimal and reversible, fix any provider-seam bugs you find, add focused regression tests, rerun validation, update this plan with exact evidence/results, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- `.testbed/modio_live_harness.gd`
- `.testbed/modio_live_harness_lib.gd`
- `.testbed/tests/test_modio_live_harness.gd`

**Status:** ✅ Complete

**Results:** Extended the headless sandbox harness with an explicit `--allow-writes` opt-in so the low-risk authenticated write slice is repeatable instead of depending on ad-hoc one-off probes. The harness now executes and summarizes a constrained write sweep on the owned sample mod `16112` after the existing public/authenticated read baseline, while keeping write behavior off by default. I also added fixture-driven regression coverage for the new write-summary helpers and CLI flag handling.

Exact coder validation run on the real AeroBeat test sandbox:

- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` -> `92/92` passing.
- `godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --allow-writes --json` -> overall `ok: true` on `https://g-1325.test.mod.io/v1`.

Observed low-risk write evidence from that final green sandbox run:

- **Subscribe / unsubscribe** on owned sample mod `16112` succeeded end-to-end.
  - `POST /games/1325/mods/16112/subscribe` -> HTTP `201`.
  - Immediate `GET /me/subscribed` readback showed `found_expected_mod_id = true` for mod `16112`.
  - `DELETE /games/1325/mods/16112/subscribe` -> HTTP `204`.
  - Immediate `GET /me/subscribed` readback showed `found_expected_mod_id = false`.
- **Ratings** are now verified and idempotently tolerated in the sandbox.
  - Earlier in this slice, a positive rating was successfully applied and read back on mod `16112`.
  - Final rerun hit the expected provider conflict for re-applying the same positive rating, so the harness now treats that state as a skip rather than a failure when the follow-up `GET /me/ratings` confirms `found_expected_rating = true`, `first_mod_id = 16112`, `first_rating = 1`.
- **Comment CRUD** is not available on this sandbox workout.
  - `POST /games/1325/mods/16112/comments` returned HTTP `403` with provider error ref `14038` (`Comments have been disabled for this workout.`).
  - The harness now records this as an explicit capability-gated skip instead of leaving the overall sweep red.
- **Tag maintenance** is not currently writable in this sandbox configuration.
  - `POST /games/1325/mods/16112/tags` with an ephemeral `oc-vrf-tag-*` value returned HTTP `422` with provider error ref `13009` (`Validation Failed...`).
  - The harness now records freeform tag maintenance as an explicit skip for this workout instead of treating it as a wrapper failure.
- **Metadata KVP maintenance** succeeded end-to-end and stayed reversible.
  - `POST /games/1325/mods/16112/metadatakvp` created ephemeral metadata for the run and returned HTTP `201`.
  - Immediate `GET /games/1325/mods/16112/metadatakvp` readback showed `found_expected_pair = true` (final run pair: `oc-vrf=1778089259.75088`).
  - `DELETE /games/1325/mods/16112/metadatakvp` returned HTTP `204`.
  - Immediate readback showed `found_expected_pair = false` and an empty metadata list.
- **Dependencies** remain intentionally unexercised in this slice because the sandbox currently exposes only one safe owned mod, so there is no second reversible dependency target yet.

No provider-seam bug was found in the wrapped request/transport layer during this slice. The meaningful changes here were harness hardening and capability-aware skip handling so real sandbox limitations (comment-disabled workout, tag validation gate, already-existing positive rating) no longer masquerade as client-side failures.

---

### Task 7: QA and audit the low-risk authenticated write sweep

**Bead ID:** `oc-rz1`  
**SubAgent:** `primary`  
**Role:** `qa` then `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the low-risk authenticated write sweep, rerun the relevant harness/tests/probes, confirm endpoint outcomes and post-write state, make only minimum necessary QA fixes if required, then perform an independent audit against the plan and close only when the slice is actually done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- code/tests only if minimum fix is needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- code/tests only if needed

**Status:** ✅ Complete

**Results:** QA independently reran the low-risk authenticated write sweep on the real AeroBeat `test.mod.io` sandbox and audited the coder slice against the current harness and regression coverage. No QA code fix was required.

Independent validation evidence:
```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --headless --path .testbed --script res://modio_live_harness.gd -- --env test --allow-writes --json
```

Observed results:
- scaffold validation passed
- full fixture-driven suite passed at `92/92` tests
- the full safe harness run with `--allow-writes` stayed green overall (`ok: true`) while preserving the already-validated public and authenticated read baseline before executing the reversible write checks

Confirmed low-risk write outcomes and post-write readback state from the harness:
- **Subscribe / unsubscribe** on owned sample mod `16112` verified end-to-end again.
  - `POST /games/1325/mods/16112/subscribe` -> HTTP `201`
  - immediate `GET /me/subscribed` readback -> HTTP `200`, `found_expected_mod_id = true`, `selected_mod_id = 16112`, `response_result_total = 1`
  - `DELETE /games/1325/mods/16112/subscribe` -> HTTP `204`
  - immediate `GET /me/subscribed` readback -> HTTP `200`, `found_expected_mod_id = false`, `response_result_total = 0`
- **Ratings** remain confirmed without needing a destructive reset.
  - `POST /games/1325/mods/16112/ratings` was skipped by the hardened harness because the sandbox already holds the same positive rating for this workout
  - follow-up `GET /me/ratings` -> HTTP `200`, `found_expected_rating = true`, `first_mod_id = 16112`, `first_rating = 1`, `response_result_total = 1`
  - QA agrees this is the correct idempotent interpretation for the current sandbox state rather than a repo-side failure
- **Comment CRUD** remains explicitly capability-gated by the sandbox.
  - create/update/delete comment checks stayed skipped because this workout has comments disabled
  - QA agrees these should remain documented skips, not failures, until the sandbox capability changes
- **Tag maintenance** remains explicitly capability-gated by the sandbox.
  - add/delete tag checks stayed skipped because the sandbox rejects these freeform tag writes for this workout
  - QA found no evidence of a wrapper request/normalization bug here
- **Metadata KVP maintenance** verified end-to-end again and stayed reversible.
  - `POST /games/1325/mods/16112/metadatakvp` -> HTTP `201`
  - immediate readback -> HTTP `200`, `found_expected_pair = true`, `pairs = ["oc-vrf=1778089492.50065"]`, `response_result_total = 1`
  - `DELETE /games/1325/mods/16112/metadatakvp` -> HTTP `204`
  - immediate readback -> HTTP `200`, `found_expected_pair = false`, `pairs = []`, `response_result_total = 0`
- **Dependencies** stayed intentionally skipped because the sandbox still exposes only one safe owned mod, so there is no second reversible dependency target yet.

QA/audit conclusion: this slice is actually done. The low-risk authenticated write sweep is reproducible through the repo’s opt-in safe harness, the meaningful reversible writes (`subscribe`/`unsubscribe` and metadata KVP add/read/delete) succeed with correct readback state on `test.mod.io`, rating presence is confirmed through idempotent readback, and the remaining skips are current sandbox capability constraints rather than provider-seam bugs in this repo.

---

### Task 8: Implement and validate the authoring/maintenance sweep

**Bead ID:** `oc-1sb`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Exercise mod authoring and maintenance endpoints in the sandbox, including create/update/delete and related modfile / tags / metadata / dependency / media flows as appropriate. Keep artifact creation intentional, document all created IDs, clean up where practical, fix any provider-seam bugs you find, add focused regression tests, rerun validation, update this plan with exact evidence/results, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/` local runtime artifacts only as needed
- `src/` / tests as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- `src/network/modio_http_transport.gd`
- `.testbed/tests/test_modio_http_transport.gd`

**Status:** ✅ Complete

**Results:** Identified and fixed a real transport-layer provider-seam bug before rerunning the sandbox sweep: multipart requests with binary bodies were being prepared as bytes but still dispatched through `HTTPClient.request(...)` using a UTF-8 string body, which broke real binary multipart writes on `test.mod.io`. The fix now routes multipart requests through `HTTPClient.request_raw(...)`, and focused regression coverage was added in `.testbed/tests/test_modio_http_transport.gd` to assert that prepared binary multipart requests prefer the raw-byte dispatch path. Full local validation then passed at `93/93` tests.

Exact coder validation steps:

- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- one-off sandbox probe using the repo adapter/transport against `https://g-1325.test.mod.io/v1` with disposable local assets under `.testbed/tmp-oc-1sb/`

Observed real sandbox authoring/maintenance evidence from the final green probe run:

- **Disposable mod authoring CRUD succeeded end-to-end.**
  - created primary mod `16117` and secondary dependency-target mod `16118` via `POST /games/1325/mods` -> HTTP `201`
  - updated primary mod `16117` via `POST /games/1325/mods/16117` -> HTTP `200`
  - authenticated owner readback via `GET /me/mods?id=16117&game_id=1325` -> HTTP `200`, `result_total = 1`, `name = "oc-1sb primary 1778090378.18966 updated"`, `summary = "Updated summary for oc-1sb primary mod"`
  - deleted both disposable mods via `DELETE /games/1325/mods/16117` and `DELETE /games/1325/mods/16118` -> HTTP `204`
- **Modfile lifecycle coverage is now explicit, not implicit.**
  - added primary modfile `22693` on mod `16117` -> HTTP `201`
  - updated modfile `22693` via `PUT /games/1325/mods/16117/files/22693` -> HTTP `200`
  - readback via `GET /games/1325/mods/16117/files/22693` -> HTTP `200`, `version = "0.0.2"`, `changelog = "updated build metadata"`, `metadata_blob = "{\"build\":\"v2\"}"`; later QA raw-payload verification found the current sandbox response does **not** include an explicit `active` field on this route, so the earlier `active = false` readback claim was stronger than the evidence supported
  - uploaded replacement live modfile `22694` -> HTTP `201`
  - deleted the no-longer-live older primary modfile `22693` -> HTTP `204`
  - dependency modfile `22695` stayed undeletable while it was the live release on disposable mod `16118`; `DELETE /games/1325/mods/16118/files/22695` returned HTTP `403`, provider error ref `15009` (`You cannot delete a modfile that is the live release for a mod.`). This is documented as sandbox/provider behavior, not a wrapper failure.
- **Dependency maintenance is meaningfully exercised and currently blocked by sandbox policy, not wrapper shape.**
  - attempted `POST /games/1325/mods/16117/dependencies` with second disposable mod `16118` -> HTTP `403`, provider error ref `15077` (`Workout can not add dependencies due to the game disallowing it.`)
  - immediate readback via `GET /games/1325/mods/16117/dependencies` -> HTTP `200`, empty list (`result_total = 0`)
  - cleanup `DELETE /games/1325/mods/16117/dependencies` with the same target id returned HTTP `200` as a safe no-op
- **Media maintenance succeeded with real server-side filename behavior.**
  - first media add on mod `16117` -> HTTP `201`
  - detail readback after first add showed one image filename: `media-2.png`
  - second media add -> HTTP `201`; follow-up detail readback showed two server-side filenames: `media-2.png`, `media-1.1.png`
  - reorder via `PUT /games/1325/mods/16117/media/reorder` -> HTTP `204`
  - delete via `DELETE /games/1325/mods/16117/media` -> HTTP `204`
- **Metadata cleanup remained safe.**
  - `DELETE /games/1325/mods/16117/metadatakvp` for the disposable `oc-1sb` key returned HTTP `200`

Net outcome for this coder slice: the repo now has a real multipart-write transport fix with regression coverage, disposable sandbox authoring/update/delete passes are proven, modfile update/delete behavior is explicitly documented including the live-release delete constraint, media add/reorder/delete is proven on owned disposable content, and dependency maintenance has been reduced to a clearly documented sandbox game-policy block rather than an unknown wrapper gap.

---

### Task 9: QA and audit the authoring/maintenance sweep

**Bead ID:** `oc-am6`  
**SubAgent:** `primary`  
**Role:** `qa` then `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the authoring/maintenance sweep, rerun the relevant harness/tests/probes, confirm endpoint outcomes and post-write state, make only minimum necessary QA fixes if required, then perform an independent audit against the plan and close only when the slice is actually done.

**Folders Created/Deleted/Modified:**
- `.plans/`
- code/tests only if minimum fix is needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- code/tests only if needed

**Status:** ✅ Complete

**Results:** QA independently reran the authoring/maintenance slice against the real AeroBeat `test.mod.io` sandbox and then audited the coder notes against fresh local validation plus two disposable sandbox probes. No repo code fix was required; the only QA correction was to tighten the plan wording around modfile `active` readback so it matches the raw provider payload actually observed.

Independent validation evidence:
```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --headless --path .testbed --script /tmp/modio_oc_am6_probe.gd
godot --headless --path .testbed --script /tmp/modio_oc_am6_active_probe.gd
```

Observed results:
- scaffold validation passed
- full fixture-driven suite passed at `93/93` tests
- the transport seam fix is still present and covered locally: `src/network/modio_http_transport.gd` routes multipart/raw-byte writes through `HTTPClient.request_raw(...)` when `_should_use_request_raw(...)` detects a binary multipart body
- the disposable QA probe created and cleaned up two sandbox mods successfully (`16121`, `16122`) while rerunning the mod/modfile/media/dependency maintenance lifecycle end-to-end through the repo adapter/transport

Confirmed authoring/maintenance outcomes from the QA sandbox probe:
- **Mod CRUD remains green when exercised in the correct provider order.**
  - `POST /games/1325/mods` created disposable primary mod `16121` and dependency-target mod `16122` with HTTP `201`
  - `POST /games/1325/mods/16121` updated the primary mod name/summary with HTTP `200`
  - an initial QA attempt to authorize a brand-new mod before adding any build reproduced provider error `15016` (`The specified mod cannot be authorized until it has at least one build available.`); QA treats that as an additional sandbox/provider lifecycle caveat, not a wrapper failure
  - final cleanup deleted both disposable mods with HTTP `204`
- **Multipart modfile writes are now truly working end-to-end through the fixed transport path.**
  - added primary modfile `22696` on mod `16121` -> HTTP `201`
  - updated modfile `22696` via `PUT /games/1325/mods/16121/files/22696` -> HTTP `200`
  - direct detail readback via `GET /games/1325/mods/16121/files/22696` -> HTTP `200`, `version = "0.0.2"`, `changelog = "updated build metadata"`, `metadata_blob = "{\"build\":\"v2\"}"`
  - uploaded replacement live modfile `22697` -> HTTP `201`
  - deleted the older non-live primary modfile `22696` -> HTTP `204`
  - added dependency-target live modfile `22698` -> HTTP `201`
  - deleting that still-live dependency modfile reproduced HTTP `403`, provider error ref `15009` (`You cannot delete a modfile that is the live release for a mod.`)
- **Dependency maintenance remains blocked by sandbox game policy, not by request shaping.**
  - `POST /games/1325/mods/16121/dependencies` with dependency target `16122` reproduced HTTP `403`, provider error ref `15077` (`Workout can not add dependencies due to the game disallowing it.`)
  - immediate `GET /games/1325/mods/16121/dependencies?recursive=false` readback stayed HTTP `200` with `result_total = 0`
  - cleanup `DELETE /games/1325/mods/16121/dependencies` with that same target id returned HTTP `200` as a safe no-op; QA confirmed the earlier coder conclusion here, and adjusted the QA probe expectation accordingly
- **Metadata KVP maintenance stayed reversible.**
  - `POST /games/1325/mods/16121/metadatakvp` -> HTTP `201`
  - immediate readback -> HTTP `200`, `pairs = ["oc-am6=1778090959"]`, `result_total = 1`
  - `DELETE /games/1325/mods/16121/metadatakvp` -> HTTP `204`
  - immediate readback -> HTTP `200`, `pairs = []`, `result_total = 0`
- **Media maintenance stayed green with real server-side filenames.**
  - first media add -> HTTP `201`; detail readback then exposed `media_after_first_add = ["media-1.png"]`
  - second media add -> HTTP `201`; follow-up detail readback exposed `media_after_second_add = ["media-1.png", "media-2.png"]`
  - reorder via `PUT /games/1325/mods/16121/media/reorder` -> HTTP `204`
  - delete via `DELETE /games/1325/mods/16121/media` -> HTTP `204`

Focused raw-payload audit finding from `/tmp/modio_oc_am6_active_probe.gd`:
- when QA updated a disposable modfile with `active=false`, the sandbox `PUT` response and subsequent `GET /files/{file-id}` detail payload both preserved the updated `version`, `changelog`, and `metadata_blob`, but they did **not** include an explicit `active` field at all
- because of that raw provider shape, QA corrected Task 8’s wording to stop claiming a verified `active = false` readback; this is a documentation/evidence correction, not a repo transport or normalization bug

QA/audit conclusion: this slice is actually done. The multipart transport repair is independently validated locally and against the real sandbox, disposable mod/modfile/media lifecycle checks succeed end-to-end through the repo adapter/transport, and the remaining negative results (`15016`, `15009`, `15077`, dependency-delete `200` no-op) are reproducible provider-behavior caveats rather than unresolved wrapper failures.

Post-close independent audit verification pass (rerun after the transport fix landed and QA completed): I treated `oc-am6` as already closed and reran the same validation stack again on current head instead of relying only on the earlier QA note. Fresh evidence on this pass:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` passed
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` passed at `93/93`
- rerunning `/tmp/modio_oc_am6_probe.gd` created and cleaned up disposable mods `16124` and `16125`, proved multipart add/update/delete on modfiles through the live transport path again (`22700`, `22701`, `22702`), reproduced dependency add `403 / 15077`, reproduced live-release modfile delete `403 / 15009`, and reproduced dependency delete as HTTP `200` safe no-op
- rerunning `/tmp/modio_oc_am6_active_probe.gd` created disposable mod `16126` with modfile `22703` and again confirmed that the provider preserves updated `version`, `changelog`, and `metadata_blob` but still does **not** surface an explicit `active` field in either the update response or later file detail readback

Additional audit note from this rerun: the probe still emits UTF-8 warning noise while preparing multipart bodies because the prepared request keeps a string mirror of binary bytes for diagnostics, but the actual dispatch path is still `HTTPClient.request_raw(...)` and the real sandbox writes succeed end-to-end. That is log noise, not a reopened transport failure.

Final post-close audit verdict: the slice remains valid as closed. No reopen is needed for `oc-am6`.

---

### Task 10: Triage deferred or special-token routes and decide tool-api readiness

**Bead ID:** `oc-nbt`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the exercised slices, identify any remaining deferred or blocked endpoint families (S2S, monetization, platform-gated auth, entitlements, checkout, etc.), state exactly why they remain deferred, and produce a clear readiness recommendation for when `aerobeat-tool-api` can safely depend on this repo. Update this plan with the final recommendation and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`

**Status:** ✅ Complete

**Results:** Independent audit review of the completed slices says the repo is now **ready for scoped `aerobeat-tool-api` dependency**, but **not ready to be treated as full-surface mod.io parity**.

Ready-now coverage that is backed by real `test.mod.io` execution in this plan:
- public baseline reads: `GET /ping`, `GET /games/{game-id}`, `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/{mod-id}`
- owned/public mod child reads: files, file detail, stats, dependants, tags, metadata KVP, team, dependencies readback
- authenticated bearer reads: `/me`, `/me/games`, `/me/mods`, `/me/files`, `/me/subscribed`, `/me/ratings`, `/me/collections`, `/me/following/collections`, `/me/followers`, `/me/users/muted`, plus `/users/{me-id}/followers|following|collections`
- low-risk reversible writes that the sandbox actually permits: mod subscribe/unsubscribe, rating presence/readback, metadata KVP add/read/delete
- authoring/maintenance on owned disposable content: mod create/update/delete, modfile add/update/delete, media add/reorder/delete
- real provider-seam fix validated: multipart binary writes now use `HTTPClient.request_raw(...)` instead of corrupting multipart uploads through UTF-8 string dispatch

Remaining deferred / blocked / partially verified families and the exact reason each still stays out of the safe dependency boundary:
- **Guides read/write family** (`/guides`, guide comments, guide tags): **Now positively exercised in the test sandbox** via disposable guide `47`. Public list/detail/tag reads worked, guide create/update/delete worked, and guide comment create/detail/list/delete worked. Remaining caveat: immediate public detail rereads after a guide comment update stayed stale and returned the original create text, which currently looks like upstream/provider cache behavior on the public comment-detail route.
- **Collections read/write/follow/subscribe/compatibility family**: **Blocked / Deferred** because no sandbox collection corpus was created, so collection reads, membership, comments, follows, subscriptions, and compatibility checks remain unproven.
- **Multi-user social mutations and rich social assertions** (`follow`, `mute`, non-empty followers/following states): **Partially verified only as empty-state reads** because the current workout effectively has a single practical test user; meaningful positive follow/mute verification wants a second sandbox account.
- **Mod comments CRUD**: **Now positively exercised in the test sandbox** on public workout `16112`. Create/detail/list/delete worked, but immediate public detail rereads after update still returned the original create text instead of the updated content, matching the guide-comment seam above.
- **Tag maintenance writes**: **Partially verified / blocked by sandbox validation policy**. Freeform `POST .../tags` returned `422`, provider error ref `13009`; read paths are covered, but write support for this workout is not proven.
- **Dependency mutation writes**: **Now positively exercised in the test sandbox**. Disposable dependency target mod `16130` plus build `22707` were created, `POST .../dependencies` on parent workout `16112` returned `201`, parent dependency readback showed the target name, dependant readback on the target showed the parent workout, `DELETE .../dependencies` returned `204`, and parent readback after delete returned empty again.
- **Mod stats**: **Partially verified**. The route itself returns HTTP `200` and the adapter matches the raw payload, but the sandbox payload currently reports zeroed counters and `mod_id = 0`, so the route is transport/normalization-safe without being a strong semantic data assertion.
- **Ratings mutation**: **Partially verified but operationally acceptable**. Positive rating presence is confirmed through readback and reruns are idempotently handled, but the workout did not include a full destructive reset / alternate-value cycle.
- **Monetization browse and owned monetization team routes** (`token-packs`, mod monetization team): **Deferred** because they require sandbox monetization setup that is unrelated to the core browse/auth/authoring seam this repo needed to harden first.
- **Checkout / purchased / wallet / entitlement routes**: **Deferred** because they depend on monetization/store setup, portal/platform headers, and product-specific receipts or purchase state that were not required for the current confidence target.
- **Platform-gated auth routes** (`steamauth`, `xboxauth`, `psnauth`, `switchauth`, `epicgamesauth`, `googleauth`, `appleauth`, `openidauth`, etc.): **Deferred** because they need real external platform credentials and account-linking setup; the completed bearer validation used the lower-friction email exchange lane instead.
- **S2S routes** (`/s2s/transactions/*`, `/s2s/connections/*`, monetization-team transaction history): **Deferred by design** because they belong to a secure backend/service-token lane, not the game-client bearer harness lane exercised here.
- **Live-server parity outside the sandbox**: **Deferred**. The supporting sandbox-validation plan still has pending live `/me` parity tasks, so the current confidence statement is intentionally about the `test.mod.io` seam, not a final live-environment certification.

Readiness recommendation for `aerobeat-tool-api`:
- **Yes, `aerobeat-tool-api` can now safely depend on this repo for the core mod.io lane** if its near-term feature set is limited to the validated surface above: public browse/detail, bearer-authenticated self reads, reversible user-state writes that the sandbox supports, and owned mod authoring/modfile/media maintenance.
- **No, `aerobeat-tool-api` should not yet assume the full wrapped REST surface is production-ready.** The deferred families above should stay either unexposed, feature-flagged, or routed behind explicit `not yet validated` guards until AeroBeat actually needs them and a dedicated sandbox/backend validation pass is run.
- **Practical safe adoption rule:** treat `aerobeat-vendor-modio` as the trusted transport/normalization seam for the already-exercised endpoint families, and treat guides, collections, multi-user social writes, comments, dependency creation, monetization, checkout, entitlements, platform auth, and S2S as out-of-scope for the first `aerobeat-tool-api` dependency milestone.
- **Recommended next trigger for widening the dependency boundary:** only expand beyond that core lane when AeroBeat has an immediate product requirement plus the necessary sandbox material/auth lane to prove the relevant family end-to-end.

---

### Task 11: Exercise newly unlocked dependency, guide, and comment flows in the test sandbox

**Bead ID:** `oc-0fm`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-0fm` on start. Derrick has now enabled dependencies with an opt-out rule, created a guide, and enabled comments on the remaining test workout in the test sandbox. Exercise the newly unlocked dependency, guide, and comment endpoint families against the test server using the validated bearer-token flow and existing sandbox fixtures where possible. Keep writes minimal and reversible, verify each write immediately through readbacks, fix any provider-seam bugs you find, add focused regression tests, rerun relevant validation, update this master plan with exact evidence/results, commit and push by default, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/` local runtime artifacts only as needed
- `src/` / tests as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- `.testbed/modio_live_harness_lib.gd`
- `.testbed/modio_unlocked_family_harness.gd`
- `.testbed/tests/test_modio_live_harness.gd`

**Status:** ✅ Complete

**Results:** Added a dedicated repeatable sandbox probe at `.testbed/modio_unlocked_family_harness.gd` plus focused guide/comment summary coverage in `.testbed/modio_live_harness_lib.gd` and regression assertions in `.testbed/tests/test_modio_live_harness.gd`.

Exact test-sandbox evidence from `godot --headless --path .testbed --script res://modio_unlocked_family_harness.gd` on 2026-05-06:
- selected existing public workout/mod `16112` (`oc-4wr sandbox pagination sample 1778082871`) as the reversible parent for comment/dependency checks
- mod comments are now live on that workout: created comment `396` -> `201`, immediate detail read -> `200`, list readback showed the new id, delete -> `204`, list-after-delete returned empty again
- guide authoring + public guide reads now work: created public guide `47` (`oc-0fm-guide-1778093505`) -> `201`, public guide list/detail returned it with `allows_comments = true`, update -> `200`, public guide tags readback returned `exercise` + `guide`, delete -> `204`
- guide comments are now live: created guide comment `397` -> `201`, immediate detail read -> `200`, list readback showed the new id, delete -> `204`, list-after-delete returned empty again
- dependency writes are now enabled: created disposable dependency target mod `16130` -> `201`, uploaded disposable build `22707` -> `201`, added it as a dependency on parent mod `16112` -> `201`, parent dependency readback -> `200` with the disposable target name present, dependant readback on `16130` -> `200` with parent workout `oc-4wr sandbox pagination sample 1778082871`, dependency delete -> `204`, parent dependency readback after delete -> empty, then deleted disposable target mod `16130` -> `204`

Focused validation reruns:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (94/94 passing)

Significant provider-seam finding documented for QA/audit follow-up:
- immediate public `GET` comment detail readbacks stay stale after comment updates even though the update `PUT` response echoes the new content
- reproduced for mod comment `396` (`expected "oc-0fm mod comment update 1778093505"`, immediate detail still returned original create text) and guide comment `397` (`expected "oc-0fm guide comment update 1778093505"`, immediate detail still returned original create text)
- an extra targeted probe waiting 3 seconds before rereading a mod comment still returned the original create text, so this currently looks like upstream/provider cache behavior on public comment-detail reads rather than a local request-shaping failure

---

### Task 12: QA the newly unlocked dependency, guide, and comment flows

**Bead ID:** `oc-6kfx`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-6kfx` on start. Independently verify the newly unlocked dependency, guide, and comment sweep against the test sandbox, rerun the relevant harness/tests/probes, confirm outcomes and request shaping, make only minimum necessary QA fixes if required, update this master plan with findings, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- code/tests only if minimum fix is needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- code/tests only if needed

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 13: Audit the newly unlocked dependency, guide, and comment flows

**Bead ID:** `oc-10br`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim bead `oc-10br` on start. Perform an independent truth-check of the newly unlocked dependency, guide, and comment sweep after coder + QA. Confirm which of these previously deferred families are now validated, note any remaining sandbox or policy caveats, update this master plan with a concise pass/fail result, and close the bead with a clear reason.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** A real-sandbox confidence pass for `aerobeat-vendor-modio` that now covers the core public browse/detail lane, bearer-authenticated self/inventory reads, reversible low-risk user writes the sandbox permits, and owned mod authoring/modfile/media maintenance. The work also found and fixed one genuine transport seam bug: binary multipart writes now dispatch via `HTTPClient.request_raw(...)`, which unblocked real upload/update coverage on `test.mod.io`.

**Reference Check:** `REF-01` and the wrapped surface list were reconciled against the exercised endpoint matrix; `REF-02` through `REF-06` supplied the sandbox harness/config evidence used for every completed slice; `REF-07` remained the doc-side source of truth for route/auth interpretation. Later follow-up slices additionally proved guide reads/writes, guide comments, mod comments, and positive dependency creation in the test sandbox, leaving collections, richer multi-user social writes, monetization, checkout, entitlements, platform auth, S2S, and live-only parity as the remaining explicit exclusions/caveats.

**Commits:**
- See the completed coder/QA slices above for code-bearing changes; this final auditor pass only updated plan documentation.

**Lessons Learned:**
- The `test.mod.io` sandbox is strong enough to harden the core transport/normalization seam before lifting behavior into higher layers, but it is not a substitute for every auth/platform/commerce/backend lane.
- Empty sandbox responses can echo pagination metadata differently than non-empty responses; request-shape truth checks matter.
- Several unresolved gaps are not wrapper bugs at all—they are sandbox capability or policy constraints (`14038`, `15077`, live-release modfile delete rules, single-user social limits).
- The safe rollout line for `aerobeat-tool-api` is feature-scoped readiness, not blanket “all wrapped routes are done.”

---

*Completed on 2026-05-06*