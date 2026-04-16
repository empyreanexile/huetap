# HueTap

An Android app that fires pre-configured Philips Hue scenes by tapping NFC cards.

**Status:** pre-v1.0. Spec is [locked at v1.4](SPEC.md); implementation is underway. Not yet released.

**Platform:** Android only.

## What it does

Tap an NTAG NFC card with your phone and a Hue scene plays on the bound bridge. The app is only for setup — binding cards to scenes, managing bridges, and viewing the tap log. Once configured, you never need to open it. Communication is LAN-only via Hue's CLIP v2 API; no accounts, no cloud.

Multi-bridge homes are first-class: each card binding carries its own bridge reference, and taps on different bridges fire in parallel.

## Documentation

- [`SPEC.md`](SPEC.md) — full requirements specification (source of truth)
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to contribute
- [`PRIVACY.md`](PRIVACY.md) — privacy policy
- [`CHANGELOG.md`](CHANGELOG.md) — release notes

Setup, NFC card, troubleshooting, and architecture guides (`docs/`) are added as the implementation progresses.

## License

MIT. See [`LICENSE`](LICENSE).
