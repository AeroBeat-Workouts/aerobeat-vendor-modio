# mod.io cook / cloud-cook / platform-management pre-slice audit — 2026-05-04

Source of truth reviewed:

- `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`

## Exact next documented endpoints after the completed source/multipart slice

### 1) Cook inspection slice

- `GET /games/{game-id}/mods/{mod-id}/cooks`
  - docs page: `modio-docs/public/en-us/restapi/docs/browse-modfile-cooks.api.mdx`
  - no request body
  - no documented query/body fields on the page
  - response: paginated `Modfile Cook Object[]`
  - schema path: `modio-docs/public/en-us/restapi/docs/schemas/modfile-cook-object.schema.mdx`
  - key response fields:
    - `cook_uuid`
    - `modfile` (source modfile id)
    - `platform`
    - `status`
    - `date_added`
    - `date_updated`
    - `metadata[]`
    - `logs[]`
    - `filename`
    - `filesize`
    - `version`

### 2) Cloud-cooking instance management slice

- `POST /games/{game-id}/cloud-cooking/finalization`
  - docs page: `modio-docs/public/en-us/restapi/docs/finalize-cloud-cooking.api.mdx`
  - no request body
  - response: `204 No Content`
  - docs wording: “Finalize a Cloud Cooking instance on Azure.”

### 3) Modfile platform-management slice

- `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms`
  - docs page: `modio-docs/public/en-us/restapi/docs/manage-platform-status.api.mdx`
  - content type: `application/x-www-form-urlencoded`
  - documented body fields:
    - `approved[]` array of platform strings
    - `denied[]` array of platform strings
  - documented behavior note:
    - does **not** set a file live
    - to set a reviewed file live, call the already-documented and already-implemented `PUT /games/{game-id}/mods/{mod-id}/files/{file-id}` with `active=true`
    - docs explicitly say a live modfile cannot be marked denied; to remove it, set another existing modfile live for that platform or add a new modfile
  - response: `200 OK` + `Modfile Object`

## Important upstream drift / corpus notes

1. The current official docs mirror only documents one cook endpoint in this family: `GET /games/{game-id}/mods/{mod-id}/cooks`.
2. The C++ SDK request constants include an additional undocumented endpoint:
   - `POST /games/{game-id}/mods/{mod-id}/cooks` (`UpsertModfileCooksRequest`)
   - local path: `modio-sdk/modio/modio/core/ModioDefaultRequestParameters.h`
   - no matching page was found in the refreshed local docs mirror.
3. Unity generated endpoints currently present in-tree for this family:
   - `AddSourceModfile.cs`
   - `ManagePlatformStatus.cs`
   - multipart endpoints
   - **not found in-tree**: generated `BrowseModfileCooks` endpoint, generated `FinalizeCloudCooking` endpoint.
4. `ManagePlatformStatus.cs` in Unity is a bodyless generated stub even though the docs page clearly defines `approved[]` and `denied[]` request fields.
5. `Edit Modfile` docs explicitly connect platform approval to live-state changes:
   - if the parent game supports cross-platform modfiles and the modfile is approved, `active=true` sets the modfile live on all approved platforms.
6. The platform reference page distinguishes request-header platform targeting (`X-Modio-Platform` lowercase header values like `ps5`, `xboxseriesx`) from schema/request-body platform enums used in mod/modfile platform objects (`PLAYSTATION5`, `XBOXSERIESX`, etc.). That means endpoint-body validation should stay tied to the documented mod/modfile platform string set, not header-value shortcuts.

## True pre-slice human decisions

### Decision 1: docs-first strictness vs SDK-only cook creation/upsert parity

**Question:** Should this repo wrap only the officially documented cook endpoints, or should it also expose the SDK-only `POST /games/{game-id}/mods/{mod-id}/cooks` surface even though it is not in the refreshed docs mirror?

**Why it matters technically:** Choosing SDK parity here would force the seam to invent/derive request shape, response normalization, and tests from non-doc sources. That breaks the current docs-first truth rule and increases future drift risk.

**Options:**
1. Wrap only the officially documented cook endpoint(s) found in `modio-docs`.
2. Add both the documented `GET /cooks` and the SDK-only undocumented `POST /cooks` for parity with the C++ SDK.
3. Defer all cook coverage until mod.io’s docs confirm the write/upsert story.

**Recommended:** Option 1. Keep the seam docs-first and ship only `GET /games/{game-id}/mods/{mod-id}/cooks` unless Derrick explicitly wants SDK-parity-over-docs risk.

### Decision 2: raw endpoint wrappers only vs release-workflow convenience helper

**Question:** For platform management, should this repo expose only the raw `POST /files/{file-id}/platforms` and existing `PUT /files/{file-id}` (`active=true`) calls, or should it also grow a convenience helper that “approve + set live” as one higher-level operation?

**Why it matters technically:** A convenience helper crosses from vendor transport into release orchestration. It would need policy about ordering, retries, partial failure, and which platforms are safe to publish, which is not transport-seam work.

**Options:**
1. Raw endpoint wrappers only; callers compose approval and go-live themselves.
2. Add a thin helper that sequences approve/deny and optional `active=true` promotion.
3. Defer platform-management entirely until a higher-level AeroBeat release orchestration layer exists.

**Recommended:** Option 1. Keep the vendor adapter thin; caller code can decide whether/when to call the already-existing edit-modfile live toggle.

### Decision 3: include cloud-cooking finalization now or defer it as an ops/admin surface

**Question:** Should the next implementation slice include `POST /games/{game-id}/cloud-cooking/finalization`, or should that endpoint be deferred until Derrick confirms AeroBeat actually needs direct cloud-cooking instance lifecycle control?

**Why it matters technically:** The endpoint is easy to wrap, but it operates at game/cloud-instance scope rather than per-mod/per-file scope. That makes it feel closer to deployment/admin workflow than ordinary content mutation.

**Options:**
1. Include it in the next slice because it is documented, bodyless, and still a thin provider call.
2. Defer it to a later admin/ops slice unless AeroBeat has an immediate need.
3. Keep a placeholder plan entry but do not implement until mod.io cloud-cooking usage is confirmed.

**Recommended:** Option 2 unless Derrick already knows AeroBeat will actively drive cloud-cooking finalization. It is thin, but also the least obviously needed endpoint in this family.

## Things coder → QA → audit can handle without asking Derrick

- request/response wrapping for documented `GET /mods/{mod-id}/cooks`
- request/response wrapping for documented `POST /files/{file-id}/platforms`
- `approved[]` / `denied[]` body validation and empty-response/error normalization rules
- reuse of the existing modfile/update response normalizer for platform-status writes
- `204 No Content` normalization for cloud-cooking finalization if that endpoint is included
- fixture creation for `Modfile Cook Object[]` and platform-status-updated `Modfile Object` payloads
- preserving the existing thin-seam rule that no automatic publish/release orchestration belongs here
- documenting the body/header platform-string distinction without inventing aliasing behavior

## Endpoints that can proceed immediately once the decisions are answered

If Derrick accepts the recommendations above, the next implementation-ready endpoints are:

1. `GET /games/{game-id}/mods/{mod-id}/cooks`
2. `POST /games/{game-id}/mods/{mod-id}/files/{file-id}/platforms`
3. optional, only if explicitly approved for this slice: `POST /games/{game-id}/cloud-cooking/finalization`
