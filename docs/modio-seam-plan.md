# mod.io seam plan

This document captures the first implementation-ready seam for real mod.io integration work in `aerobeat-vendor-modio`.

## Purpose

Keep **provider-native** concerns in this repo while allowing `aerobeat-tool-api` to compose the adapter behind an AeroBeat-facing API-manager surface.

## Seam boundaries

### This repo should own

- mod.io request construction
- auth/session request-shape support for email and OpenID flows
- provider listing/search/detail query mapping
- provider subscription/user-state mapping via `GET /me/subscribed`
- provider download metadata resolution from `modfile.download`
- provider DTO parsing and error normalization
- future thin HTTP transport execution for mod.io-specific endpoints

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
  - browse/detail request builders
    - `build_game_request(...)`
    - `build_listing_request(...)`
    - `build_mod_detail_request(...)`
    - `build_modfiles_request(...)`
  - subscription request builders
    - `build_user_subscriptions_request(...)`
    - `build_subscribe_request(...)`
    - `build_unsubscribe_request(...)`
  - normalization helpers
    - auth/user/game/mod/modfile/subscription responses
    - subscription write responses
    - download metadata resolution helpers
- `ModioHttpTransport`
  - normalized request-dictionary builder
  - structured error/rate-limit normalization seam
- provider-local models under `src/models/`
  - `ModioClientConfig`
  - `ModioListingQuery`
  - `ModioDownloadRequest`

## Download seam decision

For AeroBeat's current slice, this repo does **not** expose a fake stable `/download` provider abstraction.

Instead it:

- resolves downloads from modfile payloads returned by `GET /games/{game-id}/mods/{mod-id}` or `GET /games/{game-id}/mods/{mod-id}/files`
- preserves `binary_url`, `date_expires`, hash, and filename
- explicitly marks the resolved URL as non-canonical because current mod.io docs state hashed URLs can expire and should not be saved/reused as stable identifiers

That keeps transient CDN delivery behavior local to the vendor seam and out of AeroBeat's higher-level identity/trust decisions.

## Query/auth stance

- public/read flows default to query-based `api_key` injection
- authenticated flows prefer bearer token headers
- read flows can also prefer bearer tokens when a caller has an authenticated session already
- portal/platform/language headers remain provider-local config concerns
- no automatic blind retries are performed in the low-level seam

## Validation stance

The current validation layer is fixture-driven and based on current official API shapes documented in:

- `docs/modio-rest-api-research-2026-05-02.md`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`

Repo-local tests intentionally use simulated payloads derived from the documented shapes instead of live network calls.

## Next implementation slices

### 1. Live transport execution

Add real HTTP execution behind `ModioHttpTransport` without changing the current adapter contract.

### 2. Richer filtering and platform targeting

Expand provider query models only as needed by AeroBeat, especially around platform targeting and advanced browse filters.

### 3. Higher-level mapping in `aerobeat-tool-api`

Let `aerobeat-tool-api` translate these vendor-local DTOs into narrower AeroBeat-facing results while keeping raw mod.io mechanics isolated here.
