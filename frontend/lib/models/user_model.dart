// lib/models/user_model.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserModel extends ChangeNotifier {
  String? name;
  String? phone;
  String? role;
  String? token;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isFarmer => role?.toLowerCase() == 'farmer';
  bool get isBuyer => role?.toLowerCase() == 'buyer';

  /// Load token + fetch current user from backend
  /// (Used by SplashScreen for auto-login)
  Future<void> loadFromStorage() async {
    final storedToken = await AuthService.getToken();
    if (storedToken == null || storedToken.isEmpty) {
      // ensure cleared state
      token = null;
      name = null;
      phone = null;
      role = null;
      notifyListeners();
      return;
    }

    token = storedToken;

    // attempt to fetch user details; ignore failures
    try {
      final resp = await AuthService.getCurrentUser();
      if (resp != null && resp['ok'] == true && resp['user'] is Map) {
        final u = resp['user'] as Map;
        name = u['name']?.toString();
        phone = u['phone']?.toString();
        role = u['role']?.toString();
      }
    } catch (_) {
      // ignore - token may be invalid; app can call logout() later
    }

    notifyListeners();
  }

  /// Save user after login/register
  void setUser(String n, String p, String? r, String t) {
    name = n;
    phone = p;
    role = r;
    token = t;

    // Persist token locally
    AuthService.saveToken(t);

    notifyListeners();
  }

  /// Logout user everywhere
  Future<void> logout() async {
    name = null;
    phone = null;
    role = null;
    token = null;

    await AuthService.clearToken();
    notifyListeners();
  }

  /// historical/compatibility alias used by some screens
  Future<void> reset() => logout();

  /// Update role manually if needed (rarely used)
  void setRole(String r) {
    role = r;
    notifyListeners();
  }

  /// Re-fetch current user from server (uses saved token)
  Future<void> refreshFromServer() async {
    if (token == null || token!.isEmpty) return;
    try {
      final resp = await AuthService.getCurrentUser();
      if (resp != null && resp['ok'] == true && resp['user'] is Map) {
        final u = resp['user'] as Map;
        name = u['name']?.toString();
        phone = u['phone']?.toString();
        role = u['role']?.toString();
        notifyListeners();
      }
    } catch (e) {
      // ignore errors here; caller can handle showing messages
    }
  }

  /// Small helper to convert to json-like map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'token': token,
    };
  }
}
