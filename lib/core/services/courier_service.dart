import 'dart:io';
import 'api.dart';
import 'location_service.dart';
import '../../models/rider_job.dart';
import '../../models/rider_notification.dart';

class CourierService {
  // ── Dashboard ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> dashboard() async =>
      await Api.get('/courier/dashboard') as Map<String, dynamic>;

  // ── Online / Offline toggle ───────────────────────────────────────────────
  /// PUT /courier/status  body: { online: true|false, lat, lng }
  /// Going Online needs the phone's position (RID-AVAIL-005). Returns updated status from server.
  static Future<bool> setOnlineStatus(bool online, {RiderPosition? position}) async {
    final d = await Api.put('/courier/status', body: {
      'online': online,
      if (position != null) 'lat': position.lat,
      if (position != null) 'lng': position.lng,
    }) as Map<String, dynamic>;
    return (d['online'] as bool?) ?? online;
  }

  /// POST /courier/heartbeat — sent every minute while Online with the position, or
  /// location_off when location is switched off (RID-AVAIL-006). Without it the
  /// rider shows Offline after 5 minutes (RID-AVAIL-007).
  static Future<void> heartbeat({RiderPosition? position}) => Api.post('/courier/heartbeat',
      body: position == null ? {'location_off': true} : {'lat': position.lat, 'lng': position.lng});

  // ── Job offers ────────────────────────────────────────────────────────────
  static Future<List<JobOffer>> offers() async {
    final d = await Api.get('/courier/offers') as List;
    return d.map((o) => JobOffer.fromJson((o as Map).cast<String, dynamic>())).toList();
  }

  static Future<RiderJob> acceptOffer(int id) async =>
      _job(await Api.post('/courier/offers/$id/accept'));

  static Future<void> declineOffer(int id) => Api.post('/courier/offers/$id/decline');

  // ── Jobs ──────────────────────────────────────────────────────────────────
  static Future<({List<RiderJob> active, List<RiderJob> recent})> jobs() async {
    final d = await Api.get('/courier/jobs') as Map<String, dynamic>;
    List<RiderJob> list(String key) => (d[key] as List? ?? [])
        .map((j) => RiderJob.fromJson((j as Map).cast<String, dynamic>()))
        .toList();
    return (active: list('active'), recent: list('recent'));
  }

  static Future<RiderJob> job(int id) async =>
      RiderJob.fromJson(await Api.get('/courier/jobs/$id') as Map<String, dynamic>);

  static Future<RiderJob> confirmPickup(int id, String trackingNumber) async => _job(
      await Api.post('/courier/jobs/$id/pickup', body: {'tracking_number': trackingNumber}));

  static Future<RiderJob> startDelivery(int id) async =>
      _job(await Api.post('/courier/jobs/$id/out-for-delivery'));

  static Future<RiderJob> deliver(int id,
          {required File photo, required String otp, String? codAmount, RiderPosition? position}) async =>
      _job(await Api.postMultipart('/courier/jobs/$id/deliver', fields: {
        'otp': otp,
        if (codAmount != null) 'cod_amount': codAmount,
        // Where the delivery was completed (RID-DLV-011)
        if (position != null) 'lat': '${position.lat}',
        if (position != null) 'lng': '${position.lng}',
      }, files: {
        'photo': photo,
      }));

  static Future<RiderJob> fail(int id, String reason) async =>
      _job(await Api.post('/courier/jobs/$id/fail', body: {'reason': reason}));

  /// POST /rider/tasks/{id}/reject — the rider gives back a job they have not started.
  /// The job id is the hub-network task assignment id, the same id /rider/tasks uses.
  /// The server allows it only before the parcel is collected (AssignmentService::reject):
  /// a pickup returns to "ready for pickup", a delivery to the hub's sorted queue.
  static Future<void> declineJob(int id, String reason) =>
      Api.post('/rider/tasks/$id/reject', body: {'reason': reason});

  // ── Earnings and COD ──────────────────────────────────────────────────────
  /// GET /courier/earnings — totals and the job history between [from] and [to]
  static Future<Map<String, dynamic>> earnings({DateTime? from, DateTime? to}) async =>
      await Api.get('/courier/earnings', query: {
        if (from != null) 'from': _date(from),
        if (to != null) 'to': _date(to),
      }) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> cod() async =>
      await Api.get('/courier/cod') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> remit(double amount) async =>
      await Api.post('/courier/remittances', body: {'amount': amount}) as Map<String, dynamic>;

  // ── Profile ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> profile() async =>
      await Api.get('/courier/profile') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateVehicle({String? plateNumber, File? orCr}) async =>
      (await Api.postMultipart('/courier/profile/vehicle', fields: {
        if (plateNumber != null) 'plate_number': plateNumber,
      }, files: {
        if (orCr != null) 'or_cr': orCr,
      }) as Map<String, dynamic>)['profile'] as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateLicense({DateTime? expiry, File? document}) async =>
      (await Api.postMultipart('/courier/profile/license', fields: {
        if (expiry != null) 'license_expiry_date': _date(expiry),
      }, files: {
        if (document != null) 'driver_license_document': document,
      }) as Map<String, dynamic>)['profile'] as Map<String, dynamic>;

  // ── In-app notifications (A23) ────────────────────────────────────────────
  /// GET /rider/notifications — what logistics and admin sent the rider:
  /// a new job, a cancelled job, an expired offer.
  static Future<List<RiderNotification>> notifications() async {
    final d = await Api.get('/rider/notifications') as Map<String, dynamic>;
    return (d['data'] as List? ?? [])
        .map((n) => RiderNotification.fromJson((n as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<void> markNotificationsRead() =>
      Api.post('/rider/notifications/read');

  // ── Rider Activation ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> activationInfo(String token) async =>
      await Api.get('/rider/activation-info',
          query: {'token': token}) as Map<String, dynamic>;

  static Future<void> activate({
    required String token,
    required String password,
    required String passwordConfirmation,
  }) =>
      Api.post('/rider/activate',
          body: {
            'token'                 : token,
            'password'              : password,
            'password_confirmation' : passwordConfirmation,
          },
          auth: false);

  static Future<void> resendActivation(String email) =>
      Api.post('/rider/resend-activation',
          body: {'email': email},
          auth: false);

  static RiderJob _job(dynamic response) =>
      RiderJob.fromJson(((response as Map)['job'] as Map).cast<String, dynamic>());

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
