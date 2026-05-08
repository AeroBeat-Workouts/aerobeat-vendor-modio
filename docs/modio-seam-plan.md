# mod.io seam plan

This document captures the first implementation-ready seam for real mod.io integration work in `aerobeat-vendor-modio`.

## Purpose

Keep **provider-native** concerns in this repo while allowing `aerobeat-tool-api` to compose the adapter behind an AeroBeat-facing API-manager surface.

This seam document is intentionally broader than the currently approved AeroBeat v1 product surface. It records what the mod.io adapter can truthfully wrap, not what AeroBeat v1 is automatically allowed to expose in gameplay/UI, creator UX, or commerce UX.

## Seam boundaries

### This repo should own

- mod.io request construction
- auth/session request-shape support for email, OpenID, and documented external provider flows (Apple, Discord, Epic Games, GOG Galaxy, Google, Meta Quest/Oculus, PSN, Steam, Switch, UDT, and Xbox Live)
- provider listing/search/detail/dependency query mapping
- endpoint-aware filter serialization per wrapped endpoint
- provider subscription/user-state mapping via `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/subscribed`, `GET /me/wallets`, `GET /me/purchased`, `POST /me/entitlements`, `GET /me/ratings`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, and `GET /me/following/collections`
- provider monetization-team transport/query/normalization via bearer-authenticated `GET /games/{game-id}/mods/{mod-id}/monetization/team` and `POST /games/{game-id}/mods/{mod-id}/monetization/team`
- provider mod + guide + collection community transport/query/normalization via `GET/POST/PUT/DELETE /games/{game-id}/mods/{mod-id}/comments...`, `GET /games/{game-id}/guides...`, guide authoring (`POST /games/{game-id}/guides`, `POST /games/{game-id}/guides/{guide-id}`, `DELETE /games/{game-id}/guides/{guide-id}`), `GET /games/{game-id}/collections...`, collection authoring (`POST /games/{game-id}/collections`, `POST /games/{game-id}/collections/{collection-id}`, `DELETE /games/{game-id}/collections/{collection-id}`), read-only `GET /users/{user-id}/followers|following|collections`, and bearer-only social mutation writes for user follow/unfollow, mute/unmute, and collection follow/unfollow
- provider mod maintenance writes for `POST/DELETE /games/{game-id}/mods/{mod-id}/tags`, `POST/DELETE /games/{game-id}/mods/{mod-id}/metadatakvp`, and `POST/DELETE /games/{game-id}/mods/{mod-id}/dependencies`
- provider rating/report writes via `POST /games/{game-id}/mods/{mod-id}/ratings`, `POST /games/{game-id}/mods/{mod-id}/comments/{comment-id}/karma`, `POST /games/{game-id}/guides/{guide-id}/comments/{comment-id}/karma`, `POST /games/{game-id}/collections/{collection-id}/comments/{comment-id}/karma`, `POST /games/{game-id}/collections/{collection-id}/compatibility`, and `POST /report`
- provider download metadata resolution from `modfile.download`
- canonical artifact/cache metadata resolution derived from `provider + game_id + mod_id + modfile.id`
- provider DTO parsing, page-state helpers, and error normalization
- thin HTTP transport execution for mod.io-specific endpoints
- read-only catalog/game-meta/taxonomy utility coverage for game listing, game stats, game tag options, guide tags, ping, agreement version lookup, and read-only token-pack discovery
- mod-adjacent read enrichment coverage for mod dependants, mod tags, mod metadata KVP, and mod team reads

### This repo should not own

- AeroBeat trust approval policy
- public product-facing singleton contracts
- gameplay/UI integration behavior
- canonical content identity beyond provider-to-AeroBeat mapping helpers
- install orchestration decisions above the provider seam
- the final decision that a wrapped provider capability belongs in the approved AeroBeat v1 product surface

For the current AeroBeat v1 policy lock, broad wrapped families such as wallet/checkout, direct entitlements, monetization-team operations, S2S monetization flows, rich authoring/CMS routes, social mutation, and cook/platform-management should be treated as provider seam coverage, deferred scope, or internal/operator support unless higher-layer AeroBeat docs explicitly adopt them.

## Implemented code seam

The current slice now exposes a larger request-builder and normalization seam:

