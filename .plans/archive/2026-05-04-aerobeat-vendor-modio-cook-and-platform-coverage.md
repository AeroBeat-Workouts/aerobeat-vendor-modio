# AeroBeat Vendor Mod.io Cook and Platform Coverage

**Date:** 2026-05-04  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Extend `aerobeat-vendor-modio` into the next truthful mod.io coverage family after source/multipart upload by mapping and then, once clarified, wrapping the cook / cloud-cook / platform-management provider surfaces without drifting into higher-level AeroBeat release orchestration or broader product policy.

---

## Overview

The previous upload-pipeline slice is now complete: source-modfile handling and multipart upload/session orchestration landed, passed QA, and passed audit using the refreshed official REST docs as truth over SDK or Unity drift. That clears the next heavy family identified in the earlier handoff: cook / cloud-cook / platform-management.

This family is riskier than the prior slice because it is closer to release workflow, platform-state mutation, and potentially provider behavior that can feel orchestration-adjacent. Before any implementation starts, we need the same ambiguity-clearing pass we used for uploads: identify the exact endpoint set, verify which surfaces still fit a thin vendor-wrapper seam, and turn all real boundary or implementation-policy questions into a simple option list for Derrick.

The intended approach is still docs-first and seam-preserving. If the refreshed official corpus shows that some cook/platform endpoints are clean request/response wrappers, they can become the next execution slice. If the docs reveal places where wrapping them would implicitly force workflow engines, policy automation, or blended upload/publish behavior, those need to be called out explicitly and decided before coder work begins.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Last session handoff memory | `/home/derrick/.openclaw/workspace/memory/2026-05-03.md` |
| `REF-02` | Completed upload pipeline slice | `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md` |
| `REF-03` | Prior remaining-coverage umbrella plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-04` | Current mod.io REST research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-05` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-06` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-07` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-08` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-09` | Current implementation | `src/` |
| `REF-10` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the cook / cloud-cook / platform-management family

