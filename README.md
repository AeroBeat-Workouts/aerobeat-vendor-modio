# AeroBeat Vendor - mod.io

`aerobeat-vendor-modio` is the provider-specific **mod.io adapter** package behind `aerobeat-tool-api`.

It is **not** the public AeroBeat-facing API singleton and it is **not** a product/assembly integration surface. Product repos should depend on `aerobeat-tool-api`, which can compose this repo behind a stable AeroBeat-shaped contract.

This repo exists to keep mod.io-specific concerns local, replaceable, and out of gameplay/UI repos.

## Important v1 boundary

The repo intentionally wraps a **broader mod.io provider seam** than AeroBeat v1 is approved to expose as product behavior.

That distinction matters:

- the code and docs here describe what this **provider adapter can talk to**
- they do **not** mean AeroBeat v1 ships every wrapped capability in player-facing UX
- approved v1 product behavior stays governed by the locked AeroBeat docs/policy set, especially the v1 account/UGC/review decisions in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/.plans/2026-05-07-aerobeat-v1-feature-detail-and-ugc-policy.md`

For AeroBeat v1, treat broad areas like wallet/checkout, direct entitlements, monetization-team operations, rich authoring/CMS flows, social mutation, and other admin/creator-heavy surfaces as **provider seam coverage, deferred product scope, internal tooling support, or future-phase options unless the AeroBeat product docs explicitly approve them**.

## Repository role

This package owns the concrete mod.io-side seam for:

- auth request construction and token/session normalization
- browse/list/detail request construction for game, mod, modfile, and dependency reads
- subscription/user-state request construction for `GET /me/subscribed` and subscribe/unsubscribe flows
- download metadata resolution from `modfile.download.binary_url` and `date_expires`
- canonical artifact/cache metadata resolution grounded in `provider + game_id + mod_id + modfile.id`
- provider-specific DTOs, query shapes, and error/rate-limit normalization
- thin transport glue that can execute mod.io requests without leaking that surface into `aerobeat-tool-api`

This package should **not** own:

- AeroBeat's public API manager singleton
- product-facing gameplay/UI contracts
- canonical AeroBeat trust decisions
- direct product-repo integration contracts
- download/install orchestration policy above the provider seam

## Current implementation scope

This slice now implements a fixture-driven REST wrapper for the current researched mod.io surface.

**Important:** the list below is adapter capability coverage, not the approved AeroBeat v1 feature list. Several wrapped surfaces remain intentionally broader than the current product charter so higher layers can choose from them later without reopening the vendor seam.


- auth/session request shapes
  - `POST /oauth/emailrequest`
  - `POST /oauth/emailexchange`
  - `POST /external/appleauth`
  - `POST /external/discordauth`
  - `POST /external/epicgamesauth`
  - `POST /external/galaxyauth` *(GOG Galaxy doc-truth path; not `/external/gogauth`)*
  - `POST /external/googleauth`
  - `POST /external/oculusauth`
  - `POST /external/openidauth`
  - `POST /external/psnauth`
  - `POST /external/steamauth`
  - `POST /external/switchauth`
  - `POST /external/udtauth`
  - `POST /external/xboxauth` *(Xbox Live doc-truth path; not `/external/xboxliveauth`)*
  - `GET /authenticate/terms`
  - `GET /agreements/types/{agreement-type-id}/current`
  - `GET /agreements/versions/{agreement-version-id}`
  - `GET /me`
  - `POST /oauth/logout`
  - `GET /ping`
- browse/content reads
  - `GET /games`
  - `GET /games/{game-id}`
  - `GET /games/{game-id}/stats`
  - `GET /games/{game-id}/tags`
  - `GET /games/{game-id}/monetization/token-packs`
  - `GET /games/{game-id}/mods`
  - `GET /games/{game-id}/mods/stats`
  - `POST /games/{game-id}/mods`
  - `GET /games/{game-id}/mods/{mod-id}`
  - `POST /games/{game-id}/mods/{mod-id}`
  - `DELETE /games/{game-id}/mods/{mod-id}`
  - `GET /games/{game-id}/mods/{mod-id}/files`
  - `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`
  - `GET /games/{game-id}/mods/{mod-id}/stats`
  - `GET /games/{game-id}/mods/{mod-id}/dependants`
  - `GET /games/{game-id}/mods/{mod-id}/tags`
  - `GET /games/{game-id}/mods/{mod-id}/metadatakvp`
  - `GET /games/{game-id}/mods/{mod-id}/team`
  - `GET /games/{game-id}/guides/tags`
- user inventory/profile/state reads + writes
  - `GET /me/games`
  - `GET /me/mods`
  - `GET /me/files`
  - `GET /me/subscribed`
  - `GET /me/wallets`
  - `GET /me/purchased`
  - `POST /me/entitlements`
  - `GET /games/{game-id}/mods/{mod-id}/monetization/team`
  - `POST /games/{game-id}/mods/{mod-id}/monetization/team`
  - `GET /me/ratings`
  - `POST /games/{game-id}/mods/{mod-id}/ratings`
  - `POST /report`
  - `POST /games/{game-id}/mods/{mod-id}/subscribe`
  - `DELETE /games/{game-id}/mods/{mod-id}/subscribe`
  - `POST /games/{game-id}/mods/{mod-id}/tags`
  - `DELETE /games/{game-id}/mods/{mod-id}/tags`
  - `POST /games/{game-id}/mods/{mod-id}/metadatakvp`
  - `DELETE /games/{game-id}/mods/{mod-id}/metadatakvp`
  - `POST /games/{game-id}/mods/{mod-id}/dependencies`
  - `DELETE /games/{game-id}/mods/{mod-id}/dependencies`
  - `POST /games/{game-id}/collections/{collection-id}/subscriptions`
  - `DELETE /games/{game-id}/collections/{collection-id}/subscriptions`
- mod + guide + collection community reads/writes
  - `POST /games/{game-id}/guides`
  - `POST /games/{game-id}/guides/{guide-id}`
  - `DELETE /games/{game-id}/guides/{guide-id}`
  - `POST /games/{game-id}/collections`
  - `POST /games/{game-id}/collections/{collection-id}`
  - `DELETE /games/{game-id}/collections/{collection-id}`
  - `GET /games/{game-id}/mods/{mod-id}/comments`
  - `GET /games/{game-id}/mods/{mod-id}/comments/{comment-id}`
  - `POST /games/{game-id}/mods/{mod-id}/comments`
  - `PUT /games/{game-id}/mods/{mod-id}/comments/{comment-id}`
  - `DELETE /games/{game-id}/mods/{mod-id}/comments/{comment-id}`
  - `POST /games/{game-id}/mods/{mod-id}/comments/{comment-id}/karma`
  - `GET /games/{game-id}/guides`
  - `GET /games/{game-id}/guides/{guide-id}`
  - `GET /games/{game-id}/guides/{guide-id}/comments`
  - `GET /games/{game-id}/guides/{guide-id}/comments/{comment-id}`
  - `POST /games/{game-id}/guides/{guide-id}/comments`
  - `PUT /games/{game-id}/guides/{guide-id}/comments/{comment-id}`
  - `DELETE /games/{game-id}/guides/{guide-id}/comments/{comment-id}`
  - `POST /games/{game-id}/guides/{guide-id}/comments/{comment-id}/karma`
  - `GET /games/{game-id}/collections`
  - `GET /games/{game-id}/collections/{collection-id}`
  - `GET /games/{game-id}/collections/{collection-id}/mods`
  - `GET /games/{game-id}/collections/{collection-id}/comments`
  - `GET /games/{game-id}/collections/{collection-id}/comments/{comment-id}`
  - `POST /games/{game-id}/collections/{collection-id}/comments`
  - `PUT /games/{game-id}/collections/{collection-id}/comments/{comment-id}`
  - `DELETE /games/{game-id}/collections/{collection-id}/comments/{comment-id}`
  - `POST /games/{game-id}/collections/{collection-id}/comments/{comment-id}/karma`
  - `POST /games/{game-id}/collections/{collection-id}/compatibility`
- user/profile/social/account-state reads + social mutation writes
  - `GET /users/{user-id}/followers`
  - `GET /users/{user-id}/following`
  - `GET /users/{user-id}/collections`
  - `GET /me/followers`
  - `GET /me/users/muted`
  - `GET /me/collections`
  - `GET /me/following/collections`
  - `POST /users/{user-id}/following`
  - `DELETE /users/{user-id}/following/{target-user-id}`
  - `POST /users/{user-id}/mute`
  - `DELETE /users/{user-id}/mute`
  - `POST /games/{game-id}/collections/{collection-id}/followers`
  - `DELETE /games/{game-id}/collections/{collection-id}/followers`
- response normalization seams
  - access token, logout/message, terms, agreement, user, game reads plus game media write, mod list/detail plus mod authoring writes, modfiles, mod stats, mod events feeds, mod dependants, mod tags, mod metadata KVP, mod team, mod monetization team reads/writes, mod comments, modfile CRUD writes, guide reads plus guide authoring writes, collection reads plus collection authoring writes and collection-mod delete, authenticated user inventory lists, user wallet/purchased/entitlement reads, user-social lists, user/account collection lists, user social mutation writes, user ratings, subscriptions, dependencies, and collection compatibility writes
  - documented page helpers derived from `result_count`, `result_offset`, `result_limit`, and `result_total`
  - structured error/rate-limit mapping including `retry-after`, auth exchange/OpenID/key/terms variants, `11008`, `11009`, `11017`, `11074`, `15025`, and `17053`
- artifact/cache metadata helpers
  - canonical artifact identity + stable cache keys based on `provider + game_id + mod_id + modfile.id`
  - game-policy interpretation from `api_access_options` and `dependency_option`
  - dependency-aware artifact resolution from mod detail, modfiles, and dependencies payloads
  - explicit recursive dependency request handling and metadata-only cacheability/expiry flags
- transport execution seam
  - `ModioHttpTransport.execute(...)` and `prepare_request(...)` for final URL/header/query/body assembly
  - explicit base-URL override handling, deterministic host fallback, no double-slash joins, and configurable api/game/user+sandbox host selection via `ModioClientConfig`
  - GET/POST/PUT/DELETE execution with form-encoded and multipart bodies, including truthful multipart file-part byte payloads, bearer-only authenticated writes, and no automatic retries

The wrapper now owns a **thin execution seam** in addition to request construction and normalization. The live transport remains intentionally narrow: it prepares and dispatches mod.io-specific HTTP requests, normalizes the response/error envelope, and keeps provider-only host/auth/header logic local to this repo so higher layers can compose it later without inheriting raw mod.io rules.

The current query model is intentionally endpoint-aware instead of emitting every filter everywhere.

Broadly speaking, the adapter includes large provider-side families such as event feeds, media, authoring CRUD, modfile/source upload flows, cook/platform-management, collection and guide authoring, monetization-user routes, checkout, monetization-team operations, and monetization-adjacent S2S routes. That breadth is useful for keeping the vendor seam truthful and centralized, but much of it should be read as **provider capability or deferred/internal support**, not as the approved AeroBeat v1 player-facing surface.

AeroBeat v1 specifically should continue to present a narrower, policy-aligned surface above this repo:

- public UGC release is governed by AeroBeat review policy, with mod.io acting as the v1 curation/gate system
- direct wallet / checkout / entitlement / monetization-team / S2S operations are adapter coverage, not proof that AeroBeat v1 exposes those flows broadly in product UX
- rich guide / collection / authoring / social mutation coverage here should be treated as internal seam completeness or future-phase support unless a higher-layer AeroBeat doc explicitly adopts it
- uploader/cook/platform-management support here should be read as provider plumbing, not as permission for broad in-game creator tooling in v1

The repo still documents the exact wrapped contracts where helpful: `POST /games/{game-id}/media` stays a bearer-authenticated `multipart/form-data` wrapper over only the documented `logo`, `icon`, `header`, and `redirect_uris` fields, requires truthful multipart file-part descriptors (`filename`, optional `content_type`, raw byte `data`) for the binary media fields, and normalizes the docs-shaped message payload on `200`; `POST /games/{game-id}/mods` and `POST /games/{game-id}/mods/{mod-id}` stay bearer-authenticated `multipart/form-data` wrappers with only the REST-documented field names, enum values, multipart file semantics, and the REST-required `metadata_kvp` input while encoding its multipart parts as the docs-specified `metadata[]` field name, while `DELETE /games/{game-id}/mods/{mod-id}` remains a bodyless `204` delete; `POST /games/{game-id}/mods/{mod-id}/files` stays bearer-authenticated `multipart/form-data` with documented-field validation only and an enforced `filedata` xor `upload_id` contract, `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` stays bearer-authenticated `application/x-www-form-urlencoded` with only `version`, `changelog`, `active`, and `metadata_blob`, `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` remains a bodyless `204` delete, `GET /games/{game-id}/mods/{mod-id}/sources` + `POST /games/{game-id}/mods/{mod-id}/sources` follow the refreshed REST docs instead of Unity/plugin drift, the multipart session family preserves the documented `filename`/optional `nonce` create contract plus explicit `upload_id` query semantics, and multipart part upload stays a raw-bytes `PUT` with required `Content-Range` plus optional opaque `Digest` header instead of inventing higher-level chunk orchestration. The newly added cook/platform slice stays thin and docs-first: `GET /games/{game-id}/mods/{mod-id}/cooks` returns normalized `Modfile Cook Object` lists, `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms` stays a raw bearer-authenticated `application/x-www-form-urlencoded` wrapper using the documented repeated `approved[]` / `denied[]` form body, and `POST /games/{game-id}/cloud-cooking/finalization` remains a bodyless bearer-authenticated `204` write. The mod media slice is equally literal: `POST /games/{game-id}/mods/{mod-id}/media` now accepts a generic `images` mapping that preserves arbitrary multipart field names while requiring truthful file-part descriptors (`filename`, optional `content_type`, raw byte `data`) for uploaded image payloads, `PUT /games/{game-id}/mods/{mod-id}/media/reorder` forwards only the documented `images[]`, `youtube[]`, and `sketchfab[]` form arrays with thin local validation, and `DELETE /games/{game-id}/mods/{mod-id}/media` preserves the documented repeated delete-array semantics with `204 No Content` normalization. The monetization-user slice is likewise intentionally thin and docs-first: `GET /me/wallets` preserves the documented `game_id` requirement and returns raw wallet fields like `type`, `currency`, `balance`, `pending_balance`, `deficit`, and `monetization_status` without AeroBeat convenience semantics; `GET /me/purchased` preserves the documented mod-list filters, `_sort` allowlist, and the platform-header caveat that `game_id` must accompany platform targeting; and `POST /me/entitlements` preserves the required `X-Modio-Portal` header plus the documented PSN-specific `X-Modio-Platform` and body requirements while returning only the minimal entitlement row shape. The mod monetization-team slice is kept equally literal: `GET /games/{game-id}/mods/{mod-id}/monetization/team` is bearer-authenticated and normalizes only the documented account rows (`id`, `name_id`, `username`, `monetization_status`, `monetization_options`, `split`), while `POST /games/{game-id}/mods/{mod-id}/monetization/team` stays bearer-authenticated `multipart/form-data` and serializes the documented nested `users` request as indexed form keys (`users[0][id]`, `users[0][split]`, ...). The refreshed REST docs and Unity corpus drift on content-type labeling here, so this seam follows the REST pages for transport shape but keeps the Unity-indexed key encoding because it matches the documented nested object contract instead of inventing a wrapper-specific body format. Checkout remains deliberately thin too: `POST /games/{game-id}/mods/{mod-id}/checkout` now wraps all documented checkout modes `0..4`, validates only the documented mode/portal-specific request fields, preserves the portal/platform header rules from the REST page, and stays product-policy-honest by documenting direct mod.io checkout as a provider capability and current working fit for some non-store-controlled distribution contexts rather than hardcoding store gating into the adapter. That route coverage should not be read as a settled AeroBeat paid-workout / DMCA / safe-harbor conclusion; the final provider-backed legal sufficiency of that workflow is still pending firmer confirmation. The monetization/auth-adjacent S2S slice is explicitly server-side/service-token shaped: `POST /s2s/transactions/intent`, `POST /s2s/transactions/commit`, `POST /s2s/transactions/clawback`, `DELETE /s2s/connections/{portal-id}`, `GET /s2s/monetization-teams/{monetization-team-id}/transactions`, and `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}` all read a distinct `service_token` from `ModioClientConfig` instead of reusing bearer-user assumptions; the disconnect wrapper stays a bodyless path-only `204` delete, and the history reads require an explicit `monetization_team_id` input/config rather than inferring it. `GET /games/{game-id}/mods/{mod-id}/events` now stays a public `GET` wrapper over only the documented path plus shared pagination filters, while `GET /games/{game-id}/mods/events` stays a thin `GET` wrapper over the documented `id`, `mod_id`, `user_id`, `date_added`, `event_type`, `latest`, and `subscribed` query fields, promoting the request to bearer-authenticated mode only when the docs-specific `subscribed=true` filter requires authenticated-user context and surfacing a local validation error instead of leaking `api_key` fallback if that filter is requested without an access token. Guide add/edit and collection add/update still execute as bearer-authenticated `multipart/form-data` requests with documented-field validation only, guide delete remains a bodyless `204` delete, collection delete remains `application/x-www-form-urlencoded` with optional `permanent`/`reason`, `DELETE /games/{game-id}/collections/{collection-id}/mods` stays a bearer-authenticated `application/x-www-form-urlencoded` wrapper requiring documented repeated `mod_ids[]` positive integers, and collection update preserves the documented `sync=true` + empty `mod_ids` remove-all semantics without importing file/media helpers, local file-path helpers, undocumented SDK-only cook upserts, release-workflow convenience helpers, or broader workflow behavior. `GET /games`, `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/mods/{mod-id}/files`, `GET /games/{game-id}/mods/{mod-id}/sources`, `GET /games/{game-id}/mods/{mod-id}/cooks`, `GET /games/{game-id}/mods/{mod-id}/dependants`, `GET /games/{game-id}/mods/{mod-id}/tags`, `GET /games/{game-id}/mods/{mod-id}/metadatakvp`, `GET /games/{game-id}/mods/{mod-id}/team`, `GET /games/{game-id}/mods/{mod-id}/comments`, `GET /games/{game-id}/guides`, `GET /games/{game-id}/guides/{guide-id}/comments`, `GET /games/{game-id}/collections`, `GET /games/{game-id}/collections/{collection-id}/mods`, `GET /games/{game-id}/collections/{collection-id}/comments`, `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections`, `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, `GET /me/following/collections`, `GET /me/subscribed`, `GET /me/wallets`, `GET /me/purchased`, and `GET /me/ratings` now serialize only the documented subset each wrapped endpoint should receive, while still preserving shared paging inputs where the docs allow them. Documented `_sort` allowlists are now enforced for games, authenticated user-game reads, mod listings, authenticated user-mod reads, guide listings, collection listings, collection-mod listings, authenticated subscriptions, and authenticated purchased-mod reads so undocumented sort keys do not leak through the wrapper. Platform-targeted `GET /me/subscribed` requests also continue to force the required `game_id` field, `GET /me/ratings` defaults to the mod-centric `resource_type=mods` seam while still preserving raw provider fields in normalized output, the catalog/game-meta/taxonomy utility slice now keeps `GET /games` filters scoped to the documented game-meta fields plus `show_hidden_tags`, the authenticated user inventory/profile read batch corrected the stale gap wording from `/users/{user-id}/games|mods|modfiles` to the current documented authenticated routes `/me/games`, `/me/mods`, and `/me/files`, with `/me/games` reusing the documented game filters, `/me/mods` limited to the documented user-mod fields (`tags`, metadata, ids, status/visibility, game/date/name/modfile, maturity/monetization, platform status, paging, sort), `/me/files` limited to the documented file fields (`id`, `mod_id`, `date_added`, `date_scanned`, virus/file metadata, metadata blob, platform status, paging), and `/me/purchased` limited to the documented purchased-mod fields (`id`, `game_id`, `status`, `visible`, `submitted_by`, dates, name fields, `modfile`, metadata, `tags`, `maturity_option`, `monetization_options`, `platform_status`, `platforms`, paging, sort). The mod-adjacent read enrichment slice keeps dependants + metadata reads paging-only, mod tags scoped to the documented `date_added` + `tag` filters, mod team reads scoped to the documented `id` / `user_id` / `username` / `level` / `date_added` / `pending` filters, upload-side request wrappers constrained to the documented auth/content-type/body/query/header contracts plus path-id validation, game-tag/game-guide-tag normalization preserves provider localization/count payloads without inventing higher-level taxonomy policy, collection list serialization includes the documented category/name/maturity filters plus collection-only sort keys, collection-mod requests preserve the documented paging + `_sort` inputs plus the collection-mod-specific `maturity_option` and `show_hidden_mods` filters, the read-only `/users` + `/me` social/account-state slice remains intentionally pagination-only (`_limit`, `_offset`) despite sharing the existing user/collection normalizers, and the social-mutation write slice now stays bearer-only: follow-user sends the documented redundant form body `user_id`, user unfollow/mute/unmute plus collection unfollow normalize as `204 No Content`, collection follow preserves `already_followed := (status == 200)` plus any `Location` header while normalizing the returned collection object, and collection subscribe/unsubscribe stay bodyless bearer-only writes that normalize the returned `Mod Collection Object` without importing SDK-local install/update/uninstall orchestration or undocumented `include_dependencies` behavior into this vendor seam. The newly added mod-maintenance family stays equally thin and docs-first: tags add/delete preserve repeated `tags[]` form fields and bearer-authenticated `POST`/`DELETE` transport exactly as documented, metadata KVP add/delete preserves repeated `metadata[]` form fields including the REST-documented key-only delete behavior (`metadata[]=key` removes all values for that key), and dependency add/delete preserves repeated `dependencies[]` integer fields with the documented optional `sync` boolean on add only. The refreshed local corpus also confirmed that the drifted `/me/iap/*/sync` family is not stable enough across docs/SDK/Unity references to wrap confidently in this slice, so those routes stay intentionally deferred instead of partially inferred; partner-team / partner-program work also remains out of scope. The S2S history pages also drift in two notable ways, both documented in this seam: the refreshed GET pages describe filter fields under a request-body schema even though the transport shape is query-string based, and the list page labels its pagination envelope as `download`, which this adapter preserves verbatim while also aliasing to `pagination`. Integration-style tests validate the final encoded URLs, final headers, form bodies, and raw-byte multipart body assembly that the transport would execute.

