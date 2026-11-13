import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_stat_tile.dart';
import '../../widgets/bh_offline_banner.dart';
import '../../widgets/bh_empty_state.dart';
import 'rider_job_widgets.dart';
import '../../widgets/teal_pattern.dart';
import '../../widgets/panel_label.dart';
import '../../widgets/reveal.dart';

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});
  @override
  State<CourierDashboardScreen> createState() => _CourierDashState();
}

class _CourierDashState extends State<CourierDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CourierProvider>().loadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cp = context.watch<CourierProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final db = cp.dashboard;

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
        title: BhAppBar.kWordmark,
        showBack: false,
        // Pull down on the page to refresh
        actions: [
          _NotificationBell(cp: cp),
        ],
      ),
      body: BhOfflineBanner(
        child: cp.loadingDash
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 3),
              )
            : RefreshIndicator(
                onRefresh: cp.loadDashboard,
                color: kBrand600,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(kSpace16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Welcome + Online/Offline banner ──────────────────
                      Reveal(child: _WelcomeBanner(user: user, cp: cp, db: db)),
                      const SizedBox(height: kSpace14),

                      // ── Messages such as "account suspended" ─────────────
                      if (cp.error != null) ...[
                        _ErrorBanner(message: cp.error!, onClose: cp.clearError),
                        const SizedBox(height: kSpace14),
                      ],

                      // ── Location needed to go / stay Online ──────────────
                      if (cp.locationProblem != null) ...[
                        LocationBanner(
                          problem: cp.locationProblem!,
                          online: cp.isOnline ?? false,
                          onOpenSettings: cp.openLocationSettings,
                        ),
                        const SizedBox(height: kSpace14),
                      ],

                      // ── Deliveries saved while offline ───────────────────
                      if (cp.pendingDeliveries.isNotEmpty) ...[
                        _PendingDeliveriesBanner(cp: cp),
                        const SizedBox(height: kSpace14),
                      ],

                      // ── Stats row ─────────────────────────────────────────
                      Reveal(index: 1, child: _StatsRow(db: db)),
                      const SizedBox(height: kSpace14),

                      // ── Earnings summary ─────────────────────────────────
                      if (db != null) Reveal(index: 2, child: _EarningsCard(db: db)),
                      if (db != null) const SizedBox(height: kSpace14),

                      // ── Job offers (60 seconds each) ─────────────────────
                      if (cp.offers.isNotEmpty) ...[
                        Text('Job Offers',
                            style: kHeadingSm.copyWith(color: kTextPrimary)),
                        const SizedBox(height: kSpace10),
                        ...cp.offers.map((o) => JobOfferCard(
                            key: ValueKey('offer-${o.id}'), offer: o, cp: cp)),
                        const SizedBox(height: kSpace4),
                      ],

                      // ── Active jobs ──────────────────────────────────────
                      Reveal(
                        index: 3,
                        child: Text('Active Jobs',
                            style: kHeadingSm.copyWith(color: kTextPrimary)),
                      ),
                      const SizedBox(height: kSpace10),

                      if (cp.activeJobs.isNotEmpty)
                        for (final (i, j) in cp.activeJobs.indexed)
                          Reveal(key: ValueKey('job-${j.id}'), index: 4 + i, child: RiderJobCard(job: j))
                      else
                        BhEmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No active jobs',
                          subtitle: (cp.isOnline ?? false)
                              ? 'New job offers will appear here'
                              : 'Go Online to receive job offers',
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Jobs assigned or cancelled by logistics/admin land here (A23).
class _NotificationBell extends StatelessWidget {
  final CourierProvider cp;
  const _NotificationBell({required this.cp});

  @override
  Widget build(BuildContext context) {
    final unread = cp.unreadNotifications;
    return IconButton(
      key: const Key('notificationBell'),
      tooltip: 'Notifications',
      onPressed: () => Navigator.pushNamed(context, '/courier/notifications'),
      icon: Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.notifications_none),
        if (unread > 0)
          Positioned(
            top: -2,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 15),
              decoration: BoxDecoration(
                color: kActionDestructive,
                borderRadius: BorderRadius.circular(kRadiusFull),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Welcome + Online/Offline Banner ──────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final dynamic user;
  final CourierProvider cp;
  final Map<String, dynamic>? db;

  const _WelcomeBanner({required this.user, required this.cp, required this.db});

  @override
  Widget build(BuildContext context) {
    final isOnline = cp.isOnline ?? false;
    final isToggling = cp.togglingOnline;
    final company =
        db?['logistics_company'] as String? ?? 'TaptapGo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace20),
      decoration: TealDecoration(BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2A38), Color(0xFF1F4F5C), Color(0xFF4A949C)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x300E2A38), blurRadius: 18, offset: Offset(0, 6))
        ],
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    // Which panel this is (the Linehaul Courier panel has its own)
                    const PanelLabel(icon: Icons.two_wheeler_rounded, text: 'Rider Panel'),
                    const SizedBox(height: 2),
                    Text(company,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: kSpace12),
              // Date pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kRadiusSm),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(_todayDate(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: kSpace16),

          // ── Online / Offline toggle ──────────────────────────────────
          GestureDetector(
            onTap: isToggling ? null : () => cp.toggleOnlineStatus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF2E7D4F).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isToggling)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                  else
                    _LiveDot(online: isOnline),
                  const SizedBox(width: kSpace8),
                  // Takes the room left beside the switch and wraps with large text / display
                  // size instead of overflowing past it
                  Expanded(
                    child: Text(
                      isToggling
                          ? 'Updating...'
                          : isOnline
                              ? 'Online — Ready to Deliver'
                              : 'Offline — Go Online to Accept Parcels',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: kSpace8),
                  _OnlineSwitch(isOnline: isOnline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _todayDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _OnlineSwitch extends StatelessWidget {
  final bool isOnline;
  const _OnlineSwitch({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 40,
      height: 22,
      decoration: BoxDecoration(
        color: isOnline
            ? const Color(0xFF4CAF50)
            : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, dynamic>? db;
  const _StatsRow({required this.db});

  @override
  Widget build(BuildContext context) {
    final totalDelivered = db?['total_delivered'] ?? 0;
    final activeCount = db?['active_jobs'] ?? 0;
    final todayCount = db?['today_delivered'] ?? 0;

    // All three tiles take the tallest one's height, even when a label wraps on a small phone
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: BhStatTile(
          value: '$totalDelivered',
          label: 'Total Delivered',
          icon: Icons.check_circle_outline,
          iconColor: kBrand600,
        ),
      ),
      const SizedBox(width: kSpace10),
      Expanded(
        child: BhStatTile(
          value: '$activeCount',
          label: 'Active Jobs',
          icon: Icons.inventory_2_outlined,
          iconColor: kBrand400,
        ),
      ),
      const SizedBox(width: kSpace10),
      Expanded(
        child: BhStatTile(
          value: '$todayCount',
          label: 'Delivered Today',
          icon: Icons.today_outlined,
          iconColor: const Color(0xFFF0A500),
        ),
      ),
    ]),
    );
  }
}

// ── Earnings Summary Card ─────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic> db;
  const _EarningsCard({required this.db});

  @override
  Widget build(BuildContext context) {
    final todayEarnings = (db['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final totalEarnings = (db['total_earnings'] as num?)?.toDouble() ?? 0.0;
    final codBalance = (db['cod_balance'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration(),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kBrand50,
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 22, color: kBrand700),
          ),
          const SizedBox(width: kSpace14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Earnings',
                  style: kBodySm.copyWith(color: kTextSecondary)),
              const SizedBox(height: 2),
              Text(peso(totalEarnings),
                  style: kDisplaySm.copyWith(color: kBrand700)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kStatusDeliveredBg,
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Today',
                    style: kLabelSm.copyWith(color: kStatusDeliveredFg)),
                Text(peso(todayEarnings),
                    style: kHeadingSm.copyWith(color: kStatusDeliveredFg)),
              ],
            ),
          ),
        ]),
        const Divider(height: kSpace20),
        Row(children: [
          const Icon(Icons.payments_outlined, size: 16, color: kBrand600),
          const SizedBox(width: kSpace8),
          Expanded(child: Text('COD to remit', style: kBodySm.copyWith(color: kTextSecondary))),
          Text(peso(codBalance), style: kHeadingSm.copyWith(color: kTextPrimary)),
        ]),
      ]),
    );
  }
}

