# mod.io seam plan

This document captures the first implementation-ready seam for real mod.io integration work in `aerobeat-vendor-modio`.

## Purpose

Keep **provider-native** concerns in this repo while allowing `aerobeat-tool-api` to compose the adapter behind an AeroBeat-facing API-manager surface.

## Seam boundaries

### This repo should own

- mod.io request construction
- auth/session exchange helpers
- provider listing and search query mapping
- provider download/file resolution mapping
- provider DTO parsing and error normalization
- future thin HTTP transport execution for mod.io-specific endpoints

### This repo should not own

- AeroBeat trust approval policy
- public product-facing singleton contracts
- gameplay/UI integration behavior
- canonical content identity beyond provider-to-AeroBeat mapping helpers

## Initial code seam

The bootstrap scaffold intentionally starts with request-builder stubs:

- `ModioVendorAdapter`
  - `build_auth_exchange_request(...)`
  - `build_listing_request(...)`
  - `build_download_request(...)`
- `ModioHttpTransport`
  - normalized request-dictionary builder
- provider-local models under `src/models/`

That keeps the repo implementation-ready without forcing premature live network behavior.

## Next implementation slices

### 1. Auth

Add a provider-local auth/session model that can:

- exchange creator or athlete auth codes for mod.io-compatible session data when needed
- normalize expiry and token payloads into repo-local DTOs
- avoid leaking raw provider payloads upward when `aerobeat-tool-api` only needs a narrower contract

### 2. Listing / discovery

Expand `ModioListingQuery` and adapter parsing to support:

- in-game filtered discovery joins
- provider pagination cursors or offsets
- tag/category mapping kept local to this adapter
- normalized provider errors for rate limits, not-found, and auth failures

### 3. Download

Add download resolution helpers that can:

- resolve approved provider file URLs
- map provider file metadata into AeroBeat download/install orchestration inputs
- keep checksum/integrity verification responsibilities clearly separate from AeroBeat trust validation

## Integration stance with `aerobeat-tool-api`

`aerobeat-tool-api` should eventually depend on a narrow provider-adapter seam such as:

- configure active adapter
- request provider-backed discovery data
- request provider-backed download metadata
- translate provider failures into AeroBeat-facing results

The API manager should coordinate this adapter, not absorb its provider DTOs or raw endpoint logic.

## Validation note

The current scaffold validates only local seam construction and request-shape expectations. Live transport execution, provider payload fixtures, and integration tests belong in later slices.