- `ModioVendorAdapter`
  - auth/session request builders
    - `build_email_security_code_request(...)`
    - `build_auth_exchange_request(...)`
    - `build_apple_auth_request(...)`
    - `build_discord_auth_request(...)`
    - `build_epic_games_auth_request(...)`
    - `build_gog_galaxy_auth_request(...)`
    - `build_google_auth_request(...)`
    - `build_oculus_auth_request(...)`
    - `build_openid_auth_request(...)`
    - `build_psn_auth_request(...)`
    - `build_steam_auth_request(...)`
    - `build_switch_auth_request(...)`
    - `build_udt_auth_request(...)`
    - `build_xbox_live_auth_request(...)`
    - `build_terms_request()`
    - `build_current_agreement_request(...)`
    - `build_authenticated_user_request(...)`
    - `build_logout_request()`
  - browse/detail/dependency request builders
    - `build_game_request(...)`
    - `build_listing_request(...)`
    - `build_mod_detail_request(...)`
    - `build_modfiles_request(...)`
    - `build_modfile_request(...)`
    - `build_mod_stats_request(...)`
    - `build_dependants_request(...)`
    - `build_mod_tags_request(...)`
    - `build_mod_metadata_kvp_request(...)`
    - `build_mod_team_request(...)`
    - `build_add_mod_tags_request(...)`
    - `build_delete_mod_tags_request(...)`
    - `build_add_mod_metadata_kvp_request(...)`
    - `build_delete_mod_metadata_kvp_request(...)`
    - `build_add_mod_dependencies_request(...)`
    - `build_delete_mod_dependencies_request(...)`
    - `build_collections_request(...)`
    - `build_collection_request(...)`
    - `build_add_collection_request(...)`
    - `build_update_collection_request(...)`
    - `build_delete_collection_request(...)`
    - `build_collection_mods_request(...)`
    - `build_user_games_request(...)`
    - `build_user_mods_request(...)`
    - `build_user_modfiles_request(...)`
    - `build_user_followers_request(...)`
    - `build_user_following_request(...)`
    - `build_user_collections_request(...)`
    - `build_me_followers_request(...)`
    - `build_muted_users_request(...)`
    - `build_me_collections_request(...)`
    - `build_followed_collections_request(...)`
    - `build_guides_request(...)`
    - `build_guide_detail_request(...)`
    - `build_add_guide_request(...)`
    - `build_update_guide_request(...)`
    - `build_delete_guide_request(...)`
    - `build_dependencies_request(...)`
  - subscription/user-rating/report/comment/social-mutation request builders
    - `build_user_subscriptions_request(...)`
    - `build_user_wallet_request(...)`
    - `build_user_purchased_request(...)`
    - `build_user_entitlements_request(...)`
    - `build_mod_monetization_team_request(...)`
    - `build_create_mod_monetization_team_request(...)`
    - `build_user_ratings_request(...)`
    - `build_follow_user_request(...)`
    - `build_unfollow_user_request(...)`
    - `build_mute_user_request(...)`
    - `build_unmute_user_request(...)`
    - `build_follow_collection_request(...)`
    - `build_unfollow_collection_request(...)`
    - `build_subscribe_collection_request(...)`
    - `build_unsubscribe_collection_request(...)`
    - `build_add_mod_rating_request(...)`
    - `build_mod_comments_request(...)`
    - `build_mod_comment_request(...)`
    - `build_add_mod_comment_request(...)`
    - `build_update_mod_comment_request(...)`
    - `build_delete_mod_comment_request(...)`
    - `build_add_mod_comment_karma_request(...)`
    - `build_guide_comments_request(...)`
    - `build_guide_comment_request(...)`
    - `build_add_guide_comment_request(...)`
    - `build_update_guide_comment_request(...)`
    - `build_delete_guide_comment_request(...)`
    - `build_add_guide_comment_karma_request(...)`
    - `build_collection_comments_request(...)`
    - `build_collection_comment_request(...)`
    - `build_add_collection_comment_request(...)`
    - `build_update_collection_comment_request(...)`
    - `build_delete_collection_comment_request(...)`
    - `build_add_collection_comment_karma_request(...)`
    - `build_add_collection_compatibility_request(...)`
    - `build_submit_report_request(...)`
    - `build_subscribe_request(...)`
    - `build_unsubscribe_request(...)`
  - normalization helpers
    - auth/logout/message/user/game/games/game-stats/game-tags/game-token-packs/game-mod-stats/guide-tags/mod/modfile/mod-stats/mod-dependants/mod-tags/mod-metadata-kvp/mod-team/mod-tag write/mod-metadata write/mod-dependency write/mod-monetization-team/mod-comment/guide/guide-comment/collection/collection-comment/user-inventory list/user-wallet/user-purchased/user-entitlement/user-social list/user-collection list/user-social mutation/user-ratings/subscription/dependency/report/collection-compatibility responses
    - page-state helpers derived from `result_count`, `result_offset`, `result_limit`, and `result_total`
    - no-content write responses plus subscription and collection-follow write responses
    - download metadata resolution helpers
    - artifact/cache metadata resolution + dedupe helpers
