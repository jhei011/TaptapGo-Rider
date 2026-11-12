import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:geolocator/geolocator.dart';

/// Why the app has no position for the rider.
enum LocationProblem {
  /// Location is switched off in the phone's quick settings.
  serviceOff,

  /// Location access for the app is set to Don't Allow.
  denied,
}

class RiderPosition {
  final double lat;
  final double lng;
  const RiderPosition(this.lat, this.lng);
}

/// A position, or the reason there is none.
class LocationReading {
  final RiderPosition? position;
  final LocationProblem? problem;
  const LocationReading.at(RiderPosition this.position) : problem = null;
  const LocationReading.unavailable(LocationProblem this.problem) : position = null;
}

/// The phone's location (Rider Modules RID-AVAIL-005, RID-AVAIL-006, RID-DLV-011).
/// Tests replace [source] with a fake.
class LocationService {
  static LocationSource source = DeviceLocation();

  static Future<LocationReading> current({bool ask = false}) async {
    try {
      return await source.current(ask: ask);
    } catch (_) {
      return const LocationReading.unavailable(LocationProblem.serviceOff);
    }
  }
  static Stream<bool> enabledChanges() => source.enabledChanges();
  static Future<void> openSettings(LocationProblem problem) => source.openSettings(problem);

  static String message(LocationProblem problem) => switch (problem) {
        LocationProblem.serviceOff =>
          'Location is turned off. Turn it on so your logistics company can send you jobs nearby.',
        LocationProblem.denied =>
          'TaptapGo needs your location to go Online. Allow location access in Settings.',
      };
}

abstract class LocationSource {
  /// The current position. With [ask], the app asks for location access if it has not been decided yet.
  Future<LocationReading> current({bool ask = false});

  /// Emits false when location is switched off and true when it is switched back on.
  Stream<bool> enabledChanges();

  Future<void> openSettings(LocationProblem problem);
}

class DeviceLocation implements LocationSource {
  @override
  Future<LocationReading> current({bool ask = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationReading.unavailable(LocationProblem.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LocationReading.unavailable(LocationProblem.denied);
    }
    try {
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: kDebugMode
                ? LocationAccuracy.medium
                : LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ));
      return LocationReading.at(RiderPosition(p.latitude, p.longitude));
    } on LocationServiceDisabledException {
      return const LocationReading.unavailable(LocationProblem.serviceOff);
    } on TimeoutException {
      // Weak GPS signal indoors: fall back to the last fix the phone has
      final last = await Geolocator.getLastKnownPosition();
      return last == null
          ? const LocationReading.unavailable(LocationProblem.serviceOff)
          : LocationReading.at(RiderPosition(last.latitude, last.longitude));
    }
  }

  @override
  Stream<bool> enabledChanges() =>
      Geolocator.getServiceStatusStream().map((s) => s == ServiceStatus.enabled);

  @override
  Future<void> openSettings(LocationProblem problem) async {
    if (problem == LocationProblem.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
