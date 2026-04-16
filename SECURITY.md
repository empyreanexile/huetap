# Security Policy

HueTap is a local-only Android app. Its security-relevant surfaces are:

- **TLS pinning** to each paired Hue Bridge (TOFU on pair, armed thereafter — see [spec/technical.md#bridge-communication](spec/technical.md#bridge-communication)).
- **NFC read/write** paths, including the verified "Wipe tag" affordance (see [spec/flows.md#nfc-card-binding](spec/flows.md#nfc-card-binding) and [spec/flows.md#card-management](spec/flows.md#card-management)).
- **Bridge credentials on disk** at `files/no_backup/bridge_credentials.json` (see [spec/technical.md#bridge-credentials-file](spec/technical.md#bridge-credentials-file)).
- **Crash-report scrubbing** via Sentry's `beforeSend` hook (see [spec/technical.md#crash-reporting](spec/technical.md#crash-reporting)).

## Reporting a vulnerability

**Do not open a public GitHub issue for security reports.**

Please use GitHub's private vulnerability reporting: **Security → Report a vulnerability** on this repository. Include:

- A description of the issue
- Steps to reproduce (or a proof-of-concept)
- Affected app version and Android version
- Bridge firmware version if relevant

We aim to respond within one week. Fixes land in the next patch release.

## Supported versions

Only the latest released version is supported with security fixes.

## Threat model notes (documented trade-offs)

These are conscious v0.1 decisions, not unknown gaps. Please check against these before reporting:

- **No per-card authentication.** Possession of a card fires its scene; this is acceptable because Hue scenes turn lights on/off (see [spec/privacy-security.md#security-considerations](spec/privacy-security.md#security-considerations)).
- **No cert-change warning UX.** A cert mismatch hard-fails the request and surfaces "Re-pair?"; re-pair re-captures whatever cert the bridge presents with no comparison (see [spec/technical.md#bridge-communication](spec/technical.md#bridge-communication)).
- **App keys live in plaintext JSON in app-private storage.** Root access extracts them. A later release may move this into Keystore-backed storage (see [spec/backlog.md](spec/backlog.md)).
- **Cloned NTAG cards with the same URI behave identically.** The UID is not part of the binding identity — this enables intentional backup cards (see [spec/privacy-security.md#security-considerations](spec/privacy-security.md#security-considerations)).
