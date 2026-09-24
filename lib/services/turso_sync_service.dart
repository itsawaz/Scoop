import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/sync_config.dart';
import 'turso_client.dart';

/// Cloud sync so a user's data survives reinstalls (e.g. the 7-day iOS
/// free-provisioning expiry). Structured data lives in SharedPreferences on
/// the device; this service mirrors it to a shared Turso database, partitioned
/// by a stable per-user id so each device only ever reads back its own rows.
///
/// Storage model: one generic table `sync_items(user_id, collection, item_id,
/// payload, updated_at)`. List collections (history, weight_log, ...) store one
/// row per item; scalar profile settings are stored as a single JSON blob row.
class TursoSyncService {
  static final TursoSyncService _instance = TursoSyncService._internal();
  factory TursoSyncService() => _instance;
  TursoSyncService._internal();

  static const _userIdKey = 'sync_user_id';
  static const _schemaReadyKey = 'sync_schema_ready';

  // SharedPreferences keys holding JSON-encoded string lists.
  static const _listCollections = <String>[
    'history',
    'weight_log',
    'supplement_log',
    'saved_meals',
    'saved_supplements',
    'fasting_sessions',
    'coach_history',
    'coach_archives',
  ];

  // Scalar profile / settings keys bundled into one JSON blob row.
  static const _profileStringKeys = <String>[
    'name', 'conditions', 'goals', 'gender', 'activity_level', 'unit_system',
    'goals_json', 'goals_computed_at',
  ];
  static const _profileDoubleKeys = <String>[
    'height_cm', 'weight_kg', 'goal_weight_kg', 'initial_weight_kg',
  ];
  static const _profileIntKeys = <String>[
    'age', 'current_streak', 'max_streak', 'xp',
  ];
  static const _profileBoolKeys = <String>[
    'auto_recalculate', 'health_connected',
  ];

  bool _syncing = false;

  TursoClient? _client() =>
      SyncConfig.tursoEnabled ? TursoClient.fromConfig() : null;

  /// Stable per-user id, created once and reused across reinstalls only if the
  /// user restores it. Since reinstalls wipe local storage, the id is derived
  /// from a user-visible recovery code (see [ensureUserId]).
  Future<String> ensureUserId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_userIdKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_userIdKey, id);
    }
    return id;
  }

  Future<String?> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Set the user id explicitly (used when restoring via a recovery code).
  Future<void> setUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id.trim());
  }

  String _generateId() {
    final r = Random.secure();
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _ensureSchema(TursoClient client) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_schemaReadyKey) == true) return;
    await client.run('''
      CREATE TABLE IF NOT EXISTS sync_items (
        user_id    TEXT NOT NULL,
        collection TEXT NOT NULL,
        item_id    TEXT NOT NULL,
        payload    TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, collection, item_id)
      )
    ''');
    await prefs.setBool(_schemaReadyKey, true);
  }

  /// Push all local data up to Turso. Safe to call often; it's a full upsert.
  Future<void> push() async {
    final client = _client();
    if (client == null || _syncing) return;
    _syncing = true;
    try {
      await _ensureSchema(client);
      final prefs = await SharedPreferences.getInstance();
      final userId = await ensureUserId();
      final now = DateTime.now().toIso8601String();
      final stmts = <TursoStatement>[];

      // List collections: one row per item, keyed by the item's own id.
      for (final col in _listCollections) {
        final list = prefs.getStringList(col) ?? [];
        for (final itemStr in list) {
          final itemId = _extractId(itemStr);
          stmts.add(TursoStatement(
            'INSERT OR REPLACE INTO sync_items (user_id, collection, item_id, payload, updated_at) VALUES (?, ?, ?, ?, ?)',
            [userId, col, itemId, itemStr, now],
          ));
        }
      }

      // Profile/settings as a single blob row.
      stmts.add(TursoStatement(
        'INSERT OR REPLACE INTO sync_items (user_id, collection, item_id, payload, updated_at) VALUES (?, ?, ?, ?, ?)',
        [userId, '_profile', 'profile', jsonEncode(_collectProfile(prefs)), now],
      ));

      // Chunk to keep each pipeline request reasonable.
      for (final chunk in _chunk(stmts, 50)) {
        await client.execute(chunk);
      }
    } catch (e) {
      // Non-fatal: local data is intact; we'll retry on next trigger.
      // ignore: avoid_print
      print('[TursoSync] push failed: $e');
    } finally {
      _syncing = false;
      client.close();
    }
  }

  /// Pull all rows for the current user id and repopulate local storage.
  /// Used on a fresh install to restore after entering a recovery code.
  /// Returns the number of items restored.
  Future<int> pull() async {
    final client = _client();
    if (client == null) return 0;
    try {
      await _ensureSchema(client);
      final prefs = await SharedPreferences.getInstance();
      final userId = await ensureUserId();
      final res = await client.run(
        'SELECT collection, item_id, payload FROM sync_items WHERE user_id = ?',
        [userId],
      );

      final buckets = <String, List<String>>{};
      Map<String, dynamic>? profile;
      var count = 0;

      for (final row in res.maps) {
        final col = row['collection']?.toString() ?? '';
        final payload = row['payload']?.toString() ?? '';
        if (col == '_profile') {
          try {
            profile = jsonDecode(payload) as Map<String, dynamic>;
          } catch (_) {}
          continue;
        }
        (buckets[col] ??= []).add(payload);
        count++;
      }

      for (final col in _listCollections) {
        if (buckets.containsKey(col)) {
          await prefs.setStringList(col, buckets[col]!);
        }
      }
      if (profile != null) {
        await _applyProfile(prefs, profile);
      }
      return count;
    } catch (e) {
      // ignore: avoid_print
      print('[TursoSync] pull failed: $e');
      return 0;
    } finally {
      client.close();
    }
  }

  /// Try to extract the item's own "id" for a stable primary key; fall back to
  /// a hash of the payload so items without ids still de-duplicate.
  String _extractId(String jsonStr) {
    try {
      final m = jsonDecode(jsonStr);
      if (m is Map && m['id'] != null && '${m['id']}'.isNotEmpty) {
        return '${m['id']}';
      }
    } catch (_) {}
    return jsonStr.hashCode.toRadixString(16);
  }

  Map<String, dynamic> _collectProfile(SharedPreferences prefs) {
    final m = <String, dynamic>{};
    for (final k in _profileStringKeys) {
      final v = prefs.getString(k);
      if (v != null) m[k] = v;
    }
    for (final k in _profileDoubleKeys) {
      final v = prefs.getDouble(k);
      if (v != null) m[k] = v;
    }
    for (final k in _profileIntKeys) {
      final v = prefs.getInt(k);
      if (v != null) m[k] = v;
    }
    for (final k in _profileBoolKeys) {
      final v = prefs.getBool(k);
      if (v != null) m[k] = v;
    }
    return m;
  }

  Future<void> _applyProfile(SharedPreferences prefs, Map<String, dynamic> m) async {
    for (final k in _profileStringKeys) {
      if (m[k] is String) await prefs.setString(k, m[k] as String);
    }
    for (final k in _profileDoubleKeys) {
      if (m[k] is num) await prefs.setDouble(k, (m[k] as num).toDouble());
    }
    for (final k in _profileIntKeys) {
      if (m[k] is num) await prefs.setInt(k, (m[k] as num).toInt());
    }
    for (final k in _profileBoolKeys) {
      if (m[k] is bool) await prefs.setBool(k, m[k] as bool);
    }
  }

  Iterable<List<T>> _chunk<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, min(i + size, list.length));
    }
  }
}
