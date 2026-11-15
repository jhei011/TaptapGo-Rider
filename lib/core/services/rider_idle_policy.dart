import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import 'api.dart';
import 'courier_service.dart';
import 'pending_delivery_store.dart';

/// What the server says about the rider's work in hand.
enum WorkCheck {
  /// No job, offer, trip or unsent delivery: the idle timeout may sign the rider out.
  none,

  /// Something still needs the rider: never sign them out.
  active,

  /// The server could not be asked (no internet, server error). Treated like [active]:
  /// not being able to check is never taken as "no delivery".
  unknown,
}

/// The rider's idle logout (30 minutes), which never interrupts a delivery.
///
/// - Only one timer exists at a time; [activity] restarts the 30 minutes.
/// - When the 30 minutes are up, the **server** is asked whether the rider has work
///   ([checkWork]): jobs, offers, linehaul trips, plus deliveries saved on the phone and
///   not sent yet. Any work, or no answer, keeps the rider signed in and is checked again
///   every [recheckWhileWorking].
/// - Once the work is closed (delivered, failed, cancelled), the rider gets a fresh
///   30 minutes before being signed out.
/// - Nothing happens while the app is in the background (Maps, a call, the camera, a
///   locked screen). Back in the app, the same rule is applied: signed out only if 30
///   minutes passed without activity *and* the server says there is no work.
/// - Account suspension does not depend on this: the server refuses the rider's token
///   at once, whatever this policy decides.
class RiderIdlePolicy {
  RiderIdlePolicy({
    required this.checkWork,
    required this.onIdleTimeout,
    Duration? timeout,
    this.recheckWhileWorking = const Duration(minutes: 5),
  }) : timeout = timeout ?? configuredTimeout;

  /// 30 minutes. Debug builds may shorten it for testing on a device with
  /// `--dart-define=RIDER_IDLE_SECONDS=60`; release builds always use 30 minutes.
  static Duration get configuredTimeout {
    const seconds = int.fromEnvironment('RIDER_IDLE_SECONDS');
    return !kReleaseMode && seconds > 0 ? const Duration(seconds: seconds) : const Duration(minutes: 30);
  }

  final Duration timeout;
  final Duration recheckWhileWorking;
  final Future<WorkCheck> Function() checkWork;
  final Future<void> Function() onIdleTimeout;

  Timer? _timer;
  DateTime _lastActivity = clock.now();
  bool _running = false;
  bool _foreground = true;
  bool _checking = false;
  bool _hadWork = false;

  bool get running => _running;

  /// True while the last server check found work (or could not be made).
  bool get protectingWork => _hadWork;

  /// The rider signed in (or the app opened with a saved login).
  void start() {
    if (_running) return;
    _running = true;
    _hadWork = false;
    _lastActivity = clock.now();
    _schedule();
  }

  /// The rider signed out, or was signed out: no timer is left behind.
  void stop() {
    _running = false;
    _hadWork = false;
    _timer?.cancel();
    _timer = null;
  }

  /// A touch on the screen: the 30 minutes start again.
  void activity() {
    if (!_running) return;
    _lastActivity = clock.now();
    if (_foreground && !_checking) _schedule();
  }

  /// The app went to the background (Maps, a call, the camera, the lock screen).
  void paused() {
    _foreground = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Back in the app: apply the rule now (and ask the server if the 30 minutes are up).
  void resumed() {
    _foreground = true;
    if (_running) _evaluate();
  }

  void _schedule([Duration? after]) {
    _timer?.cancel();
    _timer = null;
    if (!_running || !_foreground) return;
    final wait = after ?? (_lastActivity.add(timeout).difference(clock.now()));
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _evaluate);
  }

  Future<void> _evaluate() async {
    if (!_running || _checking) return;
    if (clock.now().difference(_lastActivity) < timeout) {
      _schedule();
      return;
    }
    _checking = true;
    WorkCheck work;
    try {
      work = await checkWork();
    } catch (_) {
      work = WorkCheck.unknown;
    } finally {
      _checking = false;
    }
    if (!_running) return;

    if (work != WorkCheck.none) {
      // A job, offer, trip or unsent delivery (or no answer from the server): stay signed in
      _hadWork = true;
      _schedule(recheckWhileWorking);
      return;
    }
    if (_hadWork) {
      // The work was just closed: a fresh 30 minutes from now
      _hadWork = false;
      _lastActivity = clock.now();
      _schedule();
      return;
    }
    stop();
    await onIdleTimeout();
  }
}

/// Asks the server whether a rider (role `courier`) has work in hand. Deliveries saved on
/// the phone and not sent yet count as work, whatever the server says.
Future<WorkCheck> riderWorkCheck() async {
  try {
    final unsent = await PendingDeliveryStore.load();
    if (unsent.isNotEmpty) return WorkCheck.active;
    final jobs = await CourierService.jobs();
    if (jobs.active.isNotEmpty) return WorkCheck.active;
    final offers = await CourierService.offers();
    return offers.isNotEmpty ? WorkCheck.active : WorkCheck.none;
  } catch (_) {
    return WorkCheck.unknown;
  }
}

/// Asks the server whether a linehaul courier has an active trip.
Future<WorkCheck> linehaulWorkCheck() async {
  try {
    final trips = await Api.get('/linehaul/trips') as List;
    return trips.isNotEmpty ? WorkCheck.active : WorkCheck.none;
  } catch (_) {
    return WorkCheck.unknown;
  }
}
