# AeroBeat Vendor Mod.io Live Transport and Integration Tests

**Date:** 2026-05-02  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Implement the next mod.io-only slice in `aerobeat-vendor-modio` by hardening the live transport layer and adding request/integration-style tests around documented mod.io behavior, while still keeping the repo isolated as a vendor adapter and grounded in current official mod.io references.

---

## Overview

The previous slices established the wrapper seam, fixture-driven coverage, endpoint-aware query gating, paging helpers, and stronger session handling. QA and audit also flushed out several subtle API-shape mismatches by checking against current official mod.io docs and pinned local references.

The next highest-value slice is to make the transport layer more real and better tested without yet integrating `aerobeat-tool-api`. That means improving live request construction/execution seams, validating headers/base URLs/query serialization against documented host patterns, and adding integration-style tests that exercise request assembly and response/error handling in a way closer to actual runtime usage. This should still avoid bleeding API-manager responsibilities into this repo; the goal is a stronger vendor adapter, not a product-facing orchestration layer.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active live-transport plan | `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md` |
| `REF-02` | Previous coverage expansion results | `.plans/2026-05-02-aerobeat-vendor-modio-coverage-expansion.md` |
| `REF-03` | Current REST wrapper plan/results | `.plans/2026-05-02-aerobeat-vendor-modio-rest-wrapper.md` |
| `REF-04` | Current mod.io API research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-05` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-06` | Official local mod.io references | `/home/derrick/.openclaw/workspace/projects/modio/` |
| `REF-07` | Current implementation/tests | `src/`, `.testbed/tests/` |

---

## Tasks

### Task 1: Research the live-transport/integration-test target slice

**Bead ID:** `oc-9xu`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the current wrapper/transport/tests plus the official mod.io docs and pinned local references to define the next highest-value live-transport and integration-test slice that still stays entirely inside this repo. Produce an execution-ready target list for request execution hardening, host/base-URL handling, header handling, query serialization validation, response/error integration-style tests, and any documented transport constraints that are not yet exercised. Update the active plan with what actually happened and close the bead with a concrete implementation recommendation.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` (if notes need updating)

**Files Created/Deleted/Modified:**
- `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md`
- optional notes/docs if needed

**Status:** ✅ Complete

**Results:** Researched the current repo surface against the local official `modio-docs` mirror first, then cross-checked `modio-sdk` and `modio-unity` for client-behavior expectations. Recommendation: the next highest-value slice should be the repo-local **live request execution seam plus transport-focused integration tests** for the already wrapped endpoints, not broader endpoint expansion. The current wrapper/query/normalization surface is already strong; the biggest remaining risk is that request assembly and live transport rules are still only fixture-tested, while the official docs contain several host/header/auth constraints that can drift silently.

Concrete implementation target list for Task 2:

- **Host / base URL handling**
  - Add a real transport execution path that accepts an explicit base URL but also hardens `ModioClientConfig.resolve_base_url()` around documented host patterns from the intro docs: production examples use `https://api.mod.io/v1`, while the official host guidance also documents `https://g-{game-id}.modapi.io/v1` and `https://u-{user-id}.modapi.io/v1`.
  - Keep the current explicit-override-first behavior, but add tests that lock in: explicit `base_url` wins; empty explicit base URL falls back deterministically; paths are normalized to exactly one leading slash; URL join logic does not produce double slashes.
  - Treat test/sandbox host selection as configuration, not hidden inference. The intro docs mention `.test.mod.io` environment variants, but the exact substitution strategy is not fully spelled out in the current repo code, so transport should stay configurable rather than guessing.
  - Do **not** silently assume every request should use the game host. The current wrapped endpoints all work with the generic API host shape shown throughout the docs, while the introduction also documents game/user host patterns. Keep host choice explicit and testable.

- **Request execution hardening**
  - Implement the thin live execution seam inside `ModioHttpTransport` only, leaving `ModioVendorAdapter` as the request-builder/normalizer layer.
  - Support the request shapes already emitted here: `GET`, `POST`, `DELETE`; query params; `application/x-www-form-urlencoded` bodies; empty-body writes; and case-preserving outbound headers.
  - Ensure authenticated writes (`/oauth/logout`, `/games/{game-id}/mods/{mod-id}/subscribe`, `/games/{game-id}/mods/{mod-id}/subscribe` DELETE) execute with bearer auth only and do not leak `api_key` fallback into runtime requests.
  - Keep automatic retries **off** in the low-level seam, but surface timeout/network/HTTP failure details cleanly so outer layers can decide retry policy.
  - Add integration-style tests around executed request records, not just request dictionaries: full URL, final headers, encoded body, normalized response, and transport-level failures.

