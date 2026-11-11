// LIVE BACKEND TEST — skipped unless run by the ecosystem E2E script with
//   --dart-define=E2E_STATE=<state.json> --dart-define=E2E_ACCOUNTS=<accounts.json> --dart-define=E2E_PART=<part>
// It drives the app's own AuthProvider / CourierProvider / CourierService over real HTTP
// against a local backend (never production). Credentials come from a file outside the repo.
// The only stand-in is the phone's GPS (a fixed position), since tests have no GPS.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taptap_go/core/services/location_service.dart';
import 'package:taptap_go/models/rider_job.dart';
import 'package:taptap_go/providers/auth_provider.dart';
import 'package:taptap_go/providers/courier_provider.dart';

const _statePath = String.fromEnvironment('E2E_STATE');
const _accountsPath = String.fromEnvironment('E2E_ACCOUNTS');
const _part = String.fromEnvironment('E2E_PART');

class _FixedGps implements LocationSource {
  @override
  Future<LocationReading> current({bool ask = false}) async => const LocationReading.at(RiderPosition(14.2337, 121.3653));
  @override
  Stream<bool> enabledChanges() => const Stream<bool>.empty();
  @override
  Future<void> openSettings(LocationProblem problem) async {}
}

Map<String, dynamic> _read(String p) => (jsonDecode(File(p).readAsStringSync()) as Map).cast<String, dynamic>();
void _save(Map<String, dynamic> s) => File(_statePath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(s));

Future<AuthProvider> _login(String key) async {
  final a = _read(_accountsPath)[key] as Map;
  final auth = AuthProvider();
  final ok = await auth.login(a['email'] as String, a['password'] as String);
  expect(ok, isTrue, reason: 'login $key: ${auth.error}');
  return auth;
}

RiderJob _find(CourierProvider cp, String tracking, {required bool pickup}) =>
    cp.activeJobs.firstWhere((j) => j.trackingNumber == tracking && j.isPickup == pickup,
        orElse: () => throw StateError('no ${pickup ? 'pickup' : 'delivery'} job for $tracking in ${cp.activeJobs.map((j) => j.trackingNumber)}'));

void main() {
  final skip = _statePath.isEmpty ? 'live backend only' : null;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LocationService.source = _FixedGps();
    CourierProvider.connectionChanges = () => const Stream<bool>.empty();
  });

  test('gate: an unapproved rider is refused by the app; an approved rider gets in', () async {
    final a = _read(_accountsPath)['rider_unverified'] as Map;
    final refused = AuthProvider();
    expect(await refused.login(a['email'] as String, a['password'] as String), isFalse);
    expect(refused.error, contains('not approved'));
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);

    final auth = await _login('rider1');
    expect(auth.user!.role, 'courier');
    await auth.logout();
  }, skip: skip ?? (_part == 'gate' ? null : 'part $_part'));

  test('pickup: the job the hub assigned shows in the app and is picked up by scanning its waybill', () async {
    final state = _read(_statePath);
    final tracking = state['tracking'] as String;
    final auth = await _login('rider1');
    final cp = CourierProvider();
    await cp.loadJobs();
    final job = _find(cp, tracking, pickup: true);
    expect(job.canConfirmPickup, isTrue);
    expect(job.canDecline, isTrue);

    final done = await cp.confirmPickup(job.id, tracking);
    expect(done, isNotNull, reason: cp.error);
    expect(done!.status, 'done');
    expect(done.shipmentStatus, 'picked_up');

    // A second scan (e.g. a retry after a lost answer) is refused, nothing changes
    expect(await cp.confirmPickup(job.id, tracking), isNull);
    expect(cp.lastErrorWasConflict, isTrue);
    expect(cp.error, contains('already been picked up'));

    _save({...state, 'pickup_job': job.id});
    cp.stop();
    await auth.logout();
  }, skip: skip ?? (_part == 'pickup' ? null : 'part $_part'));

  test('start: the delivery job appears at the hub and the rider leaves with it', () async {
    final state = _read(_statePath);
    final auth = await _login('rider1');
    final cp = CourierProvider();
    await cp.loadJobs();
    final job = _find(cp, state['tracking'] as String, pickup: false);
    expect(job.canStartDelivery, isTrue);
    expect(job.collectsCod, isTrue);

    final out = await cp.startDelivery(job.id);
    expect(out, isNotNull, reason: cp.error);
    expect(out!.shipmentStatus, 'out_for_delivery');
    expect(out.canFinishDelivery, isTrue);

    _save({...state, 'delivery_job': job.id, 'cod_amount': job.codAmount});
    cp.stop();
    await auth.logout();
  }, skip: skip ?? (_part == 'start' ? null : 'part $_part'));

  test('deliver: proof photo, the code the buyer sees in the Shop app, and the exact COD', () async {
    final state = _read(_statePath);
    final auth = await _login('rider1');
    final cp = CourierProvider();
    final job = await cp.loadJob(state['delivery_job'] as int);
    expect(job, isNotNull, reason: cp.error);

    // A real 1×1 JPEG for the proof-of-delivery upload
    final photo = File('${Directory.systemTemp.path}/e2e_pod_${DateTime.now().millisecondsSinceEpoch}.jpg')
      ..writeAsBytesSync(base64Decode('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k='));

    final wrong = await cp.deliver(job!, photo: photo, otp: state['otp'] == '000000' ? '111111' : '000000',
        codAmount: (state['cod_amount'] as num).toStringAsFixed(2));
    expect(wrong, isNull);
    expect(cp.error, 'The delivery code is incorrect.');
    expect(cp.pendingDeliveries, isEmpty, reason: 'a refusal is not kept for later');

    final done = await cp.deliver(job, photo: photo, otp: state['otp'] as String,
        codAmount: (state['cod_amount'] as num).toStringAsFixed(2));
    expect(done, isNotNull, reason: cp.error);
    expect(done!.status, 'done');
    expect(done.shipmentStatus, 'delivered');

    await cp.loadJobs();
    expect(cp.recentJobs.map((j) => j.id), containsAll([state['pickup_job'], state['delivery_job']]));
    cp.stop();
    await auth.logout();
  }, skip: skip ?? (_part == 'deliver' ? null : 'part $_part'));
}
