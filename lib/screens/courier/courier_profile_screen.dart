import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/services/theme_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_offline_banner.dart';
import '../../widgets/field_card.dart';
import 'rider_profile_widgets.dart';

class CourierProfileScreen extends StatefulWidget {
  const CourierProfileScreen({super.key});
  @override
  State<CourierProfileScreen> createState() => _CourierProfileState();
}

class _CourierProfileState extends State<CourierProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourierProvider>().loadProfile();
      context.read<CourierProvider>().loadEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cp = context.watch<CourierProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final p = user.profile;

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: const BhAppBar(title: 'My Profile', showBack: false),
      body: BhOfflineBanner(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpace16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar / name / status card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(kSpace20),
                decoration: BoxDecoration(
                  color: kBrand800,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x220E2A38),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Column(children: [
                  // Avatar circle
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2),
                    ),
                    child: Center(
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace12),

                  // Full name
                  Text(
                    p != null
                        ? '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim()
                        : user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(user.email,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: kSpace12),

                  // Role + account status pills
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _whitePill(Icons.two_wheeler, 'Rider'),
                    const SizedBox(width: kSpace8),
                    _accountStatusPill(user.status),
                  ]),
                ]),
              ),
              const SizedBox(height: kSpace14),

              // ── Earnings summary ─────────────────────────────────────────
              if (cp.earnings != null)
                _EarningsSummaryCard(earnings: cp.earnings!)
              else
                const _EarningsSummaryCard(earnings: {}),
              const SizedBox(height: kSpace12),

              // ── Theme selector ───────────────────────────────────────────
              const _ThemeSelector(),
              const SizedBox(height: kSpace12),

              // ── Personal information ─────────────────────────────────────
              FieldCard(
                title: 'Personal Information',
                titleIcon: Icons.badge_outlined,
                children: p != null
                    ? [
                        _row2(
                          _field('First Name', p.firstName ?? '—'),
                          _field('Last Name', p.lastName ?? '—'),
                        ),
                        const SizedBox(height: kSpace12),
                        _row2(
                          _field('Middle Initial', p.middleInitial ?? '—'),
                          _field('Sex', p.sex ?? '—'),
                        ),
                        const SizedBox(height: kSpace12),
                        _row2(
                          _field('Birthday', p.birthday ?? '—'),
                          _field('Age', p.age?.toString() ?? '—'),
                        ),
                        const SizedBox(height: kSpace12),
                        _row2(
                          _field('Contact No.', p.contactNo ?? '—'),
                          _field('Email', user.email),
                        ),
                      ]
                    : [_missing()],
              ),
              const SizedBox(height: kSpace12),

              // ── Address ──────────────────────────────────────────────────
              FieldCard(
                title: 'Address',
                titleIcon: Icons.location_on_outlined,
                children: p != null
                    ? [
                        _row2(
                          _field('Province', p.province ?? '—'),
                          _field('Municipality', p.municipality ?? '—'),
                        ),
                        const SizedBox(height: kSpace12),
                        _row2(
                          _field('Barangay', p.barangay ?? '—'),
                          _field('Street', p.street ?? '—'),
                        ),
                        if (p.houseNo != null && p.houseNo!.isNotEmpty) ...[
                          const SizedBox(height: kSpace12),
                          _field('House / Unit No.', p.houseNo!),
                        ],
                      ]
                    : [_missing()],
              ),
              const SizedBox(height: kSpace12),

              // ── Rider, vehicle and documents ──────────────────────────────
              RiderVehicleSection(cp: cp),
              const SizedBox(height: kSpace20),

              // ── Logout ────────────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _logout(context, auth),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kActionDestructive,
                  side: BorderSide(
                      color: kActionDestructive.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd)),
                ),
              ),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _whitePill(IconData icon, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: kSpace12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(kRadiusFull),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _accountStatusPill(String status) {
    final (:bg, :fg) = _statusColors(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: kSpace12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(kRadiusFull),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(_statusLabel(status),
            style: TextStyle(
                fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // Local helper — mirrors C.statusColors without importing app_colors
  ({Color bg, Color fg}) _statusColors(String status) => switch (status) {
        'approved' => (bg: kStatusDeliveredBg, fg: kStatusDeliveredFg),
        'pending' => (bg: kStatusPendingBg, fg: kStatusPendingFg),
        'suspended' => (bg: kStatusFailedBg, fg: kStatusFailedFg),
        'inactive' => (bg: kStatusCancelledBg, fg: kStatusCancelledFg),
        _ => (bg: kStatusCancelledBg, fg: kStatusCancelledFg),
      };

  String _statusLabel(String s) => switch (s) {
        'approved' => 'Approved',
        'pending' => 'Pending Approval',
        'suspended' => 'Suspended',
        'inactive' => 'Inactive',
        _ => s,
      };

  Widget _row2(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: kSpace12),
          Expanded(child: b)
        ],
      );

  Widget _field(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kLabelSm.copyWith(color: kTextMuted)),
          const SizedBox(height: 3),
          Text(value, style: kLabelMd.copyWith(color: kTextPrimary)),
        ],
      );

  Widget _missing() =>
      Text('—', style: kBodySm.copyWith(color: kTextMuted));

  Future<void> _logout(BuildContext ctx, AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log Out',
                  style: TextStyle(color: kActionDestructive))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      ctx.read<CourierProvider>().stop();
      await auth.logout();
      if (ctx.mounted) {
        Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false);
      }
    }
  }
}