## Download URL stance

mod.io `binary_url` values are treated as **expiring delivery URLs**, not canonical file identities.

The wrapper therefore:

- resolves downloads from modfile metadata instead of exposing a fake stable download endpoint contract
- preserves `date_expires`, hash, filename, and file identifiers
- marks resolved download URLs as non-canonical so higher layers do not use them as durable cache keys

This follows the current official mod.io docs note that hashed download URLs can expire and should not be saved/reused as if they were permanent.

## Ratings/reporting notes

The current mod.io docs and generated refs are a little uneven around ratings. The repo-local seam therefore preserves the raw provider `rating` integer exactly as returned/sent, and only derives convenience booleans/sentiment around it. Tests cover the currently documented and SDK-backed mod rating values of `1` and `-1`, without pretending the provider contract is cleaner than it is.

Game-level capability interpretation now also exposes `community_policy.allows_negative_ratings`, so higher layers can make decisions from the documented `community_options` bitfield without moving that provider logic upstream.

## Source layout

```text
src/
├── AeroModIOManager.gd
├── modio_vendor_adapter.gd
├── models/
│   ├── modio_client_config.gd
│   ├── modio_download_request.gd
│   └── modio_listing_query.gd
└── network/
    └── modio_http_transport.gd
```

- `AeroModIOManager.gd` is the repo-owned/vendor-facing facade for downstream composition inside AeroBeat tooling. It owns config + transport wiring and keeps `ModioVendorAdapter` behind a clearer package seam.
- `modio_vendor_adapter.gd` remains the internal/provider-facing seam with the full docs-first request-builder + normalization surface.
- `models/` holds provider-local config and request/download/query DTOs.
- `network/` holds transport helpers that remain mod.io-specific.

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local validation/tests: `.testbed/tests/`
- Repo package mount: `.testbed/addons/aerobeat-vendor-modio -> ../`

