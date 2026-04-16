# Build plan

## Phase 1 — Foundations (Week 1–2)

- Project setup: Flutter init, Riverpod scaffolding, Drift schema (with composite Scenes PK and bridgeRowId FKs), theme application, l10n scaffolding.
- Sentry integration with disabled-by-default DSN, `beforeSend` scrubber (IPv4 + IPv6 + UUID + URL regexes), `beforeBreadcrumb` filter, no dio integration.
- Onboarding flow shells (welcome, privacy opt-in screens).
- CI pipeline: lint, test, format checks on PR.
- Repository docs: README skeleton, SPEC.md, LICENSE, basic CONTRIBUTING.

**Acceptance:** App builds, runs, shows onboarding screens. CI green on a sample PR.

## Phase 2 — Bridge pairing & multi-bridge plumbing (Week 2–4)

- mDNS bridge discovery with already-paired filtering.
- Manual IP entry fallback.
- Link-button polling and key exchange.
- Bridge ID fetched and stored; uniqueness enforced.
- TOFU cert capture; per-bridge `BridgeClient` with pinning interceptor (TOFU + armed modes) and per-bridge in-flight gate.
- `BridgeClientRegistry` lifecycle (create on pair, re-create on re-pair, remove on bridge removal).
- `no_backup/bridge_credentials.json` read/write with atomic file ops; multi-bridge map structure.
- Bridge re-pair flow with same-bridge / new-bridge branching, FK-scoped deletion, per-bridge auto-scoping for error-triggered re-pair, `RepairInProgress` flag.
- [Manage bridges](flows.md#manage-bridges) screen: list, rename, re-pair, remove, add another, status badges with the priority logic, pull-to-refresh.
- Startup recovery sequence (see [Bridge credentials file](technical.md#bridge-credentials-file)): handle missing credentials, orphaned credentials.
- Settings root with bridge management entry point.
- Unit tests for the API client; integration tests against a mocked bridge fixture including bridge-ID change, cert mismatch, already-paired detection, status badge transitions, and multi-bridge scenarios.

**Acceptance:** App pairs with a real Hue Bridge end-to-end. Adding a second bridge works. Removing a bridge cleans up correctly. Both re-pair branches work. Cert mismatch surfaces correctly and re-pair re-captures. Slow bridge A does not block fires on bridge B.

## Phase 3 — Scenes (Week 4–5)

- Per-bridge scene sync (parallel on launch).
- Room and zone sync for grouping.
- Scene picker with grouping and search, scoped to a single bridge.
- Hide-no-room-or-zone behavior.
- Empty-cache + sync-failure empty state with retry.
- Orphaned-scene detection + orphan sweep.
- Drift migrations confirmed working across builds.

**Acceptance:** App displays scenes correctly grouped by room and zone, scoped to the chosen bridge. Picker is usable on a real bridge with 50+ scenes. Multi-bridge sync works in parallel. Empty cache + failure surfaces the retry empty state.

## Phase 4 — Cards and NFC (Week 5–7)

- NFC binding flow: blank tag detection, UUID generation, NDEF write, write-verification with retry, double-failure tag state.
- Bridge picker step (auto-skipped when one bridge), default-bridge selection logic.
- Rebind flow with old-row deletion.
- Unknown-URI tag handling ([NFC card binding](flows.md#nfc-card-binding) Entry B), including UPDATE path for revoked bindings.
- Card label entry.
- Card list (cross-bridge) and detail screens (with bridge name subtitle).
- “Wipe tag” affordance on Revoke and Delete with URI-verify-then-wipe.
- Background NFC intent handling: both `huetap://` and (in production phase) `https://<domain>/c/` filters; lock-screen behavior (`showWhenLocked`).
- Per-bridge in-flight gate for tap firing.
- Tap firing logic with status-code-branched error handling (404 → sync + orphan snackbar, 5xx → retry, network → retry, other 4xx → reject).
- Tap log persistence and viewer with bridge column; pruning by id.
- “First card tutorial” in onboarding.

**Acceptance:** End-to-end flow works: pair bridge → bind card → tap card → scene fires (including from lock screen). With two bridges paired, binding a card surfaces the bridge picker, and the tap fires the correct bridge. Tap log records all attempts with bridge attribution. Rebinding deletes the old row. Wipe-on-delete refuses on URI mismatch.

## Phase 5 — Hardening & bulk re-pair (Week 7–8)

- Card revoke and delete flows with verified wipe.
- Orphaned-scene banner; “Update binding” routes to scene picker.
- Background scene re-sync ([Background scene re-sync](flows.md#background-scene-re-sync)) per-bridge debouncing with `isSyncing` + `pendingResync` flag handling.
- Full error handling pass: bridge unreachable (per-bridge messaging), scene deleted (404 path), cert mismatch, 3s timeout, bridge 5xx.
- [Manage bridges](flows.md#manage-bridges) “Re-pair all” banner + sequential walkthrough.
- Re-pair-in-progress tap-drop snackbar.
- Sentry scrubbing tests with synthetic events containing IPv4/IPv6/UUIDs/bridge names.
- Multi-bridge edge cases: removing the only bridge routes to onboarding; removing a non-active bridge cascades; restoring a backup with multiple bridges surfaces all as “re-pair needed” and the bulk walkthrough completes them.

**Acceptance:** All failure modes from [User flows](flows.md) are handled correctly. Sentry test events show no leaked identifiers post-scrubbing. Bulk re-pair walkthrough completes a 3-bridge restore end-to-end.

## Phase 6 — Polish and release (Week 8–9)

- Twilight Hearth refinement: animations, micro-interactions, snackbar styling.
- Android Backup Service tested end-to-end with both single-bridge and two-bridge configurations.
- Documentation pass: setup guide (single- and multi-bridge sections), NFC card guide, troubleshooting guide.
- Privacy policy finalized; production domain hosting set up (Cloudflare Pages with `/privacy` and `/c/*` routes; `assetlinks.json` published).
- Play Store assets: icon (placeholder), screenshots, descriptions, Data Safety declaration.
- Release signing keystore generated and stored as GitHub Actions secret.
- Tag-triggered build pipeline tested.

**Acceptance:** v0.1.0 tag produces an installable APK. Play Store listing is ready (may publish after beta).
