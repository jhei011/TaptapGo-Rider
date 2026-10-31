import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class ApiError implements Exception {
  final String message;
  final int? code;
  ApiError(this.message, {this.code});
  @override String toString() => message;
}

class Api {
  static const _ss = FlutterSecureStorage();

  static Future<String?> getToken() => _ss.read(key: AppConstants.tokenKey);
  static Future<void> saveToken(String t) => _ss.write(key: AppConstants.tokenKey, value: t);
  static Future<void> deleteToken() => _ss.delete(key: AppConstants.tokenKey);

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (auth) {
      final t = await getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Uri _url(String path, [Map<String, String>? q]) {
    final u = Uri.parse('${AppConstants.apiBase}$path');
    return q != null ? u.replace(queryParameters: q) : u;
  }

  static dynamic _parse(http.Response r) {
    final body = r.body.isEmpty ? '{}' : r.body;
    // If Laravel returned HTML (error page), give a clear message
    if (body.trimLeft().startsWith('<!') || body.trimLeft().startsWith('<html')) {
      throw ApiError('Server error (HTTP ${r.statusCode}). Check Laravel is running.', code: r.statusCode);
    }
    dynamic d;
    try { d = jsonDecode(body); } catch (_) { throw ApiError('Invalid server response.', code: r.statusCode); }
    if (r.statusCode >= 200 && r.statusCode < 300) return d;
    final msg = d is Map ? (d['message'] ?? 'Request failed') : 'Request failed';
    throw ApiError(msg.toString(), code: r.statusCode);
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final r = await http.get(_url(path, query), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    return _parse(r);
  }

  static Future<dynamic> post(String path, {dynamic body, bool auth = true}) async {
    final r = await http.post(_url(path),
        headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 30));
    return _parse(r);
  }

  static Future<dynamic> put(String path, {dynamic body}) async {
    final r = await http.put(_url(path),
        headers: await _headers(), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 30));
    return _parse(r);
  }

  static Future<dynamic> patch(String path, {dynamic body}) async {
    final r = await http.patch(_url(path),
        headers: await _headers(), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 30));
    return _parse(r);
  }

  static Future<dynamic> delete(String path) async {
    final r = await http.delete(_url(path), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    return _parse(r);
  }

  /// Multipart POST (for file uploads — product image, valid ID)
  static Future<dynamic> postMultipart(String path, {
    required Map<String, String> fields,
    Map<String, File>? files,
    String method = 'POST',
  }) async {
    final token = await getToken();
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
    final r = await http.Response.fromStream(streamed);
    return _parse(r);
  }
}
