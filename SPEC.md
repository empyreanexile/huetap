# HueTap — Requirements Specification v1.4

**Status:** Draft, locked for v1.0 release

**Platform:** Android only

**License:** MIT

**Repository:** New, fresh history (URL pending)

**Domain:** Placeholder, to be assigned (custom URI scheme until real domain is registered)

---

## Changelog from v1.3

**Critical fixes:**

- **§6.1** — NTAG support text rewritten: NTAG213/215/216 are all supported; “smaller” referred to NTAG210/212 with insufficient capacity.
- **§5.6 / §6.5** — URI scheme behaviour clarified: production-phase APKs register intent filters for **both** `huetap://c/<uuid>` and `https://<domain>/c/<uuid>` simultaneously. Old-format tags keep working forever; new tags use the HTTPS form.
- **§5.6 step 7** — Error handling split by status code. **HTTP 404 triggers an immediate sync of that bridge and surfaces the orphaned-scene snackbar (no retry).** 5xx returns “Bridge error, retry?” Network/timeout returns “Bridge unreachable, retry?”
- **§4.3 / §5.6** — In-flight tap gate moved from **global** to **per-bridge**. A slow fire on bridge A no longer drops a tap on bridge B.

**High-severity:**

- **§6.3** — Direct and composite FKs on `CardBindings` clarified as intentional defense-in-depth, with explanation of the transitive guarantee.
- **§5.5** — Card UUID uniqueness note: `CardBindings.uuid` is the primary key; SQLite enforces uniqueness; UUID v4 collision is statistically negligible.
- **§5.6 / §5.9** — `RepairInProgress` flag added; taps during an active re-pair flow are dropped with a snackbar (“Re-pair in progress — finish or cancel first”) instead of recursing into another re-pair.

**Medium-severity:**

- **§5.3 / §5.4** — When a per-bridge sync fails *and* the local cache is empty for that bridge, the scene picker shows an empty state: “Couldn’t load scenes from \<bridge name\>. Retry.”
- **§5.9** — New-bridge re-pair confirmation dialog reworded: “All card bindings and cached scenes for the old bridge will be deleted.”
- **§5.11** — Bridge-removal confirmation dialog now mentions that physical NFC tags retain their old URIs and can be re-bound to scenes on other bridges.
- **§5.11** — **“Re-pair all” banner + sequential walkthrough** added: when ≥1 bridges are in “Re-pair needed” state, a banner appears with a button that walks the user through each one in turn, with progress (“Bridge 2 of 3”) and graceful cancellation.
- **§6.10** — `backup_rules.xml` and `data_extraction_rules.xml` have identical content for v1; explicit note added.

**Low-severity / clarifications:**

- **§5.5** — Default bridge in the binding picker: bridge of the most recently created `CardBinding`; alphabetically-first by name as fallback when no bindings exist.
- **§5.7** — “Wipe tag” affordance now reads the tag’s URI in the same NFC session and **refuses to wipe** if the URI doesn’t match the card being revoked/deleted, with the message “This tag belongs to a different card.”
- **§5.8** — Tap log pruning specified: separate `DELETE FROM tap_logs WHERE id NOT IN (SELECT id FROM tap_logs ORDER BY id DESC LIMIT 100)` after each insert; failure tolerated until next successful prune.
- **§5.11** — Status badge logic specified (priority: Re-pair needed \> Unreachable \> Reachable; “Unreachable” = no successful HTTP in 5+ minutes or last attempt was a network failure; pull-to-refresh triggers a `GET /api/0/config` per bridge).
- **§5.12** — Per-bridge `isSyncing` + `pendingResync` flags added so a re-sync trigger fired during an in-progress sync isn’t lost.
- **§6.5** — NFC intent priority note: foreground dispatch wins during binding sessions; for HTTPS phase, App Links `autoVerify` + `assetlinks.json` claims the domain ahead of any app chooser.
- **§6.7** — Forced dark mode: added one-line caveat about possible Play Store review impact.
- **§6.9** — IP regex broadened to handle IPv4 with optional port and IPv6 (`/\b\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?\b/` and `/\b(?:[0-9a-f]{1,4}:){2,7}[0-9a-f]{1,4}\b/i`). False positives on version strings accepted as the safer side.
- **§3.2** — F-Droid exclusion reason rewritten: “Reproducible builds and signing handover add release pipeline complexity not justified for v1.”
- **Build plan** — Original v1.2 baseline was 8 weeks; v1.3 stretched to 9; v1.4 holds at 9 (the bulk re-pair UI fits within Phase 5).

---

## 1. Product Overview

### 1.1 What HueTap Is

HueTap is an Android app that lets a user trigger pre-configured Philips Hue scenes by tapping NTAG215 NFC cards placed around their home. The cards are the only way to fire scenes from the app; the app’s user interface exists only for setup, configuration, and debugging.

The product is local-only: the app talks directly to each paired Hue Bridge over the local network using the CLIP v2 API. There is no backend service, no user accounts, no cloud sync, and no remote-access capability. The app works only when the phone is on the same network as the bridge a card is bound to.

### 1.2 What HueTap Is Not

HueTap is not a general-purpose Hue controller. It does not let users dim lights, change colors, configure scenes, or manage rooms — those tasks belong in the official Hue app. HueTap consumes scenes that the user has already created elsewhere and exposes them as physical tap targets.

HueTap is not a smart home automation platform. It controls Hue scenes only. It does not support webhooks, action chains, scheduled actions, or integrations with other services in v1.0.

### 1.3 Core Design Philosophy

**Tap to act.** The card is the entire user interface during normal operation. Once configured, the user never opens the app to fire a scene.

**Local-first by necessity, not by ideology.** Cloud Hue access requires OAuth, registered developer credentials, and ongoing maintenance. Local-only is dramatically simpler and the LAN trip is faster than a cloud round-trip.

**Strict failure modes.** When a binding’s bridge is unreachable, the bound scene has been deleted, or the cert pin no longer validates, the app refuses the action and surfaces the error. No silent fallbacks, no queued retries, no last-known-state guesses.

**Revoked is not a failure.** A revoked card opens the binding screen on tap so the user can re-bind it. Same for tags whose URI exists but isn’t bound on this install.

**No per-card auth in v1.** Cards are physical objects; if an attacker has your card, they can fire your scene. The threat model is “single home, casual physical access” — turning lights on and off is low-stakes. Anything more is a v1.x problem.

**TOFU, not full PKI.** Each bridge presents a self-signed cert; on first pair, we trust and pin its fingerprint. Subsequent connections to that bridge validate against the pin; mismatches fail loudly. Re-pair is the only way to update the pin, and re-pair simply trusts whatever cert the bridge presents at that moment — no comparison, no warning.

**Multi-bridge as a first-class home reality.** Real Hue homes often have multiple bridges (one per floor, indoor + outdoor, etc.). Each card binding carries its own bridge reference; tap firing routes to the correct bridge transparently and independently — bridges do not block each other.

**Production quality, single-user expectations.** The spec is written for a polished open-source release with real users, but the product itself is scoped to a single home with one or more bridges. No multi-tenancy concerns, no quota systems, no payment infrastructure.

### 1.4 Positioning

HueTap is a personal tool released as open source. It is not a commercial product and has no paid tier. The expected user is a Hue owner with a few NFC stickers who wants physical triggers for routines they already use.

---

## 2. Target User

A single primary persona: a Philips Hue owner with an Android phone, basic comfort with installing apps from GitHub or Play Store, and willingness to write NFC tags using the in-app flow. Users are expected to already have configured Hue scenes in the official app. The app accommodates owners of one bridge as well as those with multiple bridges in the same home.

