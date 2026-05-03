# AeroBeat Vendor Mod.io Remaining Coverage and Final Audit

**Date:** 2026-05-03  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Drive `aerobeat-vendor-modio` through the remaining coherent mod.io REST coverage slices, then finish with a strict gap audit against the refreshed local official corpus so we can prove what is covered, what is intentionally out of scope, and whether anything was missed.

---

## Overview

The repo already has a truth-locked foundation across auth/session, mod browse/detail/files/stats, subscriptions, ratings/reporting, dependencies, mod comments, guides, guide comments, collections, and the read-only user/social slice. Derrick has now explicitly authorized continuing through the remaining slices without pausing between coder → QA → audit unless we hit unresolved ambiguity or a boundary decision that needs human override.

This plan is the umbrella for the rest of the push. Each remaining family still needs to be handled as a coherent batch, with local official docs first, then coder → QA → auditor, and each batch must stay inside the vendor-adapter boundary. When the implementation slices are finished, we will run a final corpus-vs-repo gap audit to verify endpoint-family coverage, identify any intentionally deferred policy/install/authoring surfaces, and make sure we did not accidentally miss a clean vendor-local read/write family.

The key constraint is not just “wrap more endpoints.” It is “wrap more endpoints truthfully.” That means preserving exact path/method/query/body contracts, response-shape fidelity, and explicit out-of-scope decisions where mod.io functionality would drag the repo into downloader/install orchestration, moderation workflow policy, or broader AeroBeat product behavior.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Doc-truth audit baseline | `.plans/2026-05-03-aerobeat-vendor-modio-doc-truth-and-repo-audit.md` |
| `REF-02` | Collection slice plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md` |
| `REF-03` | User/social slice plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-user-and-social-surface-coverage.md` |
| `REF-04` | Earlier guide/comment slice | `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md` |
| `REF-05` | Current research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-06` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-07` | Corpus completeness note | `docs/modio-rest-corpus-completeness-2026-05-03.md` |
| `REF-08` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-09` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-10` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-11` | Current implementation | `src/` |
| `REF-12` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research remaining uncovered families and execution order

**Bead ID:** `oc-09k`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the current wrapped repo surface against the refreshed official local mod.io corpus and produce an execution-ready map of the remaining uncovered endpoint families. Group them into coherent slices, recommend the next execution order, and explicitly mark any surfaces that should remain out of scope because they would pull install/orchestration, moderation policy, monetization policy, or authoring/CMS behavior into this repo. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise gap map note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Compared the current wrapped surface in `REF-11` plus `README.md`/`docs/modio-seam-plan.md` against the refreshed official local corpus in `REF-08` through `REF-10` and produced an execution-ready remaining-family map.

Remaining **clean in-scope** uncovered families:
- **Catalog / game-meta / taxonomy utility slice**
  - `GET /games`
  - `GET /games/{game-id}/stats`
  - `GET /games/{game-id}/tags`
  - `GET /games/{game-id}/tokenpacks`
  - `GET /games/{game-id}/mods/stats`
  - `GET /games/{game-id}/guides/tags`
  - `GET /agreements/types/{agreement-type-id}/versions/{version}` (doc filename `get-agreement-version.api.mdx`)
  - `GET /ping`
  - Why grouped: all are read-only catalog/capability/taxonomy utilities that extend the current browse/auth seam without introducing authoring, install, or product-policy behavior.
- **Mod-adjacent read enrichment slice**
  - `GET /games/{game-id}/mods/{mod-id}/dependants`
  - `GET /games/{game-id}/mods/{mod-id}/tags`
  - `GET /games/{game-id}/mods/{mod-id}/metadata` (`get-mod-kvp-metadata.api.mdx`)
  - `GET /games/{game-id}/mods/{mod-id}/team`
  - `GET /games/{game-id}/mods/{mod-id}/collections`
  - `GET /games/{game-id}/mods/{mod-id}/collections/{collection-id}`
  - Why grouped: these are provider-native read enrichments around already wrapped mod detail/dependency/community surfaces and should reuse the existing mod/collection/user normalizers cleanly.
- **User inventory/profile read slice**
  - `GET /users/{user-id}/games`
  - `GET /users/{user-id}/mods`
  - `GET /users/{user-id}/modfiles`
  - Why grouped: these are read-only profile inventory endpoints adjacent to the newly completed user/social slice and should reuse current paging + user/mod/modfile normalization primitives.
- **External auth provider parity slice**
  - `POST /external/appleauth`
  - `POST /external/discordauth`
  - `POST /external/epicgamesauth`
  - `POST /external/gogauth`
  - `POST /external/googleauth`
  - `POST /external/oculusauth`
  - `POST /external/psnauth`
  - `POST /external/steamauth`
  - `POST /external/switchauth`
  - `POST /external/udtauth`
  - `POST /external/xboxliveauth`
  - Why grouped: these are the remaining provider-auth variants parallel to the already wrapped OpenID flow and can likely share one request/normalization strategy with provider-specific required fields documented per page.

Recommended execution order:
1. **Catalog / game-meta / taxonomy utility slice** — smallest clean read-only win; extends discovery/capability truth with little seam risk.
2. **Mod-adjacent read enrichment slice** — highest-value remaining mod read coverage and closest to the already wrapped mod/community primitives.
3. **User inventory/profile read slice** — straightforward reuse of existing list normalization after the social/account-state read work.
4. **External auth provider parity slice** — still in scope, but lower immediate product value than the read families and likely easiest once the remaining read pressure is gone.
5. **Final corpus-vs-repo audit** after those slices land.

Remaining uncovered families that should stay **intentionally out of scope for this repo right now**:
- **Install / subscription orchestration pressure**
  - `POST/DELETE /games/{game-id}/collections/{collection-id}/subscribe`
  - source/install-adjacent collection orchestration already shows up in the official SDK/Unity flows (`SubscribeToModCollectionOp`, `ProcessNextModInUserCollection`, `ProcessNextModInServerCollection`); do not pull that install/subscription-policy behavior into this vendor seam.
- **Authoring / CMS / upload / cloud-cooking / moderation-admin surfaces**
  - create/edit/delete mod, guide, collection (`add-*.api.mdx`, `edit-*.api.mdx`, `delete-*.api.mdx`, `update-collection.api.mdx`)
  - mod media/tags/metadata/dependency writes and deletes (`add/delete/reorder-mod-media`, `add/delete-mod-tags`, `add/delete-mod-kvp-metadata`, `add/delete-mod-dependencies`)
  - modfile/source-file/upload/cook/platform-status surfaces (`add/edit/delete-modfile`, `add-source-modfile`, `browse-source-modfiles`, `browse-modfile-cooks`, multipart upload session/parts lifecycle, `finalize-cloud-cooking`, `manage-platform-status`)
  - collection membership management (`delete-collection-mods`)
  - game media writes (`add-game-media`)
  - Why out: these move the repo from vendor read/community seam into content authoring, asset pipeline, upload orchestration, release management, or moderation/admin behavior.
- **Monetization / entitlement / purchase policy surfaces**
  - `POST /games/{game-id}/mods/{mod-id}/checkout`
  - `GET /me/wallet`
  - `GET /me/purchases`
  - `GET /me/entitlements`
  - `GET /games/{game-id}/mods/{mod-id}/team/members`, `POST /games/{game-id}/mods/{mod-id}/team`, and monetization transaction/S2S routes (`get-monetization-transaction*`, `create-mod-monetization-team`, `get-users-in-mod-monetization-team`, `s-2-s-*`)
  - Why out: these require AeroBeat-side monetization, entitlements, refund/clawback, and store-policy decisions that should not be smuggled into this adapter.
- **Write-side social / moderation-policy edges**
  - `POST/DELETE /users/{user-id}/mute`
  - `POST/DELETE /users/{user-id}/follow`
  - `POST/DELETE /games/{game-id}/collections/{collection-id}/follow`
  - Why out: these are account-state mutation and moderation/social-policy behaviors rather than the current read/community seam.
- **Legacy event feeds**
  - `GET /me/events`
  - `GET /games/{game-id}/mods/events`
  - `GET /games/{game-id}/mods/{mod-id}/events`
  - Why out: they are legacy event-driven sync surfaces and do not fit the repo’s current subscription/read-state direction.

Net finding: after the already completed auth/session, mod browse/detail/files/stats, subscriptions, ratings/reporting, dependencies, mod comments, guides, guide comments, collections, and read-only user/social/account-state coverage, the remaining **clean vendor-local implementation opportunity** is now mostly read enrichment + auth parity. Most of the rest of the corpus is intentionally where install orchestration, authoring/CMS, moderation/social mutation, or monetization policy begins.

---

### Task 2: Execute remaining coherent slices

**Bead ID:** `oc-4zg`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Execute the next coherent remaining mod.io vendor slice as defined by the latest research/gap map. Use the refreshed local official corpus as source of truth, keep the seam vendor-local, and update the umbrella plan with which slice was completed, what changed, validation evidence, and any newly identified sub-slices. Commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

**Status:** ✅ Complete

**Results:** Completed the first four execution families from the gap map, with this coder pass finishing the remaining **external auth provider parity batch**.

1. **Catalog / game-meta / taxonomy utility batch**
   - Added vendor-local request builders, transport coverage, fixtures, and normalization for `GET /games`, `GET /games/{game-id}/stats`, `GET /games/{game-id}/tags`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/guides/tags`, `GET /agreements/versions/{agreement-version-id}`, and `GET /ping`, plus the doc-corrected read-only token-pack surface at `GET /games/{game-id}/monetization/token-packs`.
   - The refreshed local corpus corrected two paths from the earlier gap wording (`/games/{game-id}/tokenpacks` -> `/games/{game-id}/monetization/token-packs`, `/agreements/types/{agreement-type-id}/versions/{version}` -> `/agreements/versions/{agreement-version-id}`), and the implementation followed the local official docs/SDK/Unity refs instead of the stale gap-map phrasing.

