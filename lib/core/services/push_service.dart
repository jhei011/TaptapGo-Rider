import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../demo/demo_api.dart' show kDemoMode;
import 'api.dart';

/// What a push notification is about, from the data the server puts in it
/// (AssignmentUpdate::toPush and LinehaulTripUpdate::toPush).
class PushTap {
  /// 'job' (Rider panel) or 'trip' (Linehaul Courier panel).
  final String type;

  /// offered | cancelled | expired (jobs), assigned | cancelled | completed (trips).
  final String kind;

  /// The job (assignment) or trip id.
  final int? id;

  const PushTap({required this.type, this.kind = '', this.id});

  static PushTap? fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (type != 'job' && type != 'trip') return null;
    final raw = type == 'job' ? data['assignment_id'] : data['trip_id'];
    return PushTap(type: type, kind: data['kind']?.toString() ?? '', id: int.tryParse(raw?.toString() ?? ''));
  }

  /// A job or trip that is still there to look at. A cancelled or expired one is no longer
  /// the rider's, so the Rider panel shows the notification list instead.
  bool get opensDetail => id != null && kind != 'cancelled' && kind != 'expired';
}

/// A push that arrived while the app was open (Android does not show those itself).
class PushMessage {
  final String title;
  final String body;
  final PushTap? tap;
  const PushMessage({required this.title, required this.body, this.tap});
}

/// Push notifications through Firebase Cloud Messaging (Android).
///
/// After login the phone's token is sent to POST /api/device-tokens; the server pushes new
/// jobs, cancelled jobs and linehaul trips to it. Logging out deletes the login on the
/// server, and the phone's token with it. Off in demo builds, on the web and in tests.
class PushService {
  PushService._();

  /// Tests and the demo never talk to Firebase.
  static bool enabled = !kIsWeb && !kDemoMode && Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST');

  /// A notification the rider tapped, waiting for the right panel to open it.
  static final ValueNotifier<PushTap?> pendingTap = ValueNotifier(null);

  static final _received = StreamController<PushMessage>.broadcast();

  /// Pushes received while the app is open: shown as a banner, and the panel refreshes.
  static Stream<PushMessage> get received => _received.stream;

  /// Tests: a push arriving while the app is open.
  @visibleForTesting
  static void debugReceive(PushMessage m) => _received.add(m);

  static bool _started = false;

  /// Sets up Firebase once and sends this phone's token to the server. Safe to call on every
  /// login and app start; problems are only logged (push is a convenience, never a blocker).
  static Future<void> register() async {
    if (!enabled) return;
    try {
      await _start();
      final messaging = FirebaseMessaging.instance;
      // Android 13+ asks the rider once; before that notifications are allowed by default
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // The classic FCM registration token: the server's HTTP v1 send targets it. (The newer
      // register()/onRegistered gives an installation ID for a different send API.)
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _sendToken(token);
    } catch (e) {
      debugPrint('Push notifications not set up: $e');
    }
  }

  /// The panel takes a tapped notification meant for it ([type] 'job' or 'trip').
  static PushTap? takeTap(String type) {
    final tap = pendingTap.value;
    if (tap == null || tap.type != type) return null;
    pendingTap.value = null;
    return tap;
  }

  /// After logout: a notification tapped for the previous login must not open later.
  static void clear() => pendingTap.value = null;

  static Future<void> _start() async {
    if (_started) return;
    _started = true;
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;

    // Firebase sometimes gives the phone a new token; keep the server's copy current
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((token) async {
      if (await Api.getToken() != null) _sendToken(token).catchError((_) {});
    });
    // Open in the foreground: Android shows nothing, the app shows a banner
    FirebaseMessaging.onMessage.listen((m) => _received.add(PushMessage(
          title: m.notification?.title ?? 'TaptapGo',
          body: m.notification?.body ?? '',
          tap: PushTap.fromData(m.data),
        )));
    // Tapped while the app was in the background, or the tap that started the app
    FirebaseMessaging.onMessageOpenedApp.listen((m) => pendingTap.value = PushTap.fromData(m.data));
    final initial = await messaging.getInitialMessage();
    if (initial != null) pendingTap.value = PushTap.fromData(initial.data);
  }

  static Future<void> _sendToken(String token) =>
      Api.post('/device-tokens', body: {'token': token, 'platform': 'android'});
}
