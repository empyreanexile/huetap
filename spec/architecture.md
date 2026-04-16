# Architecture

## Stack

| Layer | Choice |
| --- | --- |
| UI framework | Flutter (latest stable; targetSdk 34+) |
| State management | Riverpod (pin to a specific 3.x minor in `pubspec.yaml`; document chosen version in CONTRIBUTING) |
| Local storage | Drift (SQLite) |
| HTTP client | dio with custom cert pinning interceptor (one instance per bridge, registered in `BridgeClientRegistry`) |
| NFC | nfc_manager |
| Crash reporting | sentry_flutter (Sentry SaaS) |
| Discovery | multicast_dns for mDNS |
| Localization | flutter_localizations + intl |

No cryptography dependency in v0.1: cert fingerprinting uses Dart’s built-in SHA-256.

## Code organization

The project follows clean-architecture conventions: `data/` (DTOs, API clients, Drift DAOs), `domain/` (typed entities, use cases), `presentation/` (widgets, providers). Riverpod providers live in `presentation/providers/` per feature.

```plain text
lib/
  core/
    theme/             — Twilight Hearth tokens
    errors/            — typed failure types
    db/                — Drift database setup, migrations
    net/               — BridgeClientRegistry, per-bridge dio + TOFU pinning interceptor
    secrets/           — no_backup credentials file (load, store, remove)
  features/
    onboarding/        — welcome, privacy opt-in, first-bridge pairing, first-card tutorial
    bridges/           — discovery, pairing, manage list, rename, re-pair, remove, bulk re-pair walkthrough
    scenes/            — per-bridge sync, picker, room+zone grouping, search
    cards/             — bind, revoke, delete (+ optional verified tag wipe), label, update scene
    nfc/               — read/write/wipe, intent handling, URI parsing
    log/               — tap history view, write helpers
    settings/          — bridge list entry point, privacy toggles
  l10n/                — ARB files, generated localizations
  main.dart
```

## Data flow

```plain text
NFC tap (background)
      ↓
Android intent → MainActivity (singleTop, showWhenLocked) → deep link handler
      ↓
Parse URI → extract UUID → look up CardBinding in Drift
      ↓
   ┌──── if RepairInProgress flag is set → snackbar "Re-pair in progress" + drop
   ├──── if missing → open binding screen with UUID pre-filled (Entry B, see [NFC card binding](flows.md#nfc-card-binding))
   ├──── if revoked → open binding screen, treat as blank
   ├──── if scene orphaned → snackbar with "Update binding" action; do not fire
   │
   ├──── fetch Bridge row by binding.bridgeRowId; load credentials from no-backup file
   ├──── obtain BridgeClient from registry (creates on first use, with cert pin armed)
   ├──── if per-bridge in-flight gate is set for THIS bridge → drop tap silently
   │           ↓
   │     TLS handshake; pinning interceptor verifies presented cert's
   │     SHA-256 against stored fingerprint → mismatch = hard fail,
   │     snackbar offers "Re-pair <bridge name>"
   │           ↓
   │     PUT /clip/v2/resource/scene/{uuid} with {"recall":{"action":"active"}}
   │           ↓
   │     handle response → success: haptic + toast + log success + update Bridges.lastReachable
   │                       failure: status-code-specific snackbar + log error
   │           ↓
   └──── trigger background scene re-sync for THIS bridge (debounced)
```

The in-flight gate is **per-bridge**. Independent bridges fire independently; a slow bridge does not block others. Within a single bridge, a second tap arriving while the first is in flight is dropped silently with a debug log entry.
