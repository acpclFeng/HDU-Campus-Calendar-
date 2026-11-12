// 本机存储层：
//   · 令牌 → flutter_secure_storage（Android Keystore / iOS Keychain，系统级加密）
//   · 日历缓存 → shared_preferences（断网时显示上次结果，不含令牌）
// 没有任何账号、PIN、服务器上传；令牌永远不会离开这台手机（只发给 api.hduhelp.com）。

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class TokenStore {
  static const _tokenKey = 'cc.token.v1';
  static const _cacheKey = 'cc.calendar.cache.v1';
  static const _metaKey = 'cc.calendar.meta.v1';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> readToken() => _secure.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _secure.write(key: _tokenKey, value: token.trim());

  Future<void> clearToken() async {
    await _secure.delete(key: _tokenKey);
    await clearCache();
  }

  Future<String?> lastSync() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_metaKey);
  }

  Future<CalendarResult?> loadCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return CalendarResult.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCache(CalendarResult data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey, jsonEncode(data.toJson()));
    await p.setString(_metaKey, DateTime.now().toIso8601String());
  }

  Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_cacheKey);
    await p.remove(_metaKey);
  }

  static String mask(String token) {
    if (token.isEmpty) return '—';
    if (token.length <= 10) return '${token.substring(0, 2)}••••';
    return '${token.substring(0, 6)}••••••${token.substring(token.length - 4)}';
  }
}