**Bead ID:** `oc-y7d`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the current wrapped repo surface against the refreshed official local mod.io corpus and produce an execution-ready map for the next cook / cloud-cook / platform-management family after the completed upload pipeline slice. Identify the exact documented endpoints, group them into coherent provider-local slices, distinguish which ones still fit a thin vendor adapter seam, and turn every real pre-slice boundary or implementation-policy question into a simple Derrick decision memo with options and a recommendation. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise audit note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-cook-and-platform-coverage.md`
- `docs/modio-cook-platform-pre-slice-audit-2026-05-04.md`

**Status:** ✅ Complete

**Results:** Pre-slice ambiguity audit completed against `REF-06` / `REF-07` / `REF-08` and the current repo surface in `REF-09` / `REF-10`.

Exact next documented endpoints after the completed upload pipeline slice:
- **Cook inspection slice**
  - `GET /games/{game-id}/mods/{mod-id}/cooks`
  - docs: `REF-06/public/en-us/restapi/docs/browse-modfile-cooks.api.mdx`
  - response schema: paginated `Modfile Cook Object[]`
  - object schema path: `REF-06/public/en-us/restapi/docs/schemas/modfile-cook-object.schema.mdx`
  - no documented request body or endpoint-specific filters on the current page
- **Cloud-cooking instance management slice**
  - `POST /games/{game-id}/cloud-cooking/finalization`
  - docs: `REF-06/public/en-us/restapi/docs/finalize-cloud-cooking.api.mdx`
  - no request body
  - response: `204 No Content`
- **Modfile platform-management slice**
  - `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms`
  - docs: `REF-06/public/en-us/restapi/docs/manage-platform-status.api.mdx`
  - content type: `application/x-www-form-urlencoded`
  - documented body fields: `approved[]`, `denied[]`
  - response: `200 OK` + `Modfile Object`
  - docs explicitly say this endpoint does **not** set a file live; callers must use the already-implemented `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` with `active=true` after approval when they want promotion

Important upstream drift / boundary findings:
- The refreshed docs mirror currently documents only one cook endpoint in this family: `GET /games/{game-id}/mods/{mod-id}/cooks`.
- `REF-07/modio/modio/core/ModioDefaultRequestParameters.h` includes an extra SDK request constant, `POST /games/{game-id}/mods/{mod-id}/cooks` (`UpsertModfileCooksRequest`), but no matching local official docs page was found. This is real corpus drift and should not be silently imported.
- `REF-08/Modio/API/Generated/Endpoints/ManagePlatformStatus.cs` exists, but it is a bodyless generated stub even though the docs page clearly defines `approved[]` / `denied[]` request fields.
- Generated Unity endpoints for `BrowseModfileCooks` and `FinalizeCloudCooking` were not found in the checked-in local tree, so the docs mirror remains the best source of truth here.
- `REF-06/public/en-us/restapi/docs/edit-modfile.api.mdx` confirms that, when cross-platform submissions are supported and the modfile is approved, `active=true` sets the modfile live on all approved platforms.
- `REF-06/public/en-us/game-integration/restapi/getting-started/restapi-platforms.md` distinguishes lowercase request-header platform targeting values (for `X-Modio-Platform`) from the platform enum strings used in mod/modfile platform request/response schemas. The seam should validate body fields against the documented mod/modfile platform enum set, not header-value shortcuts.

True pre-slice Derrick decisions:
1. **Docs-first strictness vs SDK-only cook upsert parity**
   - Why it matters: adding SDK-only `POST /mods/{mod-id}/cooks` would force non-doc request/response inference and break the current docs-first seam rule.
   - Options:
     - Wrap only officially documented cook endpoint(s).
     - Also expose the SDK-only undocumented `POST /mods/{mod-id}/cooks`.
     - Defer all cook coverage until docs confirm a write/upsert story.
   - **Recommendation:** wrap only officially documented cook endpoint(s); do **not** add undocumented SDK-only `POST /mods/{mod-id}/cooks` unless Derrick explicitly wants SDK-parity-over-docs risk.
2. **Raw endpoint wrappers only vs release-workflow convenience helper**
   - Why it matters: a helper that approves and then sets live would cross from vendor transport into release orchestration/policy.
   - Options:
     - Raw endpoint wrappers only; callers compose approval and the existing `active=true` live-toggle.
     - Add a convenience helper that sequences approve/deny and optional go-live.
     - Defer platform-management until a higher-level AeroBeat release workflow exists.
   - **Recommendation:** raw endpoint wrappers only.
3. **Include cloud-cooking finalization now or defer as an ops/admin surface**
   - Why it matters: the endpoint is thin but game/cloud-instance scoped rather than per-mod/per-file scoped, so it may belong to a later admin-facing slice unless AeroBeat actively needs it.
   - Options:
     - Include it now because it is documented and bodyless.
     - Defer it unless AeroBeat has immediate cloud-cooking instance lifecycle needs.
     - Keep it in the plan but hold implementation until usage is confirmed.
   - **Recommendation:** defer it unless Derrick already knows AeroBeat will actively drive cloud-cooking finalization.

Things that do **not** need Derrick before coder → QA → audit:
- wrapping the documented `GET /mods/{mod-id}/cooks` request/response
- wrapping the documented `POST /files/{file-id}/platforms` request/response
- validating `approved[]` / `denied[]` body shape
- reusing the existing modfile response normalization for platform-status writes
- adding fixtures/tests for `Modfile Cook Object[]` and platform-status-updated `Modfile Object` payloads
- normalizing `204 No Content` for cloud-cooking finalization if that endpoint is approved into the slice

Immediate implementation-ready endpoint map once those decisions are locked:
- `GET /games/{game-id}/mods/{mod-id}/cooks`
- `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms`
- optional, only if explicitly approved for this slice: `POST /games/{game-id}/cloud-cooking/finalization`

**Derrick decision lock-in (2026-05-04):**
- wrap only documented cook endpoints; do not add undocumented SDK-only cook upsert
- raw wrappers only; no release-workflow convenience helper
- include `POST /games/{game-id}/cloud-cooking/finalization` in this slice now

Concise audit note added at `docs/modio-cook-platform-pre-slice-audit-2026-05-04.md`.

---

### Task 2: Implement the next approved cook/platform slice

**Bead ID:** `oc-6wf`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved cook/platform mod.io slice exactly as defined by the research and Derrick’s decision lock-in. Wrap only the documented cook endpoint(s), keep platform management as raw wrappers only, and include cloud-cooking finalization in this slice. Preserve exact request/path/header/body semantics from the refreshed official REST docs, keep the wrapper thin, add only minimal provider-local helpers, extend tests/fixtures/docs, update the plan with exact results and any deliberate deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `src/network/`
- `.testbed/tests/`
- `.testbed/tests/fixtures/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `src/network/modio_http_transport.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `.testbed/tests/fixtures/modfile_cooks.json`
- `.testbed/tests/fixtures/modfile_platform_status_updated.json`
- `docs/modio-seam-plan.md`
- `README.md`
- `.plans/2026-05-04-aerobeat-vendor-modio-cook-and-platform-coverage.md`

**Status:** ⏳ Pending → 🚧 In Progress → ✅ Complete

**Results:** Implemented the approved docs-first cook/platform slice exactly within the thin vendor seam:
- added `build_modfile_cooks_request()` + `normalize_modfile_cooks_response()` for `GET /games/{game-id}/mods/{mod-id}/cooks`
- added `build_manage_modfile_platforms_request()` + `normalize_manage_modfile_platforms_response()` for `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms`
- added `build_finalize_cloud_cooking_request()` + `normalize_finalize_cloud_cooking_response()` for `POST /games/{game-id}/cloud-cooking/finalization`
- added schema-based validation for platform status bodies using wrapper input fields `approved` / `denied`, emitted on-wire as repeated form keys `approved[]` / `denied[]`
- extended the transport form encoder so `application/x-www-form-urlencoded` array fields serialize as repeated keys, which was required to preserve the documented platform-management wire format exactly
- added fixture coverage for `Modfile Cook Object` lists and platform-status-updated `Modfile Object` responses
- extended adapter + transport tests to assert final encoded URLs, bearer/auth behavior, exact form body strings, and `204 No Content` normalization for cloud-cooking finalization
- updated repo docs/README to record the new seam and the still-deliberate exclusions

Validation evidence:
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_modio_vendor_adapter.gd -gexit` → `32/32 passed`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_modio_http_transport.gd -gexit` → `22/22 passed`

Corpus drift handled:
- the refreshed official REST docs include `GET /games/{game-id}/mods/{mod-id}/cooks` plus bodyless `POST /games/{game-id}/cloud-cooking/finalization`, but do not expose the SDK/Unity-style cook upsert route; this implementation deliberately omitted that undocumented `POST /games/{game-id}/mods/{mod-id}/cooks` path
- platform-management stayed schema/body driven from the REST docs instead of leaning on SDK/header shorthand or collapsing into existing `active=true` modfile update behavior

Deliberate deferrals preserved:
- no undocumented cook upsert wrapper
- no release-workflow helper that chains platform approval with go-live
- no broader cloud-cook orchestration beyond the documented finalization POST

---

### Task 3: QA the cook/platform slice

**Bead ID:** `oc-y4a`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest cook/platform implementation against the refreshed official local mod.io corpus. Confirm request shapes, transport behavior, fixtures, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-cook-and-platform-coverage.md`