The repo root remains the published package boundary. Development and validation happen from the hidden `.testbed/` project.

### Private mod.io config (testbed only)

Local credentials live in `.testbed/configs/` and are **ignored by git**. Copy the templates and fill in your real values:

```bash
cp .testbed/configs/modio.local.example.cfg .testbed/configs/modio.local.cfg
cp .testbed/configs/modio.session.local.example.cfg .testbed/configs/modio.session.local.cfg
```

Environment selection precedence (first match wins):

1. explicit harness argument `--env test|live`
2. `MODIO_ENV=test|live`
3. `.testbed/configs/modio.session.local.cfg` `[modio] environment`
4. `.testbed/configs/modio.local.cfg` `[modio] default_environment`
5. fallback to `test`

Only `test` and `live` are supported. Leave `base_url` blank unless you are intentionally overriding host resolution.

Paid-mods harness inputs are split intentionally:

- stable cfg (`modio.local.cfg`): long-lived environment facts like `service_token`, `monetization_team_id`, `owned_mod_id`, and `paid_mod_id`
- session cfg (`modio.session.local.cfg`): ephemeral per-run values like `access_token`, `user_id`, `entitlements_payload_json`, `checkout_payload_json`, `s2s_filters_json`, `s2s_transaction_id`, and S2S delegation/idempotent keys
- each `*_payload_json` value should be a JSON object; for entitlements/checkout, keep `portal` / `platform` at the top level and put the raw request body under `fields`, for example `{"portal":"epicgames","fields":{...}}`
- the default Workout Browser scene reads Game ID + API key from `modio.local.cfg`, reads the selected environment / athlete email / access token / user id from `modio.session.local.cfg`, writes updated auth/session values back into `modio.session.local.cfg`, auto-loads the public catalog on reopen when public config is present, and attempts a truthful `/me` + wallet + purchase-history refresh when a stored token exists