// ── Theme selector ────────────────────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final ts = context.watch<ThemeService>();
    final current = ts.mode;

    const chips = [
      (AppThemeMode.system, 'System', Icons.brightness_auto_outlined),
      (AppThemeMode.light, 'Light', Icons.light_mode_outlined),
      (AppThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    ];

    return FieldCard(
      title: 'Appearance',
      titleIcon: Icons.palette_outlined,
      children: [
        Row(
          children: chips.map((chip) {
            final (mode, label, icon) = chip;
            final isSelected = current == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: kSpace6),
                child: GestureDetector(
                  onTap: () => context.read<ThemeService>().setMode(mode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: kSpace8, horizontal: kSpace6),
                    decoration: BoxDecoration(
                      color: isSelected ? kBrand500 : kSurfaceBase,
                      borderRadius: BorderRadius.circular(kRadiusMd),
                      border: Border.all(
                        color: isSelected ? kBrand500 : kBorderDefault,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: isSelected ? Colors.white : kTextSecondary),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: kLabelSm.copyWith(
                            color: isSelected ? Colors.white : kTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Earnings summary card ─────────────────────────────────────────────────────
class _EarningsSummaryCard extends StatelessWidget {
  final Map<String, dynamic> earnings;
  const _EarningsSummaryCard({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final total = (earnings['total_earnings'] as num?)?.toDouble() ?? 0.0;
    final today = (earnings['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final week = (earnings['week_earnings'] as num?)?.toDouble() ?? 0.0;
    final month = (earnings['month_earnings'] as num?)?.toDouble() ?? 0.0;
    final delivered = earnings['total_delivered'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorderDefault),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 18, color: kBrand700),
            const SizedBox(width: kSpace8),
            Text('Earnings & Statistics',
                style: kHeadingSm.copyWith(color: kTextPrimary)),
          ]),
          const SizedBox(height: kSpace14),

          // Total earnings highlight
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: kSpace14, vertical: 10),
            decoration: BoxDecoration(
              color: kBrand800,
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Earnings',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                Text('₱${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: kSpace12),

          // Period breakdown
          Row(children: [
            Expanded(
                child: _periodTile('Today', '₱${today.toStringAsFixed(2)}')),
            const SizedBox(width: kSpace10),
            Expanded(
                child: _periodTile(
                    'This Week', '₱${week.toStringAsFixed(2)}')),
            const SizedBox(width: kSpace10),
            Expanded(
                child: _periodTile(
                    'This Month', '₱${month.toStringAsFixed(2)}')),
          ]),
          const SizedBox(height: kSpace10),

          // Delivered count
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: kSpace12, vertical: kSpace8),
            decoration: BoxDecoration(
              color: kBrand50,
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: kBrand700),
                  const SizedBox(width: kSpace6),
                  Text('Total Deliveries Completed',
                      style: kBodySm.copyWith(color: kBrand700)),
                ]),
                Text('$delivered',
                    style: kHeadingMd.copyWith(color: kBrand700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodTile(String label, String amount) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: kSpace8),
        decoration: BoxDecoration(
          color: kBrand50,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(color: kBorderDefault),
        ),
        child: Column(children: [
          Text(label, style: kLabelSm.copyWith(color: kTextSecondary)),
          const SizedBox(height: 4),
          Text(amount, style: kHeadingSm.copyWith(color: kBrand700)),
        ]),
      );
}