- **Header handling**
  - Lock in outbound support for `Authorization: Bearer <token>`, `Accept-Language`, `X-Modio-Platform`, `X-Modio-Portal`, and `X-Modio-Delegation-Token` on the endpoints that already expose them in this repo.
  - Keep `Accept-Language` optional but, when configured, send it exactly as configured; docs say invalid/missing values fall back to the authenticated user’s language or English (US).
  - Keep `X-Modio-Platform` and `X-Modio-Portal` optional but preserve them exactly; the docs say supported values are case-insensitive, and they materially affect platform-approved content and `display_name_portal` behavior.
  - Preserve current rule that authenticated `/me`, `/oauth/logout`, and subscription writes use bearer auth and omit `api_key` query auth.
  - Note for later slices only: localization docs also describe `Content-Language` for submitting translated content, but none of the current wrapped write endpoints require it yet.

- **Query serialization validation at transport level**
  - Add integration-style tests that validate the final encoded query string, not just the intermediate query dictionary.
  - Lock in current documented endpoint gating:
    - `GET /games/{game-id}/mods` may emit `_limit`, `_offset`, `_q`, `tags`, `tags-in`, `tags-not-in`, `metadata_blob`, `metadata_kvp`, `_sort`, `id`, `name_id`, `status`, `visible`, `submitted_by`.
    - `GET /games/{game-id}/mods/{mod-id}/files` currently stays constrained to `_limit`, `_offset`, and `id` in this wrapper.
    - `GET /me/subscribed` keeps the shared list filters already audited here and must inject `game_id` whenever `X-Modio-Platform` is set.
  - Validate deterministic encoding for `metadata_kvp` ordering, repeated paging fields as strings, and boolean form/body values such as `include_dependencies`.
  - Add a transport-level guard test that bearer-authenticated public reads do not redundantly append `api_key` when the chosen auth mode is bearer-only/preferred.

- **Documented response/error handling to exercise in integration-style tests**
  - Success cases to execute through the live transport seam:
    - `GET /authenticate/terms` → `200`
    - `GET /agreements/types/{agreement-type-id}/current` → `200`
    - `GET /me` → `200`
    - `POST /oauth/logout` → `200`
    - `POST /games/{game-id}/mods/{mod-id}/subscribe` → both documented `201` created **and** `200` already subscribed
    - `DELETE /games/{game-id}/mods/{mod-id}/subscribe` → documented `204 No Content`
  - Error cases worth locking in because the docs call them out explicitly and they shape higher-layer control flow:
    - `429` with `retry-after`, including `retry-after: 0` rolling-rate-limit behavior and error refs `11008` (global) vs `11009` (endpoint)
    - auth exchange / session failures such as `11011`, `11012`, `11013`, `11014`, `11005`
    - terms-required `11074`
    - key restriction `11016` / `11017`
    - account locked `17053`
    - unsubscribe error `15005`
    - subscribe restrictions `15000` / `15001`
    - generic `422` validation envelope with nested `errors`
    - fallback `5xx` categorization when the body is missing or incomplete

- **Transport constraints not yet covered well enough**
  - Rate-limit behavior is normalized today, but not exercised as a real executed-response seam.
  - Portal/platform behavior is only dictionary-tested today; add executed request coverage because these headers alter server behavior, not just local config.
  - Localization is only config-tested today; add executed-header coverage for `Accept-Language`, especially because the docs describe response fallback semantics and portal/tag localization behavior.
  - Download constraints should remain documented but not expanded into a downloader yet: `binary_url` may carry a verification hash, expire, and require bearer auth depending on `api_access_options` from `GET /games/{game-id}`.

Exact doc-grounded rules/constraints to preserve or harden in implementation notes/tests:

- Intro/auth docs: API key auth is query-based and read-only; OAuth uses `Authorization: Bearer ...`; bearer tokens can also be used for `GET`.
- Platform docs: `X-Modio-Platform` should be included for platform-specific approval visibility; `X-Modio-Portal` affects `display_name_portal`; supported values are case-insensitive.
- Localization docs: `Accept-Language` controls localized responses and defaults to English (US) when no valid value is supplied.
- Rate-limit docs: obey `retry-after`; treat `retry-after: 0` as rolling-rate-limit and wait 60 seconds; preserve `11008` vs `11009` distinction.
- Subscription docs: `POST /games/{game-id}/mods/{mod-id}/subscribe` returns either `201` or `200`; `DELETE /games/{game-id}/mods/{mod-id}/subscribe` returns `204`; platform-targeted `GET /me/subscribed` requires `game_id`.
- Game/modfile docs: `api_access_options` and expiring hashed `download.binary_url` values mean transport should not normalize download URLs into stable identifiers.

