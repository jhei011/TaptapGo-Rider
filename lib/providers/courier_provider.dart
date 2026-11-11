import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/services/courier_service.dart';
import '../core/services/api.dart';
import '../core/services/location_service.dart';
import '../core/services/pending_delivery_store.dart';
import '../models/rider_job.dart';
import '../models/rider_notification.dart';

class CourierProvider extends ChangeNotifier {
  Map<String, dynamic>? _dashboard;
  List<JobOffer>        _offers  = [];
  List<RiderJob>        _active  = [];
  List<RiderJob>        _recent  = [];
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _earnings;
  Map<String, dynamic>? _cod;
  List<PendingDelivery> _pending = [];
  List<RiderNotification> _notifications = [];

  bool _loadingNotifications = false;
  String? _notificationError;

  bool _loadingDash     = false;
  bool _loadingJobs     = false;
  bool _loadingEarnings = false;
  bool _togglingOnline  = false;
  bool _started         = false;
  bool _syncing         = false;

  /// Online/offline status — null = unknown (not yet fetched)
  bool? _isOnline;

  /// Why going Online was refused, or why no offers arrive while Online (RID-AVAIL-005/006)
  LocationProblem? _locationProblem;

  String? _error;
  int? _lastErrorStatus;

  Timer? _heartbeat;
  Timer? _offerPoll;
  StreamSubscription<bool>? _locationWatch;
  StreamSubscription<bool>? _connectionWatch;

  /// Emits true when the phone gets a connection back. Tests replace it.
  static Stream<bool> Function() connectionChanges = () => Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  // ── Getters ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? get dashboard       => _dashboard;
  List<JobOffer>         get offers          => _offers;
  List<RiderJob>         get activeJobs      => _active;
  List<RiderJob>         get recentJobs      => _recent;
  Map<String, dynamic>?  get profile         => _profile;
  Map<String, dynamic>?  get earnings        => _earnings;
  Map<String, dynamic>?  get cod             => _cod;
  List<PendingDelivery>  get pendingDeliveries => _pending;
  List<RiderNotification> get notifications   => _notifications;
  bool                   get loadingNotifications => _loadingNotifications;
  String?                get notificationError => _notificationError;
  int                    get unreadNotifications =>
      _notifications.where((n) => !n.isRead).length;
  bool                   get loadingDash     => _loadingDash;
  bool                   get loadingJobs     => _loadingJobs;
  bool                   get loadingEarnings => _loadingEarnings;
  bool                   get togglingOnline  => _togglingOnline;
  bool                   get syncing         => _syncing;
  bool?                  get isOnline        => _isOnline;
  LocationProblem?       get locationProblem => _locationProblem;
  String?                get error           => _error;

  PendingDelivery? pendingFor(int jobId) {
    for (final p in _pending) {
      if (p.jobId == jobId) return p;
    }
    return null;
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    _loadingDash = true; _error = null; notifyListeners();
    await _start();
    try {
      _dashboard = await CourierService.dashboard();
      // Sync online status from dashboard response if present
      if (_dashboard?['is_online'] != null) {
        _setOnline(_dashboard!['is_online'] as bool);
      }
      await Future.wait([loadJobs(), loadOffers(), loadNotifications()]);
    } on ApiError catch (e) { _error = e.message; }
    catch (_) { _error = 'Failed to load dashboard.'; }
    _loadingDash = false; notifyListeners();
    unawaited(syncPending());
  }

  /// Once per session: reload deliveries saved while offline and send them when the connection is back.
  Future<void> _start() async {
    if (_started) return;
    _started = true;
    try {
      _pending = await PendingDeliveryStore.load();
    } catch (_) {}
    _connectionWatch = connectionChanges().listen((connected) {
      if (connected) syncPending();
    }, onError: (_) {});
  }

