# AeroBeat Vendor Mod.io Upload Pipeline Coverage

**Date:** 2026-05-04  
**Status:** Complete  
**Agent:** Chip 🐱💻

---

## Goal

Extend `aerobeat-vendor-modio` into the next truthful mod.io coverage family by wrapping the upload-side provider surfaces — starting with source-modfile handling and multipart upload/session orchestration — without drifting into higher-level AeroBeat workflow orchestration.

---

## Overview

Yesterday’s vendor-modio push closed out the previous umbrella plan’s clean read/community/auth surface and left the remaining heavy families explicitly called out at handoff: source-modfile handling, multipart upload/session orchestration, cook/cloud-cook/platform management, and monetization / entitlements / S2S. Derrick’s stated goal remains literal 100% mod.io API coverage, and the standing rule for these heavier slices is to ask up front only if the docs force a real boundary/product decision; otherwise keep executing through coder → QA → audit.

This plan picks up at the next upload-side family after modfile CRUD. The immediate target is the provider-local file pipeline surface that still fits a thin wrapper posture: source-modfile reads/writes and multipart upload/session lifecycle coverage, using the refreshed local official mod.io corpus as source of truth over stale generator wording whenever they disagree. The key constraint is that this repo may wrap provider endpoints and validate request shapes strongly, but it must not silently turn into a full upload workflow engine, install orchestrator, or broader AeroBeat release-management layer.

The research pass confirms that the natural next thin-wrapper family is exactly eight endpoints: two `/sources` endpoints and six multipart upload/session endpoints. The corpus also exposes a few real pre-slice decisions before implementation starts: whether this repo stops at raw endpoint coverage or grows workflow helpers, whether source uploads mirror the full documented request contract or the narrower SDK helper subset, and how strictly to treat documented field names and raw-binary multipart semantics where the SDK/generator drift.