International availability is unrestricted, but English is the only language at launch. Internationalization scaffolding is in place for community-contributed translations.

---

## 3. Scope Summary

### 3.1 In Scope for v1.0

| Capability | Notes |
| --- | --- |
| Bridge pairing (multiple) | mDNS discovery, link-button exchange, TOFU cert capture; first bridge in onboarding, additional from settings |
| Bridge management | List, rename, re-pair, remove (per-bridge); detect already-paired bridges; bulk re-pair walkthrough |
| Scene listing | Synced per-bridge; grouped by room and zone within each bridge; searchable |
| NFC card binding | Write UUID v4 to blank tag, bind to a scene on a chosen bridge with a label |
| NFC tap firing | Background reads, scene recall via local API to the binding’s bridge, haptic + toast feedback |
| Card management | Revoke, delete (both with optional verified tag wipe), update bound scene, edit label |
| Tap log | Persistent, last 100 entries across all bridges, timestamp + scene + bridge name + result |
| Settings | Bridge management, privacy preferences |
| Crash reporting | Sentry SaaS, opt-in on first launch, aggressive scrubbing |
| Auto-backup | Android Backup Service for bindings + settings only (bridge credentials excluded) |
| Docs | README, SPEC.md, NFC card buying guide, troubleshooting guide |

### 3.2 Out of Scope for v1.0

| Capability | Reason for exclusion |
| --- | --- |
| iOS support | Defer; Android-only for first release |
| Webhooks | Single-feature focus; HueTap fires scenes only |
| Action chains | Single-feature focus |
| Cloud / remote-access | Substantial complexity; not needed for at-home use |
| In-app scene firing | Cards are the only intended trigger |
| Home screen widgets | Same reason |
| Per-card PIN protection | Threat model doesn’t justify the UX cost in v1; revisit if real users ask |
| Biometric auth | Out of scope alongside PIN |
| Cert change detection / warnings | TOFU only; re-pair to re-pin |
| F-Droid distribution | Reproducible builds and signing handover add release pipeline complexity not justified for v1 |
| Multiple user accounts | Single-user device assumption |
| Tap-aware automations (e.g. event stream subscriptions) | Out of v1 |
| Cross-bridge scene picker grouping | Scenes are bridge-local; binding flow picks bridge first |

---

## 4. Architecture

### 4.1 Stack

| Layer | Choice |
| --- | --- |
| UI framework | Flutter (latest stable; targetSdk 34+) |
| State management | Riverpod (pin to a specific 3.x minor in `pubspec.yaml`; document chosen version in CONTRIBUTING) |
| Local storage | Drift (SQLite) |
| HTTP client | dio with custom cert pinning interceptor (one instance per bridge, registered in `BridgeClientRegistry`) |
| NFC | nfc_manager |
| Crash reporting | sentry_flutter (Sentry SaaS) |
| Discovery | multicast_dns for mDNS |
| Localization | flutter_localizations + intl |

No cryptography dependency in v1: cert fingerprinting uses Dart’s built-in SHA-256.

### 4.2 Code Organization

The project follows clean-architecture conventions: `data/` (DTOs, API clients, Drift DAOs), `domain/` (typed entities, use cases), `presentation/` (widgets, providers). Riverpod providers live in `presentation/providers/` per feature.

```plain text
lib/
  core/
    theme/             — Twilight Hearth tokens
    errors/            — typed failure types
    db/                — Drift database setup, migrations
    net/               — BridgeClientRegistry, per-bridge dio + TOFU pinning interceptor
    secrets/           — no_backup credentials file (load, store, remove)
  features/
    onboarding/        — welcome, privacy opt-in, first-bridge pairing, first-card tutorial
    bridges/           — discovery, pairing, manage list, rename, re-pair, remove, bulk re-pair walkthrough
    scenes/            — per-bridge sync, picker, room+zone grouping, search
    cards/             — bind, revoke, delete (+ optional verified tag wipe), label, update scene
    nfc/               — read/write/wipe, intent handling, URI parsing
    log/               — tap history view, write helpers
    settings/          — bridge list entry point, privacy toggles
  l10n/                — ARB files, generated localizations
  main.dart
```

### 4.3 Data Flow

```plain text
NFC tap (background)
      ↓
Android intent → MainActivity (singleTop, showWhenLocked) → deep link handler
      ↓
Parse URI → extract UUID → look up CardBinding in Drift
      ↓
   ┌──── if RepairInProgress flag is set → snackbar "Re-pair in progress" + drop
   ├──── if missing → open binding screen with UUID pre-filled (Entry B, §5.5)
   ├──── if revoked → open binding screen, treat as blank
   ├──── if scene orphaned → snackbar with "Update binding" action; do not fire
   │
   ├──── fetch Bridge row by binding.bridgeRowId; load credentials from no-backup file
   ├──── obtain BridgeClient from registry (creates on first use, with cert pin armed)
   ├──── if per-bridge in-flight gate is set for THIS bridge → drop tap silently
   │           ↓
   │     TLS handshake; pinning interceptor verifies presented cert's
   │     SHA-256 against stored fingerprint → mismatch = hard fail,
   │     snackbar offers "Re-pair <bridge name>"
   │           ↓
   │     PUT /clip/v2/resource/scene/{uuid} with {"recall":{"action":"active"}}
   │           ↓
   │     handle response → success: haptic + toast + log success + update Bridges.lastReachable
   │                       failure: status-code-specific snackbar + log error
   │           ↓
   └──── trigger background scene re-sync for THIS bridge (debounced)
```

The in-flight gate is **per-bridge**. Independent bridges fire independently; a slow bridge does not block others. Within a single bridge, a second tap arriving while the first is in flight is dropped silently with a debug log entry.

---

## 5. Feature Requirements

### 5.1 Onboarding

First launch presents four sequential screens:

1. **Welcome.** Brief description of what HueTap does, single “Continue” button.
2. **Privacy opt-in.** Plain-language summary: no data collected; optional anonymous crash reports via Sentry. Two buttons: “Enable crash reports” (default) and “Skip.” Toggle revealed in settings later.
3. **Pair your first bridge.** Discovery flow described in §5.2. Cannot proceed until at least one bridge is paired. Additional bridges are added later from §5.11.
4. **First card tutorial.** Walks the user through binding their first card. Skippable.

After completion, the user lands on the cards list (empty if they skipped the tutorial).

### 5.2 Bridge Pairing

The pairing flow runs during onboarding (first bridge) and from §5.11 (subsequent bridges). The flow is identical:

1. App displays a “Looking for your Hue Bridge…” screen.
2. App performs mDNS discovery using multicast_dns, listening for `_hue._tcp` services on the local network.
3. Discovery results are presented as a list. **Already-paired bridges are shown disabled with the label “Already paired”** (matched by bridge ID once known; until then, by IP). If none are found after 30 seconds, show “No bridge found” with retry and “Enter IP manually” affordances.
4. User picks a bridge (or types an IP). User is then prompted to press the physical link button on the top of the bridge.
5. App polls `POST https://<bridge-ip>/api` with a `devicetype` payload until the bridge returns an application key. Polling occurs every 2 seconds for up to 60 seconds. **During pairing, the per-bridge pinning interceptor runs in TOFU mode** — it accepts any cert the bridge presents and exposes the SHA-256 fingerprint to the caller.
6. On success, fetch `GET /api/0/config` (still in TOFU mode) to obtain the bridge ID and name.
7. **Already-paired check by bridge ID:** if a `Bridges` row already exists with this `bridgeId`, abort with “This bridge is already paired” and route the user to that bridge’s row in §5.11. (This catches the case where the user added the bridge by IP without realizing it was already paired.)
8. Insert a row in `Bridges` (auto-incremented id, ip, bridgeId, name, pairedAt). Write the application key and SHA-256 cert fingerprint to `files/no_backup/bridge_credentials.json` keyed by bridge ID.
9. Register a new `BridgeClient` in the `BridgeClientRegistry` for this bridge, with the pinning interceptor armed against the captured fingerprint.
10. Run an immediate scene sync (§5.3) for the new bridge.
11. Success screen with the bridge name and a “Continue” button.

