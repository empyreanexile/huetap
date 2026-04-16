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

## Where SPEC sections live

| SPEC § | Code |
|---|---|
| §5.2 Pair bridge | [lib/core/net/bridge_pairing_service.dart](../lib/core/net/bridge_pairing_service.dart), [lib/features/pair/](../lib/features/pair) |
| §5.3 Scene sync | [lib/core/net/hue_api_client.dart](../lib/core/net/hue_api_client.dart), [lib/features/scenes/bridge_scenes_screen.dart](../lib/features/scenes/bridge_scenes_screen.dart) |
| §5.5 Bind card | [lib/core/nfc/](../lib/core/nfc), [lib/features/bind/](../lib/features/bind) |
| §5.6 Tap to fire | [lib/core/tap/](../lib/core/tap), [lib/features/tap/](../lib/features/tap) |
| §5.9 Re-pair | [lib/core/net/bridge_pinning_adapter.dart](../lib/core/net/bridge_pinning_adapter.dart) (service; UX TBD) |
| §6.2 Cert pinning | [lib/core/net/bridge_pinning_adapter.dart](../lib/core/net/bridge_pinning_adapter.dart) |
| §6.3 Schema | [lib/core/db/database.dart](../lib/core/db/database.dart) |
| §6.4 Credentials file | [lib/core/secrets/bridge_credentials_store.dart](../lib/core/secrets/bridge_credentials_store.dart) |
| §6.5 NFC intent routing | [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml), [lib/main.dart](../lib/main.dart) |
| §6.10 Auto-backup | [android/app/src/main/res/xml/backup_rules.xml](../android/app/src/main/res/xml/backup_rules.xml), [data_extraction_rules.xml](../android/app/src/main/res/xml/data_extraction_rules.xml) |

## Still to land

See the [SPEC.md](../SPEC.md) sections tracked as open feature work in issue labels: §5.1 Onboarding, §5.7 Card detail, §5.8 Tap log UI, §5.9 Re-pair UI, §5.11 Manage bridges + bulk re-pair, §5.12 Debounced resync, §5.13 Settings, §6.9 Sentry wiring, §7.2 Mock bridge fixture.
