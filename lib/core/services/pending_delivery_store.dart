import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

/// A delivery the rider completed with no internet (RID-DLV-009). It is kept on the
/// phone, with a copy of the proof photo, until the server has recorded it.
class PendingDelivery {
  final int jobId;
  final String trackingNumber;
  final String otp;
  final String? codAmount;
  final String photoPath;
  final RiderPosition? position;
  final DateTime savedAt;

  /// The server's reason when it refused the saved delivery (e.g. a wrong code); it is not retried automatically.
  final String? error;

  const PendingDelivery({
    required this.jobId, required this.trackingNumber, required this.otp, this.codAmount,
    required this.photoPath, this.position, required this.savedAt, this.error,
  });

  PendingDelivery withError(String? error) => PendingDelivery(
      jobId: jobId, trackingNumber: trackingNumber, otp: otp, codAmount: codAmount,
      photoPath: photoPath, position: position, savedAt: savedAt, error: error);

  Map<String, dynamic> toJson() => {
        'job_id': jobId, 'tracking_number': trackingNumber, 'otp': otp, 'cod_amount': codAmount,
        'photo_path': photoPath, 'lat': position?.lat, 'lng': position?.lng,
        'saved_at': savedAt.toIso8601String(), 'error': error,
      };

  factory PendingDelivery.fromJson(Map<String, dynamic> j) => PendingDelivery(
        jobId: j['job_id'] as int,
        trackingNumber: j['tracking_number'] as String? ?? '',
        otp: j['otp'] as String? ?? '',
        codAmount: j['cod_amount'] as String?,
        photoPath: j['photo_path'] as String? ?? '',
        position: j['lat'] == null ? null : RiderPosition((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        savedAt: DateTime.tryParse(j['saved_at'] as String? ?? '') ?? DateTime.now(),
        error: j['error'] as String?,
      );
}

class PendingDeliveryStore {
  static const _key = 'pending_deliveries';

  /// Where photo copies are kept. Tests point this at a temporary folder.
  static Future<Directory> Function() photoDir = getApplicationDocumentsDirectory;

  static Future<List<PendingDelivery>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => PendingDelivery.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  static Future<void> save(List<PendingDelivery> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(items.map((p) => p.toJson()).toList()));
    }
  }

  /// Copies the camera photo out of the image picker's cache, which the phone may clear.
  static Future<String> keepPhoto(File photo, int jobId) async {
    final dir = Directory('${(await photoDir()).path}${Platform.pathSeparator}pending_pod');
    await dir.create(recursive: true);
    final target = '${dir.path}${Platform.pathSeparator}job_$jobId.jpg';
    if (photo.path == target) return target; // re-sending a delivery that is already saved
    return (await photo.copy(target)).path;
  }

  static Future<void> deletePhoto(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
