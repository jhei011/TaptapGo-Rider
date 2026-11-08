import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/services/api.dart';
import '../core/services/auth_service.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  static const _riderIdleTimeout = Duration(minutes: 30);
  Timer? _idleTimer;

  User? _user;
  AuthStatus _status = AuthStatus.unknown;
  bool _loading = false;
  String? _error;

  User?       get user    => _user;
  AuthStatus  get status  => _status;
  bool        get loading => _loading;
  String?     get error   => _error;
  bool get authenticated  => _status == AuthStatus.authenticated;

  Future<void> boot() async {
    final token = await Api.getToken();
    if (token == null) { _status = AuthStatus.unauthenticated; notifyListeners(); return; }
    try {
      // The saved token's user, whatever the role (M9: stay logged in after the app is reopened)
      final d = await Api.get('/me') as Map<String, dynamic>;
      _user = User.fromJson(d);
      _status = AuthStatus.authenticated;
      resetIdleTimer();
      notifyListeners();
    } catch (_) {
      await Api.deleteToken();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final r = await AuthService.login(email, password);
      await Api.saveToken(r.token);
      _user = r.user;
      _status = AuthStatus.authenticated;
      resetIdleTimer();
      _loading = false; notifyListeners();
      return true;
    } on ApiError catch (e) {
      _error = e.message; _loading = false;
      _status = AuthStatus.unauthenticated; notifyListeners();
      return false;
    } catch (_) {
      _error = 'Connection error. Make sure the server is running.';
      _loading = false; _status = AuthStatus.unauthenticated; notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    await AuthService.logout();
    _user = null; _status = AuthStatus.unauthenticated; notifyListeners();
  }

  void updateUser(User u) { _user = u; notifyListeners(); }
  void clearError()       { _error = null; notifyListeners(); }

  void resetIdleTimer() {
    final role = _user?.role;
    if (role != 'courier' && role != 'linehaul') return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_riderIdleTimeout, _idleLogout);
  }

  Future<void> _idleLogout() async {
    _idleTimer = null;
    if (_status != AuthStatus.authenticated) return;
    final role = _user?.role;
    if (role != 'courier' && role != 'linehaul') return;
    await logout();
  }

  /// Sends a password-reset link. Returns null on success, error message on failure.
  Future<String?> forgotPassword(String email) async {
    try {
      await AuthService.forgotPassword(email);
      return null;
    } on ApiError catch (e) {
      // Normalise "email not found" variants from the backend into one friendly message
      final msg = e.message.toLowerCase();
      if (msg.contains('email') || msg.contains('user') || msg.contains('found') || msg.contains('exist')) {
        return "We can't find a user with that email address.";
      }
      return e.message;
    } catch (_) {
      return 'Connection error. Please try again.';
    }
  }
}
