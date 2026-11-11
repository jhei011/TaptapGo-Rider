import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/rider_notification.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_empty_state.dart';
import '../../widgets/bh_offline_banner.dart';
import 'rider_job_widgets.dart' show formatTime;

/// What logistics and admin sent this rider (A23): a new job, a cancelled job,
/// an offer that expired. Tapping a job notification opens that job.
class RiderNotificationsScreen extends StatefulWidget {
  const RiderNotificationsScreen({super.key});

  @override
  State<RiderNotificationsScreen> createState() => _RiderNotificationsScreenState();
}

class _RiderNotificationsScreenState extends State<RiderNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CourierProvider>().loadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CourierProvider>();
    final items = cp.notifications;

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
        title: 'Notifications',
        actions: [
          if (cp.unreadNotifications > 0)
            IconButton(
              key: const Key('markAllRead'),
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: cp.markNotificationsRead,
            ),
        ],
      ),
      body: BhOfflineBanner(
        child: RefreshIndicator(
          onRefresh: cp.loadNotifications,
          color: kBrand600,
          child: cp.loadingNotifications && items.isEmpty
              ? const Center(child: CircularProgressIndicator(color: kBrand600))
              : items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 60),
                      BhEmptyState(
                        icon: Icons.notifications_none,
                        title: 'No notifications yet',
                        subtitle: cp.notificationError ??
                            'New jobs and changes from your logistics company will appear here.',
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(kSpace14),
                      itemCount: items.length + (cp.notificationError == null ? 0 : 1),
                      separatorBuilder: (_, __) => const SizedBox(height: kSpace10),
                      itemBuilder: (context, i) {
                        if (cp.notificationError != null && i == 0) {
                          return _errorCard(cp.notificationError!);
                        }
                        final item = items[i - (cp.notificationError == null ? 0 : 1)];
                        return _NotificationTile(notification: item);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) => Container(
        padding: const EdgeInsets.all(kSpace12),
        decoration: BoxDecoration(
          color: kStatusFailedBg,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: kStatusFailedFg.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: kStatusFailedFg),
          const SizedBox(width: kSpace8),
          Expanded(child: Text(message, style: kBodySm.copyWith(color: kStatusFailedFg))),
        ]),
      );
}

class _NotificationTile extends StatelessWidget {
  final RiderNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = _style(notification.kind);
    return Material(
      color: notification.isRead ? kSurfaceBase : kBrand50,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: notification.opensJob
            ? () => Navigator.pushNamed(context, '/courier/job',
                arguments: notification.assignmentId)
            : null,
        child: Container(
          padding: const EdgeInsets.all(kSpace14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(
                color: notification.isRead ? kBorderDefault : kBrand400),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(kRadiusMd)),
              child: Icon(icon, size: 19, color: fg),
            ),
            const SizedBox(width: kSpace10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  notification.message.isEmpty
                      ? 'Notification'
                      : notification.message,
                  style: kBodyMd.copyWith(
                    color: kTextPrimary,
                    fontWeight:
                        notification.isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  if (!notification.isRead) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          const BoxDecoration(color: kBrand600, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('New', style: kLabelSm.copyWith(color: kBrand700)),
                    const SizedBox(width: kSpace8),
                  ],
                  Text(formatTime(notification.createdAt?.toIso8601String()),
                      style: kLabelSm.copyWith(color: kTextMuted)),
                  if (notification.opensJob) ...[
                    const Spacer(),
                    Text('Open job',
                        style: kLabelSm.copyWith(color: kBrand700)),
                    const Icon(Icons.chevron_right, size: 15, color: kBrand700),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  (IconData, Color, Color) _style(String kind) => switch (kind) {
        'offered' => (Icons.local_shipping_outlined, kBrand700, kBrand50),
        'cancelled' => (
            Icons.cancel_outlined,
            kStatusFailedFg,
            kStatusFailedBg
          ),
        'expired' => (Icons.timer_off_outlined, kStatusPendingFg, kStatusPendingBg),
        _ => (Icons.notifications_none, kBrand700, kBrand50),
      };
}
