# Privacy and security

## Data collection

The app collects no telemetry by default. With explicit user consent, the app sends crash reports to Sentry SaaS containing only stack trace frames, exception class name, device model, Android version, and app version. URLs, IPs (v4 and v6, with optional ports), UUIDs, scene names, card labels, and bridge names are stripped by an explicit `beforeSend` hook before transmission (see [Crash reporting](technical.md#crash-reporting)).

## Data storage

All app data is stored locally on the device:

- Drift database in app-private storage (Bridges metadata, Scenes, CardBindings, TapLogs, Settings)
- Bridge credentials (per-bridge application key + cert fingerprint) in app-private `files/no_backup/bridge_credentials.json`, excluded from Android Backup
- shared_preferences in app-private storage

No data is transmitted off-device except scrubbed crash reports (when enabled) and Hue API calls (which stay on the LAN).

## Security considerations

- **NFC card cloning:** NTAG215 cards have writable UIDs on some clones. The app does not rely on UID for security; the URI on the card is the only identity. A cloned card with the same URI behaves identically — by design, this enables backup cards.
- **No card-level auth:** PIN protection is intentionally out of v0.1 scope. Threat model: physical access to a card lets the holder fire a Hue scene. This is judged acceptable for v0.1 because Hue scenes turn lights on and off; nothing more.
- **TOFU cert pinning, per bridge:** each bridge presents a self-signed cert; we trust it on first pair, pin its fingerprint, and validate every subsequent connection to that bridge against its pin. Mismatches hard-fail. Re-pair is the only way to update a pin and simply re-captures whatever cert the bridge currently presents — no warnings, no comparison.
- **Application key storage:** stored per-bridge in app-private `files/no_backup/`. An attacker with root access could extract them; this is accepted for v0.1 as the threat model is “single-user device, casual physical access.”
- **Backup security:** Android Backup Service encrypts backups with a key tied to the user’s lock screen credential. Bindings, scenes, and tap log are backed up; bridge credentials are not, so a restored install on a new device always re-pairs every bridge.
- **Tag wipe is best-effort and verified:** the optional “Wipe tag” affordance on Revoke and Delete only fires if the user taps the correct card during the confirmation dialog. The app reads the tag’s URI first and refuses to wipe a card that doesn’t match.

## Privacy policy content

The PRIVACY.md document covers:

- What data the app collects (scrubbed crash reports only, optional)
- What data the app stores locally (bindings, scenes, log)
- What data the app transmits (Hue API calls on LAN, optional Sentry crash reports with explicit scrubbing)
- What data the app does not collect (no analytics, no advertising IDs, no location)
- The exact `beforeSend` scrubbing rules (so the user can audit them in source)
- User rights (delete app to delete all data; toggle crash reporting in settings)
- Contact (GitHub issues)
