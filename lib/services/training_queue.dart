import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/sync_config.dart';

/// On-device staging buffer for AI training data.
///
/// Every time the user analyzes a meal, we persist the meal image + the AI's
/// analysis JSON + metadata locally. Whenever the private training endpoint is
/// reachable, queued items are uploaded (multipart POST) and then DELETED from
/// the device to reclaim space. If the endpoint is unreachable, items stay
/// queued and are retried on the next flush.
///
/// Layout: {appDocs}/training_queue/{itemId}.jpg  +  {itemId}.json
class TrainingQueue {
  static final TrainingQueue _instance = TrainingQueue._internal();
  factory TrainingQueue() => _instance;
  TrainingQueue._internal();

  static const _dirName = 'training_queue';
  bool _flushing = false;

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Persist a captured meal analysis for later upload.
  /// [imageBytes] may be null for text-only analyses.
  Future<void> enqueue({
    required String userId,
    required Map<String, dynamic> analysis,
    Uint8List? imageBytes,
    String? userDescription,
    String? modelUsed,
  }) async {
    try {
      final dir = await _dir();
      final itemId =
          '${DateTime.now().millisecondsSinceEpoch}_${userId.hashCode.toRadixString(16)}';

      final meta = <String, dynamic>{
        'itemId': itemId,
        'userId': userId,
        'capturedAt': DateTime.now().toIso8601String(),
        'hasImage': imageBytes != null,
        'userDescription': userDescription ?? '',
        'modelUsed': modelUsed ?? '',
        'analysis': analysis,
      };

      if (imageBytes != null) {
        await File('${dir.path}/$itemId.jpg').writeAsBytes(imageBytes, flush: true);
      }
      await File('${dir.path}/$itemId.json')
          .writeAsString(jsonEncode(meta), flush: true);
    } catch (e) {
      // ignore: avoid_print
      print('[TrainingQueue] enqueue failed: $e');
    }
    // Fire-and-forget attempt to drain immediately if the endpoint is up.
    unawaited(flush());
  }

  /// Number of items currently queued on-device.
  Future<int> pendingCount() async {
    try {
      final dir = await _dir();
      final metas = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));
      return metas.length;
    } catch (_) {
      return 0;
    }
  }

  /// Quick reachability probe so we don't spin on uploads when offline / the
  /// laptop endpoint is down.
  Future<bool> _endpointReachable(http.Client client) async {
    try {
      final resp = await client
          .get(Uri.parse(SyncConfig.trainingHealthUrl), headers: _authHeaders())
          .timeout(const Duration(seconds: 4));
      return resp.statusCode >= 200 && resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _authHeaders() {
    final token = SyncConfig.trainingEndpointToken;
    return token.isEmpty ? {} : {'Authorization': 'Bearer $token'};
  }

  /// Attempt to upload every queued item. Deletes local files on HTTP 2xx.
  Future<void> flush() async {
    if (!SyncConfig.trainingEndpointConfigured || _flushing) return;
    _flushing = true;
    final client = http.Client();
    try {
      if (!await _endpointReachable(client)) return;

      final dir = await _dir();
      final metaFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      for (final metaFile in metaFiles) {
        try {
          final meta =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          final itemId = meta['itemId']?.toString() ?? '';
          if (itemId.isEmpty) {
            await metaFile.delete();
            continue;
          }
          final imgFile = File('${dir.path}/$itemId.jpg');
          final hasImage = await imgFile.exists();

          final req = http.MultipartRequest(
            'POST',
            Uri.parse(SyncConfig.trainingUploadUrl),
          );
          req.headers.addAll(_authHeaders());
          req.fields['itemId'] = itemId;
          req.fields['userId'] = meta['userId']?.toString() ?? '';
          req.fields['capturedAt'] = meta['capturedAt']?.toString() ?? '';
          req.fields['userDescription'] =
              meta['userDescription']?.toString() ?? '';
          req.fields['modelUsed'] = meta['modelUsed']?.toString() ?? '';
          req.fields['analysis'] = jsonEncode(meta['analysis'] ?? {});
          if (hasImage) {
            req.files.add(await http.MultipartFile.fromPath('image', imgFile.path));
          }

          final streamed = await client.send(req).timeout(const Duration(seconds: 30));
          if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
            // Delivered — clean up local copies to reclaim space.
            if (hasImage) await imgFile.delete();
            await metaFile.delete();
          } else {
            // Server reachable but rejected this item; keep it and stop the
            // batch to avoid hammering. Retry next flush.
            // ignore: avoid_print
            print('[TrainingQueue] upload rejected (${streamed.statusCode}) for $itemId');
            break;
          }
        } catch (e) {
          // Network hiccup mid-batch — keep the item, retry later.
          // ignore: avoid_print
          print('[TrainingQueue] upload error: $e');
          break;
        }
      }
    } finally {
      client.close();
      _flushing = false;
    }
  }
}
