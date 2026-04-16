# Architecture

> **Stub.** Read [`SPEC.md`](../SPEC.md) for the authoritative design — this file is a contributor-oriented map into the code.

## Layers

```
lib/
  core/
    db/              Drift schema + generated code (Bridges, Scenes, CardBindings, TapLogs, Settings)
    net/             BridgeClient registry, per-bridge dio + TOFU pinning, pairing, discovery
    nfc/             NfcService — read/write/wipe with readback verification
    secrets/         BridgeCredentialsStore — atomic JSON in files/no_backup/
    tap/             TapFireService + TapHandler (cross-cutting tap-to-fire pipeline)
    theme/           Twilight Hearth design tokens
    providers.dart   Top-level Riverpod wiring
  features/
    home/            Paired bridges + bound cards list
    pair/            Discovery → press-link → poll flow
    scenes/          Per-bridge scene list + "fire now"
    bind/            Blank-tag write sheet
    tap/             FireScreen (cold-start) + foreground TapHandler
    common/          Shared sheet + status card widgets
  l10n/              ARB files + generated AppLocalizations
  main.dart          Three launch paths: icon, cold-NFC (launchUuid), warm-NFC (uriLinkStream)
```

## Key invariants

- **Per-bridge `BridgeClient`** — each paired bridge has one dio instance, one pinning interceptor (TOFU during pair/re-pair, armed elsewhere), and one in-flight gate. Slow bridge A never blocks bridge B.
- **TOFU, not PKI** — each bridge's self-signed cert is pinned on first pair. Mismatches hard-fail. Re-pair re-captures whatever cert the bridge presents, without comparison.
- **Credentials live outside Drift** — `files/no_backup/bridge_credentials.json` holds app keys + cert fingerprints. Excluded from Android Backup by convention, so a restore always re-pairs.
- **Scenes have composite PK `(id, bridgeRowId)`** — Hue scene UUIDs are bridge-local. `CardBindings(sceneId, bridgeRowId) → Scenes(id, bridgeRowId)` is a composite FK that transitively guarantees binding-to-bridge integrity.
- **Three NFC launch paths** wired in `main.dart`: icon tap → HomeScreen; cold NFC (process dead) → `getInitialLink()` → FireScreen in place of HomeScreen; warm NFC (process alive, backgrounded) → `uriLinkStream` → FireScreen pushed on top and dismissed after fire.

## Where spec sections live

| Spec section | Code |
|---|---|
| [Bridge pairing](../spec/flows.md#bridge-pairing) | [lib/core/net/bridge_pairing_service.dart](../lib/core/net/bridge_pairing_service.dart), [lib/features/pair/](../lib/features/pair) |
| [Scene sync](../spec/flows.md#scene-sync) | [lib/core/net/hue_api_client.dart](../lib/core/net/hue_api_client.dart), [lib/features/scenes/bridge_scenes_screen.dart](../lib/features/scenes/bridge_scenes_screen.dart) |
| [NFC card binding](../spec/flows.md#nfc-card-binding) | [lib/core/nfc/](../lib/core/nfc), [lib/features/bind/](../lib/features/bind) |
| [NFC tap behavior](../spec/flows.md#nfc-tap-behavior) | [lib/core/tap/](../lib/core/tap), [lib/features/tap/](../lib/features/tap) |
| [Bridge re-pair](../spec/flows.md#bridge-re-pair) | [lib/core/net/bridge_pinning_adapter.dart](../lib/core/net/bridge_pinning_adapter.dart) (service; UX TBD) |
| [Bridge communication](../spec/technical.md#bridge-communication) | [lib/core/net/bridge_pinning_adapter.dart](../lib/core/net/bridge_pinning_adapter.dart) |
| [Database schema](../spec/technical.md#database-schema) | [lib/core/db/database.dart](../lib/core/db/database.dart) |
| [Bridge credentials file](../spec/technical.md#bridge-credentials-file) | [lib/core/secrets/bridge_credentials_store.dart](../lib/core/secrets/bridge_credentials_store.dart) |
| [NFC intent routing](../spec/technical.md#nfc-intent-routing) | [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml), [lib/main.dart](../lib/main.dart) |
| [Auto-backup](../spec/technical.md#auto-backup) | [android/app/src/main/res/xml/backup_rules.xml](../android/app/src/main/res/xml/backup_rules.xml), [data_extraction_rules.xml](../android/app/src/main/res/xml/data_extraction_rules.xml) |

## Still to land

Tracked against the [user flows](../spec/flows.md) and [technical](../spec/technical.md) specs: onboarding, card detail, tap log UI, re-pair UI, manage bridges + bulk re-pair, debounced resync, settings, Sentry wiring, and the mocked bridge fixture.
