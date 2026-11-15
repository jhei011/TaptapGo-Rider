import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/providers/auth_provider.dart';

/// The server now limits wrong passwords on the app login like the website (5, then a pause:
/// HTTP 429 with a message). The rider sees that message, is not signed in, and no token is
/// kept. (Server side: RiderModulesTest::test_app_login_is_rate_limited_like_the_website.)
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('a locked login shows the wait message and keeps no token', () async {
    await http.runWithClient(() async {
      final auth = AuthProvider();
      final ok = await auth.login('rider@example.test', 'whatever');
      expect(ok, isFalse);
      expect(auth.error, 'Too many login attempts. Please try again in 1 minute(s).');
      expect(auth.authenticated, isFalse);
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
    }, () => MockClient((r) async => http.Response.bytes(
        utf8.encode(jsonEncode({'message': 'Too many login attempts. Please try again in 1 minute(s).', 'code': 'too_many_attempts', 'retry_after': 60})),
        429, headers: {'content-type': 'application/json; charset=utf-8', 'retry-after': '60'})));
  });
}
