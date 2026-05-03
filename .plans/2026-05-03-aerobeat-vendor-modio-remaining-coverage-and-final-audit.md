# AeroBeat Vendor Mod.io Remaining Coverage and Final Audit

**Date:** 2026-05-03  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Drive `aerobeat-vendor-modio` through the remaining coherent mod.io REST coverage slices, then finish with a strict gap audit against the refreshed local official corpus so we can prove what is covered, what is intentionally out of scope, and whether anything was missed.

---

## Overview

The repo already has a truth-locked foundation across auth/session, mod browse/detail/files/stats, subscriptions, ratings/reporting, dependencies, mod comments, guides, guide comments, collections, and the read-only user/social slice. Derrick has now explicitly authorized continuing through the remaining slices without pausing between coder → QA → audit unless we hit unresolved ambiguity or a boundary decision that needs human override.

This plan is the umbrella for the rest of the push. Each remaining family still needs to be handled as a coherent batch, with local official docs first, then coder → QA → auditor, and each batch must stay inside the vendor-adapter boundary. When the implementation slices are finished, we will run a final corpus-vs-repo gap audit to verify endpoint-family coverage, identify any intentionally deferred policy/install/authoring surfaces, and make sure we did not accidentally miss a clean vendor-local read/write family.

The key constraint is not just “wrap more endpoints.” It is “wrap more endpoints truthfully.” That means preserving exact path/method/query/body contracts, response-shape fidelity, and explicit out-of-scope decisions where mod.io functionality would drag the repo into downloader/install orchestration, moderation workflow policy, or broader AeroBeat product behavior.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Doc-truth audit baseline | `.plans/2026-05-03-aerobeat-vendor-modio-doc-truth-and-repo-audit.md` |
| `REF-02` | Collection slice plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-collection-surface-coverage.md` |
| `REF-03` | User/social slice plan/results | `.plans/2026-05-03-aerobeat-vendor-modio-user-and-social-surface-coverage.md` |
| `REF-04` | Earlier guide/comment slice | `.plans/2026-05-02-aerobeat-vendor-modio-adjacent-comment-surfaces.md` |
| `REF-05` | Current research note | `docs/modio-rest-api-research-2026-05-02.md` |
| `REF-06` | Current seam plan | `docs/modio-seam-plan.md` |
| `REF-07` | Corpus completeness note | `docs/modio-rest-corpus-completeness-2026-05-03.md` |
| `REF-08` | Local official docs mirror | `/home/derrick/.openclaw/workspace/projects/modio/modio-docs` |
| `REF-09` | Local official SDK reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk` |
| `REF-10` | Local official Unity integration reference | `/home/derrick/.openclaw/workspace/projects/modio/modio-unity` |
| `REF-11` | Current implementation | `src/` |
| `REF-12` | Current fixture/test corpus | `.testbed/tests/` |

---

## Tasks

### Task 1: Research remaining uncovered families and execution order