// ── Error / notice banner ─────────────────────────────────────────────────────
/// Going Online was refused, or location was switched off while Online (RID-AVAIL-005, RID-AVAIL-006).
class LocationBanner extends StatelessWidget {
  final LocationProblem problem;
  final bool online;
  final VoidCallback onOpenSettings;
  const LocationBanner({super.key, required this.problem, required this.online, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('locationBanner'),
        padding: const EdgeInsets.all(kSpace12),
        decoration: BoxDecoration(
          color: kStatusFailedBg,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: kStatusFailedFg.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.location_off_outlined, color: kStatusFailedFg, size: 18),
            const SizedBox(width: kSpace8),
            Expanded(
              child: Text(
                online
                    ? 'Location is off. You will not get new job offers until you turn it back on.'
                    : "You can't go Online yet. ${LocationService.message(problem)}",
                style: kBodySm.copyWith(color: kStatusFailedFg),
              ),
            ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Open Settings'),
              onPressed: onOpenSettings,
              style: TextButton.styleFrom(foregroundColor: kStatusFailedFg),
            ),
          ),
        ]),
      );
}

class _PendingDeliveriesBanner extends StatelessWidget {
  final CourierProvider cp;
  const _PendingDeliveriesBanner({required this.cp});

  @override
  Widget build(BuildContext context) {
    final count = cp.pendingDeliveries.length;
    return Container(
      padding: const EdgeInsets.all(kSpace12),
      decoration: BoxDecoration(color: kStatusPendingBg, borderRadius: BorderRadius.circular(kRadiusMd)),
      child: Row(children: [
        Icon(Icons.cloud_off_outlined, size: 18, color: kStatusPendingFg),
        const SizedBox(width: kSpace8),
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'delivery is' : 'deliveries are'} saved on this phone and not sent yet: '
            '${cp.pendingDeliveries.map((p) => p.trackingNumber).join(', ')}.',
            style: kBodySm.copyWith(color: kStatusPendingFg),
          ),
        ),
        TextButton(
          onPressed: cp.syncing ? null : cp.syncPending,
          child: Text(cp.syncing ? 'Sending…' : 'Retry'),
        ),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace10),
        decoration: BoxDecoration(
          color: kStatusFailedBg,
          borderRadius: BorderRadius.circular(kRadiusMd),
          border: Border.all(color: kStatusFailedFg.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: kStatusFailedFg, size: 18),
          const SizedBox(width: kSpace8),
          Expanded(child: Text(message, style: kBodySm.copyWith(color: kStatusFailedFg))),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: kStatusFailedFg),
            tooltip: 'Dismiss',
            onPressed: onClose,
          ),
        ]),
      );
}

/// The Online/Offline dot. Going Online sends out a few soft pulses, then it glows steadily.
class _LiveDot extends StatefulWidget {
  final bool online;
  const _LiveDot({required this.online});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF69F0AE);
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.online) _start();
  }

  @override
  void didUpdateWidget(_LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.online && !old.online) _start();
    if (!widget.online) _pulse.value = 0;
  }

  void _start() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    // A few pulses only, so the screen settles
    _pulse.repeat(count: 3).whenComplete(() { if (mounted) _pulse.value = 0; });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 10,
        height: 10,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (widget.online && _pulse.value > 0)
              Container(
                width: 10 + 16 * _pulse.value,
                height: 10 + 16 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green.withValues(alpha: 0.45 * (1 - _pulse.value)),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: widget.online ? _green : Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                boxShadow: widget.online ? [BoxShadow(color: _green.withValues(alpha: 0.6), blurRadius: 6)] : null,
              ),
            ),
          ]),
        ),
      );
}
