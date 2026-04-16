# Distribution

## GitHub Releases

Primary distribution for technical users. Each release includes:

- Three APKs (one per ABI). **Placeholder phase (current):** APKs are built with `--debug --split-per-abi` and signed only by the debug keystore; they are suitable for sideloading. **Release phase (pre-v1.0):** once a release keystore is generated and stored as the `KEYSTORE_*` GitHub Actions secrets, the workflow switches to `--release --split-per-abi` signed with that keystore.
- SHA-256 checksums
- Release notes
- Source tarball (auto-generated)

Users sideload by enabling “Install from unknown sources” and installing the APK matching their device’s ABI.

## Play Store

Requires a Google Play Developer account (\$25 one-time). Listed as a free app with no in-app purchases. Uses a single AAB build covering all ABIs.

Play Store listing requires:

- App icon (placeholder: Material Symbols icon styled with Twilight Hearth colors)
- Feature graphic (1024×500)
- 2–8 screenshots
- Short description (80 chars)
- Full description
- **Privacy policy URL:**
	- Production phase: `https://<production-domain>/privacy` (rendered from `PRIVACY.md`, hosted alongside the App Links landing page on Cloudflare Pages or equivalent).
	- Placeholder phase (pre-domain): `https://github.com/<owner>/<repo>/blob/main/PRIVACY.md` as a temporary fallback. The production URL replaces it before public Play Store rollout.
- Content rating (Everyone)
- Target audience (Adults)
- **Data Safety declaration:**
	- Data collected: crash diagnostics (stack traces, device model, OS version, app version) — optional, user-toggleable, not used for advertising or analytics
	- Data shared: none
	- Data encrypted in transit: yes (HTTPS to Sentry)
	- Data deletion mechanism: uninstall the app, or disable crash reporting in settings
	- All other categories: not collected

## Versioning

Semantic versioning. v0.1.0 is the first public release. Patch versions (v0.1.x) for bugfixes. Minor versions (v0.x.0) for feature additions that don’t break the spec. Major versions (vx.0.0) for breaking changes.

`pubspec.yaml` version field uses Flutter’s `<semver>+<build_number>` format. Build number is monotonically increasing for Play Store.