### 5.3 Scene Sync

The app maintains a local cache of scenes in the Drift database, scoped per bridge.

- **Triggers:**
	- **App launch:** all bridges sync in parallel. Failures are tolerated and logged per-bridge.
	- **After a successful scene fire:** the binding’s bridge syncs (debounced; see §5.12).
	- **After bridge pair or re-pair:** that bridge syncs immediately, awaited by the calling flow.
	- **After a 404 from a scene-fire PUT:** the responsible bridge syncs immediately (synchronously) so the orphaned-scene state is reflected before the snackbar appears (§5.6 step 7).
- **Endpoints (per-bridge):** `GET /clip/v2/resource/scene`, `GET /clip/v2/resource/room`, and `GET /clip/v2/resource/zone`, all with the `hue-application-key` header.
- **Reconciliation, in a single Drift transaction per bridge:**
	- Scenes returned by the bridge are upserted with the bridge’s `bridgeRowId`. Upsert overwrites `name`, `roomId`, `roomName`, `zoneId`, `zoneName` from the bridge response. **If the bridge omits a field (e.g. scene removed from a room), the local field is set to NULL.**
	- Scenes in the local cache for this `bridgeRowId` that no longer exist on the bridge are marked `orphaned = true`.
	- **Orphan sweep:** scenes with `orphaned = true` for this `bridgeRowId` that have zero `CardBinding` references are deleted in the same transaction.
- **Failure with non-empty cache:** the existing cache is left untouched; an error is logged but not surfaced.
- **Failure with empty cache:** the scene picker for that bridge shows an empty state: “Couldn’t load scenes from \<bridge name\>. Retry.” with a retry action that re-runs the sync. The binding flow blocks at the picker step until either a successful sync or the user backs out.

### 5.4 Scene Picker

The picker is shown during card binding (after the bridge picker, if needed) and during “update scene” on an existing card. The picker is always scoped to a single bridge — the bridge picked in the binding flow, or the binding’s existing bridge for “update scene.”

- **Layout:** A search bar at the top, then collapsible sections grouped by room and zone for that bridge. A scene assigned to a zone but no room appears under the zone; one assigned to a room but no zone appears under the room; one assigned to both appears under both (listed once per group).
- **Empty sections:** Hidden.
- **Scenes assigned to neither a room nor a zone:** Hidden. Documented in `docs/troubleshooting.md` as “if your scene doesn’t appear, assign it to a room or zone in the Hue app.”
- **Search:** Filters across all sections of this bridge; matches scene name, room name, and zone name. Results displayed flat (no grouping) when search is non-empty.
- **Orphaned scenes:** Not shown.
- **Empty cache + sync failure:** rendered as an empty state with a retry button (see §5.3).

### 5.5 NFC Card Binding

Two entry points share the same downstream UI:

**Entry A — “Add card” from the cards list (blank tag flow):**

1. User opens the cards list and taps “Add card.”
2. The app prompts: “Hold a blank NFC tag to your phone.”
3. App enters foreground NFC read mode using nfc_manager.
4. When a tag is detected:
	- **Tag has a HueTap URI matching a binding in this install:** prompt: “This card is already bound to ‘\<label\>’ on ‘\<bridge name\>’. Rebind?” If user confirms, generate a new UUID, write it to the tag (with verify-readback), then **delete the old `CardBinding` row** as part of the same Drift transaction that inserts the new one. Proceed to step 5.
	- **Tag has a HueTap URI but no matching binding in this install** (e.g. backup-less reinstall, lent card, second device): prompt: “This card has a HueTap URI but isn’t bound on this device. Bind it now?” If user confirms, **reuse the existing UUID** and proceed to step 5 without writing the tag again.
	- **Tag has data from another app or unreadable data:** prompt: “This tag isn’t blank. Overwrite it?”
	- **Tag is blank or confirmed for overwrite:** generate a new UUID v4 and write it as an NDEF URI record, then **read back and verify the write byte-for-byte**. On mismatch, retry once. On second mismatch, abort with “Couldn’t write the tag. Try again with a fresh tap.” **Failure model:** if both write attempts succeed but readback fails both times, the tag may now contain the new UUID with no corresponding binding row. The error message instructs the user to re-tap the card; that re-tap falls through to Entry B.
5. **Bridge picker (only when ≥2 bridges are paired):** “Which bridge should this card use?” Sorted by bridge name. Auto-skipped when exactly one bridge exists. **Default selection:** the bridge of the most recently created `CardBinding` row (any time, all-time). If no bindings exist, the alphabetically-first bridge by name.
6. User picks a scene from the picker (§5.4), scoped to the selected bridge.
7. User enters a label (free-text, required, max 60 chars). Default suggestion is the scene name.
8. Card is saved to the database (linked to the chosen `bridgeRowId`), success haptic + toast.

**UUID uniqueness:** `CardBindings.uuid` is the primary key; SQLite enforces uniqueness at insert time. UUID v4 collision is statistically negligible (\~1 in 5×10³⁶); no preflight check is needed.

**Entry B — Tap on a card whose URI exists but isn’t bound, or whose binding is revoked (covered in §5.6 step 2):**

Jumps directly to the bridge picker (step 5) with the UUID pre-filled from the tag. No re-tap, no UUID regeneration, no tag rewrite. **If a `CardBinding` row already exists for this UUID with `revoked = true`, step 8 UPDATES that row** (clearing `revoked`, setting new `bridgeRowId`, `sceneId`, and `label`; resetting `tapCount` and `lastTapped` to NULL) instead of inserting.

### 5.6 NFC Tap Behavior (Firing)