### Scene-based proving surface

The hidden `.testbed/` project now has a default operator-facing Workout Browser scene plus the older focused smoke-test entrypoints.

- `.testbed/scenes/workout_browser.tscn`
  - default `.testbed` entrypoint with editable `Test|Live` server target, Game ID, API Key, email-code athlete auth, profile summary, public browse, athlete browse, subscribed-workout pagination, and subscribe/unsubscribe detail CTAs
- `.testbed/scenes/public_catalog_testbed.tscn`
  - focused smoke scene for public connectivity + catalog/detail reads
- `.testbed/scenes/authenticated_user_testbed.tscn`
  - focused smoke scene for authenticated `/me` + user-state reads
- `.testbed/scenes/safe_write_testbed.tscn`
  - focused smoke scene for reversible low-risk sandbox writes (subscribe / unsubscribe / positive rating)
- `.testbed/scenes/paid_mods_testbed.tscn`
  - focused smoke scene for paid-mod reads plus guarded paid/team/S2S posture notes
- shared smoke-scene behavior lives in `.testbed/scripts/modio_scene_runner.gd`
- Workout Browser controller/state helpers live in `.testbed/scripts/modio_workout_browser_testbed.gd`, `.testbed/scripts/modio_workout_browser_state.gd`, and `.testbed/scripts/modio_session_config_store.gd`

