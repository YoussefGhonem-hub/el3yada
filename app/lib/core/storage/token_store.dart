import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/auth_session.dart';

/// Keeps the signed-in session between app launches.
abstract interface class TokenStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

/// Keychain on iOS/macOS, Keystore on Android, Credential Manager on Windows.
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  static const _key = 'auth.session';
  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// For tests.
class MemoryTokenStore implements TokenStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(const FlutterSecureStorage()),
);
