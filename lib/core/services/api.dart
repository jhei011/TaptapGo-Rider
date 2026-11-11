import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../demo/demo_api.dart' show kDemoMode;

/// The server answered, but refused or failed the request.
class ApiError implements Exception {
  final String message;

  /// HTTP status (401, 403, 404, 409, 422, 429, 5xx…).
  final int? code;

  /// The backend's machine-readable reason, when it sends one
  /// (LogisticsError codes such as `already_picked_up`, `otp_wrong`, `not_your_assignment`).
  final String? errorCode;

  ApiError(this.message, {this.code, this.errorCode});

  bool get isUnauthorized => code == 401;
  bool get isForbidden    => code == 403;
  bool get isNotFound     => code == 404;
  bool get isConflict     => code == 409;
  bool get isValidation   => code == 422;
  bool get isServerError  => code != null && code! >= 500;

  @override String toString() => message;
}

/// The request got no answer: no connection, host not found, or timed out.
/// Deliberately not an [ApiError]: callers that keep work for later (the offline
/// delivery queue) tell "the server refused" apart from "nothing arrived".
class NetworkError implements Exception {
  final String message;
  const NetworkError([this.message = 'No internet connection. Check your connection and try again.']);
  @override String toString() => message;
}

/// Why the app signed the rider out without being asked to.
enum SessionEndReason { expired, accessRevoked, idle }

class SessionEnded {
  final SessionEndReason reason;
  final String message;
  const SessionEnded(this.reason, this.message);
}

class Api {
  static const _ss = FlutterSecureStorage();
  static const _userKey = 'auth_user';

  static final _sessionEnded = StreamController<SessionEnded>.broadcast();

  /// Fires when the server rejects the saved login (401), or rejects a rider whose
  /// account is no longer active (403 on rider endpoints). AuthProvider listens.
  static Stream<SessionEnded> get sessionEnded => _sessionEnded.stream;

  // The demo build has no account, so it counts as logged in without touching the phone's saved login
  static Future<String?> getToken() async {
    if (kDemoMode) return 'demo-token';
    return _ss.read(key: AppConstants.tokenKey);
  }
  static Future<void> saveToken(String t) => _ss.write(key: AppConstants.tokenKey, value: t);
  static Future<void> deleteToken() => _ss.delete(key: AppConstants.tokenKey);