If the refreshed docs show that some upload-side endpoints are only meaningful when paired with cook/platform/publishing policy or monetization/purchase semantics, I’ll split those into separate follow-on plans instead of smuggling them into this slice. The intended result here is a truthful batch that advances endpoint-family coverage while preserving the repo’s vendor-adapter seam.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Last session handoff memory | `/home/derrick/.openclaw/workspace/memory/2026-05-03.md` |
| `REF-02` | Prior remaining-coverage umbrella plan | `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md` |
| `REF-03` | Current mod.io REST research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-04` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-05` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-06` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-07` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-08` | Current implementation | `src/` |
| `REF-09` | Current fixture/test corpus | `.testbed/tests/` |
| `REF-10` | Completed modfile CRUD slice | `.plans/2026-05-03-aerobeat-vendor-modio-modfile-crud.md` |
| `REF-11` | Upload-family pre-slice audit note | `docs/modio-upload-pre-slice-audit-2026-05-04.md` |

---

## Tasks

### Task 1: Research the next upload-side provider-local slice

**Bead ID:** `oc-0ai`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the current wrapped repo surface against the refreshed official local mod.io corpus and produce an execution-ready map for the next upload-side family after modfile CRUD. Focus first on source-modfile handling and multipart upload/session orchestration; distinguish which endpoints are still clean thin-wrapper vendor surfaces versus which would force cook/platform-management, publishing workflow, or monetization/product-policy decisions. Update the plan with exact findings, recommended execution order, and any required human decision points, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/`

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`
- `docs/modio-upload-pre-slice-audit-2026-05-04.md`

**Status:** ✅ Complete

**Results:**

Research completed against `REF-05` through `REF-07` and recorded in `REF-11`.

Exact next endpoint map after the completed modfile CRUD slice:

1. **Source-modfile handling**
   - `GET /games/{game-id}/mods/{mod-id}/sources`
     - browse source modfiles
     - no body
     - paginated `Modfile Object[]`
   - `POST /games/{game-id}/mods/{mod-id}/sources`
     - add source modfile
     - `multipart/form-data`
     - documented body fields:
       - `filedata` binary, required iff `upload_id` omitted
       - `upload_id` string, required iff `filedata` omitted
       - `version` string
       - `changelog` string
       - `active` boolean
       - `filehash` MD5 string
       - `metadata_blob` string
       - `platforms[]` platform-string array
     - `201 Created` + `Modfile Object`

2. **Multipart upload/session orchestration endpoints**
   - `POST /games/{game-id}/mods/{mod-id}/files/multipart`
     - create upload session
     - `application/x-www-form-urlencoded`
     - body: required `filename`, optional `nonce`
   - `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions`
     - list sessions
     - optional `status` query enum (`0 incomplete`, `1 pending`, `2 processing`, `3 complete`, `4 cancelled`)
   - `GET /games/{game-id}/mods/{mod-id}/files/multipart`
     - list uploaded parts
     - required `upload_id` query
   - `PUT /games/{game-id}/mods/{mod-id}/files/multipart`
     - upload one part
     - required `upload_id` query
     - required `Content-Range` header
     - optional `Digest` header
     - raw binary body for the part bytes
   - `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`
     - complete session
     - required `upload_id` query
   - `DELETE /games/{game-id}/mods/{mod-id}/files/multipart`
     - terminate session
     - required `upload_id` query
     - normalized `204 No Content`

Why this is the correct next family:

- `REF-10` intentionally stopped before source uploads and multipart lifecycle work.
- These eight endpoints are still provider-local transport surfaces and do **not** require pulling cook/cloud-cook, file platform-status management, or monetization into the same slice.
- `POST /sources` is the natural companion to existing modfile create support because it shares the same payload concepts while targeting a different upstream route.
- multipart session endpoints are the natural companion to existing `upload_id` support because they are the documented provider mechanism for producing the `upload_id` consumed by modfile/source-modfile create.

Upstream corpus drift that implementation must respect explicitly:

- docs are the field-name source of truth; the SDK and Unity references are sanity checks, not contract owners
- `modio-unity` includes add-source + multipart generated endpoints but does not expose a checked-in generated browse-source endpoint in the current tree
- `modio-sdk` source helper drifts from docs by appending `metadata` instead of documented `metadata_blob`, and by omitting documented `active` / `filehash` fields from its higher-level source-create params
- multipart create drift:
  - docs mark `nonce` optional
  - Unity generated request constructor requires `nonce`
  - SDK upload op always sends a hash-derived nonce
- multipart part drift:
  - docs prose + Unity endpoint show raw binary body semantics for `PUT /files/multipart`
  - docs schema labeling and SDK request constants still say `application/x-www-form-urlencoded`
- digest drift:
  - docs prose / Unity comments say `SHA-256`
  - docs error table also mentions `CRC32C`

True pre-slice Derrick decisions that should be answered **before** coder work starts:

1. **Slice boundary: raw wrapper only vs workflow helper**
   - **Explanation:** The endpoint family itself is straightforward, but the SDK and Unity samples also show higher-level behavior like archive compression, automatic 50 MiB chunking, resumable upload checks, and final attach flows. That behavior can live either in this vendor adapter or in a higher-level repo.
   - **Why it matters technically:** If this repo owns workflow helpers, the public seam grows beyond endpoint coverage and starts needing file-path APIs, chunking/retry policy, progress behavior, and stateful orchestration. If it stays raw, the coder can implement each endpoint directly and leave orchestration above the seam.
   - **Options:**
     - A. Raw endpoint wrappers only, with strong request-shape validation
     - B. Raw wrappers plus a minimal multipart helper (chunking/resume/finalize)
     - C. Full SDK-style upload workflow helper surface
   - **Recommended:** **A**

2. **Source-modfile request parity: full docs vs reduced SDK-style helper subset**
   - **Explanation:** The docs show `POST /sources` as essentially the same request contract as add-modfile, including `active`, `filehash`, and `filedata` xor `upload_id`. The SDK high-level source helper only surfaces a smaller subset.
   - **Why it matters technically:** This choice defines the public request schema in `aerobeat-vendor-modio`. Choosing the SDK subset would knowingly drop documented fields. Choosing docs parity preserves literal API coverage and keeps source/modfile semantics aligned.
   - **Options:**
     - A. Full documented parity for `POST /sources`
     - B. Reduced SDK-style subset (`version`, `changelog`, `metadata_blob`, `platforms`, plus upload attachment)
     - C. Full parity plus undocumented compatibility aliases
   - **Recommended:** **A**

3. **Strict documented names vs SDK-drift compatibility aliases**
   - **Explanation:** The official docs say `metadata_blob` and optional `nonce`. The SDK helper drifts to `metadata`, and Unity makes `nonce` look required even though docs say optional.
   - **Why it matters technically:** If the seam accepts drift aliases, the repo becomes more forgiving than the docs and starts encoding unofficial compatibility policy. If it stays strict, tests and DTOs remain predictable and traceable to the official corpus.
   - **Options:**
     - A. Strict docs only: accept `metadata_blob`; treat `nonce` as optional; no aliasing
     - B. Accept both documented and drift aliases for convenience
     - C. Follow SDK/Unity behavior instead of docs where they disagree
   - **Recommended:** **A**

4. **Multipart part representation in the seam API**
   - **Explanation:** The raw upload-part endpoint is not a normal form write. It wants query + headers + binary bytes, and the checked-in corpus is a little inconsistent about labeling that body.
   - **Why it matters technically:** This determines whether the adapter API stays transport-truthful or hides the raw contract behind file-path/chunk abstractions. It also affects test fixtures and transport encoding logic.
   - **Options:**
     - A. Expose raw bytes body + explicit `upload_id` query + explicit `Content-Range` / optional `Digest` headers
     - B. Wrap bytes behind a helper object but still expose the endpoint directly
     - C. Treat it like a generic form/body write even though the docs prose says otherwise
   - **Recommended:** **A**

Things that do **not** need Derrick before coding and can stay in coder → QA → audit:

- implement all eight endpoints with the documented methods/paths/query/header/body contracts
- keep multipart session list/parts list pagination + `status` filtering truthful
- normalize delete-session as `204 No Content`
- pass `Digest` through as an optional opaque header string while documenting the algorithm drift
- preserve the seam rule that cook/platform-management/monetization stay out of this slice

**Recommended execution order once Derrick answers the four decisions above:**

1. `GET /games/{game-id}/mods/{mod-id}/sources`
2. `POST /games/{game-id}/mods/{mod-id}/sources`
3. `POST /games/{game-id}/mods/{mod-id}/files/multipart`
4. `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions`
5. `GET /games/{game-id}/mods/{mod-id}/files/multipart`
6. `PUT /games/{game-id}/mods/{mod-id}/files/multipart`
7. `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`
8. `DELETE /games/{game-id}/mods/{mod-id}/files/multipart`

If Derrick accepts the recommended options, all eight endpoints can proceed immediately in the next coder slice without pulling in cloud-cook, per-platform status management, or monetization.

**Derrick decision lock-in (2026-05-04):**
- Question 1 → **A**: raw endpoint wrappers only, with strong validation
- Question 2 → **A**: full documented parity for `POST /sources`
- Question 3 → **A**: strict docs-only field names/semantics (`metadata_blob`, optional `nonce`, no drift aliases)
- Question 4 → **A**: raw bytes multipart-part representation with explicit query/header transport details
- Additional direction: because this repo is intentionally a REST API wrapper, treat the refreshed official REST docs as truth when Unity/plugin surfaces drift.

---

### Task 2: Implement the next upload-side slice

**Bead ID:** `oc-9p0`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the next approved upload-side mod.io slice as defined by the latest research pass, covering the full eight-endpoint source-modfile + multipart upload/session family. Preserve exact request/path/header/body contracts from the refreshed official REST docs as source of truth, add only minimal provider-local helpers, extend tests/fixtures/docs, update the plan with what changed and what was deliberately deferred, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`

