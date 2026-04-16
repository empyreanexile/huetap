# HueTap Privacy Policy

**Last updated:** 2026-04-16 (spec v1.4 baseline; implementation in progress)

HueTap is a local-only Android app that controls Philips Hue scenes on your home network. It has no backend, no user accounts, and does not sync to any cloud.

## Data the app collects

Nothing by default.

With your explicit opt-in on first launch (toggleable anytime in settings), the app may send **anonymous crash reports** to Sentry (a SaaS crash-reporting provider). Reports contain:

- Stack trace frames
- Exception class name (e.g. `DioException`, `TimeoutException`, `CertificateMismatchException`)
- Device model
- Android version
- App version

## Data stripped before sending

A `beforeSend` scrubbing hook removes the following from all fields and breadcrumbs before a crash report leaves your device:

- IPv4 addresses, including those with optional ports — regex: `/\b\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?\b/`
- IPv6 addresses — regex: `/\b(?:[0-9a-f]{1,4}:){2,7}[0-9a-f]{1,4}\b/i`
- UUIDs — regex: `/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i`
- URLs — regex: `/https?:\/\/[^\s]+/`
- Exception `value` fields are replaced with the exception class name only
- HTTP breadcrumbs (`category == "http"`) are dropped entirely

False positives (e.g. version strings that match the IPv4 pattern) are accepted — over-stripping is the safer side for privacy. The source of these regexes is auditable in the repository.

## Data the app stores locally

On your device, in app-private storage:

- **Bridge metadata** (IP, bridge ID, name, pair time) — backed up via Android Backup Service.
- **Scene cache** (scene names, room/zone grouping) — backed up.
- **Card bindings** (UUIDs from your NFC cards, bound scene IDs, labels) — backed up.
- **Tap log** (last 100 entries across all bridges) — backed up.
- **App settings** (including your crash-reporting opt-in choice) — backed up.
- **Bridge application keys and TLS cert fingerprints** — stored in `files/no_backup/bridge_credentials.json`, **excluded from Android Backup** by Android convention. Restoring a backup on a new device will require you to re-pair every bridge.

## Data the app transmits

- **Hue Bridge API calls** to your bridges on the local network (HTTPS, pinned to each bridge's self-signed cert after first pair).
- **Anonymous crash reports** to Sentry — only if you opted in.

The app does not transmit any other data.

## Data the app does not collect

- No analytics.
- No advertising identifiers.
- No location.
- No contacts.
- No microphone or camera.

## Your rights

- **Uninstall the app** to delete all local data, including backed-up data on your next Android Backup Service cycle.
- **Disable crash reporting** anytime in Settings → Privacy.
- **Audit the scrubbing rules** in source (the exact regexes above are the ones applied in the `beforeSend` hook).

## Contact

Report privacy concerns as GitHub issues on the repository.
