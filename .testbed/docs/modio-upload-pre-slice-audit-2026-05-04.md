# mod.io upload pre-slice audit — 2026-05-04

Source of truth reviewed:

- `/home/derrick/.openclaw/workspace/projects/modio/modio-docs`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-sdk`
- `/home/derrick/.openclaw/workspace/projects/modio/modio-unity`

## Natural next endpoint groups after modfile CRUD

### 1) Source-modfile handling

- `GET /games/{game-id}/mods/{mod-id}/sources`
  - browse source modfiles
  - no body
  - documented response: paginated `Modfile Object[]`
- `POST /games/{game-id}/mods/{mod-id}/sources`
  - add source modfile
  - documented content type: `multipart/form-data`
  - documented body fields:
    - `filedata` binary, required iff `upload_id` omitted
    - `upload_id` string, required iff `filedata` omitted
    - `version` string
    - `changelog` string
    - `active` boolean
    - `filehash` string (MD5)
    - `metadata_blob` string
    - `platforms[]` array of platform strings
  - documented response: `201 Created` + `Modfile Object`

### 2) Multipart upload/session orchestration

- `POST /games/{game-id}/mods/{mod-id}/files/multipart`
  - create upload session
  - documented content type: `application/x-www-form-urlencoded`
  - body:
    - `filename` string, required, must include `.zip`, max 100 chars
    - `nonce` string, optional, max 64 chars, idempotency key
  - documented response: `200 OK` + `Multipart Upload Object`
- `GET /games/{game-id}/mods/{mod-id}/files/multipart/sessions`
  - list upload sessions for authenticated user + mod
  - query:
    - optional `status` enum: `0 incomplete`, `1 pending`, `2 processing`, `3 complete`, `4 cancelled`
  - response: paginated `Multipart Upload Object[]`
- `GET /games/{game-id}/mods/{mod-id}/files/multipart`
  - list uploaded parts for a session
  - query:
    - required `upload_id`
  - response: paginated `Multipart Upload Part Object[]`
- `PUT /games/{game-id}/mods/{mod-id}/files/multipart`
  - upload one part
  - query:
    - required `upload_id`
  - headers:
    - required `Content-Range: bytes start-finish/total`
    - optional `Digest`
  - body:
    - raw binary bytes for the part
  - response: `200 OK` + `Multipart Upload Part Object`
- `POST /games/{game-id}/mods/{mod-id}/files/multipart/complete`
  - complete session
  - query:
    - required `upload_id`
  - response: `200 OK` + `Multipart Upload Object`
- `DELETE /games/{game-id}/mods/{mod-id}/files/multipart`
  - cancel session
  - query:
    - required `upload_id`
  - response: `204 No Content`

## Upstream drift / corpus notes

1. `modio-docs` is the best source of truth for field names and endpoint existence.
2. `modio-unity` includes generated endpoints for add-source and multipart flows, but not a generated browse-source endpoint in the checked-in tree.
3. `modio-sdk` includes request constants and multipart/source upload ops, but its source-upload helper drifts from docs:
   - source helper appends `metadata` instead of documented `metadata_blob`
   - helper surface omits documented `active` and `filehash`
4. multipart create drift:
   - docs mark `nonce` optional
   - unity generated request constructor requires `nonce`
   - sdk always sends a hash-derived nonce
5. multipart part drift:
   - docs page schema labels the request body under `application/x-www-form-urlencoded`
   - docs prose says the body should contain no form params and should be the raw bytes described by `Content-Range`
   - unity endpoint uses byte-array body semantics
   - sdk request constants still label the request as `application/x-www-form-urlencoded`
6. digest drift:
   - docs prose / unity comments say supported algorithm is `SHA-256`
   - docs error table mentions `SHA-256, CRC32C`

## Real pre-slice decisions

### Decision 1: endpoint wrapper only, or upload workflow helper too?

Recommendation: keep this repo at raw endpoint coverage plus strong request-shape validation. Do not add archive compression, file-path helpers, auto chunking, auto retry, auto resume, or auto final attach behavior in this slice.

### Decision 2: source-modfile write parity

Recommendation: expose full documented `POST /sources` contract, not the reduced SDK helper subset. That means supporting `active`, `filehash`, and the documented `filedata` xor `upload_id` rule.

### Decision 3: strict documented names vs SDK drift aliases

Recommendation: stay strict to docs. Accept documented `metadata_blob`; do not alias undocumented `metadata`. Treat `nonce` as optional, not required.

### Decision 4: multipart part request representation

Recommendation: model `PUT /files/multipart` as raw binary body + explicit `upload_id` query + explicit `Content-Range` / optional `Digest` headers. Do not disguise it as normal form fields.

## Non-blockers that coder/qa/audit can handle without escalation

- request/response normalization for the six multipart endpoints and two source endpoints
- documented session-status enum validation
- `204 No Content` normalization for delete-session
- optional `Digest` passthrough as an opaque string while documenting the upstream algorithm drift
- pagination/filter serialization for session/parts list endpoints
- preserving the existing thin-seam rule that higher-level upload orchestration belongs elsewhere
