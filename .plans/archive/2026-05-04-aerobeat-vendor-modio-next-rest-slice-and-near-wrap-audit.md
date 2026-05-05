# AeroBeat Vendor Mod.io Next REST Slice and Near-Wrap Audit

**Date:** 2026-05-04  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Land the next smallest coherent confirmed REST-backed mod.io slice while also running a near-wrap audit to verify that no additional confirmed REST functionality has been missed as we approach the end of the current coverage push.

---

## Overview

The repo has now landed the major confirmed REST-backed families across browse/detail/community reads, upload pipeline, cook/platform management, monetization reads, checkout, documented S2S, monetization-team routes, and the deferred mod-maintenance write family. The remaining frontier is now relatively small, which means the highest value is no longer just raw implementation speed — it is pairing each next slice with a fresh corpus-truth check so we do not leave behind any small confirmed REST-backed gaps by accident.

This plan therefore runs two linked tracks: (1) identify and land the next smallest coherent confirmed REST-backed family, and (2) run a near-wrap corpus sweep after updating the current frontier so we know whether any other confirmed REST pages remain unwrapped, intentionally deferred, or blocked by drift. The goal is to shrink the remaining set while also increasing confidence that what remains is truly intentional.

The working rule remains unchanged: confirmed REST-backed routes get wrapped; Unity/SDK-only drifted surfaces do not get silently implemented and instead require separate research or direct clarification from mod.io if the docs remain inconclusive.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Final remaining-coverage audit | `.plans/2026-05-04-aerobeat-vendor-modio-final-remaining-coverage-audit.md` |
| `REF-02` | Deferred REST write family | `.plans/2026-05-04-aerobeat-vendor-modio-deferred-rest-write-surfaces.md` |
| `REF-03` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-04` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-05` | Current implementation | `src/` |
| `REF-06` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research the next smallest coherent confirmed REST-backed slice

**Bead ID:** `oc-w5o`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the current remaining confirmed REST-backed surface against the refreshed local REST corpus and identify the next smallest coherent slice to implement. Prefer a family that is compact, clearly page-backed, and low ambiguity. Update the plan with the exact recommended next slice and any real pre-slice decisions, then close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` only if a concise note materially helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Re-read the remaining-frontier classification in `REF-01`, the deferred-write follow-up in `REF-02`, the current seam docs in `REF-03`, and the refreshed official REST pages in `REF-04`, then sanity-checked the repo surface in `REF-05`. Recommendation: the exact next smallest coherent confirmed REST-backed slice should be **S2S disconnect only** — `DELETE /s2s/connections/{portal-id}` from `s-2-s-disconnect-user.api.mdx`.

Why this is the best next slice before the near-wrap audit:
- it is the smallest remaining confirmed REST page-backed route: one endpoint, one path param, no body, `204 No Content`
- it fits an already-established seam instead of opening a new one: the repo already has service-token-backed S2S transport for transaction routes, so this can reuse the existing S2S auth path rather than introducing a fresh transport/payload family
- it is lower ambiguity than the other likely candidates:
  - **mod media add/delete/reorder** is confirmed REST-backed, but it is a three-endpoint mixed multipart/form/delete family with uploaded binaries, gallery-order semantics, and more request-shape surface
  - **collection member removal** is also compact, but it lives in the collection admin/membership seam and overlaps conceptually with the already wrapped collection update `sync=true` path, making it slightly less clean for a near-wrap truth pass
  - **event feeds** are page-backed but explicitly include deprecated/legacy behavior (`/me/events`) and a broader filter/normalization surface than this pass needs
  - **mod create/edit/delete families** are much larger and materially more validation-heavy, especially `edit-mod` multipart semantics

Real pre-slice decisions Derrick still needs to make:
- **None, if the slice stays a thin raw S2S wrapper.** The docs are specific enough to implement this as a service-token-authenticated `DELETE /s2s/connections/{portal-id}` with path-only input and normalized no-content success semantics, reusing the existing S2S auth boundary already present in `src/`.
- Optional naming choice only, not a blocker: whether the public helper should keep the raw doc term `portal_id` or expose a repo-local alias such as `studio_user_id` while still serializing the documented `{portal-id}` path param. That is a wrapper ergonomics choice, not a contract ambiguity.

Deferred after this recommendation, still confirmed REST-backed: mod media add/delete/reorder, `DELETE /games/{game-id}/collections/{collection-id}/mods`, and the legacy event feeds. Those remain better candidates for the post-slice near-wrap audit to classify/order than for this smallest-next-batch slot.

---

### Task 2: Implement the approved next REST slice

**Bead ID:** `oc-149`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved next confirmed REST-backed slice exactly as defined by the research and Derrick’s decision lock-in. For this slice, implement `DELETE /s2s/connections/{portal-id}` as a thin raw S2S wrapper using the existing service-token seam. Preserve exact request/path/header/body semantics from the refreshed REST docs, keep the wrapper thin, extend tests/fixtures/docs, update the plan with exact results and explicit non-REST deferrals, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md`

