# AeroBeat Vendor - mod.io

`aerobeat-vendor-modio` is the provider-specific **mod.io adapter** package behind `aerobeat-tool-api`.

It is **not** the public AeroBeat-facing API singleton and it is **not** a product/assembly integration surface. Product repos should depend on `aerobeat-tool-api`, which can compose this repo behind a stable AeroBeat-shaped contract.

This repo exists to keep mod.io-specific concerns local, replaceable, and out of gameplay/UI repos.

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

This slice now implements a fixture-driven REST wrapper for the current researched mod.io surface:

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
  - `GET /games/{game-id}/mods/{mod-id}`
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
  - access token, logout/message, terms, agreement, user, game, mod list/detail, modfiles, mod stats, mod dependants, mod tags, mod metadata KVP, mod team, mod monetization team reads/writes, mod comments, modfile CRUD writes, guide reads plus guide authoring writes, collection reads plus collection authoring writes, authenticated user inventory lists, user wallet/purchased/entitlement reads, user-social lists, user/account collection lists, user social mutation writes, user ratings, subscriptions, dependencies, and collection compatibility writes
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
  - GET/POST/PUT/DELETE execution with form-encoded and multipart bodies, bearer-only authenticated writes, and no automatic retries

The wrapper now owns a **thin execution seam** in addition to request construction and normalization. The live transport remains intentionally narrow: it prepares and dispatches mod.io-specific HTTP requests, normalizes the response/error envelope, and keeps provider-only host/auth/header logic local to this repo so higher layers can compose it later without inheriting raw mod.io rules.

