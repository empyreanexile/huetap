# Documentation

## Repository documents

| File | Purpose |
| --- | --- |
| `README.md` | Project overview, screenshots, install instructions, link to docs |
| `SPEC.md` | This document |
| `CONTRIBUTING.md` | Issue reporting, PR conventions, code style, pinned dependency versions |
| `PRIVACY.md` | Privacy policy for Play Store and in-app linking |
| `LICENSE` | MIT license text |
| `CHANGELOG.md` | Per-release notes |
| `docs/setup.md` | Detailed setup walkthrough with screenshots; covers single- and multi-bridge homes |
| `docs/nfc-cards.md` | What NFC cards to buy, where to buy them, how to position them |
| `docs/troubleshooting.md` | Common issues: bridge not found, scenes not appearing (assign to a room or zone), cert mismatch (re-pair), taps not registering, multi-bridge gotchas, restoring a backup with multiple bridges |
| `docs/architecture.md` | High-level architecture overview for contributors, including the multi-bridge client registry |

## In-app help

The settings screen includes a “Help” section with links to the docs above (opens in browser). No in-app help content is embedded; the docs are the source of truth.

## Issue templates

GitHub issue templates for:

- Bug report (with required fields: device model, Android version, app version, bridge model, number of bridges paired, reproduction steps)
- Feature request (with required fields: use case, proposed behavior)
- Documentation issue
- Question

Labels: `bug`, `enhancement`, `documentation`, `question`, `good first issue`, `wontfix`, `duplicate`.

Triage commitment: respond to new issues within one week. Issues without responses for 30 days may be auto-labeled `stale` and closed after another 30 days without activity.
