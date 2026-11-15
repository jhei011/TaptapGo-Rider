import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/theme/app_theme.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/screens/auth/login_screen.dart';
import 'package:taptap_go/screens/linehaul/linehaul_shell.dart';
import 'package:taptap_go/screens/linehaul/linehaul_trips_screen.dart';

/// One login opens the Rider panel (role courier) or the Linehaul Courier panel (role linehaul), and the linehaul trip flow
/// (Loading → Start Trip → On the road → Arrived → Unloading) against a fake API.

Map<String, dynamic> _user(String role) =>
    {'id': 9, 'name': 'Ernesto Villareal', 'email': 'ernesto@example.com', 'role': role, 'status': 'approved'};

Map<String, dynamic> _trip(String status) => {
      'id': 21, 'code': 'LH-261113-QCBUL', 'status': status,
      'status_label': const {'draft': 'Loading', 'dispatched': 'On the road', 'receiving': 'Unloading'}[status],
      'origin': {'id': 1, 'code': 'HUB-QC', 'name': 'QC Hub'},
      'destination': {'id': 2, 'code': 'HUB-BUL', 'name': 'Bulacan Hub'},
      'vehicle_plate': 'NAB4521', 'parcel_count': 2, 'received_count': 0, 'total_weight_kg': 6.5,
      'can_depart': status == 'draft', 'can_arrive': status == 'dispatched',
      'created_at': '2026-11-13T01:00:00Z',
      'dispatched_at': status == 'draft' ? null : '2026-11-13T01:30:00Z',
      'arrived_at': status == 'receiving' ? '2026-11-13T03:00:00Z' : null,
      'closed_at': null,
      'parcels': [
        {'tracking_number': 'TRK-2001001', 'weight_kg': 2.5, 'received': false},
        {'tracking_number': 'TRK-2001002', 'weight_kg': 4, 'received': false},
      ],
    };

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Widget _app(Widget home) => ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        theme: AppTheme.light,
        // The test font draws every glyph as a full square; scale as the other login tests do
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
          child: w!,
        ),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Login screen')),
          '/courier': (_) => const Scaffold(body: Text('Rider panel')),
          '/linehaul': (_) => const Scaffold(body: Text('Linehaul panel')),
        },
        home: home,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'ernesto@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret@2026');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
  }

  // One login for everyone: no Rider / Linehaul choice, the account decides the panel.
  for (final (role, panel) in [('linehaul', 'Linehaul panel'), ('courier', 'Rider panel')]) {
    testWidgets('one login: a $role account opens the $panel, with no panel choice on the screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(const LoginScreen()));
        await tester.pump();
        expect(find.text('Welcome, Rider'), findsOneWidget);
        expect(find.text('Linehaul Courier'), findsNothing);

        await signIn(tester);
        expect(find.text(panel), findsOneWidget);
        expect(calls, ['POST /login']); // signed in once, never signed out again
      }, () => MockClient((r) async {
            final key = '${r.method} ${r.url.path.replaceFirst('/api', '')}';
            calls.add(key);
            return key == 'POST /login'
                ? _json({'token': 'tok', 'user': _user(role)})
                : _json({'message': 'Not found'}, 404);
          }));
    });
  }

  testWidgets('linehaul panel: home shows the current trip; the courier starts it and reports arriving', (tester) async {
    // A phone screen (the trip screen also has a Navigate button above Start Trip)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    var status = 'draft';
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const LinehaulShell()));
      await tester.pumpAndSettle();

      // Home: duty status and the current trip
      expect(find.text('Loading'), findsWidgets);
      expect(find.text('Current trips'), findsOneWidget);
      expect(find.text('LH-261113-QCBUL'), findsOneWidget);
      expect(find.text('HUB-QC'), findsOneWidget);
      expect(find.text('HUB-BUL'), findsOneWidget);
      expect(find.text('2 parcels'), findsOneWidget);
      expect(find.text('6.5 kg'), findsOneWidget);
      // No rider screens in this panel
      expect(find.text('Parcels'), findsNothing);
      expect(find.text('Earnings'), findsNothing);
      expect(calls.where((c) => c.contains('/courier/')), isEmpty);

      // Trips tab
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();
      expect(find.text('My Trips'), findsOneWidget);
      await tester.tap(find.text('LH-261113-QCBUL').last);
      await tester.pumpAndSettle();
      expect(find.text('TRK-2001001'), findsOneWidget);
      expect(find.text('Parcels on this trip (2)'), findsOneWidget);

      // Start Trip → On the road
      await tester.ensureVisible(find.text('Start Trip'));
      await tester.tap(find.text('Start Trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /linehaul/trips/21/depart'));
      expect(find.text('On the road'), findsOneWidget);
      expect(find.text('Trip LH-261113-QCBUL started. Drive safely.'), findsOneWidget);
      // Let the message time out (it covers the button in the small test window)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Arrived → Unloading, waiting for the hub to receive
      await tester.ensureVisible(find.text('Arrived at HUB-BUL'));
      await tester.tap(find.text('Arrived at HUB-BUL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /linehaul/trips/21/arrive'));
      expect(find.text('Unloading'), findsOneWidget);
      expect(find.textContaining('HUB-BUL is receiving the parcels'), findsOneWidget);

      // History tab
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('No completed trips yet'), findsOneWidget);
    }, () => MockClient((r) async {
          final key = '${r.method} ${r.url.path.replaceFirst('/api', '')}';
          calls.add(key);
          if (key == 'POST /linehaul/trips/21/depart') status = 'dispatched';
          if (key == 'POST /linehaul/trips/21/arrive') status = 'receiving';
          return switch (key) {
            'GET /linehaul/home' => _json({
                'name': 'Ernesto Villareal', 'logistics_company': 'Bilis Hatid', 'home_hub': null,
                'vehicle_type': 'Closed Van', 'plate_number': 'NAB4521', 'load_capacity_kg': 3000,
                'duty_status': status == 'draft' ? 'Loading' : 'On Trip',
              }),
            'GET /linehaul/trips' => _json(r.url.queryParameters['scope'] == 'history' ? [] : [_trip(status)]),
            'GET /linehaul/trips/21' => _json(_trip(status)),
            'POST /linehaul/trips/21/depart' =>
              _json({'message': 'Trip LH-261113-QCBUL started. Drive safely.', 'trip': _trip(status)}),
            'POST /linehaul/trips/21/arrive' =>
              _json({'message': 'Arrived at HUB-BUL. The hub will receive the parcels.', 'trip': _trip(status)}),
            _ => _json({'message': 'Forbidden'}, 403),
          };
        }));
  });

  Future<void> openTrip(WidgetTester tester, Map<String, dynamic> Function() trip) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    await tester.pumpWidget(_app(const LinehaulTripDetailScreen(tripId: 21)));
    await tester.pumpAndSettle();
  }

  testWidgets('trip load is shown against the truck capacity, in red with a note when over it', (tester) async {
    final trip = {..._trip('draft'), 'total_weight_kg': 3200.5, 'capacity_kg': 3000, 'over_capacity': true};
    await http.runWithClient(() async {
      await openTrip(tester, () => trip);
      expect(find.text('3200.5 of 3000 kg'), findsOneWidget);
      expect(find.byKey(const Key('overCapacity')), findsOneWidget);
    }, () => MockClient((r) async => _json(trip)));
  });

  testWidgets('within capacity: "6.5 of 3000 kg" and no warning', (tester) async {
    final trip = {..._trip('draft'), 'capacity_kg': 3000, 'over_capacity': false};
    await http.runWithClient(() async {
      await openTrip(tester, () => trip);
      expect(find.text('6.5 of 3000 kg'), findsOneWidget);
      expect(find.byKey(const Key('overCapacity')), findsNothing);
    }, () => MockClient((r) async => _json(trip)));
  });

  for (final (status, target) in [('draft', 'HUB-QC'), ('dispatched', 'HUB-BUL'), ('receiving', null)]) {
    testWidgets('Navigate goes to ${target ?? 'nowhere'} while the trip is $status', (tester) async {
      await http.runWithClient(() async {
        await openTrip(tester, () => _trip(status));
        if (target == null) {
          expect(find.byKey(const Key('navigateHub')), findsNothing);
        } else {
          expect(find.text('Navigate to $target'), findsOneWidget);
        }
      }, () => MockClient((r) async => _json(_trip(status))));
    });
  }

  testWidgets('an open trip refreshes by itself: a parcel added while loading appears without pulling down', (tester) async {
    var trip = _trip('draft');
    var gets = 0;
    await http.runWithClient(() async {
      await openTrip(tester, () => trip);
      expect(find.text('Parcels on this trip (2)'), findsOneWidget);

      // Hub staff load a third parcel
      trip = {
        ...trip,
        'parcel_count': 3,
        'parcels': [...(trip['parcels'] as List), {'tracking_number': 'TRK-2001003', 'weight_kg': 1, 'received': false}],
      };
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Parcels on this trip (3)'), findsOneWidget);
      expect(find.text('TRK-2001003'), findsOneWidget);
      expect(gets, greaterThanOrEqualTo(2));
    }, () => MockClient((r) async {
          gets++;
          return _json(trip);
        }));
  });
}
