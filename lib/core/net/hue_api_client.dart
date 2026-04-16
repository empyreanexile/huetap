// Thin wrapper over Hue CLIP v2 — the two verbs HueTap actually uses in
// Phase 1-4: list scenes, fire scene. Room/zone enrichment is included
// because SPEC §6.3 stores roomName/zoneName alongside each scene for UX.
//
// Instances are built by the BridgeClientRegistry, one per paired bridge.
// Each owns a dio bound to the bridge's per-bridge BridgePinningAdapter.

import 'package:dio/dio.dart';

/// One remote scene as the list UI needs it.
class HueScene {
  const HueScene({
    required this.id,
    required this.name,
    this.roomId,
    this.roomName,
    this.zoneId,
    this.zoneName,
  });

  final String id;
  final String name;
  final String? roomId;
  final String? roomName;
  final String? zoneId;
  final String? zoneName;
}

class HueApiClient {
  HueApiClient({
    required String ip,
    required String applicationKey,
    required Dio dio,
  }) : _ip = ip,
       _appKey = applicationKey,
       _dio = dio;

  final String _ip;
  final String _appKey;
  final Dio _dio;

  Map<String, Object?> get _headers =>
      <String, Object?>{'hue-application-key': _appKey};

  /// `GET /clip/v2/resource/scene`, enriched with room/zone names resolved
  /// from parallel `GET /clip/v2/resource/{room,zone}` calls.
  Future<List<HueScene>> listScenes() async {
    final responses = await Future.wait([
      _dio.get<Map<String, Object?>>(
        'https://$_ip/clip/v2/resource/scene',
        options: Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
      _dio.get<Map<String, Object?>>(
        'https://$_ip/clip/v2/resource/room',
        options: Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
      _dio.get<Map<String, Object?>>(
        'https://$_ip/clip/v2/resource/zone',
        options: Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
    ]);

    final roomNames = _nameMapFrom(responses[1].data);
    final zoneNames = _nameMapFrom(responses[2].data);

    final sceneBody = responses[0].data;
    final sceneRows = (sceneBody?['data'] as List?) ?? const [];
    return sceneRows
        .whereType<Map<String, Object?>>()
        .map((row) => _sceneFromJson(row, roomNames, zoneNames))
        .whereType<HueScene>()
        .toList(growable: false);
  }

  /// `PUT /clip/v2/resource/scene/<id>` with `recall=active`.
  Future<void> fireScene(String sceneId) async {
    await _dio.put<dynamic>(
      'https://$_ip/clip/v2/resource/scene/$sceneId',
      data: <String, Object?>{
        'recall': <String, Object?>{'action': 'active'},
      },
      options: Options(
        headers: _headers,
        // SPEC §6.2: 3s timeout for fire requests.
        sendTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );
  }

  // --- helpers -----------------------------------------------------------

  Map<String, String> _nameMapFrom(Map<String, Object?>? body) {
    final rows = (body?['data'] as List?) ?? const [];
    final result = <String, String>{};
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final id = row['id'];
      final meta = row['metadata'];
      if (id is! String || meta is! Map) continue;
      final name = meta['name'];
      if (name is String) result[id] = name;
    }
    return result;
  }

  HueScene? _sceneFromJson(
    Map<String, Object?> row,
    Map<String, String> roomNames,
    Map<String, String> zoneNames,
  ) {
    final id = row['id'];
    final meta = row['metadata'];
    if (id is! String || meta is! Map) return null;
    final name = meta['name'];
    if (name is! String) return null;

    final group = row['group'];
    String? roomId, roomName, zoneId, zoneName;
    if (group is Map) {
      final rid = group['rid'];
      final rtype = group['rtype'];
      if (rid is String && rtype is String) {
        if (rtype == 'room') {
          roomId = rid;
          roomName = roomNames[rid];
        } else if (rtype == 'zone') {
          zoneId = rid;
          zoneName = zoneNames[rid];
        }
      }
    }

    return HueScene(
      id: id,
      name: name,
      roomId: roomId,
      roomName: roomName,
      zoneId: zoneId,
      zoneName: zoneName,
    );
  }
}