**Bead ID:** `oc-09k`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Compare the current wrapped repo surface against the refreshed official local mod.io corpus and produce an execution-ready map of the remaining uncovered endpoint families. Group them into coherent slices, recommend the next execution order, and explicitly mark any surfaces that should remain out of scope because they would pull install/orchestration, moderation policy, monetization policy, or authoring/CMS behavior into this repo. Update the plan with exact findings and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a concise gap map note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`
- optional note(s)

**Status:** ✅ Complete

**Results:** Compared the current wrapped surface in `REF-11` plus `README.md`/`docs/modio-seam-plan.md` against the refreshed official local corpus in `REF-08` through `REF-10` and produced an execution-ready remaining-family map.

Remaining **clean in-scope** uncovered families:
- **Catalog / game-meta / taxonomy utility slice**
  - `GET /games`
  - `GET /games/{game-id}/stats`
  - `GET /games/{game-id}/tags`
  - `GET /games/{game-id}/tokenpacks`
  - `GET /games/{game-id}/mods/stats`
  - `GET /games/{game-id}/guides/tags`
  - `GET /agreements/types/{agreement-type-id}/versions/{version}` (doc filename `get-agreement-version.api.mdx`)
  - `GET /ping`
  - Why grouped: all are read-only catalog/capability/taxonomy utilities that extend the current browse/auth seam without introducing authoring, install, or product-policy behavior.
- **Mod-adjacent read enrichment slice**
  - `GET /games/{game-id}/mods/{mod-id}/dependants`
  - `GET /games/{game-id}/mods/{mod-id}/tags`
  - `GET /games/{game-id}/mods/{mod-id}/metadata` (`get-mod-kvp-metadata.api.mdx`)
  - `GET /games/{game-id}/mods/{mod-id}/team`
  - `GET /games/{game-id}/mods/{mod-id}/collections`
  - `GET /games/{game-id}/mods/{mod-id}/collections/{collection-id}`
  - Why grouped: these are provider-native read enrichments around already wrapped mod detail/dependency/community surfaces and should reuse the existing mod/collection/user normalizers cleanly.
- **User inventory/profile read slice**
  - `GET /users/{user-id}/games`
  - `GET /users/{user-id}/mods`
  - `GET /users/{user-id}/modfiles`
  - Why grouped: these are read-only profile inventory endpoints adjacent to the newly completed user/social slice and should reuse current paging + user/mod/modfile normalization primitives.
- **External auth provider parity slice**
  - `POST /external/appleauth`
  - `POST /external/discordauth`
  - `POST /external/epicgamesauth`
  - `POST /external/gogauth`
  - `POST /external/googleauth`
  - `POST /external/oculusauth`
  - `POST /external/psnauth`
  - `POST /external/steamauth`
  - `POST /external/switchauth`
  - `POST /external/udtauth`
  - `POST /external/xboxliveauth`
  - Why grouped: these are the remaining provider-auth variants parallel to the already wrapped OpenID flow and can likely share one request/normalization strategy with provider-specific required fields documented per page.

Recommended execution order:
1. **Catalog / game-meta / taxonomy utility slice** — smallest clean read-only win; extends discovery/capability truth with little seam risk.
2. **Mod-adjacent read enrichment slice** — highest-value remaining mod read coverage and closest to the already wrapped mod/community primitives.
3. **User inventory/profile read slice** — straightforward reuse of existing list normalization after the social/account-state read work.
4. **External auth provider parity slice** — still in scope, but lower immediate product value than the read families and likely easiest once the remaining read pressure is gone.
5. **Final corpus-vs-repo audit** after those slices land.

Remaining uncovered families that should stay **intentionally out of scope for this repo right now**:
- **Install / subscription orchestration pressure**
  - `POST/DELETE /games/{game-id}/collections/{collection-id}/subscribe`
  - source/install-adjacent collection orchestration already shows up in the official SDK/Unity flows (`SubscribeToModCollectionOp`, `ProcessNextModInUserCollection`, `ProcessNextModInServerCollection`); do not pull that install/subscription-policy behavior into this vendor seam.
- **Authoring / CMS / upload / cloud-cooking / moderation-admin surfaces**
  - create/edit/delete mod, guide, collection (`add-*.api.mdx`, `edit-*.api.mdx`, `delete-*.api.mdx`, `update-collection.api.mdx`)
  - mod media/tags/metadata/dependency writes and deletes (`add/delete/reorder-mod-media`, `add/delete-mod-tags`, `add/delete-mod-kvp-metadata`, `add/delete-mod-dependencies`)
  - modfile/source-file/upload/cook/platform-status surfaces (`add/edit/delete-modfile`, `add-source-modfile`, `browse-source-modfiles`, `browse-modfile-cooks`, multipart upload session/parts lifecycle, `finalize-cloud-cooking`, `manage-platform-status`)
  - collection membership management (`delete-collection-mods`)
  - game media writes (`add-game-media`)
  - Why out: these move the repo from vendor read/community seam into content authoring, asset pipeline, upload orchestration, release management, or moderation/admin behavior.
- **Monetization / entitlement / purchase policy surfaces**
  - `POST /games/{game-id}/mods/{mod-id}/checkout`
  - `GET /me/wallet`
  - `GET /me/purchases`
  - `GET /me/entitlements`
  - `GET /games/{game-id}/mods/{mod-id}/team/members`, `POST /games/{game-id}/mods/{mod-id}/team`, and monetization transaction/S2S routes (`get-monetization-transaction*`, `create-mod-monetization-team`, `get-users-in-mod-monetization-team`, `s-2-s-*`)
  - Why out: these require AeroBeat-side monetization, entitlements, refund/clawback, and store-policy decisions that should not be smuggled into this adapter.
- **Write-side social / moderation-policy edges**
  - `POST/DELETE /users/{user-id}/mute`
  - `POST/DELETE /users/{user-id}/follow`
  - `POST/DELETE /games/{game-id}/collections/{collection-id}/follow`
  - Why out: these are account-state mutation and moderation/social-policy behaviors rather than the current read/community seam.
- **Legacy event feeds**
  - `GET /me/events`
  - `GET /games/{game-id}/mods/events`
  - `GET /games/{game-id}/mods/{mod-id}/events`
  - Why out: they are legacy event-driven sync surfaces and do not fit the repo’s current subscription/read-state direction.

Net finding: after the already completed auth/session, mod browse/detail/files/stats, subscriptions, ratings/reporting, dependencies, mod comments, guides, guide comments, collections, and read-only user/social/account-state coverage, the remaining **clean vendor-local implementation opportunity** is now mostly read enrichment + auth parity. Most of the rest of the corpus is intentionally where install orchestration, authoring/CMS, moderation/social mutation, or monetization policy begins.

---

### Task 2: Execute remaining coherent slices

**Bead ID:** `oc-4zg`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Execute the next coherent remaining mod.io vendor slice as defined by the latest research/gap map. Use the refreshed local official corpus as source of truth, keep the seam vendor-local, and update the umbrella plan with which slice was completed, what changed, validation evidence, and any newly identified sub-slices. Commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

**Status:** ✅ Complete

**Results:** Completed the first execution family from the gap map: the **catalog / game-meta / taxonomy utility batch**. Added vendor-local request builders, transport coverage, fixtures, and normalization for `GET /games`, `GET /games/{game-id}/stats`, `GET /games/{game-id}/tags`, `GET /games/{game-id}/mods/stats`, `GET /games/{game-id}/guides/tags`, `GET /agreements/versions/{agreement-version-id}`, and `GET /ping`, plus the doc-corrected read-only token-pack surface at `GET /games/{game-id}/monetization/token-packs`. The refreshed local corpus corrected two paths from the earlier gap wording (`/games/{game-id}/tokenpacks` -> `/games/{game-id}/monetization/token-packs`, `/agreements/types/{agreement-type-id}/versions/{version}` -> `/agreements/versions/{agreement-version-id}`), and the implementation followed the local official docs/SDK/Unity refs instead of the stale gap-map phrasing.

Validation evidence:
- `godot --headless --path .testbed --script res://tests/validate_scaffold.gd` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`35/35` tests passed, `1100` asserts)

