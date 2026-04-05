import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _kJwt = 'auth_jwt';

  static String get baseurl {
    if (kIsWeb) return "http://localhost:5000";
    return "http://10.0.2.2:5000";
  }

  static Future<void> saveToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_kJwt);
    } else {
      await p.setString(_kJwt, token);
    }
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kJwt);
  }

  /// Returns `null` on success, or a short error message from the server.
  static Future<String?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("$baseurl/register");
    debugPrint("sending request to: $url");
    final response = await http.post(
      url,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );
    debugPrint("status code: ${response.statusCode}");
    debugPrint("response body: ${response.body}");

    if (response.statusCode == 200) {
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final t = map['token'] as String?;
        if (t != null && t.isNotEmpty) await saveToken(t);
      } catch (_) {}
      return null;
    }
    try {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = map["message"] as String? ?? "Register failed";
      final detail = map["detail"] as String?;
      if (detail != null && detail.isNotEmpty) {
        return "$msg — $detail";
      }
      return msg;
    } catch (_) {
      return "Register failed (HTTP ${response.statusCode})";
    }
  }

  /// Returns `null` on success (token saved). Otherwise an error message.
  static Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse("$baseurl/login");
    final response = await http.post(
      url,
      headers: const {"content-type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );
    if (response.statusCode == 200) {
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final t = map['token'] as String?;
        if (t != null && t.isNotEmpty) await saveToken(t);
      } catch (_) {}
      return null;
    }
    try {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return map['message'] as String? ?? 'Login failed';
    } catch (_) {
      return 'Login failed (HTTP ${response.statusCode})';
    }
  }
}
