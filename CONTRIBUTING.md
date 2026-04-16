# Contributing to HueTap

Thanks for your interest. Before opening a PR, read [`SPEC.md`](SPEC.md) — it is the source of truth for scope, architecture, and behavior.

## Reporting issues

Use the [issue templates](.github/ISSUE_TEMPLATE). Bug reports must include device model, Android version, app version, bridge model, and number of bridges paired. We aim to respond within one week. Issues without activity for 30 days may be labeled `stale` and closed after another 30 days.

## Development setup

1. Install Flutter stable (latest; targetSdk 34+).
2. Clone the repo.
3. `flutter pub get`.
4. `flutter analyze` and `flutter test` to verify.

## Pull requests

- One logical change per PR.
- Include tests for new behavior (see [spec/testing.md](spec/testing.md) for coverage targets).
- Run `dart format .` before committing.
- `flutter analyze` must pass with zero warnings.
- `flutter test` must pass.
- CI (lint, test, format) runs on every PR.

## Code style

- Follow `dart format` defaults.
- Clean-architecture layout: `data/`, `domain/`, `presentation/` inside each feature (see [spec/architecture.md#code-organization](spec/architecture.md#code-organization)).
- Riverpod providers live under `presentation/providers/` per feature.
- No hardcoded user-facing strings outside of ARB files (`lib/l10n/`).

## Pinned dependency versions

The spec requires pinning Riverpod to a specific 3.x minor. The chosen version is recorded in `pubspec.yaml`; document any bumps here and in `CHANGELOG.md`.

- Riverpod: `<pin recorded in pubspec.yaml>`

## Translations

See [docs/i18n.md](docs/i18n.md). Two starter locales (`en_US`, `en_GB`) sit alongside the canonical `app_en.arb` template. To contribute another language, copy `lib/l10n/app_en.arb` to `lib/l10n/app_<locale>.arb`, translate values, and submit a PR.

## License

By contributing you agree that your contributions are licensed under the MIT License (see [`LICENSE`](LICENSE)).