Scope notes:
- Kept vendor-local boundaries intact: no writes, admin/media management, authoring/CMS, install orchestration, or legacy event work were added.
- Kept monetization handling narrowly read-only: token-pack discovery only, no purchase/intents/wallet flows.

---

### Task 3: QA each remaining slice automatically

**Bead ID:** `oc-2js`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the latest remaining-slice implementation against the refreshed local official mod.io corpus. Confirm request shapes, normalization, fixtures, tests, and seam docs match the docs and that vendor-local boundaries hold. Make only minimum necessary fixes, rerun validation/tests, update the umbrella plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit each remaining slice automatically

**Bead ID:** `oc-16a`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform an independent truth-check of the latest remaining-slice implementation against the refreshed local official mod.io corpus. Confirm the added coverage is accurate, still isolated as a vendor adapter seam, and advances the repo toward full truthful coverage. Make only minimum necessary fixes, rerun validation/tests, update the umbrella plan, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `src/`
- `.testbed/tests/`
- `docs/`
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/tests/docs as needed
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 5: Final corpus-vs-repo gap audit

**Bead ID:** `oc-sj7`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01` through `REF-12`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. After the remaining coherent slices are done, perform a final explicit gap audit comparing the current repo surface against the refreshed official local mod.io corpus. Produce a clear list of: covered endpoint families, intentionally deferred/out-of-scope families, and any truly missed clean vendor-local surfaces. Update the plan and any concise repo-local audit note with exact results, commit/push if needed, and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- `docs/` if a final gap note is helpful

**Files Created/Deleted/Modified:**
- `.plans/2026-05-03-aerobeat-vendor-modio-remaining-coverage-and-final-audit.md`
- optional final audit note(s)

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

*Completed on 2026-05-03*
