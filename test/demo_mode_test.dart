import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/demo/demo_api.dart';
import 'package:taptap_go/core/services/api.dart';
import 'package:taptap_go/core/services/location_service.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/providers/courier_provider.dart';

/// The demo build's stand-in for the API: the app's real providers run against it.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'demo-token'});
    SharedPreferences.setMockInitialValues({});
    LocationService.source = DemoLocation();
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
  });

  test('demo mode is off unless the build asks for it', () {
    expect(kDemoMode, isFalse);
  });

  test('opens as the rider with no account, and the rider flow works on sample data', () async {
    final demo = DemoApi(role: 'courier');
    await http.runWithClient(() async {
      final auth = AuthProvider();
      await auth.boot();
      expect(auth.authenticated, isTrue);
      expect(auth.user!.name, 'Pedro Jose Garcia');

      final cp = CourierProvider();
      await cp.loadDashboard();
      expect(cp.error, isNull);
      expect(cp.dashboard!['logistics_company'], 'Bilis Hatid Express Inc.');
      expect(cp.activeJobs, hasLength(2));
      expect(cp.offers, isEmpty); // offers come only while Online

      await cp.toggleOnlineStatus();
      expect(cp.isOnline, isTrue);
      expect(cp.offers, hasLength(1));

      expect(await cp.acceptOffer(cp.offers.single), isTrue);
      expect(cp.activeJobs, hasLength(3));

      expect(await cp.confirmPickup(7, 'TRK-0000000'), isNull);
      expect(cp.error, 'The tracking number does not match this job.');
      final picked = await cp.confirmPickup(7, 'trk-1234567');
      expect(picked!.shipmentStatus, 'picked_up');
      expect(cp.activeJobs, hasLength(2));

      await cp.loadEarnings();
      expect(cp.earnings!['today_earnings'], 110);
      expect(cp.cod!['balance'], 500);
      cp.stop();
    }, () => demo.client);
  });

  test('opens as the courier when the build asks for that role', () async {
    final demo = DemoApi(role: 'linehaul');
    await http.runWithClient(() async {
      final auth = AuthProvider();
      await auth.boot();
      expect(auth.user!.role, 'linehaul');
      final home = await Api.get('/linehaul/home') as Map;
      expect(home['name'], 'Ernesto Villareal');
      expect(home['duty_status'], 'Off Duty');
    }, () => demo.client);
  });

  test('anything the demo does not cover gets a clear message', () async {
    final demo = DemoApi();
    await http.runWithClient(() async {
      await expectLater(Api.get('/buyer/products'),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', 'This is not available in the demo.')));
    }, () => demo.client);
  });
}
