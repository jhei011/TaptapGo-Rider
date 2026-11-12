// TEST-ONLY FAKES: every HTTP answer below comes from a MockClient defined in this file.
// They mirror the JSON shapes of origin/production (ApiRiderJobController, ApiRiderTaskController,
// ApiAuthController, bootstrap/app.php LogisticsError rendering). The live backend is exercised
// separately by the ecosystem E2E script; nothing here shows a feature as working on its own.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/api.dart';
import 'package:taptap_go/main.dart' show ForcedLogoutWatcher;
import 'package:taptap_go/models/rider_job.dart';
import 'package:taptap_go/models/user.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/providers/courier_provider.dart';
import 'package:taptap_go/screens/courier/rider_job_screen.dart';

class _Fake {
  final requests = <http.Request>[];
  final Map<String, Object> routes;
  _Fake(this.routes);

  late final client = MockClient((r) async {
    requests.add(r);
    final key = '${r.method} ${r.url.path.replaceFirst('/api', '')}';
    final route = routes[key];
    if (route == null) return http.Response(jsonEncode({'message': 'Not found: $key'}), 404);
    if (route is Exception) throw route;
    final (status, body) = route is (int, Object) ? route : (200, route);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
  });

  List<http.Request> sent(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == '/api$path').toList();
}

Map<String, dynamic> _job({int id = 7, String type = 'pickup', String shipment = 'awaiting_pickup'}) => {
      'id': id, 'type': type, 'status': 'assigned', 'shipment_status': shipment, 'attempt': 1, 'max_attempts': 3,
      'tracking_number': 'TRK-1234567', 'order_id': 41, 'parcels': 1, 'pay': 30, 'earned': 0, 'result': null,
      'payment_method': 'cod', 'cod_amount': 500,
      'pickup': {'name': 'Seller Shop', 'address': 'Seller St.', 'area': 'Central'},
      'dropoff': {'name': 'Buyer', 'address': 'Buyer St.', 'area': 'Brgy. Central'},
      'items': [], 'times': {}, 'direction': 'forward',
    };

Map<String, dynamic> _user({String role = 'courier', String status = 'approved'}) =>
    {'id': 5, 'name': 'Rider One', 'email': 'rider@example.test', 'role': role, 'status': status};

Future<String?> _token() => const FlutterSecureStorage().read(key: 'auth_token');

