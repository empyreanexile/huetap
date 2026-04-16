# User flows

> This file describes the v0.1 design contract. See the project README for current implementation status.

## Onboarding

First launch presents four sequential screens:

1. **Welcome.** Brief description of what HueTap does, single “Continue” button.
2. **Privacy opt-in.** Plain-language summary: no data collected; optional anonymous crash reports via Sentry. Two buttons: “Enable crash reports” (default) and “Skip.” Toggle revealed in settings later.
3. **Pair your first bridge.** Discovery flow described in [Bridge pairing](#bridge-pairing). Cannot proceed until at least one bridge is paired. Additional bridges are added later from [Manage bridges](#manage-bridges).
4. **First card tutorial.** Walks the user through binding their first card. Skippable.

After completion, the user lands on the cards list (empty if they skipped the tutorial).

## Bridge pairing

The pairing flow runs during onboarding (first bridge) and from [Manage bridges](#manage-bridges) (subsequent bridges). The flow is identical:

1. App displays a “Looking for your Hue Bridge…” screen.
2. App performs mDNS discovery using multicast_dns, listening for `_hue._tcp` services on the local network. mDNS relies on link-local multicast; some routers (especially with AP/client isolation enabled) block it between wireless clients. Manual IP entry is the fallback.
3. Discovery results are presented as a list. **Already-paired bridges are shown disabled with the label “Already paired”** (matched by bridge ID once known; until then, by IP). If none are found after 30 seconds, show “No bridge found” with retry and “Enter IP manually” affordances.
4. User picks a bridge (or types an IP). User is then prompted to press the physical link button on the top of the bridge.
5. App polls `POST https://<bridge-ip>/api` with a `devicetype` payload until the bridge returns an application key. Polling occurs every 2 seconds for up to 60 seconds. **During pairing, the per-bridge pinning interceptor runs in TOFU mode** — it accepts any cert the bridge presents and exposes the SHA-256 fingerprint to the caller.
6. On success, fetch `GET /api/0/config` (still in TOFU mode) to obtain the bridge ID and name.
7. **Already-paired check by bridge ID:** if a `Bridges` row already exists with this `bridgeId`, abort with “This bridge is already paired” and route the user to that bridge’s row in [Manage bridges](#manage-bridges). (This catches the case where the user added the bridge by IP without realizing it was already paired.)
8. Insert a row in `Bridges` (auto-incremented id, ip, bridgeId, name, pairedAt). Write the application key and SHA-256 cert fingerprint to `files/no_backup/bridge_credentials.json` keyed by bridge ID.
9. Register a new `BridgeClient` in the `BridgeClientRegistry` for this bridge, with the pinning interceptor armed against the captured fingerprint.
10. Run an immediate scene sync ([Scene sync](#scene-sync)) for the new bridge.
11. Success screen with the bridge name and a “Continue” button.

## Scene sync

The app maintains a local cache of scenes in the Drift database, scoped per bridge.

- **Triggers:**
	- **App launch:** all bridges sync in parallel. Failures are tolerated and logged per-bridge.
	- **After a successful scene fire:** the binding’s bridge syncs (debounced; see [Background scene re-sync](#background-scene-re-sync)).
	- **After bridge pair or re-pair:** that bridge syncs immediately, awaited by the calling flow.
	- **After a 404 from a scene-fire PUT:** the responsible bridge syncs immediately (synchronously) so the orphaned-scene state is reflected before the snackbar appears ([NFC tap behavior](#nfc-tap-behavior)).
- **Endpoints (per-bridge):** `GET /clip/v2/resource/scene`, `GET /clip/v2/resource/room`, and `GET /clip/v2/resource/zone`, all with the `hue-application-key` header.
- **Reconciliation, in a single Drift transaction per bridge:**
	- Scenes returned by the bridge are upserted with the bridge’s `bridgeRowId`. Upsert overwrites `name`, `roomId`, `roomName`, `zoneId`, `zoneName` from the bridge response. **If the bridge omits a field (e.g. scene removed from a room), the local field is set to NULL.**
	- Scenes in the local cache for this `bridgeRowId` that no longer exist on the bridge are marked `orphaned = true`.
	- **Orphan sweep:** scenes with `orphaned = true` for this `bridgeRowId` that have zero `CardBinding` references are deleted in the same transaction.
- **Failure with non-empty cache:** the existing cache is left untouched; an error is logged but not surfaced.
- **Failure with empty cache:** the scene picker for that bridge shows an empty state: “Couldn’t load scenes from \<bridge name\>. Retry.” with a retry action that re-runs the sync. The binding flow blocks at the picker step until either a successful sync or the user backs out.

## Scene picker

The picker is shown during card binding (after the bridge picker, if needed) and during “update scene” on an existing card. The picker is always scoped to a single bridge — the bridge picked in the binding flow, or the binding’s existing bridge for “update scene.”

- **Layout:** A search bar at the top, then collapsible sections grouped by room and zone for that bridge. A scene assigned to a zone but no room appears under the zone; one assigned to a room but no zone appears under the room; one assigned to both appears under both (listed once per group).
- **Empty sections:** Hidden.
- **Scenes assigned to neither a room nor a zone:** Hidden. Documented in `docs/troubleshooting.md` as “if your scene doesn’t appear, assign it to a room or zone in the Hue app.”
- **Search:** Filters across all sections of this bridge; matches scene name, room name, and zone name. Results displayed flat (no grouping) when search is non-empty.
- **Orphaned scenes:** Not shown.
- **Empty cache + sync failure:** rendered as an empty state with a retry button (see [Scene sync](#scene-sync)).

## NFC card binding

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
6. User picks a scene from the picker ([Scene picker](#scene-picker)), scoped to the selected bridge.
7. User enters a label (free-text, required, max 60 chars). Default suggestion is the scene name.
8. Card is saved to the database (linked to the chosen `bridgeRowId`), success haptic + toast.

**UUID uniqueness:** `CardBindings.uuid` is the primary key; SQLite enforces uniqueness at insert time. UUID v4 collision is statistically negligible (\~1 in 5×10³⁶); no preflight check is needed.

**Entry B — Tap on a card whose URI exists but isn’t bound, or whose binding is revoked (covered in [NFC tap behavior](#nfc-tap-behavior) step 2):**

Jumps directly to the bridge picker (step 5) with the UUID pre-filled from the tag. No re-tap, no UUID regeneration, no tag rewrite. **If a `CardBinding` row already exists for this UUID with `revoked = true`, step 8 UPDATES that row** (clearing `revoked`, setting new `bridgeRowId`, `sceneId`, and `label`; resetting `tapCount` and `lastTapped` to NULL) instead of inserting.

## NFC tap behavior

- **Trigger:** Background NFC read of an NDEF URI matching a registered HueTap scheme. Two schemes are accepted concurrently in the production phase: `huetap://c/<uuid>` (placeholder phase, kept forever for backward compatibility with existing tags) and `https://<production-domain>/c/<uuid>` (HTTPS App Link). Both are extracted to the same UUID.
- **Activity:** Single-task, `singleTop` launch mode so taps don’t stack instances. The activity declares `android:showWhenLocked="true"` and calls `setShowWhenLocked(true)` to request that the system show the activity over the keyguard. Whether the activity actually appears without an unlock depends on OEM security policy; see troubleshooting. Intent filter declares `android.nfc.action.NDEF_DISCOVERED` for the custom scheme and a separate App Links filter for the HTTPS scheme (see [NFC intent routing](technical.md#nfc-intent-routing)).
- **Concurrency, per-bridge:** each bridge has its own in-flight gate. If a fire is already in flight for that bridge (in the window between PUT-sent and response-handled), incoming taps **on that same bridge** are dropped silently with a debug log entry. Taps on other bridges proceed in parallel.
- **Concurrency, re-pair:** if the global `RepairInProgress` flag is set (i.e. the user is in [Bridge re-pair](#bridge-re-pair)), taps are dropped with a snackbar: “Re-pair in progress — finish or cancel first.”
- **Flow:**
	1. Parse URI, extract UUID.
	2. Look up `CardBinding` by UUID. If missing, open binding screen ([NFC card binding](#nfc-card-binding) Entry B) with the UUID pre-filled. If `revoked = true`, treat as missing (same flow).
	3. If the binding’s scene is `orphaned`, show snackbar: “This card’s scene was deleted in the Hue app. Update binding?” with action button. Tapping the action opens the same scene picker as [Card management](#card-management)’s “Update scene,” scoped to the binding’s bridge. Do not fire.
	4. Fetch the binding’s bridge row + credentials. Obtain the `BridgeClient` for this bridge from the registry. If the bridge has no credentials (Re-pair needed), show snackbar “\<bridge name\> needs re-pairing” with action that opens [Bridge re-pair](#bridge-re-pair) scoped to this bridge. If the bridge is unreachable (no LAN, wrong network, bridge offline), show snackbar “\<bridge name\> unreachable. Check your wifi.” with retry button. Log the failure.
	5. PUT to `/clip/v2/resource/scene/{uuid}` with `{"recall":{"action":"active"}}`. The pinning interceptor validates the presented cert’s SHA-256 against the stored fingerprint during the TLS handshake; mismatch raises `CertificateMismatchException`, surfaced as snackbar “\<bridge name\> identity changed. Re-pair?” with an action that opens [Bridge re-pair](#bridge-re-pair) scoped to this bridge.
	6. **On success:** vibrate (medium impact), show toast “
		activated”, write log entry (with `bridgeRowId`), update `Bridges.lastReachable`, schedule background scene re-sync ([Background scene re-sync](#background-scene-re-sync)) for this bridge. Haptic feedback and toast rendering are subject to OEM launcher and OS policy; both are best-effort.
	7. **On failure, branched by status code:**
		- **404** (scene not found on bridge — deleted between last sync and now): trigger an immediate synchronous sync of this bridge ([Scene sync](#scene-sync)), then show the orphaned-scene snackbar from step 3 with “Update binding” action. **No retry button.**
		- **5xx** (bridge internal error): snackbar “\<bridge name\> error. Retry?” with retry action. Log entry.
		- **Network / timeout / connection-refused:** snackbar “\<bridge name\> unreachable. Retry?” with retry action. Log entry.
		- **Other 4xx (excluding 401/403):** snackbar “\<bridge name\> rejected the request” with no retry. Log entry with the status code in `errorMessage`.
	8. **On 401/403:** trigger re-pair flow ([Bridge re-pair](#bridge-re-pair)) auto-scoped to this bridge, show snackbar, do not retry automatically.

## Card management

The cards list shows every binding regardless of bridge. Each row displays the card label, the scene name, and (when ≥2 bridges are paired) the bridge name as a subtitle. Tapping a card opens its detail screen with the following actions:

- **Update scene** — opens scene picker scoped to the binding’s bridge, replaces the bound scene.
- **Edit label** — inline rename.
- **Revoke** — sets `revoked = true`. Card behaves identically to a blank tag on next tap (the user can re-bind it). Confirmation dialog explains this and offers an optional **“Wipe tag now”** checkbox: if checked and the user taps the card during the confirmation window (foreground NFC session opens), the tag’s URI is read first; if it matches the card being revoked, the NDEF record is overwritten with an empty record. **If the URI doesn’t match (e.g. user tapped the wrong card), refuse with “This tag belongs to a different card. Use that card’s screen to wipe it.”** If the user dismisses the dialog without tapping, only the binding is revoked.
- **Delete** — removes the binding row entirely (no soft state). Confirmation dialog with the same optional **“Wipe tag now”** checkbox and the same URI-verification behavior. If the deleted scene now has zero references and is orphaned, it is also deleted (covered by [Scene sync](#scene-sync)’s orphan sweep on next sync).

The “Wipe tag” affordance is best-effort — it requires the user to tap the correct card while the dialog is open. If they don’t, no harm done; the card retains its URI and on next tap falls through to Entry B (treat as unknown URI).

## Tap log

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

No filtering or search in v0.1 — small enough to scroll.

## Bridge re-pair

Triggered when a request to a bridge returns 401 or 403, when its pinning interceptor raises `CertificateMismatchException`, when the user manually selects “Re-pair” on a bridge in [Manage bridges](#manage-bridges), or when the user invokes “Re-pair all” from the bulk re-pair walkthrough ([Manage bridges](#manage-bridges)).

**Re-pair is modal.** While a re-pair flow is active, the global `RepairInProgress` flag is set. Background NFC taps received during this window are dropped with a snackbar (see [NFC tap behavior](#nfc-tap-behavior)).

**Bridge selection:**

- Error-triggered re-pair is auto-scoped: the failing `BridgeClient` knows its bridge.
- Manual re-pair from [Manage bridges](#manage-bridges) is invoked on a specific bridge row.
- Bulk re-pair walkthrough invokes the flow once per bridge sequentially.

The re-pair runs the same discovery + link-button polling as initial pairing ([Bridge pairing](#bridge-pairing)). The pinning interceptor for the target bridge is switched to TOFU mode for the duration of the re-pair flow. After a new application key is obtained, the app fetches `GET /api/0/config` and compares the returned bridge ID against the stored bridge ID for the target bridge. There is exactly one branch decision:

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
5. **Await scene sync** ([Scene sync](#scene-sync)) for the new bridge with a loading indicator before dismissing the success dialog.

After either branch, clear the `RepairInProgress` flag.

Physical tags from the old bridge still hold their old URIs. On next tap, they fall through to [NFC card binding](#nfc-card-binding) Entry B (URI present, no matching binding) and the user can re-bind them to scenes on the new bridge.

## Network change during tap

If the phone is on a non-home network when a tap occurs, the binding’s bridge is unreachable. The snackbar message reads: “\<bridge name\> unreachable. Check your wifi.” with a “Retry” action. No background retries — the user is in front of the card, they can tap again.

## Manage bridges

Accessed from the settings root. Layout:

- **“Re-pair needed” banner** (only when ≥1 bridges are in “Re-pair needed” state). Text: “N bridges need re-pairing.” Action: **“Re-pair all”** button. Tapping starts a sequential walkthrough:
	1. Picks the first re-pair-needed bridge in display order.
	2. Opens [Bridge re-pair](#bridge-re-pair) flow scoped to it. Header shows “Bridge K of N” progress.
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
	- **Re-pair** — opens [Bridge re-pair](#bridge-re-pair) scoped to this bridge.
	- **Remove** — confirmation dialog: “Remove ‘\<bridge name\>’? This deletes \<N\> card bindings and \<M\> cached scenes for this bridge. **Physical NFC tags retain their old URIs and can be re-bound to scenes on other bridges by tapping them.**” On confirmation, delete the bridge row, its credentials entry, all `CardBindings` and `Scenes` rows for its `bridgeRowId`, and unregister its `BridgeClient`. If this was the last bridge, the user is routed back to the [Bridge pairing](#bridge-pairing) flow (post-onboarding state).
- **“Add another bridge”** button at the bottom — opens [Bridge pairing](#bridge-pairing).

**Pull-to-refresh** on the bridge list triggers a `GET /api/0/config` per bridge (in parallel) to refresh status badges. No background polling.

**Status badge logic (priority order):**

1. **“Re-pair needed”** (red) — credentials missing for this bridge ID in the no-backup file.
2. **“Unreachable”** (yellow) — `lastReachable` was more than 5 minutes ago, *or* the most recent activity (any HTTP attempt) failed with a network error.
3. **“Reachable”** (green) — otherwise.

## Background scene re-sync

Triggered after a successful scene fire ([NFC tap behavior](#nfc-tap-behavior) step 6). Implementation, per bridge:

- Each bridge has two flags in its Riverpod provider state: `isSyncing` (bool) and `pendingResync` (bool).
- A 5-second debounced `Timer` per bridge.
- On trigger:
	- If `isSyncing == false`: restart the timer. When the timer fires, set `isSyncing = true`, clear `pendingResync`, run the sync, set `isSyncing = false` on completion.
	- If `isSyncing == true`: set `pendingResync = true` (no timer change).
- After a sync completes, if `pendingResync == true`: reset the flag and start a fresh 5-second timer. This guarantees no trigger is lost during an in-progress sync.
- Failed syncs are logged but not retried; the next fire restarts the cycle.

Not WorkManager — overkill for v0.1.