**Status:** ✅ Complete

**Results:** Independently re-verified the cook/platform slice against `REF-06` through `REF-08` and found no implementation drift requiring code changes. Exact QA findings:
- `GET /games/{game-id}/mods/{mod-id}/cooks` matches the refreshed REST docs exactly: path/method are correct, request is bodyless, auth stays public `api_key_query`, and response normalization preserves the documented `Modfile Cook Object` fields (`cook_uuid`, `modfile`, lowercase cook `platform`, `status`, timestamps, `metadata`, `logs`, `filename`, `filesize`, `version`) using `.testbed/tests/fixtures/modfile_cooks.json`.
- `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms` matches the refreshed REST docs exactly: bearer-authenticated `application/x-www-form-urlencoded`, documented route/path ids, schema-based wrapper input validation limited to `approved` / `denied`, and on-wire serialization emitted as repeated `approved[]` / `denied[]` keys (`approved%5B%5D=WINDOWS&approved%5B%5D=PLAYSTATION5&denied%5B%5D=SWITCH2`).
- Platform body validation remains correctly separated from `X-Modio-Platform` header targeting semantics: request-body values are validated against the documented mod/modfile platform enum (`WINDOWS`, `PLAYSTATION5`, `SWITCH2`, etc.) rather than the lowercase header-token values from `REF-06/public/en-us/game-integration/restapi/getting-started/restapi-platforms.md`.
- `POST /games/{game-id}/cloud-cooking/finalization` remains correctly bodyless on the documented path and normalizes `204 No Content` as `{ ok = true, finalized = true, data = {} }`.
- Confirmed no undocumented SDK-only cook upsert leaked into the seam: the repo exposes only the documented cook browse wrapper and does **not** add `POST /games/{game-id}/mods/{mod-id}/cooks`.
- Re-checked the generic form-array transport change and found no regression evidence in existing form-urlencoded semantics: `_encode_parameters()` now repeats array keys, which is required for the documented platform-management wire format, while existing non-array form routes still retain their exact locked body strings in transport coverage (for example modfile update remains `active=false&changelog=Timing%20cleanup&metadata_blob=game_version%3A1.1.1&version=1.1.1`, cloud finalization remains empty-body, and delete/bodyless writes remain empty-body).
- README/seam docs remain truthful about the slice boundary: raw wrappers only, no release-workflow helper, no undocumented cook upsert, and no broader cloud-cook orchestration beyond the finalization POST.

