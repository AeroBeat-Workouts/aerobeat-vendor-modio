# AeroBeat Vendor Mod.io Modfile CRUD Coverage

**Date:** 2026-05-03  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Continue the push toward 100 percent mod.io REST coverage by implementing the dedicated modfile CRUD slice first, while keeping the repo as a thin documented-field wrapper with strong request-shape validation only.

---

## Overview

Derrick chose to stage the upload/file-pipeline family instead of tackling the whole operational surface at once. That means we should start with the simplest coherent piece: modfile CRUD itself, and leave multipart/source-modfile/cook/platform-management behavior for later slices.

The key boundaries for this slice are now explicit. This repo should wrap documented fields only, not accept local file paths as a convenience API, not inspect local artifacts, and not drift into cook/platform workflow behavior. We should enforce strong documented request-shape validation, but keep file-orchestration and higher-level release workflow out of scope.

This plan starts with a research pass so we can pin the exact documented modfile CRUD routes, request shapes, validation rules, auth expectations, and response semantics before coder work begins.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Guide + collection authoring slice | `.plans/2026-05-03-aerobeat-vendor-modio-guide-and-collection-authoring.md` |
| `REF-02` | Collection subscription slice | `.plans/2026-05-03-aerobeat-vendor-modio-collection-subscription-coverage.md` |
| `REF-03` | Umbrella remaining-coverage plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-04` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-05` | Current README scope | `README.md` |
| `REF-06` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-07` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-08` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-09` | Current implementation | `src/` |
| `REF-10` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the modfile CRUD slice

**Bead ID:** `oc-dif`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Review the refreshed local official mod.io corpus and define the dedicated modfile CRUD slice. Confirm exact documented routes, methods, auth requirements, request-body rules, response semantics, and specific request-shape validation we should enforce. Keep local file-path assistance, multipart workflow orchestration, source-modfile handling, and cook/platform-management out of scope. Surface any real decisions only if the docs force them. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-modfile-crud.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Reviewed `REF-06` through `REF-08` and defined the dedicated modfile CRUD slice as exactly three authenticated write endpoints, with the slice intentionally limited to the raw REST contract only and explicitly excluding local file-path assistance, multipart workflow orchestration, source-modfile handling, and cook/platform-management behavior.

Recommended slice to add now:
- `POST /games/{game-id}/mods/{mod-id}/files`
- `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}`
- `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}`

Auth / transport truth:
- Treat all three routes as **bearer-auth required**.
- `modio-unity` requires authentication on all three generated endpoints, and the official REST pages document permission-gated `403` failures for every route.
- Preserve the documented content types exactly:
  - add modfile: `multipart/form-data`
  - edit modfile: `application/x-www-form-urlencoded`
  - delete modfile: no request body; upstream SDK/Unity still model the route with form-url-encoded request setup, so the vendor seam should keep the outgoing body empty while not inventing any body fields.

Exact request-body contract and validation to enforce:
- **Add modfile** (`add-modfile.api.mdx`)
  - Path ids required: `game-id`, `mod-id`.
  - Documented body fields: `filedata`, `upload_id`, `version`, `changelog`, `active`, `filehash`, `metadata_blob`, `platforms`.
  - Enforce the only explicit required-field rule from the docs: **exactly one of `filedata` or `upload_id` must be supplied**. `filedata` is required if `upload_id` is omitted; `upload_id` is required if `filedata` is omitted.
  - Because this repo must keep local file-path assistance and multipart orchestration out of scope, accept `filedata` only as a raw caller-supplied multipart value and `upload_id` only as a raw caller-supplied completed multipart session id; do not add local zip inspection, local filesize checks, file compression helpers, multipart session helpers, or automatic switching behavior.
  - Enforce documented field names/types only: `version` string, `changelog` string, `active` boolean, `filehash` string, `metadata_blob` string, `platforms` array of documented platform strings.
  - For `platforms`, constrain values to the documented platform enum from the modfile schema: `ALL`, `WINDOWS`, `MAC`, `LINUX`, `ANDROID`, `IOS`, `XBOXONE`, `XBOXSERIESX`, `PLAYSTATION4`, `PLAYSTATION5`, `SWITCH`, `OCULUS`, `SOURCE`, `SWITCH2`, `WINDOWSSERVER`, `LINUXSERVER`.
  - Do **not** enforce local-only rules that require inspecting the submitted archive (zip-ness, real filename characters, actual file size, MD5 match, or multi-directory overwrite behavior); those are provider-side validation/runtime concerns unless the caller has already supplied a raw field that can be passed through untouched.
  - Preserve the documented note that `input_json` is not supported here.
- **Edit modfile** (`edit-modfile.api.mdx`)
  - Path ids required: `game-id`, `mod-id`, `file-id`.
  - Optional documented body fields: `version`, `changelog`, `active`, `metadata_blob`.
  - Enforce documented field names/types only: `version` string, `changelog` string, `active` boolean, `metadata_blob` string.
  - Do **not** invent support for replacing the file binary, upload ids, platforms, source files, cook state, or platform-status management on this route.
  - Do **not** force a minimum-one-field rule unless repo policy already requires it elsewhere; the docs do not mark any edit field as required.
  - Docs contain a wording tension: the prose says fields other than `changelog`, `version`, and `active` should use a new file, while the explicit request schema still documents `metadata_blob`. Treat the schema as source of truth for this repo and allow `metadata_blob`.
- **Delete modfile** (`delete-modfile.api.mdx`)
  - Path ids required: `game-id`, `mod-id`, `file-id`.
  - No body schema. Validate path ids only and reject extra body fields in any higher-level helper API.
  - Preserve the documented behavioral note that the live active modfile cannot be deleted and that deletion is only available to the game administrator or the original uploader; these are provider-enforced semantics, not extra local request fields.

Response semantics to preserve:
- add modfile → `201` + `Modfile Object`, with `Location` header on success
- edit modfile → `200` + `Modfile Object`
- delete modfile → `204` no content
- Keep documented permission/validation failures transparent in docs/tests:
  - add modfile: `403` permission failure, `422` payload unreadable/unvalidated by mod.io
  - edit modfile: `403` permission failure
  - delete modfile: `403` permission failure, including the documented live-modfile delete restriction (`15009`)

Cross-corpus drift / implementation note:
- `modio-unity` exposes `AddModfileRequest` for create, but currently has **no generated `EditModfileRequest` body object** even though the refreshed REST docs clearly document four editable form fields and the generated edit endpoint still exists. Treat this as upstream generator incompleteness, not a repo decision; implementation should follow the refreshed REST contract.
- The C++ SDK and Unity generated endpoints corroborate the route/method/content-type/auth contract for add/edit/delete, but they also carry broader upload helpers and multipart orchestration outside this repo's intended seam. Follow the REST request schema, not the higher-level SDK workflow behavior.

Scope boundary for the coder pass:
- ✅ include only add/edit/delete modfile on the documented routes above
- ✅ include strong request-shape validation for documented fields and the `filedata` xor `upload_id` rule
- ✅ preserve modfile-response normalization semantics already used by existing modfile reads
- ❌ no local path/file convenience API, archive inspection, compression, multipart session/parts lifecycle, source-modfile coverage, cloud-cook flows, or platform-management helpers
- ❌ no provider-local workflow that decides when to use multipart vs direct upload

Decision check:
- **No Derrick decision is required before implementation** if we keep the slice as the thin documented REST wrapper above.

---

### Task 2: Implement the agreed modfile CRUD slice

**Bead ID:** `oc-71y`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the researched modfile CRUD slice using the refreshed local official corpus as source of truth. Keep the seam thin, wrap documented fields only, enforce strong documented request-shape validation, and keep local file-path assistance, source-modfile handling, multipart workflow orchestration, and cook/platform-management out of scope. Update fixtures/tests/docs/plan, run repo-local validation, commit/push by default, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-modfile-crud.md`

