# mod.io Unity SDK vs `aerobeat-vendor-modio` gap audit — 2026-05-05

## Purpose

This document explains the remaining gap between the local official mod.io Unity SDK and the Godot-facing `aerobeat-vendor-modio` wrapper **after the final REST audit**.

The source of truth for normal wrapper scope is the local official REST corpus in `modio-docs`, not Unity parity. Unity is used here as a comparison reference to answer a narrower question:

> What functionality does the Unity SDK expose that this repo still does not, and which of those gaps are real REST gaps vs. intentional non-goals vs. upstream drift that needs mod.io clarification?

## Final wrapper status

- `aerobeat-vendor-modio` now wraps **133 of 134** documented endpoint pages in `modio-docs/public/en-us/restapi/docs/*.api.mdx`.
- The only documented REST route still intentionally unwrapped is **`GET /me/events`**.
- That route is a **documented deferral**, not an accidental miss:
  - the official page marks it **deprecated for in-game use**
  - the official page says **new games should use `GET /me/subscribed` instead**
  - Derrick explicitly locked it out of the finish line
- Result: the remaining Unity-vs-wrapper gap is now mostly about:
  1. **Unity-only client/runtime features**
  2. **drift-blocked monetization/IAP surfaces**
  3. **non-REST orchestration layers** that Unity ships on top of the API

## Short version

If the question is **“does the Godot wrapper still miss stable documented REST endpoints that Unity has?”** the truthful answer is:

- **Only one:** deprecated `GET /me/events`, intentionally deferred.

If the question is **“does Unity still do more than this wrapper?”** the truthful answer is also yes, but most of that extra surface is **not** “missing REST coverage.” It is one of:

- Unity-side runtime/state management
- Unity-specific auth and store integrations
- install/download lifecycle orchestration
- monetization abstractions that depend on platform services or drifted endpoints
- UI / event / service-locator conveniences

## Comparison categories

### 1. REST-covered functionality now wrapped

These are no longer meaningful Unity parity gaps at the transport seam.

`aerobeat-vendor-modio` now covers the documented REST families Unity depends on for ordinary API access, including:

- auth/session requests
- agreements / terms reads
- game, mod, modfile, guide, and collection browse/detail reads
- mod authoring CRUD
- modfile CRUD
- source modfiles
- multipart upload sessions and part upload
- cook inspection, platform-management, and cloud-cooking finalization
- mod media and game media writes
- comments / ratings / reports
- dependencies / dependants / tags / metadata KVP
- user inventory/profile/social reads
- subscriptions / purchases / wallet / entitlements query
- checkout and monetization S2S routes
- mod monetization-team routes
- mod event feeds (`/mods/{mod-id}/events`, `/mods/events`)

From a Godot integration angle, this means the vendor wrapper now has essentially full docs-first REST reach for the public corpus. A future Godot higher layer can build product behavior on top of this without needing Unity just to access the documented API.

### 2. Intentional documented deferral

#### `GET /me/events`

Status:
- documented in REST
- generated in Unity (`Modio/API/Generated/Endpoints/GetUserEvents.cs`)
- **intentionally not wrapped here**

Why it stays out:
- the REST page explicitly says it is **deprecated for in-game use**
- the page says **new games should use `GET /me/subscribed`**
- wrapping it would add legacy behavior that the docs themselves steer new game clients away from

Godot implication:
- this is not a real blocker
- if AeroBeat needs “current subscribed state,” `GET /me/subscribed` is the correct path
- if AeroBeat somehow needs historical legacy user-event semantics, that should be a deliberate exception rather than default wrapper scope

### 3. Unity-only or non-wrapper surfaces

These are real Unity-vs-wrapper differences, but they are **not** evidence that the Godot wrapper is missing stable REST coverage.

#### 3.1 Client bootstrap and service binding

Unity ships a full client runtime layer around the API:
- `ModioClient.Init()` / `Shutdown()`
- service binding via `ModioServices`
- platform-selected auth service resolution
- persistent user/data storage integration

Representative files:
- `modio-unity/Modio/ModioClient.cs`
- `modio-unity/Modio/Authentication/ModioMultiplatformAuthResolver.cs`

`aerobeat-vendor-modio` does **not** try to replicate this. It is a thin request-builder/transport/normalizer seam, not a singleton runtime.

