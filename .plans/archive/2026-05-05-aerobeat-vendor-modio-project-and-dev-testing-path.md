# AeroBeat Vendor Mod.io Project and Dev Testing Path

**Date:** 2026-05-05  
**Status:** Stale  
**Agent:** Chip 🐱‍💻

---

## Goal

Figure out the intended mod.io development/testing path for AeroBeat: how to set up the real mod.io project, obtain the required API keys/credentials, and understand how mod.io expects developers to create and manage test mods during integration work without guessing at the wrong project structure.

---

## Overview

Before moving up into `aerobeat-tool-api`, Derrick wants the real mod.io project/testing posture clarified. The key question is not just “how do we get keys,” but “what does mod.io expect a game team to do for development and testing?” In particular, we want to know whether a single real AeroBeat project is normally reused for development with hidden/private/unpublished test mods, whether mod.io provides a sandbox/test mode, or whether separate projects/games are expected for certain flows.

This is a research-only slice. We are not creating the project yet and we are not wiring secrets yet. We want a docs-backed answer about the intended developer workflow so the later live integration harness can be designed cleanly and safely.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | AeroBeat mod.io comparison doc | `/workspace/projects/aerobeat/aerobeat-vendor-modio/docs/modio-unity-vs-vendor-wrapper-gap-2026-05-05.md` |
| `REF-02` | Final deferred-rest completion plan | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-deferred-rest-finish.md` |
| `REF-03` | mod.io docs mirror | `/workspace/projects/modio/modio-docs/` |
| `REF-04` | sync-surface research plan | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-sync-surface-verification.md` |

---

## Tasks

### Task 1: Research mod.io’s intended project/keys/test-mod workflow for development

**Bead ID:** `oc-5cv`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-04`  
**Prompt:** In `/workspace/projects/aerobeat/aerobeat-vendor-modio`, claim the assigned bead on start. Research how mod.io intends developers to set up and test a game integration: creating the real project/game, obtaining public/private/API credentials, using test/sandbox environments if available, and managing development/test mods. Determine whether mod.io expects a single real game/project with hidden/private/unpublished test mods, a separate project, or some other workflow. Use local docs first, then external research if needed. Update this plan with exact findings, confidence level, useful links, and a practical recommendation for AeroBeat. Close the bead when done.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/docs/` only if a short note helps

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-project-and-dev-testing-path.md`

**Status:** ✅ Complete

**Results:**
- mod.io’s docs describe two official development/testing paths, not just one:
  1. a **hidden real game profile** using the **Preview System** for team members/collaborators, and
  2. the separate **test environment / sandbox** at `test.mod.io` with separate `api_key`, `game_id`, and API base URL.
- Creating the real project/game: mod.io says to create a **game account** from the mod.io homepage (`Get started` / `add your game`). The game is hidden automatically at first. Teams then manage it from the game admin settings / library dashboard. The docs explicitly say to locate the API key in the game admin **API** section or the **API Access** page.
- Credentials/setup mod.io documents for integrations:
  - per game/profile: **`game_id`**, **`api_key`**, and **`api_url` / API path**
  - for SDK init: **environment** (`Live` or `Test`) and **portal**; C++ SDK docs show `Options.GameEnvironment = Modio::Environment::Live` and say the SDK supports the test sandbox via the environment parameter
  - for write operations as a user: **OAuth 2 access tokens** via email/platform/OpenID/manual token flows
- Sandbox/test mode: yes. The REST API intro says mod.io has a **test sandbox** with separate accounts/data and separate endpoints like `https://g-{your-game-id}.test.mod.io/v1`; when going live you switch API path plus the production `api_key` and `game_id`.
- Day-to-day workflow implied by the docs:
  - if the title is not launched yet, keep the main game profile **hidden** and test there using Preview System/team access
  - if the title is already released and a private environment is needed, mod.io explicitly says you can create a **second hidden game profile**
  - if you want isolated throwaway data while integration is in progress, use the **test sandbox**
  - therefore mod.io appears to support **all three** patterns depending on phase, but the intended production path still centers on **one real production game profile** plus optional hidden/test companions
- Safe test-mod handling guidance from docs/API behavior:
  - keep the game hidden until launch
  - use Preview access for testers/collaborators
  - for hidden games/mods, use **codenames and non-descriptive screenshots** because permitted users may still see connected content on profiles
  - use mod visibility/status controls to keep test mods private: the REST docs say `visible=0` hides mods from browsing, and `status=0` / not accepted also keeps them out of normal browsing
  - use private/admin-only tags for internal filtering/featuring where useful
- Practical AeroBeat recommendation:
  - Create **one real AeroBeat production game profile** on production mod.io now, but keep it **hidden** until launch.
  - Also create a **test.mod.io sandbox game profile** for low-risk integration and throwaway data during harness development.
  - If AeroBeat is already publicly released before UGC launch, create a **second hidden production profile** for private production-like rehearsals rather than polluting the public-facing profile.
  - Plan to store/configure **two environment tuples** in the harness: `(api_url, game_id, api_key)` for **test** and `(api_url, game_id, api_key)` for **live**; user write flows also need OAuth tokens in whichever environment is active.
  - For development test mods, default to **hidden/not-accepted** mods, internal naming, non-descriptive art, and preview-limited tester access.
- Confidence: **High** for sandbox existence, hidden-game workflow, second-hidden-profile option, and required per-game credentials because those are directly stated in the local docs. **Medium** on exact AeroBeat operational preference between hidden prod profile vs second hidden prod profile, because that is a recommendation synthesized from those docs rather than a single sentence from mod.io.
- Useful doc links / references:
  - `/workspace/projects/modio/modio-docs/public/en-us/modio/getting-started.md`
  - `/workspace/projects/modio/modio-docs/public/en-us/modio/launch-checklist.md` (same content theme as `road-to-launch.md`)
  - `/workspace/projects/modio/modio-docs/public/en-us/modio/road-to-launch.md`
  - `/workspace/projects/modio/modio-docs/public/en-us/game-integration/restapi/getting-started/restapi-introduction.md`
  - `/workspace/projects/modio/modio-docs/public/en-us/game-integration/restapi/getting-started/restapi-status-and-visibility.md`
  - `/workspace/projects/modio/modio-docs/public/en-us/game-integration/cppsdk/getting-started/cpp-initialization.mdx`
  - `/workspace/projects/modio/modio-docs/public/en-us/game-integration/cppsdk/index.mdx`

---

## Final Results

**Status:** ✅ Complete

**What We Built:**
- A docs-backed recommendation for how AeroBeat should set up mod.io development and testing.
- Confirmation that mod.io supports both a **separate sandbox/test environment** and **hidden production game profiles** with preview access.
- A practical credential/setup plan for the future live integration harness.

**Reference Check:**
- `REF-03` satisfied directly from local mod.io docs mirror.
- `REF-01`, `REF-02`, and `REF-04` were context only; no conflicts found.

**Commits:**
- None (research/plan update only in this sub-task context).

**Lessons Learned:**
- mod.io’s intended workflow is more flexible than a single yes/no answer: sandbox exists for isolated testing, but the real production path still revolves around a real game profile that starts hidden and can be previewed before launch.
- For harness design, the key abstraction is environment switching between **test** and **live** using separate `api_url`, `game_id`, and `api_key` sets.

---

*Completed on 2026-05-05*