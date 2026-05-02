# AeroBeat Vendor - mod.io

`aerobeat-vendor-modio` is the provider-specific **mod.io adapter** package behind `aerobeat-tool-api`.

It is **not** the public AeroBeat-facing API singleton and it is **not** a product/assembly integration surface. Product repos should depend on `aerobeat-tool-api`, which can compose this repo behind a stable AeroBeat-shaped contract.

This repo exists to keep mod.io-specific concerns local, replaceable, and out of gameplay/UI repos.

## Repository role

This package owns the concrete mod.io-side seam for:

- auth request construction and token/session normalization
- browse/list/detail request construction for game, mod, and modfile reads
- subscription/user-state request construction for `GET /me/subscribed` and subscribe/unsubscribe flows
- download metadata resolution from `modfile.download.binary_url` and `date_expires`
- provider-specific DTOs, query shapes, and error/rate-limit normalization
- future transport glue that talks to mod.io without leaking that surface into `aerobeat-tool-api`

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
- user-state writes/reads
  - `GET /me/subscribed`
  - `POST /games/{game-id}/mods/{mod-id}/subscribe`
  - `DELETE /games/{game-id}/mods/{mod-id}/subscribe`
- response normalization seams
  - access token, terms, agreement, user, game, mod list/detail, modfiles, subscriptions
  - structured error/rate-limit mapping including `retry-after`, `11008`, `11009`, and `11074`

The wrapper still does **not** perform live HTTP execution in this repo. It owns request construction, provider-local DTO normalization, and download metadata handling so the execution layer can land later without changing the upstream seam.

## Download URL stance

mod.io `binary_url` values are treated as **expiring delivery URLs**, not canonical file identities.

The wrapper therefore:

- resolves downloads from modfile metadata instead of exposing a fake stable download endpoint contract
- preserves `date_expires`, hash, filename, and file identifiers
- marks resolved download URLs as non-canonical so higher layers do not use them as durable cache keys

This follows the current official mod.io docs note that hashed download URLs can expire and should not be saved/reused as if they were permanent.

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