2. **Mod-adjacent read enrichment batch** ✅ completed in this pass
   - Added vendor-local request builders, transport coverage, fixtures, normalization helpers, and seam-doc updates for:
     - `GET /games/{game-id}/mods/{mod-id}/dependants`
     - `GET /games/{game-id}/mods/{mod-id}/tags`
     - `GET /games/{game-id}/mods/{mod-id}/metadatakvp`
     - `GET /games/{game-id}/mods/{mod-id}/team`
   - Reused the existing collection coverage as-is instead of inventing undocumented mod-scoped aliases: the refreshed local official corpus in `REF-08` through `REF-10` reconfirmed that collection reads remain on the already wrapped game-scoped routes `GET /games/{game-id}/collections` and `GET /games/{game-id}/collections/{collection-id}` rather than `/games/{game-id}/mods/{mod-id}/collections...`.
   - Kept the new query serialization truthful to the docs: dependants + metadata KVP are paging-only, mod tags accept only `date_added` + `tag` plus paging, and mod team accepts only `id`, `user_id`, `username`, `level`, `date_added`, and `pending` plus paging.

3. **User inventory/profile read batch** ✅ completed in a prior pass
   - Added vendor-local authenticated request builders, transport coverage, reuse-focused normalization wrappers, and seam-doc updates for the current documented authenticated routes:
     - `GET /me/games`
     - `GET /me/mods`
     - `GET /me/files`
   - The refreshed local official corpus in `REF-08` through `REF-10` forced a narrower correction from the stale gap wording: this batch intentionally did **not** add undocumented public aliases such as `/users/{user-id}/games`, `/users/{user-id}/mods`, or `/users/{user-id}/modfiles`; it followed the current docs/SDK/Unity surfaces at `/me/games`, `/me/mods`, and `/me/files`.
   - Kept the new query serialization truthful to the docs: `/me/games` reuses the documented game filters and sort keys, `/me/mods` accepts only the documented authenticated user-mod fields (`tags`, metadata, ids, status/visibility, game/date/name/modfile, maturity/monetization, platform status, paging, sort), and `/me/files` accepts only the documented authenticated user-modfile fields (`id`, `mod_id`, `date_added`, `date_scanned`, virus/file metadata, metadata blob, platform status, paging).
   - Reused existing game/mod/modfile list fixtures and normalizers where truthful, adding only thin user-inventory normalization wrappers plus the extra `ModioListingQuery` fields needed to serialize the documented user-mod and user-modfile filters. This pass also corrected the shared game sort allowlist to the current documented keys so the new authenticated user-game surface matches the refreshed corpus.

