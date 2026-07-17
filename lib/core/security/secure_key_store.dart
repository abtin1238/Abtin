import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نگه‌داری امن کلید رمزنگاری دیتابیس.
///
/// در پروداکشن موبایل این لایه باید با Android Keystore / iOS Keychain
/// (مثلاً از طریق `flutter_secure_storage`) جایگزین شود.
/// اینجا کلید محلی تولید و به‌صورت obfuscated نگه‌داری می‌شود تا
/// فایل SQLite بدون passphrase قابل خواندن نباشد.
class SecureKeyStore {
  static const _prefsKey = 'abtin.db.passphrase.v1';

  /// دریافت یا تولید passphrase دیتابیس.
  static Future<String> getOrCreatePassphrase() async {
    if (kIsWeb) return 'abtin-web-demo-key';
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) {
      return utf8.decode(base64Decode(existing));
    }
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final raw = base64UrlEncode(bytes);
    await prefs.setString(_prefsKey, base64Encode(utf8.encode(raw)));
    return raw;
  }
}
