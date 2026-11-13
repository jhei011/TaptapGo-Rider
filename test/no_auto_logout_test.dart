import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/api.dart';
import 'package:taptap_go/providers/auth_provider.dart';

/// Riders and linehaul couriers are not signed out for being inactive: only by logging out,
/// an expired login, or their company suspending or removing them.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    SharedPreferences.setMockInitialValues({});
  });

  for (final role in ['courier', 'linehaul']) {
    test('a $role left idle for 2 hours is still signed in', () {
      final client = MockClient((r) async => http.Response(
          jsonEncode({'id': 5, 'name': 'Rider One', 'email': 'r@example.test', 'role': role, 'status': 'approved'}), 200,
          headers: {'content-type': 'application/json'}));
      fakeAsync((clock) {
        late AuthProvider auth;
        http.runWithClient(() {
          auth = AuthProvider();
          auth.boot();
        }, () => client);
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 1));
        expect(auth.authenticated, isTrue);

        clock.elapse(const Duration(hours: 2));
        expect(auth.authenticated, isTrue);
        expect(auth.forcedLogouts, 0);
        expect(auth.error, isNull);
      });
    });
  }

  test('a login the server ends (expired) still signs the rider out', () async {
    final auth = AuthProvider();
    await http.runWithClient(() => auth.boot(), () => MockClient((r) async => http.Response(
        jsonEncode({'id': 5, 'name': 'Rider One', 'email': 'r@example.test', 'role': 'courier', 'status': 'approved'}), 200,
        headers: {'content-type': 'application/json'})));
    expect(auth.authenticated, isTrue);

    await http.runWithClient(() async {
      await expectLater(Api.get('/courier/jobs'), throwsA(isA<ApiError>()));
    }, () => MockClient((r) async => http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401,
        headers: {'content-type': 'application/json'})));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(auth.authenticated, isFalse);
  });
}