4. **External auth provider parity batch** ✅ completed in this pass
   - Added vendor-local request builders and transport-tested request execution coverage for the remaining documented external auth providers parallel to the existing OpenID flow:
     - `POST /external/appleauth`
     - `POST /external/discordauth`
     - `POST /external/epicgamesauth`
     - `POST /external/galaxyauth`
     - `POST /external/googleauth`
     - `POST /external/oculusauth`
     - `POST /external/psnauth`
     - `POST /external/steamauth`
     - `POST /external/switchauth`
     - `POST /external/udtauth`
     - `POST /external/xboxauth`
   - Reused the existing access-token/session normalization seam instead of inventing new auth response shapes; this batch only added the minimum truthful provider-specific request builders plus targeted request/transport tests and seam-doc updates.
   - The refreshed local official corpus in `REF-08` through `REF-10` forced two path corrections from the earlier gap wording: GOG Galaxy is documented at `/external/galaxyauth` rather than `/external/gogauth`, and Xbox Live is documented at `/external/xboxauth` rather than `/external/xboxliveauth`.
   - Kept provider-specific request differences truthful to the local corpus: Google accepts either `auth_code` or `id_token`; Meta Quest/Oculus requires `device`, `nonce`, `user_id`, and `access_token`; UDT uses the required `X-Modio-Delegation-Token` header with an empty form body; and the new builders clamp `date_expires` using the documented provider maxima (one week for Apple/Discord/Epic/GOG/Google/Steam, one common year for Oculus/PSN/Switch/Xbox).
   - No new response fixtures were required because the existing access-token fixture/normalization seam already truthfully covers the shared success envelope returned by these provider auth endpoints.

Validation evidence:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`42/42` tests passed, `1323` asserts)

Scope notes:
- This coder pass completed the remaining **external auth provider parity batch** only; it did not broaden into purchase/entitlement/store policy, install orchestration, broader platform SDK behavior, or any authoring/admin surface.
- Kept vendor-local boundaries intact: no write-side mod tags/metadata/dependency/team management, authoring/CMS, uploads, install orchestration, monetization purchase/intents, or legacy event work were added.
- Kept monetization handling narrowly read-only: token-pack discovery only, no purchase/intents/wallet flows.

---

### Task 3: QA each remaining slice automatically

**Bead ID:** `oc-2js`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest remaining-slice implementation against the refreshed local official mod.io corpus. Confirm request shapes, normalization, fixtures, tests, and seam docs match the docs and that vendor-local boundaries hold. Make only minimum necessary fixes, rerun validation/tests, update the umbrella plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

**Status:** ✅ Complete

**Results:** Independently QA-checked the catalog / game-meta / taxonomy utility batch against the refreshed local official corpus in `REF-08` through `REF-10`.

