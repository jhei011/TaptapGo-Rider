import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/location_service.dart';
import 'package:taptap_go/models/rider_job.dart';
import 'package:taptap_go/providers/courier_provider.dart';
import 'package:taptap_go/screens/courier/courier_earnings_screen.dart' show payRuleText;
import 'package:taptap_go/screens/courier/rider_job_screen.dart';
import 'package:taptap_go/screens/courier/rider_job_widgets.dart';
import 'package:taptap_go/screens/linehaul/linehaul_trips_screen.dart' show hubMapsQuery;
import 'package:taptap_go/widgets/change_password_sheet.dart';

import 'rider_modules_test.dart' show FakeApi, FakeLocation, Reply, here, job, pumpApp;

/// Fixes from the 16 Nov live audit (fake API; the server side is tested in the website's tests).
Map<String, dynamic> splitPickup({String status = 'assigned'}) =>
    job(id: 7, type: 'pickup', status: status, shipment: status == 'assigned' ? 'pickup_assigned' : 'picked_up_from_seller')
      ..['cod_amount'] = 390
      ..['order_total'] = 590
      ..['wallet_paid'] = 200
      ..['cod_total'] = 390;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    SharedPreferences.setMockInitialValues({});
    LocationService.source = FakeLocation(const LocationReading.at(here));
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
  });

  group('Linehaul Navigate searches the hub address, not its name', () {
    test('address only, even when the hub has a name', () {
      expect(hubMapsQuery({'name': 'Dvidhub Hub', 'address': '0965, P flores street, Norzagaray, Bulacan'}),
          '0965, P flores street, Norzagaray, Bulacan');
    });
    test('the name only when there is no address', () {
      expect(hubMapsQuery({'name': 'Dvidhub Hub', 'address': null}), 'Dvidhub Hub');
      expect(hubMapsQuery({'name': 'Dvidhub Hub', 'address': '  '}), 'Dvidhub Hub');
    });
  });

  group('Earnings pay rule comes from the server', () {
    test('15% / 40% of the shipping fee', () {
      expect(payRuleText({'pickup_percent': 15, 'delivery_percent': 40, 'failed_attempt': 0}),
          'Pickup: 15% of the shipping fee · Delivery: 40% · Failed attempt: ₱0.00');
      expect(payRuleText({'pickup_percent': 12.5, 'delivery_percent': '40'}), contains('Pickup: 12.5%'));
    });
    test('an older server without the rule shows nothing (no made-up ₱30 / ₱50)', () {
      expect(payRuleText(null), isNull);
      expect(payRuleText({'pickup_percent': 15}), isNull);
    });
  });

  group('Pickup jobs never say cash is collected at pickup', () {
    testWidgets('pickup job screen: "Cash at delivery", not "Cash to collect" / "Cash collected"', (tester) async {
      for (final status in ['assigned', 'done']) {
        final api = FakeApi({'GET /courier/jobs/7': splitPickup(status: status)});
        await http.runWithClient(() async {
          await pumpApp(tester, api, const RiderJobScreen(jobId: 7));
          await tester.pumpAndSettle();
          expect(find.text('Cash at delivery'), findsOneWidget, reason: status);
          expect(find.text('Cash to collect'), findsNothing, reason: status);
          expect(find.text('Cash collected'), findsNothing, reason: status);
          expect(find.text('₱390.00'), findsOneWidget, reason: status);
        }, () => api.client);
      }
    });

    testWidgets('job card on Home: "No cash at pickup" for a pickup, the COD for a delivery', (tester) async {
      final pickup = RiderJob.fromJson(splitPickup());
      final delivery = RiderJob.fromJson(job(id: 8, type: 'delivery', status: 'assigned', shipment: 'out_for_delivery'));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
        RiderJobCard(job: pickup),
        RiderJobCard(job: delivery),
      ]))));
      expect(find.text('No cash at pickup'), findsOneWidget);
      expect(find.textContaining('COD ₱'), findsOneWidget);
    });
  });

  group('Change password (riders and linehaul couriers)', () {
    test('the same rules as the website', () {
      expect(newPasswordProblem('short', 'x'), 'Use at least 8 characters.');
      expect(newPasswordProblem('alllower1!', 'x'), 'Use both uppercase and lowercase letters.');
      expect(newPasswordProblem('NoNumber!!', 'x'), 'Add at least one number.');
      expect(newPasswordProblem('NoSymbol12', 'x'), 'Add at least one symbol, such as ! or @.');
      expect(newPasswordProblem('Same@2026x', 'Same@2026x'), 'Choose a password different from your current one.');
      expect(newPasswordProblem('Rider@2027x', 'Rider@2026x'), isNull);
    });

    testWidgets('sends the current and new password; shows the server message', (tester) async {
      final api = FakeApi({'POST /me/password': {'message': 'Your password has been changed.'}});
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChangePasswordButton())));
        await tester.tap(find.byKey(const Key('openChangePassword')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('currentPassword')), 'Rider@2026x');
        await tester.enterText(find.byKey(const Key('newPassword')), 'Rider@2027x');
        await tester.enterText(find.byKey(const Key('confirmPassword')), 'Rider@2027x');
        await tester.tap(find.byKey(const Key('changePasswordButton')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        expect(find.text('Your password has been changed.'), findsOneWidget);
        expect(api.last('POST', '/me/password')!.body, contains('Rider@2027x'));
      }, () => api.client);
    });

    testWidgets('a wrong current password shows the server reason', (tester) async {
      final api = FakeApi({'POST /me/password': const Reply(422, {'message': 'Your current password is incorrect.'})});
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChangePasswordButton())));
        await tester.tap(find.byKey(const Key('openChangePassword')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('currentPassword')), 'Wrong@2026x');
        await tester.enterText(find.byKey(const Key('newPassword')), 'Rider@2027x');
        await tester.enterText(find.byKey(const Key('confirmPassword')), 'Rider@2027x');
        await tester.tap(find.byKey(const Key('changePasswordButton')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        expect(find.text('Your current password is incorrect.'), findsOneWidget);
      }, () => api.client);
    });
  });
}