The current query model is intentionally endpoint-aware instead of emitting every filter everywhere. The write seam now also includes the documented modfile CRUD slice, the full source-modfile + multipart upload/session family, the cook/platform-management slice, the guide + collection authoring family, the authenticated monetization-user slice, the newly approved mod monetization-team slice, and the newly approved checkout + monetization S2S slice: `POST /games/{game-id}/mods/{mod-id}/files` stays bearer-authenticated `multipart/form-data` with documented-field validation only and an enforced `filedata` xor `upload_id` contract, `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` stays bearer-authenticated `application/x-www-form-urlencoded` with only `version`, `changelog`, `active`, and `metadata_blob`, `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` remains a bodyless `204` delete, `GET /games/{game-id}/mods/{mod-id}/sources` + `POST /games/{game-id}/mods/{mod-id}/sources` follow the refreshed REST docs instead of Unity/plugin drift, the multipart session family preserves the documented `filename`/optional `nonce` create contract plus explicit `upload_id` query semantics, and multipart part upload stays a raw-bytes `PUT` with required `Content-Range` plus optional opaque `Digest` header instead of inventing higher-level chunk orchestration. The newly added cook/platform slice stays thin and docs-first: `GET /games/{game-id}/mods/{mod-id}/cooks` returns normalized `Modfile Cook Object` lists, `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms` stays a raw bearer-authenticated `application/x-www-form-urlencoded` wrapper using the documented repeated `approved[]` / `denied[]` form body, and `POST /games/{game-id}/cloud-cooking/finalization` remains a bodyless bearer-authenticated `204` write. The monetization-user slice is likewise intentionally thin and docs-first: `GET /me/wallets` preserves the documented `game_id` requirement and returns raw wallet fields like `type`, `currency`, `balance`, `pending_balance`, `deficit`, and `monetization_status` without AeroBeat convenience semantics; `GET /me/purchased` preserves the documented mod-list filters, `_sort` allowlist, and the platform-header caveat that `game_id` must accompany platform targeting; and `POST /me/entitlements` preserves the required `X-Modio-Portal` header plus the documented PSN-specific `X-Modio-Platform` and body requirements while returning only the minimal entitlement row shape. The mod monetization-team slice is kept equally literal: `GET /games/{game-id}/mods/{mod-id}/monetization/team` is bearer-authenticated and normalizes only the documented account rows (`id`, `name_id`, `username`, `monetization_status`, `monetization_options`, `split`), while `POST /games/{game-id}/mods/{mod-id}/monetization/team` stays bearer-authenticated `multipart/form-data` and serializes the documented nested `users` request as indexed form keys (`users[0][id]`, `users[0][split]`, ...). The refreshed REST docs and Unity corpus drift on content-type labeling here, so this seam follows the REST pages for transport shape but keeps the Unity-indexed key encoding because it matches the documented nested object contract instead of inventing a wrapper-specific body format. Checkout remains deliberately thin too: `POST /games/{game-id}/mods/{mod-id}/checkout` now wraps all documented checkout modes `0..4`, validates only the documented mode/portal-specific request fields, preserves the portal/platform header rules from the REST page, and stays product-policy-honest by documenting direct mod.io checkout as a current non-store / web / PC seam rather than hardcoding store gating into the adapter. The monetization S2S slice is explicitly server-side/service-token shaped: `POST /s2s/transactions/intent`, `POST /s2s/transactions/commit`, `POST /s2s/transactions/clawback`, `GET /s2s/monetization-teams/{monetization-team-id}/transactions`, and `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}` all read a distinct `service_token` from `ModioClientConfig` instead of reusing bearer-user assumptions, and the history reads require an explicit `monetization_team_id` input/config rather than inferring it. Guide add/edit and collection add/update still execute as bearer-authenticated `multipart/form-data` requests with documented-field validation only, guide delete remains a bodyless `204` delete, collection delete remains `application/x-www-form-urlencoded` with optional `permanent`/`reason`, and collection update preserves the documented `sync=true` + empty `mod_ids` remove-all semantics without importing file/media helpers, local file-path helpers, undocumented SDK-only cook upserts, release-workflow convenience helpers, or broader workflow behavior. `GET /games`, `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/mods/{mod-id}/files`, `GET /games/{game-id}/mods/{mod-id}/sources`, `GET /games/{game-id}/mods/{mod-id}/cooks`, `GET /games/{game-id}/mods/{mod-id}/dependants`, `GET /games/{game-id}/mods/{mod-id}/tags`, `GET /games/{game-id}/mods/{mod-id}/metadatakvp`, `GET /games/{game-id}/mods/{mod-id}/team`, `GET /games/{game-id}/mods/{mod-id}/comments`, `GET /games/{game-id}/guides`, `GET /games/{game-id}/guides/{guide-id}/comments`, `GET /games/{game-id}/collections`, `GET /games/{game-id}/collections/{collection-id}/mods`, `GET /games/{game-id}/collections/{collection-id}/comments`, `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections`, `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, `GET /me/following/collections`, `GET /me/subscribed`, `GET /me/wallets`, `GET /me/purchased`, and `GET /me/ratings` now serialize only the documented subset each wrapped endpoint should receive, while still preserving shared paging inputs where the docs allow them. Documented `_sort` allowlists are now enforced for games, authenticated user-game reads, mod listings, authenticated user-mod reads, guide listings, collection listings, collection-mod listings, authenticated subscriptions, and authenticated purchased-mod reads so undocumented sort keys do not leak through the wrapper. Platform-targeted `GET /me/subscribed` requests also continue to force the required `game_id` field, `GET /me/ratings` defaults to the mod-centric `resource_type=mods` seam while still preserving raw provider fields in normalized output, the catalog/game-meta/taxonomy utility slice now keeps `GET /games` filters scoped to the documented game-meta fields plus `show_hidden_tags`, the authenticated user inventory/profile read batch corrected the stale gap wording from `/users/{user-id}/games|mods|modfiles` to the current documented authenticated routes `/me/games`, `/me/mods`, and `/me/files`, with `/me/games` reusing the documented game filters, `/me/mods` limited to the documented user-mod fields (`tags`, metadata, ids, status/visibility, game/date/name/modfile, maturity/monetization, platform status, paging, sort), `/me/files` limited to the documented file fields (`id`, `mod_id`, `date_added`, `date_scanned`, virus/file metadata, metadata blob, platform status, paging), and `/me/purchased` limited to the documented purchased-mod fields (`id`, `game_id`, `status`, `visible`, `submitted_by`, dates, name fields, `modfile`, metadata, `tags`, `maturity_option`, `monetization_options`, `platform_status`, `platforms`, paging, sort). The mod-adjacent read enrichment slice keeps dependants + metadata reads paging-only, mod tags scoped to the documented `date_added` + `tag` filters, mod team reads scoped to the documented `id` / `user_id` / `username` / `level` / `date_added` / `pending` filters, upload-side request wrappers constrained to the documented auth/content-type/body/query/header contracts plus path-id validation, game-tag/game-guide-tag normalization preserves provider localization/count payloads without inventing higher-level taxonomy policy, collection list serialization includes the documented category/name/maturity filters plus collection-only sort keys, collection-mod requests preserve the documented paging + `_sort` inputs plus the collection-mod-specific `maturity_option` and `show_hidden_mods` filters, the read-only `/users` + `/me` social/account-state slice remains intentionally pagination-only (`_limit`, `_offset`) despite sharing the existing user/collection normalizers, and the social-mutation write slice now stays bearer-only: follow-user sends the documented redundant form body `user_id`, user unfollow/mute/unmute plus collection unfollow normalize as `204 No Content`, collection follow preserves `already_followed := (status == 200)` plus any `Location` header while normalizing the returned collection object, and collection subscribe/unsubscribe stay bodyless bearer-only writes that normalize the returned `Mod Collection Object` without importing SDK-local install/update/uninstall orchestration or undocumented `include_dependencies` behavior into this vendor seam. The refreshed local corpus also confirmed that the drifted `/me/iap/*/sync` family is not stable enough across docs/SDK/Unity references to wrap confidently in this slice, so those routes stay intentionally deferred instead of partially inferred; partner-team / partner-program work also remains out of scope. The S2S history pages also drift in two notable ways, both documented in this seam: the refreshed GET pages describe filter fields under a request-body schema even though the transport shape is query-string based, and the list page labels its pagination envelope as `download`, which this adapter preserves verbatim while also aliasing to `pagination`. Integration-style tests validate the final encoded URLs, final headers, form bodies, and raw-byte multipart body assembly that the transport would execute.

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
├── modio_vendor_adapter.gd
├── models/
│   ├── modio_client_config.gd
│   ├── modio_download_request.gd
│   └── modio_listing_query.gd
└── network/
    └── modio_http_transport.gd
```

- `modio_vendor_adapter.gd` is the provider-facing entry seam for future composition by `aerobeat-tool-api`.
- `models/` holds provider-local config and request/download/query DTOs.
- `network/` holds transport helpers that remain mod.io-specific.

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local validation/tests: `.testbed/tests/`
- Repo package bridge: `.testbed/src -> ../src`

The repo root remains the published package boundary. Development and validation happen from the hidden `.testbed/` project.

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

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run the scaffold validation

From the repo root:

```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
```

### Run the fixture-driven wrapper tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## References used for the current implementation

- research note: [`docs/modio-rest-api-research-2026-05-02.md`](docs/modio-rest-api-research-2026-05-02.md)
- seam plan: [`docs/modio-seam-plan.md`](docs/modio-seam-plan.md)
- primary local docs mirror: `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
- official behavior sanity references:
  - `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
  - `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`

## Seam plan

See [`docs/modio-seam-plan.md`](docs/modio-seam-plan.md).