**Status:** ✅ Complete

**Results:** Implemented the approved smallest confirmed REST-backed slice exactly as a thin service-token S2S wrapper: `DELETE /s2s/connections/{portal-id}`.

Exact implementation/results:
- added `build_s2s_disconnect_request(portal_id: String)` in `src/modio_vendor_adapter.gd`
- added `_normalize_s2s_disconnect_path(...)` so the wrapper stays path-only, trims input, requires a positive integer `portal_id`, and keeps the existing explicit `service_token` auth separation
- reused `_build_service_read_headers()` rather than form helpers so the request stays bodyless and does **not** invent a `Content-Type` header for this REST page
- added `normalize_s2s_disconnect_response(status_code, headers = {})` with minimal `204 No Content` handling via the existing no-content write normalizer plus a truthful `disconnected` flag
- extended `.testbed/tests/test_modio_vendor_adapter.gd` with request-shape coverage, invalid-request coverage (`service_token` missing + invalid `portal_id`), and `204` normalization coverage
- updated `README.md` and `docs/modio-seam-plan.md` so the S2S seam now explicitly includes the disconnect route as a bodyless service-token-only delete

Validation evidence:
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`63/63` passing, `2161` asserts, one pre-existing float/int warning remained elsewhere in the suite)

Corpus drift handled:
- none for this endpoint contract itself; the refreshed REST page was clean and was followed directly
- explicit implementation choice was to avoid adding a `Content-Type` header because the route is documented as bodyless `DELETE` with only the general S2S bearer-auth requirement

