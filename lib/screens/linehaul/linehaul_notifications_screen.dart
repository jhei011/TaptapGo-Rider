import 'package:flutter/material.dart';
import '../../core/services/api.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_empty_state.dart';
import '../../widgets/reveal.dart';
import '../courier/rider_job_widgets.dart' show formatTime;
import 'linehaul_trips_screen.dart';

/// One in-app notification for a linehaul courier, from GET /api/notifications.
/// The server sends these as LinehaulTripUpdate: a new trip, a cancelled one,
/// or a trip that was completed (every parcel received at the destination hub).
class LinehaulNotification {
  final String id;
  final String message;
  final String kind; // assigned | cancelled | completed | …
  final int? tripId;
  final DateTime? createdAt;
  final bool read;

  const LinehaulNotification({
    required this.id,
    required this.message,
    this.kind = '',
    this.tripId,
    this.createdAt,
    this.read = false,
  });

  LinehaulNotification markedRead() =>
      LinehaulNotification(id: id, message: message, kind: kind, tripId: tripId, createdAt: createdAt, read: true);

  factory LinehaulNotification.fromJson(Map<String, dynamic> j) {
    final payload = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LinehaulNotification(
      id: j['id'].toString(),
      message: (payload['message'] as String?)?.trim() ?? '',
      kind: payload['kind'] as String? ?? '',
      tripId: (payload['trip_id'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      read: j['read'] == true || j['read_at'] != null,
    );
  }
}

/// Loads the courier's notifications. Shared by the bell (unread count) and the list.
class LinehaulNotifications extends ChangeNotifier {
  List<LinehaulNotification> items = const [];
  bool loading = false;
  String? error;

  int get unread => items.where((n) => !n.read).length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final d = await Api.get('/notifications') as List;
      items = [for (final n in d) LinehaulNotification.fromJson((n as Map).cast<String, dynamic>())];
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load notifications. Pull down to try again.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    if (unread == 0) return;
    try {
      await Api.post('/notifications/read');
      items = [for (final n in items) n.read ? n : n.markedRead()];
      error = null;
    } catch (_) {
      error = 'Could not mark notifications as read. Try again when you are online.';
    }
    notifyListeners();
  }
}

/// The bell on the linehaul Home screen, with the unread count.
class LinehaulNotificationBell extends StatelessWidget {
  final LinehaulNotifications store;
  const LinehaulNotificationBell({super.key, required this.store});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final unread = store.unread;
          return IconButton(
            key: const Key('linehaulNotificationBell'),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => LinehaulNotificationsScreen(store: store))),
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_none),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(color: kActionDestructive, borderRadius: BorderRadius.circular(kRadiusFull)),
                    child: Text(unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          );
        },
      );
}

/// New trips, cancelled trips and completed trips. Tapping one opens that trip.
class LinehaulNotificationsScreen extends StatefulWidget {
  final LinehaulNotifications store;
  const LinehaulNotificationsScreen({super.key, required this.store});

  @override
  State<LinehaulNotificationsScreen> createState() => _LinehaulNotificationsScreenState();
}

class _LinehaulNotificationsScreenState extends State<LinehaulNotificationsScreen> {
  LinehaulNotifications get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) store.load();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.items;
          return Scaffold(
            backgroundColor: kSurfaceRaised,
            appBar: BhAppBar(
              title: 'Notifications',
              actions: [
                if (store.unread > 0)
                  IconButton(
                    key: const Key('linehaulMarkAllRead'),
                    icon: const Icon(Icons.done_all),
                    tooltip: 'Mark all as read',
                    onPressed: store.markAllRead,
                  ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: store.load,
              color: kBrand600,
              child: store.loading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: kBrand600))
                  : items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 60),
                          BhEmptyState(
                            icon: Icons.notifications_none,
                            title: 'No notifications yet',
                            subtitle: store.error ?? 'New trips and changes from your logistics company will appear here.',
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(kSpace14),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: kSpace10),
                          itemBuilder: (context, i) => Reveal(index: i, child: _tile(items[i])),
                        ),
            ),
          );
        },
      );

  Widget _tile(LinehaulNotification n) {
    final (icon, fg, bg) = switch (n.kind) {
      'assigned' => (Icons.local_shipping_outlined, kBrand700, kBrand50),
      'cancelled' => (Icons.cancel_outlined, kStatusFailedFg, kStatusFailedBg),
      'completed' => (Icons.check_circle_outline, kBrand700, kBrand50),
      'nbi_verified' => (Icons.verified_user_outlined, kBrand700, kBrand50),
      _ => (Icons.notifications_none, kBrand700, kBrand50),
    };
    return Material(
      color: n.read ? kSurfaceBase : kBrand50,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: n.tripId == null
            ? null
            : () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => LinehaulTripDetailScreen(tripId: n.tripId!))),
        child: Container(
          padding: const EdgeInsets.all(kSpace14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: n.read ? kBorderDefault : kBrand400),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kRadiusMd)),
              child: Icon(icon, size: 19, color: fg),
            ),
            const SizedBox(width: kSpace10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.message.isEmpty ? 'Notification' : n.message,
                    style: kBodyMd.copyWith(
                        color: kTextPrimary, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  if (!n.read) ...[
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: kBrand600, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('New', style: kLabelSm.copyWith(color: kBrand700)),
                    const SizedBox(width: kSpace8),
                  ],
                  Text(formatTime(n.createdAt?.toIso8601String()), style: kLabelSm.copyWith(color: kTextMuted)),
                  if (n.tripId != null) ...[
                    const Spacer(),
                    Text('Open trip', style: kLabelSm.copyWith(color: kBrand700)),
                    Icon(Icons.chevron_right, size: 15, color: kBrand700),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
