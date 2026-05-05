# AeroBeat Vendor Mod.io Live Env and Harness

**Date:** 2026-05-05  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Set up a private local mod.io environment/config workflow for `aerobeat-vendor-modio`, support clean test-vs-live switching, and build the first safe live integration harness so AeroBeat can validate the REST adapter against real mod.io projects without leaking secrets or polluting production data.

---

## Overview

Derrick now has the real AeroBeat mod.io production tuple (`api_url`, `game_id`, `api_key`) and wants to move into the live-integration setup workload. We already locked the intended provider workflow: use `test.mod.io` as the default development/testing environment, keep the real AeroBeat project hidden until launch, and avoid casual production-data pollution while the wrapper is still being proven.

This means the next slice should not jump straight into arbitrary live calls. First we need a private local config shape for credentials, then deterministic environment switching between test and live, then a narrow harness that exercises only safe flows. The first validation pass should focus on non-destructive checks such as auth/session setup and browse/read flows, with only carefully chosen write tests later if the environment and boundaries are fully understood.

This plan should also carry the taxonomy lock-ins that matter to provider-facing uploader/test logic: public launch tags are `feature`, `difficulty`, and `genre`; `trust_state` is admin-hidden/admin-only; and workout packages should remain single-feature, which will need validator enforcement in a follow-up slice.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Final REST completion plan | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-deferred-rest-finish.md` |
| `REF-02` | Project/testing path research | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-project-and-dev-testing-path.md` |
| `REF-03` | Sync surface research | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-sync-surface-verification.md` |
| `REF-04` | Current README and dev flow | `/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |
| `REF-05` | Current config model | `/workspace/projects/aerobeat/aerobeat-vendor-modio/src/models/modio_client_config.gd` |
| `REF-06` | Current docs on mod.io tag mapping | `/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/modio-tag-mapping.md` |
| `REF-07` | Current repo ignore policy | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.gitignore` |
| `REF-08` | Current hidden workbench manifest | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/addons.jsonc` |

---

## Recommended Design: Private Local Env / Config Shape

### Summary

Keep the repo’s credential wiring **testbed-local, file-backed, and explicit**. Do **not** invent a broad environment system for this thin adapter repo. The adapter already has the right runtime model in `ModioClientConfig`; what is missing is only a small local loader/input convention for the hidden `.testbed/` harness.

Recommended shape:

1. one ignored **stable secrets/config** file for per-environment project credentials,
2. one optional ignored **session override** file for short-lived user tokens / user-targeted host testing,
3. one committed **example/template** for each file,
4. one explicit environment selector with **`test` as the default**,
5. no implicit live selection and no inference from URL/key values.

### Recommended committed vs uncommitted files

**Commit these template/example files:**

- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.local.example.cfg`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.session.local.example.cfg`
- README usage notes describing how to copy/fill them

**Keep these real files uncommitted / ignored:**

- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.local.cfg`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.session.local.cfg`

**Why `.testbed/` instead of repo root?**

Because `REF-04` and `REF-08` establish that real development and validation already happen through the hidden workbench project. Keeping the private config there keeps the published package boundary clean and avoids pretending the shipping adapter package itself owns a general deployment-secret system.

### Recommended stable local config file

`/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.local.cfg`

Use Godot `ConfigFile` format so the future harness can load it natively without adding an external `.env` parser.

Recommended shape:

```ini
[modio]
default_environment="test"
accept_language="en-US"
host_kind="api"

[modio.test]
game_id=""
api_key=""
base_url=""
service_token=""
portal=""
platform=""
monetization_team_id=""

[modio.live]
game_id=""
api_key=""
base_url=""
service_token=""
portal=""
platform=""
monetization_team_id=""
```

#### Field intent

- `default_environment`
  - `test` or `live`
  - should ship as `test` in the committed example
- `accept_language`
  - shared default; maps directly onto `ModioClientConfig.accept_language`
- `host_kind`
  - shared default; normally `api`
  - only override for explicit `game` / `user` host testing
- `modio.test.*`
  - the `test.mod.io` sandbox tuple
- `modio.live.*`
  - the hidden real AeroBeat production tuple
- `base_url`
  - optional explicit override only
  - prefer blank so `ModioClientConfig.resolve_base_url()` and `use_test_environment` remain the primary truth
- `service_token`
  - only if S2S/monetization-admin flows are actually being tested later
  - safe to leave blank in early harness work
- `portal`, `platform`, `monetization_team_id`
  - optional per-environment defaults, because these may differ between sandbox and live once platform/monetization testing starts

### Recommended session override file

`/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/modio.session.local.cfg`

Use this only for short-lived user/session state so the stable project tuple file does not become a junk drawer for ephemeral auth.

