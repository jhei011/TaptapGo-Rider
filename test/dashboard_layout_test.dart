import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/location_service.dart';
import 'package:taptap_go/core/theme/app_theme.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/providers/courier_provider.dart';
import 'package:taptap_go/screens/courier/courier_dashboard_screen.dart';

/// GPS that is on and has a position (the dashboard asks for it).
class _Gps implements LocationSource {
  @override
  Future<LocationReading> current({bool ask = false}) async => const LocationReading.at(RiderPosition(14.27, 121.41));
  @override
  Stream<bool> enabledChanges() => const Stream<bool>.empty();
  @override
  Future<void> openSettings(LocationProblem problem) async {}
}

http.Client _api({required bool online}) => MockClient((r) async {
      final path = r.url.path.replaceFirst('/api', '');
      final Object body = switch (path) {
        '/me' => {'id': 5, 'name': 'David James Limjoco', 'email': 'rider@example.test', 'role': 'courier', 'status': 'approved'},
        '/courier/dashboard' => {'is_online': online, 'total_delivered': 0, 'active_jobs': 0, 'delivered_today': 0},
        '/courier/jobs' => {'active': [], 'recent': []},
        '/courier/offers' => [],
        _ => {'message': 'Not found'},
      };
      final status = body is Map && body['message'] == 'Not found' ? 404 : 200;
      return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    });

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    SharedPreferences.setMockInitialValues({});
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
    LocationService.source = _Gps();
  });

  // A 360-dp-wide phone with large text, like a Realme with display/font size turned up.
  for (final online in [false, true]) {
    for (final theme in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
      testWidgets('the ${online ? 'Online' : 'Offline'} row fits beside its switch with large text (${theme.key})', (tester) async {
        tester.view.physicalSize = const Size(360 * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        // The offline banner asks the phone whether it is connected: answer "Wi-Fi"
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (call) async => call.method == 'check' ? <String>['wifi'] : null);
        messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity_status'), (_) async => null);
        addTearDown(() {
          messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
          messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity_status'), null);
        });

        await http.runWithClient(() async {
          final auth = AuthProvider();
          final cp = CourierProvider();
          await tester.runAsync(auth.boot);
          // Already Online when the screen opens (as after reopening the app): the green
          // dot's first frame crashed the dashboard before (MediaQuery read in initState)
          if (online) await tester.runAsync(cp.loadDashboard);
          await tester.pumpWidget(MultiProvider(
            providers: [ChangeNotifierProvider.value(value: auth), ChangeNotifierProvider.value(value: cp)],
            child: MaterialApp(
              theme: theme.value,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const CourierDashboardScreen(),
            ),
          ));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();

          expect(find.text(online ? 'Online — Ready to Deliver' : 'Offline — Go Online to Accept Parcels'), findsOneWidget);
          expect(tester.takeException(), isNull); // no "RIGHT OVERFLOWED" or other layout error
          cp.stop();
        }, () => _api(online: online));
      });
    }
  }
}