**Status:** ✅ Complete

**Results:** Implemented the dedicated modfile CRUD slice in `src/modio_vendor_adapter.gd` and extended transport/adapter coverage in `.testbed/tests/` using the refreshed local official corpus (`REF-06` through `REF-08`) as the source of truth. Added bearer-authenticated request builders for `POST /games/{game-id}/mods/{mod-id}/files`, `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}`, and `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` with the documented content types, documented-field validation only, positive path-id validation, and the required `filedata` xor `upload_id` rule. Added normalized write helpers for `201` create, `200` update, and `204` delete semantics using the existing modfile object normalization. Updated `README.md` and `docs/modio-seam-plan.md` to describe the new slice and its deliberate scope boundary, then ran repo-local validation successfully: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

---

### Task 3: QA the modfile CRUD slice

**Bead ID:** `oc-1q1`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the modfile CRUD slice against the refreshed local official corpus. Confirm request shapes, auth mode, response handling, validation behavior, tests, and seam docs are truthful and that vendor-local boundaries remain intact. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-modfile-crud.md`

**Status:** ✅ Complete

**Results:** Independently verified the dedicated modfile CRUD slice against `REF-06` through `REF-08` and confirmed the implementation matches the refreshed local official corpus without requiring code changes. Verified `POST /games/{game-id}/mods/{mod-id}/files` stays bearer-authenticated `multipart/form-data` with documented fields only plus enforced `filedata` xor `upload_id`; verified `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` stays bearer-authenticated `application/x-www-form-urlencoded` and allows exactly the documented editable fields `version`, `changelog`, `active`, and `metadata_blob`; verified `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` remains a path-id-only delete that normalizes `204 No Content` with an empty outgoing body. Confirmed README and seam docs truthfully describe the slice and its deliberate exclusions, and confirmed vendor-local boundaries remain intact: no source-modfile coverage, multipart-session orchestration, cook/cloud-cook behavior, platform-status management, or local file assistance leaked into this slice. Re-ran repo-local validation successfully: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (51/51 tests passed).

---

### Task 4: Audit the modfile CRUD slice

**Bead ID:** `oc-2n6`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-10`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the modfile CRUD slice against the refreshed local official corpus. Confirm the added coverage is accurate, docs are truthful, request-shape validation matches the documented contract, and the seam still avoids local file assistance, source-modfile handling, multipart workflow orchestration, and cook/platform-management leakage. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-modfile-crud.md`

**Status:** ✅ Complete

**Results:** Independently truth-checked the dedicated modfile CRUD slice against `REF-06` through `REF-08` and found no residual implementation drift requiring code changes. Confirmed `POST /games/{game-id}/mods/{mod-id}/files` remains bearer-authenticated `multipart/form-data` on the documented route with documented fields only, enforced `filedata` xor `upload_id`, documented platform enum validation, and no source-modfile / multipart-session / local file-assistance / cook-platform workflow leakage. Confirmed `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` remains bearer-authenticated `application/x-www-form-urlencoded` with only the documented editable fields `version`, `changelog`, `active`, and `metadata_blob`, matching the refreshed REST schema despite the Unity generator lacking a dedicated edit request object. Confirmed `DELETE /games/{game-id}/mods/{mod-id}/files/{file-id}` remains a path-id-only bearer-authenticated delete with empty outgoing body and normalized `204 No Content` semantics, while preserving provider-enforced constraints like the live-modfile delete restriction (`15009`) as upstream behavior rather than local request fields. Re-checked `README.md` and `docs/modio-seam-plan.md` and found the documented scope truthful: this slice stays limited to add/edit/delete modfile only and explicitly leaves source-modfile flows, multipart upload orchestration, local file-path assistance, archive inspection, cloud-cook flows, and platform-management helpers out of scope. Re-ran repo-local validation successfully: `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://tests/validate_scaffold.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (51/51 tests passed).

---

## Final Results

**Status:** ✅ Complete

**What We Built:** A thin documented-field wrapper for the dedicated modfile CRUD slice only: bearer-authenticated add/edit/delete request builders, documented request-shape validation including `filedata` xor `upload_id`, normalized `201`/`200`/`204` write responses, transport coverage, and truthful seam documentation without leaking higher-level upload/cook/platform workflow behavior into the vendor seam.

**Reference Check:** `REF-06` through `REF-08` satisfied. The implementation, tests, and docs match the refreshed local official corpus for request routes/methods/auth/content types, editable field scope including `metadata_blob`, create/delete response semantics, and the deliberate exclusion of source-modfile, multipart-session orchestration, local file assistance, archive inspection, cloud-cook flows, and platform-management helpers.

**Commits:**
- `80726f5` - Add dedicated modfile CRUD seam
- `5c5044f` - docs: record modfile CRUD QA verification
- Pending auditor plan-update commit if this audit modifies tracked files.

**Lessons Learned:** For this slice, the refreshed REST docs remain the source of truth over generator gaps in `modio-unity` (notably the missing dedicated edit request object), while the SDK/Unity surfaces are still useful to corroborate auth, route, and transport expectations.

---

*Completed on 2026-05-03*