Recommended shape:

```ini
[modio]
environment=""
host_kind=""

[modio.test]
access_token=""
user_id=""

[modio.live]
access_token=""
user_id=""
```

#### Why split stable vs session data?

- `game_id`, `api_key`, and optional `service_token` are environment/project credentials.
- `access_token` and `user_id` are usually user/session scoped and more likely to churn.
- The split reduces accidental reuse of stale bearer tokens and keeps the thin repo from normalizing long-lived local storage of user auth as the primary pattern.

### Recommended environment selection rules

Use **explicit selection only**. Never infer test vs live from `api_key`, `game_id`, or `base_url` contents.

Recommended precedence for the future harness/loader:

1. explicit harness argument / override: `--env test|live`
2. optional shell override: `MODIO_ENV=test|live`
3. `[modio] environment` from `modio.session.local.cfg` if set
4. `[modio] default_environment` from `modio.local.cfg`
5. hard fallback: `test`

Additional safety rule:

- `live` should require an **explicit choice** somewhere above the fallback layer.
- In practice: the example config should still default to `test`, and the harness should print which environment tuple it selected before doing network calls.

### Recommended shell/env variables

Keep shell env support **minimal** so the adapter repo does not sprout a second full config system.

Recommended one-off overrides only:

- `MODIO_ENV=test|live`
- optional later: `MODIO_HOST_KIND=api|game|user`

Do **not** require a full parallel env-var matrix like `MODIO_TEST_GAME_ID`, `MODIO_LIVE_GAME_ID`, etc. for the first pass. The file-backed config is the primary source of truth for local work; env vars are only small runtime overrides.

### How `ModioClientConfig` should consume the selected values

`REF-05` is already almost exactly the right shape. Recommendation: **do not broaden the model yet**. Just feed the selected environment block into the existing constructor.

Recommended mapping:

- `p_game_id` ← selected env `game_id`
- `p_api_key` ← selected env `api_key`
- `p_base_url` ← selected env `base_url` (or leave blank / default when empty)
- `p_access_token` ← selected session env `access_token`
- `p_accept_language` ← shared `accept_language`
- `p_portal` ← selected env `portal`
- `p_platform` ← selected env `platform`
- `p_host_kind` ← session override `host_kind` if set, else shared `host_kind`
- `p_user_id` ← selected session env `user_id`
- `p_use_test_environment` ← `true` when selected environment is `test`, else `false`
- `p_service_token` ← selected env `service_token`
- `p_monetization_team_id` ← selected env `monetization_team_id`

### Design stance on `base_url`

Prefer this rule:

- normal local usage: leave `base_url` blank and rely on `use_test_environment` + `host_kind`
- explicit `base_url` only for odd endpoint/host verification or docs-truth debugging

That keeps the current model’s host-resolution logic meaningful and reduces opportunities for mismatched values like “live env selected but test URL pasted in by accident.”

### What should stay out of scope for this thin adapter repo

Do **not** add these in the first implementation slice:

- a repo-wide secret manager
- CI live secrets plumbing
- automatic OAuth login flows
- automatic token refresh/persistence
- multi-profile environment proliferation (`staging`, `preview`, `qa`, etc.)
- product-layer policy about which AeroBeat user can run which mod.io mutations

This repo only needs enough config shape to let the hidden `.testbed/` harness build a truthful `ModioClientConfig` for `test` and `live`.

### Recommendation for test vs live usage

- **Default development target:** `test`
- **Live target meaning:** the hidden AeroBeat production project only
- **First live harness scope:** read-only or otherwise non-destructive checks first
- **Write-capable flows:** only after the harness can print/confirm active environment clearly and the live project remains hidden/admin-controlled

### Open questions for the next implementation slice

1. Should the first harness support `MODIO_ENV` only, or both `MODIO_ENV` and `--env`?
   - Recommendation: support both if cheap; otherwise `--env` is the clearer primary UX.
2. Should live-only destructive flows require a second explicit flag beyond `--env live`?
   - Recommendation: probably yes for later write tests, but not required for the initial read-only harness slice.
3. Does AeroBeat want to persist bearer `access_token` values in `modio.session.local.cfg`, or should the first harness require them to be pasted/entered per run?
   - Recommendation: allow the file but keep it optional; do not require persistence.
4. If AeroBeat later creates a second hidden production-like project after public launch, should that become a third environment name?
   - Recommendation: not yet. Keep only `test` and `live` for now; add another named environment only when a real second live-like profile exists.

---

## Tasks

### Task 1: Design the private local env/config shape and switching rules