Validation rerun:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`54/54` tests passed, `1786` asserts)

Minimum code fixes required: none. Commit/push not required beyond this plan update.

---

### Task 4: Audit the cook/platform slice

**Bead ID:** `oc-5xe`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest cook/platform implementation against the refreshed official local mod.io corpus and the repo seam plan. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and clearly documents anything deferred to later monetization or other policy-heavy families. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-cook-and-platform-coverage.md`

**Status:** ✅ Complete

**Results:** Independent audit pass against `REF-06` through `REF-08` plus the repo seam/docs state in `REF-04`, `REF-05`, `REF-09`, and `REF-10`. Exact audit findings:
- `GET /games/{game-id}/mods/{mod-id}/cooks` remains docs-correct: public `api_key_query` auth, no request body, exact documented path/method, and response normalization preserves the documented `Modfile Cook Object` fields while keeping the provider’s lowercase cook `platform` values (`ps5`, `switch2`) intact.
- `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms` remains docs-correct: bearer-authenticated `application/x-www-form-urlencoded`, exact documented route ids, wrapper input limited to `approved` / `denied`, and on-wire encoding uses repeated `approved[]` / `denied[]` keys exactly as the refreshed docs require.
- Platform-status validation stays anchored to the documented mod/modfile body-schema enum strings (`ALL`, `WINDOWS`, `PLAYSTATION5`, `SWITCH2`, etc.) via `MODFILE_PLATFORM_VALUES`; it does **not** accept the lowercase `X-Modio-Platform` header-targeting tokens from `REF-06/public/en-us/game-integration/restapi/getting-started/restapi-platforms.md` as body aliases.
- `POST /games/{game-id}/cloud-cooking/finalization` remains a thin bodyless wrapper on the documented path and continues to normalize `204 No Content` as a successful empty-data response with `finalized = true`; no broader cloud-cooking lifecycle helper/orchestration surface leaked into the seam.
- Reconfirmed the seam does **not** expose the undocumented SDK-only `POST /games/{game-id}/mods/{mod-id}/cooks` upsert route anywhere in the adapter/tests/docs surface; only the documented cook browse wrapper exists.
- Rechecked the transport-level repeated-form-key change and found no scalar form-urlencoded regression evidence: `_encode_parameters()` now repeats array keys for documented array bodies, while existing scalar form routes still retain their exact locked output strings and bodyless write routes still serialize as empty bodies.
- README + `docs/modio-seam-plan.md` remain truthful about the boundary: raw wrappers only, no release-workflow convenience helper, no undocumented cook upsert, and no extra cloud-cook orchestration beyond finalization.

Minimum code fixes required: none.

Validation rerun:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`54/54` tests passed, `1786` asserts)

Commit/push: not required because the audit found no implementation drift and made no code fixes.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The cook/platform slice remains shipped exactly at the locked thin-wrapper boundary: documented cook browse coverage, documented per-platform status management with repeated form keys, and documented cloud-cooking finalization with bodyless `204` normalization.

**Reference Check:** Satisfied `REF-06` through `REF-08` for endpoint truth, plus `REF-04`, `REF-05`, `REF-09`, and `REF-10` for repo-scope/documentation/test truth. No deliberate deviations remain beyond the already-locked exclusion of the undocumented SDK-only cook upsert route and any release-workflow helper behavior.

**Commits:**
- `1e70494` - coder implementation baseline audited in this pass
- No new commit required from audit; plan updated locally with exact findings.

**Lessons Learned:** When the refreshed official REST mirror and generated SDK/Unity surfaces drift, the clean path is to keep the seam docs-first and prove any transport change with locked execute-level body-string coverage so array-form fixes do not silently regress older scalar form routes.

---

*Completed on 2026-05-04*