- **Trigger:** Background NFC read of an NDEF URI matching a registered HueTap scheme. Two schemes are accepted concurrently in the production phase: `huetap://c/<uuid>` (placeholder phase, kept forever for backward compatibility with existing tags) and `https://<production-domain>/c/<uuid>` (HTTPS App Link). Both are extracted to the same UUID.
- **Activity:** Single-task, `singleTop` launch mode so taps don’t stack instances. The activity declares `android:showWhenLocked="true"` and calls `setShowWhenLocked(true)` so taps fire from the lock screen without requiring unlock. Intent filter declares `android.nfc.action.NDEF_DISCOVERED` for the custom scheme and a separate App Links filter for the HTTPS scheme (§6.5).
- **Concurrency, per-bridge:** each bridge has its own in-flight gate. If a fire is already in flight for that bridge (in the window between PUT-sent and response-handled), incoming taps **on that same bridge** are dropped silently with a debug log entry. Taps on other bridges proceed in parallel.
- **Concurrency, re-pair:** if the global `RepairInProgress` flag is set (i.e. the user is in §5.9), taps are dropped with a snackbar: “Re-pair in progress — finish or cancel first.”
- **Flow:**
	1. Parse URI, extract UUID.
	2. Look up `CardBinding` by UUID. If missing, open binding screen (§5.5 Entry B) with the UUID pre-filled. If `revoked = true`, treat as missing (same flow).
	3. If the binding’s scene is `orphaned`, show snackbar: “This card’s scene was deleted in the Hue app. Update binding?” with action button. Tapping the action opens the same scene picker as §5.7’s “Update scene,” scoped to the binding’s bridge. Do not fire.
	4. Fetch the binding’s bridge row + credentials. Obtain the `BridgeClient` for this bridge from the registry. If the bridge has no credentials (Re-pair needed), show snackbar “\<bridge name\> needs re-pairing” with action that opens §5.9 scoped to this bridge. If the bridge is unreachable (no LAN, wrong network, bridge offline), show snackbar “\<bridge name\> unreachable. Check your wifi.” with retry button. Log the failure.
	5. PUT to `/clip/v2/resource/scene/{uuid}` with `{"recall":{"action":"active"}}`. The pinning interceptor validates the presented cert’s SHA-256 against the stored fingerprint during the TLS handshake; mismatch raises `CertificateMismatchException`, surfaced as snackbar “\<bridge name\> identity changed. Re-pair?” with an action that opens §5.9 scoped to this bridge.
	6. **On success:** vibrate (medium impact), show toast “
		activated”, write log entry (with `bridgeRowId`), update `Bridges.lastReachable`, schedule background scene re-sync (§5.12) for this bridge.
	7. **On failure, branched by status code:**
		- **404** (scene not found on bridge — deleted between last sync and now): trigger an immediate synchronous sync of this bridge (§5.3), then show the orphaned-scene snackbar from step 3 with “Update binding” action. **No retry button.**
		- **5xx** (bridge internal error): snackbar “\<bridge name\> error. Retry?” with retry action. Log entry.
		- **Network / timeout / connection-refused:** snackbar “\<bridge name\> unreachable. Retry?” with retry action. Log entry.
		- **Other 4xx (excluding 401/403):** snackbar “\<bridge name\> rejected the request” with no retry. Log entry with the status code in `errorMessage`.
	8. **On 401/403:** trigger re-pair flow (§5.9) auto-scoped to this bridge, show snackbar, do not retry automatically.

### 5.7 Card Management Screen

The cards list shows every binding regardless of bridge. Each row displays the card label, the scene name, and (when ≥2 bridges are paired) the bridge name as a subtitle. Tapping a card opens its detail screen with the following actions:

- **Update scene** — opens scene picker scoped to the binding’s bridge, replaces the bound scene.
- **Edit label** — inline rename.
- **Revoke** — sets `revoked = true`. Card behaves identically to a blank tag on next tap (the user can re-bind it). Confirmation dialog explains this and offers an optional **“Wipe tag now”** checkbox: if checked and the user taps the card during the confirmation window (foreground NFC session opens), the tag’s URI is read first; if it matches the card being revoked, the NDEF record is overwritten with an empty record. **If the URI doesn’t match (e.g. user tapped the wrong card), refuse with “This tag belongs to a different card. Use that card’s screen to wipe it.”** If the user dismisses the dialog without tapping, only the binding is revoked.
- **Delete** — removes the binding row entirely (no soft state). Confirmation dialog with the same optional **“Wipe tag now”** checkbox and the same URI-verification behavior. If the deleted scene now has zero references and is orphaned, it is also deleted (covered by §5.3’s orphan sweep on next sync).

The “Wipe tag” affordance is best-effort — it requires the user to tap the correct card while the dialog is open. If they don’t, no harm done; the card retains its URI and on next tap falls through to Entry B (treat as unknown URI).

### 5.8 Tap Log

A scrollable list view, **newest-first by default, toggleable to oldest-first**, showing:

- Timestamp (relative for last 24h, absolute for older)
- Card label
- Scene name
- Bridge name (when ≥2 bridges are paired)
- Result (success / error type)
- Optional error message for failures

Rolling buffer of the last 100 entries across all bridges. Pruning runs as a separate query after each insert:

```sql
DELETE FROM tap_logs WHERE id NOT IN (
  SELECT id FROM tap_logs ORDER BY id DESC LIMIT 100
);
```

Pruning by `id` (autoincrement) gives a stable insertion-order policy that doesn’t depend on system clock. If pruning fails, the insert is **not rolled back** — the log temporarily exceeds 100 entries until the next successful prune.

No filtering or search in v1 — small enough to scroll.

### 5.9 Bridge Re-pair Flow

Triggered when a request to a bridge returns 401 or 403, when its pinning interceptor raises `CertificateMismatchException`, when the user manually selects “Re-pair” on a bridge in §5.11, or when the user invokes “Re-pair all” from the bulk re-pair walkthrough (§5.11).

**Re-pair is modal.** While a re-pair flow is active, the global `RepairInProgress` flag is set. Background NFC taps received during this window are dropped with a snackbar (see §5.6).

**Bridge selection:**

- Error-triggered re-pair is auto-scoped: the failing `BridgeClient` knows its bridge.
- Manual re-pair from §5.11 is invoked on a specific bridge row.
- Bulk re-pair walkthrough invokes the flow once per bridge sequentially.

The re-pair runs the same discovery + link-button polling as initial pairing (§5.2). The pinning interceptor for the target bridge is switched to TOFU mode for the duration of the re-pair flow. After a new application key is obtained, the app fetches `GET /api/0/config` and compares the returned bridge ID against the stored bridge ID for the target bridge. There is exactly one branch decision:

**Same bridge (bridge ID matches):**

In a single Drift transaction:

1. Update the application key and the SHA-256 cert fingerprint in `files/no_backup/bridge_credentials.json` for that bridge ID. Whatever cert was presented is now the new pin — no comparison, no warning.
2. Update `Bridges` row metadata (ip if changed, name if changed, `lastReachable = now`).
3. Existing `CardBindings` and `Scenes` rows for this `bridgeRowId` are preserved.

After the transaction, re-arm the `BridgeClient` for this bridge with the new fingerprint.

**New bridge (bridge ID differs):**

The user has replaced the physical bridge. In a single Drift transaction:

1. Confirmation dialog: “This is a different bridge than before. **All card bindings and cached scenes for the old bridge will be deleted.** Cards can be re-bound to the new bridge afterward. Continue?”
2. On confirmation:
   - Delete all `CardBindings` rows where `bridgeRowId = <old bridge row id>`.
   - Delete all `Scenes` rows where `bridgeRowId = <old bridge row id>`.
   - Delete the old `Bridges` row.
   - Insert a new `Bridges` row (auto-incremented id, new bridgeId, ip, name, pairedAt, lastReachable = now).
3. In `files/no_backup/bridge_credentials.json`, remove the old bridge ID’s entry and write a new entry under the new bridge ID with the captured application key and cert fingerprint.
4. Register a new `BridgeClient` in the registry; remove the old one.
5. **Await scene sync** (§5.3) for the new bridge with a loading indicator before dismissing the success dialog.

After either branch, clear the `RepairInProgress` flag.

Physical tags from the old bridge still hold their old URIs. On next tap, they fall through to §5.5 Entry B (URI present, no matching binding) and the user can re-bind them to scenes on the new bridge.

### 5.10 Network Change During Tap

If the phone is on a non-home network when a tap occurs, the binding’s bridge is unreachable. The snackbar message reads: “\<bridge name\> unreachable. Check your wifi.” with a “Retry” action. No background retries — the user is in front of the card, they can tap again.

### 5.11 Manage Bridges

Accessed from the settings root. Layout:

- **“Re-pair needed” banner** (only when ≥1 bridges are in “Re-pair needed” state). Text: “N bridges need re-pairing.” Action: **“Re-pair all”** button. Tapping starts a sequential walkthrough:
	1. Picks the first re-pair-needed bridge in display order.
	2. Opens §5.9 re-pair flow scoped to it. Header shows “Bridge K of N” progress.
	3. On success, advances to the next re-pair-needed bridge.
	4. On user cancel within a sub-flow, exits the walkthrough; remaining bridges keep their “Re-pair needed” state. The banner updates to reflect the new count.
	5. On completion (all re-paired), dismisses the banner and shows toast “All bridges re-paired.”
	6. If a re-pair fails (e.g. link button not pressed in time), surfaces the failure for that bridge and offers “Skip” (continue walkthrough) or “Cancel” (exit walkthrough).
- **Bridge list** — one row per paired bridge, showing:
	- Bridge name (editable inline)
	- IP address
	- Status badge (see logic below)
	- Number of cards bound to this bridge
- **Per-bridge actions** (overflow menu on each row):
	- **Re-pair** — opens §5.9 scoped to this bridge.
	- **Remove** — confirmation dialog: “Remove ‘\<bridge name\>’? This deletes \<N\> card bindings and \<M\> cached scenes for this bridge. **Physical NFC tags retain their old URIs and can be re-bound to scenes on other bridges by tapping them.**” On confirmation, delete the bridge row, its credentials entry, all `CardBindings` and `Scenes` rows for its `bridgeRowId`, and unregister its `BridgeClient`. If this was the last bridge, the user is routed back to the §5.2 pairing flow (post-onboarding state).
- **“Add another bridge”** button at the bottom — opens §5.2.

**Pull-to-refresh** on the bridge list triggers a `GET /api/0/config` per bridge (in parallel) to refresh status badges. No background polling.

**Status badge logic (priority order):**

1. **“Re-pair needed”** (red) — credentials missing for this bridge ID in the no-backup file.
2. **“Unreachable”** (yellow) — `lastReachable` was more than 5 minutes ago, *or* the most recent activity (any HTTP attempt) failed with a network error.
3. **“Reachable”** (green) — otherwise.

### 5.12 Background Scene Re-sync

Triggered after a successful scene fire (§5.6 step 6). Implementation, per bridge:

- Each bridge has two flags in its Riverpod provider state: `isSyncing` (bool) and `pendingResync` (bool).
- A 5-second debounced `Timer` per bridge.
- On trigger:
	- If `isSyncing == false`: restart the timer. When the timer fires, set `isSyncing = true`, clear `pendingResync`, run the sync, set `isSyncing = false` on completion.
	- If `isSyncing == true`: set `pendingResync = true` (no timer change).
- After a sync completes, if `pendingResync == true`: reset the flag and start a fresh 5-second timer. This guarantees no trigger is lost during an in-progress sync.
- Failed syncs are logged but not retried; the next fire restarts the cycle.

Not WorkManager — overkill for v1.

---

## 6. Technical Specifications

### 6.1 NFC Card Format

- **Tag types supported:** NTAG213 (137 bytes usable), NTAG215 (504 bytes), NTAG216 (888 bytes). NTAG215 is recommended. Smaller variants (NTAG210/212) lack capacity for the URI plus NDEF framing and are not supported.
- **NDEF record:** Single URI record. Format depends on phase:
	- **Placeholder phase** (no domain): `huetap://c/<uuid>` where `<uuid>` is a UUID v4.
	- **Production phase** (post-domain): `https://<domain>/c/<uuid>` with the same UUID format. Tags written in the placeholder phase keep working forever — the production-phase APK registers intent filters for both schemes (§6.5).
- **Read access:** Public. There is no per-card secret on the tag.
- **Write protection:** Cards are not locked after writing. v1 does not write-protect tags; users may overwrite them with other tools or with HueTap’s “Wipe tag” affordance (§5.7).
- **Write verification:** After writing, the tag is read back in the same NFC session and the URI is compared byte-for-byte. Mismatch triggers one retry.
- **Wipe verification:** Same session pattern; before writing the empty record, the tag’s existing URI is read and confirmed to match the card being revoked/deleted. Mismatch refuses the wipe (§5.7).

### 6.2 Bridge Communication

- **Discovery:** mDNS lookup for `_hue._tcp.local`. Falls back to manual IP entry if no service is found.
- **`BridgeClient` registry:** A central registry holds one `BridgeClient` per paired bridge. Each `BridgeClient` wraps a dedicated dio instance with its own pinning interceptor armed to that bridge’s stored fingerprint. Clients are created lazily on first use after app launch and re-created on re-pair. Removing a bridge unregisters its client. Each client also owns its bridge’s per-bridge in-flight gate (§5.6).
- **Cert handling — TOFU only:** Each `BridgeClient`’s pinning interceptor operates in two modes. In **TOFU mode** (during pairing and re-pair for that bridge), it accepts any cert and exposes the captured SHA-256 fingerprint to the caller. In **armed mode** (all other times), it validates the presented cert’s SHA-256 against that bridge’s stored fingerprint during the TLS handshake; mismatch raises `CertificateMismatchException` and the request is aborted before any HTTP body is sent. There is no comparison, warning, or “is this a new cert?” UX — re-pair simply re-captures whatever the bridge presents and overwrites the stored fingerprint for that bridge.
- **Auth:** `hue-application-key` HTTP header on all v2 endpoints, sourced from that bridge’s credentials entry.
- **Endpoints used (per bridge):**
	- `GET /api/0/config` — fetch bridge ID and name (during pairing, re-pair, and pull-to-refresh in §5.11)
	- `GET /clip/v2/resource/scene` — list scenes
	- `GET /clip/v2/resource/room` — list rooms
	- `GET /clip/v2/resource/zone` — list zones
	- `PUT /clip/v2/resource/scene/{id}` with `{"recall":{"action":"active"}}` — fire scene
	- `POST /api` (v1 endpoint, used only during pairing) — exchange link-button press for application key
- **Timeout:** 3 seconds for scene-fire requests. 10 seconds for sync requests. 60 seconds for pairing.
- **`Bridges.lastReachable`:** updated on every successful HTTP response from that bridge, regardless of endpoint.

### 6.3 Local Database Schema (Drift)

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

Migration strategy: schema versioning via Drift’s migration helpers. v1.0 ships with version 1; future versions add migrations forward only.

### 6.4 Bridge Credentials File

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
   - **Bridge row but no credentials** (e.g. user restored a backup that included the database but not the no-backup file): mark the bridge as “Re-pair needed” in §5.11; do not register a `BridgeClient`. Any tap to a binding on this bridge surfaces “\<bridge name\> needs re-pairing” with an action that opens §5.9 scoped to it. The §5.11 banner offers “Re-pair all” when ≥1 such bridges exist.
   - **Credentials but no bridge row** (corrupted state, e.g. partial write recovery): orphaned credentials entry; remove it via `removeCredentials(bridgeId)`.
5. If zero `Bridges` rows exist after this sequence, route to §5.1 onboarding.

This recovery path is best-effort: cross-storage atomicity between Drift and the JSON file is not guaranteed during a process kill mid-write, but inconsistencies are detected and surfaced to the user on next launch rather than silently corrupting state.

### 6.5 NFC Read/Write/Wipe and Intent Routing

Using nfc_manager:

- **Foreground binding mode:** `NfcManager.instance.startSession(...)` with explicit user-triggered session start. Writes the NDEF URI, then re-reads the same tag within the session and verifies the payload before closing the session.
- **Foreground wipe mode:** Same session pattern; reads the tag’s URI first to confirm it matches the card being revoked/deleted; on match, writes a single empty NDEF record (one record with `TNF_EMPTY` and no payload), then verifies by readback. On mismatch, refuses the wipe with the message specified in §5.7.

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
- **For background dispatch on `https://<production-domain>/c/`**, App Links with `autoVerify="true"` and a valid `assetlinks.json` (§6.6) claim the domain at install time, bypassing the chooser entirely.

**MainActivity flags:** declared `singleTop`, with `android:showWhenLocked="true"` so background NDEF dispatch fires the activity over the lock screen on Android 8.1+. The activity also calls `setShowWhenLocked(true)` programmatically for older OEM behavior.

### 6.6 App Links and Web Fallback

In the placeholder phase, custom URI scheme is sufficient. Production phase requires:

1. Domain ownership confirmed.
2. `assetlinks.json` hosted at `https://<domain>/.well-known/assetlinks.json`, declaring the app’s package name and signing certificate SHA-256.
3. Static install landing page hosted at `https://<domain>/c/*` (catches all card UUIDs).
4. Landing page content: brief explainer (“This card was set up to control smart lights. Install the app to use it.”), Play Store link, GitHub Releases link.
5. Privacy policy hosted at `https://<domain>/privacy` (rendered from `PRIVACY.md`), used as the Play Store privacy policy URL.

Hosting: Cloudflare Pages or any static host. No backend.

### 6.7 Theme

The app uses the Twilight Hearth design system in dark mode only:

- **Primary colors:** charcoal `#2D2926` (background), dusty plum `#7A5E80` (accents), soft lilac `#C8A0C8` (highlights).
- **Typography:** Nunito (regular, bold, semibold) loaded from Google Fonts via the google_fonts package.
- **Iconography:** Google Material Symbols Outlined exclusively, loaded as a font from material_symbols_icons.
- **No emoji anywhere in the UI.**
- **Aesthetic:** Warm, organic, fantasy-adventure rather than sci-fi. Rounded corners (12dp default), soft shadows, gentle transitions.

System dark/light setting is ignored. Twilight Hearth is always applied. Accessibility tradeoff acknowledged: users who require light mode for sun glare or photophobia may find the app difficult; this may also attract critical Play Store reviews from users expecting respect of system theme. v1.x will revisit with a light variant if issue volume warrants it.

### 6.8 Permissions

AndroidManifest.xml declares:

```xml
<uses-permission android:name="android.permission.NFC"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-feature android:name="android.hardware.nfc" android:required="true"/>
```

`ACCESS_NETWORK_STATE` is used to detect “no connectivity” vs “wrong network” failure modes for snackbar messaging. No wifi-state permission, no location permission.

### 6.9 Crash Reporting

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

### 6.10 Auto-Backup

Android Backup Service is enabled in the manifest:

```xml
<application
  android:allowBackup="true"
  android:fullBackupContent="@xml/backup_rules"
  android:dataExtractionRules="@xml/data_extraction_rules">
```

**Both XML files have identical content for v1.** `backup_rules.xml` covers Auto Backup (Android 6 through 11) and `data_extraction_rules.xml` covers Auto Backup + Device-to-Device transfer (Android 12+); since the app’s targetSdk is 34+, D2D transfers go through `data_extraction_rules`. Keeping the rule sets identical avoids divergence as the targetSdk is bumped over time.

Layout on device:

```plain text
files/
  huetap.db                     ← BACKED UP (Bridges metadata, Scenes, CardBindings, TapLogs, Settings)
  no_backup/
    bridge_credentials.json     ← NOT BACKED UP (application keys + cert fingerprints, by Android convention)
```

Both XML files include `files/huetap.db` and exclude `files/no_backup/`.

Effect on restore: a new device pulls the backup, has all bindings, scenes, and the tap log for every previously paired bridge, but no application keys. On first launch after restore, every `Bridges` row is in “Re-pair needed” state (per §6.4 startup recovery). The §5.11 banner surfaces “N bridges need re-pairing” with the “Re-pair all” walkthrough; same-bridge re-pair preserves bindings, new-bridge re-pair deletes them.

---

## 7. Quality and Testing

### 7.1 Test Coverage Targets

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

### 7.2 Mocked Bridge Fixture

A test fixture (`test/fixtures/mock_bridge.dart`) implements a minimal HTTP server matching the CLIP v2 API surface used by the app:

- `GET /api/0/config` returns a configurable bridge ID
- `GET /clip/v2/resource/scene` returns a configurable list
- `GET /clip/v2/resource/room` returns a configurable list
- `GET /clip/v2/resource/zone` returns a configurable list
- `PUT /clip/v2/resource/scene/{id}` with valid recall returns 200; configurable to return 404, 401, 403, 500, or hang past the timeout
- Configurable cert mismatch and bridge-ID change scenarios
- Self-signed cert generated at fixture setup, fingerprint exposed for pinning tests; alternate certs exposed for mismatch tests
- The fixture can be instantiated multiple times with distinct ports and certs to test multi-bridge scenarios.

### 7.3 CI Pipeline

GitHub Actions workflow `ci.yml`:

- **On every PR and push to main:**
	- `flutter analyze` (must pass with no warnings)
	- `flutter test` (must pass)
	- `dart format --output=none --set-exit-if-changed .`
- **On tag push (semver tag like `v1.0.0`):**
	- All of the above
	- `flutter build apk --release --split-per-abi` for arm64-v8a, armeabi-v7a, x86_64
	- Sign APKs using a release signing keystore stored as a GitHub Actions secret
	- Upload signed APKs as artifacts to a GitHub Release
	- Generate SHA-256 checksums alongside

A separate workflow handles Play Store uploads via fastlane, manually triggered to avoid accidental publishes.

---

## 8. Distribution

### 8.1 GitHub Releases

Primary distribution for technical users. Each release includes:

- Three APKs (one per ABI), signed with the release signing keystore
- SHA-256 checksums
- Release notes
- Source tarball (auto-generated)

Users sideload by enabling “Install from unknown sources” and installing the APK matching their device’s ABI.

### 8.2 Play Store

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

### 8.3 Versioning

Semantic versioning. v1.0.0 is the first public release. Patch versions (v1.0.x) for bugfixes. Minor versions (v1.x.0) for feature additions that don’t break the spec. Major versions (vx.0.0) for breaking changes.

`pubspec.yaml` version field uses Flutter’s `<semver>+<build_number>` format. Build number is monotonically increasing for Play Store.

---

## 9. Documentation

### 9.1 Repository Documents

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

### 9.2 In-App Help

The settings screen includes a “Help” section with links to the docs above (opens in browser). No in-app help content is embedded; the docs are the source of truth.

### 9.3 Issue Templates

GitHub issue templates for:

- Bug report (with required fields: device model, Android version, app version, bridge model, number of bridges paired, reproduction steps)
- Feature request (with required fields: use case, proposed behavior)
- Documentation issue
- Question

Labels: `bug`, `enhancement`, `documentation`, `question`, `good first issue`, `wontfix`, `duplicate`.

Triage commitment: respond to new issues within one week. Issues without responses for 30 days may be auto-labeled `stale` and closed after another 30 days without activity.

---

## 10. Privacy and Security

### 10.1 Data Collection

The app collects no telemetry by default. With explicit user consent, the app sends crash reports to Sentry SaaS containing only stack trace frames, exception class name, device model, Android version, and app version. URLs, IPs (v4 and v6, with optional ports), UUIDs, scene names, card labels, and bridge names are stripped by an explicit `beforeSend` hook before transmission (§6.9).