- `ModioHttpTransport`
  - normalized request-dictionary builder
  - `prepare_request(...)` for final URL/query/header/body assembly
  - `execute(...)` for thin GET/POST/DELETE dispatch via injected executor or the built-in HTTP client path
  - structured error/rate-limit normalization seam
- provider-local models under `src/models/`
  - `ModioClientConfig`
  - `ModioListingQuery`
  - `ModioDownloadRequest`

## Download seam decision

For AeroBeat's current slice, this repo does **not** expose a fake stable `/download` provider abstraction.

Instead it:

- resolves downloads from modfile payloads returned by `GET /games/{game-id}/mods/{mod-id}`, `GET /games/{game-id}/mods/{mod-id}/files`, or dependency payloads from `GET /games/{game-id}/mods/{mod-id}/dependencies`
- derives a canonical artifact/cache identity from `provider + game_id + mod_id + modfile.id`
- preserves `binary_url`, `date_expires`, hash, filename, dependency depth, and game download-policy bits as transport/cache metadata
- explicitly marks the resolved URL as non-canonical because current mod.io docs state hashed URLs can expire and should not be saved/reused as stable identifiers
- records recursive dependency intent explicitly because the official docs warn the endpoint's default recursion behavior will change in a future API version

That keeps transient CDN delivery behavior local to the vendor seam and out of AeroBeat's higher-level identity/trust decisions.

## Query/auth stance

