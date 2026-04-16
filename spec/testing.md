# Testing and CI

## Coverage targets

No quantitative line-coverage threshold in CI. Coverage is qualitative: every item in this table has at least one test.

| Layer | Coverage approach |
| --- | --- |
| Hue API client | Unit tests with mocked HTTP responses for every endpoint, including 404, 5xx, 401/403, and network/timeout |
| URI parsing | Unit tests for both `huetap://` and `https://` schemes, plus malformed and edge-case URIs |
| Card binding logic | Widget tests covering blank-tag, overwritten-tag, rebind (with old-row deletion), unknown-URI flows, and revoked-card UPDATE path |
| NFC write verification | Unit tests for write-then-readback with mismatch and retry paths, and tag-state-on-double-failure |
| NFC wipe | Unit tests for URI-verify-then-wipe, including the mismatch-refuse path |
| Bridge pairing | Integration tests against the mocked bridge fixture, including already-paired detection |
| Bridge re-pair branching | Integration tests for same-bridge and new-bridge paths, including FK-scoped binding/scene deletion |
| Bulk re-pair walkthrough | Tests for sequential progression, mid-walkthrough cancel, mid-walkthrough failure, and full-completion banner dismissal |
| Re-pair-in-progress gate | Test that taps during active re-pair are dropped with the snackbar and do not recurse |
| Multi-bridge | Tests covering: 2+ bridges paired, binding flow with bridge picker, tap routing to correct bridge, per-bridge in-flight gate (slow bridge A doesn’t block tap on bridge B), removing a bridge cascades correctly, restoring a multi-bridge backup surfaces re-pair-needed and bulk re-pair walks through them |
| Cert pinning | Per-bridge tests for TOFU mode, armed mode, and mismatch (raise `CertificateMismatchException`) |
| Credentials file | Unit tests for atomic write, concurrent access serialization, multi-bridge map round-trip, and startup recovery cases |
| Scene firing | Integration tests covering success, 404 (immediate sync + orphan snackbar), 401, 5xx, 3s timeout, in-flight drop |
| Scene sync orphan sweep | Tests verifying orphaned scenes with zero CardBinding refs are deleted; orphaned scenes with refs are retained |
| Empty-cache + sync failure | Test verifying picker shows the empty state with retry and binding flow blocks correctly |
| Background re-sync race | Test that triggers fired during in-progress sync are coalesced via `pendingResync` and not lost |
| Tap log pruning | Test verifying the DELETE-with-NOT-IN keeps exactly the latest 100 by id; failure of pruning doesn’t roll back the insert |
| Status badge logic | Tests for each priority case (Re-pair needed \> Unreachable \> Reachable) including the 5-minute threshold |
| Onboarding flow | Widget tests for the full first-launch sequence |
| Sentry scrubbing | Unit tests verifying `beforeSend` strips IPv4 (with port), IPv6, UUIDs, URLs, and HTTP breadcrumbs from synthetic events |

## Mocked bridge fixture

A test fixture (`test/fixtures/mock_bridge.dart`) implements a minimal HTTP server matching the CLIP v2 API surface used by the app:

- `GET /api/0/config` returns a configurable bridge ID
- `GET /clip/v2/resource/scene` returns a configurable list
- `GET /clip/v2/resource/room` returns a configurable list
- `GET /clip/v2/resource/zone` returns a configurable list
- `PUT /clip/v2/resource/scene/{id}` with valid recall returns 200; configurable to return 404, 401, 403, 500, or hang past the timeout
- Configurable cert mismatch and bridge-ID change scenarios
- Self-signed cert generated at fixture setup, fingerprint exposed for pinning tests; alternate certs exposed for mismatch tests
- The fixture can be instantiated multiple times with distinct ports and certs to test multi-bridge scenarios.

## CI pipeline

GitHub Actions workflow `ci.yml`:

- **On every PR and push to main:**
	- `flutter analyze` (must pass with no warnings)
	- `flutter test` (must pass)
	- `dart format --output=none --set-exit-if-changed .`
- **On tag push (semver tag like `v0.1.0`):**
	- All of the above
	- **Placeholder phase (current):** CI on tag push builds `--debug --split-per-abi` APKs, unsigned except by the debug keystore; suitable for sideloading.
	- **Release phase (pre-v1.0):** once a release keystore is generated and stored as the `KEYSTORE_*` GitHub Actions secrets, the workflow switches to `--release --split-per-abi` signed with that keystore.
	- Builds cover arm64-v8a, armeabi-v7a, and x86_64.
	- Upload APKs as artifacts to a GitHub Release.
	- Generate SHA-256 checksums alongside.

A separate workflow handles Play Store uploads via fastlane, manually triggered to avoid accidental publishes.