Open the default scene by running the `.testbed/` project normally, or open any individual smoke scene directly from the `.testbed/` editor project.

### Run the safe live harness

From the repo root:

```bash
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --help
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --json
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --json
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --paid-mods --allow-paid-writes --json
godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- --env live --json
```

What it does on the first pass:

1. loads the selected `test` or `live` tuple through `ModioEnvLoader`
2. prints the resolved environment/base URL/host kind so you can confirm the target before requests fire
3. runs only non-destructive checks:
   - `GET /ping` using the selected public tuple for real-service connectivity validation
   - `GET /games/{game-id}`
   - `GET /games/{game-id}/mods` with a small limit (default `3`)
   - when a public mod exists, drills into the first returned mod for detail/files/file-detail/stats/dependants/tags/metadatakvp/team/dependencies
   - `GET /authenticate/terms`
   - optional authenticated user-read sweep when `modio.session.local.cfg` contains an `access_token`: `GET /me`, `/me/games`, `/me/mods`, `/me/files`, `/me/subscribed`, `/me/ratings`, `/me/collections`, `/me/following/collections`, `/me/followers`, `/me/users/muted`, plus derived `/users/{me-id}/followers`, `/users/{me-id}/following`, and `/users/{me-id}/collections`
4. when `--paid-mods` is enabled, also exercises the paid-mods matrix the harness can truthfully support today:
   - bearer reads: `GET /games/{game-id}/monetization/token-packs`, `GET /me/wallets`, `GET /me/purchased`
   - owned paid-mod read: `GET /games/{game-id}/mods/{owned_mod_id}/monetization/team`
   - guarded writes: `POST /me/entitlements`, `POST /games/{game-id}/mods/{paid_mod_id}/checkout`
   - service-token reads: `GET /s2s/monetization-teams/{monetization-team-id}/transactions`, then detail via configured or discovered `transaction_id`
