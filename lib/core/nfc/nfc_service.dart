// NFC read/write for NTAG215 blank tags (SPEC §5.3 / §5.4 / §6.5).
//
// Payload format: a single well-known URI record with value
// `huetap://c/<uuid-v4>`. We also append a Text record with the card label
// so that a tap outside the app (e.g. Android's built-in NFC sniffer)
// shows meaningful text, but the URI record is the authoritative binding.
//
// Sessions are one-shot: `startSession` fires `onDiscovered` exactly once
// per surface, then the caller should `stopSession`.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// Custom URI scheme used for card bindings.
const String huetapUriScheme = 'huetap';

/// Encode `huetap://c/<uuid>` into a URI NDEF record.
NdefRecord makeHuetapUriRecord(String uuid) {
  final uri = '$huetapUriScheme://c/$uuid';
  // URI record payload = prefix byte (0x00 = no abbreviation) + UTF-8 URI.
  final payload = Uint8List.fromList(<int>[0x00, ...utf8.encode(uri)]);
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(<int>[0x55]), // 'U'
    identifier: Uint8List(0),
    payload: payload,
  );
}

/// Encode a UTF-8 Text record (RFC TNF-wellKnown 'T').
NdefRecord makeTextRecord(String text, {String lang = 'en'}) {
  final langBytes = utf8.encode(lang);
  final textBytes = utf8.encode(text);
  // Status byte: UTF-8 (bit7=0), language code length in low 6 bits.
  final status = langBytes.length & 0x3F;
  final payload = Uint8List.fromList(<int>[status, ...langBytes, ...textBytes]);
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(<int>[0x54]), // 'T'
    identifier: Uint8List(0),
    payload: payload,
  );
}

/// Attempt to decode a URI NDEF record back into its string form.
String? decodeUriRecord(NdefRecord r) {
  if (r.typeNameFormat != TypeNameFormat.wellKnown) return null;
  if (r.type.length != 1 || r.type.first != 0x55) return null;
  if (r.payload.isEmpty) return null;
  final prefixIdx = r.payload.first;
  final prefix = _uriPrefixes[prefixIdx] ?? '';
  final rest = utf8.decode(r.payload.sublist(1), allowMalformed: true);
  return '$prefix$rest';
}

/// Extract the UUID from a `huetap://c/<uuid>` URI. Returns null if the URI
/// doesn't match the expected shape.
String? parseHuetapUuid(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return null;
  if (parsed.scheme != huetapUriScheme) return null;
  if (parsed.host != 'c') return null;
  final segs = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.length != 1) return null;
  return segs.first;
}

