import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/seller_provider.dart';
import '../../widgets/field_card.dart';
import 'seller_shell.dart';
import 'seller_widgets.dart';
class SellerProfileScreen extends StatefulWidget {
  final SellerShellState? shell;
  const SellerProfileScreen({super.key, this.shell});
  @override State<SellerProfileScreen> createState() => _SellerProfileState();
}

class _SellerProfileState extends State<SellerProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SellerProvider>().loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final p = user.profile;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: SellerAppBar(
        title: 'My Profile',
        onMenuTap: () {
          widget.shell?.openDrawer();
          if (widget.shell == null) Scaffold.of(context).openDrawer();
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 20),
            onPressed: () =>
                Navigator.pushNamed(context, '/seller/profile/edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // ── Gradient header banner ─────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: C.heroGrad),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Column(children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(user.initials,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(user.email,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 10),
              // Seller badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.store_outlined,
                      size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Seller',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Business Info ────────────────────────────────────────
              FieldCard(
                title: 'Business Info',
                titleIcon: Icons.store_outlined,
                subtitle: 'How buyers know your store',
                children: p != null
                    ? [
                        InfoRow(
                            label: 'Business Name',
                            value: p.businessName ?? '—'),
                        InfoRow(
                            label: 'Line of Business',
                            value: p.lineOfBusiness ?? '—'),
                      ]
                    : [const Text('—',
                        style: TextStyle(color: C.textMuted))],
              ),
              const SizedBox(height: 12),

              // ── Personal Information ─────────────────────────────────
              FieldCard(
                title: 'Personal Information',
                titleIcon: Icons.badge_outlined,
                children: p != null
                    ? [
                        InfoRow(
                            label: 'First Name',
                            value: p.firstName ?? '—'),
                        InfoRow(
                            label: 'Last Name',
                            value: p.lastName ?? '—'),
                        InfoRow(
                            label: 'Middle Initial',
                            value: p.middleInitial ?? '—'),
                        InfoRow(label: 'Sex', value: p.sex ?? '—'),
                        InfoRow(
                            label: 'Birthday',
                            value: p.birthday ?? '—'),
                        InfoRow(
                            label: 'Age',
                            value: p.age?.toString() ?? '—'),
                        InfoRow(
                            label: 'Contact No.',
                            value: p.contactNo ?? '—'),
                      ]
                    : [const Text('—',
                        style: TextStyle(color: C.textMuted))],
              ),
              const SizedBox(height: 12),

              // ── Address ──────────────────────────────────────────────
              FieldCard(
                title: 'Address Information',
                titleIcon: Icons.location_on_outlined,
                children: p != null
                    ? [
                        InfoRow(
                            label: 'Province',
                            value: p.province ?? '—'),
                        InfoRow(
                            label: 'Municipality',
                            value: p.municipality ?? '—'),
                        InfoRow(
                            label: 'Barangay',
                            value: p.barangay ?? '—'),
                        InfoRow(
                            label: 'Street',
                            value: p.street ?? '—'),
                        InfoRow(
                            label: 'House No.',
                            value: p.houseNo ?? '—'),
                      ]
                    : [const Text('—',
                        style: TextStyle(color: C.textMuted))],
              ),
              const SizedBox(height: 12),

              // ── Account Status ───────────────────────────────────────
              FieldCard(
                title: 'Account Status',
                titleIcon: Icons.shield_outlined,
                children: [
                  InfoRow(label: 'Email', value: user.email),
                  const InfoRow(label: 'Role', value: 'Seller'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status',
                            style: TextStyle(
                                fontSize: 13, color: C.textSecondary)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: user.status == 'approved'
                                ? C.deliveredBg
                                : C.warnBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.status[0].toUpperCase() +
                                user.status.substring(1),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: user.status == 'approved'
                                    ? C.delivered
                                    : C.warn),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Logout button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context, auth),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.danger,
                    side: BorderSide(
                        color: C.danger.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _logout(BuildContext ctx, AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log Out',
                  style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await auth.logout();
      if (ctx.mounted) {
        Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false);
      }
    }
  }
}
