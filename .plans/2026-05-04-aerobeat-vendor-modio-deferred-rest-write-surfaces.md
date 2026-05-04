# AeroBeat Vendor Mod.io Deferred REST Write Surfaces

**Date:** 2026-05-04  
**Status:** Draft  
**Agent:** Chip 🐱‍💻

---

## Goal

Resume the remaining confirmed REST-backed deferred work in `aerobeat-vendor-modio` while explicitly excluding Unity/SDK-only drifted surfaces unless a separate research pass proves the REST contract or produces a mod.io clarification request.

---

## Overview

The final remaining-coverage audit is complete. It confirmed that the repo is now truth-locked across the major clean mod.io REST families, and that the remaining frontier splits into two categories: (1) confirmed REST-backed but intentionally deferred work, and (2) drift-blocked surfaces such as `/me/iap/*/sync` or SDK-only cook upsert where local REST endpoint pages do not cleanly confirm the contract.

Derrick has now set the governing rule for the rest of this push: if it is confirmed in the REST API, it gets wrapped; if it only appears in Unity/SDK or otherwise drifts away from the REST corpus, it needs its own research pass, and if the research remains inconclusive we should contact mod.io and ask them to clarify the intended contract for a Godot integration.

This plan starts with the next coherent deferred REST-backed write family rather than reopening the drift-blocked sync work. After re-checking the refreshed local REST corpus, the best next cluster is narrower than the initial sketch: the thin form-encoded mod maintenance writes for tags, metadata KVP, and dependencies. Those six endpoints share the same seam shape (mod-scoped bearer writes with `application/x-www-form-urlencoded` array payloads plus standard `201`/`204` message-or-no-content responses) and can land truthfully without pulling in multipart upload handling or reopening collection-surface scope.

The rest of the earlier candidate list remains confirmed REST-backed but not first in line. Mod media add/delete/reorder is cleanly documented, yet it is a materially different multipart/media-management subfamily with extra request-shape decisions (`multipart/form-data`, uploaded binaries, gallery ordering semantics, and mixed image/youtube/sketchfab payloads). Collection member removal is also cleanly documented, but it belongs to the collection mutation seam rather than this mod-maintenance batch. Unity/SDK-only or REST-drifted surfaces remain explicitly out of scope for this plan and belong in separate research/escalation work if they need to move.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Final remaining-coverage audit | `.plans/2026-05-04-aerobeat-vendor-modio-final-remaining-coverage-audit.md` |
| `REF-02` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-03` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-04` | Current implementation | `src/` |
| `REF-05` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the next coherent deferred REST-backed write family

**Bead ID:** `oc-2so`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-05`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the deferred confirmed REST-backed surface against the refreshed local official REST corpus and identify the next coherent implementation batch. Prefer the smallest truthful family that still groups naturally. Explicitly exclude Unity/SDK-only drifted surfaces from this plan. If any candidate endpoint is not cleanly REST-page-backed, move it into a separate research/escalation note instead of including it here. Update the plan with the exact next family and any real pre-slice decisions, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` only if a concise escalation note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-deferred-rest-write-surfaces.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Re-audited the deferred confirmed write surface against `REF-03`, then cross-checked current seam shape in `REF-02`/`REF-04`. Recommendation: the exact next coherent batch is the **mod maintenance form-write family** only: `POST /games/{game-id}/mods/{mod-id}/tags`, `DELETE /games/{game-id}/mods/{mod-id}/tags`, `POST /games/{game-id}/mods/{mod-id}/metadatakvp`, `DELETE /games/{game-id}/mods/{mod-id}/metadatakvp`, `POST /games/{game-id}/mods/{mod-id}/dependencies`, and `DELETE /games/{game-id}/mods/{mod-id}/dependencies`. These six endpoints are all cleanly page-backed in `REF-03`, share the same bearer + `application/x-www-form-urlencoded` transport shape, and map naturally onto the existing read-side mod tags / metadata KVP / dependencies seam already present in `REF-04`.

