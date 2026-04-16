# Security Policy

HueTap is a local-only Android app. Its security-relevant surfaces are:

- **TLS pinning** to each paired Hue Bridge (TOFU on pair, armed thereafter — SPEC §6.2).
- **NFC read/write** paths, including the verified "Wipe tag" affordance (SPEC §5.5, §5.7).
- **Bridge credentials on disk** at `files/no_backup/bridge_credentials.json` (SPEC §6.4).
- **Crash-report scrubbing** via Sentry's `beforeSend` hook (SPEC §6.9).

## Reporting a vulnerability

**Do not open a public GitHub issue for security reports.**

Please use GitHub's private vulnerability reporting: **Security → Report a vulnerability** on this repository. Include:

- A description of the issue
- Steps to reproduce (or a proof-of-concept)
- Affected app version and Android version
- Bridge firmware version if relevant

We aim to respond within one week. Fixes land in the next patch release.

## Supported versions

Only the latest released version is supported with security fixes during the v1.x line.

## Threat model notes (documented trade-offs)

These are conscious v1.0 decisions, not unknown gaps. Please check against these before reporting:

- **No per-card authentication.** Possession of a card fires its scene; this is acceptable because Hue scenes turn lights on/off (SPEC §10.3).
- **No cert-change warning UX.** A cert mismatch hard-fails the request and surfaces "Re-pair?"; re-pair re-captures whatever cert the bridge presents with no comparison (SPEC §6.2).
- **App keys live in plaintext JSON in app-private storage.** Root access extracts them. v1.x may move this into Keystore-backed storage (SPEC §14 backlog).
- **Cloned NTAG cards with the same URI behave identically.** The UID is not part of the binding identity — this enables intentional backup cards (SPEC §10.3).
