import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/utils/waybill_code.dart';
import 'package:taptap_go/models/rider_job.dart';
import 'package:taptap_go/providers/courier_provider.dart';

/// The seller's waybill carries a QR link to the order (…/orders/{id}); the logistics waybill
/// a Code 128 barcode with the tracking number. A rider can scan either at pickup.
Map<String, dynamic> pickupJob({int id = 7, int orderId = 41, String status = 'assigned'}) => {
      'id': id, 'type': 'pickup', 'status': status, 'shipment_status': 'awaiting_pickup',
      'attempt': 1, 'max_attempts': 3, 'tracking_number': 'TRK-1234567', 'order_id': orderId,
      'parcels': 1, 'pay': 30, 'earned': 0, 'result': null, 'payment_method': 'cod', 'cod_amount': 500,
      'pickup': {'name': 'Seller', 'address': 'Pila, Laguna', 'area': 'Pila'},
      'dropoff': {'name': 'Buyer', 'address': 'Victoria, Laguna', 'area': 'Victoria'},
      'items': [], 'failed_reason': null, 'times': {}, 'pod_photo_url': null,
      'direction': 'forward', 'return_number': null,
    };

void main() {
  group('WaybillCode.parse', () {
    test('a tracking number stays a tracking number (trimmed, upper case)', () {
      final c = WaybillCode.parse('  trk-1234567 ');
      expect(c.isOrderLink, isFalse);
      expect(c.trackingNumber, 'TRK-1234567');
    });

    test('the seller-waybill QR link gives the order id (live and local hosts)', () {
      for (final link in [
        'https://logistics.taptapshop.store/orders/41',
        'http://logistics.localhost:8001/orders/41/',
        'https://logistics.taptapshop.store/orders/41?from=qr',
      ]) {
        final c = WaybillCode.parse(link);
        expect(c.isOrderLink, isTrue, reason: link);
        expect(c.orderId, 41, reason: link);
      }
    });

    test('any other link is not taken for an order', () {
      expect(WaybillCode.parse('https://example.com/orders/41/items').isOrderLink, isFalse);
      expect(WaybillCode.parse('https://example.com/parcels/41').isOrderLink, isFalse);
    });
  });

  group('pickup with a scanned seller-waybill QR', () {
    late List<http.Request> sent;
    late List<Map<String, dynamic>> active;

    http.Client client() => MockClient((r) async {
          sent.add(r);
          final path = r.url.path.replaceFirst('/api', '');
          if (r.method == 'GET' && path == '/courier/jobs') {
            return http.Response(jsonEncode({'active': active, 'recent': []}), 200, headers: {'content-type': 'application/json'});
          }
          if (r.method == 'POST' && path == '/courier/jobs/7/pickup') {
            return http.Response(
                jsonEncode({'message': 'Parcel picked up.', 'job': pickupJob(status: 'done')..['shipment_status'] = 'picked_up'}),
                200, headers: {'content-type': 'application/json'});
          }
          return http.Response(jsonEncode({'message': 'Not found'}), 404, headers: {'content-type': 'application/json'});
        });

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
      SharedPreferences.setMockInitialValues({});
      CourierProvider.connectionChanges = () => const Stream<bool>.empty();
      sent = [];
      active = [pickupJob()];
    });

    List<http.Request> pickups() => sent.where((r) => r.method == 'POST' && r.url.path.endsWith('/pickup')).toList();

    test('Scan tab: the QR link confirms the pickup of that order with its tracking number', () async {
      await http.runWithClient(() async {
        final cp = CourierProvider();
        final done = await cp.pickupByScan('https://logistics.taptapshop.store/orders/41');
        expect(done, isNotNull, reason: cp.error);
        expect(jsonDecode(pickups().single.body), {'tracking_number': 'TRK-1234567'});
      }, client);
    });

    test('Scan tab: a QR link for an order with no pickup job is refused without a pickup call', () async {
      await http.runWithClient(() async {
        final cp = CourierProvider();
        expect(await cp.pickupByScan('https://logistics.taptapshop.store/orders/99'), isNull);
        expect(cp.error, 'None of your pickup jobs is for order #99.');
        expect(pickups(), isEmpty);
      }, client);
    });

    test('Job screen: the QR of this job\'s order sends the job\'s tracking number', () async {
      await http.runWithClient(() async {
        final cp = CourierProvider();
        final done = await cp.confirmPickupWithCode(RiderJob.fromJson(pickupJob()), 'http://logistics.localhost:8001/orders/41');
        expect(done, isNotNull, reason: cp.error);
        expect(jsonDecode(pickups().single.body), {'tracking_number': 'TRK-1234567'});
      }, client);
    });

    test('Job screen: the QR of another order is refused before reaching the server', () async {
      await http.runWithClient(() async {
        final cp = CourierProvider();
        expect(await cp.confirmPickupWithCode(RiderJob.fromJson(pickupJob()), 'https://logistics.taptapshop.store/orders/12'), isNull);
        expect(cp.error, 'This waybill is for order #12, not this job (order #41).');
        expect(pickups(), isEmpty);
      }, client);
    });

    test('Job screen: a typed or barcode tracking number still goes to the server as typed', () async {
      await http.runWithClient(() async {
        final cp = CourierProvider();
        await cp.confirmPickupWithCode(RiderJob.fromJson(pickupJob()), ' trk-1234567 ');
        expect(jsonDecode(pickups().single.body), {'tracking_number': 'TRK-1234567'});
      }, client);
    });
  });
}
