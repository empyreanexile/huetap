# Overview

## Product

HueTap is an Android app that lets a user trigger pre-configured Philips Hue scenes by tapping NTAG215 NFC cards placed around their home. The cards are the only way to fire scenes from the app; the app’s user interface exists only for setup, configuration, and debugging.

The product is local-only: the app talks directly to each paired Hue Bridge over the local network using the CLIP v2 API. There is no backend service, no user accounts, no cloud sync, and no remote-access capability. The app works only when the phone is on the same network as the bridge a card is bound to.

HueTap is not a general-purpose Hue controller. It does not let users dim lights, change colors, configure scenes, or manage rooms — those tasks belong in the official Hue app. HueTap consumes scenes that the user has already created elsewhere and exposes them as physical tap targets.

HueTap is not a smart home automation platform. It controls Hue scenes only. It does not support webhooks, action chains, scheduled actions, or integrations with other services in v0.1.

HueTap is a personal tool released as open source. It is not a commercial product and has no paid tier. The expected user is a Hue owner with a few NFC stickers who wants physical triggers for routines they already use.

## Target User

A single primary persona: a Philips Hue owner with an Android phone, basic comfort with installing apps from GitHub or Play Store, and willingness to write NFC tags using the in-app flow. Users are expected to already have configured Hue scenes in the official app. The app accommodates owners of one bridge as well as those with multiple bridges in the same home.

International availability is unrestricted, but English is the only language at launch. Internationalization scaffolding is in place for community-contributed translations.

## In scope for v0.1

| Capability | Notes |
| --- | --- |
| Bridge pairing (multiple) | mDNS discovery, link-button exchange, TOFU cert capture; first bridge in onboarding, additional from settings |
| Bridge management | List, rename, re-pair, remove (per-bridge); detect already-paired bridges; bulk re-pair walkthrough |
| Scene listing | Synced per-bridge; grouped by room and zone within each bridge; searchable |
| NFC card binding | Write UUID v4 to blank tag, bind to a scene on a chosen bridge with a label |
| NFC tap firing | Background reads, scene recall via local API to the binding’s bridge, haptic + toast feedback |
| Card management | Revoke, delete (both with optional verified tag wipe), update bound scene, edit label |
| Tap log | Persistent, last 100 entries across all bridges, timestamp + scene + bridge name + result |
| Settings | Bridge management, privacy preferences |
| Crash reporting | Sentry SaaS, opt-in on first launch, aggressive scrubbing |
| Auto-backup | Android Backup Service for bindings + settings only (bridge credentials excluded) |
| Docs | README, SPEC.md, NFC card buying guide, troubleshooting guide |

## Out of scope for v0.1

| Capability | Reason for exclusion |
| --- | --- |
| iOS support | Defer; Android-only for first release |
| Webhooks | Single-feature focus; HueTap fires scenes only |
| Action chains | Single-feature focus |
| Cloud / remote-access | Substantial complexity; not needed for at-home use |
| In-app scene firing | Cards are the only intended trigger |
| Home screen widgets | Same reason |
| Per-card PIN protection | Threat model doesn’t justify the UX cost in v0.1; revisit if real users ask |
| Biometric auth | Out of scope alongside PIN |
| Cert change detection / warnings | TOFU only; re-pair to re-pin |
| F-Droid distribution | Reproducible builds and signing handover add release pipeline complexity not justified for v0.1 |
| Multiple user accounts | Single-user device assumption |
| Tap-aware automations (e.g. event stream subscriptions) | Out of v0.1 |
| Cross-bridge scene picker grouping | Scenes are bridge-local; binding flow picks bridge first |

## Design principles

**Tap to act.** The card is the entire user interface during normal operation. Once configured, the user never opens the app to fire a scene.

**Local-first by necessity, not by ideology.** Cloud Hue access requires OAuth, registered developer credentials, and ongoing maintenance. Local-only is dramatically simpler and the LAN trip is faster than a cloud round-trip.

**Strict failure modes.** When a binding’s bridge is unreachable, the bound scene has been deleted, or the cert pin no longer validates, the app refuses the action and surfaces the error. No silent fallbacks, no queued retries, no last-known-state guesses.

**Revoked is not a failure.** A revoked card opens the binding screen on tap so the user can re-bind it. Same for tags whose URI exists but isn’t bound on this install.

**No per-card auth in v0.1.** Cards are physical objects; if an attacker has your card, they can fire your scene. The threat model is “single home, casual physical access” — turning lights on and off is low-stakes. Anything more is a later problem.

**TOFU, not full PKI.** Each bridge presents a self-signed cert; on first pair, we trust and pin its fingerprint. Subsequent connections to that bridge validate against the pin; mismatches fail loudly. Re-pair is the only way to update the pin, and re-pair simply trusts whatever cert the bridge presents at that moment — no comparison, no warning.

**Multi-bridge as a first-class home reality.** Real Hue homes often have multiple bridges (one per floor, indoor + outdoor, etc.). Each card binding carries its own bridge reference; tap firing routes to the correct bridge transparently and independently — bridges do not block each other.

**Production quality, single-user expectations.** The spec is written for a polished open-source release with real users, but the product itself is scoped to a single home with one or more bridges. No multi-tenancy concerns, no quota systems, no payment infrastructure.
