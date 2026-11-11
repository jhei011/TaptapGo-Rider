import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/services/api.dart';
import '../core/services/auth_service.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  static const _riderIdleTimeout = Duration(minutes: 30);
  Timer? _idleTimer;
  StreamSubscription<SessionEnded>? _sessionWatch;

  User? _user;
  AuthStatus _status = AuthStatus.unknown;
  bool _loading = false;
  String? _error;
  bool _offline = false;
  int _forcedLogouts = 0;
  bool _ending = false;

  AuthProvider() {
    _sessionWatch = Api.sessionEnded.listen((e) => _endSession(e.message, revoke: e.reason == SessionEndReason.accessRevoked));
  }

  User?       get user    => _user;
  AuthStatus  get status  => _status;
  bool        get loading => _loading;
  String?     get error   => _error;
  bool get authenticated  => _status == AuthStatus.authenticated;

  /// The session was restored from the phone because the server could not be reached.
  bool get offline => _offline;

  /// Goes up each time the app signs the rider out on its own; the app root then
  /// stops the rider's timers and returns to the login screen.
  int get forcedLogouts => _forcedLogouts;

  static bool _isRider(String? role) => role == 'courier' || role == 'linehaul';

  /// Riders and couriers may only work while their logistics company has them approved;
  /// the server refuses the rider endpoints otherwise. Null when [u] may use the app.
  static String? accessProblem(User u) {
    if (!_isRider(u.role) || u.status == 'approved') return null;
    return switch (u.status) {
      'pending_activation' => 'Your account has not been activated yet. Open the activation link in your email.',
      'pending'            => 'Your rider account is waiting for approval by your logistics company.',
      'suspended'          => 'Your rider account is suspended. Contact your logistics company.',
      'rejected'           => 'Your rider application was rejected.',
      _                    => 'Your rider account is not approved yet. Contact your logistics company.',
    };
  }

  Future<void> boot() async {
    final token = await Api.getToken();
    if (token == null) { _status = AuthStatus.unauthenticated; notifyListeners(); return; }
    try {
      // The saved token's user, whatever the role (M9: stay logged in after the app is reopened)
      final d = await Api.get('/me') as Map<String, dynamic>;
      final u = User.fromJson(d);
      if (accessProblem(u) case final problem?) {
        await _endSession(problem, revoke: true, forced: false);
        return;
      }
      _user = u;
      _offline = false;
      await Api.saveUser(d).catchError((_) {});
      _status = AuthStatus.authenticated;
      resetIdleTimer();
      notifyListeners();
    } on ApiError catch (_) {
      // The server refused the saved login (expired or revoked token, or a deleted account)
      await _clearSaved();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (_) {
      // No connection: keep the login and open with the last confirmed user, so a rider
      // can still finish deliveries offline (they are queued and sent later).
      final saved = await Api.readSavedUser();
      final u = saved == null ? null : User.fromJson(saved);
      if (u != null && accessProblem(u) == null) {
        _user = u;
        _offline = true;
        _status = AuthStatus.authenticated;
        resetIdleTimer();
      } else {
        _status = AuthStatus.unauthenticated;
        _error = 'No connection to the server. Check your internet and log in again.';
      }
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final r = await AuthService.login(email, password);
      if (accessProblem(r.user) case final problem?) {
        // Do not keep a token the rider cannot work with; revoke it on the server.
        await Api.saveToken(r.token);
        await AuthService.logout();
        _error = problem; _loading = false;
        _status = AuthStatus.unauthenticated; notifyListeners();
        return false;
      }
      await Api.saveToken(r.token);
      await Api.saveUser(r.rawUser).catchError((_) {});
      _user = r.user;
      _offline = false;
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
    await Api.deleteSavedUser().catchError((_) {});
    _user = null; _offline = false; _status = AuthStatus.unauthenticated; notifyListeners();
  }

  void updateUser(User u) { _user = u; notifyListeners(); }
  void clearError()       { _error = null; notifyListeners(); }

  void resetIdleTimer() {
    final role = _user?.role;
    if (!_isRider(role)) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_riderIdleTimeout, _idleLogout);
  }

  Future<void> _idleLogout() async {
    _idleTimer = null;
    if (_status != AuthStatus.authenticated) return;
    if (!_isRider(_user?.role)) return;
    await _endSession('You were logged out after 30 minutes without activity.', revoke: true);
  }

  /// Signs out without the rider asking: [revoke] also ends the token on the server
  /// (best effort); [forced] tells the app root to leave the current screen.
  Future<void> _endSession(String message, {required bool revoke, bool forced = true}) async {
    if (_ending || (forced && _status != AuthStatus.authenticated)) return;
    _ending = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    try {
      if (revoke) {
        await AuthService.logout();
      } else {
        await Api.deleteToken().catchError((_) {});
      }
      await Api.deleteSavedUser().catchError((_) {});
    } finally {
      _ending = false;
    }
    _user = null;
    _offline = false;
    _status = AuthStatus.unauthenticated;
    // Shown in the login screen's error banner
    _error = message;
    if (forced) _forcedLogouts++;
    notifyListeners();
  }

  Future<void> _clearSaved() async {
    await Api.deleteToken().catchError((_) {});
    await Api.deleteSavedUser().catchError((_) {});
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _sessionWatch?.cancel();
    super.dispose();
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