Exact QA findings:
- ✅ Request paths/methods verified against local official docs/SDK/Unity for `GET /games`, `GET /games/{game-id}/stats`, `GET /games/{game-id}/tags`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/guides/tags`, `GET /agreements/versions/{agreement-version-id}`, `GET /games/{game-id}/monetization/token-packs`, and `GET /ping`.
- ✅ The coder’s doc-truth corrections for token packs and agreement-version routes were correct; implementation/tests already used the corrected paths instead of the earlier stale gap-map wording.
- ✅ Token-pack auth boundary stayed truthful: the local Unity integration requires authentication for `GET /games/{game-id}/monetization/token-packs`, and the repo continues to issue it as bearer-auth without leaking an API key into the request URL.
- ✅ Normalization/fixtures stayed truthful for the added game stats, game tags, guide tags, agreement-version, token-pack, and ping payloads; no seam-local invention beyond light helper fields already used elsewhere (`has_expiry` / `is_stale` for expiring stats payloads, raw localization/count payload preservation for tag options).
- ✅ Vendor-local boundaries remained intact: no write routes, authoring/CMS, install orchestration, wallet/purchase flows, or legacy event work were added.
- ❌ One drift was found and fixed: `GET /games` filter serialization/docs/tests used `maturity_option` (singular), but the refreshed official docs + Unity generator use `maturity_options` (plural) for that endpoint. Fixed the query serialization plus the affected repo-local docs/tests.

Files changed during QA:
- `src/models/modio_listing_query.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

Validation evidence after the fix:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`35/35` tests passed, `1100` asserts)

Additional QA pass — mod-adjacent read enrichment batch:
- ✅ Request paths/methods re-verified against the refreshed local official corpus for `GET /games/{game-id}/mods/{mod-id}/dependants`, `GET /games/{game-id}/mods/{mod-id}/tags`, `GET /games/{game-id}/mods/{mod-id}/metadatakvp`, and `GET /games/{game-id}/mods/{mod-id}/team`.
- ✅ The doc-truth correction to `metadatakvp` held: implementation/tests/docs continue to use `/games/{game-id}/mods/{mod-id}/metadatakvp`, matching `modio-docs` and the generated Unity endpoint.
- ✅ Dependants + metadata KVP remained paging-only, mod tags remained limited to documented `date_added` + `tag` filters plus paging, and mod team remained limited to documented `id` / `user_id` / `username` / `level` / `date_added` / `pending` filters plus paging.
- ✅ The repo continued to omit invented mod-scoped collection routes. The refreshed local corpus pages titled `Get Mod Collections` / `Get Mod Collection` still resolve to the already-wrapped game-scoped collection paths (`/games/{game-id}/collections` and `/games/{game-id}/collections/{collection-id}`), so no extra mod-scoped collection wrapper was missing.
- ✅ Fixtures/normalizers stayed truthful to the refreshed docs schemas: dependants preserve `mod_id`/status/visibility/logo payloads, tags preserve `name`/`name_localized`/deprecated `date_added`, metadata KVP preserves `metakey`/`metavalue`, and team preserves `invite_pending` plus deprecated nested user `timezone`/`language` fields without inventing higher-level policy.
- ✅ README/seam-plan claims stayed truthful and vendor-local boundaries remained intact: no write-side tags/metadata/team/dependency management or higher-level AeroBeat orchestration leaked into this slice.
- ✅ No residual drift found in this QA pass. No code/docs/test fixes were required.

Validation evidence for this QA pass:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`38/38` tests passed, `1164` asserts)

Files changed during this QA pass:
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

Additional QA pass — authenticated user inventory/profile read batch:
- ✅ Request paths/methods re-verified against the refreshed local official corpus for `GET /me/games`, `GET /me/mods`, and `GET /me/files`; implementation/tests/docs all stayed aligned to the authenticated `/me/...` routes, not guessed `/users/{user-id}/...` aliases.
- ✅ The doc-truth correction held across the repo: no undocumented `/users/{user-id}/games`, `/users/{user-id}/mods`, or `/users/{user-id}/modfiles` route was implemented or claimed.
- ✅ Query shaping remained truthful to the refreshed docs plus generated Unity surfaces:
  - `/me/games` reuses the documented game filters and documented game sort allowlist.
  - `/me/mods` stays limited to documented authenticated user-mod fields (`tags`, `metadata_blob`, `metadata_kvp`, `id`, `name_id`, `status`, `visible`, `submitted_by`, `game_id`, `date_added`, `date_updated`, `date_live`, `name`, `modfile`, `maturity_option`, `monetization_options`, `platform_status`, paging, `_sort`).
  - `/me/files` stays limited to documented authenticated user-modfile fields (`id`, `mod_id`, `date_added`, `date_scanned`, `virus_status`, `virus_positive`, `filesize`, `filehash`, `filename`, `version`, `changelog`, `metadata_blob`, `platform_status`, paging).
- ✅ Normalization/fixtures stayed truthful: user-game responses reuse the existing game list normalizer, user-mod responses reuse the existing mod list normalizer, and user-modfile responses reuse the existing modfile list normalizer without inventing extra seam policy; fixture coverage matches current provider field names including file scan / virus metadata.
- ✅ README and seam-plan claims stayed truthful to the refreshed local corpus: they now describe only the documented authenticated user inventory routes and the actual supported filter subsets.
- ✅ Vendor-local boundaries remained intact: this slice stayed read-only and did not add write-side tags/metadata/team/dependency management, authoring/CMS, uploads, install orchestration, purchase/wallet/intents, or legacy event work.
- ✅ No residual drift found in this QA pass. No code/docs/test fixes were required.