Pre-slice decisions that still matter: (1) whether Derrick wants this implementation bead to include the documented `sync` boolean on dependency add now, or to ship a narrower append/remove-only first pass; recommendation: **include `sync` now** because it is explicitly documented on the REST page and stays within the same endpoint contract. (2) Whether to normalize these writes as generic message/no-content responses only, or add convenience flags such as `created`, `deleted`, `synced`, `tags_added`, `metadata_deleted`; recommendation: **keep normalization thin** and only add minimal booleans already consistent with existing seam patterns (`created`/`deleted` where status-code-derived), avoiding invented semantic summaries. (3) For metadata deletion, whether to expose the REST-documented key-only delete behavior (`metadata[]=key` removes all values for that key) without extra client-side validation; recommendation: **preserve the REST contract exactly** and do not over-constrain it locally.

Explicitly deferred but still REST-confirmed: mod media add/delete/reorder (`POST /games/{game-id}/mods/{mod-id}/media`, `DELETE /games/{game-id}/mods/{mod-id}/media`, `PUT /games/{game-id}/mods/{mod-id}/media/reorder`) and collection member removal (`DELETE /games/{game-id}/collections/{collection-id}/mods`). They were not excluded for doc-truth reasons; they were deferred because they form different natural batches (multipart media-management and collection mutation, respectively). Unity/SDK-only drifted surfaces remain excluded from this plan unless a separate REST-confirmation/escalation pass resolves them.

---

### Task 2: Implement the approved deferred REST-backed write subset

**Bead ID:** `oc-vhq`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-05`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved deferred REST-backed write subset exactly as defined by the research and Derrick’s decision lock-in. For this slice, implement the six-endpoint mod write family: tags add/delete, metadata KVP add/delete, and dependencies add/delete. Preserve exact request/path/header/body semantics from the refreshed REST docs, include the documented dependency `sync` boolean, keep write normalization thin, preserve REST metadata delete semantics exactly, extend tests/fixtures/docs, update the plan with exact results and explicit non-REST deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-deferred-rest-write-surfaces.md`

**Status:** ✅ Complete

**Results:** Implemented the approved six-endpoint mod-maintenance write family in `src/modio_vendor_adapter.gd` with thin request builders, thin write-response normalizers, and minimal docs-first field validation aligned to the existing adapter seam in `REF-04`:
- `POST /games/{game-id}/mods/{mod-id}/tags`
- `DELETE /games/{game-id}/mods/{mod-id}/tags`
- `POST /games/{game-id}/mods/{mod-id}/metadatakvp`
- `DELETE /games/{game-id}/mods/{mod-id}/metadatakvp`
- `POST /games/{game-id}/mods/{mod-id}/dependencies`
- `DELETE /games/{game-id}/mods/{mod-id}/dependencies`

Exact implementation notes validated against `REF-03`:
- tags add/delete preserve bearer-authenticated `application/x-www-form-urlencoded` writes with repeated `tags[]` form fields
- metadata add/delete preserve repeated `metadata[]` form fields and intentionally keep the REST-documented key-only delete behavior untouched (`metadata[]=key` remains valid and is not over-normalized locally)
- dependency add/delete preserve repeated `dependencies[]` integer fields, and add-only preserves the documented optional `sync` boolean exactly as documented
- write normalization stays thin: add responses normalize the returned message payload plus `location` and a status-derived `created` flag; delete responses normalize as no-content writes plus a status-derived `deleted` flag

Validation + evidence:
- extended `.testbed/tests/test_modio_vendor_adapter.gd` with request-shape assertions for all six routes, including auth mode, content type, body shape, add-only `sync`, and metadata key-only delete coverage
- added success-normalization coverage for all six routes using the existing message/no-content fixture seam
- command: `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- result: `39/39` scripts passed, `62/62` tests passed, `2116` asserts

Docs updated:
- `README.md`
- `docs/modio-seam-plan.md`

Deliberate deferrals preserved:
- REST-confirmed but different-family mod media add/delete/reorder and collection member removal remain out of this bead exactly as planned
- Unity/SDK-only drifted surfaces, including `/me/iap/*/sync`, remain deferred and undocumented-contract work was not pulled into this implementation slice

---

### Task 3: QA the approved deferred REST-backed write subset

**Bead ID:** `oc-6gj`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-05`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest deferred REST-backed write implementation against the refreshed official REST corpus. Confirm request shapes, transport behavior, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-deferred-rest-write-surfaces.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit the approved deferred REST-backed write subset

**Bead ID:** `oc-2q8`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-05`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest deferred REST-backed write implementation against the refreshed official REST corpus and the repo seam plan. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and clearly distinguishes confirmed REST work from separately researched drift cases. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-deferred-rest-write-surfaces.md`

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