- public/read flows default to query-based `api_key` injection
- authenticated `GET /me`, `GET /me/games`, `GET /me/mods`, `GET /me/files`, `GET /me/subscribed`, `GET /me/wallets`, `GET /me/purchased`, `POST /me/entitlements`, `GET /games/{game-id}/mods/{mod-id}/monetization/team`, `POST /games/{game-id}/mods/{mod-id}/monetization/team`, `POST /games/{game-id}/mods/{mod-id}/checkout`, `GET /games/{game-id}/monetization/token-packs`, logout, subscription writes, collection-subscription writes, and the social-mutation writes (`POST/DELETE /users/{user-id}/following...`, `POST/DELETE /users/{user-id}/mute`, `POST/DELETE /games/{game-id}/collections/{collection-id}/followers`) require bearer-token headers
- monetization/auth-adjacent server-to-server routes (`POST /s2s/transactions/intent`, `POST /s2s/transactions/commit`, `POST /s2s/transactions/clawback`, `DELETE /s2s/connections/{portal-id}`, `GET /s2s/monetization-teams/{monetization-team-id}/transactions`, `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}`) require a separate service-side bearer token and intentionally do not reuse the ordinary user access-token helpers
- endpoint query serialization is intentionally capability-gated so unsupported filters do not leak onto the wrong wrapped endpoint
- `GET /games` now serializes only the current documented game listing filters (`id`, `status`, `submitted_by`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `summary`, `instructions_url`, `ugc_name`, `presentation_option`, `submission_option`, `curation_option`, `profanity_option`, `dependency_option`, `community_options`, `monetization_options`, `api_access_options`, `maturity_options`, `show_hidden_tags`) plus paging and the current documented game sort keys
- `GET /games/{game-id}/mods/stats` now serializes only paging plus the documented optional `mod_id` filter
- `GET /games/{game-id}/mods/{mod-id}/dependants` and `GET /games/{game-id}/mods/{mod-id}/metadatakvp` now serialize paging only (`_limit`, `_offset`)
- `GET /games/{game-id}/mods/{mod-id}/tags` now serializes only the documented `date_added` and `tag` filters plus paging
- `GET /games/{game-id}/mods/{mod-id}/team` now serializes only the documented `id`, `user_id`, `username`, `level`, `date_added`, and `pending` filters plus paging
- the approved mod-maintenance write seam stays thin and docs-first: `POST/DELETE /games/{game-id}/mods/{mod-id}/tags` preserve repeated `tags[]` form fields, `POST/DELETE /games/{game-id}/mods/{mod-id}/metadatakvp` preserve repeated `metadata[]` form fields including the REST-documented key-only delete behavior, and `POST/DELETE /games/{game-id}/mods/{mod-id}/dependencies` preserve repeated `dependencies[]` integer fields with the documented optional `sync` boolean on add only
- the refreshed local corpus corrected the stale gap wording for authenticated user inventory/profile reads: this seam wraps `/me/games`, `/me/mods`, and `/me/files`, not undocumented `/users/{user-id}/games|mods|modfiles` aliases
- `GET /me/games` now serializes only the current documented game filters (`id`, `status`, `submitted_by`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `summary`, `instructions_url`, `ugc_name`, `presentation_option`, `submission_option`, `curation_option`, `profanity_option`, `dependency_option`, `community_options`, `monetization_options`, `api_access_options`, `maturity_options`, `show_hidden_tags`) plus paging and the current documented game sort keys
- `GET /me/mods` now serializes only the documented authenticated user-mod filters (`tags`, `metadata_blob`, `metadata_kvp`, `id`, `name_id`, `status`, `visible`, `submitted_by`, `game_id`, `date_added`, `date_updated`, `date_live`, `name`, `modfile`, `maturity_option`, `monetization_options`, `platform_status`) plus paging and the documented user-mod sort keys
- `GET /me/files` now serializes only the documented authenticated user-modfile filters (`id`, `mod_id`, `date_added`, `date_scanned`, `virus_status`, `virus_positive`, `filesize`, `filehash`, `filename`, `version`, `changelog`, `metadata_blob`, `platform_status`) plus paging
- `GET /me/wallets` now preserves the documented `game_id` requirement unless the caller is using a g-url host and normalizes only the raw provider wallet fields (`type`, `payment_method_id`, `game_id`, `currency`, `balance`, `pending_balance`, `deficit`, `monetization_status`)
- `GET /me/purchased` now serializes only the documented purchased-mod filters (`id`, `game_id`, `status`, `visible`, `submitted_by`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `modfile`, `metadata_kvp`, `metadata_blob`, `tags`, `maturity_option`, `monetization_options`, `platform_status`, `platforms`) plus paging and the documented purchased-mod sort keys; platform-targeted requests must include `game_id`, so this seam injects the configured game id when needed
- `POST /me/entitlements` now preserves the required `X-Modio-Portal` header, validates only the documented request-body fields (`game_id`, `psn_token`, `psn_env`, `psn_service_label`, `xbox_token`, `epicgames_token`, `epicgames_sandbox_id`), enforces the PSN-only `X-Modio-Platform` requirement, and normalizes only the minimal entitlement row shape (`sku_id`, `entitlement_type`)
- `POST /games/{game-id}/mods/{mod-id}/checkout` now wraps all documented checkout modes `0..4`, preserves the docs-first portal/platform header rules, and validates only the documented mode/portal-specific fields (`display_amount` for type `0`; `payment_method_id` + `terms_accepted` + `refund_accepted` for types `2`/`3`; `transaction_id` for type `4`; PSN/Xbox/Epic token fields only when their portal headers are in play)
- the approved monetization-team seam is intentionally thin and REST-first: `GET /games/{game-id}/mods/{mod-id}/monetization/team` stays bearer-authenticated and returns only the documented account rows (`id`, `name_id`, `username`, `monetization_status`, `monetization_options`, `split`), while `POST /games/{game-id}/mods/{mod-id}/monetization/team` preserves the REST-page `multipart/form-data` contract and serializes the documented nested `users` array as indexed keys like `users[0][id]` / `users[0][split]`
- observed corpus drift is documented instead of guessed over for the monetization-team write: the refreshed REST page labels the create route as `multipart/form-data`, while the generated Unity client currently sends `application/x-www-form-urlencoded` but still expands the nested body into indexed `users[{i}][...]` keys; this seam follows the REST transport shape and reuses the indexed-key encoding because it is the only cross-corpus piece that cleanly matches the documented object-array contract
- the current product stance for direct mod.io checkout stays explicitly documented as non-store / web / PC-only for now, but that policy is not hardcoded into the adapter beyond the REST contract itself
- the monetization/auth-adjacent S2S slice is now intentionally server-side/service-token shaped instead of user-bearer shaped: `POST /s2s/transactions/intent`, `POST /s2s/transactions/commit`, `POST /s2s/transactions/clawback`, `DELETE /s2s/connections/{portal-id}`, `GET /s2s/monetization-teams/{monetization-team-id}/transactions`, and `GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}` all use a distinct `service_token` from `ModioClientConfig`; the disconnect wrapper preserves the REST page’s bodyless path-only `204 No Content` contract, and the history reads require an explicit `monetization_team_id` input/config instead of inferring it
- observed corpus drift is documented rather than guessed over: the refreshed GET S2S history pages place filter fields under a request-body schema even though the transport shape is query-string based, the list page labels its pagination envelope as `download`, and the clawback page types `gateway_uuid` as an integer despite describing it as an alpha-dash identifier; this seam serializes GET filters as query params, preserves the `download` payload while aliasing it to `pagination`, and treats `gateway_uuid` as a string
- the drifted `/me/iap/*/sync` family remains intentionally deferred in this slice because the refreshed docs, SDK, and Unity corpus do not provide a clean enough docs-first contract to wrap without guessing
- `GET /games/{game-id}/guides` now serializes only the current documented guide filters (`id`, `game_id`, `status`, `submitted_by`, `submitted_by_display_name`, `date_added`, `date_updated`, `date_live`, `name_id`, `tags`, `tags-in`, `tags-not-in`) plus paging and documented sort keys
- `GET /games/{game-id}/guides/{guide-id}/comments` now serializes only the current documented guide-comment filters (`id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, `content`) plus paging
- `GET /games/{game-id}/collections` now serializes only the current documented collection filters (`id`, `status`, `mod_id`, `category`, `submitted_by`, `submitted_by_display_name`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `maturity_option`, `tags`, `tags-in`, `tags-not-in`) plus paging and documented sort keys
- `GET /games/{game-id}/collections/{collection-id}/mods` now serializes the documented paging inputs, collection-mod sort keys, and the collection-mod-specific `maturity_option` / `show_hidden_mods` filters
- `GET /games/{game-id}/collections/{collection-id}/comments` now serializes only the current documented collection-comment filters (`id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, `content`) plus paging
- `GET /users/{user-id}/followers`, `GET /users/{user-id}/following`, `GET /users/{user-id}/collections`, `GET /me/followers`, `GET /me/users/muted`, `GET /me/collections`, and `GET /me/following/collections` now serialize paging only (`_limit`, `_offset`) even when other shared query fields are present
- `POST /users/{user-id}/following` sends the documented redundant form-encoded `user_id` body field for the target user while staying bearer-only
- `DELETE /users/{user-id}/following/{target-user-id}`, `POST /users/{user-id}/mute`, `DELETE /users/{user-id}/mute`, and `DELETE /games/{game-id}/collections/{collection-id}/followers` all normalize as `204 No Content` writes with empty `data`
- `POST /games/{game-id}/collections/{collection-id}/followers` keeps the returned `Mod Collection Object`, preserves `location`, and exposes `already_followed` when the provider returns `200 OK`
- `POST /games/{game-id}/collections/{collection-id}/subscriptions` and `DELETE /games/{game-id}/collections/{collection-id}/subscriptions` stay bodyless bearer-only writes, normalize the returned `Mod Collection Object`, and intentionally do not import SDK-local install/update/uninstall orchestration or undocumented `include_dependencies` behavior into this vendor seam
- modfile create/update/delete now cover the documented dedicated CRUD slice only: `POST /games/{game-id}/mods/{mod-id}/files` with bearer-authenticated `multipart/form-data`, documented fields only (`filedata`, `upload_id`, `version`, `changelog`, `active`, `filehash`, `metadata_blob`, `platforms`), and enforced `filedata` xor `upload_id`; `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` with bearer-authenticated `application/x-www-form-urlencoded` for `version`, `changelog`, `active`, and `metadata_blob`; and bodyless `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` normalized as `204 No Content`
- source-modfile coverage now mirrors the refreshed REST corpus instead of the Unity/plugin drift: `GET /games/{game-id}/mods/{mod-id}/sources` reuses the documented modfile list shape, and `POST /games/{game-id}/mods/{mod-id}/sources` preserves the full documented multipart contract (`active`, `filehash`, `metadata_blob`, `platforms[]`, and `filedata` xor `upload_id`) with docs-first field names only
- multipart upload/session coverage now stays thin but exact: `POST /games/{game-id}/mods/{mod-id}/files/multipart` validates only documented `filename` plus optional `nonce`; `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions` exposes just the documented `status`, `_limit`, and `_offset` filters; `GET /games/{game-id}/mods/{mod-id}/files/multipart`, `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`, and `DELETE /games/{game-id}/mods/{mod-id}/files/multipart` all require explicit `upload_id` query handling; and `PUT /games/{game-id}/mods/{mod-id}/files/multipart` sends raw bytes with explicit `Content-Range` plus optional opaque `Digest` header while intentionally not inventing an algorithm policy where the corpus drifts
- mod media management now stays thin and REST-first too: `POST /games/{game-id}/mods/{mod-id}/media` preserves the docs note that image field names are flexible by accepting a generic `images` mapping of multipart field names to truthful file-part descriptors (`filename`, optional `content_type`, raw byte `data`), while still forwarding documented `sync`, `youtube[]`, and `sketchfab[]`; `PUT /games/{game-id}/mods/{mod-id}/media/reorder` forwards only the documented `images[]`, `youtube[]`, and `sketchfab[]` form arrays with thin local shape/URL validation and deliberately leaves full-array mismatch enforcement to mod.io; and `DELETE /games/{game-id}/mods/{mod-id}/media` preserves the documented repeated array delete contract with `204 No Content` normalization
- the cook/platform slice now covers only the refreshed documented REST surface: `GET /games/{game-id}/mods/{mod-id}/cooks`, `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms` with repeated `approved[]` / `denied[]` form fields, and bodyless `POST /games/{game-id}/cloud-cooking/finalization`; it intentionally does **not** add the undocumented SDK-only `POST /games/{game-id}/mods/{mod-id}/cooks` upsert route or any release-workflow convenience helper that chains platform approval with go-live
- the upload/platform seam still intentionally does **not** import local file-path helpers, archive inspection, chunk/workflow orchestration, monetization helpers, or broader workflow policy into this vendor seam
- guide add/edit now validate the documented multipart-only field contract (`name`, `summary`, `description`, `logo`, `tags` required on create; documented optional edit fields including `status`, `name_id`, `url`, `tags`) and return normalized `Guide Object` writes for `201`/`200`
- collection add/update now validate only the documented multipart fields without inventing required fields, preserve `sync=true` semantics including empty `mod_ids` meaning remove all, and return normalized `Mod Collection Object` writes for `201`/`200`
- collection delete remains a bearer-authenticated `application/x-www-form-urlencoded` delete with optional `permanent` / `reason`, normalizing `204 No Content` as an empty-data delete response
- platform-targeted `GET /me/subscribed` requests must include `game_id`, so this repo injects it when platform targeting is configured
- `GET /me/ratings` defaults the seam to `resource_type=mods` plus the configured `game_id`, while preserving raw provider rating integers (`1` / `-1`) instead of re-inventing the contract
- token request expiry values are sanitized per documented flow instead of blindly forwarding stale/oversized values
- portal/platform/language/delegation headers remain provider-local config concerns
- host selection stays explicit/configurable through `ModioClientConfig` (`api`, `game`, `user`, optional sandbox) while explicit base-URL overrides still win
- the low-level seam performs no automatic blind retries

## Validation stance

The current validation layer is fixture-driven and based on current official API shapes documented in:

- `docs/modio-rest-api-research-2026-05-02.md`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`

Repo-local tests intentionally use simulated payloads derived from the documented shapes instead of live network calls, but they now validate the transport seam at the executed-request level: final encoded URL, final headers, form body encoding, and normalized HTTP/error outcomes. The refreshed local corpus also reconfirmed that collection reads stay on the existing game-scoped routes (`GET /games/{game-id}/collections...` and `GET /games/{game-id}/collections/{collection-id}`), so this seam deliberately does not add undocumented mod-scoped collection aliases.

## Next implementation slices

### 1. Multipart/upload and richer write coverage

The transport seam now supports documented multipart authoring bodies for the guide + collection CMS slice while deliberately keeping binary/media helper behavior out of scope.

### 2. Richer filtering and platform targeting

Expand provider query models only as needed by AeroBeat, especially around platform targeting and advanced browse filters.

### 3. Higher-level mapping in `aerobeat-tool-api`

Let `aerobeat-tool-api` translate these vendor-local DTOs into narrower AeroBeat-facing results while keeping raw mod.io mechanics isolated here.