Changed files:
- `src/modio_vendor_adapter.gd`
- `.testbed/tests/test_modio_vendor_adapter.gd`
- `README.md`
- `docs/modio-seam-plan.md`
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md`

Remaining frontier notes useful for the next near-wrap pass:
- this slice deliberately did **not** broaden into collection-member removal, mod-media writes, legacy event feeds, or the drifted `/me/iap/*/sync` family
- the next audit should still classify those separately rather than folding them into this exact S2S-auth unlink wrapper

---

### Task 3: QA the approved next REST slice

**Bead ID:** `oc-c0y`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest slice against the refreshed official REST corpus. Confirm request shapes, transport behavior, docs, and seam boundaries are truthful; make only minimum necessary fixes; rerun validation/tests; update the plan with exact findings; commit/push if needed; and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md`

**Status:** ✅ Complete

**Results:** Independently QA-verified the `DELETE /s2s/connections/{portal-id}` slice against the refreshed official REST page in `REF-04` and the shipped repo code/tests/docs in `REF-05`/`REF-06`.

Exact QA findings:
- request contract matches the refreshed REST page: method `DELETE`, path `/s2s/connections/{portal-id}`, one required integer path parameter, and no documented request body
- implementation stays a thin raw S2S wrapper: `build_s2s_disconnect_request(portal_id: String)` only trims/validates the documented path id, reuses `_build_service_read_headers()`, and does not introduce repo-local aliasing or extra unlink semantics
- auth boundary is truthful: the route uses the explicit service-token bearer seam (`Authorization: Bearer <service_token>`) rather than user bearer auth
- transport behavior is correctly bodyless: the request body is `{}`, `content_type` is empty, and no `Content-Type` header is attached for this route; the transport layer only injects `Content-Type` when `content_type` is non-empty, so this slice does not silently become a form request
- `portal_id` validation is appropriately strict for the documented path contract: positive integer path id only, with invalid input surfacing `portal_id must be a positive integer path id`
- 204 handling is thin and correct: `normalize_s2s_disconnect_response(...)` delegates to the existing no-content normalizer, preserves `data = {}`, and adds only a truthful `disconnected` flag keyed to `status_code == 204`
- no extra S2S semantics leaked in: no delegation-token requirement, no form body, no content-type behavior, and no user-bearer fallback assumptions were added

Fixes made:
- none; no contract drift was found in implementation, tests, or docs for this slice

Validation evidence:
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`63/63` passing, `2161` asserts, `1` pre-existing warning)

Files changed during QA:
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md` only

Commit/push:
- none needed; QA found no code/doc/test drift to fix

---

### Task 4: Audit the approved next REST slice

**Bead ID:** `oc-ekd`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest slice against the refreshed official REST corpus and the repo seam plan. Confirm the added coverage is accurate, thin, and clearly bounded. Make only minimum necessary fixes, rerun validation/tests, update the plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md`

**Status:** ✅ Complete

**Results:** Independently audited the `DELETE /s2s/connections/{portal-id}` slice against the refreshed official REST page in `REF-04`, the repo seam docs in `REF-05`, and the shipped implementation/tests in `REF-06`.

Exact audit findings:
- request contract is truthful to the refreshed REST page: method `DELETE`, path `/s2s/connections/{portal-id}`, one required integer path parameter, and no documented request body
- implementation stays a thin raw S2S wrapper: `build_s2s_disconnect_request(portal_id: String)` trims and validates only the documented path id, reuses `_build_service_read_headers()`, and does not add repo-local aliasing, unlink helpers, or extra semantics
- auth boundary remains correctly service-token scoped: the route uses the explicit S2S bearer seam (`Authorization: Bearer <service_token>`) and does not assume ordinary user bearer auth
- transport behavior remains bodyless and thin: the request body is `{}`, `content_type` is empty, the request omits `Content-Type`, and `ModioHttpTransport` only injects that header when `content_type` is non-empty
- `portal_id` validation remains truthful for the documented path contract: trimmed positive integer path id only, with invalid input surfacing `portal_id must be a positive integer path id`
- `204 No Content` normalization is correct and thin: `normalize_s2s_disconnect_response(...)` delegates to `_normalize_no_content_write_response(...)`, preserves `data = {}`, and adds only `disconnected := (response.ok and status_code == 204)`
- no extra S2S or user-bearer assumptions leaked in: no delegation token requirement, no form/content-type behavior, no body payload, and no fallback to ordinary access-token semantics

Fixes made:
- none; audit found no code, test, or docs drift for this slice

Changed files during audit:
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md` only

Validation evidence:
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`63/63` passing, `2161` asserts, `1` pre-existing warning)

Commit/push:
- none needed; no implementation fixes were required

Verdict:
- **Go** — this slice is truthful to the refreshed REST corpus and stays within Derrick’s locked thin-wrapper boundary.

---

### Task 5: Near-wrap corpus sweep after the slice lands

**Bead ID:** `oc-3xw`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-06`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start after the slice above is complete. Re-run a near-wrap corpus-vs-repo audit to catch any remaining confirmed REST-backed surfaces, distinguish them from intentional deferrals and drift-blocked families, and update the plan with an exact remaining frontier. Close the bead with a useful reason.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` only if a concise note materially helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-04-aerobeat-vendor-modio-next-rest-slice-and-near-wrap-audit.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Re-ran the near-wrap corpus-vs-repo sweep against `REF-04` first, then re-checked the current shipped seam in `REF-05`, the prior audit trail in `REF-01` / `REF-02` / `REF-03`, and test/docs evidence in `REF-06`.

Exact post-slice frontier:
- The earlier final-audit frontier had **18 confirmed REST-page-backed unwrapped routes** plus the separately drift-blocked `/me/iap/*/sync` family and SDK-only cook upsert drift.
- Since then, the repo has landed:
  - the **six-endpoint mod-maintenance write family** (`tags`, `metadatakvp`, `dependencies` add/delete)
  - the **S2S disconnect route** `DELETE /s2s/connections/{portal-id}`
- That reduces the remaining confirmed REST-page-backed frontier to **11 routes**.
- No new accidentally missed confirmed REST family appeared in this sweep.

### Covered endpoint families
Confirmed covered at the family level after this pass:
- auth/session + agreement utility
- catalog / game-meta / taxonomy utility
- core mod read + community surface
- modfile / upload / multipart / cook / platform pipeline
- guide read/write/comment family
- user inventory / account-state / social profile family
- monetization-user / checkout / documented transaction S2S family
- monetization-team read/create family
- collection reads, comments, compatibility, authoring create/update/delete, follow/unfollow, and subscribe/unsubscribe
- mod-maintenance reads **and now writes** for tags, metadata KVP, and dependencies
- S2S account-link disconnect is now covered and no longer part of the frontier

### Intentionally deferred but confirmed REST-backed families
These routes are still real official REST endpoint pages, but remain unwrapped **by choice**, not by accident:
- **Game/mod authoring + admin writes**
  - `POST /games/{game-id}/media`
  - `POST /games/{game-id}/mods`
  - `POST /games/{game-id}/mods/{mod-id}`
  - `DELETE /games/{game-id}/mods/{mod-id}`
- **Mod media management**
  - `POST /games/{game-id}/mods/{mod-id}/media`
  - `PUT /games/{game-id}/mods/{mod-id}/media/reorder`
  - `DELETE /games/{game-id}/mods/{mod-id}/media`
- **Collection membership admin route**
  - `DELETE /games/{game-id}/collections/{collection-id}/mods`
  - precise classification: this is still an unwrapped confirmed REST page, but it is **intentionally deferred**, not an accidental capability hole, because the repo already covers broader membership replacement/removal semantics through collection update with documented `sync=true`
- **Legacy event feeds**
  - `GET /me/events`
  - `GET /games/{game-id}/mods/events`
  - `GET /games/{game-id}/mods/{mod-id}/events`
  - precise classification: intentionally deferred because the official corpus itself treats `/me/events` as deprecated for in-game use and points integrations toward subscription/state flows instead

### Drift-blocked families
Still excluded because the refreshed corpus does not provide a clean enough docs-first REST contract:
- **`/me/iap/*/sync` family**
  - candidate platform members remain `apple`, `epicgames`, `google`, `meta`, `psn`, `steam`, `xboxlive`
  - these remain blocked by official-corpus drift across docs/SDK/Unity rather than by repo neglect
- **SDK-only cook upsert drift**
  - `POST /games/{game-id}/mods/{mod-id}/cooks`
  - still SDK-evidenced without a matching local official REST endpoint page

### Truly missing confirmed REST-backed surfaces
- **None found.**
- This sweep did **not** uncover any accidentally unwrapped confirmed REST-backed route outside the already-known deferred families above.
- The remaining 11 REST-page-backed routes are now a deliberate frontier, not a hidden gap.

Docs note:
- No extra docs note was added. The active plan and current seam doc already capture the useful boundary, and a separate note would not materially improve handoff.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Landed the smallest confirmed REST-backed follow-up slice (`DELETE /s2s/connections/{portal-id}`) and then reran a corpus-truth near-wrap sweep. The repo now covers the previously deferred mod-maintenance write family plus the S2S disconnect route, and the exact remaining confirmed REST-page-backed frontier is narrowed to **11 intentionally deferred routes** rather than any hidden accidental miss.

**Reference Check:** `REF-04` remained the route-existence source of truth, with `REF-01` / `REF-02` / `REF-03` used to classify prior intent and `REF-05` / `REF-06` used to confirm the shipped seam/tests. The updated audit confirms: (1) the new S2S disconnect slice is correctly removed from the frontier, (2) the earlier mod-maintenance write gap is now closed, (3) the only remaining confirmed REST-page-backed routes are the known deferred game/mod authoring, mod-media, collection-member-delete, and legacy-event pages, and (4) `/me/iap/*/sync` plus cook upsert remain drift-blocked rather than silently implementable.

**Commits:**
- `e6a9125` - Add deferred mod maintenance write surfaces
- `2ad6676` - Fix mod.io form array key encoding
- prior slice commit(s) for S2S disconnect already landed before this audit pass
- this near-wrap audit updated the plan only; no additional code/doc commit was required

**Lessons Learned:** Once the surface gets close to wrapped, the important distinction is no longer “wrapped or not” in the abstract. The high-value truth check is whether an unwrapped route is (a) genuinely forgotten, (b) intentionally deferred because it belongs to a different seam batch, or (c) blocked by corpus drift. After this pass, the remainder is clearly (b) or (c); nothing still looks accidentally unwrapped.

---

*Completed on 2026-05-04*
