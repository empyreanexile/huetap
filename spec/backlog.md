# Backlog and open questions

## Post-v0.1 backlog

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

## Open questions

These are deferred decisions, not blocking v0.1:

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
