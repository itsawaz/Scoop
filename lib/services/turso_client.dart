import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/sync_config.dart';

/// Minimal client for the Turso / libSQL "SQL over HTTP" v2 API.
///
/// Talks to `POST {base}/v2/pipeline` with a Bearer token. No native
/// dependencies, so it behaves identically on iOS and Android.
///
/// Docs: https://docs.turso.tech/sdk/http/reference
class TursoException implements Exception {
  final String message;
  TursoException(this.message);
  @override
  String toString() => 'TursoException: $message';
}

/// A single statement + its positional args.
class TursoStatement {
  final String sql;
  final List<Object?> args;
  TursoStatement(this.sql, [this.args = const []]);
}

/// Result of one execute: column names + rows (each row is a list of Dart
/// values already decoded from Turso's typed value format).
class TursoResult {
  final List<String> columns;
  final List<List<Object?>> rows;
  TursoResult(this.columns, this.rows);

  /// Convenience: rows as maps keyed by column name.
  List<Map<String, Object?>> get maps => rows
      .map((r) => {for (var i = 0; i < columns.length; i++) columns[i]: r[i]})
      .toList();
}

class TursoClient {
  final String baseUrl;
  final String authToken;
  final http.Client _http;

  TursoClient({required String url, required this.authToken, http.Client? client})
      : baseUrl = _normalizeUrl(url),
        _http = client ?? http.Client();

  factory TursoClient.fromConfig({http.Client? client}) => TursoClient(
        url: SyncConfig.tursoUrl,
        authToken: SyncConfig.tursoAuthToken,
        client: client,
      );

  static String _normalizeUrl(String url) {
    var u = url.trim();
    // Turso CLI hands out libsql:// / turso:// URLs; HTTP API needs https://.
    if (u.startsWith('libsql://')) u = 'https://${u.substring('libsql://'.length)}';
    if (u.startsWith('turso://')) u = 'https://${u.substring('turso://'.length)}';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// Encode a Dart value into Turso's typed-value JSON representation.
  static Map<String, Object?> _encodeArg(Object? v) {
    if (v == null) return {'type': 'null', 'value': null};
    if (v is int) return {'type': 'integer', 'value': v.toString()};
    if (v is double) return {'type': 'float', 'value': v};
    if (v is bool) return {'type': 'integer', 'value': v ? '1' : '0'};
    return {'type': 'text', 'value': v.toString()};
  }

  /// Decode a Turso typed value into a Dart value.
  static Object? _decodeValue(Map<String, dynamic> v) {
    switch (v['type']) {
      case 'null':
        return null;
      case 'integer':
        return int.tryParse('${v['value']}');
      case 'float':
        return (v['value'] as num?)?.toDouble();
      case 'text':
        return v['value']?.toString();
      case 'blob':
        return v['value']; // base64 string; not used by our schema
      default:
        return v['value'];
    }
  }

  /// Execute one or more statements in a single pipeline round-trip.
  /// The connection is closed at the end (stateless usage).
  Future<List<TursoResult>> execute(List<TursoStatement> statements) async {
    if (baseUrl.isEmpty) {
      throw TursoException('Turso URL not configured');
    }

    final requests = [
      for (final s in statements)
        {
          'type': 'execute',
          'stmt': {
            'sql': s.sql,
            'args': s.args.map(_encodeArg).toList(),
          },
        },
      {'type': 'close'},
    ];

    final resp = await _http
        .post(
          Uri.parse('$baseUrl/v2/pipeline'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'requests': requests}),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TursoException('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    final out = <TursoResult>[];

    for (final r in results) {
      if (r is! Map) continue;
      if (r['type'] == 'error') {
        final err = r['error'];
        throw TursoException('SQL error: ${err is Map ? err['message'] : err}');
      }
      final resp0 = r['response'];
      if (resp0 is! Map) continue;
      if (resp0['type'] != 'execute') continue; // skip close response
      final result = resp0['result'] as Map<String, dynamic>? ?? {};
      final cols = ((result['cols'] as List?) ?? [])
          .map((c) => (c is Map ? (c['name']?.toString() ?? '') : '$c'))
          .toList();
      final rows = <List<Object?>>[];
      for (final row in (result['rows'] as List?) ?? []) {
        if (row is List) {
          rows.add(row
              .map((cell) => cell is Map<String, dynamic>
                  ? _decodeValue(cell)
                  : cell)
              .toList());
        }
      }
      out.add(TursoResult(cols, rows));
    }
    return out;
  }

  /// Single-statement convenience.
  Future<TursoResult> run(String sql, [List<Object?> args = const []]) async {
    final results = await execute([TursoStatement(sql, args)]);
    return results.isNotEmpty ? results.first : TursoResult([], []);
  }

  void close() => _http.close();
}