Validation evidence for this QA pass:
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`41/41` tests passed, `1245` asserts)

Files changed during this QA pass:
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

Additional QA pass — external auth provider parity batch:
- ✅ Request paths/methods re-verified against the refreshed local official corpus for every implemented provider route in this batch: `POST /external/appleauth`, `POST /external/discordauth`, `POST /external/epicgamesauth`, `POST /external/galaxyauth`, `POST /external/googleauth`, `POST /external/oculusauth`, `POST /external/openidauth`, `POST /external/psnauth`, `POST /external/steamauth`, `POST /external/switchauth`, `POST /external/udtauth`, and `POST /external/xboxauth`.
- ✅ The doc-truth route corrections held across implementation/tests/docs: this repo continues to use `POST /external/galaxyauth` instead of stale `gogauth` wording and `POST /external/xboxauth` instead of stale `xboxliveauth` wording.
- ✅ Provider-specific request/body/header differences vs generic OpenID stayed truthful:
  - Apple uses `id_token` + `terms_agreed` (+ optional clamped `date_expires`) with no email field in this wrapper, matching the refreshed REST schema.
  - Discord uses `discord_token`; Epic uses `id_token`; GOG Galaxy and Steam use `appdata`; Google supports `auth_code` or `id_token`; Oculus uses `device` + `nonce` + `user_id` + `access_token`; PSN uses `auth_code` + optional `env`; Switch uses `id_token`; Xbox uses `xbox_token`; UDT sends the delegation token in the `X-Modio-Delegation-Token` header with an otherwise empty form body.
  - OpenID-only fields (`monetization_account`, `psn_token`, `psn_env`) remained isolated to `build_openid_auth_request(...)` and were not incorrectly leaked into the provider-specific builders.
- ✅ Expiry clamping rules stayed truthful to the refreshed corpus where documented: week clamp (`+604800s`) remains on OpenID, Apple, Discord, Epic, GOG Galaxy, Google, and Steam; common-year clamp (`+31536000s`) remains on Oculus, PSN, Switch, Xbox, and email exchange; UDT correctly has no request-body expiry field.
- ✅ Normalization reuse stayed truthful: the external auth batch still reuses the existing access-token normalization seam without inventing provider-specific token result shapes or leaking higher-level account policy out of this vendor adapter.
- ✅ README/docs claims stayed truthful and vendor-local boundaries remained intact: the repo documents only the wrapped mod.io-facing auth seam, correctly calls out the galaxyauth/xboxauth doc-truth names, and does not drift into AeroBeat public API, UI, consent orchestration, or product-side account policy.
- ✅ No repo-local drift was found in this QA pass, so no code/test/docs fixes were required in `aerobeat-vendor-modio`.
- ⚠️ Residual corpus drift found upstream, not in this repo: the refreshed local Unity generated request objects still model Google auth with an optional `email` field and Epic auth with `access_token`, while the refreshed REST docs and C++ SDK guidance point to Google `auth_code`/`id_token` semantics and Epic `id_token` semantics. This repo currently matches the refreshed REST docs / C++ SDK auth guidance and the generated Unity endpoint paths (`/external/googleauth`, `/external/epicgamesauth`, `/external/galaxyauth`, `/external/xboxauth`).

Validation evidence for this QA pass:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`42/42` tests passed, `1323` asserts)

Files changed during this QA pass:
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

---

### Task 4: Audit each remaining slice automatically

**Bead ID:** `oc-16a`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest remaining-slice implementation against the refreshed local official mod.io corpus. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and advances the repo toward full truthful coverage. Make only minimum necessary fixes, rerun validation/tests, update the umbrella plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

**Status:** ✅ Complete

**Results:** Independently audited the catalog / game-meta / taxonomy utility batch and the mod-adjacent read enrichment batch against the refreshed local official corpus in `REF-08` through `REF-10`, including the Task 2 implementation notes and the QA follow-up findings.

