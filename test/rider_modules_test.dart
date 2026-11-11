import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/location_service.dart';
import 'package:taptap_go/core/services/pending_delivery_store.dart';
import 'package:taptap_go/models/rider_job.dart';
import 'package:taptap_go/providers/courier_provider.dart';
import 'package:taptap_go/screens/courier/courier_dashboard_screen.dart';
import 'package:taptap_go/screens/courier/courier_earnings_screen.dart';
import 'package:taptap_go/screens/courier/rider_job_screen.dart';
import 'package:taptap_go/screens/courier/rider_job_widgets.dart';
import 'package:taptap_go/screens/courier/rider_notifications_screen.dart';
import 'package:taptap_go/screens/courier/rider_profile_widgets.dart';
import 'package:taptap_go/screens/courier/waybill_scanner_screen.dart';

/// Rider Modules (R1-R7) screens against a fake API (the real API is covered by the
/// Laravel RiderModulesTest).
Map<String, dynamic> job({
  int id = 7,
  String type = 'pickup',
  String status = 'assigned',
  String shipment = 'awaiting_pickup',
  String payment = 'cod',
  String direction = 'forward',
  String? returnNumber,
}) =>
    {
      'id': id, 'type': type, 'status': status, 'shipment_status': shipment,
      'attempt': 1, 'max_attempts': 3, 'tracking_number': 'TRK-1234567', 'order_id': 41,
      'parcels': 1, 'pay': type == 'pickup' ? 30 : 50, 'earned': 0, 'result': null,
      'payment_method': payment, 'cod_amount': payment == 'cod' ? 500 : 0,
      'pickup': {
        'name': 'Maria Clara Handicrafts', 'contact': 'Maria Clara Santos', 'phone': '09189876543',
        'address': 'Blk 12 Lot 8, Sampaguita St., Commonwealth, Quezon City, Metro Manila',
        'area': 'Commonwealth, Quezon City',
      },
      'dropoff': {
        'name': 'Juan Miguel Dela Cruz', 'phone': '09171234567',
        'address': '45, Kalayaan Ave., Central, Quezon City, Metro Manila', 'area': 'Brgy. Central, Quezon City',
      },
      'items': [{'name': 'Rattan Fruit Basket', 'quantity': 1}],
      'failed_reason': null, 'times': {'assigned': '2026-10-28T09:00:00+08:00'}, 'pod_photo_url': null,
      'direction': direction, 'return_number': returnNumber,
    };

/// A response with a status other than 200.
class Reply {
  final int status;
  final Object body;
  const Reply(this.status, this.body);
}

/// No internet: the request never reaches the server.
final offline = http.ClientException('Failed host lookup');

class FakeApi {
  final requests = <http.Request>[];
  final Map<String, Object> routes;
  FakeApi(this.routes);

  late final client = MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}';
    final route = routes[key];
    if (route == null) return http.Response(jsonEncode({'message': 'Not found: $key'}), 404);
    if (route is Exception) throw route;
    final reply = route is Reply ? route : Reply(200, route);
    return http.Response.bytes(utf8.encode(jsonEncode(reply.body)), reply.status,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });

  List<http.Request> sent(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == '/api$path').toList();

  http.Request? last(String method, String path) =>
      requests.lastWhere((r) => r.method == method && r.url.path == '/api$path', orElse: () => http.Request('NONE', Uri()));
}

Future<void> pumpApp(WidgetTester tester, FakeApi api, Widget child, {CourierProvider? cp}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final provider = cp ?? CourierProvider();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      // The test font draws every glyph as a full square; keep rows within the screen width
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
        child: w!,
      ),
      home: child,
    ),
  ));
}

/// The phone's GPS: a position, or the reason there is none.
class FakeLocation implements LocationSource {
  LocationReading reading;
  final switches = StreamController<bool>.broadcast();
  LocationProblem? openedSettingsFor;
  int asked = 0;
  FakeLocation(this.reading);

  @override
  Future<LocationReading> current({bool ask = false}) async {
    if (ask) asked++;
    return reading;
  }

  @override
  Stream<bool> enabledChanges() => switches.stream;

  @override
  Future<void> openSettings(LocationProblem problem) async => openedSettingsFor = problem;
}

/// Commonwealth, Quezon City
const here = RiderPosition(14.6976, 121.0880);

