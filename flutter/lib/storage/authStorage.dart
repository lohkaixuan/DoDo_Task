// lib/services/auth_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _kToken = 'auth_token';
  static const _kUserId = 'user_id';
  static const _kUserEmail = 'user_email';
  static final _secure = const FlutterSecureStorage();

  static Future<void> save(String token, String userId, String email) async {
    await _secure.write(key: _kToken, value: token);
    await _secure.write(key: _kUserId, value: userId);
    await _secure.write(key: _kUserEmail, value: email);
  }

  static Future<String?> readToken() => _secure.read(key: _kToken);
  static Future<String?> readUserId() => _secure.read(key: _kUserId);
  static Future<String?> readUserEmail() => _secure.read(key: _kUserEmail);

  static Future<void> clear() async {
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kUserId);
    await _secure.delete(key: _kUserEmail);
  }
}