### 10.2 Data Storage

All app data is stored locally on the device:

- Drift database in app-private storage (Bridges metadata, Scenes, CardBindings, TapLogs, Settings)
- Bridge credentials (per-bridge application key + cert fingerprint) in app-private `files/no_backup/bridge_credentials.json`, excluded from Android Backup
- shared_preferences in app-private storage

No data is transmitted off-device except scrubbed crash reports (when enabled) and Hue API calls (which stay on the LAN).

### 10.3 Security Considerations

- **NFC card cloning:** NTAG215 cards have writable UIDs on some clones. The app does not rely on UID for security; the URI on the card is the only identity. A cloned card with the same URI behaves identically — by design, this enables backup cards.
- **No card-level auth:** PIN protection is intentionally out of v1 scope. Threat model: physical access to a card lets the holder fire a Hue scene. This is judged acceptable for v1 because Hue scenes turn lights on and off; nothing more.
- **TOFU cert pinning, per bridge:** each bridge presents a self-signed cert; we trust it on first pair, pin its fingerprint, and validate every subsequent connection to that bridge against its pin. Mismatches hard-fail. Re-pair is the only way to update a pin and simply re-captures whatever cert the bridge currently presents — no warnings, no comparison.
- **Application key storage:** stored per-bridge in app-private `files/no_backup/`. An attacker with root access could extract them; this is accepted for v1.0 as the threat model is “single-user device, casual physical access.”
- **Backup security:** Android Backup Service encrypts backups with a key tied to the user’s lock screen credential. Bindings, scenes, and tap log are backed up; bridge credentials are not, so a restored install on a new device always re-pairs every bridge.
- **Tag wipe is best-effort and verified:** the optional “Wipe tag” affordance on Revoke and Delete only fires if the user taps the correct card during the confirmation dialog. The app reads the tag’s URI first and refuses to wipe a card that doesn’t match.

### 10.4 Privacy Policy Content

The PRIVACY.md document covers:

- What data the app collects (scrubbed crash reports only, optional)
- What data the app stores locally (bindings, scenes, log)
- What data the app transmits (Hue API calls on LAN, optional Sentry crash reports with explicit scrubbing)
- What data the app does not collect (no analytics, no advertising IDs, no location)
- The exact `beforeSend` scrubbing rules (so the user can audit them in source)
- User rights (delete app to delete all data; toggle crash reporting in settings)
- Contact (GitHub issues)

---

## 11. Localization

### 11.1 Approach

The app uses Flutter’s standard localization stack: `flutter_localizations`, `intl`, ARB files in `lib/l10n/`.

All user-facing strings are externalized via `AppLocalizations.of(context).<key>`. No hardcoded English strings outside of the ARB files. Strings that interpolate bridge names, card labels, or scene names use ICU placeholders.

### 11.2 Languages at Launch

English (`en`) only. The ARB infrastructure is in place so contributors can add languages by submitting new ARB files via PR.

### 11.3 Translation Workflow

A `docs/i18n.md` document explains how to contribute translations:

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<locale>.arb`
2. Translate all values, leaving keys and `@@locale` metadata
3. Submit a PR

Translations go through standard PR review. Maintainer reviews translations only for completeness and obvious technical errors, not for linguistic quality.

---

## 12. Build Plan

Original v1.2 baseline was 8 weeks; v1.3 stretched to 9 weeks for multi-bridge work; v1.4 holds at 9 weeks (the bulk re-pair walkthrough fits within Phase 5).

### Phase 1 — Foundations (Week 1–2)

- Project setup: Flutter init, Riverpod scaffolding, Drift schema (with composite Scenes PK and bridgeRowId FKs), theme application, l10n scaffolding.
- Sentry integration with disabled-by-default DSN, `beforeSend` scrubber (IPv4 + IPv6 + UUID + URL regexes), `beforeBreadcrumb` filter, no dio integration.
- Onboarding flow shells (welcome, privacy opt-in screens).
- CI pipeline: lint, test, format checks on PR.
- Repository docs: README skeleton, SPEC.md, LICENSE, basic CONTRIBUTING.

**Acceptance:** App builds, runs, shows onboarding screens. CI green on a sample PR.

### Phase 2 — Bridge Pairing & Multi-Bridge Plumbing (Week 2–4)

- mDNS bridge discovery with already-paired filtering.
- Manual IP entry fallback.
- Link-button polling and key exchange.
- Bridge ID fetched and stored; uniqueness enforced.
- TOFU cert capture; per-bridge `BridgeClient` with pinning interceptor (TOFU + armed modes) and per-bridge in-flight gate.
- `BridgeClientRegistry` lifecycle (create on pair, re-create on re-pair, remove on bridge removal).
- `no_backup/bridge_credentials.json` read/write with atomic file ops; multi-bridge map structure.
- Bridge re-pair flow with same-bridge / new-bridge branching, FK-scoped deletion, per-bridge auto-scoping for error-triggered re-pair, `RepairInProgress` flag.
- §5.11 Manage Bridges screen: list, rename, re-pair, remove, add another, status badges with the priority logic, pull-to-refresh.
- Startup recovery sequence (§6.4): handle missing credentials, orphaned credentials.
- Settings root with bridge management entry point.
- Unit tests for the API client; integration tests against a mocked bridge fixture including bridge-ID change, cert mismatch, already-paired detection, status badge transitions, and multi-bridge scenarios.

**Acceptance:** App pairs with a real Hue Bridge end-to-end. Adding a second bridge works. Removing a bridge cleans up correctly. Both re-pair branches work. Cert mismatch surfaces correctly and re-pair re-captures. Slow bridge A does not block fires on bridge B.

### Phase 3 — Scenes (Week 4–5)

- Per-bridge scene sync (parallel on launch).
- Room and zone sync for grouping.
- Scene picker with grouping and search, scoped to a single bridge.
- Hide-no-room-or-zone behavior.
- Empty-cache + sync-failure empty state with retry.
- Orphaned-scene detection + orphan sweep.
- Drift migrations confirmed working across builds.

**Acceptance:** App displays scenes correctly grouped by room and zone, scoped to the chosen bridge. Picker is usable on a real bridge with 50+ scenes. Multi-bridge sync works in parallel. Empty cache + failure surfaces the retry empty state.

### Phase 4 — Cards and NFC (Week 5–7)

- NFC binding flow: blank tag detection, UUID generation, NDEF write, write-verification with retry, double-failure tag state.
- Bridge picker step (auto-skipped when one bridge), default-bridge selection logic.
- Rebind flow with old-row deletion.
- Unknown-URI tag handling (Entry B in §5.5), including UPDATE path for revoked bindings.
- Card label entry.
- Card list (cross-bridge) and detail screens (with bridge name subtitle).
- “Wipe tag” affordance on Revoke and Delete with URI-verify-then-wipe.
- Background NFC intent handling: both `huetap://` and (in production phase) `https://<domain>/c/` filters; lock-screen behavior (`showWhenLocked`).
- Per-bridge in-flight gate for tap firing.
- Tap firing logic with status-code-branched error handling (404 → sync + orphan snackbar, 5xx → retry, network → retry, other 4xx → reject).
- Tap log persistence and viewer with bridge column; pruning by id.
- “First card tutorial” in onboarding.

**Acceptance:** End-to-end flow works: pair bridge → bind card → tap card → scene fires (including from lock screen). With two bridges paired, binding a card surfaces the bridge picker, and the tap fires the correct bridge. Tap log records all attempts with bridge attribution. Rapid double-taps on the same bridge don’t double-fire; rapid taps across two bridges fire both. Rebinding deletes the old row. Wipe-on-delete refuses on URI mismatch.

