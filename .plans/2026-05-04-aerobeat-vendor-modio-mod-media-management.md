# AeroBeat Vendor Mod.io Mod Media Management

**Date:** 2026-05-04  
**Status:** Draft  
**Agent:** Chip 🐱‍💻

---

## Goal

Land the next smallest coherent confirmed REST-backed mod.io slice by wrapping mod media add / reorder / delete surfaces truthfully and keeping the seam thin.

---

## Overview

The near-wrap corpus sweep confirmed that the remaining confirmed REST-backed frontier is now small and deliberate. Among the remaining families, mod media management is the smallest coherent batch that is clearly page-backed, not drift-blocked, and not legacy/deprecated.

This slice covers the mod-scoped media management writes: add media, reorder media, and delete media. Before coder starts, we still want the same quick truth pass used throughout this push: verify the exact REST-backed paths and body semantics, confirm whether there are any media-payload quirks that need an explicit decision, and then run coder → QA → audit.

The standing rule remains unchanged: if it is clearly confirmed in the REST API, it gets wrapped. Unity/SDK-only drifted behavior does not control the contract.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Near-wrap next-slice and audit plan | `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md` |
| `REF-02` | Final remaining-coverage audit | `.plans/2026-05-04-aerobeat-vendor-modio-final-remaining-coverage-audit.md` |
| `REF-03` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-04` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-05` | Current implementation | `src/` |
| `REF-06` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the confirmed mod media management family

**Bead ID:** `oc-y2a`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Verify the exact confirmed REST-backed mod media management family, including add media, reorder media, and delete media. Identify any real pre-slice decisions needed around request-body semantics or multipart handling, update the plan with exact findings, and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` only if a concise note materially helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-mod-media-management.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Confirmed the exact official REST-backed family from `REF-04`:
- `POST /games/{game-id}/mods/{mod-id}/media` (`public/en-us/restapi/docs/add-mod-media.api.mdx`)
- `PUT /games/{game-id}/mods/{mod-id}/media/reorder` (`public/en-us/restapi/docs/reorder-mod-media.api.mdx`)
- `DELETE /games/{game-id}/mods/{mod-id}/media` (`public/en-us/restapi/docs/delete-mod-media.api.mdx`)

Exact request/body findings:
- **Add media** is `multipart/form-data` only. It accepts uploaded image parts, `sync` boolean, repeated `youtube[]` links, and repeated `sketchfab[]` links. The page explicitly says image body names are flexible for gallery uploads, while the schema examples show `logo`, `image1`, and `image2`; thin wrapper guidance: do not over-model arbitrary image field names unless we intentionally add a generic multipart-part escape hatch.
- **Reorder media** is `PUT` with `application/x-www-form-urlencoded` arrays for `images[]`, `youtube[]`, and `sketchfab[]`. The page note says you can only reorder existing media and any differences in the media arrays cause `400`; this implies caller-supplied arrays should represent the intended full existing ordering for each touched media family, not partial patch semantics.
- **Delete media** is `DELETE` with `application/x-www-form-urlencoded` arrays for `images[]`, `youtube[]`, and `sketchfab[]`; semantics are delete-the-listed-members, with `204 No Content` on success.

Real pre-slice decisions still needed:
1. **Multipart file-part honesty for add-media.** Current transport in `REF-05` serializes multipart fields as plain text parts (`name="..."`) and current tests assert path-like strings such as `@/tmp/file.png`, but it does not emit filename/content-type/binary file parts. For this media slice Derrick needs to choose whether to:
   - first add true file-part multipart support / a documented file-descriptor shape, then expose add-media fully, or
   - deliberately scope this slice to the two form-encoded routes first (`reorder` + `delete`) and defer `add-media` until multipart file semantics are made honest.
2. **Wrapper shape for arbitrary gallery image fields.** Because the official page says gallery image body names are flexible, decide whether the public seam should:
   - expose a generic `images`/`parts` mapping that preserves arbitrary field names, or
   - intentionally support only a narrow documented subset (`logo` plus repeated arrays/known keys) and document that as a repo-level constraint.
3. **Local validation strictness for reorder.** The docs confirm server-side full-array mismatch rejection, but do not require client-side enforcement. Thin-seam recommendation is pass-through validation only (type/array shape), not local reconstruction against current mod media state.

Recommended implementation subset from research:
- safest smallest truthful batch: ship **delete + reorder** first because both are standard form-encoded array writes already aligned with existing transport behavior;
- only ship **add-media** in the same bead if we also add explicit honest multipart file-part support or a clearly documented generic multipart-part contract that can actually send image bytes.

---

### Task 2: Implement the approved mod media slice

**Bead ID:** `oc-qnk`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved confirmed REST-backed mod media management slice exactly as defined by the research and Derrick’s decision lock-in. For this slice, implement the full family: `POST /games/{game-id}/mods/{mod-id}/media`, `PUT /games/{game-id}/mods/{mod-id}/media/reorder`, and `DELETE /games/{game-id}/mods/{mod-id}/media`. Preserve exact request/path/header/body semantics from the refreshed REST docs, keep the wrapper thin, and add truthful multipart file-part support needed to send image bytes for add-media rather than faking the contract. Extend tests/fixtures/docs, update the plan with exact results and explicit non-REST deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `src/modio_vendor_adapter.gd`
- `src/network/modio_http_transport.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_http_transport.gd`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-04-aerobeat-vendor-modio-mod-media-management.md`

