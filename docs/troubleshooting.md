# Troubleshooting

> **Stub.** Expand as real-world issues come in. File an issue with device model + Android version + bridge model + number of bridges paired if a problem isn't covered here.

## Bridge not found during discovery

- Make sure your phone and the bridge are on the **same Wi-Fi network** (same SSID, not a guest network).
- Some routers block mDNS between wireless clients ("client isolation" or "AP isolation" — check your router settings).
- As a fallback, enter the bridge IP manually. Find it in the official Hue app under **Settings → Hue Bridges → i**.
- Corporate Wi-Fi often blocks multicast entirely — use a regular home network.

## "Press the link button" times out

- The round button on top of the bridge must be pressed **within 60 seconds** of the countdown starting.
- Press once; don't hold. The LED flashes to confirm.

## Scenes don't appear in the picker

**Scenes not assigned to a room or zone are hidden.** HueTap's picker groups by room/zone; unassigned scenes have nowhere to sit.

Fix: in the official Hue app, open the scene and assign it to a room or a zone, then pull-to-refresh the scene list in HueTap.

## "Bridge identity changed" / cert mismatch

This means the bridge presented a different TLS certificate than the one pinned on first pair. Common causes:

- Bridge firmware reset or factory-reset.
- Different physical bridge at the same IP.
- Someone-on-your-network attacking the TLS handshake (unlikely but possible).

HueTap refuses to send the request and offers **"Re-pair?"** — which re-captures whatever certificate the bridge presents now. If you know the bridge legitimately changed (e.g. you replaced the hardware), re-pair. If you don't know why, investigate before re-pairing.

## Tap doesn't fire

- Hold the card to the **back** of your phone, not the front.
- Some phones have the NFC antenna near the top, others in the middle. Experiment.
- **Metal phone cases block NFC.** Try without the case.
- If the phone is locked, the app fires from the lock screen without unlocking — but some OEM security policies may block this.

## Restored a backup — "N bridges need re-pairing"

This is expected. Android Backup Service preserves your bindings and tap log, but **not the bridge credentials** (app keys + TLS fingerprints). After restore, every bridge needs to be re-paired. Tap the banner's **"Re-pair all"** button for a guided walkthrough.

Bindings are preserved when the same bridge is re-paired. Bindings are deleted only when you re-pair onto a **different** bridge (different bridge ID).

## Multi-bridge gotchas

- Each card is tied to a specific bridge at bind time. Tapping a card fires its bridge — not whichever bridge is nearest.
- If bridge A is slow or offline, cards bound to bridge A fail; cards bound to bridge B keep working.
- Removing a bridge from HueTap deletes all bindings for that bridge. The physical cards retain their URIs and can be re-bound to scenes on other bridges by tapping them.
