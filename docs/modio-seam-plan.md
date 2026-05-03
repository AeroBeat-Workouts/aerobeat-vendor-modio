# mod.io seam plan

This document captures the first implementation-ready seam for real mod.io integration work in `aerobeat-vendor-modio`.

## Purpose

Keep **provider-native** concerns in this repo while allowing `aerobeat-tool-api` to compose the adapter behind an AeroBeat-facing API-manager surface.

## Seam boundaries

### This repo should own

- mod.io request construction
- auth/session request-shape support for email and OpenID flows
- provider listing/search/detail/dependency query mapping
- endpoint-aware filter serialization per wrapped endpoint
- provider subscription/user-state mapping via `GET /me/subscribed` and `GET /me/ratings`
- provider mod + guide + collection community transport/query/normalization via `GET/POST/PUT/DELETE /games/{game-id}/mods/{mod-id}/comments...`, `GET /games/{game-id}/guides...`, and `GET /games/{game-id}/collections...`
- provider rating/report writes via `POST /games/{game-id}/mods/{mod-id}/ratings`, `POST /games/{game-id}/mods/{mod-id}/comments/{comment-id}/karma`, `POST /games/{game-id}/guides/{guide-id}/comments/{comment-id}/karma`, `POST /games/{game-id}/collections/{collection-id}/comments/{comment-id}/karma`, `POST /games/{game-id}/collections/{collection-id}/compatibility`, and `POST /report`
- provider download metadata resolution from `modfile.download`
- canonical artifact/cache metadata resolution derived from `provider + game_id + mod_id + modfile.id`
- provider DTO parsing, page-state helpers, and error normalization
- thin HTTP transport execution for mod.io-specific endpoints

### This repo should not own

- AeroBeat trust approval policy
- public product-facing singleton contracts
- gameplay/UI integration behavior
- canonical content identity beyond provider-to-AeroBeat mapping helpers
- install orchestration decisions above the provider seam

## Implemented code seam

The current slice now exposes a larger request-builder and normalization seam:

- `ModioVendorAdapter`
  - auth/session request builders
    - `build_email_security_code_request(...)`
    - `build_auth_exchange_request(...)`
    - `build_openid_auth_request(...)`
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
    - `build_collections_request(...)`
    - `build_collection_request(...)`
    - `build_collection_mods_request(...)`
    - `build_guides_request(...)`
    - `build_guide_detail_request(...)`
    - `build_dependencies_request(...)`
  - subscription/user-rating/report/comment request builders
    - `build_user_subscriptions_request(...)`
    - `build_user_ratings_request(...)`
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
    - auth/logout/message/user/game/mod/modfile/mod-stats/mod-comment/guide/guide-comment/collection/collection-comment/user-ratings/subscription/dependency/report/collection-compatibility responses
    - page-state helpers derived from `result_count`, `result_offset`, `result_limit`, and `result_total`
    - subscription write responses
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
- authenticated `GET /me`, `GET /me/subscribed`, logout, and subscription writes require bearer-token headers
- endpoint query serialization is intentionally capability-gated so unsupported filters do not leak onto the wrong wrapped endpoint
- `GET /games/{game-id}/guides` now serializes only the current documented guide filters (`id`, `game_id`, `status`, `submitted_by`, `submitted_by_display_name`, `date_added`, `date_updated`, `date_live`, `name_id`, `tags`, `tags-in`, `tags-not-in`) plus paging and documented sort keys
- `GET /games/{game-id}/guides/{guide-id}/comments` now serializes only the current documented guide-comment filters (`id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, `content`) plus paging
- `GET /games/{game-id}/collections` now serializes only the current documented collection filters (`id`, `status`, `mod_id`, `category`, `submitted_by`, `submitted_by_display_name`, `date_added`, `date_updated`, `date_live`, `name`, `name_id`, `maturity_option`, `tags`, `tags-in`, `tags-not-in`) plus paging and documented sort keys
- `GET /games/{game-id}/collections/{collection-id}/mods` now serializes only paging plus the current documented collection-mod filters (`maturity_option`, `show_hidden_mods`) and documented sort keys
- `GET /games/{game-id}/collections/{collection-id}/comments` now serializes only the current documented collection-comment filters (`id`, `resource_id`, `submitted_by`, `date_added`, `reply_id`, `thread_position`, `karma`, `content`) plus paging
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

Repo-local tests intentionally use simulated payloads derived from the documented shapes instead of live network calls, but they now validate the transport seam at the executed-request level: final encoded URL, final headers, form body encoding, and normalized HTTP/error outcomes.

## Next implementation slices

### 1. Multipart/upload and richer write coverage

If AeroBeat needs creation/update surfaces later, extend the transport only far enough to support documented multipart and other write-specific content types.

### 2. Richer filtering and platform targeting

Expand provider query models only as needed by AeroBeat, especially around platform targeting and advanced browse filters.

### 3. Higher-level mapping in `aerobeat-tool-api`

Let `aerobeat-tool-api` translate these vendor-local DTOs into narrower AeroBeat-facing results while keeping raw mod.io mechanics isolated here.
