import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/location_service.dart';
import 'package:taptap_go/models/rider_job.dart';
import 'package:taptap_go/providers/courier_provider.dart';
import 'package:taptap_go/screens/courier/rider_job_screen.dart';

import 'rider_modules_test.dart' show FakeApi, FakeLocation, here, job, pumpApp;

/// TapTapPay orders on the rider's side: the rider collects only the cash part
/// (fake API in these tests; the server is tested in the website's TapTapPayTest).
Map<String, dynamic> splitJob({String status = 'assigned', String shipment = 'out_for_delivery'}) =>
    job(id: 9, type: 'delivery', status: status, shipment: shipment)
      ..['cod_amount'] = status == 'assigned' ? 860 : 0
      ..['order_total'] = 1060
      ..['wallet_paid'] = 200
      ..['cod_total'] = 860;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    SharedPreferences.setMockInitialValues({});
    LocationService.source = FakeLocation(const LocationReading.at(here));
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
  });

  test('model: COD split, full TapTapPay, and an older server without the fields', () {
    final split = RiderJob.fromJson(splitJob());
    expect(split.paidWithWallet, isTrue);
    expect(split.orderTotal, 1060);
    expect(split.cashAmount, 860);

    final done = RiderJob.fromJson(splitJob(status: 'done', shipment: 'delivered'));
    expect(done.codAmount, 0);
    expect(done.cashAmount, 860); // what was collected, not "COD ₱0.00"

    final paid = RiderJob.fromJson(job(type: 'delivery', payment: 'taptappay')
      ..['order_total'] = 1060
      ..['wallet_paid'] = 1060
      ..['cod_total'] = 0);
    expect(paid.isTapTapPay, isTrue);
    expect(paid.collectsCod, isFalse);
    expect(paid.paymentLabel, 'Paid (TapTapPay)');

    final old = RiderJob.fromJson(job(type: 'delivery'));
    expect(old.paidWithWallet, isFalse);
    expect(old.orderTotal, isNull);
    expect(old.cashAmount, 500);
  });

  testWidgets('job screen: order total, paid via TapTapPay and the cash to collect', (tester) async {
    final api = FakeApi({'GET /courier/jobs/9': splitJob()});
    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9));
      await tester.pumpAndSettle();
      expect(find.text('Order total'), findsOneWidget);
      expect(find.text('₱1,060.00'), findsOneWidget);
      expect(find.text('Paid via TapTapPay'), findsOneWidget);
      expect(find.text('₱200.00'), findsOneWidget);
      expect(find.text('Cash to collect'), findsOneWidget);
      expect(find.text('₱860.00'), findsOneWidget);
      // the COD field asks for the cash part only
      expect(find.textContaining('COD collected (₱860.00)'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('job screen: a finished split job still shows the cash collected', (tester) async {
    final api = FakeApi({'GET /courier/jobs/9': splitJob(status: 'done', shipment: 'delivered')});
    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9));
      await tester.pumpAndSettle();
      expect(find.text('Cash collected'), findsOneWidget);
      expect(find.text('₱860.00'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('job screen: fully paid with TapTapPay, nothing to collect', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs/9': job(id: 9, type: 'delivery', shipment: 'out_for_delivery', payment: 'taptappay')
        ..['order_total'] = 1060
        ..['wallet_paid'] = 1060
        ..['cod_total'] = 0,
    });
    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9));
      await tester.pumpAndSettle();
      expect(find.text('Paid via TapTapPay'), findsOneWidget);
      expect(find.textContaining('nothing to collect'), findsOneWidget);
      expect(find.textContaining('COD collected'), findsNothing);
    }, () => api.client);
  });
}
