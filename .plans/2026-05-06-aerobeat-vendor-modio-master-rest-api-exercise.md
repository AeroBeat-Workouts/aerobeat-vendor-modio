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
| Mod authoring CRUD | `POST /games/{game-id}/mods`, `POST /games/{game-id}/mods/{mod-id}`, `DELETE /games/{game-id}/mods/{mod-id}` | Create/update **Already validated in sandbox setup work**; delete **Planned** | Bearer token; valid logo asset; safe disposable mod naming/material | We already proved create plus status/visibility update while making the sample mod. Formal slice work should capture that route family in the master plan and add explicit delete coverage on a disposable artifact. |
| Modfile CRUD | `POST /games/{game-id}/mods/{mod-id}/files`, `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` | Create **Already validated in sandbox setup work**; update/delete **Planned** | Bearer token; owned mod; disposable zip payload | File upload was already required to publish the sample mod. Update/delete still need direct coverage. |
| Mod maintenance metadata | `POST`/`DELETE` tags, metadata KVP, dependencies; `GET` related readbacks | **Planned** | Bearer token; owned mod; optional second dependency mod for dependency flows | Best exercised immediately after disposable mod creation so readback verification is local and attributable. |
| Mod media/order maintenance | `POST /games/{game-id}/mods/{mod-id}/media`, `PUT /games/{game-id}/mods/{mod-id}/media/reorder`, `DELETE /games/{game-id}/mods/{mod-id}/media` | **Planned** | Bearer token; owned mod; disposable image assets | Moderate risk only because of artifact prep, not because of destructive impact. |
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

**Status:** ⏳ Pending

**Results:** Pending.

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
- code/tests as needed

**Status:** ⏳ Pending

**Results:** Pending.

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

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 6: Implement and validate the low-risk authenticated write sweep

**Bead ID:** `oc-vrf`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Exercise the low-risk authenticated write endpoints that are safe to use in the test sandbox, such as subscriptions, ratings, comments on sandbox-owned content, and simple social/account-state writes where supported. Keep changes minimal and reversible, fix any provider-seam bugs you find, add focused regression tests, rerun validation, update this plan with exact evidence/results, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `.testbed/` local runtime artifacts only as needed
- `src/` / tests as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-05-06-aerobeat-vendor-modio-master-rest-api-exercise.md`
- code/tests as needed

**Status:** ⏳ Pending

**Results:** Pending.

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

**Status:** ⏳ Pending

**Results:** Pending.

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
- code/tests as needed

**Status:** ⏳ Pending

**Results:** Pending.

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

**Status:** ⏳ Pending

**Results:** Pending.

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

**Status:** ⏳ Pending

**Results:** Pending.

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