Godot implication:
- Godot should own its own service graph, token persistence, and startup lifecycle
- copying Unity’s service-locator architecture into the vendor wrapper would be scope drift

#### 3.2 Local synced user state and repositories

Unity has a richer local user model than this wrapper:
- `User.Sync()` orchestration
- cached profile / subscriptions / purchases / collections / ratings / wallet state
- `ModRepository` and `ModCollectionRepository`
- local change listeners / events

Representative files:
- `modio-unity/Modio/Users/User.cs`
- `modio-unity/Modio/Users/ModRepository.cs`
- `modio-unity/Modio/Users/ModCollectionRepository.cs`

The wrapper intentionally stops lower in the stack. It returns normalized REST payloads but does not maintain a live client-side shadow model.

Godot implication:
- if AeroBeat wants Unity-style “current user state” objects, that belongs in a Godot integration layer above this repo
- this is a product/runtime layer, not a transport gap

#### 3.3 Install/download/session orchestration

Unity includes substantial mod-installation behavior:
- installation manager startup/shutdown
- retry install flows
- temp mod sessions
- disk-space checks
- install wake-up behavior after subscription/purchase sync

Representative file:
- `modio-unity/Modio/ModInstallationManagement.cs`

`aerobeat-vendor-modio` deliberately does not implement this. The repo only resolves download metadata and artifact/cache identity; it does not claim to be a full install manager.

Godot implication:
- Godot still needs its own install/download orchestration layer
- that layer can use this wrapper’s file/download metadata, but it should not live inside the vendor REST seam

#### 3.4 UI and engine integration helpers

Unity ships engine-specific UX helpers:
- auth picker / terms panels / WSS prompt panels
- example scenes and UI components
- avatar/UI glue
- Unity purchasing bridge code

Representative paths:
- `modio-unity/Unity/UI/`
- `modio-unity/Unity/Examples/`

These are plainly Unity-only and not meaningful parity targets for a Godot vendor wrapper.

Godot implication:
- AeroBeat should treat these as design references only
- any Godot UI should be purpose-built instead of trying to mirror Unity SDK structure

### 4. Drift-blocked or ambiguous surfaces

These are the most important remaining comparison items, because they are the ones most likely to require direct mod.io clarification before a Godot integration should rely on them.

#### 4.1 `/me/iap/*/sync`

This is the largest remaining gap between Unity’s practical capability and the docs-first Godot wrapper.

What we know locally:
- Unity contains generated endpoints and active integration paths for multiple entitlement-sync routes
- the monetization guide `features/monetization/purchase-servers/modio-as-purchase-server.md` documents several of these flows conceptually and, in some cases, operationally
- the official mirrored REST endpoint corpus under `public/en-us/restapi/docs/*.api.mdx` does **not** contain matching endpoint pages for this family

Examples:
- `POST /me/iap/steam/sync`
- `POST /me/iap/xboxlive/sync`
- `POST /me/iap/psn/sync`
- `POST /me/iap/meta/sync`
- `POST /me/iap/epicgames/sync`
- `POST /me/iap/apple/sync`
- `POST /me/iap/google/sync`

Why this is blocked:
- body/header shapes drift across guide vs. SDK vs. Unity
- some portals are guide-backed, some only SDK/Unity-backed
- some platforms appear partially supported in code but not consistently in the public corpus

Concrete drift already recorded in local research:
- **PSN:** guide uses `psn_token` / `psn_env` / `psn_service_label`; SDK + Unity use `auth_code` / `env` / `service_label`
- **Meta:** guide uses `meta_device` + `meta_user_id`; SDK uses `device` + `user_id`; Unity currently sends them as query params on a `POST`
- **Apple/Google:** present in Unity and/or SDK, but missing from the mirrored REST pages

Godot implication:
- do **not** claim parity here yet
- do **not** implement these in a docs-first wrapper without an explicit policy change
- if AeroBeat needs store-native entitlement conversion, this is the clearest place where direct mod.io clarification is warranted

#### 4.2 USD marketplace and entitlement service abstractions

Unity has service abstractions that imply a broader monetization runtime than the REST wrapper currently provides:
- `IModioEntitlementService`
- `IModioUsdMarketplaceService`
- `ModioMobileStoreService`

