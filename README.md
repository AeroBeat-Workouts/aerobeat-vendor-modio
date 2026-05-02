# AeroBeat Vendor - mod.io

`aerobeat-vendor-modio` is the provider-specific **mod.io adapter** package behind `aerobeat-tool-api`.

It is **not** the public AeroBeat-facing API singleton and it is **not** a product/assembly integration surface. Product repos should depend on `aerobeat-tool-api`, which can compose this repo behind a stable AeroBeat-shaped contract.

This repo exists to keep mod.io-specific concerns local, replaceable, and out of gameplay/UI repos.

## Repository role

This package owns the concrete mod.io-side seam for:

- auth request construction and token/session exchange helpers
- listing/search request construction for approved discovery flows
- download request construction and provider file resolution
- provider-specific DTOs, query shapes, and error normalization
- future transport glue that talks to mod.io without leaking that surface into `aerobeat-tool-api`

This package should **not** own:

- AeroBeat's public API manager singleton
- product-facing gameplay/UI contracts
- canonical AeroBeat trust decisions
- direct product-repo integration contracts

## Package details

- **Type:** Vendor adapter package
- **License:** **MPL 2.0**
- **Intended consumer:** `aerobeat-tool-api`
- **Allowed shared dependency lane:** `aerobeat-tool-core`

## Current bootstrap scope

This first scaffold intentionally stays small:

- reusable `plugin.cfg` package metadata
- hidden GodotEnv-compatible `.testbed/` workbench
- initial `src/` layout centered on the adapter seam
- request-builder style stubs for mod.io auth / listing / download flows
- a first seam plan for where real provider integration should land next

It does **not** implement live network behavior yet.

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
- `models/` holds provider-local config and request DTOs.
- `network/` holds transport helpers that should remain mod.io-specific.

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

### Run the repo-local scaffold validation

From the repo root:

```bash
godot --headless --path .testbed --script res://tests/validate_scaffold.gd
```

## Seam plan: mod.io auth / listing / download

See [`docs/modio-seam-plan.md`](docs/modio-seam-plan.md).

Short version:

1. `aerobeat-tool-api` should compose one provider adapter instance.
2. This repo should map mod.io request/response details into provider-local DTOs.
3. AeroBeat-owned trust, approval, and install policy should stay outside this repo.
4. Real HTTP execution can land later behind the current `ModioHttpTransport` seam without changing the package role.
