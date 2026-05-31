# mod.io REST corpus completeness audit — 2026-05-03

Local official sources audited:

- `projects/modio/modio-docs`
- `projects/modio/modio-sdk`
- `projects/modio/modio-unity`

## What is represented locally

Primary REST source of truth is `modio-docs`.

- 134 endpoint pages under `public/en-us/restapi/docs/*.api.mdx`
- 85 schema pages under `public/en-us/restapi/docs/schemas/*.schema.mdx`
- conceptual REST pages for introduction, filtering, pagination, sorting, errors, rate limiting, localization, reports, status/visibility, platforms, search, and monetization under `public/en-us/game-integration/restapi/`

Documented endpoint families present locally:

- games catalog/profile
- game stats, tags, media, token packs, cloud-cooking finalization
- mods
- mod comments, ratings, tags, metadata KVP, dependencies, dependants, events, stats
- modfiles, source modfiles, cloud-cooking cooks, multipart uploads, per-platform status management
- mod monetization team and checkout/purchase flow
- guides and guide comments
- collections, collection comments, followers, ratings, subscriptions, collection mods
- authenticated-user (`/me`) surfaces: profile, events, games, collections, followed collections, files, mods, purchases, ratings, subscriptions, wallets, entitlements, muted users, followers
- user social/profile surfaces: followers, following, collections, mute/unmute
- OAuth email request/exchange/logout
- external auth providers: Apple, Discord, Epic, GOG Galaxy, Google, Oculus, OpenID, PSN, Steam, Switch, UDT, Xbox
- agreements / terms
- reporting
- server-to-server monetization / transaction / connection surfaces
- ping utility

## Gaps and risks

The local corpus is strong enough for a strict wrapper audit, but not perfectly self-sealing.

1. `modio-docs` appears to contain at least two dead or missing internal REST doc routes referenced from endpoint/schema pages:
   - `/restapi/docs/files`
   - `/restapi/docs/metadata`
   These are referenced from pages such as `get-mods.api.mdx`, `get-mod-dependencies.api.mdx`, and `get-user-modfiles.api.mdx`, but no matching local page exists.

2. There is no local OpenAPI/Swagger artifact in the audited official repos. For wrapper work this means endpoint existence and many response shapes are documented, but there is no single machine-readable contract to prove every field/enum globally.

3. Deprecated-but-still-documented fields are present inside schema content and need to remain in audit scope rather than being assumed removable. Examples observed locally include `timezone`, `language`, `virustotal_hash`, and deprecated tag/date fields.

4. `modio-sdk` and `modio-unity` are useful sanity references for behavior and supported workflows, but they do not replace `modio-docs` as a full REST inventory. They cover common integration slices rather than the complete REST surface.

## Recommendation

Recommendation: proceed with the strict `aerobeat-vendor-modio` repo audit using the current local corpus.

Reasoning:

- endpoint-family coverage is broad and current enough to audit wrapper path/method/query/body support
- schema coverage is substantial enough to audit most normalized objects and fixtures
- the known corpus gaps are narrow and identifiable, not broad enough to block repo auditing

Follow-up recommendation:

- if the repo audit reaches a disputed field/enum/edge-case not clearly resolved by the local docs pages and schema pages, pull additional official material at that moment rather than assuming undocumented behavior
- specifically keep an eye on metadata/file conceptual docs and any S2S / monetization edge cases, because those are the clearest local weak spots