5. exits non-zero on any failed network check or if the selected environment is missing the required public tuple (`game_id`, `api_key`)

Safety notes:

- `test` remains the default target unless you explicitly select `live`
- `--public-only` forces the harness to skip the optional authenticated user-read sweep even when a token is present
- `--paid-mods` opt-ins the monetization validation slice; guarded entitlements/checkout writes still stay skipped unless `--allow-paid-writes` is also passed
- monetization-team writes plus S2S intent/commit/clawback remain harness placeholders today: `--allow-paid-team-write` and `--allow-paid-s2s-writes` currently reserve those opt-in lanes for future wiring, but do not execute the writes yet
- the harness currently stops at `GET /authenticate/terms` for agreement coverage because the test-sandbox terms payload does not expose agreement type/version ids to chain into the agreement-detail routes automatically
- real secrets stay in ignored `.testbed/configs/*.local.cfg` files only

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

Baseline dev/test dependencies stay narrow: `aerobeat-tool-core` plus `gut`.

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

The project now defaults to `res://scenes/workout_browser.tscn`.
You can still open the dedicated scene entrypoints directly when you want a narrow smoke pass:

- `res://scenes/workout_browser.tscn`
- `res://scenes/public_catalog_testbed.tscn`
- `res://scenes/authenticated_user_testbed.tscn`
- `res://scenes/safe_write_testbed.tscn`
- `res://scenes/paid_mods_testbed.tscn`

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run the scaffold validation

From the repo root:

```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
godot --headless --path .testbed --script res://tests/validate_modio_testbed_scenes.gd
```

### Run the fixture-driven wrapper tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## References used for the current implementation

- research note: [`.testbed/docs/modio-rest-api-research-2026-05-02.md`](.testbed/docs/modio-rest-api-research-2026-05-02.md)
- seam plan: [`.testbed/docs/modio-seam-plan.md`](.testbed/docs/modio-seam-plan.md)
- primary local docs mirror: `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
- official behavior sanity references:
  - `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
  - `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`

## Seam plan

See [`.testbed/docs/modio-seam-plan.md`](.testbed/docs/modio-seam-plan.md).