/// Lets queued futures and stream events run (for tests outside testWidgets).
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// The text fields of a multipart request, e.g. the deliver call.
Map<String, String> multipartFields(http.Request r) => {
      for (final m in RegExp(r'form-data; name="([^"]+)"\r\n\r\n([^\r]*)\r\n').allMatches(r.body)) m.group(1)!: m.group(2)!,
    };

late FakeLocation gps;

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    SharedPreferences.setMockInitialValues({});
    gps = FakeLocation(const LocationReading.at(here));
    LocationService.source = gps;
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
  });

  testWidgets('RID-JOB-001: an offer shows pickup, drop-off, COD and pay with a countdown; Accept assigns it', (tester) async {
    final api = FakeApi({
      'POST /courier/offers/3/accept': {'message': 'Job accepted.', 'job': job()},
      'GET /courier/jobs': {'active': [job()], 'recent': []},
    });
    await http.runWithClient(() async {
      final cp = CourierProvider();
      final offer = JobOffer(id: 3, expiresAt: DateTime.now().add(const Duration(seconds: 58)), job: RiderJob.fromJson(job()));
      await pumpApp(tester, api, Scaffold(body: JobOfferCard(offer: offer, cp: cp)), cp: cp);

      expect(find.text('Maria Clara Handicrafts · Commonwealth, Quezon City'), findsOneWidget);
      expect(find.text('Brgy. Central, Quezon City'), findsOneWidget);
      expect(find.text('₱500.00'), findsOneWidget);
      expect(find.text('₱30.00 pickup'), findsOneWidget);
      expect(find.textContaining('s left'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(api.last('POST', '/courier/offers/3/accept')!.method, 'POST');
      expect(cp.activeJobs.single.id, 7);
      expect(find.text('Job accepted.'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('RID-JOB-006: a rider holding 3 active jobs cannot accept a 4th', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs': {
        'active': [job(id: 1), job(id: 2), job(id: 3)],
        'recent': [],
      },
    });
    await http.runWithClient(() async {
      final cp = CourierProvider();
      await cp.loadJobs();
      expect(cp.activeJobs, hasLength(3));

      final offer = JobOffer(
          id: 4, expiresAt: DateTime.now().add(const Duration(seconds: 60)), job: RiderJob.fromJson(job(id: 4)));
      await pumpApp(tester, api, Scaffold(body: JobOfferCard(offer: offer, cp: cp)), cp: cp);

      expect(find.text('You already have 3 active jobs. Finish one before accepting another.'), findsOneWidget);
      final accept = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Accept'));
      expect(accept.onPressed, isNull);
    }, () => api.client);
  });

  testWidgets('RID-PICK-003: the tracking number is typed and confirmed', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs/7': job(),
      'POST /courier/jobs/7/pickup': {'message': 'Parcel picked up.', 'job': job(status: 'done', shipment: 'picked_up')..['result'] = 'Picked up'},
      'GET /courier/jobs': {'active': [], 'recent': []},
    });
    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 7));
      await tester.pumpAndSettle();

      expect(find.text('Maria Clara Handicrafts'), findsOneWidget);
      expect(find.text('09189876543'), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);

      expect(find.text('Scan waybill'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('trackingField')), 'TRK-1234567');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Confirm pickup'));
      await tester.pumpAndSettle();

      expect(jsonDecode(api.last('POST', '/courier/jobs/7/pickup')!.body), {'tracking_number': 'TRK-1234567'});
      expect(find.text('This job is finished: Picked up.'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('RID-DLV-003/008/010: delivery needs a live photo, the 6-digit code and the COD; buyer can be called or messaged', (tester) async {
    final api = FakeApi({'GET /courier/jobs/9': job(id: 9, type: 'delivery', shipment: 'out_for_delivery')});
    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9));
      await tester.pumpAndSettle();

      expect(find.text('Juan Miguel Dela Cruz'), findsOneWidget);
      expect(find.text('09171234567'), findsOneWidget);
      for (final action in ['Navigate', 'Call', 'Message']) {
        expect(find.text(action), findsOneWidget);
      }
      // Camera only: no gallery or file option for the proof photo
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose file'), findsNothing);

      final otp = tester.widget<TextField>(find.byKey(const Key('otpField')));
      expect(otp.keyboardType, TextInputType.number);
      expect(otp.maxLength, 6);
      final cod = tester.widget<TextField>(find.byKey(const Key('codField')));
      expect(cod.keyboardType, const TextInputType.numberWithOptions(decimal: true));

      await tester.enterText(find.byKey(const Key('otpField')), '123456');
      await tester.enterText(find.byKey(const Key('codField')), '500.00');
      await tester.tap(find.text('Mark as Delivered'));
      await tester.pump();
      expect(find.text('Take a proof-of-delivery photo.'), findsOneWidget);
      expect(api.requests.where((r) => r.url.path.endsWith('/deliver')), isEmpty);
    }, () => api.client);
  });

  testWidgets('RID-FAIL-001/002: Mark as Failed needs a reason', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs/9': job(id: 9, type: 'delivery', shipment: 'out_for_delivery'),
      'POST /courier/jobs/9/fail': {
        'message': 'Delivery marked as failed.',
        'job': job(id: 9, type: 'delivery', status: 'failed', shipment: 'failed_delivery')
          ..['failed_reason'] = 'Buyer not home'
          ..['result'] = 'Failed (Buyer not home)',
      },
      'GET /courier/jobs': {'active': [], 'recent': []},
    });
    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark as Failed'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(ElevatedButton, 'Mark as Failed');
      expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('Buyer not home'));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(jsonDecode(api.last('POST', '/courier/jobs/9/fail')!.body), {'reason': 'buyer_not_home'});
      expect(find.text('Failed (Buyer not home)'), findsWidgets);
    }, () => api.client);
  });

  testWidgets('RID-EARN-001 to 004: totals, history and remitting COD', (tester) async {
    final api = FakeApi({
      'GET /courier/earnings': {
        'today_earnings': 210, 'week_earnings': 210, 'month_earnings': 210, 'total_earnings': 210, 'total_delivered': 3,
        'history': [
          {'job_id': 1, 'date': '2026-10-28T10:00:00+08:00', 'tracking_number': 'TRK-0000001', 'type': 'delivery', 'result': 'Delivered', 'pay': 50},
          {'job_id': 2, 'date': '2026-10-28T11:00:00+08:00', 'tracking_number': 'TRK-0000002', 'type': 'delivery', 'result': 'Failed (Buyer not home)', 'pay': 0},
        ],
      },
      'GET /courier/cod': {
        'balance': 1800, 'pending_total': 0, 'remittances': [],
        'collected': [
          {'order_id': 41, 'tracking_number': 'TRK-0000001', 'amount': 500},
          {'order_id': 42, 'tracking_number': 'TRK-0000003', 'amount': 1300},
        ],
      },
      'POST /courier/remittances': {
        'message': 'Remittance submitted.', 'remittance': {'id': 1, 'amount': 1800, 'status': 'pending'},
        'cod': {'balance': 1800, 'pending_total': 1800, 'collected': [], 'remittances': [{'id': 1, 'amount': 1800, 'shortfall': 0, 'status': 'pending'}]},
      },
    });
    await http.runWithClient(() async {
      await pumpApp(tester, api, const CourierEarningsScreen());
      await tester.pumpAndSettle();

      expect(find.text('₱210.00'), findsWidgets);
      expect(find.text('Delivered · TRK-0000001'), findsOneWidget);
      expect(find.text('Failed (Buyer not home) · TRK-0000002'), findsOneWidget);
      expect(find.text('₱1,800.00'), findsOneWidget);
      expect(find.text('Order #42 · TRK-0000003'), findsOneWidget);

      await tester.tap(find.text('Remit COD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(jsonDecode(api.last('POST', '/courier/remittances')!.body), {'amount': 1800.0});
      expect(find.text('₱1,800.00 remitted, waiting for confirmation'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('RID-PROF-001/008: profile shows license, vehicle and company; documents open; edits offer camera and files', (tester) async {
    final api = FakeApi({
      'GET /courier/profile': {
        'id': 5, 'name': 'Pedro Jose Garcia', 'status': 'approved', 'logistics_company': 'Bilis Hatid Express Inc.',
        'driver_license_number': 'N01-23-456789', 'license_expiry_date': '2030-03-22', 'vehicle_type': 'motorcycle',
        'plate_number': '123ABC', 'needs_reverification': false,
        'documents': {
          'driver_license': {'name': 'license.jpg', 'url': 'https://example.com/l'},
          'or_cr': {'name': 'or_cr.pdf', 'url': 'https://example.com/o'},
        },
      },
    });
    await http.runWithClient(() async {
      final cp = CourierProvider();
      await cp.loadProfile();
      await pumpApp(tester, api, Scaffold(body: SingleChildScrollView(child: RiderVehicleSection(cp: cp))), cp: cp);

      for (final text in ['Bilis Hatid Express Inc.', 'Active', 'N01-23-456789', '03/22/2030', 'Motorcycle', '123ABC', 'license.jpg', 'or_cr.pdf']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Open'), findsNWidgets(2));

      await tester.tap(find.text('Edit vehicle'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plateField')), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);
    }, () => api.client);
  });

  test('offer countdown is based on the seconds the server reports', () {
    final offer = JobOffer.fromJson({'id': 1, 'seconds_left': 40, 'expires_at': '2000-01-01T00:00:00Z', 'job': job()});
    expect(offer.secondsLeft(), inInclusiveRange(39, 40));
  });

  test('peso formatting', () {
    expect(peso(1800), '₱1,800.00');
    expect(peso(0), '₱0.00');
    expect(peso(1750.5), '₱1,750.50');
  });

  // Keep the analyzer happy about the services import used by FilteringTextInputFormatter tests
  test('digits-only formatter used by the delivery code field', () {
    final f = FilteringTextInputFormatter.digitsOnly;
    expect(f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '12a3')).text, '123');
  });

  // ── Location (RID-AVAIL-005, RID-AVAIL-006) ──────────────────────────────

  test('RID-AVAIL-005: going Online asks for location; without it nothing is sent, with it the position is sent', () async {
    final api = FakeApi({'PUT /courier/status': {'online': true}, 'GET /courier/offers': []});
    await http.runWithClient(() async {
      final cp = CourierProvider();
      gps.reading = const LocationReading.unavailable(LocationProblem.denied);
      await cp.toggleOnlineStatus();
      expect(gps.asked, 1);
      expect(cp.isOnline, isNot(true));
      expect(cp.locationProblem, LocationProblem.denied);
      expect(api.sent('PUT', '/courier/status'), isEmpty);
      await cp.openLocationSettings();
      expect(gps.openedSettingsFor, LocationProblem.denied);

      gps.reading = const LocationReading.at(here);
      await cp.toggleOnlineStatus();
      expect(cp.isOnline, isTrue);
      expect(cp.locationProblem, isNull);
      expect(jsonDecode(api.last('PUT', '/courier/status')!.body), {'online': true, 'lat': 14.6976, 'lng': 121.088});
      cp.stop();
    }, () => api.client);
  });

  testWidgets('RID-AVAIL-005/006: the location banner explains the problem and opens Settings', (tester) async {
    var opened = 0;
    await pumpApp(tester, FakeApi({}), Scaffold(
        body: LocationBanner(problem: LocationProblem.denied, online: false, onOpenSettings: () => opened++)));
    expect(find.textContaining("You can't go Online yet."), findsOneWidget);
    expect(find.textContaining('Allow location access in Settings.'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    expect(opened, 1);

    await pumpApp(tester, FakeApi({}), Scaffold(
        body: LocationBanner(problem: LocationProblem.serviceOff, online: true, onOpenSettings: () {})));
    expect(find.text('Location is off. You will not get new job offers until you turn it back on.'), findsOneWidget);
  });

  test('RID-AVAIL-006: location switched off while Online is reported at once; switched on, the position is sent', () async {
    final api = FakeApi({'PUT /courier/status': {'online': true}, 'GET /courier/offers': [], 'POST /courier/heartbeat': {'online': true}});
    await http.runWithClient(() async {
      final cp = CourierProvider();
      await cp.toggleOnlineStatus();
      expect(cp.isOnline, isTrue);

      gps.reading = const LocationReading.unavailable(LocationProblem.serviceOff);
      gps.switches.add(false);
      await settle();
      expect(cp.locationProblem, LocationProblem.serviceOff);
      expect(jsonDecode(api.last('POST', '/courier/heartbeat')!.body), {'location_off': true});

      gps.reading = const LocationReading.at(here);
      gps.switches.add(true);
      await settle();
      expect(cp.locationProblem, isNull);
      expect(jsonDecode(api.last('POST', '/courier/heartbeat')!.body), {'lat': 14.6976, 'lng': 121.088});
      cp.stop();
    }, () => api.client);
  });

  // ── Waybill scanner (RID-PICK-002, 005, 006, 007) ────────────────────────

  final pickedUp = job(status: 'done', shipment: 'picked_up')
    ..['earned'] = 30
    ..['result'] = 'Picked up';

  testWidgets('RID-PICK-002/005: a scanned waybill confirms the pickup; scanning it again shows already picked up', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs': {'active': [job()], 'recent': []},
      'POST /courier/jobs/7/pickup': {'message': 'Parcel picked up.', 'job': pickedUp},
    });
    await http.runWithClient(() async {
      late void Function(String) scan;
      await pumpApp(tester, api, WaybillScannerScreen(
          confirmPickups: true,
          cameraBuilder: (context, onCode) {
            scan = onCode;
            return const SizedBox.expand();
          }));

      scan('TRK-1234567');
      await tester.pumpAndSettle();
      expect(find.text('Picked up TRK-1234567. You earned ₱30.00.'), findsOneWidget);
      expect(jsonDecode(api.last('POST', '/courier/jobs/7/pickup')!.body), {'tracking_number': 'TRK-1234567'});

      // The camera keeps seeing the same waybill: ignored until Scan next
      scan('TRK-1234567');
      await tester.pumpAndSettle();
      expect(api.sent('POST', '/courier/jobs/7/pickup'), hasLength(1));

      // Second scan of the same waybill
      api.routes['GET /courier/jobs'] = {'active': [], 'recent': [pickedUp]};
      api.routes['POST /courier/jobs/7/pickup'] = const Reply(409, {'message': 'This parcel has already been picked up.'});
      await tester.tap(find.text('Scan next'));
      await tester.pumpAndSettle();
      scan('TRK-1234567');
      await tester.pumpAndSettle();
      expect(find.text('This parcel has already been picked up.'), findsOneWidget);
      expect(api.sent('POST', '/courier/jobs/7/pickup'), hasLength(2));
    }, () => api.client);
  });

  testWidgets('RID-PICK-002: opened from a pickup job, the scanner returns the tracking number it read', (tester) async {
    String? result;
    await pumpApp(tester, FakeApi({}), Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await Navigator.push<String>(context, MaterialPageRoute(
              builder: (_) => WaybillScannerScreen(
                  cameraBuilder: (_, onCode) =>
                      TextButton(onPressed: () => onCode(' TRK-1234567 '), child: const Text('barcode in view'))))),
          child: const Text('open scanner'),
        ),
      ),
    ));
    await tester.tap(find.text('open scanner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('barcode in view'));
    await tester.pumpAndSettle();
    expect(result, 'TRK-1234567');
  });

  testWidgets('RID-PICK-006: camera access denied explains it, offers Settings, and typing still confirms the pickup', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs': {'active': [job()], 'recent': []},
      'POST /courier/jobs/7/pickup': {'message': 'Parcel picked up.', 'job': pickedUp},
    });
    await http.runWithClient(() async {
      await pumpApp(tester, api, WaybillScannerScreen(
          confirmPickups: true, cameraBuilder: (_, __) => const CameraUnavailable(permissionDenied: true)));
      expect(find.text('Camera access is needed to scan the waybill.'), findsOneWidget);
      expect(find.text('Allow camera access for TaptapGo in Settings, or type the tracking number below.'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('scanTypedField')), 'trk-1234567');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Picked up TRK-1234567. You earned ₱30.00.'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('RID-PICK-007: a scan with no internet is refused with a message; back online it is picked up once', (tester) async {
    final api = FakeApi({'GET /courier/jobs': {'active': [job()], 'recent': []}});
    await http.runWithClient(() async {
      final cp = CourierProvider();
      await cp.loadJobs(); // jobs were loaded before the signal was lost
      api.routes['GET /courier/jobs'] = offline;
      api.routes['POST /courier/jobs/7/pickup'] = offline;
      late void Function(String) scan;
      await pumpApp(tester, api, WaybillScannerScreen(
          confirmPickups: true,
          cameraBuilder: (context, onCode) {
            scan = onCode;
            return const SizedBox.expand();
          }), cp: cp);

      scan('TRK-1234567');
      await tester.pumpAndSettle();
      expect(find.text('No internet connection. Nothing was sent — try again when you are back online.'), findsOneWidget);

      api.routes['GET /courier/jobs'] = {'active': [], 'recent': [pickedUp]};
      api.routes['POST /courier/jobs/7/pickup'] = {'message': 'Parcel picked up.', 'job': pickedUp};
      await tester.tap(find.text('Scan next'));
      await tester.pumpAndSettle();
      scan('TRK-1234567');
      await tester.pumpAndSettle();
      expect(find.text('Picked up TRK-1234567. You earned ₱30.00.'), findsOneWidget);
    }, () => api.client);
  });

  // ── Offline delivery and delivery location (RID-DLV-009, RID-DLV-011) ─────

  test('RID-DLV-009/011: a delivery made with no internet is kept, survives reopening the app, and is sent once with its location', () async {
    final dir = await Directory.systemTemp.createTemp('pod');
    addTearDown(() => dir.delete(recursive: true));
    PendingDeliveryStore.photoDir = () async => dir;
    final photo = File('${dir.path}${Platform.pathSeparator}camera.jpg')..writeAsBytesSync([1, 2, 3]);
    final delivering = RiderJob.fromJson(job(id: 9, type: 'delivery', shipment: 'out_for_delivery'));
    final api = FakeApi({
      'POST /courier/jobs/9/deliver': offline,
      'GET /courier/dashboard': {'is_online': false},
      'GET /courier/jobs': {'active': [], 'recent': []},
      'GET /courier/offers': [],
    });
    await http.runWithClient(() async {
      final cp = CourierProvider();
      expect(await cp.deliver(delivering, photo: photo, otp: '123456', codAmount: '500.00'), isNull);
      expect(cp.error, 'No internet connection. The delivery is saved on this phone and will be sent when you are back online.');
      final saved = cp.pendingFor(9)!;
      expect([saved.otp, saved.codAmount], ['123456', '500.00']);
      expect(saved.photoPath, isNot(photo.path)); // a copy outside the camera cache
      expect(File(saved.photoPath).readAsBytesSync(), [1, 2, 3]);

      // The app is closed and reopened, still with no internet
      final reopened = CourierProvider();
      await reopened.loadDashboard();
      await settle();
      expect(reopened.pendingFor(9)?.otp, '123456');

      // Back online
      api.routes['POST /courier/jobs/9/deliver'] = {
        'message': 'Parcel delivered.',
        'job': job(id: 9, type: 'delivery', status: 'done', shipment: 'delivered'),
      };
      await reopened.syncPending();
      final attempts = api.sent('POST', '/courier/jobs/9/deliver');
      expect(attempts, hasLength(3)); // first try and the retry on reopening never reached the server
      expect(multipartFields(attempts.last),
          {'otp': '123456', 'cod_amount': '500.00', 'lat': '14.6976', 'lng': '121.088'});
      expect(attempts.last.body, contains('name="photo"'));
      expect(reopened.pendingDeliveries, isEmpty);
      expect(await PendingDeliveryStore.load(), isEmpty);
      expect(File(saved.photoPath).existsSync(), isFalse);

      await reopened.syncPending();
      expect(api.sent('POST', '/courier/jobs/9/deliver'), hasLength(3)); // recorded once
    }, () => api.client);
  });

  // ── Cross-role: buyer → seller return trips ─────────────────────────────

  testWidgets('A return trip to the seller needs no delivery code and collects no COD', (tester) async {
    final returned = job(
      id: 9,
      type: 'delivery',
      shipment: 'out_for_delivery',
      direction: 'reverse',
      returnNumber: 'RET-000042',
    );
    final api = FakeApi({'GET /courier/jobs/9': returned});
    final parsed = RiderJob.fromJson(returned);
    expect(parsed.isReturn, isTrue);
    expect(parsed.collectsCod, isFalse);

    await http.runWithClient(() async {
      final cp = CourierProvider();
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9), cp: cp);
      await tester.pumpAndSettle();

      expect(find.text('Return Delivery'), findsOneWidget);
      expect(find.text('Deliver back to seller'), findsOneWidget);
      expect(find.text('Return RET-000042 · Buyer → seller'), findsOneWidget);
      expect(find.text('No pay for a return trip'), findsOneWidget);
      // No code to ask the seller for, and nothing to collect
      expect(find.byKey(const Key('otpField')), findsNothing);
      expect(find.byKey(const Key('codField')), findsNothing);
      expect(find.textContaining('there is no delivery code'), findsOneWidget);

      await tester.tap(find.text('Mark as Returned'));
      await tester.pumpAndSettle();
      // Only the photo is missing — the code is not asked for
      expect(find.text('Take a proof-of-delivery photo.'), findsOneWidget);
    }, () => api.client);
  });

  testWidgets('A23: what logistics sends the rider shows as notifications and can be marked read', (tester) async {
    final api = FakeApi({
      'GET /rider/notifications': {
        'data': [
          {
            'id': 'n1',
            'data': {
              'assignment_id': 7,
              'kind': 'offered',
              'message': 'New pickup offered to you.',
            },
            'read_at': null,
            'created_at': '2026-10-28T09:00:00+08:00',
          },
          {
            'id': 'n2',
            'data': {
              'kind': 'cancelled',
              'message': 'An assignment was cancelled.',
            },
            'read_at': '2026-10-28T08:00:00+08:00',
            'created_at': '2026-10-28T07:00:00+08:00',
          },
        ],
      },
      'POST /rider/notifications/read': {'message': 'Notifications marked as read.'},
    });

    await http.runWithClient(() async {
      final cp = CourierProvider();
      await pumpApp(tester, api, const RiderNotificationsScreen(), cp: cp);
      await tester.pumpAndSettle();

      expect(cp.unreadNotifications, 1);
      expect(find.text('New pickup offered to you.'), findsOneWidget);
      expect(find.text('An assignment was cancelled.'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Open job'), findsOneWidget);

      await tester.tap(find.byKey(const Key('markAllRead')));
      await tester.pumpAndSettle();

      expect(cp.unreadNotifications, 0);
      expect(api.sent('POST', '/rider/notifications/read'), hasLength(1));
    }, () => api.client);
  });

  test('RID-AVAIL-004: logging out marks an Online rider Offline first', () async {
    final api = FakeApi({
      'GET /courier/dashboard': {'is_online': true},
      'GET /courier/jobs': {'active': [], 'recent': []},
      'GET /courier/offers': [],
      'PUT /courier/status': {'online': false},
    });
    await http.runWithClient(() async {
      final cp = CourierProvider();
      await cp.loadDashboard();
      expect(cp.isOnline, isTrue);

      await cp.goOffline();
      expect(cp.isOnline, isFalse);
      final put = api.last('PUT', '/courier/status');
      expect(jsonDecode(put!.body), {'online': false});
      cp.stop();
    }, () => api.client);
  });

  testWidgets('RID-DLV-009: after reopening the app, the job shows the delivery is not sent yet, with the photo, code and amount kept', (tester) async {
    final api = FakeApi({
      'GET /courier/jobs/9': job(id: 9, type: 'delivery', shipment: 'out_for_delivery'),
      'GET /courier/dashboard': {'is_online': false},
      'GET /courier/jobs': {'active': [], 'recent': []},
      'GET /courier/offers': [],
      'POST /courier/jobs/9/deliver': offline,
    });
    final cp = CourierProvider();
    late Directory dir;
    // Real files: the saved photo, and the app starting up with no internet
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('pod');
      final photo = File('${dir.path}${Platform.pathSeparator}job_9.jpg')
        ..writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));
      SharedPreferences.setMockInitialValues({
        'pending_deliveries': jsonEncode([
          {'job_id': 9, 'tracking_number': 'TRK-1234567', 'otp': '123456', 'cod_amount': '500.00',
           'photo_path': photo.path, 'lat': 14.6976, 'lng': 121.088, 'saved_at': '2026-10-28T10:00:00', 'error': null},
        ]),
      });
      await http.runWithClient(() async {
        await cp.loadDashboard();
        await settle();
      }, () => api.client);
    });
    addTearDown(() => dir.deleteSync(recursive: true));

    await http.runWithClient(() async {
      await pumpApp(tester, api, const RiderJobScreen(jobId: 9), cp: cp);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pendingBanner')), findsOneWidget);
      expect(find.textContaining('Not sent yet.'), findsOneWidget);
      expect(find.text('Retry now'), findsOneWidget);
      expect(find.text('Retake photo'), findsOneWidget); // the saved photo is back
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('500.00'), findsOneWidget);
    }, () => api.client);
  });
}