### Phase 5 — Hardening & Bulk Re-pair (Week 7–8)

- Card revoke and delete flows with verified wipe.
- Orphaned-scene banner; “Update binding” routes to scene picker.
- Background scene re-sync (§5.12) per-bridge debouncing with `isSyncing` + `pendingResync` flag handling.
- Full error handling pass: bridge unreachable (per-bridge messaging), scene deleted (404 path), cert mismatch, 3s timeout, bridge 5xx.
- §5.11 “Re-pair all” banner + sequential walkthrough.
- Re-pair-in-progress tap-drop snackbar.
- Sentry scrubbing tests with synthetic events containing IPv4/IPv6/UUIDs/bridge names.
- Multi-bridge edge cases: removing the only bridge routes to onboarding; removing a non-active bridge cascades; restoring a backup with multiple bridges surfaces all as “re-pair needed” and the bulk walkthrough completes them.

**Acceptance:** All failure modes from §5 are handled correctly. Sentry test events show no leaked identifiers post-scrubbing. Bulk re-pair walkthrough completes a 3-bridge restore end-to-end.

### Phase 6 — Polish and Release (Week 8–9)

- Twilight Hearth refinement: animations, micro-interactions, snackbar styling.
- Android Backup Service tested end-to-end with both single-bridge and two-bridge configurations.
- Documentation pass: setup guide (single- and multi-bridge sections), NFC card guide, troubleshooting guide.
- Privacy policy finalized; production domain hosting set up (Cloudflare Pages with `/privacy` and `/c/*` routes; `assetlinks.json` published).
- Play Store assets: icon (placeholder), screenshots, descriptions, Data Safety declaration.
- Release signing keystore generated and stored as GitHub Actions secret.
- Tag-triggered build pipeline tested.
- Beta installation on personal device for two weeks of dogfooding, including: lock-screen taps, rapid double-taps on one bridge and across two bridges, network-loss recovery, intentional bridge re-pair, deliberate scene deletion to exercise the 404 path.

**Acceptance:** v1.0.0 tag produces a signed, installable APK. Play Store listing is ready (may publish after beta).

---

## 13. Success Criteria

v1.0 is considered complete when:

- The user can pair their first bridge in under two minutes from a fresh install.
- The user can add a second bridge from settings in under one minute.
- The user can bind a card to a scene in under one minute (one extra step in the multi-bridge case).
- A background tap on a bound card meets these latency targets:
	- **Warm-start, p50:** tap detection to PUT request dispatched within **200 ms**; PUT round-trip within typical LAN latency (200–500 ms).
	- **Warm-start, p95:** tap detection to PUT dispatched within **500 ms**.
	- **Cold-start:** adds **800–1500 ms** of Android activity-launch overhead; this is tolerated.
- Rapid consecutive taps on the same card never produce double-fires.
- Rapid consecutive taps across two bridges fire both bridges in parallel.
- Lock-screen taps fire reliably without requiring unlock.
- With two bridges paired, a tap on a card bound to bridge A fires bridge A even when bridge B is offline or slow.
- A scene deleted on the bridge between syncs surfaces the orphaned-scene snackbar within one tap (404 path), without retry prompting.
- All scope items in §3.1 are implemented and tested.
- Documentation in §9 is published and reviewed by at least one external reader (a friend, not the author).
- The app is installed on the author’s phone and used as the primary Hue trigger for at least two weeks before public release.

---

## 14. Post-v1 Backlog

Captured here for future planning, not committed:

- iOS support (requires NDEF strategy alignment and Apple’s NFC entitlement work)
- Per-card PIN protection if real users request it
- Webhooks as a second action type
- Action chains (sequence of scenes + delays + webhooks)
- Hue v2 event stream subscriptions for state-aware automations (e.g. “fire only if living room lights are off”)
- Cloud / remote-access via Hue’s OAuth API
- Home screen widget for in-app fallback firing
- F-Droid distribution with reproducible builds
- Wear OS companion for tap-from-watch firing
- Move bridge credentials from `no_backup/` flat file into Android Keystore-backed encrypted storage for stronger at-rest security
- Light variant of Twilight Hearth for accessibility
- Tap log export (CSV, JSON)
- Cross-bridge scene picker grouping (e.g. “all ‘Movie Night’ scenes across bridges”)
- Default-bridge preference in settings (for binding flow when there are many bridges)
- Background bridge health polling (today only on app foreground or pull-to-refresh)
- Tap-time retry queue for transient failures (today, errors require re-tap)

---

## Appendix A — Glossary

| Term | Definition |
| --- | --- |
| Bridge | The Philips Hue Bridge hardware that controls all Hue lights on a network |
| Bridge ID | The unique identifier returned by `GET /api/0/config`, used to detect bridge replacement on re-pair, key the credentials file, and prevent duplicate pairing |
| BridgeClient | The per-bridge dio instance + pinning interceptor + in-flight gate, registered in `BridgeClientRegistry` |
| Scene | A pre-configured set of light states (color, brightness, on/off) targeting one or more lights, created in the Hue app |
| Application key | An alphanumeric token (\~40 chars on current bridge firmware) issued by the Hue Bridge to authenticate API requests |
| Card | A physical NTAG NFC sticker registered with HueTap |
| Binding | The association between a card UUID and a scene on a specific bridge, with a label |
| Room | A Hue grouping primitive for lights physically in the same room |
| Zone | A Hue grouping primitive for lights grouped logically (e.g. “Downstairs”, “Outdoor”) rather than by room |
| TOFU | Trust on First Use; pinning a self-signed cert at first connection and validating against it thereafter. Re-pair re-captures the cert without comparison or warning. |
| CLIP v2 | Hue’s modern REST API, served at `/clip/v2/` on the bridge |
| Twilight Hearth | The visual design system: charcoal, plum, lilac palette with Nunito and Material Symbols |
| Orphaned binding | A card whose bound scene no longer exists on its bridge |
| Orphaned scene | A scene marked `orphaned = true` in the local cache. Pruned during sync if zero bindings reference it. |
| Revoked card | A binding flagged as inactive; behaves as a blank tag on tap and can be re-bound (UPDATE in place) |
| Wipe tag | Optional verified overwrite of the tag’s NDEF record with an empty record, offered during Revoke and Delete confirmations; refuses on URI mismatch |
| RepairInProgress | A global flag set while §5.9 is active; taps during this window are dropped with a snackbar to prevent recursive re-pair |
| In-flight gate | Per-bridge guard preventing a second fire to the same bridge while one is in flight |

---

## Appendix B — Open Questions for v1.x

These are deferred decisions, not blocking v1.0:

- Should the tap log be exportable (CSV, JSON)?
- Should the app expose a “fire test” button on the card detail screen for debugging?
- Should the orphaned-scene banner be dismissible until the scene set changes?
- Should Sentry crash reports include a hash of a Hue Bridge ID for cross-device correlation, or strictly nothing?
- Should the app re-introduce per-card PIN protection if multiple users request it?
- Should the app offer a light theme variant?
- Should a “default bridge” preference be added to settings to streamline binding when many bridges are paired?
- Should removing the last bridge route to onboarding, or to an empty “Add a bridge” landing page within the main app shell?
- Should bridge status badges update via background polling rather than requiring foreground or pull-to-refresh?
- Should transient failures be retried via a tap-time queue rather than requiring a fresh user tap?

These will be answered as the product is used in real conditions.
