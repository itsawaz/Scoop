import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/sync_config.dart';
import 'turso_client.dart';

/// Direct-to-Turso email/password authentication.
///
/// SECURITY NOTE: This talks to Turso directly using a token shipped in the
/// app binary, which means anyone who extracts the APK can reach the database.
/// Passwords are therefore stored only as salted PBKDF2-HMAC-SHA256 hashes
/// (never plaintext), but for wide public distribution this should move behind
/// a thin auth backend that holds the Turso credentials and issues per-user
/// tokens. Fine for a personal / small-group release.
class AuthResult {
  final bool ok;
  final String? error;
  final String? userId;
  const AuthResult.success(this.userId)
      : ok = true,
        error = null;
  const AuthResult.failure(this.error)
      : ok = false,
        userId = null;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _userIdKey = 'auth_user_id';
  static const _emailKey = 'auth_email';
  static const _schemaKey = 'auth_schema_ready';

  static const int _pbkdf2Iterations = 100000;
  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  String? _cachedUserId;
  String? _cachedEmail;

  bool get isConfigured => SyncConfig.tursoEnabled;

  TursoClient? _client() => isConfigured ? TursoClient.fromConfig() : null;

  // --- Session ---------------------------------------------------------------

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    _cachedUserId = id;
    _cachedEmail = prefs.getString(_emailKey);
    return id != null && id.isNotEmpty;
  }

  String? get currentUserId => _cachedUserId;
  String? get currentEmail => _cachedEmail;

  Future<void> _persistSession(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_emailKey, email);
    _cachedUserId = userId;
    _cachedEmail = email;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    _cachedUserId = null;
    _cachedEmail = null;
  }

  // --- Password hashing (PBKDF2-HMAC-SHA256) ---------------------------------

  Uint8List _randomSalt() {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(_saltBytes, (_) => r.nextInt(256)));
  }

  /// PBKDF2 over HMAC-SHA256. Returns the derived key bytes.
  Uint8List _pbkdf2(String password, Uint8List salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final hLen = 32; // sha256 output
    final numBlocks = (dkLen / hLen).ceil();
    final out = BytesBuilder();

    for (var block = 1; block <= numBlocks; block++) {
      // INT_32_BE(block)
      final blockIndex = Uint8List(4)
        ..[0] = (block >> 24) & 0xff
        ..[1] = (block >> 16) & 0xff
        ..[2] = (block >> 8) & 0xff
        ..[3] = block & 0xff;

      var u = hmac.convert([...salt, ...blockIndex]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return out.toBytes().sublist(0, dkLen);
  }

  /// Encoded form stored in the DB: `pbkdf2$iters$saltB64$hashB64`
  String _hashPassword(String password) {
    final salt = _randomSalt();
    final dk = _pbkdf2(password, salt, _pbkdf2Iterations, _keyBytes);
    return 'pbkdf2\$$_pbkdf2Iterations\$${base64.encode(salt)}\$${base64.encode(dk)}';
  }

  bool _verifyPassword(String password, String encoded) {
    try {
      final parts = encoded.split('\$');
      if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
      final iters = int.parse(parts[1]);
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = _pbkdf2(password, Uint8List.fromList(salt), iters, expected.length);
      // Constant-time comparison.
      if (actual.length != expected.length) return false;
      var diff = 0;
      for (var i = 0; i < actual.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }

  // --- Schema ----------------------------------------------------------------

  Future<void> _ensureSchema(TursoClient client) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_schemaKey) == true) return;
    await client.run('''
      CREATE TABLE IF NOT EXISTS users (
        user_id       TEXT PRIMARY KEY,
        email         TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at    TEXT NOT NULL
      )
    ''');
    await prefs.setBool(_schemaKey, true);
  }

  String _newUserId() {
    final r = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  bool _looksLikeEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  // --- Signup / Login --------------------------------------------------------

  Future<AuthResult> signup(String email, String password) async {
    if (!isConfigured) {
      return const AuthResult.failure('Cloud accounts are not configured in this build.');
    }
    final e = _normalizeEmail(email);
    if (!_looksLikeEmail(e)) return const AuthResult.failure('Enter a valid email address.');
    if (password.length < 8) {
      return const AuthResult.failure('Password must be at least 8 characters.');
    }

    final client = _client()!;
    try {
      await _ensureSchema(client);

      // Check for existing account.
      final existing = await client.run('SELECT user_id FROM users WHERE email = ?', [e]);
      if (existing.rows.isNotEmpty) {
        return const AuthResult.failure('An account with that email already exists.');
      }

      final userId = _newUserId();
      final hash = _hashPassword(password);
      await client.run(
        'INSERT INTO users (user_id, email, password_hash, created_at) VALUES (?, ?, ?, ?)',
        [userId, e, hash, DateTime.now().toIso8601String()],
      );

      await _persistSession(userId, e);
      return AuthResult.success(userId);
    } on TursoException catch (ex) {
      return AuthResult.failure('Could not create account: ${ex.message}');
    } catch (ex) {
      return AuthResult.failure('Could not create account: $ex');
    } finally {
      client.close();
    }
  }

  Future<AuthResult> login(String email, String password) async {
    if (!isConfigured) {
      return const AuthResult.failure('Cloud accounts are not configured in this build.');
    }
    final e = _normalizeEmail(email);
    if (!_looksLikeEmail(e)) return const AuthResult.failure('Enter a valid email address.');
    if (password.isEmpty) return const AuthResult.failure('Enter your password.');

    final client = _client()!;
    try {
      await _ensureSchema(client);
      final res = await client.run(
        'SELECT user_id, password_hash FROM users WHERE email = ?',
        [e],
      );
      if (res.rows.isEmpty) {
        return const AuthResult.failure('No account found for that email.');
      }
      final row = res.maps.first;
      final userId = row['user_id']?.toString() ?? '';
      final hash = row['password_hash']?.toString() ?? '';
      if (!_verifyPassword(password, hash)) {
        return const AuthResult.failure('Incorrect password.');
      }
      await _persistSession(userId, e);
      return AuthResult.success(userId);
    } on TursoException catch (ex) {
      return AuthResult.failure('Could not sign in: ${ex.message}');
    } catch (ex) {
      return AuthResult.failure('Could not sign in: $ex');
    } finally {
      client.close();
    }
  }

  /// Permanently delete the current user's account row. (Data rows are removed
  /// separately by the sync service.)
  Future<bool> deleteAccount() async {
    final id = _cachedUserId;
    if (id == null || !isConfigured) return false;
    final client = _client()!;
    try {
      await client.run('DELETE FROM users WHERE user_id = ?', [id]);
      await logout();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
