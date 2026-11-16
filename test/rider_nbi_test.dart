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
import 'package:taptap_go/screens/courier/rider_profile_widgets.dart';
import 'package:taptap_go/widgets/bh_primary_button.dart';

/// NBI clearance: a rider without one on file cannot go Online or take jobs until they upload it.
class _Gps implements LocationSource {
  @override
  Future<LocationReading> current({bool ask = false}) async => const LocationReading.at(RiderPosition(14.27, 121.41));
  @override
  Stream<bool> enabledChanges() => const Stream<bool>.empty();
  @override
  Future<void> openSettings(LocationProblem problem) async {}
}

Map<String, dynamic> _profile({required bool nbiMissing, bool nbiUnverified = false}) => {
      'id': 5, 'name': 'Pedro Jose Garcia', 'status': 'approved', 'logistics_company': 'Bilis Hatid Express Inc.',
      'driver_license_number': 'N01-23-456789', 'license_expiry_date': '2030-03-22', 'vehicle_type': 'motorcycle',
      'plate_number': '123ABC', 'needs_reverification': false, 'nbi_missing': nbiMissing, 'nbi_unverified': nbiUnverified,
      'documents': {
        'driver_license': {'name': 'license.jpg', 'url': 'https://example.com/l'},
        'or_cr': {'name': 'or_cr.pdf', 'url': 'https://example.com/o'},
        'nbi_clearance': nbiMissing ? null : {'name': 'nbi.jpg', 'url': 'https://example.com/n'},
      },
    };

http.Client _api({required bool nbiMissing, bool nbiUnverified = false}) => MockClient((r) async {
      final path = r.url.path.replaceFirst('/api', '');
      final Object body = switch (path) {
        '/me' => {'id': 5, 'name': 'Pedro Jose Garcia', 'email': 'rider@example.test', 'role': 'courier', 'status': 'approved'},
        '/courier/dashboard' => {'is_online': false, 'total_delivered': 0, 'active_jobs': 0, 'delivered_today': 0},
        '/courier/jobs' => {'active': [], 'recent': []},
        '/courier/offers' => [],
        '/courier/profile' => _profile(nbiMissing: nbiMissing, nbiUnverified: nbiUnverified),
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

  Future<CourierProvider> pumpHome(WidgetTester tester, {required bool nbiMissing}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => call.method == 'check' ? <String>['wifi'] : null);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity_status'), (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/connectivity_status'), null);
    });

    final auth = AuthProvider();
    final cp = CourierProvider();
    await tester.runAsync(auth.boot);
    await tester.runAsync(cp.loadDashboard);
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: auth), ChangeNotifierProvider.value(value: cp)],
      child: MaterialApp(theme: AppTheme.light, home: const CourierDashboardScreen()),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    return cp;
  }

  testWidgets('Home tells a rider without an NBI clearance to upload it, and the button opens Profile', (tester) async {
    await http.runWithClient(() async {
      final cp = await pumpHome(tester, nbiMissing: true);
      expect(cp.nbiMissing, isTrue);
      expect(find.byKey(const Key('nbiBanner')), findsOneWidget);
      expect(find.text('NBI clearance needed'), findsOneWidget);

      await tester.tap(find.text('Upload NBI clearance'));
      expect(cp.takeRequestedTab(), 3); // the Profile tab
      cp.stop();
    }, () => _api(nbiMissing: true));
  });

  testWidgets('Home shows no NBI notice when the clearance is on file', (tester) async {
    await http.runWithClient(() async {
      final cp = await pumpHome(tester, nbiMissing: false);
      expect(cp.nbiMissing, isFalse);
      expect(find.byKey(const Key('nbiBanner')), findsNothing);
      expect(find.byKey(const Key('nbiPendingBanner')), findsNothing);
      cp.stop();
    }, () => _api(nbiMissing: false));
  });

  testWidgets('an uploaded NBI the logistics company has not verified yet: Home says it is waiting, no "ready" message', (tester) async {
    await http.runWithClient(() async {
      final cp = await pumpHome(tester, nbiMissing: false);
      expect(cp.nbiUnverified, isTrue);
      expect(find.byKey(const Key('nbiBanner')), findsNothing);
      expect(find.byKey(const Key('nbiPendingBanner')), findsOneWidget);
      expect(find.text('NBI clearance waiting for verification'), findsOneWidget);
      expect(find.textContaining('You can now take jobs'), findsNothing);
      cp.stop();
    }, () => _api(nbiMissing: false, nbiUnverified: true));
  });

  testWidgets('Profile: NBI clearance is marked missing; its upload needs a photo before Save', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      final cp = CourierProvider();
      await cp.loadProfile();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: cp,
        child: MaterialApp(theme: AppTheme.light,
            home: Scaffold(body: SingleChildScrollView(child: RiderVehicleSection(cp: cp)))),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nbiMissing')), findsOneWidget);
      expect(find.text('Upload NBI'), findsOneWidget);
      expect(find.text('NBI clearance'), findsWidgets); // tile + documents row

      await tester.tap(find.text('Upload NBI'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.byKey(const Key('nbiRequired')), findsOneWidget);
      final save = tester.widget<BhPrimaryButton>(find.widgetWithText(BhPrimaryButton, 'Save'));
      expect(save.onPressed, isNull);
    }, () => _api(nbiMissing: true));
  });
}