**Status:** ⏳ Pending → 🚧 In Progress → ✅ Complete

**Results:** Implemented the approved eight-endpoint upload slice in the thin vendor adapter with docs-first request/response behavior and no workflow expansion.

Exact endpoint coverage added:
- `GET /games/{game-id}/mods/{mod-id}/sources`
- `POST /games/{game-id}/mods/{mod-id}/sources`
- `POST /games/{game-id}/mods/{mod-id}/files/multipart`
- `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions`
- `GET /games/{game-id}/mods/{mod-id}/files/multipart`
- `PUT /games/{game-id}/mods/{mod-id}/files/multipart`
- `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`
- `DELETE /games/{game-id}/mods/{mod-id}/files/multipart`

What changed:
- `src/modio_vendor_adapter.gd`
  - added request builders + normalization helpers for the full source-modfile and multipart upload/session family
  - preserved exact REST-doc field names/semantics for `POST /sources` including `active`, `filehash`, `metadata_blob`, `platforms[]`, and `filedata` xor `upload_id`
  - validated multipart create as `filename` plus optional `nonce`
  - validated multipart session browse as documented `status`, `_limit`, `_offset` only
  - modeled multipart part upload as raw body transport with explicit `upload_id` query, required `Content-Range`, and optional opaque `Digest`
