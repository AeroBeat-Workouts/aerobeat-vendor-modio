# mod.io REST API research for AeroBeat vendor wrapper

**Date:** 2026-05-02  
**Repo:** `aerobeat-vendor-modio`  
**Purpose:** freeze an execution-ready understanding of the current official mod.io REST surface before implementing the wrapper.

## Source of truth used

Official docs first:

- `https://docs.mod.io/restapi/introduction`
- `https://docs.mod.io/restapi/rate-limiting`
- `https://docs.mod.io/restapi/errors`
- endpoint pages from the official `modio/modio-docs` repo cloned locally below

Local long-lived reference clones created/updated under `~/workspace/projects/modio/`:

- `modio-docs`  
  - remote: `git@github.com:modio/modio-docs.git`
  - local path: `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
  - pinned at: `0a029b13f2dd2f0a576b793d5471e14014dba259`
  - why keep it: primary durable source for current REST endpoint docs, auth docs, error refs, rate limits, and endpoint schemas.
- `modio-sdk`  
  - remote: `git@github.com:modio/modio-sdk.git`
  - local path: `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
  - pinned at: `cd9bc6b3de300183d47ac2a6abcd56ff52f68929`
  - why keep it: official C++ SDK, useful as a behavior/integration reference for auth, subscriptions, installation/download expectations, and naming that mod.io itself considers stable enough for shipped game integrations.
- `modio-unity`  
  - remote: `git@github.com:modio/modio-unity.git`
  - local path: `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`
  - pinned at: `f05e82d2658c3340c02c7843f34223d464b0ab4f`
  - why keep it: official Unity plugin with a ready-made client integration layer and examples for auth, browsing, subscriptions, sync, install/download, and user-facing terms handling.

## Recommended local reference strategy

Use a three-layer strategy:

1. **Primary truth source:** `modio-docs`
   - implementation and fixtures should be derived from the cloned docs pages, not memory.
2. **Behavior sanity reference:** `modio-sdk`
   - use when docs are technically correct but ambiguous about client expectations or flow sequencing.
3. **Game-client workflow reference:** `modio-unity`
   - use for “how a real game integration tends to drive the API” especially around auth UX, subscription sync, and install lifecycle.

For this repo specifically:

- keep this research note committed in `aerobeat-vendor-modio`
- derive test fixtures from the endpoint schemas in `modio-docs`
- do **not** bake direct dependency on the cloned repos into runtime code
- when implementation starts, cite the exact cloned file paths in code comments or fixture generation notes where the API shape was taken from

## Current API base/auth model

Per official introduction docs:

- game API base path pattern: `https://g-{game-id}.modapi.io/v1`
- user API base path pattern: `https://u-{user-id}.modapi.io/v1`
- test environment variants use `.test.mod.io`
- API key auth is query-based and read-only GET
- OAuth bearer token auth is header-based and supports GET/POST/PUT/DELETE
- bearer token can be used for GET as well; if both token and API key are supplied, token wins

For AeroBeat’s wrapper, the wrapper should own:

- base URL construction
- API key query injection for read-only public browsing
- bearer token header injection for authenticated flows
- content-type rules for form-encoded vs multipart requests
- rate-limit and structured error mapping

## API surface to wrap first for the current AeroBeat slice

This is the smallest execution-ready surface that matches the current AeroBeat architecture docs: mod.io as the outer discovery/distribution shell, with AeroBeat retaining trust, validation, and runtime authority.

### 1. Auth/session flows

Wrap first:

- `POST /oauth/emailrequest`
  - request email security code
  - form field: `email`
- `POST /oauth/emailexchange`
  - exchange security code for access token
  - form fields: `security_code`, optional `date_expires`
  - notable error refs: `11011`, `11012`, `11013`, `11014`, `17053`
- `POST /external/openidauth`
  - OpenID sign-in for SSO/provider-based auth
  - fields include `id_token`, `terms_agreed`, optional `email`, optional `date_expires`
  - important errors: `11074` when latest terms consent is required; `11086`/`11087`/`11091` for config/provider failures
- `GET /authenticate/terms`
  - fetches text/buttons/links for terms consent UI
- `GET /agreements/types/{agreement-type-id}/current`
  - fetch latest agreement text/version if AeroBeat wants inline rendering instead of external links
- `GET /me`
  - current authenticated user profile/status
- `POST /oauth/logout`
  - revoke current access token

Wrapper stance:

- support **email auth** and **OpenID auth** explicitly
- treat terms collection as part of auth orchestration for SSO/OpenID
- keep token state external to the wrapper if possible, but return typed token payloads and structured auth errors

### 2. Listing/search/browse

Wrap first:

- `GET /games/{game-id}`
  - needed to discover game-level settings, especially:
    - `api_access_options`
    - `submission_option`
    - `tag_options`
    - `platforms`
- `GET /games/{game-id}/mods`
  - main browse/search/list endpoint

Important supported browse filters/sorts from current docs:

- identity filters: `id`, `name`, `name_id`, `submitted_by`
- time filters: `date_added`, `date_updated`, `date_live`
- metadata/tag filters: `metadata_blob`, `metadata_kvp`, `tags`
- visibility/admin-only filters: `status`, `visible`, `platform_status`
- sorting: `name`, `date_live`, `date_updated`, `submitted_by`, `downloads_today`, `downloads_total`, `subscribers_total`, `ratings_weighted_aggregate`
- pagination metadata: `result_count`, `result_offset`, `result_limit`, `result_total`

Wrapper stance:

- first implementation should expose a typed browse query object rather than leaking raw query strings everywhere
- support pagination, sort, tags, metadata filters, and optional platform targeting header
- treat admin-only filters as advanced/optional to avoid wrapper surface bloat in the first pass

### 3. Content details

Wrap first:

- `GET /games/{game-id}/mods/{mod-id}`
  - single mod detail
- `GET /games/{game-id}/mods/{mod-id}/files`
  - published modfiles for the mod

Fields that matter immediately for AeroBeat:

- mod identity: `id`, `game_id`, `name`, `name_id`, `profile_url`
- display: `summary`, `description`, `description_plaintext`, `logo`, `media`, `tags`
- ownership: `submitted_by`
- state: `status`, `visible`, `date_added`, `date_updated`, `date_live`
- stats: `downloads_total`, `subscribers_total`, ratings fields
- platform/file linkage: top-level `modfile`, `platforms`
- game-owned opaque metadata: `metadata_blob`, `metadata_kvp`

Wrapper stance:

- define vendor DTOs for `Game`, `Mod`, `ModStats`, `Modfile`, and the small nested objects actually used
- do not normalize everything into AeroBeat canonical models yet; preserve vendor shape in the wrapper layer and map above it later

### 4. Subscribe/library-ish and user-state flows

Wrap first:

- `GET /me/subscribed`
  - current authenticated user subscriptions
  - docs explicitly say to use this for new games instead of deprecated user events
- `POST /games/{game-id}/mods/{mod-id}/subscribe`
  - supports `include_dependencies`
  - returns `201` on new subscription and `200` if already subscribed
- `DELETE /games/{game-id}/mods/{mod-id}/subscribe`
  - unsubscribe endpoint should be wrapped alongside subscribe for symmetry
- `GET /me/events`
  - **do not** use for new implementation except possibly legacy compatibility; docs say it is deprecated for in-game use and not returned for games created after 2024-03-31

Wrapper stance:

- model subscriptions as the only supported user library state in the first slice
- do not build around events polling
- consider `GET /me/subscribed` the canonical user-state sync endpoint for the first implementation

### 5. File/download access

Wrap first:

- download information should come from:
  - `GET /games/{game-id}/mods/{mod-id}` via current `modfile.download`
  - `GET /games/{game-id}/mods/{mod-id}/files` for explicit file lists/history

Important official behavior:

- modfile objects include:
  - `id`, `version`, `filesize`, `filesize_uncompressed`, `filehash.md5`, `filename`, `metadata_blob`
  - `download.binary_url`
  - `download.date_expires`
  - virus scan fields
- if the game requires downloads to be initiated via the API, `binary_url` contains a verification hash and expires
- official docs explicitly say saved/reused `binary_url` values will not work reliably in that mode
- `GET /games/{game-id}` exposes `api_access_options`; if `DOWNLOADS` is disabled the URLs will contain frequently changing verification hashes, and `AUTHORISED_DOWNLOADS` / `PAID_DOWNLOADS` further tighten requirements

Wrapper stance:

- never treat download URLs as stable cache keys
- expose download info with explicit expiry metadata
- separate “fetch metadata” from “perform download” in the wrapper interface
- preserve hash and virus scan fields because AeroBeat’s trust layer will likely care about them, even if mod.io is not the final runtime trust authority

## Error and rate-limit behavior to design for immediately

### Rate limiting

Official defaults:

- game API keys: unlimited requests
- user API keys: 60 req/min
- user OAuth tokens: 120 req/min
- user token writes: 60 req/min
- IPs: 1000 req/min
- IP writes: 60 req/min

Important runtime behavior:

- `429` with `retry-after` header in seconds
- global ratelimit error ref: `11008`
- per-endpoint ratelimit error ref: `11009`
- if `retry-after: 0`, docs describe this as a rolling ratelimit; mod.io recommends retrying after 60 seconds

