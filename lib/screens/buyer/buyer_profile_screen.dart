import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/buyer_provider.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/field_card.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});
  @override State<BuyerProfileScreen> createState() => _BuyerProfileState();
}

class _BuyerProfileState extends State<BuyerProfileScreen> {
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BuyerProvider>().loadProfile()); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final p = user.profile;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: const TaptapNavBar(
        title: 'My Profile',
        showBack: false,
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header gradient banner — matches Laravel profile header
          Container(
            decoration: const BoxDecoration(gradient: C.heroGrad),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(user.initials,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 3),
              Text(user.email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Personal Information
              FieldCard(title: 'Personal Information', titleIcon: Icons.badge_outlined, children: [
                if (p != null) ...[
                  InfoRow(label: 'First Name', value: p.firstName ?? '—'),
                  InfoRow(label: 'Last Name', value: p.lastName ?? '—'),
                  InfoRow(label: 'Middle Initial', value: p.middleInitial ?? '—'),
                  InfoRow(label: 'Sex', value: p.sex ?? '—'),
                  InfoRow(label: 'Birthday', value: p.birthday ?? '—'),
                  InfoRow(label: 'Age', value: p.age?.toString() ?? '—'),
                  InfoRow(label: 'Contact No.', value: p.contactNo ?? '—'),
                ] else
                  const Center(child: Text('No profile data', style: TextStyle(color: C.textMuted, fontSize: 13))),
              ]),
              const SizedBox(height: 12),

              // Address
              FieldCard(title: 'Address', titleIcon: Icons.location_on_outlined, children: [
                if (p != null) ...[
                  InfoRow(label: 'Province', value: p.province ?? '—'),
                  InfoRow(label: 'Municipality', value: p.municipality ?? '—'),
                  InfoRow(label: 'Barangay', value: p.barangay ?? '—'),
                  InfoRow(label: 'Street', value: p.street ?? '—'),
                  InfoRow(label: 'House No.', value: p.houseNo ?? '—'),
                ] else
                  const Center(child: Text('—', style: TextStyle(color: C.textMuted))),
              ]),
              const SizedBox(height: 12),

              // Account Status
              FieldCard(title: 'Account Status', titleIcon: Icons.shield_outlined, children: [
                InfoRow(label: 'Email', value: user.email),
                const InfoRow(label: 'Role', value: 'Buyer'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Status', style: TextStyle(fontSize: 13, color: Color(0xFF8A9491))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: C.deliveredBg, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Approved',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.delivered)),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),

              // Log Out button only
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context, auth),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.danger, side: BorderSide(color: C.danger.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _logout(BuildContext ctx, AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: ctx, builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: C.danger))),
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