- `src/network/modio_http_transport.gd`
  - extended the execution seam to carry `raw_body` / `body_bytes` and dispatch raw-byte uploads without disturbing existing form/multipart flows
- `.testbed/tests/test_modio_vendor_adapter.gd`
  - added request/validation + normalization coverage for the new source/multipart slice
- `.testbed/tests/test_modio_http_transport.gd`
  - added executed-request coverage for raw multipart part upload headers/query/body bytes
- `.testbed/tests/fixtures/multipart_upload_session.json`
- `.testbed/tests/fixtures/multipart_upload_sessions.json`
- `.testbed/tests/fixtures/multipart_upload_parts.json`
- `docs/modio-seam-plan.md`
- `README.md`
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`

Corpus drift handled:
- treated refreshed REST docs as truth where Unity/plugin terminology or behavior drifted
- kept `metadata_blob` and optional `nonce` exactly as documented instead of aliasing SDK/Unity names
- documented/implemented `Digest` as an opaque optional header because corpus sources disagree on algorithm examples
- modeled multipart part upload as raw bytes despite schema/generator drift that tends to imply form-like bodies

Validation evidence:
- `~/.local/bin/godot --headless --path .testbed -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- result: **54/54 tests passed**

Deliberately deferred / kept out of scope:
- no chunk/workflow orchestration helpers beyond minimal provider-local validation/normalization
- no cloud-cook, platform-management, monetization, archive/file-path helpers, or broader upload workflows
- no invented digest-algorithm policy beyond passing through the caller-provided header value

---

### Task 3: QA the upload-side slice

**Bead ID:** `oc-z21`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest upload-side implementation against the refreshed local official mod.io corpus. Confirm request shapes, transport behavior, fixtures, docs, and boundary discipline are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`

**Status:** ✅ Complete

**Results:** Independently QAed the upload-side slice against `REF-05` through `REF-07`, with special attention to the locked docs-first rules for source-modfile parity and raw multipart transport.

Exact QA findings:
- Verified the implemented request builders match the refreshed REST corpus for all eight scoped endpoints:
  - `GET /games/{game-id}/mods/{mod-id}/sources`
  - `POST /games/{game-id}/mods/{mod-id}/sources`
  - `POST /games/{game-id}/mods/{mod-id}/files/multipart`
  - `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions`
  - `GET /games/{game-id}/mods/{mod-id}/files/multipart`
  - `PUT /games/{game-id}/mods/{mod-id}/files/multipart`
  - `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`
  - `DELETE /games/{game-id}/mods/{mod-id}/files/multipart`
- Confirmed `POST /sources` preserves the full documented contract from `REF-05`: `active`, `filehash`, `metadata_blob`, `platforms[]`, and strict `filedata` xor `upload_id`, with no SDK/Unity compatibility aliasing.
- Confirmed multipart create keeps documented `filename` plus optional `nonce`, and session browse stays restricted to documented `status`, `_limit`, and `_offset` with the correct `0..4` status enum.
- Confirmed `PUT /files/multipart` preserves explicit `upload_id` query handling, required `Content-Range`, optional opaque `Digest`, and executed-request raw-body transport at the HTTP seam.
- Confirmed fixtures, README scope text, seam docs, response normalizers, and Task 2 plan claims all line up with the refreshed corpus and keep upload workflow orchestration out of scope.

Minimum fix made during QA:
- Tightened multipart part validation in `src/modio_vendor_adapter.gd` so `part_body` now accepts raw `PackedByteArray` bytes only.
- Removed the prior permissive `String` acceptance, which drifted from Derrick’s locked raw-bytes rule and the REST docs’ binary part semantics.
- Extended `.testbed/tests/test_modio_vendor_adapter.gd` with a regression assertion that string-backed part uploads are rejected.

Changed files:
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`