**Status:** ✅ Complete

**Results:** Implemented the full approved confirmed REST-backed mod media family:
- `POST /games/{game-id}/mods/{mod-id}/media`
- `PUT /games/{game-id}/mods/{mod-id}/media/reorder`
- `DELETE /games/{game-id}/mods/{mod-id}/media`

What actually changed:
- Added `build_add_mod_media_request`, `build_reorder_mod_media_request`, and `build_delete_mod_media_request` in `src/modio_vendor_adapter.gd`.
- Added `normalize_add_mod_media_response`, `normalize_reorder_mod_media_response`, and `normalize_delete_mod_media_response` so add-media normalizes the documented message-object write and reorder/delete normalize `204 No Content` writes.
- Added thin docs-first request validation for this slice only:
  - add-media accepts a generic `images` mapping whose keys become the multipart field names sent to mod.io
  - each uploaded image value may now be a truthful multipart file-part descriptor `{ "filename", optional "content_type", "data" }` where `data` is raw `PackedByteArray` bytes
  - reorder/delete only validate documented array shape plus URL shape for `youtube` / `sketchfab`; they deliberately do **not** attempt local full-array mismatch enforcement because the REST page assigns that rule to the server
- Extended `ModioHttpTransport` multipart encoding so multipart requests can emit real file parts with `Content-Disposition ...; filename="..."`, optional `Content-Type`, and raw byte payloads instead of only text-only parts.
- Added/updated integration-style tests covering request builders, response normalizers, final encoded multipart bodies, and final encoded form-array bodies.
- Updated `README.md` and `docs/modio-seam-plan.md` to record the new thin seam and the generic-image-field contract.

Validation evidence:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`65/65` passing; one pre-existing Float/Int comparison warning remains in an unrelated checkout/S2S normalization test)

Deliberate deferrals / non-REST scope kept out:
- no higher-level media workflow helpers were added
- no client-side reconstruction of current remote media state for reorder was added
- no narrow hardcoded gallery slot API (`logo` / `image1` / `image2` only) was imposed; the seam preserves arbitrary image field names through the generic `images` mapping

---

### Task 3: QA the approved mod media slice

**Bead ID:** `oc-64i`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest mod media implementation against the refreshed official REST corpus. Confirm request shapes, transport behavior, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-mod-media-management.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the approved mod media slice

**Bead ID:** `oc-ue9`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest mod media implementation against the refreshed official REST corpus and the repo seam plan. Confirm the added coverage is accurate, thin, and clearly bounded. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-mod-media-management.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⏳ Pending

**What We Built:** Pending.

**Reference Check:** Pending.

**Commits:**
- Pending.

**Lessons Learned:** Pending.

---

*Completed on 2026-05-04*