Representative files:
- `modio-unity/Modio/Monetization/IModioEntitlementService.cs`
- `modio-unity/Modio/Monetization/IModioUsdMarketplaceService.cs`
- `modio-unity/Unity/Platforms/MobilePurchasing/ModioMobileStoreService.cs`

Important distinction:
- the wrapper **does** cover the stable REST pieces around wallet, purchases, entitlements query, checkout, token packs, and monetization S2S
- the wrapper **does not** cover the Unity runtime layer that talks to store SDKs, opens platform-native purchase flows, consumes receipts, syncs entitlements, and refreshes wallet state afterward

Godot implication:
- if AeroBeat wants platform-store commerce inside Godot, it needs both:
  1. Godot-side platform/store bindings
  2. mod.io confirmation about which sync endpoints/contracts are intended for non-Unity clients

#### 4.3 WSS / device-code-style authentication

Unity includes a WSS auth path that is more than a simple REST form post:
- `Modio/Platforms/WSS/WssAuthService.cs`
- `IWssCodeDisplayer` UX coupling

This looks like a device-login / live-code experience rather than plain REST-only email or OpenID exchange.

The current wrapper already covers the documented REST auth routes, but it does not implement a WSS runtime.

Godot implication:
- if AeroBeat only needs email auth, OpenID, or the documented external auth request shapes, the wrapper is already sufficient
- if AeroBeat wants the same device-login UX Unity exposes, confirm with mod.io whether WSS auth is an intended cross-engine integration path or just a Unity/plugin-level convenience

### 5. Features most likely to need direct mod.io clarification for Godot

If Derrick wants a short list of “ask mod.io these first,” this is it.

#### Clarification priority 1: official status of `/me/iap/*/sync`

Questions to ask:
- Which `/me/iap/*/sync` routes are officially supported for production game clients today?
- Which exact request field names are canonical for each platform?
- Which headers are mandatory per platform?
- Are Apple/Google sync endpoints intentionally supported for third-party engine clients even though they are absent from the mirrored REST endpoint pages?
- Is there a current docs location that supersedes the missing `.api.mdx` pages?

#### Clarification priority 2: intended non-Unity monetization integration model

Questions to ask:
- For Godot or custom-engine titles, is the intended path:
  - direct mod.io checkout / wallet, or
  - platform-native purchase + entitlement sync, or
  - both depending on storefront?
- Which portals are considered first-class for in-game marketplace support outside Unity/Unreal?
- Are there platform-specific restrictions mod.io expects game teams to enforce client-side?

#### Clarification priority 3: WSS/device auth support outside Unity

Questions to ask:
- Is the WSS auth flow an officially supported cross-engine integration surface?
- Is there a public/properly documented non-Unity contract for it?
- Should custom engines prefer documented REST auth routes unless mod.io explicitly directs otherwise?

#### Clarification priority 4: scope boundary for install-management expectations

Questions to ask:
- Does mod.io expect custom engine clients to build install/session management entirely themselves on top of REST + downloads?
- Are there any non-Unity reference expectations for temp sessions, retries, enable/disable semantics, or local repository state?

## Godot-facing conclusion

### What is actually missing from the wrapper?

Very little of the documented REST API.

The wrapper is now effectively REST-complete for the current mirrored corpus, with one intentional legacy exception:
- `GET /me/events` deferred because the docs say not to use it for new games

### What is still missing compared with Unity?

Mostly things that should **not** be solved by blindly copying Unity into the vendor wrapper:
- client runtime/state management
- install orchestration
- UI helpers
- Unity/store SDK integrations
- drifted monetization sync routes

### What should happen next for AeroBeat?

From a Godot integration angle, the next honest layer split is:

1. Keep `aerobeat-vendor-modio` as the docs-first REST seam.
2. Build any Godot-specific session/cache/install/runtime behavior **above** it.
3. Treat `/me/iap/*/sync`, store-native monetization, and WSS/device auth as **clarification-first** topics with mod.io rather than assumed parity work.

## Bottom line

After the final REST audit, the remaining Unity SDK gap is **not** “we still owe a bunch of missing documented endpoints.”

It is:
- **one intentional deprecated REST deferral**: `GET /me/events`
- **several Unity/runtime conveniences** that belong above the vendor wrapper
- **a small but important set of monetization/auth surfaces** where the local official corpus is incomplete or internally drifted, and where direct mod.io guidance would materially reduce risk for a Godot implementation