Validation evidence:
- Command: `~/.local/bin/godot --headless --path .testbed -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Result: **54/54 tests passed** after the QA fix.

Commit/push:
- Not performed in QA, because the repo worktree already contains unrelated pre-existing plan/doc churn outside this bead and I kept the QA changes minimal for auditor review.

---

### Task 4: Audit the upload-side slice

**Bead ID:** `oc-gon`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-11`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest upload-side implementation against the refreshed local official mod.io corpus and the repo seam plan. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and clearly documents anything deferred to later cook/platform or monetization plans. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`

**Status:** ✅ Complete

**Results:** Independently audited the final upload-side slice against `REF-05` through `REF-11`, the refreshed local REST docs, and the locked repo-boundary rules. No additional code fixes were required beyond QA's raw-bytes regression fix.

Exact audit findings:
- Re-verified all eight scoped wrappers use the correct documented methods and paths and stay inside the approved seam:
  - `GET /games/{game-id}/mods/{mod-id}/sources`
  - `POST /games/{game-id}/mods/{mod-id}/sources`
  - `POST /games/{game-id}/mods/{mod-id}/files/multipart`
  - `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions`
  - `GET /games/{game-id}/mods/{mod-id}/files/multipart`
  - `PUT /games/{game-id}/mods/{mod-id}/files/multipart`
  - `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`
  - `DELETE /games/{game-id}/mods/{mod-id}/files/multipart`
- Confirmed `POST /sources` keeps full docs-first parity from `REF-05`: documented field names only (`filedata`, `upload_id`, `version`, `changelog`, `active`, `filehash`, `metadata_blob`, `platforms`), strong validation, and strict `filedata` xor `upload_id` semantics with no Unity/SDK alias drift.
- Confirmed multipart create/list/parts/complete/delete wrappers preserve the documented auth, query, and body contracts from `REF-06` through `REF-08`, including required explicit `upload_id` query handling where documented.
- Specifically verified QA's fix is correct and necessary: multipart part upload now rejects `String` payloads and accepts raw `PackedByteArray` bytes only, which matches Derrick's locked raw-bytes rule and the refreshed REST-doc intent for binary part transport.
- Confirmed the HTTP seam still executes multipart part uploads as raw bytes with `application/octet-stream`, required `Content-Range`, optional `Digest`, explicit `upload_id` query, and no higher-level chunk/workflow orchestration.
- Confirmed fixtures, response normalizers, README text, seam docs, and Task 2/Task 3 claims remain truthful after the QA fix.
- Confirmed no cook/cloud-cook/platform-management/monetization/workflow-helper behavior leaked into this slice; the upload family remains a thin provider wrapper with request-shape validation only.

Fixes made during audit:
- None. QA's raw-bytes tightening already brought the slice into compliance.

Changed files:
- `.plans/2026-05-04-aerobeat-vendor-modio-upload-pipeline-coverage.md`

Validation evidence:
- Command: `~/.local/bin/godot --headless --path .testbed -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Result: **54/54 tests passed** during the audit pass.

Commit/push:
- No new code fix commit was needed from audit.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Added and independently validated the upload-side mod.io coverage slice for source-modfile handling plus multipart upload/session orchestration, with docs-first request validation, truthful response normalization, transport-level raw-byte multipart execution, refreshed fixtures/docs/plan coverage, and no spillover into cook/platform/monetization or broader workflow helpers.

**Reference Check:** Final implementation and audit findings were checked against `REF-05` through `REF-11`. The final seam matches the refreshed REST corpus for the scoped upload endpoints and preserves the locked docs-first/raw-bytes boundary decisions.

**Commits:**
- `a28a765` - coder implementation handoff for upload pipeline coverage
- `a4ebb4a` - QA follow-up tightening multipart part uploads to raw bytes only

**Lessons Learned:** The mod.io generated/body-schema surfaces still drift around multipart upload semantics, so the safest rule for this family is to trust the refreshed REST prose and endpoint contracts, keep the wrapper raw and narrow, and enforce binary-only multipart parts explicitly at the adapter boundary.

---

*Completed on 2026-05-04*