  // ── Online / Offline ──────────────────────────────────────────────────────
  Future<void> toggleOnlineStatus() async {
    if (_togglingOnline) return;
    final target = !(_isOnline ?? false);
    _togglingOnline = true; _error = null; notifyListeners();
    try {
      RiderPosition? position;
      if (target) {
        // Going Online needs the phone's location (RID-AVAIL-005)
        final reading = await LocationService.current(ask: true);
        _locationProblem = reading.problem;
        position = reading.position;
      }
      if (!target || position != null) {
        _setOnline(await CourierService.setOnlineStatus(target, position: position));
        if (_isOnline == true) await loadOffers();
      }
    } on ApiError catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Connection error. Check your internet and try again.';
    }
    _togglingOnline = false; notifyListeners();
  }

  Future<void> openLocationSettings() async {
    final problem = _locationProblem;
    if (problem != null) await LocationService.openSettings(problem);
  }

  /// While Online, check in every minute with the position, react at once when location
  /// is switched off or on, and look for new offers every 5 seconds (30s in debug so
  /// the USB/ADB connection is not hammered during development).
  void _setOnline(bool online) {
    _isOnline = online;
    _heartbeat?.cancel();
    _offerPoll?.cancel();
    _locationWatch?.cancel();
    if (!online) {
      _offers = [];
      _locationProblem = null;
      return;
    }
    // In debug mode use a slower poll so the USB/ADB link isn't saturated.
    const pollInterval = kDebugMode
        ? Duration(seconds: 30)
        : Duration(seconds: 5);

    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) => _checkIn());
    _offerPoll = Timer.periodic(pollInterval, (_) => loadOffers());
    _locationWatch = LocationService.enabledChanges().listen((enabled) {
      if (!enabled) {
        // Tell the server straight away so no new offer is sent (RID-AVAIL-006)
        _locationProblem = LocationProblem.serviceOff;
        _offers = [];
        notifyListeners();
        CourierService.heartbeat().catchError((_) {});
      } else {
        _checkIn();
      }
    }, onError: (_) {});
  }

  Future<void> _checkIn() async {
    final reading = await LocationService.current();
    if (_isOnline != true) return;
    if (_locationProblem != reading.problem) {
      _locationProblem = reading.problem;
      notifyListeners();
    }
    await CourierService.heartbeat(position: reading.position).catchError((_) {});
    // New assignments and cancellations from logistics show up without a manual refresh
    unawaited(loadNotifications());
  }

  /// Logging out ends the shift, so an Online rider is marked Offline first
  /// (RID-AVAIL-004). Best effort: the phone may be offline or the server slow,
  /// and neither may keep the rider signed in.
  Future<void> goOffline() async {
    if (_isOnline != true) return;
    try {
      await CourierService.setOnlineStatus(false)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
    _isOnline = false;
  }

  /// Stops the timers and forgets what was shown (on logout), so the next rider on
  /// this phone never sees the previous rider's jobs. Deliveries saved offline stay
  /// on the phone until they are sent.
  void stop() {
    _heartbeat?.cancel();
    _offerPoll?.cancel();
    _locationWatch?.cancel();
    _isOnline = null;
    _locationProblem = null;
    _offers = [];
    _active = [];
    _recent = [];
    _dashboard = null;
    _profile = null;
    _earnings = null;
    _cod = null;
    _notifications = [];
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _offerPoll?.cancel();
    _locationWatch?.cancel();
    _connectionWatch?.cancel();
    super.dispose();
  }

  // ── Offers ────────────────────────────────────────────────────────────────
  Future<void> loadOffers() async {
    try {
      _offers = await CourierService.offers();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> acceptOffer(JobOffer offer) => _run(() async {
        await CourierService.acceptOffer(offer.id);
        _offers.removeWhere((o) => o.id == offer.id);
        await loadJobs();
      });

  Future<bool> declineOffer(JobOffer offer) => _run(() async {
        await CourierService.declineOffer(offer.id);
        _offers.removeWhere((o) => o.id == offer.id);
      });

  // ── Jobs ──────────────────────────────────────────────────────────────────
  Future<void> loadJobs() async {
    _loadingJobs = true; notifyListeners();
    try {
      final r = await CourierService.jobs();
      _active = r.active;
      _recent = r.recent;
    } on ApiError catch (e) { _error = e.message; }
    catch (_) { _error = 'Failed to load jobs.'; }
    _loadingJobs = false; notifyListeners();
  }

  Future<RiderJob?> loadJob(int id) async {
    try { return await CourierService.job(id); }
    on ApiError catch (e) { _error = e.message; notifyListeners(); return null; }
    catch (_) { _error = 'Connection error. Check your internet and try again.'; notifyListeners(); return null; }
  }

  Future<RiderJob?> confirmPickup(int id, String trackingNumber) =>
      _runJob(() => CourierService.confirmPickup(id, trackingNumber.trim()));

  /// A waybill scanned from the Scan tab: confirms the pickup of the job with that
  /// tracking number. Scanning a parcel that is already picked up gets the server's
  /// "already picked up" answer (RID-PICK-002, RID-PICK-005). Returns the picked-up job, or null with [error] set.
  Future<RiderJob?> pickupByScan(String code) async {
    final tracking = code.trim().toUpperCase();
    RiderJob? find() {
      for (final j in [..._active, ..._recent]) {
        if (j.isPickup && j.trackingNumber.toUpperCase() == tracking) return j;
      }
      return null;
    }

    var job = find();
    if (job == null) {
      await loadJobs();
      job = find();
    }
    if (job == null) {
      _error = 'None of your pickup jobs has tracking number $tracking.';
      notifyListeners();
      return null;
    }
    return confirmPickup(job.id, tracking);
  }

  Future<RiderJob?> startDelivery(int id) => _runJob(() => CourierService.startDelivery(id));

  /// Marks the job Delivered with the place it happened (RID-DLV-011). With no internet the
  /// delivery is saved on the phone and sent later (RID-DLV-009); then null is returned and
  /// [pendingFor] has it.
  Future<RiderJob?> deliver(RiderJob job, {required File photo, required String otp, String? codAmount}) async {
    _error = null;
    final position = (await LocationService.current()
            .timeout(const Duration(seconds: 8), onTimeout: () => const LocationReading.unavailable(LocationProblem.serviceOff)))
        .position;
    try {
      final done = await CourierService.deliver(job.id, photo: photo, otp: otp, codAmount: codAmount, position: position);
      await _removePending(job.id);
      await loadJobs();
      notifyListeners();
      return done;
    } on ApiError catch (e) {
      _error = e.message;
    } catch (_) {
      await _keepPending(PendingDelivery(
        jobId: job.id, trackingNumber: job.trackingNumber, otp: otp, codAmount: codAmount,
        photoPath: await PendingDeliveryStore.keepPhoto(photo, job.id).catchError((_) => photo.path),
        position: position, savedAt: DateTime.now(),
      ));
      _error = 'No internet connection. The delivery is saved on this phone and will be sent when you are back online.';
    }
    notifyListeners();
    return null;
  }

  /// Sends the deliveries saved while offline. Stops at the first connection error.
  Future<void> syncPending() async {
    if (_syncing || _pending.every((p) => p.error != null)) return;
    _syncing = true; notifyListeners();
    var changed = false;
    for (final p in List.of(_pending)) {
      if (p.error != null) continue;
      if (!File(p.photoPath).existsSync()) {
        await _markPending(p.jobId, 'The proof-of-delivery photo is no longer on this phone. Take it again.');
        changed = true;
        continue;
      }
      try {
        await CourierService.deliver(p.jobId,
            photo: File(p.photoPath), otp: p.otp, codAmount: p.codAmount, position: p.position);
        await _removePending(p.jobId);
        changed = true;
      } on ApiError catch (e) {
        // Already recorded (the first try reached the server but the answer was lost)?
        final job = await CourierService.job(p.jobId).then<RiderJob?>((j) => j, onError: (_) => null);
        if (job?.shipmentStatus == 'delivered') {
          await _removePending(p.jobId);
        } else {
          await _markPending(p.jobId, e.message);
        }
        changed = true;
      } catch (_) {
        break; // still offline
      }
    }
    _syncing = false;
    if (changed) await loadJobs();
    notifyListeners();
  }

  Future<void> _keepPending(PendingDelivery delivery) async {
    _pending = [..._pending.where((p) => p.jobId != delivery.jobId), delivery];
    await PendingDeliveryStore.save(_pending);
  }

  /// The saved delivery cannot be sent as it is: keep it, with the reason, for the rider to correct.
  Future<void> _markPending(int jobId, String reason) async {
    _pending = [for (final x in _pending) x.jobId == jobId ? x.withError(reason) : x];
    await PendingDeliveryStore.save(_pending);
  }

  Future<void> _removePending(int jobId) async {
    final saved = pendingFor(jobId);
    if (saved == null) return;
    _pending = _pending.where((p) => p.jobId != jobId).toList();
    await PendingDeliveryStore.save(_pending);
    await PendingDeliveryStore.deletePhoto(saved.photoPath);
  }

  Future<RiderJob?> fail(int id, String reason) => _runJob(() => CourierService.fail(id, reason));

  /// Gives back a job the rider has not started (before pickup / before leaving the hub).
  /// Logistics sees the reason and gives the parcel to another rider.
  Future<bool> declineJob(int id, String reason) => _run(() async {
        await CourierService.declineJob(id, reason.trim());
        _active = _active.where((j) => j.id != id).toList();
        await loadJobs();
      });

  /// The last action was refused because the job changed on the server (HTTP 409),
  /// e.g. it was already picked up from another phone. The screen reloads the job.
  bool get lastErrorWasConflict => _lastErrorStatus == 409;

  // ── Earnings and COD ──────────────────────────────────────────────────────
  Future<void> loadEarnings({DateTime? from, DateTime? to}) async {
    _loadingEarnings = true; _error = null; notifyListeners();
    try {
      final results = await Future.wait([
        CourierService.earnings(from: from, to: to),
        CourierService.cod(),
      ]);
      _earnings = results[0];
      _cod = results[1];
    } on ApiError catch (e) { _error = e.message; }
    catch (_) { _error = 'Failed to load earnings.'; }
    _loadingEarnings = false; notifyListeners();
  }

  Future<bool> remit(double amount) => _run(() async {
        final r = await CourierService.remit(amount);
        _cod = (r['cod'] as Map).cast<String, dynamic>();
      });

  // ── In-app notifications ──────────────────────────────────────────────────
  /// What logistics and admin sent the rider (A23). A failure here must not
  /// hide the dashboard, so it has its own message.
  Future<void> loadNotifications() async {
    _loadingNotifications = true;
    _notificationError = null;
    notifyListeners();
    try {
      _notifications = await CourierService.notifications();
    } on ApiError catch (e) {
      _notificationError = e.message;
    } catch (_) {
      _notificationError = 'Could not load notifications.';
    }
    _loadingNotifications = false;
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    final unread = unreadNotifications;
    if (unread == 0) return;
    try {
      await CourierService.markNotificationsRead();
      _notifications = [for (final n in _notifications) n.isRead ? n : n.markedRead()];
      notifyListeners();
    } catch (_) {
      _notificationError = 'Could not mark notifications as read. Try again when you are online.';
      notifyListeners();
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    try { _profile = await CourierService.profile(); notifyListeners(); }
    catch (_) {}
  }

  Future<bool> updateVehicle({String? plateNumber, File? orCr}) => _run(() async {
        _profile = await CourierService.updateVehicle(plateNumber: plateNumber, orCr: orCr);
      });

  Future<bool> updateLicense({DateTime? expiry, File? document}) => _run(() async {
        _profile = await CourierService.updateLicense(expiry: expiry, document: document);
      });

  void clearError() { _error = null; notifyListeners(); }

  // ── Helpers ───────────────────────────────────────────────────────────────
  /// Runs an action and keeps the server's message (or a connection error) in [error].
  Future<bool> _run(Future<void> Function() action) async {
    _error = null;
    _lastErrorStatus = null;
    try {
      await action();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      _error = e.message;
      _lastErrorStatus = e.code;
    } catch (_) {
      _error = 'No internet connection. Nothing was sent — try again when you are back online.';
    }
    notifyListeners();
    return false;
  }

  Future<RiderJob?> _runJob(Future<RiderJob> Function() action) async {
    RiderJob? job;
    final ok = await _run(() async {
      job = await action();
      await loadJobs();
    });
    return ok ? job : null;
  }
}
