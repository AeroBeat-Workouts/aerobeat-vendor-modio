# AeroBeat planning note: mod.io Unity SDK vs `aerobeat-vendor-modio`

## Why this exists

This is the practical version of the Unity-vs-wrapper comparison for AeroBeat planning.

The short answer:

- `aerobeat-vendor-modio` is now basically **REST-complete** for the public mod.io docs we are treating as source of truth.
- That does **not** mean AeroBeat v1 is approved to expose every wrapped capability.
- The main thing AeroBeat still **does not** have is **Unity-style engine/runtime behavior above the REST API**.
- That means the next work is mostly **Godot product integration work**, not "wrap more ordinary REST endpoints."

For source material, also see:
- `/workspace/projects/aerobeat/aerobeat-vendor-modio/.plans/2026-05-05-aerobeat-vendor-modio-deferred-rest-finish.md`
- `/workspace/projects/modio/modio-docs/`
- `/workspace/projects/modio/modio-unity/`

## Current wrapper status

`aerobeat-vendor-modio` wraps **133 of 134** documented mod.io REST endpoint pages from the local docs mirror.

The only documented route still intentionally not wrapped is:
- `GET /me/events`

That is not an accidental miss. The docs mark it deprecated for in-game use and tell new games to use `GET /me/subscribed` instead.

## What AeroBeat should actually care about

AeroBeat should care about this split:

For the current policy-locked v1, a lot of the wrapped surface should be read as **provider capability** rather than **approved product behavior**. In particular, things like direct checkout/wallet flows, broad creator-authoring coverage, rich social mutation, or monetization-team/S2S operations should remain deferred or internal unless the higher-level AeroBeat docs explicitly bring them into scope.

### 1. Things already handled by `aerobeat-vendor-modio`

This repo already gives us the docs-first REST seam for things like:
- auth/session requests
- game/mod browsing
- subscriptions and purchased state reads
- mod authoring and modfile routes
- media, metadata, dependencies, tags, comments, ratings
- collection and guide surfaces
- wallet, checkout, entitlements query, and other documented monetization REST routes
- mod event feeds

In plain terms: if AeroBeat needs to **talk to documented mod.io HTTP endpoints**, this repo is now in good shape.

### 2. Things Unity gives teams that this wrapper intentionally does not

Unity ships a lot more than raw API access. It also ships:
- client bootstrap and singleton/service wiring
- cached user/subscription/purchase state
- install/download/session orchestration
- UI panels and example flows
- store/platform-specific auth and monetization helpers

In plain terms: Unity is part REST client, part game-engine integration layer, part product starter kit.

`aerobeat-vendor-modio` is only the **REST wrapper** part.

### 3. What the next AeroBeat work probably is

The next likely work for AeroBeat is not "add another normal REST endpoint."
It is:
- a Godot-side mod.io service layer
- token/session persistence
- local cache/repository decisions
- install/download lifecycle handling
- Godot UI/UX for login, subscriptions, library, install/update state, and errors
- safe live integration testing with real mod.io credentials

## Simple difference summary

### `aerobeat-vendor-modio`

Use this for:
- truthful request building
- normalized mod.io REST responses
- docs-first seam verification
- keeping engine-agnostic API behavior stable

Do **not** expect it to be:
- a full mod manager runtime
- a UI kit
- a store SDK bridge
- a Unity-style app framework

### Unity SDK

Use Unity as a reference for:
- what a finished game integration usually needs above REST
- what UX flows mod.io expects games to support
- how install/state/monetization flows may be organized

Do **not** treat Unity as a parity target for this vendor wrapper.

## What maps to Godot responsibilities above the wrapper

This is the most important planning section for AeroBeat.

### Godot should own these responsibilities

#### App/bootstrap layer
Godot should decide:
- when mod.io services start and stop
- where tokens are stored
- how auth/session refresh is handled
- how wrapper calls are injected into the rest of the game

Unity has its own runtime/bootstrap pattern. We should **not** port that structure directly into this repo.

#### Local user state
Godot should own:
- current user profile state
- subscribed mods state
- purchased/unlocked state
- collection/library state
- local caching and refresh policy

Unity has repository/state helpers for this. For AeroBeat, that belongs in a Godot-facing integration layer above the wrapper.

#### Download/install/update workflow
Godot should own:
- download queueing
- install destinations
- temp file handling
- retries/resume policy
- disk-space checks
- enable/disable/update behavior

This is one of the biggest functional gaps between "REST wrapper complete" and "game feature complete."

