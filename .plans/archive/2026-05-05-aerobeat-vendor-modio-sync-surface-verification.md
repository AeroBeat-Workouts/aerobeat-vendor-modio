# AeroBeat Vendor Mod.io Sync Surface Verification

**Date:** 2026-05-05  
**Status:** Stale  
**Agent:** Chip 🐱‍💻

---

## Goal

Verify whether the Unity SDK's purchase-to-mod sync functionality is exposing real mod.io REST-like surfaces that custom engines such as Godot can likely call directly, or whether it appears to depend on Unity-specific/private/non-public integration paths that should be treated as unavailable to AeroBeat.

---

## Overview

Derrick's current hypothesis is sensible: AeroBeat may not need a first-party mod.io Godot sync convenience layer if a higher-level AeroBeat API layer can bridge store purchases to the correct mod.io unlock calls. But before we lock that in, we want one focused research pass to answer a narrower question: when Unity exposes these sync functions, are they backed by REST-looking routes that seem intended for broader clients, or do they appear gated, Unity-specific, or otherwise unsupported outside that SDK path?

This is a research-only slice. We are not implementing sync support. We are trying to sharpen the engineering posture for `aerobeat-tool-api`: either “ignore the Unity sync convenience and build our own higher layer over the documented wrapper” or “there is evidence that custom engines may be meant to call these routes directly if they have the right storefront receipts/tokens.”

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | AeroBeat comparison doc | `/workspace/projects/aerobeat/aerobeat-vendor-modio/docs/modio-unity-vs-vendor-wrapper-gap-2026-05-05.md` |
| `REF-02` | Existing sync drift plan | `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-04-aerobeat-vendor-modio-iap-sync-drift-resolution.md` |
| `REF-03` | mod.io docs mirror | `/workspace/projects/modio/modio-docs/` |
| `REF-04` | mod.io Unity SDK reference | `/workspace/projects/modio/modio-unity/` |
| `REF-05` | mod.io SDK reference | `/workspace/projects/modio/modio-sdk/` |

---

## Tasks

### Task 1: Research whether Unity sync surfaces appear public, gated, or Unity-specific

**Bead ID:** `oc-rkk`  
**SubAgent:** `primary`  
**Role:** `research`  
**References:** `REF-01` through `REF-05`  
**Prompt:** In `aerobeat-vendor-modio`, claim the assigned bead on start. Perform a focused research pass on the Unity SDK purchase/entitlement sync surfaces. Determine whether they look like general mod.io REST-style routes that custom engines like Godot could plausibly call directly if they have storefront receipts/tokens, or whether they appear Unity-specific, gated, private, or otherwise unsupported outside the Unity SDK path. Use local docs/corpus first, then external research if needed. Update this plan with exact findings, confidence level, and a practical recommendation for AeroBeat's `aerobeat-tool-api` higher-layer design. Close the bead when done.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/`
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/docs/` only if a small note is useful

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-sync-surface-verification.md`

**Status:** ✅ Complete

**Results:** Research completed against `REF-01` through `REF-05`, plus targeted official docs cross-checks on docs.mod.io for monetization guidance.

**Exact findings**
- The Unity SDK sync calls are **not merely Unity-private magic**. In `modio-unity`, the generated endpoint code calls normal-looking authenticated HTTP routes under `/me/iap/*/sync`, for example:
  - `POST /me/iap/google/sync`
  - `POST /me/iap/apple/sync`
  - `POST /me/iap/steam/sync`
  - `POST /me/iap/meta/sync`
  - `POST /me/iap/psn/sync`
  - `POST /me/iap/xboxlive/sync`
  - `POST /me/iap/epicgames/sync`
- These endpoint methods require ordinary mod.io auth (`request.Options.RequireAuthentication()`) plus platform-specific receipt/token payloads such as `receipt`, `xbox_token`, `auth_code`, `epicgames_token`, `epicgames_sandbox_id`, or Meta `device` + `user_id`.
- The Unity mobile purchase path is thin glue, not a hidden backend channel. `ModioMobileStoreService` parses Unity IAP purchase data and directly calls `ModioAPI.InAppPurchases.SyncGoogleEntitlements(...)` or `SyncAppleEntitlement(...)`, then syncs the wallet. That strongly suggests the real integration boundary is the mod.io HTTP route plus valid store proof, not a Unity-only private service.
- The Unity docs also describe the sync flow in platform-agnostic/product terms, not as “Unity-only entitlement support.” The Unity Marketplace guide says `User.Current.SyncEntitlements()` uses the current platform's `IModioEntitlementService`, and the mobile guide explicitly says to pass the purchase receipt through to mod.io consumption.
- The C++ SDK docs independently describe the same concept for custom/native integrations: `RefreshUserEntitlementsAsync` / `GetAvailableUserEntitlementsAsync` consume or inspect platform entitlements, and platform-specific docs are required to populate the needed entitlement parameters. This is strong evidence that mod.io expects non-Unity clients to perform equivalent sync behavior.
- External official monetization docs materially strengthened the picture versus the older local-only drift read:
  - `docs.mod.io/monetization/modio-as-purchase-server` publicly documents the overall entitlement-sync flow as a game-client action.
  - That guide explicitly says the **game client** authenticates with mod.io via the platform that tracks the entitlements, then instructs mod.io to sync those platform entitlements.
  - It publicly documents at least `POST /me/iap/xboxlive/sync` and starts enumerating the platform-specific sync section from a REST shape perspective.