/// Lets broadcast-stream events and queued futures run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    SharedPreferences.setMockInitialValues({});
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
  });

  group('Api error mapping', () {
    test('422 shows the first field error, not "(and N more errors)"', () {
      final r = http.Response(jsonEncode({
        'message': 'Choose why the delivery failed. (and 1 more error)',
        'errors': {'reason': ['Choose why the delivery failed.'], 'x': ['Other']},
      }), 422);
      expect(() => Api.parse(r), throwsA(isA<ApiError>()
          .having((e) => e.message, 'message', 'Choose why the delivery failed.')
          .having((e) => e.isValidation, 'isValidation', true)));
    });

    test('409 keeps the backend message and LogisticsError code', () {
      final r = http.Response(jsonEncode({'message': 'This parcel has already been picked up.', 'code': 'already_picked_up'}), 409);
      expect(() => Api.parse(r), throwsA(isA<ApiError>()
          .having((e) => e.errorCode, 'errorCode', 'already_picked_up')
          .having((e) => e.isConflict, 'isConflict', true)
          .having((e) => e.message, 'message', 'This parcel has already been picked up.')));
    });

    test('5xx JSON and HTML pages become a plain "server had a problem" message', () {
      expect(() => Api.parse(http.Response(jsonEncode({'message': 'Server Error'}), 500)),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('server had a problem'))));
      expect(() => Api.parse(http.Response('<!DOCTYPE html><html>oops</html>', 502)),
          throwsA(isA<ApiError>().having((e) => e.code, 'code', 502)));
    });

    test('404 from findOrFail does not leak the model name', () {
      final r = http.Response(jsonEncode({'message': r'No query results for model [App\Models\TaskAssignment] 9'}), 404);
      expect(() => Api.parse(r), throwsA(isA<ApiError>().having((e) => e.message, 'message', isNot(contains('App\\Models')))));
    });

    test('no connection is a NetworkError, never an ApiError (the offline queue relies on it)', () async {
      final fake = _Fake({'GET /courier/jobs': http.ClientException('Failed host lookup')});
      await http.runWithClient(() async {
        await expectLater(Api.get('/courier/jobs'), throwsA(isA<NetworkError>()));
      }, () => fake.client);
    });
  });

  group('Session handling', () {
    test('401 on any request ends the session: token removed, user cleared, reason shown', () async {
      final fake = _Fake({
        'GET /me': _user(),
        'GET /courier/jobs': (401, {'message': 'Unauthenticated.'}),
      });
      await http.runWithClient(() async {
        final auth = AuthProvider();
        await auth.boot();
        expect(auth.authenticated, isTrue);

        await expectLater(Api.get('/courier/jobs'), throwsA(isA<ApiError>()));
        await _settle();

        expect(auth.authenticated, isFalse);
        expect(auth.forcedLogouts, 1);
        expect(auth.error, contains('session has expired'));
        expect(await _token(), isNull);
        auth.dispose();
      }, () => fake.client);
    });

    test('403 suspension on a rider endpoint signs the rider out and revokes the token', () async {
      final fake = _Fake({
        'GET /me': _user(),
        'GET /courier/jobs': (403, {'message': 'Your rider account is suspended. Contact your logistics company.'}),
        'POST /logout': {'message': 'Logged out successfully'},
      });
      await http.runWithClient(() async {
        final auth = AuthProvider();
        await auth.boot();
        await expectLater(Api.get('/courier/jobs'), throwsA(isA<ApiError>()));
        await _settle();

        expect(auth.authenticated, isFalse);
        expect(auth.error, 'Your rider account is suspended. Contact your logistics company.');
        expect(fake.sent('POST', '/logout'), hasLength(1));
        auth.dispose();
      }, () => fake.client);
    });

    test("403 'not your assignment' is an ordinary refusal and keeps the rider signed in", () async {
      final fake = _Fake({
        'GET /me': _user(),
        'POST /rider/tasks/9/reject': (403, {'message': 'This assignment belongs to another rider.', 'code': 'not_your_assignment'}),
      });
      await http.runWithClient(() async {
        final auth = AuthProvider();
        await auth.boot();
        await expectLater(Api.post('/rider/tasks/9/reject', body: {'reason': 'x'}), throwsA(isA<ApiError>()));
        await _settle();
        expect(auth.authenticated, isTrue);
        expect(auth.forcedLogouts, 0);
        auth.dispose();
      }, () => fake.client);
    });

    test('a rider account that is not approved cannot sign in; its token is revoked at once', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fake = _Fake({
        'POST /login': {'token': 'new-token', 'user': _user(status: 'unverified')},
        'POST /logout': {'message': 'Logged out successfully'},
      });
      await http.runWithClient(() async {
        final auth = AuthProvider();
        final ok = await auth.login('rider@example.test', 'secret123');
        expect(ok, isFalse);
        expect(auth.authenticated, isFalse);
        expect(auth.error, contains('not approved'));
        expect(fake.sent('POST', '/logout').single.headers['Authorization'], 'Bearer new-token');
        expect(await _token(), isNull);
        auth.dispose();
      }, () => fake.client);
    });

    test('wrong password shows the server message and stores nothing', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fake = _Fake({'POST /login': (401, {'message': 'Invalid credentials'})});
      await http.runWithClient(() async {
        final auth = AuthProvider();
        expect(await auth.login('rider@example.test', 'wrong'), isFalse);
        expect(auth.error, 'Invalid credentials');
        expect(auth.forcedLogouts, 0); // a failed login is not a session ending
        expect(await _token(), isNull);
        auth.dispose();
      }, () => fake.client);
    });

    test('accessProblem: only approved riders and couriers may work', () {
      User u(String role, String status) => User.fromJson(_user(role: role, status: status));
      expect(AuthProvider.accessProblem(u('courier', 'approved')), isNull);
      expect(AuthProvider.accessProblem(u('linehaul', 'approved')), isNull);
      expect(AuthProvider.accessProblem(u('courier', 'suspended')), contains('suspended'));
      expect(AuthProvider.accessProblem(u('courier', 'pending_activation')), contains('activated'));
      expect(AuthProvider.accessProblem(u('buyer', 'unverified')), isNull); // not a rider account
    });

    test('opening the app with no connection keeps the rider signed in with the last confirmed user', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'test-token',
        'auth_user': jsonEncode(_user()),
      });
      final fake = _Fake({'GET /me': http.ClientException('Failed host lookup')});
      await http.runWithClient(() async {
        final auth = AuthProvider();
        await auth.boot();
        expect(auth.authenticated, isTrue);
        expect(auth.offline, isTrue);
        expect(auth.user!.name, 'Rider One');
        expect(await _token(), 'test-token');
        auth.dispose();
      }, () => fake.client);
    });

    test('a saved login the server rejects (401) is cleared on start', () async {
      final fake = _Fake({'GET /me': (401, {'message': 'Unauthenticated.'})});
      await http.runWithClient(() async {
        final auth = AuthProvider();
        await auth.boot();
        await _settle();
        expect(auth.status, AuthStatus.unauthenticated);
        expect(await _token(), isNull);
        auth.dispose();
      }, () => fake.client);
    });

    testWidgets('a forced logout stops the rider polling and returns to the login screen', (tester) async {
      final fake = _Fake({
        'GET /me': _user(),
        'GET /courier/jobs': (401, {'message': 'Unauthenticated.'}),
      });
      await http.runWithClient(() async {
        final auth = AuthProvider();
        final cp = CourierProvider();
        final nav = GlobalKey<NavigatorState>();
        await tester.runAsync(auth.boot);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: cp),
          ],
          child: ForcedLogoutWatcher(
            navigatorKey: nav,
            child: MaterialApp(
              navigatorKey: nav,
              home: const Text('courier home'),
              routes: {'/login': (_) => const Text('login screen')},
            ),
          ),
        ));
        expect(find.text('courier home'), findsOneWidget);

        await tester.runAsync(() async {
          await cp.loadJobs();
          await _settle();
        });
        await tester.pumpAndSettle();

        expect(find.text('login screen'), findsOneWidget);
        expect(cp.isOnline, isNull);
        expect(cp.activeJobs, isEmpty);
      }, () => fake.client);
    });
  });

  group('Decline an assigned job', () {
    test('canDecline: only before the rider holds the parcel', () {
      expect(RiderJob.fromJson(_job()).canDecline, isTrue);
      expect(RiderJob.fromJson(_job(type: 'delivery', shipment: 'at_hub')).canDecline, isTrue);
      expect(RiderJob.fromJson(_job(type: 'delivery', shipment: 'out_for_delivery')).canDecline, isFalse);
      expect(RiderJob.fromJson({..._job(), 'status': 'done', 'shipment_status': 'picked_up'}).canDecline, isFalse);
    });

    testWidgets("Can't take this job sends the reason to /rider/tasks/{id}/reject and leaves the job", (tester) async {
      final fake = _Fake({
        'GET /courier/jobs/7': _job(),
        'POST /rider/tasks/7/reject': {'message': 'Assignment rejected.', 'replayed': false, 'data': {'id': 7, 'status': 'rejected'}},
        'GET /courier/jobs': {'active': [], 'recent': []},
      });
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final cp = CourierProvider();
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: cp,
          child: MaterialApp(
            home: Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const RiderJobScreen(jobId: 7))),
              child: const Text('open job'),
            )))),
          ),
        ));
        await tester.tap(find.text('open job'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('declineJob')));
        await tester.tap(find.byKey(const Key('declineJob')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vehicle problem'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('declineConfirm')));
        await tester.pumpAndSettle();

        final sent = fake.sent('POST', '/rider/tasks/7/reject');
        expect(sent, hasLength(1));
        expect(jsonDecode(sent.single.body), {'reason': 'Vehicle problem'});
        expect(find.text('open job'), findsOneWidget); // back on the list
      }, () => fake.client);
    });

    testWidgets('a pickup refused with 409 reloads the job so the screen shows the server state', (tester) async {
      var loads = 0;
      var pickups = 0;
      final client = MockClient((r) async {
        if (r.method == 'GET' && r.url.path == '/api/courier/jobs/7') {
          loads++;
          final body = loads == 1 ? _job() : {..._job(), 'status': 'done', 'shipment_status': 'picked_up', 'result': 'Picked up'};
          return http.Response(jsonEncode(body), 200);
        }
        if (r.method == 'POST' && r.url.path == '/api/courier/jobs/7/pickup') {
          pickups++;
          return http.Response(jsonEncode({'message': 'This parcel has already been picked up.', 'code': 'already_picked_up'}), 409);
        }
        return http.Response(jsonEncode({'message': 'Not found'}), 404);
      });
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => CourierProvider(),
          child: const MaterialApp(home: RiderJobScreen(jobId: 7)),
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('trackingField')), 'TRK-1234567');
        await tester.tap(find.widgetWithText(OutlinedButton, 'Confirm pickup'));
        await tester.pumpAndSettle();

        expect(pickups, 1);
        expect(loads, 2);
        expect(find.textContaining('This job is finished'), findsOneWidget);
        expect(find.byKey(const Key('declineJob')), findsNothing);
      }, () => client);
    });
  });
}
