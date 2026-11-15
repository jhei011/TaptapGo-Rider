import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/pending_delivery_store.dart';
import 'package:taptap_go/core/services/rider_idle_policy.dart';
import 'package:taptap_go/models/user.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/widgets/confirm_logout.dart';
import 'package:taptap_go/widgets/rider_idle_watcher.dart';

/// The rider's 30-minute idle logout, which must never interrupt a delivery.
/// SIMULATED TIME: these tests move a fake clock (fake_async + package:clock); no test waits
/// 30 real minutes. The "server" is a stand-in function or a MockClient (labelled per test).
const thirty = Duration(minutes: 30);

/// A policy whose server answer the test controls.
class _Harness {
  WorkCheck work = WorkCheck.none;
  int checks = 0;
  int logouts = 0;
  bool throwOnCheck = false;
  late final RiderIdlePolicy policy = RiderIdlePolicy(
    timeout: thirty,
    checkWork: () async {
      checks++;
      if (throwOnCheck) throw Exception('no connection');
      return work;
    },
    onIdleTimeout: () async => logouts++,
  );
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    SharedPreferences.setMockInitialValues({});
  });

  group('Session scenarios (simulated time)', () {
    test('1. no assignment, inactive 30 minutes: signed out (not a minute earlier)', () {
      fakeAsync((t) {
        final h = _Harness()..policy.start();
        t.elapse(const Duration(minutes: 29, seconds: 59));
        expect(h.logouts, 0);
        t.elapse(const Duration(seconds: 2));
        t.flushMicrotasks();
        expect(h.checks, 1, reason: 'the server was asked first');
        expect(h.logouts, 1);
        expect(h.policy.running, isFalse, reason: 'no timer left after the logout');
      });
    });

    test('touching the screen restarts the 30 minutes', () {
      fakeAsync((t) {
        final h = _Harness()..policy.start();
        t.elapse(const Duration(minutes: 25));
        h.policy.activity();
        t.elapse(const Duration(minutes: 25));
        expect(h.logouts, 0);
        t.elapse(const Duration(minutes: 6));
        t.flushMicrotasks();
        expect(h.logouts, 1);
      });
    });

    test('2. an assigned parcel and 2 hours without touching the app: still signed in', () {
      fakeAsync((t) {
        final h = _Harness()..work = WorkCheck.active..policy.start();
        t.elapse(const Duration(hours: 2));
        t.flushMicrotasks();
        expect(h.logouts, 0);
        expect(h.policy.protectingWork, isTrue);
        expect(h.checks, greaterThan(1), reason: 'checked again every few minutes while working');
      });
    });

    for (final (n, what) in [
      (3, 'the app in the background (delivering) for more than 30 minutes'),
      (4, 'switching to Google Maps during the delivery'),
      (5, 'locking the phone during the delivery'),
      (6, 'taking proof-of-delivery photos (the camera app is in front)'),
    ]) {
      test('$n. $what: still signed in, and no server check while away', () {
        fakeAsync((t) {
          final h = _Harness()..work = WorkCheck.active..policy.start();
          t.elapse(const Duration(minutes: 5));
          h.policy.paused(); // Android: the app goes to the background
          t.elapse(const Duration(minutes: 90));
          t.flushMicrotasks();
          expect(h.checks, 0, reason: 'nothing runs while in the background');
          h.policy.resumed();
          t.flushMicrotasks();
          expect(h.checks, 1, reason: 'back in the app, the server is asked');
          expect(h.logouts, 0, reason: 'the delivery is still assigned');
        });
      });
    }

    test('3b. even with NO assignment, being in the background never signs out by itself', () {
      fakeAsync((t) {
        final h = _Harness()..policy.start();
        h.policy.paused();
        t.elapse(const Duration(hours: 3));
        t.flushMicrotasks();
        expect(h.logouts, 0, reason: 'decided only when the rider is back in the app');
        h.policy.resumed();
        t.flushMicrotasks();
        expect(h.logouts, 1, reason: '30+ minutes without activity and the server says no work');
      });
    });

    test('7. internet lost then back during a delivery: never treated as "no delivery"', () {
      fakeAsync((t) {
        final h = _Harness()..work = WorkCheck.active..policy.start();
        t.elapse(thirty);
        t.flushMicrotasks();
        h.throwOnCheck = true; // no connection
        t.elapse(const Duration(minutes: 40));
        t.flushMicrotasks();
        expect(h.logouts, 0);
        h.work = WorkCheck.unknown; // server error
        h.throwOnCheck = false;
        t.elapse(const Duration(minutes: 20));
        t.flushMicrotasks();
        expect(h.logouts, 0);
        h.work = WorkCheck.active; // back online, delivery still assigned
        t.elapse(const Duration(minutes: 10));
        t.flushMicrotasks();
        expect(h.logouts, 0);
        expect(h.policy.running, isTrue);
      });
    });

    test('7b. offline from the start (never got an answer): never signed out', () {
      fakeAsync((t) {
        final h = _Harness()..throwOnCheck = true..policy.start();
        t.elapse(const Duration(hours: 4));
        t.flushMicrotasks();
        expect(h.logouts, 0);
      });
    });

    test('8. all deliveries done, then idle: a fresh 30 minutes, then signed out', () {
      fakeAsync((t) {
        final h = _Harness()..work = WorkCheck.active..policy.start();
        t.elapse(const Duration(hours: 1));
        t.flushMicrotasks();
        h.work = WorkCheck.none; // the last delivery was closed
        t.elapse(const Duration(minutes: 5)); // next server check sees it
        t.flushMicrotasks();
        expect(h.logouts, 0, reason: 'not signed out the moment the work ends');
        t.elapse(const Duration(minutes: 29));
        t.flushMicrotasks();
        expect(h.logouts, 0);
        t.elapse(const Duration(minutes: 2));
        t.flushMicrotasks();
        expect(h.logouts, 1);
      });
    });

    test('9. several assignments: protected until the last one is closed', () {
      fakeAsync((t) {
        var open = 3;
        var logouts = 0;
        RiderIdlePolicy(
          timeout: thirty,
          checkWork: () async => open > 0 ? WorkCheck.active : WorkCheck.none,
          onIdleTimeout: () async => logouts++,
        ).start();
        for (var i = 0; i < 3; i++) {
          t.elapse(const Duration(minutes: 40));
          t.flushMicrotasks();
          expect(logouts, 0, reason: '$open assignment(s) still open');
          open--;
        }
        t.elapse(const Duration(minutes: 5));
        t.flushMicrotasks();
        t.elapse(const Duration(minutes: 31));
        t.flushMicrotasks();
        expect(logouts, 1);
      });
    });

    test('only one timer: many touches and resumes never start extra checks', () {
      fakeAsync((t) {
        final h = _Harness()..work = WorkCheck.active..policy.start();
        for (var i = 0; i < 200; i++) {
          h.policy.activity();
          h.policy.resumed();
          t.elapse(const Duration(seconds: 1));
        }
        h.policy.start(); // starting twice does nothing
        t.elapse(thirty);
        t.flushMicrotasks();
        expect(h.checks, 1, reason: 'one timer, one check');
      });
    });
  });

  group('What counts as work: the server is asked (MockClient stands in for it)', () {
    Map<String, dynamic> job(int id) => {
          'id': id, 'type': 'delivery', 'status': 'assigned', 'shipment_status': 'out_for_delivery', 'attempt': 1,
          'max_attempts': 3, 'tracking_number': 'TT$id', 'order_id': id, 'parcels': 1, 'pay': 24, 'earned': 0,
          'payment_method': 'cod', 'cod_amount': 700, 'pickup': {'name': 'S', 'address': 'a', 'area': 'a'},
          'dropoff': {'name': 'B', 'address': 'b', 'area': 'b'}, 'items': [], 'times': {},
        };

    Future<WorkCheck> ask(MockClient server) => http.runWithClient(riderWorkCheck, () => server);

    test('an active job on the server: active', () async {
      expect(await ask(MockClient((r) async => r.url.path.endsWith('/courier/jobs')
          ? _json({'active': [job(1)], 'recent': []}) : _json([]))), WorkCheck.active);
    });
    test('an offer waiting for an answer: active', () async {
      expect(await ask(MockClient((r) async => r.url.path.endsWith('/courier/jobs')
          ? _json({'active': [], 'recent': []}) : _json([{'id': 9, 'seconds_left': 30, 'job': job(9)}]))), WorkCheck.active);
    });
    test('nothing on the server: none', () async {
      expect(await ask(MockClient((r) async => r.url.path.endsWith('/courier/jobs')
          ? _json({'active': [], 'recent': [job(2)..['status'] = 'done']}) : _json([]))), WorkCheck.none);
    });
    test('server error or no connection: unknown (never "none")', () async {
      expect(await ask(MockClient((r) async => _json({'message': 'boom'}, 500))), WorkCheck.unknown);
      expect(await ask(MockClient((r) async => throw http.ClientException('offline'))), WorkCheck.unknown);
    });
    test('a delivery saved on the phone and not sent yet: active, even if the server says nothing', () async {
      await PendingDeliveryStore.save([
        PendingDelivery(jobId: 1, trackingNumber: 'TT1', otp: '123456', codAmount: '700.00', photoPath: '/x.jpg', savedAt: DateTime(2026)),
      ]);
      expect(await ask(MockClient((r) async => r.url.path.endsWith('/courier/jobs')
          ? _json({'active': [], 'recent': []}) : _json([]))), WorkCheck.active);
    });
    test('linehaul: an active trip is active, no trip is none, no answer is unknown', () async {
      Future<WorkCheck> lh(MockClient s) => http.runWithClient(linehaulWorkCheck, () => s);
      expect(await lh(MockClient((r) async => _json([{'id': 1, 'status': 'in_transit'}]))), WorkCheck.active);
      expect(await lh(MockClient((r) async => _json([]))), WorkCheck.none);
      expect(await lh(MockClient((r) async => _json({}, 503))), WorkCheck.unknown);
    });
  });

  group('In the app', () {
    Future<AuthProvider> signedIn(WidgetTester tester, String role) async {
      final auth = AuthProvider()
        ..updateUser(User.fromJson({'id': 5, 'name': 'Rider', 'email': 'r@x.test', 'role': role, 'status': 'approved'}));
      return auth;
    }

    testWidgets('the watcher follows the app lifecycle (Maps, lock screen) and stops on logout', (tester) async {
      final calls = <String>[];
      final auth = await signedIn(tester, 'courier');
      // updateUser alone does not mark it authenticated; boot the saved login against a stand-in server
      await http.runWithClient(() async {
        await tester.runAsync(auth.boot);
      }, () => MockClient((r) async => _json({'id': 5, 'name': 'Rider', 'email': 'r@x.test', 'role': 'courier', 'status': 'approved'})));
      expect(auth.authenticated, isTrue);
      late RiderIdlePolicy policy;
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: RiderIdleWatcher(
          policyFor: (_) => policy = _RecordingPolicy(calls),
          child: const MaterialApp(home: Scaffold(body: Text('Rider panel'))),
        ),
      ));
      expect(calls, ['start']);
      await tester.tap(find.text('Rider panel'));
      expect(calls.last, 'activity');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(calls.last, 'paused');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(calls.last, 'resumed');
      expect(policy, isNotNull);
      // 11. Suspended by an admin during a delivery: the server answers 403 on a rider endpoint,
      // the session ends at once (protection does not keep access) and the idle timer stops
      await http.runWithClient(() async {
        await tester.runAsync(() async {
          try {
            await http.runWithClient(() => riderWorkCheck(), () => MockClient((r) async => _json({'message': 'Your rider account is suspended. Contact your logistics company.'}, 403)));
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
      }, () => MockClient((r) async => _json({'message': 'ok'})));
      await tester.pump();
      expect(auth.authenticated, isFalse, reason: 'suspension ends the session even during a delivery');
      expect(auth.error, contains('suspended'));
      expect(calls.last, 'stop');
    });

    testWidgets('buyer and seller accounts cannot use TaptapGo (rider-only app)', (tester) async {
      for (final role in ['buyer', 'seller', 'admin', 'logistics']) {
        expect(AuthProvider.accessProblem(User.fromJson({'id': 1, 'name': 'x', 'email': 'x@x.test', 'role': role, 'status': 'approved'})),
            contains('TaptapGo is for riders'));
      }
      for (final role in ['courier', 'linehaul']) {
        expect(AuthProvider.accessProblem(User.fromJson({'id': 1, 'name': 'x', 'email': 'x@x.test', 'role': role, 'status': 'approved'})), isNull);
      }
    });

    Future<bool?> logoutWith(WidgetTester tester, {required int unsent, required WorkCheck work, String? tap}) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: TextButton(
        onPressed: () async => result = await confirmRiderLogout(c, unsentDeliveries: unsent, checkWork: () async => work, message: 'Bye'),
        child: const Text('Log out'),
      )))));
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      if (tap != null) {
        await tester.tap(find.text(tap).last);
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('12a. manual logout with unsent deliveries is blocked', (tester) async {
      final r = await logoutWith(tester, unsent: 2, work: WorkCheck.none);
      expect(find.text('Deliveries not sent yet'), findsOneWidget);
      expect(find.textContaining('2 deliveries are saved on this phone'), findsOneWidget);
      expect(find.text('Log out anyway'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(r, isNull); // not finished yet when checked above
    });

    testWidgets('12b. manual logout with an active job warns and needs "Log out anyway"', (tester) async {
      await logoutWith(tester, unsent: 0, work: WorkCheck.active);
      expect(find.text('You still have active work'), findsOneWidget);
      expect(find.textContaining('does not cancel it or give it back'), findsOneWidget);
      expect(find.text('Log out anyway'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('You still have active work'), findsNothing);
    });

    testWidgets('12c. server unreachable at logout: still warned (never assumed "no work")', (tester) async {
      await logoutWith(tester, unsent: 0, work: WorkCheck.unknown);
      expect(find.text('You still have active work'), findsOneWidget);
      expect(find.textContaining('could not be reached'), findsOneWidget);
    });

    testWidgets('12d. no work: the normal "Log out?"', (tester) async {
      await logoutWith(tester, unsent: 0, work: WorkCheck.none);
      expect(find.text('Log out?'), findsOneWidget);
      expect(find.text('Log out anyway'), findsNothing);
    });
  });
}

/// Records what the watcher asks the policy to do.
class _RecordingPolicy extends RiderIdlePolicy {
  final List<String> calls;
  _RecordingPolicy(this.calls) : super(checkWork: () async => WorkCheck.active, onIdleTimeout: () async {});
  @override
  void start() => calls.add('start');
  @override
  void stop() => calls.add('stop');
  @override
  void activity() => calls.add('activity');
  @override
  void paused() {
    if (calls.last != 'paused') calls.add('paused');
  }
  @override
  void resumed() => calls.add('resumed');
}