/// Thin facade around `NfcManager` that hides the android-specific Ndef
/// conversion. All methods throw on failure.
class NfcService {
  /// Write a fresh `huetap://c/<uuid>` binding (+ optional label) to whatever
  /// compatible NDEF tag the user taps next.
  ///
  /// Completes when the write succeeds. Throws on I/O failure, read-only tag,
  /// or NFC disabled. Caller is responsible for showing "hold card to phone"
  /// UX and wiring cancellation via the returned canceller.
  Future<NfcWriteHandle> startWrite({
    required String uuid,
    String? label,
    required void Function(NfcWriteOutcome outcome) onResult,
  }) async {
    final completer = Completer<NfcWriteOutcome>();
    final nfc = NfcManager.instance;

    final avail = await nfc.checkAvailability();
    if (avail != NfcAvailability.enabled) {
      final outcome = NfcWriteOutcome.failure(
        'NFC is ${avail.name}. Enable NFC and try again.',
      );
      onResult(outcome);
      completer.complete(outcome);
      return NfcWriteHandle._(stop: () async {});
    }

    await nfc.startSession(
      pollingOptions: <NfcPollingOption>{NfcPollingOption.iso14443},
      onDiscovered: (tag) async {
        try {
          final ndef = NdefAndroid.from(tag);
          if (ndef == null) {
            final outcome = NfcWriteOutcome.failure(
              'This tag is not NDEF-compatible.',
            );
            onResult(outcome);
            if (!completer.isCompleted) completer.complete(outcome);
            return;
          }
          if (!ndef.isWritable) {
            final outcome = NfcWriteOutcome.failure('Tag is read-only.');
            onResult(outcome);
            if (!completer.isCompleted) completer.complete(outcome);
            return;
          }

          final records = <NdefRecord>[
            makeHuetapUriRecord(uuid),
            if (label != null && label.trim().isNotEmpty)
              makeTextRecord(label.trim()),
          ];
          await ndef.writeNdefMessage(NdefMessage(records: records));

          final outcome = NfcWriteOutcome.success(uuid: uuid);
          onResult(outcome);
          if (!completer.isCompleted) completer.complete(outcome);
        } catch (e) {
          final outcome = NfcWriteOutcome.failure('Write failed: $e');
          onResult(outcome);
          if (!completer.isCompleted) completer.complete(outcome);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return NfcWriteHandle._(
      stop: () async {
        if (!completer.isCompleted) {
          completer.complete(const NfcWriteOutcome.cancelled());
        }
        await nfc.stopSession();
      },
    );
  }

  /// One-shot read: starts a session, reports the first NDEF URI seen, then
  /// ends. Used by the in-app tap-to-fire path when the app is already open.
  Future<NfcReadHandle> startRead({
    required void Function(NfcReadOutcome outcome) onResult,
  }) async {
    final nfc = NfcManager.instance;
    final avail = await nfc.checkAvailability();
    if (avail != NfcAvailability.enabled) {
      onResult(NfcReadOutcome.failure('NFC is ${avail.name}.'));
      return NfcReadHandle._(stop: () async {});
    }

    await nfc.startSession(
      pollingOptions: <NfcPollingOption>{NfcPollingOption.iso14443},
      onDiscovered: (tag) async {
        try {
          final ndef = NdefAndroid.from(tag);
          if (ndef == null) {
            onResult(NfcReadOutcome.failure('Not an NDEF tag.'));
            return;
          }
          final msg = ndef.cachedNdefMessage ?? await ndef.getNdefMessage();
          if (msg == null || msg.records.isEmpty) {
            onResult(NfcReadOutcome.failure('Tag is blank.'));
            return;
          }
          String? uuid;
          for (final r in msg.records) {
            final uri = decodeUriRecord(r);
            if (uri == null) continue;
            final extracted = parseHuetapUuid(uri);
            if (extracted != null) {
              uuid = extracted;
              break;
            }
          }
          if (uuid == null) {
            onResult(NfcReadOutcome.failure('Tag is not a HueTap card.'));
            return;
          }
          onResult(NfcReadOutcome.success(uuid: uuid));
        } catch (e) {
          onResult(NfcReadOutcome.failure('Read failed: $e'));
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return NfcReadHandle._(stop: () => nfc.stopSession());
  }
}

/// URI record prefix abbreviation table (subset — everything we'll ever see).
const Map<int, String> _uriPrefixes = <int, String>{
  0x00: '',
  0x01: 'http://www.',
  0x02: 'https://www.',
  0x03: 'http://',
  0x04: 'https://',
};

class NfcWriteHandle {
  NfcWriteHandle._({required this.stop});
  final Future<void> Function() stop;
}

class NfcReadHandle {
  NfcReadHandle._({required this.stop});
  final Future<void> Function() stop;
}

sealed class NfcWriteOutcome {
  const NfcWriteOutcome();
  const factory NfcWriteOutcome.success({required String uuid}) =
      NfcWriteSuccess;
  const factory NfcWriteOutcome.failure(String message) = NfcWriteFailure;
  const factory NfcWriteOutcome.cancelled() = NfcWriteCancelled;
}

class NfcWriteSuccess extends NfcWriteOutcome {
  const NfcWriteSuccess({required this.uuid});
  final String uuid;
}

class NfcWriteFailure extends NfcWriteOutcome {
  const NfcWriteFailure(this.message);
  final String message;
}

class NfcWriteCancelled extends NfcWriteOutcome {
  const NfcWriteCancelled();
}

sealed class NfcReadOutcome {
  const NfcReadOutcome();
  const factory NfcReadOutcome.success({required String uuid}) =
      NfcReadSuccess;
  const factory NfcReadOutcome.failure(String message) = NfcReadFailure;
}

class NfcReadSuccess extends NfcReadOutcome {
  const NfcReadSuccess({required this.uuid});
  final String uuid;
}

class NfcReadFailure extends NfcReadOutcome {
  const NfcReadFailure(this.message);
  final String message;
}