#### UI/UX
Godot should own:
- login screens
- terms/consent prompts
- browse/search screens
- subscribed/library/install views
- progress/error UI
- purchase/storefront UI if AeroBeat uses it

Unity UI/examples/helpers should be treated as:
- **reference material for product flows and edge cases**
- **not code to port 1:1**

A direct UI port would bring Unity assumptions into the Godot stack and likely create more confusion than value.

#### Platform/store integration
If AeroBeat needs platform-native purchase or entitlement sync behavior, Godot will likely need:
- engine/plugin bindings for the target store/platform
- wrapper calls for the documented mod.io side
- separate live validation of each platform path

This is not something the current wrapper solves by itself.

## What Unity pieces should be ported vs. treated as references

### Treat as references, not direct port targets

- Unity UI panels
- Unity example scenes
- Unity service-locator/bootstrap structure
- Unity-specific auth display helpers
- Unity install manager architecture
- Unity purchasing bridge code

These are useful to **study**, but they should not be blindly copied into Godot.

### Reasonable to translate conceptually into Godot

- which user flows exist
- which states the game needs to track
- which install/download edge cases matter
- what success/failure UX needs to exist
- what minimum product behavior mod.io expects around auth, subscriptions, installs, and entitlements

So the rule of thumb is:
- **port the product ideas and required behaviors**
- **do not port the Unity implementation shape**

## Outstanding drift / questions to ask mod.io

These are the items most likely to change AeroBeat scope or reduce integration risk.

### 1. `/me/iap/*/sync` official support and exact contracts

We need a clear answer on:
- which `/me/iap/*/sync` routes are officially supported today
- which platforms are truly supported for non-Unity/custom-engine clients
- exact request body fields per platform
- exact required headers per platform
- where the canonical docs live if they are not in `/workspace/projects/modio/modio-docs/`

This is the biggest remaining drift area.

### 2. Non-Unity monetization model for custom-engine games

We should ask mod.io:
- for Godot/custom-engine games, should we prefer wallet/checkout flows, platform-native purchase + sync flows, or both?
- which storefront/platform combinations are considered production-ready outside Unity/Unreal?
- what client-side enforcement or restrictions do they expect us to own?

### 3. WSS / device-style auth expectations

We should ask:
- is the WSS/device-style auth flow officially supported outside Unity?
- is there a stable public contract for custom engines?
- should Godot stick to documented REST auth flows unless mod.io says otherwise?

### 4. Install-management expectations for custom engines

We should ask:
- does mod.io expect custom engines to build install/session management fully themselves?
- are there reference expectations for temp sessions, retries, enable/disable rules, or local repository semantics?

## Testing reality: what is covered now vs. what still needs live testing

### What current coverage really means

Current coverage is strong for **wrapper truth**, but it is still mostly:
- mocked/unit-style request-builder tests
- mocked transport tests
- fixture/docs-truth validation
- repo-level validation that the wrapper matches the local REST documentation we have

That is valuable, but it is **not the same as real live mod.io integration testing**.

### What real live testing will likely require

A real live wrapper test pass will likely need a **private local test setup** that is **not committed** to the repo.

That setup will probably include:
- mod.io game **public key**
- mod.io **private/API key** or other auth material needed for the specific flows under test
- a safe local env/config file such as an untracked `.env`, local test config, or equivalent secret-backed harness input
- a dedicated low-risk mod.io game/test space or clearly scoped live-test content
- explicit rules for what the live tests are allowed to create, update, subscribe to, purchase, or delete

### Safe live-test scope recommendation

For AeroBeat, the safest next live-test scope is probably:
- auth/session smoke testing
- browse/read endpoints
- subscription state checks in a controlled test account
- one or two carefully scoped write flows in a test-only mod/game area

Do **not** start with destructive or monetization-sensitive live tests unless the env/config and test account boundaries are locked down first.

### Practical implication for planning

Before we claim "real integration verified," AeroBeat likely needs a separate follow-up task to define:
- local secret/config shape
- safe test accounts
- safe test content ownership
- allowed write/delete scope
- whether monetization/IAP live tests are in or out for the first pass

## Bottom line for AeroBeat

The main gap is no longer "missing public REST wrappers."

The main gap is:
- Godot runtime/integration work above the wrapper
- unresolved mod.io guidance for some monetization/auth paths
- absence of private credential-backed live integration testing

So the honest next plan is:
1. keep `aerobeat-vendor-modio` as the thin docs-first REST seam
2. build AeroBeat's Godot-side integration layer above it
3. ask mod.io for clarification on the drifted monetization/auth surfaces
4. define a private, safe, live-test setup before claiming production readiness
