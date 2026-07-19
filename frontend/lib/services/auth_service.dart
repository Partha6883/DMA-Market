// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _baseUrl = 'https://dma-backend.onrender.com'; // update if your backend IP changes
const _tokenKey = 'dma_token';
final _storage = FlutterSecureStorage();

class AuthService {
  /// Save token to secure storage
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Get token from secure storage (or null)
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Clear token from storage
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Convenience: return headers with Authorization if token exists
  static Future<Map<String, String>> authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Register (name, phone/email, password, role)
  /// Returns a Map with ok:true on success (contains token,user) or ok:false + error.
  static Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? phone,
    required String password,
    String? role, // 'buyer' or 'farmer'
  }) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    final body = jsonEncode({
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
      if (role != null) 'role': role,
    });

    try {
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 15));
      final text = resp.body;
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        // not valid json
      }

      if (resp.statusCode == 200 && parsed != null && parsed['ok'] == true) {
        final token = parsed['token']?.toString() ?? '';
        if (token.isNotEmpty) await saveToken(token);
        return {'ok': true, 'token': token, 'user': parsed['user']};
      }

      // return structured error
      final err = parsed != null ? (parsed['error'] ?? parsed['message'] ?? parsed) : 'Unexpected response';
      return {'ok': false, 'error': err, 'raw': text, 'status': resp.statusCode};
    } catch (e) {
      return {'ok': false, 'error': 'Network error: $e'};
    }
  }

  /// Login with phone or email + password.
  /// Simplified API: pass phone in first param (or email) and password.
  /// Returns Map with ok, token, user or ok:false + error.
  static Future<Map<String, dynamic>> login(String phoneOrEmail, String password) async {
    // the backend accepts phone OR email in the same fields; we try phone
    final url = Uri.parse('$_baseUrl/auth/login');
    final body = jsonEncode({
      // If your UI always sends phone, keep as phone; backend accepts either.
      'phone': phoneOrEmail,
      'password': password,
    });

    try {
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 12));
      final text = resp.body;
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}

      if (resp.statusCode == 200 && parsed != null && parsed['ok'] == true) {
        final token = parsed['token']?.toString() ?? '';
        if (token.isNotEmpty) await saveToken(token);
        return {'ok': true, 'token': token, 'user': parsed['user']};
      }

      final err = parsed != null ? (parsed['error'] ?? parsed['message'] ?? parsed) : 'Login failed';
      return {'ok': false, 'error': err, 'raw': text, 'status': resp.statusCode};
    } catch (e) {
      return {'ok': false, 'error': 'Network error: $e'};
    }
  }

  /// Logout locally (clears token). Server-side logout not required for JWT.
  static Future<void> logout() async {
    await clearToken();
  }

  /// Get current user info from /auth/me. Returns Map or null on error.
  /// If server responds with ok:false, returns that map.
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    final url = Uri.parse('$_baseUrl/auth/me');
    try {
      final resp = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      final text = resp.body;
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}

      if (resp.statusCode == 200 && parsed != null && parsed['ok'] == true) {
        return parsed;
      }

      // Return parsed even if ok:false so caller can inspect error
      if (parsed != null) return parsed;
      return {'ok': false, 'error': 'Unexpected response', 'raw': text, 'status': resp.statusCode};
    } catch (e) {
      return {'ok': false, 'error': 'Network error: $e'};
    }
  }
}