**Bead ID:** `oc-p0y`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Design the private local config/env shape for mod.io credentials and environment switching. Specify what files/variables should exist, how test vs live should be selected, what should stay uncommitted, and how the current config model should consume those values. Update the plan with exact recommendations and close the bead.

**Folders Created/Deleted/Modified:**
- `.plans/`
- docs paths only if a short note helps

**Files Created/Deleted/Modified:**
- `.plans/2026-05-05-aerobeat-vendor-modio-live-env-and-harness.md`

**Status:** ✅ Complete

**Results:** Reviewed the current repo shape, README/testbed flow, `.gitignore`, and `ModioClientConfig`. Recommended a narrow hidden-workbench config design centered on two ignored Godot `ConfigFile` inputs under `.testbed/`: one stable per-environment secrets file (`modio.local.cfg`) and one optional short-lived session override file (`modio.session.local.cfg`), each paired with a committed `.example.cfg` template. Recommended that `test` and `live` be the only environment names for now, with `test` as the default and `live` requiring explicit selection rather than inference. Recommended keeping shell env support minimal (`MODIO_ENV`, optionally later `MODIO_HOST_KIND`) and feeding the chosen values directly into the existing `ModioClientConfig` constructor rather than widening the model. Rationale: this preserves the thin adapter boundary, keeps secrets out of git, keeps package-root publishing clean, and matches the repo’s existing `.testbed/`-centric development flow from `REF-04` and `REF-08`.

---

### Task 2: Implement the private env/config scaffolding and test/live switching

**Bead ID:** `oc-ebm`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Implement the approved private env/config scaffolding and test/live switching support. Keep secrets uncommitted, update docs/examples as needed, and preserve the thin adapter boundary. Update the plan with exact files/results, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.testbed/tests/`
- `.plans/`
- repo root docs

**Files Created/Deleted/Modified:**
- `.testbed/modio.local.example.cfg`
- `.testbed/modio.session.local.example.cfg`
- `.testbed/modio_env_loader.gd`
- `.testbed/tests/test_modio_env_loader.gd`
- `.gitignore`
- `README.md`
- `.plans/2026-05-05-aerobeat-vendor-modio-live-env-and-harness.md`

**Status:** ✅ Complete

**Results:** Added a testbed-local mod.io config loader that resolves `test` vs `live` with explicit precedence and maps directly into `ModioClientConfig`. Committed example config templates for stable and session data, ignored real local cfg files, documented the flow in the README, and added focused GUT coverage for selection/override behavior.

---

### Task 3: Build the first safe live integration harness

**Bead ID:** `oc-d0e`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Build the first safe live integration harness around the approved env/config flow. Limit the first-pass checks to non-destructive or explicitly approved-safe operations, with test environment as the default target. Update docs and the plan with exact usage/coverage, commit and push by default, then close the bead.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- docs/ or repo root docs/examples
- `.plans/`

**Files Created/Deleted/Modified:**
- harness/test files as needed
- `.plans/2026-05-05-aerobeat-vendor-modio-live-env-and-harness.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: QA and audit the live harness setup

**Bead ID:** `oc-u5h`  
**SubAgent:** `primary`  
**Role:** `qa` / `auditor`  
**References:** `REF-01` through `REF-08`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Independently verify the env/config scaffolding and live harness setup, confirm secrets stay out of git, confirm test-vs-live switching is explicit and safe, and truth-check that the first live test scope is non-destructive by default. Update the plan with exact findings, make only minimum necessary fixes, commit/push if needed, then close the bead.

**Folders Created/Deleted/Modified:**
- repo paths as needed
- `.plans/`

**Files Created/Deleted/Modified:**
- implementation/docs as needed
- `.plans/2026-05-05-aerobeat-vendor-modio-live-env-and-harness.md`

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Completed the design slice and the scaffolding implementation for a private `.testbed`-local two-file config system with committed templates, explicit `test` / `live` switching, `test` as the default target, and direct consumption by the existing `ModioClientConfig` model without widening the adapter boundary. Added a testbed-only loader plus focused GUT coverage for the selection/override behavior.

**Reference Check:** `REF-02`, `REF-04`, `REF-05`, `REF-07`, and `REF-08` directly informed the design. The recommendation is consistent with the earlier sandbox-vs-hidden-live research in `REF-02`, keeps the workbench-local development posture from `REF-04` / `REF-08`, and reuses the current config model from `REF-05` with no unnecessary new abstraction.

**Commits:**
- (see Task 2 implementation commit)

**Lessons Learned:** The current adapter already has the important runtime shape; the real missing piece is just a safe local input convention. The cleanest answer is not a full secret framework or a giant env-var matrix, but a tiny `.testbed`-local config pair that keeps stable environment credentials separate from short-lived session auth.

---

*Completed on 2026-05-05*
