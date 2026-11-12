import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../services/location_service.dart';

/// Demo build: `flutter run --dart-define=DEMO=true`. It opens the app without an account, server
/// or database. Every request is answered here on the device, so nothing can reach the real
/// system. Normal builds do not have this switch on and still need a real login.
const bool kDemoMode = bool.fromEnvironment('DEMO');

/// `courier` is the rider dashboard; `linehaul` is the courier (hub to hub) home screen.
const String kDemoRole = String.fromEnvironment('DEMO_ROLE', defaultValue: 'courier');

/// A fixed position in place of the phone's GPS, so Go Online works anywhere.
class DemoLocation implements LocationSource {
  @override
  Future<LocationReading> current({bool ask = false}) async =>
      const LocationReading.at(RiderPosition(14.6976, 121.0880));

  @override
  Stream<bool> enabledChanges() => const Stream<bool>.empty();

  @override
  Future<void> openSettings(LocationProblem problem) async {}
}

/// In-memory stand-in for the API. Changes last until the app is closed.
class DemoApi {
  DemoApi({this.role = kDemoRole});

  final String role;
  bool _online = false;
  double _earnedToday = 80;
  double _codBalance = 500;
  double _remitted = 0;

  late final List<Map<String, dynamic>> _offers = [
    {'id': 3, 'seconds_left': 60, 'job': _job(id: 11, tracking: 'TRK-1234570', orderId: 44)},
  ];
  late final List<Map<String, dynamic>> _active = [
    _job(id: 7, tracking: 'TRK-1234567', orderId: 41),
    _job(id: 9, tracking: 'TRK-1234568', orderId: 42, type: 'delivery', shipment: 'out_for_delivery'),
  ];
  /// What logistics/admin sent the rider (A23), as on GET /rider/notifications.
  late final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'n1',
      'data': {
        'assignment_id': 7,
        'kind': 'offered',
        'message': 'New pickup offered to you.',
      },
      'read_at': null,
      'created_at': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
    },
    {
      'id': 'n2',
      'data': {
        'kind': 'cancelled',
        'message': 'An assignment was cancelled: the buyer changed the delivery address.',
      },
      'read_at': null,
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    },
  ];

  late final List<Map<String, dynamic>> _recent = [
    _job(id: 5, tracking: 'TRK-1234566', orderId: 40, type: 'delivery', status: 'done', shipment: 'delivered')
      ..['earned'] = 50
      ..['result'] = 'Delivered',
    _job(id: 4, tracking: 'TRK-1234566', orderId: 40, status: 'done', shipment: 'picked_up')
      ..['earned'] = 30
      ..['result'] = 'Picked up',
  ];

  late final http.Client client = MockClient((request) async {
    final path = request.url.path.replaceFirst(RegExp(r'^/api'), '');
    final reply = _answer(request, path);
    return http.Response.bytes(utf8.encode(jsonEncode(reply.body)), reply.status,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });

  _Reply _answer(http.Request request, String path) {
    final route = '${request.method} $path';
    final job = RegExp(r'^/courier/jobs/(\d+)').firstMatch(path);
    final offer = RegExp(r'^/courier/offers/(\d+)/(accept|decline)$').firstMatch(path);

    if (offer != null) return _respondToOffer(int.parse(offer.group(1)!), offer.group(2)!);
    if (job != null) return _jobAction(request, int.parse(job.group(1)!), path);

    return switch (route) {
      'GET /me' => _Reply(_user),
      'POST /login' => _Reply({'token': 'demo-token', 'user': _user}),
      'POST /logout' => _Reply({'message': 'Logged out successfully'}),
      'GET /courier/dashboard' => _Reply(_dashboard()),
      'PUT /courier/status' => _setOnline(request),
      'POST /courier/heartbeat' => _Reply({'online': _online, 'location_off': false}),
      'GET /courier/offers' => _Reply(_online ? _offers : const []),
      'GET /courier/jobs' => _Reply({'active': _active, 'recent': _recent}),
      'GET /courier/earnings' => _Reply(_earnings()),
      'GET /courier/cod' => _Reply(_cod()),
      'POST /courier/remittances' => _remit(request),
      'GET /courier/profile' => _Reply(_profile),
      'GET /rider/notifications' => _Reply({'data': _notifications}),
      'POST /rider/notifications/read' => _readNotifications(),
      'GET /linehaul/home' => _Reply(_linehaulHome),
      _ => _Reply({'message': 'This is not available in the demo.'}, 404),
    };
  }

  Map<String, dynamic> get _user => {
        'id': 1,
        'name': role == 'linehaul' ? 'Ernesto Villareal' : 'Pedro Jose Garcia',
        'email': role == 'linehaul' ? 'ernesto.villareal@example.com' : 'pedrojose.garcia@example.com',
        'role': role,
        'status': 'approved',
      };

  Map<String, dynamic> _dashboard() => {
        'is_online': _online,
        'logistics_company': 'Bilis Hatid Express Inc.',
        'total_delivered': _recent.where((j) => j['shipment_status'] == 'delivered').length,
        'active_jobs': _active.length,
        'today_delivered': _recent.where((j) => j['shipment_status'] == 'delivered').length,
        'today_earnings': _earnedToday,
        'total_earnings': _earnedToday,
        'cod_balance': _codBalance,
      };

  _Reply _readNotifications() {
    final now = DateTime.now().toIso8601String();
    for (final n in _notifications) {
      n['read_at'] ??= now;
    }
    return _Reply({'message': 'Notifications marked as read.'});
  }

  _Reply _setOnline(http.Request request) {
    _online = (jsonDecode(request.body) as Map)['online'] == true;
    return _Reply({'online': _online, 'message': _online ? 'You are now online.' : 'You are now offline.'});
  }

  _Reply _respondToOffer(int id, String answer) {
    final index = _offers.indexWhere((o) => o['id'] == id);
    if (index < 0) return _Reply({'message': 'This offer is no longer available.'}, 409);
    final job = _offers.removeAt(index)['job'] as Map<String, dynamic>;
    if (answer == 'decline') return _Reply({'message': 'Offer declined.'});
    _active.add(job);
    return _Reply({'message': 'Job accepted.', 'job': job});
  }

  _Reply _jobAction(http.Request request, int id, String path) {
    final all = [..._active, ..._recent];
    final index = all.indexWhere((j) => j['id'] == id);
    if (index < 0) return _Reply({'message': 'Job not found.'}, 404);
    final job = all[index];
    final action = path.split('/').last;

    switch (action) {
      case 'pickup':
        if (job['status'] != 'assigned') return _Reply({'message': 'This parcel has already been picked up.'}, 409);
        final typed = (jsonDecode(request.body) as Map)['tracking_number'].toString().trim().toUpperCase();
        if (typed != job['tracking_number']) return _Reply({'message': 'The tracking number does not match this job.'}, 422);
        _finish(job, shipment: 'picked_up', result: 'Picked up', status: 'done', earned: 30);
        return _Reply({'message': 'Parcel picked up.', 'job': job});
      case 'out-for-delivery':
        job['shipment_status'] = 'out_for_delivery';
        return _Reply({'message': 'Parcel is out for delivery.', 'job': job});
      case 'deliver':
        // Any 6-digit code and COD amount is accepted: the demo has no buyer to check against
        _codBalance += (job['cod_amount'] as num).toDouble();
        _finish(job, shipment: 'delivered', result: 'Delivered', status: 'done', earned: 50);
        return _Reply({'message': 'Parcel delivered.', 'job': job});
      case 'fail':
        _finish(job, shipment: 'failed_delivery', result: 'Failed', status: 'failed', earned: 0);
        return _Reply({'message': 'Delivery marked as failed.', 'job': job});
      default:
        return _Reply(job);
    }
  }

  void _finish(Map<String, dynamic> job,
      {required String shipment, required String result, required String status, required double earned}) {
    job.addAll({'status': status, 'shipment_status': shipment, 'result': result, 'earned': earned});
    _earnedToday += earned;
    _active.remove(job);
    _recent.insert(0, job);
  }

  Map<String, dynamic> _earnings() => {
        'today_earnings': _earnedToday,
        'week_earnings': _earnedToday,
        'month_earnings': _earnedToday,
        'total_earnings': _earnedToday,
        'total_delivered': _recent.where((j) => j['shipment_status'] == 'delivered').length,
        'history': [
          for (final j in _recent)
            {
              'job_id': j['id'], 'date': DateTime.now().toIso8601String(), 'tracking_number': j['tracking_number'],
              'type': j['type'], 'result': j['result'], 'pay': j['earned'],
            },
        ],
      };

  Map<String, dynamic> _cod() => {
        'balance': _codBalance,
        'pending_total': _remitted,
        'collected': [
          {'order_id': 40, 'tracking_number': 'TRK-1234566', 'amount': 500},
        ],
        'remittances': [
          if (_remitted > 0) {'id': 1, 'amount': _remitted, 'shortfall': 0, 'status': 'pending'},
        ],
      };

  _Reply _remit(http.Request request) {
    _remitted = ((jsonDecode(request.body) as Map)['amount'] as num).toDouble();
    return _Reply({
      'message': 'Remittance submitted.',
      'remittance': {'id': 1, 'amount': _remitted, 'status': 'pending'},
      'cod': _cod(),
    }, 201);
  }

  static const _profile = {
    'id': 1, 'name': 'Pedro Jose Garcia', 'email': 'pedrojose.garcia@example.com', 'status': 'approved',
    'logistics_company': 'Bilis Hatid Express Inc.', 'driver_license_number': 'N01-23-456789',
    'license_expiry_date': '2030-03-22', 'vehicle_type': 'motorcycle', 'plate_number': '123ABC',
    'needs_reverification': false,
    'documents': {
      'driver_license': {'name': 'drivers_license.jpg', 'url': 'https://example.com/demo-document'},
      'or_cr': {'name': 'or_cr.pdf', 'url': 'https://example.com/demo-document'},
    },
  };

  static const _linehaulHome = {
    'name': 'Ernesto Villareal', 'email': 'ernesto.villareal@example.com',
    'logistics_company': 'Bilis Hatid Express Inc.',
    'home_hub': {'code': 'HUB-QC', 'name': 'Bilis Hatid QC First-Mile Hub'},
    'vehicle_type': '4-Wheeler Closed Van Truck', 'plate_number': 'NAB4521', 'load_capacity_kg': 3000,
    'duty_status': 'Off Duty',
  };

  static Map<String, dynamic> _job({
    required int id, required String tracking, required int orderId,
    String type = 'pickup', String status = 'assigned', String shipment = 'awaiting_pickup',
  }) =>
      {
        'id': id, 'type': type, 'status': status, 'shipment_status': shipment, 'attempt': 1, 'max_attempts': 3,
        'tracking_number': tracking, 'order_id': orderId, 'parcels': 1, 'pay': type == 'pickup' ? 30 : 50,
        'earned': 0, 'result': null, 'payment_method': 'cod', 'cod_amount': 500,
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
        'failed_reason': null,
        'times': {'assigned': DateTime.now().toIso8601String()},
        'pod_photo_url': null,
      };
}

class _Reply {
  final Object body;
  final int status;
  _Reply(this.body, [this.status = 200]);
}
