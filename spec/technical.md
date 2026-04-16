# Technical

> This file describes the v0.1 design contract. See the project README for current implementation status.

## NFC card format

- **Tag types supported:** NTAG213 (137 bytes usable), NTAG215 (504 bytes), NTAG216 (888 bytes). NTAG215 is recommended. Smaller variants (NTAG210/212) lack capacity for the URI plus NDEF framing and are not supported.
- **NDEF record:** Single URI record. Format depends on phase:
	- **Placeholder phase** (no domain): `huetap://c/<uuid>` where `<uuid>` is a UUID v4.
	- **Production phase** (post-domain): `https://<domain>/c/<uuid>` with the same UUID format. Tags written in the placeholder phase keep working forever — the production-phase APK registers intent filters for both schemes (see [NFC intent routing](#nfc-intent-routing)).
- **Read access:** Public. There is no per-card secret on the tag.
- **Write protection:** Cards are not locked after writing. v0.1 does not write-protect tags; users may overwrite them with other tools or with HueTap’s “Wipe tag” affordance ([Card management](flows.md#card-management)).
- **Write verification:** After writing, the tag is read back in the same NFC session and the URI is compared byte-for-byte. Mismatch triggers one retry.
- **Wipe verification:** Same session pattern; before writing the empty record, the tag’s existing URI is read and confirmed to match the card being revoked/deleted. Mismatch refuses the wipe ([Card management](flows.md#card-management)).

## Bridge communication

- **Discovery:** mDNS lookup for `_hue._tcp.local`. Falls back to manual IP entry if no service is found.
- **`BridgeClient` registry:** A central registry holds one `BridgeClient` per paired bridge. Each `BridgeClient` wraps a dedicated dio instance with its own pinning interceptor armed to that bridge’s stored fingerprint. Clients are created lazily on first use after app launch and re-created on re-pair. Removing a bridge unregisters its client. Each client also owns its bridge’s per-bridge in-flight gate ([NFC tap behavior](flows.md#nfc-tap-behavior)).
- **Cert handling — TOFU only:** Each `BridgeClient`’s pinning interceptor operates in two modes. In **TOFU mode** (during pairing and re-pair for that bridge), it accepts any cert and exposes the captured SHA-256 fingerprint to the caller. In **armed mode** (all other times), it validates the presented cert’s SHA-256 against that bridge’s stored fingerprint during the TLS handshake; mismatch raises `CertificateMismatchException` and the request is aborted before any HTTP body is sent. There is no comparison, warning, or “is this a new cert?” UX — re-pair simply re-captures whatever the bridge presents and overwrites the stored fingerprint for that bridge.
- **Auth:** `hue-application-key` HTTP header on all v2 endpoints, sourced from that bridge’s credentials entry.
- **Endpoints used (per bridge):**
	- `GET /api/0/config` — fetch bridge ID and name (during pairing, re-pair, and pull-to-refresh in [Manage bridges](flows.md#manage-bridges))
	- `GET /clip/v2/resource/scene` — list scenes
	- `GET /clip/v2/resource/room` — list rooms
	- `GET /clip/v2/resource/zone` — list zones
	- `PUT /clip/v2/resource/scene/{id}` with `{"recall":{"action":"active"}}` — fire scene
	- `POST /api` (v1 endpoint, used only during pairing) — exchange link-button press for application key
- **Timeout:** 3 seconds for scene-fire requests (target). 10 seconds for sync requests. 60 seconds for pairing.
- **`Bridges.lastReachable`:** updated on every successful HTTP response from that bridge, regardless of endpoint.

## Database schema

Tables:

```dart
@DataClassName('Bridge')
class Bridges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ip => text()();
  TextColumn get bridgeId => text().unique()();   // from /api/0/config; secrets file is keyed by this
  TextColumn get name => text().nullable()();
  DateTimeColumn get pairedAt => dateTime()();
  DateTimeColumn get lastReachable => dateTime().nullable()();
}

@DataClassName('Scene')
class Scenes extends Table {
  TextColumn get id => text()();             // Hue scene UUID (bridge-local)
  IntColumn get bridgeRowId => integer().references(Bridges, #id)();
  TextColumn get name => text()();
  TextColumn get roomId => text().nullable()();
  TextColumn get roomName => text().nullable()();
  TextColumn get zoneId => text().nullable()();
  TextColumn get zoneName => text().nullable()();
  BoolColumn get orphaned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSynced => dateTime()();

  @override
  Set<Column> get primaryKey => {id, bridgeRowId};
}

@DataClassName('CardBinding')
class CardBindings extends Table {
  TextColumn get uuid => text()();           // UUID v4 from card
  TextColumn get label => text()();
  IntColumn get bridgeRowId => integer().references(Bridges, #id)();
  TextColumn get sceneId => text()();
  BoolColumn get revoked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastTapped => dateTime().nullable()();
  IntColumn get tapCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {uuid};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (scene_id, bridge_row_id) REFERENCES scenes (id, bridge_row_id)',
  ];
}

@DataClassName('TapLog')
class TapLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bridgeRowId => integer().nullable().references(Bridges, #id)();
  TextColumn get cardUuid => text().nullable()();   // null if unbound
  TextColumn get cardLabel => text().nullable()();
  TextColumn get sceneId => text().nullable()();
  TextColumn get sceneName => text().nullable()();
  BoolColumn get success => boolean()();
  TextColumn get errorType => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
}

@DataClassName('Settings')
class SettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get crashReportingEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get language => text().withDefault(const Constant('en'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
```

**Multi-bridge notes:**

- `Bridges.bridgeId` is unique to prevent the same physical bridge from being paired twice.
- `Scenes` uses a composite primary key `(id, bridgeRowId)` because Hue scene UUIDs are bridge-local. The composite FK on `CardBindings(sceneId, bridgeRowId) → Scenes(id, bridgeRowId)` ensures a binding’s scene is on its declared bridge.
- Hue scene UUIDs are random 36-char strings; cross-bridge ID collisions are statistically negligible. Even if one occurred, the composite PK keeps the rows distinct.
- There is no global “active bridge” concept. Each `CardBinding` carries its own `bridgeRowId`. Settings stores no bridge selection.

**Foreign-key composition on `CardBindings`:** the table declares **two** FKs that share the `bridgeRowId` column — a direct FK to `Bridges(id)` (via `references()`) and a composite FK to `Scenes(id, bridgeRowId)` (via `customConstraints`). The composite FK transitively guarantees `bridgeRowId` references a valid bridge (since `Scenes.bridgeRowId` is itself FK-constrained), so the direct FK is technically redundant. It is **kept intentionally** as defense-in-depth: SQLite enforces both, and a future schema change that decouples `Scenes.bridgeRowId` would not silently weaken the binding-to-bridge invariant.

Migration strategy: schema versioning via Drift’s migration helpers. v0.1 ships with version 1; future versions add migrations forward only.

## Bridge credentials file

Bridge secrets live outside the Drift database, in `files/no_backup/bridge_credentials.json`. The directory is excluded from Android Backup by being under `no_backup/` (Android’s convention).

File schema:

```json
{
  "version": 1,
  "bridges": {
    "<bridgeId>": {
      "applicationKey": "...",
      "certFingerprintSha256": "..."
    }
  }
}
```

The `secrets` module exposes:

- `loadAllCredentials() -> Map<String, BridgeCredentials>`
- `loadCredentials(bridgeId) -> BridgeCredentials?`
- `storeCredentials(bridgeId, credentials)`
- `removeCredentials(bridgeId)`

All file operations are atomic (write to temp file, fsync, rename). Concurrent access is serialized via a single in-process lock.

**Startup and recovery:**

App startup runs this sequence:

1. Open Drift database.
2. Call `loadAllCredentials()` from the secrets module. If the file is missing, treat as empty map (fresh install or post-restore).
3. Read all `Bridges` rows.
4. For each bridge row, look up its credentials by `bridgeId`:
   - **Both present:** register a `BridgeClient` for it with pinning armed. Normal operation.
   - **Bridge row but no credentials** (e.g. user restored a backup that included the database but not the no-backup file): mark the bridge as “Re-pair needed” in [Manage bridges](flows.md#manage-bridges); do not register a `BridgeClient`. Any tap to a binding on this bridge surfaces “\<bridge name\> needs re-pairing” with an action that opens [Bridge re-pair](flows.md#bridge-re-pair) scoped to it. The [Manage bridges](flows.md#manage-bridges) banner offers “Re-pair all” when ≥1 such bridges exist.
   - **Credentials but no bridge row** (corrupted state, e.g. partial write recovery): orphaned credentials entry; remove it via `removeCredentials(bridgeId)`.
5. If zero `Bridges` rows exist after this sequence, route to [Onboarding](flows.md#onboarding).

This recovery path is best-effort: cross-storage atomicity between Drift and the JSON file is not guaranteed during a process kill mid-write, but inconsistencies are detected and surfaced to the user on next launch rather than silently corrupting state.

## NFC intent routing

Using nfc_manager:

- **Foreground binding mode:** `NfcManager.instance.startSession(...)` with explicit user-triggered session start. Writes the NDEF URI, then re-reads the same tag within the session and verifies the payload before closing the session.
- **Foreground wipe mode:** Same session pattern; reads the tag’s URI first to confirm it matches the card being revoked/deleted; on match, writes a single empty NDEF record (one record with `TNF_EMPTY` and no payload), then verifies by readback. On mismatch, refuses the wipe with the message specified in [Card management](flows.md#card-management).

**Background firing intent filters on `MainActivity`:**

```xml
<!-- Custom scheme; works in both placeholder and production phases -->
<intent-filter>
  <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <data android:scheme="huetap" android:host="c"/>
</intent-filter>

<!-- HTTPS App Link; added in production phase, kept thereafter -->
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="https"
        android:host="<production-domain>"
        android:pathPrefix="/c/"/>
</intent-filter>
```

**Intent priority and conflict resolution:**

- **During foreground binding sessions** (`enableForegroundDispatch` or nfc_manager session), HueTap takes priority over any background dispatch — this is Android NFC’s built-in behavior.
- **For background dispatch on `huetap://`**, no other app on the user’s device is expected to register this scheme; ambiguity is unlikely.
- **For background dispatch on `https://<production-domain>/c/`**, App Links with `autoVerify="true"` and a valid `assetlinks.json` (see [App Links and web fallback](#app-links-and-web-fallback)) claim the domain at install time, bypassing the chooser entirely.

**MainActivity flags:** declared `singleTop`, with `android:showWhenLocked="true"` so background NDEF dispatch fires the activity over the lock screen on Android 8.1+. The activity also calls `setShowWhenLocked(true)` programmatically for older OEM behavior.

## App Links and web fallback

In the placeholder phase, custom URI scheme is sufficient. Production phase requires:

1. Domain ownership confirmed.
2. `assetlinks.json` hosted at `https://<domain>/.well-known/assetlinks.json`, declaring the app’s package name and signing certificate SHA-256.
3. Static install landing page hosted at `https://<domain>/c/*` (catches all card UUIDs).
4. Landing page content: brief explainer (“This card was set up to control smart lights. Install the app to use it.”), Play Store link, GitHub Releases link.
5. Privacy policy hosted at `https://<domain>/privacy` (rendered from `PRIVACY.md`), used as the Play Store privacy policy URL.

Hosting: Cloudflare Pages or any static host. No backend.

## Theme

The app uses the Twilight Hearth design system in dark mode only:

- **Primary colors:** charcoal `#2D2926` (background), dusty plum `#7A5E80` (accents), soft lilac `#C8A0C8` (highlights).
- **Typography:** Nunito (regular, bold, semibold) loaded from Google Fonts via the google_fonts package.
- **Iconography:** Google Material Symbols Outlined exclusively, loaded as a font from material_symbols_icons.
- **No emoji anywhere in the UI.**
- **Aesthetic:** Warm, organic, fantasy-adventure rather than sci-fi. Rounded corners (12dp default), soft shadows, gentle transitions.

System dark/light setting is ignored. Twilight Hearth is always applied. Accessibility tradeoff acknowledged: users who require light mode for sun glare or photophobia may find the app difficult; this may also attract critical Play Store reviews from users expecting respect of system theme. Post-v0.1 will revisit with a light variant if issue volume warrants it.

## Permissions

AndroidManifest.xml declares:

```xml
<uses-permission android:name="android.permission.NFC"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-feature android:name="android.hardware.nfc" android:required="true"/>
```

`ACCESS_NETWORK_STATE` is used to detect “no connectivity” vs “wrong network” failure modes for snackbar messaging. No wifi-state permission, no location permission.

## Crash reporting

- **Provider:** Sentry SaaS, free tier (5,000 events/month).
- **DSN:** Configured at build time via `-dart-define=SENTRY_DSN=...`. Empty DSN disables Sentry entirely (used in debug builds and by users who prefer to build from source without it).
- **Opt-in:** Disabled by default. Enabled via the privacy opt-in screen on first launch and toggleable in settings.
- **Configuration:**
	- `sendDefaultPii: false`
	- `attachStacktrace: true`
	- `attachScreenshot: false`
	- `enableAutoSessionTracking: false`
	- **HTTP integrations not registered.** The dio integration (`SentryDioExtension`) is deliberately not added; this is what suppresses HTTP breadcrumbs at the source.
	- `maxBreadcrumbs: 20` — global cap. The absent dio integration prevents HTTP crumbs from consuming that budget in the first place; `beforeBreadcrumb` is the fallback if a transitive dependency adds them.
	- **`beforeBreadcrumb` hook:** drops any crumb where `category == "http"` as a belt-and-braces fallback in case a transitive integration adds one.
- **`beforeSend` hook:** strips matching substrings from any remaining string fields and breadcrumbs, replaces exception `value` with the exception class name only (e.g. `DioException`, `TimeoutException`, `CertificateMismatchException`). Regex set:

	False positives (e.g. dotted version strings caught by the IPv4 regex) are accepted because over-stripping is the safer side for privacy.

	- **IPv4 with optional port:** `/\b\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?\b/`
	- **IPv6:** `/\b(?:[0-9a-f]{1,4}:){2,7}[0-9a-f]{1,4}\b/i`
	- **UUID:** `/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i`
	- **URLs:** `/https?:\/\/[^\s]+/`
- **Captured data after scrubbing:** stack trace frames, exception class, device model, Android version, app version. No URLs, no IPs, no UUIDs, no scene names, no card labels, no bridge names.

## Auto-backup

Android Backup Service is enabled in the manifest:

```xml
<application
  android:allowBackup="true"
  android:fullBackupContent="@xml/backup_rules"
  android:dataExtractionRules="@xml/data_extraction_rules">
```

**Both XML files have identical content for v0.1.** `backup_rules.xml` covers Auto Backup (Android 6 through 11) and `data_extraction_rules.xml` covers Auto Backup + Device-to-Device transfer (Android 12+); since the app’s targetSdk is 34+, D2D transfers go through `data_extraction_rules`. Keeping the rule sets identical avoids divergence as the targetSdk is bumped over time.

Layout on device:

```plain text
files/
  huetap.db                     ← BACKED UP (Bridges metadata, Scenes, CardBindings, TapLogs, Settings)
  no_backup/
    bridge_credentials.json     ← NOT BACKED UP (application keys + cert fingerprints, by Android convention)
```

Both XML files include `files/huetap.db` and exclude `files/no_backup/`.

Effect on restore: a new device pulls the backup, has all bindings, scenes, and the tap log for every previously paired bridge, but no application keys. On first launch after restore, every `Bridges` row is in “Re-pair needed” state (per [Bridge credentials file](#bridge-credentials-file) startup recovery). The [Manage bridges](flows.md#manage-bridges) banner surfaces “N bridges need re-pairing” with the “Re-pair all” walkthrough; same-bridge re-pair preserves bindings, new-bridge re-pair deletes them.
