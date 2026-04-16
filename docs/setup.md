# Setup

> **Stub.** This document will be expanded as Phase 2 (bridge pairing) and Phase 4 (NFC binding) UX stabilizes. File an issue if anything below is unclear on a current build.

## Prerequisites

- Android 14 (API 34) or newer
- NFC hardware (required — the app will refuse to install without it)
- A Philips Hue Bridge on the same Wi-Fi network as your phone
- At least one scene configured in the official Hue app, assigned to a room or zone (scenes with no room/zone are hidden from HueTap's picker — see [troubleshooting.md](troubleshooting.md))
- NTAG213, 215, or 216 cards/stickers (NTAG215 recommended — see [nfc-cards.md](nfc-cards.md))

## Pair your first bridge

1. Open HueTap.
2. Tap **"Find bridge"** on the welcome screen.
3. The app scans your LAN via mDNS for Hue bridges. If nothing is found in 30 seconds, you can enter the bridge IP manually (find it in the Hue app under Settings → Hue Bridges → i).
4. Pick the bridge.
5. Press the physical **round button on top of the Hue Bridge** within 60 seconds.
6. The app stores the bridge's application key and pins its TLS cert fingerprint.
7. Scenes from that bridge sync automatically.

## Bind a card to a scene

1. From the home screen, tap **"New"** → **"Bind a new card"**.
2. Pick a bridge (auto-skipped if only one is paired).
3. Pick a scene.
4. Enter a label (optional — defaults to the scene name).
5. **Hold a blank NTAG card against the back of your phone.**
6. The app writes `huetap://c/<uuid>` + your label to the tag and verifies the write by reading it back.
7. Stick the card somewhere and tap it.

## Adding more bridges

Once the first bridge is paired, use **"New"** → **"Pair another bridge"** from the home screen.

## Restoring from a backup

Android Backup Service saves your bindings, scene cache, tap log, and settings. Bridge credentials are intentionally **not** backed up for security.

After restoring on a new device, every paired bridge shows "Re-pair needed." The app will walk you through re-pairing each one — bindings are preserved when the bridge ID matches.