Exact audit findings — catalog / game-meta / taxonomy utility batch:
- ✅ Request paths/methods truth-check passed for all implemented routes in this batch: `GET /games`, `GET /games/{game-id}/stats`, `GET /games/{game-id}/tags`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/guides/tags`, `GET /agreements/versions/{agreement-version-id}`, `GET /games/{game-id}/monetization/token-packs`, and `GET /ping`.
- ✅ The earlier gap-map wording drift stayed corrected in implementation/tests/docs: token packs remain on the current documented monetization route (`/games/{game-id}/monetization/token-packs`), and agreement-version reads remain on `/agreements/versions/{agreement-version-id}`.
- ✅ The QA fix was present and truthful: `GET /games` now serializes `maturity_options` (plural) while collection and collection-mod filters correctly remain on `maturity_option` where the corpus still documents the singular field.
- ✅ Normalization and fixtures for games, game stats, game tags, guide tags, agreement versions, token packs, and ping remained consistent with the refreshed docs/SDK/Unity corpus. The repo preserves provider fields/localization payloads and only adds the same light seam-local helper metadata already used elsewhere (`has_expiry` / `is_stale`).
- ✅ README and seam docs stayed truthful about the added surface and its vendor-local boundaries.
- ✅ Vendor-local boundary discipline held: no install orchestration, authoring/CMS, moderation/admin, monetization purchase/intents, or other higher-level AeroBeat policy work was pulled into this slice.

Exact audit findings — mod-adjacent read enrichment batch:
- ✅ Request paths/methods truth-check passed for all implemented routes in this batch: `GET /games/{game-id}/mods/{mod-id}/dependants`, `GET /games/{game-id}/mods/{mod-id}/tags`, `GET /games/{game-id}/mods/{mod-id}/metadatakvp`, and `GET /games/{game-id}/mods/{mod-id}/team`.
- ✅ The doc-truth correction to metadata KVP held across implementation/tests/docs: the repo continues to use the documented `/games/{game-id}/mods/{mod-id}/metadatakvp` route rather than the stale `metadata` wording from the initial gap-map note.
- ✅ The repo correctly omitted invented mod-scoped collection routes. The refreshed local corpus still titles those pages `Get Mod Collections` / `Get Mod Collection`, but both the raw REST docs and the generated Unity endpoints resolve to the already wrapped game-scoped routes `GET /games/{game-id}/collections` and `GET /games/{game-id}/collections/{collection-id}` instead of `/games/{game-id}/mods/{mod-id}/collections...`.
- ✅ Query serialization stayed truthful to the corpus: dependants + metadata KVP remain paging-only, mod tags remain limited to documented `date_added` + `tag` filters plus paging, and mod team remains limited to documented `id`, `user_id`, `username`, `level`, `date_added`, and `pending` filters plus paging.
- ✅ Normalization and fixtures remained truthful to the refreshed docs/SDK/Unity corpus: dependants preserve `mod_id` / status / visibility / logo fields, tags preserve `name` / `name_localized` / deprecated `date_added`, metadata KVP preserves `metakey` / `metavalue`, and team preserves `invite_pending` plus the deprecated nested user `timezone` / `language` fields while adding only the seam-local convenience flag `is_pending`.
- ✅ README and seam docs stayed truthful about the added surface and still describe the collection omission and endpoint-specific filter limits accurately.
- ✅ Vendor-local boundary discipline held: no write-side tags/metadata/team/dependency management, no authoring/CMS or install-orchestration work, and no monetization/admin policy leakage were pulled into this slice.
- ✅ No residual drift found. No code/docs/test fixes were required during audit.

Additional audit pass — authenticated user inventory/profile read batch:
- ✅ Request paths/methods truth-check passed for all implemented routes in this batch: `GET /me/games`, `GET /me/mods`, and `GET /me/files`.
- ✅ The doc-truth correction away from the stale gap-map wording held across implementation/tests/docs: the repo continues to wrap only the documented authenticated `/me/...` routes and did not add or claim undocumented `/users/{user-id}/games`, `/users/{user-id}/mods`, or `/users/{user-id}/modfiles` aliases.
- ✅ Query serialization stayed truthful to the refreshed docs/SDK/Unity corpus:
  - `/me/games` reuses the documented game filters and documented game sort allowlist, including the corrected `maturity_options` field name.
  - `/me/mods` remains limited to the documented authenticated user-mod fields (`tags`, `metadata_blob`, `metadata_kvp`, `id`, `name_id`, `status`, `visible`, `submitted_by`, `game_id`, `date_added`, `date_updated`, `date_live`, `name`, `modfile`, `maturity_option`, `monetization_options`, `platform_status`) plus paging and the documented user-mod sort keys.
  - `/me/files` remains limited to the documented authenticated user-modfile fields (`id`, `mod_id`, `date_added`, `date_scanned`, `virus_status`, `virus_positive`, `filesize`, `filehash`, `filename`, `version`, `changelog`, `metadata_blob`, `platform_status`) plus paging, with no undocumented `_sort` or search filters leaking through.
- ✅ Normalization and fixtures remained truthful to the refreshed docs/SDK/Unity corpus: `normalize_user_games_response()` delegates to the existing game list normalizer, `normalize_user_mods_response()` delegates to the existing mod list normalizer, and `normalize_user_modfiles_response()` delegates to the existing modfile list normalizer without inventing extra seam policy; the shared fixture coverage preserves provider fields including file scan / virus metadata and expiring download URLs.
- ✅ README and seam docs stayed truthful: they now describe only the documented authenticated user inventory routes and the actual supported filter subsets for each route.
- ✅ Vendor-local boundary discipline held: this slice stayed read-only and did not pull in write-side user/social mutation, authoring/CMS, uploads, install orchestration, monetization purchase/wallet/intents, or legacy event work.
- ✅ No residual drift found. No code/docs/test fixes were required during this audit pass.

Additional audit pass — external auth provider parity batch:
- ✅ Request paths/methods truth-check passed for every implemented provider route in this batch: `POST /external/appleauth`, `POST /external/discordauth`, `POST /external/epicgamesauth`, `POST /external/galaxyauth`, `POST /external/googleauth`, `POST /external/oculusauth`, `POST /external/openidauth`, `POST /external/psnauth`, `POST /external/steamauth`, `POST /external/switchauth`, `POST /external/udtauth`, and `POST /external/xboxauth`.
- ✅ The doc-truth route corrections held across implementation/tests/docs: this repo continues to use `POST /external/galaxyauth` instead of stale `gogauth` wording and `POST /external/xboxauth` instead of stale `xboxliveauth` wording.
- ✅ Provider-specific request/body/header differences vs generic OpenID stayed truthful to the refreshed corpus:
  - Apple uses `id_token` + `terms_agreed` (+ optional week-clamped `date_expires`) and intentionally does **not** expose an email field in this wrapper, matching the refreshed REST schema.
  - Discord uses `discord_token` plus optional `email`; Epic uses `id_token` plus optional `email`; GOG Galaxy and Steam use `appdata` plus optional `email`; Oculus uses `device` + `nonce` + `user_id` + `access_token` plus optional `email`; PSN uses `auth_code` + optional `env` + optional `email`; Switch uses `id_token` + optional `email`; Xbox uses `xbox_token` + optional `email`; UDT sends the delegation token in the `X-Modio-Delegation-Token` header with an otherwise empty form body.
  - Google remains distinct from generic OpenID and from the Unity-generated drift: this repo accepts the refreshed REST-documented `auth_code` or `id_token` semantics without adding an undocumented email field.
  - OpenID-only fields (`monetization_account`, `psn_token`, `psn_env`) remain isolated to `build_openid_auth_request(...)` and are not leaked into the provider-specific builders.
- ✅ Expiry clamping rules stayed truthful where the refreshed corpus documents them: week clamp (`+604800s`) remains on OpenID, Apple, Discord, Epic, GOG Galaxy, Google, and Steam; common-year clamp (`+31536000s`) remains on Oculus, PSN, Switch, Xbox, and email exchange; UDT correctly has no request-body expiry field.
- ✅ Normalization reuse stayed truthful: the external auth batch still reuses the existing access-token normalization seam without inventing provider-specific token result shapes or leaking higher-level account policy out of this vendor adapter.
- ✅ README/docs truthfulness and vendor-local boundary discipline both held: the repo documents only the wrapped mod.io-facing auth seam, calls out the galaxyauth/xboxauth doc-truth names, and does not drift into AeroBeat public API, UI consent orchestration, or product-side account policy.
- ⚠️ Residual corpus drift remains upstream rather than in this repo: the refreshed local Unity generated request objects still disagree with the refreshed REST docs / C++ SDK guidance on at least Google (`email` modeled in Unity vs `auth_code` / `id_token`-only REST schema) and Epic (`access_token` modeled in Unity vs `id_token` in REST docs / C++ SDK guidance). This repo currently matches the refreshed REST docs / C++ SDK guidance while still matching the generated Unity endpoint paths (`/external/googleauth`, `/external/epicgamesauth`, `/external/galaxyauth`, `/external/xboxauth`).
- ✅ No repo-local drift was found in this audit pass. No code/docs/test fixes were required.

Validation evidence:
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`42/42` tests passed, `1323` asserts)

Audit note: because the audit produced only plan-state documentation updates, the only tracked file changed in this pass was this umbrella plan.

---

### Task 5: Final corpus-vs-repo gap audit

**Bead ID:** `oc-sj7`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. After the remaining coherent slices are done, perform a final explicit gap audit comparing the current repo surface against the refreshed official local mod.io corpus. Produce a clear list of: covered endpoint families, intentionally deferred/out-of-scope families, and any truly missed clean vendor-local surfaces. Update the plan and any concise repo-local audit note with exact results, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a final gap note is helpful

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`
- optional final audit note(s)

