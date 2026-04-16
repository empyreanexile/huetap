# Glossary

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
| RepairInProgress | A global flag set while the re-pair flow is active; taps during this window are dropped with a snackbar to prevent recursive re-pair |
| In-flight gate | Per-bridge guard preventing a second fire to the same bridge while one is in flight |
