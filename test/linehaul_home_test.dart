import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:taptap_go/core/theme/app_theme.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/screens/linehaul/linehaul_home_screen.dart';

/// Courier (linehaul) screens of the Account Creation workbook (TC-COU-032, 051, 052) against a fake API.
const home = {
  'name': 'Ernesto Villareal', 'email': 'ernesto.villareal@example.com', 'logistics_company': 'Bilis Hatid Express Inc.',
  'home_hub': {'code': 'HUB-QC', 'name': 'Bilis Hatid QC First-Mile Hub'},
  'vehicle_type': '4-Wheeler Closed Van Truck', 'plate_number': 'NAB4521', 'load_capacity_kg': 3000, 'duty_status': 'Off Duty',
};

MockClient fakeApi(List<String> calls) => MockClient((request) async {
      final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}';
      calls.add(key);
      final body = switch (key) {
        'GET /linehaul/home' => home,
        // No active trip, so logging out shows the normal "Log out?" (an active trip gets a warning)
        'GET /linehaul/trips' => <Object>[],
        'GET /me' => {'id': 9, 'name': 'Ernesto Villareal', 'email': 'ernesto.villareal@example.com', 'role': 'linehaul', 'status': 'approved'},
        'POST /logout' => {'message': 'Logged out successfully'},
        'GET /notifications' => [
            {'id': 'n1', 'read': false, 'created_at': '2026-11-17T08:00:00+08:00',
             'data': {'trip_id': 7, 'code': 'LH-0007', 'kind': 'assigned', 'message': 'New linehaul trip LH-0007: HUB-QC to HUB-BUL.'}},
            {'id': 'n2', 'read': true, 'created_at': '2026-11-16T08:00:00+08:00',
             'data': {'trip_id': 5, 'code': 'LH-0005', 'kind': 'completed', 'message': 'Trip LH-0005 is complete.'}},
          ],
        'POST /notifications/read' => {'message': 'Notifications marked as read.', 'unread': 0},
        _ => null,
      };
      return body == null
          ? http.Response(jsonEncode({'message': 'Forbidden'}), 403)
          : http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'auth_token': 'courier-token'}));

  testWidgets('TC-COU-032/052: the courier home shows the courier, company, hub, truck and Off Duty; Log Out clears the history', (tester) async {
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(theme: AppTheme.light,
          routes: {'/login': (_) => const Scaffold(body: Text('Login screen'))},
          home: const LinehaulHomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      for (final text in ['Ernesto Villareal', 'Bilis Hatid Express Inc.', 'HUB-QC · Bilis Hatid QC First-Mile Hub',
          '4-Wheeler Closed Van Truck', 'NAB4521', '3,000 kg', 'Off Duty']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // No rider job offers or rider screens
      expect(find.textContaining('Job Offers'), findsNothing);
      expect(find.textContaining('Online'), findsNothing);
      expect(calls.where((c) => c.contains('/courier/')), isEmpty);

      await tester.tap(find.byTooltip('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /logout'));
      expect(find.text('Login screen'), findsOneWidget);
      // Back has nowhere to go: the account screens were removed
      expect(Navigator.of(tester.element(find.text('Login screen'))).canPop(), isFalse);
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
    }, () => fakeApi(calls));
  });

  test('TC-COU-051: reopening the app restores the courier session from the saved token', () async {
    final calls = <String>[];
    await http.runWithClient(() async {
      final auth = AuthProvider();
      await auth.boot();
      expect(auth.authenticated, isTrue);
      expect(auth.user!.role, 'linehaul');
      expect(auth.user!.name, 'Ernesto Villareal');
      expect(calls, ['GET /me']);
    }, () => fakeApi(calls));
  });

  testWidgets('the linehaul home has a notification bell with the unread trips; the list marks them read', (tester) async {
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(theme: AppTheme.light, home: const LinehaulHomeScreen()),
      ));
      await tester.pumpAndSettle();

      final bell = find.byKey(const Key('linehaulNotificationBell'));
      expect(bell, findsOneWidget);
      expect(find.descendant(of: bell, matching: find.text('1')), findsOneWidget);

      await tester.tap(bell);
      await tester.pumpAndSettle();
      expect(find.text('New linehaul trip LH-0007: HUB-QC to HUB-BUL.'), findsOneWidget);
      expect(find.text('Trip LH-0005 is complete.'), findsOneWidget);
      expect(find.text('Open trip'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('linehaulMarkAllRead')));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /notifications/read'));
      expect(find.byKey(const Key('linehaulMarkAllRead')), findsNothing);
    }, () => fakeApi(calls));
  });

  testWidgets('no logistics company on record: the panel shows TaptapGo, like the Rider Panel', (tester) async {
    for (final company in [null, '', '  ']) {
      final noCompany = Map<String, Object?>.from(home)..['logistics_company'] = company;
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: MaterialApp(theme: AppTheme.light, home: LinehaulHomeScreen(key: UniqueKey())),
        ));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('linehaulCompany'))).data, 'TaptapGo', reason: '$company');
      }, () => MockClient((request) async {
            final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}';
            final body = key == 'GET /linehaul/home' ? noCompany : key == 'GET /linehaul/trips' ? <Object>[] : null;
            return body == null
                ? http.Response(jsonEncode({'message': 'Forbidden'}), 403)
                : http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          }));
    }
  });

  // NBI clearance, like riders: no trips until it is on file and verified by the logistics company
  Future<void> pumpWithNbi(WidgetTester tester, {required bool missing, required bool waiting}) async {
    final withNbi = Map<String, Object?>.from(home)
      ..['nbi_missing'] = missing
      ..['nbi_unverified'] = waiting;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(theme: AppTheme.light, home: LinehaulHomeScreen(key: UniqueKey())),
    ));
    await tester.pumpAndSettle();
    expect(withNbi, isNotEmpty);
  }

  MockClient nbiApi(Map<String, Object?> homeBody) => MockClient((request) async {
        final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}';
        final body = key == 'GET /linehaul/home' ? homeBody : key == 'GET /linehaul/trips' ? <Object>[] : null;
        return body == null
            ? http.Response(jsonEncode({'message': 'Forbidden'}), 403)
            : http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  testWidgets('no NBI on file: Home asks for it; the upload sheet needs a file before Save', (tester) async {
    final body = Map<String, Object?>.from(home)..['nbi_missing'] = true..['nbi_unverified'] = false;
    await http.runWithClient(() async {
      await pumpWithNbi(tester, missing: true, waiting: false);
      expect(find.byKey(const Key('linehaulNbiMissing')), findsOneWidget);
      expect(find.text('NBI clearance needed'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('linehaulNbiUpload')));
      await tester.tap(find.byKey(const Key('linehaulNbiUpload')));
      await tester.pumpAndSettle();
      expect(find.text('Upload your NBI clearance'), findsOneWidget);
      // Nothing picked yet: Save is off
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('linehaulNbiSave'))).onPressed, isNull);
    }, () => nbiApi(body));
  });

  testWidgets('NBI uploaded, not verified yet: Home says it is waiting', (tester) async {
    final body = Map<String, Object?>.from(home)..['nbi_missing'] = false..['nbi_unverified'] = true;
    await http.runWithClient(() async {
      await pumpWithNbi(tester, missing: false, waiting: true);
      expect(find.byKey(const Key('linehaulNbiWaiting')), findsOneWidget);
      expect(find.text('NBI clearance waiting for verification'), findsOneWidget);
      expect(find.byKey(const Key('linehaulNbiMissing')), findsNothing);
    }, () => nbiApi(body));
  });

  testWidgets('verified NBI: no NBI card on Home', (tester) async {
    final body = Map<String, Object?>.from(home)..['nbi_missing'] = false..['nbi_unverified'] = false;
    await http.runWithClient(() async {
      await pumpWithNbi(tester, missing: false, waiting: false);
      expect(find.byKey(const Key('linehaulNbiMissing')), findsNothing);
      expect(find.byKey(const Key('linehaulNbiWaiting')), findsNothing);
    }, () => nbiApi(body));
  });
}