**Status:** ✅ Complete

**Results:** Final corpus-vs-repo audit completed against `REF-08` through `REF-10`, with the repo surface confirmed from `REF-11` plus `README.md`, `docs/modio-seam-plan.md`, and the earlier plan trail in `REF-01` through `REF-07`.

Final covered endpoint families:
- **Auth/session + agreement utility**
  - OAuth email request/exchange, OpenID, all documented external provider auth variants (Apple, Discord, Epic Games, GOG Galaxy, Google, Meta Quest/Oculus, PSN, Steam, Switch, UDT, Xbox), terms, current agreement, agreement version, authenticated user, logout, and ping.
- **Catalog / game-meta / taxonomy utility**
  - `GET /games`, `GET /games/{game-id}`, `GET /games/{game-id}/stats`, `GET /games/{game-id}/tags`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/guides/tags`, and authenticated read-only token-pack discovery at `GET /games/{game-id}/monetization/token-packs`.
- **Core mod browse/detail/file/state reads**
  - `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/{mod-id}`, `GET /games/{game-id}/mods/{mod-id}/files`, `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`, `GET /games/{game-id}/mods/{mod-id}/stats`, dependency reads, dependants, tags, metadata KVP, and team reads.
- **User inventory/profile/state reads and adjacent writes that stay vendor-local**
  - `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/subscribed`, `GET /me/ratings`, mod rating write, report submit, and mod subscribe/unsubscribe.
- **Guide/community family**
  - guide list/detail, guide tags, guide comments list/detail/create/update/delete, and guide comment karma.
- **Collection/community family**
  - collection list/detail, collection-mod membership reads, collection comments list/detail/create/update/delete, collection comment karma, and collection compatibility rating write.
- **Read-only user/social/account-state family**
  - `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, and `GET /me/following/collections`.