Wrapper stance:

- parse and surface `retry-after`
- distinguish global vs endpoint-local rate limits in typed errors
- avoid automatic blind retries inside the low-level wrapper; let callers decide

### Errors

Common HTTP codes to map now:

- `401` invalid/missing/revoked auth
- `403` permission/terms/account state restrictions
- `404` not found
- `409` duplicate/competing write
- `422` validation error with nested `errors`
- `429` rate limited
- `500` / `503` transient server-side problems

Important cross-endpoint `error_ref` values for first slice:

- `11000` missing API key
- `11001` malformed API key
- `11002` invalid API key
- `11003` missing write scope
- `11004` missing read scope
- `11005` token expired/revoked
- `11006` user deleted
- `11007` user banned
- `11008` global ratelimit
- `11009` endpoint ratelimit
- `11074` latest terms agreement required
- `13009` validation errors with nested field-level `errors`
- `14000` generic resource not found
- `14001` game not found
- `15010` modfile not found
- `15022` mod not found
- `15023` mod deleted
- `15025` admin-only mod filter attempted without permission
- `15000` subscribe blocked by DMCA
- `15001` subscribe blocked because mod is hidden

Wrapper stance:

- include both HTTP code and `error_ref` in typed vendor errors
- preserve field-level validation payload for `422`
- make not-found, auth-expired, terms-required, and rate-limited easy for upper layers to branch on

## Ambiguities / risks to call out before coding

1. **Terms flow is easy to get subtly wrong.**
   - For OpenID and platform SSO, docs require `terms_agreed=false` by default and only `true` on the retry immediately after consent collection.
   - AeroBeat should not “remember to always send true”.

2. **Email auth flow docs are slightly asymmetric.**
   - `emailexchange` request schema lists `security_code` and optional `date_expires`, but the prose says it exchanges a code issued from the email request and that the same API key must be used.
   - The schema excerpt visible in the docs does not re-list `email` as required even though the prose implies the exchange is bound to the original email request context. Implementation should verify exact live behavior before over-constraining the wrapper interface.

3. **Download URLs are not stable artifacts.**
   - The docs repeatedly note expiring verification hashes in `binary_url` depending on game API settings.
   - Any AeroBeat cache/install layer must cache files by AeroBeat trust metadata or modfile identity/hash, not by mod.io URL.

4. **Platform targeting changes result shape.**
   - `X-Modio-Platform` style targeting affects which mods/files come back and even whether `modfile` may be empty on detail responses.
   - Wrapper should make platform targeting explicit, not hidden global state.

5. **`/me/events` is legacy-only for new games.**
   - Do not architect sync around events polling.

6. **Game-level API access options can materially change download behavior.**
   - `api_access_options` on `GET /games/{game-id}` should be read early and probably surfaced in diagnostics/config.

7. **mod.io strongly recommends using SDK/plugin instead of raw REST unless custom integration is required.**
   - That is fine here because AeroBeat explicitly wants a vendor-owned seam, but it means we should keep the wrapper thin and not try to out-SDK the SDK on the first pass.

8. **Deprecated fields still appear in schemas.**
   - Several user/modfile fields are marked deprecated. Preserve them only if needed for fixture fidelity; do not build new abstractions around them.

## Recommended first implementation cut

Implement only these wrapper capabilities first:

1. `getGame(gameId)`
2. `listMods(gameId, query, platform?)`
3. `getMod(gameId, modId, platform?)`
4. `listModfiles(gameId, modId, platform?)`
5. `requestEmailCode(email)`
6. `exchangeEmailCode(securityCode, dateExpires?)`
7. `authenticateOpenId(idToken, termsAgreed, opts)`
8. `getTerms(portal?, language?)`
9. `getCurrentAgreement(typeId)`
10. `getAuthenticatedUser(token)`
11. `getUserSubscriptions(query, platform?)`
12. `subscribeToMod(gameId, modId, includeDependencies?)`
13. `unsubscribeFromMod(gameId, modId)`
14. `logout()`

That is enough to support:

- browse/search/details
- authenticated user session bootstrap
- subscription/library sync
- download metadata retrieval
- explicit handling of terms/rate-limit/error edge cases

## Architecture note for AeroBeat

The AeroBeat docs are still the right direction:

- use mod.io for discovery, outer community state, subscriptions, and file hosting convenience
- keep AeroBeat trust, validation, bake/sign, and install authority outside mod.io
- treat mod.io IDs and URLs as mapped vendor identifiers, not canonical gameplay/runtime identity

So this wrapper should preserve mod.io’s native data shape cleanly, but not become the final trusted runtime contract.
