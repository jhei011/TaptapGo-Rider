import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/push_service.dart';
import 'package:taptap_go/core/theme/app_theme.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/providers/courier_provider.dart';
import 'package:taptap_go/screens/courier/courier_shell.dart';
import 'package:taptap_go/screens/courier/rider_job_screen.dart';
import 'package:taptap_go/screens/linehaul/linehaul_shell.dart';
import 'package:taptap_go/screens/linehaul/linehaul_trips_screen.dart';
import 'package:taptap_go/widgets/push_watcher.dart';

/// Push notifications: what a push is about, opening the tapped one in the right panel,
/// and the banner for pushes that arrive while the app is open.

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _trip() => {
      'id': 21, 'code': 'LH-261113-QCBUL', 'status': 'draft', 'status_label': 'Loading',
      'origin': {'id': 1, 'code': 'HUB-QC', 'name': 'QC Hub'},
      'destination': {'id': 2, 'code': 'HUB-BUL', 'name': 'Bulacan Hub'},
      'vehicle_plate': 'NAB4521', 'parcel_count': 1, 'received_count': 0, 'total_weight_kg': 2.5,
      'can_depart': true, 'can_arrive': false, 'created_at': '2026-11-13T01:00:00Z',
      'parcels': [
        {'tracking_number': 'TRK-2001001', 'weight_kg': 2.5, 'received': false},
      ],
    };

/// Answers every request the panels make with something harmless.
MockClient _api(List<String> calls) => MockClient((r) async {
      final key = '${r.method} ${r.url.path.replaceFirst('/api', '')}';
      calls.add(key);
      return switch (key) {
        'GET /linehaul/home' => _json({'name': 'Ernesto Villareal', 'duty_status': 'Loading'}),
        'GET /linehaul/trips' => _json([_trip()]),
        'GET /linehaul/trips/21' => _json(_trip()),
        _ => _json({'message': 'Not found'}, 404),
      };
    });

Widget _app(Widget home, {GlobalKey<ScaffoldMessengerState>? messengerKey}) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourierProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: messengerKey,
        routes: {
          '/login': (_) => const Scaffold(body: Text('Login screen')),
          '/courier/notifications': (_) => const Scaffold(body: Text('Notifications screen')),
        },
        onGenerateRoute: (s) => s.name == '/courier/job'
            ? MaterialPageRoute(builder: (_) => RiderJobScreen(jobId: s.arguments as int))
            : null,
        home: home,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    PushService.clear();
  });

  test('push data from the server says which job or trip it is about', () {
    final job = PushTap.fromData({'type': 'job', 'kind': 'offered', 'assignment_id': '42'})!;
    expect((job.type, job.kind, job.id, job.opensDetail), ('job', 'offered', 42, true));

    final trip = PushTap.fromData({'type': 'trip', 'kind': 'completed', 'trip_id': '7'})!;
    expect((trip.type, trip.id, trip.opensDetail), ('trip', 7, true));

    // A cancelled job is no longer the rider's: the notification list opens instead
    expect(PushTap.fromData({'type': 'job', 'kind': 'cancelled', 'assignment_id': '42'})!.opensDetail, isFalse);
    expect(PushTap.fromData({'type': 'something_else'}), isNull);
    expect(PushTap.fromData({}), isNull);
  });

  test('tests and demo builds never talk to Firebase', () {
    expect(PushService.enabled, isFalse);
  });

  test('each panel only takes the notifications meant for it', () {
    PushService.pendingTap.value = const PushTap(type: 'trip', id: 21);
    expect(PushService.takeTap('job'), isNull);
    expect(PushService.takeTap('trip')?.id, 21);
    expect(PushService.pendingTap.value, isNull);
  });

  testWidgets('a tapped trip notification opens that trip in the Linehaul panel', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    await http.runWithClient(() async {
      // The tap that started the app is waiting when the panel opens
      PushService.pendingTap.value = const PushTap(type: 'trip', kind: 'assigned', id: 21);
      await tester.pumpWidget(_app(const LinehaulShell()));
      await tester.pumpAndSettle();

      expect(find.byType(LinehaulTripDetailScreen), findsOneWidget);
      expect(find.text('TRK-2001001'), findsOneWidget);
      expect(PushService.pendingTap.value, isNull);

      // Tapped while the panel is open (app in the background)
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LinehaulTripDetailScreen), findsNothing);
      PushService.pendingTap.value = const PushTap(type: 'trip', kind: 'completed', id: 21);
      await tester.pumpAndSettle();
      expect(find.byType(LinehaulTripDetailScreen), findsOneWidget);
    }, () => _api(calls));
  });

  testWidgets('a rider\'s job notification is never opened by the Linehaul panel', (tester) async {
    await http.runWithClient(() async {
      PushService.pendingTap.value = const PushTap(type: 'job', kind: 'offered', id: 9);
      await tester.pumpWidget(_app(const LinehaulShell()));
      await tester.pumpAndSettle();
      expect(find.byType(RiderJobScreen), findsNothing);
      expect(find.byType(LinehaulTripDetailScreen), findsNothing);
    }, () => _api([]));
  });

  testWidgets('a tapped job notification opens the job; a cancelled one opens the notification list', (tester) async {
    final calls = <String>[];
    await http.runWithClient(() async {
      PushService.pendingTap.value = const PushTap(type: 'job', kind: 'offered', id: 9);
      await tester.pumpWidget(_app(const CourierShell()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RiderJobScreen), findsOneWidget);
      expect(calls, contains('GET /courier/jobs/9'));

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      PushService.pendingTap.value = const PushTap(type: 'job', kind: 'cancelled', id: 9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Notifications screen'), findsOneWidget);
    }, () => _api(calls));
  });

  testWidgets('a push while the app is open shows a banner; View opens it', (tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: PushWatcher(
        messengerKey: messengerKey,
        child: MaterialApp(scaffoldMessengerKey: messengerKey, home: const Scaffold(body: Text('Home'))),
      ),
    ));

    PushService.debugReceive(const PushMessage(
      title: 'New delivery',
      body: 'New delivery offered to you. Tracking TRK-1.',
      tap: PushTap(type: 'job', kind: 'offered', id: 9),
    ));
    await tester.pumpAndSettle();

    expect(find.text('New delivery'), findsOneWidget);
    expect(find.text('New delivery offered to you. Tracking TRK-1.'), findsOneWidget);
    await tester.tap(find.text('View'));
    expect(PushService.pendingTap.value?.id, 9);
  });
}