Final intentionally deferred / out-of-scope families:
- **Authoring / CMS / admin writes**
  - create/edit/delete game media, mods, guides, collections, mod media, mod tags, mod metadata KVP, mod dependencies, and collection membership management.
- **Upload / file-pipeline / platform-management surfaces**
  - add/edit/delete modfiles, source modfiles, multipart upload session/parts lifecycle, browse modfile cooks, finalize cloud cooking, and per-platform status management.
- **Collection follow/subscribe and install-orchestration edges**
  - collection follow/unfollow, subscribe/unsubscribe-to-collection-mods, and the broader SDK/plugin install loops these imply.
- **Write-side social / moderation-policy mutation**
  - follow/unfollow user, mute/unmute user, and other account-state mutation behavior.
- **Monetization / purchase / entitlement / partner-team / S2S policy surfaces**
  - checkout/purchase, wallet, purchases, entitlements, monetization-team management, transaction endpoints, and S2S connection/disconnect flows.
- **Legacy event feeds**
  - `/me/events`, `/games/{game-id}/mods/events`, and `/games/{game-id}/mods/{mod-id}/events`.

Final missed clean vendor-local surfaces:
- **None found.** After the corpus refresh and explicit correction pass, no remaining uncovered family met all of these conditions at once: clearly documented in the refreshed official local corpus, cleanly vendor-local for this adapter, and not already covered by an existing wrapped route under the corrected path/auth truth. The main apparent gaps from earlier wording all resolved into corpus-truth corrections rather than real misses:
  - user inventory is the authenticated `/me/games`, `/me/mods`, and `/me/files` family, not undocumented `/users/{user-id}/...` aliases
  - mod collection pages still resolve to the already wrapped game-scoped collection routes rather than mod-scoped aliases
  - token packs live on `/games/{game-id}/monetization/token-packs`
  - agreement-version reads live on `/agreements/versions/{agreement-version-id}`
  - GOG Galaxy / Xbox auth live on `/external/galaxyauth` and `/external/xboxauth`
  - mod metadata KVP lives on `/metadatakvp`

Corpus-correction truth check:
- ✅ The repo/docs/plan trail now consistently reflects the corrected authenticated user inventory routes (`/me/games`, `/me/mods`, `/me/files`), game-scoped collection reads, token-pack monetization route, agreement-version route, `metadatakvp`, `galaxyauth`, `xboxauth`, and the `maturity_options` fix for game listing filters.
- ✅ Residual disagreement remains upstream rather than in this repo: the refreshed Unity-generated request objects still drift from refreshed REST docs / SDK guidance on Google and Epic auth request fields, while this repo matches the refreshed REST docs / SDK contract and the generated Unity endpoint paths.

Validation evidence for the final audit:
- `grep -n "^[[:space:]]*func build_" src/modio_vendor_adapter.gd`
- `grep -RInE "galaxyauth|xboxauth|maturity_options|metadatakvp|/me/games|/me/mods|/me/files|monetization/token-packs|agreements/versions" README.md docs/modio-seam-plan.md .plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md .plans/2026-05-03-aerobeat-vendor-modio-doc-truth-and-repo-audit.md`
- `python3` inventory passes over `modio-docs/public/en-us/restapi/docs/*.api.mdx` to enumerate the remaining official families and spot-check corrected pages such as `get-user-games.api.mdx`, `get-mod-collections.api.mdx`, `get-game-token-packs.api.mdx`, `get-agreement-version.api.mdx`, `authenticate-via-gog-galaxy.api.mdx`, and `authenticate-via-xbox-live.api.mdx`
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`42/42` tests passed, `1323` asserts)

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The repo now truthfully covers the clean vendor-local mod.io seam for AeroBeat across auth/session, external auth parity, game/catalog meta, core mod browse/detail/file/state reads, dependency/community reads, guides, collections, authenticated user inventory/state, read-only user/social/account-state reads, ratings/reporting, and subscription flows. The remaining official corpus families now cluster on intentionally deferred policy-heavy or pipeline-heavy surfaces rather than missed clean adapter work.

**Reference Check:** `REF-08` through `REF-10` remain the source of truth for the final surface classification, while `REF-01` through `REF-07` show the correction trail from stale wording to final repo truth. The final audit confirmed that prior corpus corrections are reflected consistently in code/docs/plan state: `/me/games|mods|files`, game-scoped collections, `metadatakvp`, `/games/{game-id}/monetization/token-packs`, `/agreements/versions/{agreement-version-id}`, `/external/galaxyauth`, `/external/xboxauth`, and `maturity_options` for game-list filtering.

**Commits:**
- Final auditor closeout recorded in git history for this plan-only audit pass.

**Lessons Learned:** The biggest remaining audit risk was not missing giant endpoint families; it was trusting endpoint titles or earlier wording instead of the actual refreshed page path/schema contract. In this corpus, several deceptive names (`Get User Games`, `Get Mod Collections`, provider auth page titles) only stay truthful if we check the concrete `MethodEndpoint` path and request schema every time.

---

*Completed on 2026-05-03*