Docs ambiguities/risks to carry forward:

- The docs mix generic `api.mod.io/v1` examples with documented game/user host patterns (`g-{game-id}.modapi.io`, `u-{user-id}.modapi.io`), so host selection should stay explicit/configurable and be covered by tests.
- The intro docs mention `.test.mod.io` variants, but the exact host-construction rule is easy to mis-assume; avoid magic inference.
- `exchange-email-security-code` still appears to contain the previously noted schema typo around required fields versus the actual `security_code` body.
- OpenID docs still describe request `date_expires` as capped to one week while returned access-token docs continue to describe a much longer default expiry; keep request sanitation and response normalization separate.
- Platform/portal values are documented as case-insensitive, while current tests/config examples use mixed casing (`WINDOWS`, `steam`); preserve configured values outbound and do not over-normalize unless an implementation need appears.

Execution-ready recommendation: Task 2 should implement a minimal live `ModioHttpTransport.execute(...)` seam plus a test double / harness that can validate full URL assembly, header/query/body encoding, and normalized HTTP/error handling for the already wrapped endpoints above. That gives this repo the highest-value remaining confidence boost while keeping all work strictly inside the vendor seam and avoiding premature `aerobeat-tool-api` integration.

---

### Task 2: Implement live transport hardening and integration-style tests

**Bead ID:** `oc-2w2`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the agreed next live-transport/integration-test slice using current official mod.io docs and the pinned local reference repos as source of truth. Strengthen request execution/building where needed, add integration-style tests around request assembly and documented response/error handling, and keep all vendor concerns local to this repo. Do not pull in AeroBeat API-manager responsibilities. Update README/docs/seam plan as needed, update the active plan with what actually happened, run repo-local validation/tests, commit and push by default, and close the bead with validation + commit details.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/network/modio_http_transport.gd`
- `src/models/modio_client_config.gd`
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `.testbed/tests/fixtures/global_rate_limit_error.json`
- `.testbed/tests/fixtures/validation_error.json`
- `.testbed/tests/fixtures/admin_filter_error.json`
- `.testbed/tests/fixtures/server_error.json`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md`

**Status:** ✅ Complete

**Results:** Implemented the thin live `ModioHttpTransport.execute(...)` seam plus `prepare_request(...)` so this repo now validates final assembled mod.io requests instead of only intermediate request dictionaries. `ModioClientConfig` now supports explicit `api` / `game` / `user` host selection, optional sandbox host generation, explicit base-URL override precedence, and normalized joins without double slashes. `ModioVendorAdapter` was tightened so public browse/terms/agreement/game/mod requests stay query-authenticated while `/me`, `/me/subscribed`, logout, and subscription writes stay bearer-only. Added integration-style GUT coverage for final encoded URLs, form bodies, Authorization / Accept-Language / X-Modio-Platform / X-Modio-Portal / X-Modio-Delegation-Token handling, documented `GET` / `POST` / `DELETE` request execution behavior, and executed-response normalization for `authenticate/terms`, current agreement, `/me`, logout, subscribe/unsubscribe, `429` + `Retry-After` + `11008` / `11009`, plus auth / terms / admin / validation / server error envelopes from the research note. Repo-local validation now passes via scaffold smoke test plus GUT test suite.

---

### Task 3: QA against official transport expectations

**Bead ID:** `oc-mwv`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the live-transport hardening and integration-style tests against the current official mod.io docs and pinned local references, not memory. Confirm the new behavior matches documented host/header/query/response expectations, fixtures/tests are grounded in current API truth, and vendor concerns remain local to this repo. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with clear pass/fail findings.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit against official transport expectations

**Bead ID:** `oc-7jb`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-07`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the live-transport hardening and integration-style tests against the current official mod.io docs and pinned local references. Confirm the implementation is accurate, still isolated as a vendor adapter seam, and ready for later composition by `aerobeat-tool-api`. Make only minimum necessary fixes, rerun validation/tests, update the active plan, commit/push if changes were made, and close with a clear pass/fail reason.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-02-aerobeat-vendor-modio-live-transport-and-integration-tests.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⏳ In Progress

**What We Built:** Pending.

**Reference Check:** Pending.

**Commits:**
- Pending

**Lessons Learned:** Pending.

---

*Completed on 2026-05-02*
