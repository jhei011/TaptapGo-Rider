import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
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
        'GET /me' => {'id': 9, 'name': 'Ernesto Villareal', 'email': 'ernesto.villareal@example.com', 'role': 'linehaul', 'status': 'approved'},
        'POST /logout' => {'message': 'Logged out successfully'},
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
        child: MaterialApp(
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
      await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
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
}