  /// The last user the server confirmed, so the app can open without a connection.
  static Future<Map<String, dynamic>?> readSavedUser() async {
    try {
      final raw = await _ss.read(key: _userKey);
      return raw == null ? null : (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
  static Future<void> saveUser(Map<String, dynamic> user) => _ss.write(key: _userKey, value: jsonEncode(user));
  static Future<void> deleteSavedUser() => _ss.delete(key: _userKey);

  static Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Uri _url(String path, [Map<String, String>? q]) {
    final u = Uri.parse('${AppConstants.apiBase}$path');
    return q != null ? u.replace(queryParameters: q) : u;
  }

  /// Sends a request and turns every outcome into data, an [ApiError] or a [NetworkError].
  static Future<dynamic> _send(String path, Future<http.Response> Function(String? token) call,
      {bool auth = true}) async {
    final token = auth ? await getToken() : null;
    http.Response r;
    try {
      r = await call(token);
    } on TimeoutException {
      throw const NetworkError('The server took too long to answer. Check your connection and try again.');
    } on SocketException {
      throw const NetworkError();
    } on http.ClientException {
      throw const NetworkError();
    } on HandshakeException {
      throw const NetworkError('A secure connection to the server could not be made.');
    }
    try {
      return parse(r);
    } on ApiError catch (e) {
      _reportSessionProblem(path, e, sentToken: token != null);
      rethrow;
    }
  }

  /// 401 with a token: the login is no longer valid. 403 on rider endpoints (except
  /// "not your assignment"): the rider account was suspended or is not a rider account.
  static void _reportSessionProblem(String path, ApiError e, {required bool sentToken}) {
    if (!sentToken || kDemoMode) return;
    if (e.isUnauthorized) {
      _sessionEnded.add(const SessionEnded(SessionEndReason.expired, 'Your session has expired. Please log in again.'));
    } else if (e.isForbidden && e.errorCode != 'not_your_assignment' && _isRiderPath(path)) {
      _sessionEnded.add(SessionEnded(SessionEndReason.accessRevoked,
          e.message == 'Forbidden' ? 'This account cannot use the rider app. Contact your logistics company.' : e.message));
    }
  }

  static bool _isRiderPath(String path) =>
      path.startsWith('/courier/') || path.startsWith('/linehaul/') ||
      (path.startsWith('/rider/') && !path.startsWith('/rider/activat') && !path.startsWith('/rider/resend-activation'));

  /// Decodes a response; throws [ApiError] with a message the rider can act on.
  static dynamic parse(http.Response r) {
    final body = r.body.isEmpty ? '{}' : r.body;
    // Laravel answered with an HTML page (a crash or a proxy error page), not JSON
    if (body.trimLeft().startsWith('<!') || body.trimLeft().startsWith('<html')) {
      throw ApiError(_fallback(r.statusCode), code: r.statusCode);
    }
    dynamic d;
    try { d = jsonDecode(body); } catch (_) { throw ApiError('Invalid server response.', code: r.statusCode); }
    if (r.statusCode >= 200 && r.statusCode < 300) return d;
    throw ApiError(_message(r.statusCode, d), code: r.statusCode,
        errorCode: d is Map && d['code'] is String ? d['code'] as String : null);
  }

  static String _message(int status, dynamic d) {
    final server = d is Map && d['message'] is String ? (d['message'] as String).trim() : '';
    // 422: show the first field error instead of "… (and 2 more errors)"
    if (status == 422 && d is Map && d['errors'] is Map) {
      for (final v in (d['errors'] as Map).values) {
        if (v is List && v.isNotEmpty && v.first is String) return v.first as String;
      }
    }
    if (status >= 500) return _fallback(status);
    // findOrFail() names the database model; never show that
    if (status == 404 && (server.isEmpty || server.startsWith('No query results'))) {
      return _fallback(404);
    }
    if (server.isNotEmpty) return server;
    return _fallback(status);
  }

  static String _fallback(int status) => switch (status) {
        401 => 'Your session has expired. Please log in again.',
        403 => 'You are not allowed to do this.',
        404 => 'Not found. It may have been removed or given to someone else.',
        409 => 'This was already changed. Refresh to see the latest.',
        422 => 'Some details are not valid. Check them and try again.',
        429 => 'Too many attempts. Wait a moment and try again.',
        >= 500 => 'The server had a problem (HTTP $status). Please try again in a moment.',
        _ => 'Request failed (HTTP $status).',
      };

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(path, (t) => http.get(_url(path, query), headers: _headers(token: t))
          .timeout(const Duration(seconds: 30)));

  static Future<dynamic> post(String path, {dynamic body, bool auth = true}) =>
      _send(path, (t) => http.post(_url(path), headers: _headers(token: t), body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 30)), auth: auth);

  static Future<dynamic> put(String path, {dynamic body}) =>
      _send(path, (t) => http.put(_url(path), headers: _headers(token: t), body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 30)));

  static Future<dynamic> patch(String path, {dynamic body}) =>
      _send(path, (t) => http.patch(_url(path), headers: _headers(token: t), body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 30)));

  static Future<dynamic> delete(String path) =>
      _send(path, (t) => http.delete(_url(path), headers: _headers(token: t))
          .timeout(const Duration(seconds: 30)));

  /// Multipart POST (for file uploads — proof-of-delivery photo, rider documents)
  static Future<dynamic> postMultipart(String path, {
    required Map<String, String> fields,
    Map<String, File>? files,
    String method = 'POST',
  }) =>
      _send(path, (token) async {
        final req = http.MultipartRequest(method, _url(path));
        req.headers['Accept'] = 'application/json';
        if (token != null) req.headers['Authorization'] = 'Bearer $token';
        req.fields.addAll(fields);
        if (files != null) {
          for (final e in files.entries) {
            req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
          }
        }
        final streamed = await req.send().timeout(const Duration(seconds: 60));
        return http.Response.fromStream(streamed);
      });
}