- However, this is **not cleanly equal across all platforms**:
  - Some surfaces are publicly documented in general monetization docs and platform guides.
  - Some are only clearly evidenced in SDK/Unity code paths.
  - Console paths still appear partly partner/approval/NDA gated in practice.
  - Prior local drift findings still stand for shape inconsistency on some routes, especially PSN and Meta.

**Classification**
1. **Public-but-underdocumented REST-like routes:** Yes, this is the best fit for the family as a whole. The routes look like first-class mod.io authenticated HTTP endpoints, not Unity internals.
2. **SDK convenience over public routes:** Yes, especially for Unity mobile and the broader `SyncEntitlements()` abstractions. Unity is mostly wrapping platform purchase UX + receipt extraction + calls into these backend routes.
3. **Unity-specific/private/gated behavior:** Partly, but mostly around platform enablement and docs access rather than the core route concept itself. Console-specific flows and some marketplace setup docs are gated; the route family itself does not look Unity-exclusive.

**Practical recommendation for AeroBeat / `aerobeat-tool-api`**
- Treat these sync calls as a **real mod.io integration surface** that a custom engine like Godot can plausibly target **if** AeroBeat can supply:
  - a valid mod.io user access token,
  - the correct platform-native receipt/token/proof,
  - any platform header/query/body requirements for the selected store,
  - platform-specific compliance behavior outside mod.io (purchase UI, receipt acquisition, user identity, etc.).
- Do **not** model the higher layer as “call Unity behavior.” Model it as:
  1. platform-native purchase/auth adapter in Godot or another client layer,
  2. `aerobeat-tool-api` sync endpoint(s) that forward verified platform proof to the corresponding mod.io `/me/iap/*/sync` route,
  3. post-sync wallet/purchase refresh against ordinary mod.io reads.
- Keep the implementation **platform-whitelisted**, not generic-string dynamic, at least initially.
- First candidates for real support should remain the lower-drift, better-evidenced routes (`steam`, `xboxlive`, likely `google`/`apple` when mobile receipt handling is available).
- Keep `psn` and `meta` behind explicit caution flags until the request-shape/documentation drift is resolved more confidently.
- For consoles and any partner-gated platforms, assume business/platform approval risk even if the route exists.

**Confidence level:** Medium-high.
- High confidence that the sync family is **not Unity-private** and is conceptually intended for broader mod.io clients.
- Medium confidence on exact per-platform production readiness outside Unity/Unreal, because source quality and request-shape clarity still vary by portal.

**Bottom line**
- Recommended AeroBeat posture: **build a higher-layer mod.io sync bridge over selected `/me/iap/*/sync` routes, not a Unity clone; but gate rollout per platform and avoid assuming every Unity-supported portal is equally clean for Godot on day one.**

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Completed a focused verification pass on the Unity purchase/entitlement sync surface and tightened AeroBeat's recommended integration posture. The conclusion is that the Unity sync methods are largely wrappers over real mod.io authenticated `/me/iap/*/sync` HTTP routes rather than Unity-only private behavior, but platform support clarity still varies and some portals remain guide-/partner-/SDK-backed rather than uniformly REST-page-backed.

**Reference Check:**
- `REF-01` / `REF-02`: aligned with the earlier drift finding that the family was real but unevenly documented; refined the conclusion toward “public-ish route family with platform-specific caveats,” not “Unity-only.”
- `REF-03` / `REF-04`: confirmed concrete endpoint names, request bodies, auth requirements, and Unity mobile receipt handoff behavior.
- `REF-05`: confirmed that the native/C++ SDK describes the same entitlement-sync concept for non-Unity integrations, reinforcing that custom engines are expected to supply platform-specific entitlement params and call the same underlying capability.

**Commits:**
- None. Research/plan update only.

**Lessons Learned:** The important line is not “Unity vs Godot”; it is “can AeroBeat produce the right store proof and route it safely?” The mod.io side looks bridgeable for custom engines, but exact production posture should stay platform-by-platform rather than assuming every Unity marketplace path is equally mature for a Godot stack.

---

*Completed on 2026-05-05*