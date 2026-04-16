# Changelog

All notable changes to this project are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

- Initial repository scaffolding against [spec v1.4](SPEC.md).
- Raised Android `minSdk` to 34 (Android 14). Drops pre-Android-14 device support; the spec allows this (SPEC §4.1 only commits to `targetSdk 34+`, not a minSdk floor).
- Switched Twilight Hearth theme to the **light variant** per the v4 wireframes. Deviates from SPEC §6.7 ("dark mode only") but within the door that section leaves open ("v1.x will revisit with a light variant if issue volume warrants it"). Spec wording should be reconciled before v1.0 lock. Full token set added to `lib/core/theme/twilight_hearth_theme.dart`: cream surfaces, 4-level text hierarchy, accent colors (rose/meadow/blue/amber/danger), gradients (primary/charcoal/hero/scaffoldBody/overlay), radii, and shadows.
