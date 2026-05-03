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
  - `POST /external/openidauth`
  - `GET /authenticate/terms`
  - `GET /agreements/types/{agreement-type-id}/current`
  - `GET /me`
  - `POST /oauth/logout`
- browse/content reads
  - `GET /games/{game-id}`
  - `GET /games/{game-id}/mods`
  - `GET /games/{game-id}/mods/{mod-id}`
  - `GET /games/{game-id}/mods/{mod-id}/files`
  - `GET /games/{game-id}/mods/{mod-id}/files/{file-id}`
  - `GET /games/{game-id}/mods/{mod-id}/stats`
- user-state writes/reads
  - `GET /me/subscribed`
  - `GET /me/ratings`
  - `POST /games/{game-id}/mods/{mod-id}/ratings`
  - `POST /report`
  - `POST /games/{game-id}/mods/{mod-id}/subscribe`
  - `DELETE /games/{game-id}/mods/{mod-id}/subscribe`
- mod + guide + collection community reads/writes
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
- response normalization seams
  - access token, logout/message, terms, agreement, user, game, mod list/detail, modfiles, mod stats, mod comments, guides, guide comments, collections, collection comments, user ratings, subscriptions, dependencies, and collection compatibility writes
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
  - GET/POST/DELETE execution with form-encoded bodies, bearer-only authenticated writes, and no automatic retries

The wrapper now owns a **thin execution seam** in addition to request construction and normalization. The live transport remains intentionally narrow: it prepares and dispatches mod.io-specific HTTP requests, normalizes the response/error envelope, and keeps provider-only host/auth/header logic local to this repo so higher layers can compose it later without inheriting raw mod.io rules.

The current query model is intentionally endpoint-aware instead of emitting every filter everywhere. `GET /games/{game-id}/mods`, `GET /games/{game-id}/mods/{mod-id}/files`, `GET /games/{game-id}/mods/{mod-id}/comments`, `GET /games/{game-id}/guides`, `GET /games/{game-id}/guides/{guide-id}/comments`, `GET /games/{game-id}/collections`, `GET /games/{game-id}/collections/{collection-id}/mods`, `GET /games/{game-id}/collections/{collection-id}/comments`, `GET /me/subscribed`, and `GET /me/ratings` now serialize only the documented subset each wrapped endpoint should receive, while still preserving shared paging inputs. Documented `_sort` allowlists are now enforced for mod listings, guide listings, collection listings, collection-mod listings, and authenticated subscriptions so undocumented sort keys do not leak through the wrapper. Platform-targeted `GET /me/subscribed` requests also continue to force the required `game_id` field, `GET /me/ratings` defaults to the mod-centric `resource_type=mods` seam while still preserving raw provider fields in normalized output, guide list serialization now includes the current documented `submitted_by_display_name` / `date_updated` / `date_live` filters plus guide-only sort keys, collection list serialization includes the documented category/name/maturity filters plus collection-only sort keys, collection-mod requests preserve the documented `show_hidden_mods` / `maturity_option` inputs without leaking unrelated listing fields, and mod + guide + collection comment normalization keep the raw comment fields while adding only light seam-local helpers such as `is_reply`, `thread_depth`, `is_pinned`, `is_locked`, and `option_flags`. Integration-style tests validate the final encoded URLs and form bodies that the transport would execute.

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
