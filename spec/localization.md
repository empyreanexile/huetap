# Localization

## Approach

The app uses Flutter’s standard localization stack: `flutter_localizations`, `intl`, ARB files in `lib/l10n/`.

All user-facing strings are externalized via `AppLocalizations.of(context).<key>`. No hardcoded English strings outside of the ARB files. Strings that interpolate bridge names, card labels, or scene names use ICU placeholders.

## Languages at launch

English (`en`) only. The ARB infrastructure is in place so contributors can add languages by submitting new ARB files via PR.

## Translation workflow

A `docs/i18n.md` document explains how to contribute translations:

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<locale>.arb`
2. Translate all values, leaving keys and `@@locale` metadata
3. Submit a PR

Translations go through standard PR review. Maintainer reviews translations only for completeness and obvious technical errors, not for linguistic quality.
