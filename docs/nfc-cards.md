# NFC Cards

> **Stub.** Expand with specific product links and positioning photos once Phase 4 dogfooding completes.

## Supported tag types

HueTap writes a single NDEF URI record. Any NTAG chip with enough capacity works:

| Chip | Usable bytes | Verdict |
|---|---|---|
| **NTAG213** | 137 | Works. Fine for HueTap's short URI. |
| **NTAG215** | 504 | **Recommended.** Plenty of headroom, widely available. |
| **NTAG216** | 888 | Works. Usually more expensive with no benefit for HueTap. |
| NTAG210/212 | 48/128 after framing | **Not supported.** URI + framing doesn't fit reliably. |
| MIFARE Classic | varies | Not supported. Different protocol; HueTap only writes NDEF. |

## Where to buy

NTAG215 cards and stickers are sold in bulk on Amazon, AliExpress, and specialty NFC shops. Quality varies; avoid no-name lots if you plan to use the optional "Wipe tag" feature (flaky writes cause mismatches).

## Positioning

- **Stick cards where people naturally pause** — doorways, bedside tables, light switches, phone chargers.
- Avoid **metal surfaces** — they detune the antenna. Use a foam spacer or an NFC-on-metal tag.
- **Don't stack cards** — adjacent tags can confuse the reader.

## Cloning and backups

NTAG215 cards have a writable UID on some clones. HueTap **does not rely on the UID** — only the URI written to the card. A cloned card with the same URI behaves identically to the original, which means **you can make intentional backup copies** of an important card by scanning it into a second tag with the same URI (using a third-party NFC tool). This is by design; see SPEC §10.3.

## Wipe and rebind

HueTap will overwrite an existing NTAG (with your confirmation) when you re-bind it, and it can wipe a card as part of Revoke or Delete — see [setup.md](setup.md) and [troubleshooting.md](troubleshooting.md).
