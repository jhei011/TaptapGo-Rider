import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/api.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../courier/rider_job_widgets.dart' show cardDecoration;

/// Home screen of a courier: a linehaul driver who moves parcels between hubs
/// (Account Creation, Courier role: TC-COU-032). Couriers get no rider job offers or rider screens.
class LinehaulHomeScreen extends StatefulWidget {
  const LinehaulHomeScreen({super.key});

  @override
  State<LinehaulHomeScreen> createState() => _LinehaulHomeScreenState();
}

class _LinehaulHomeScreenState extends State<LinehaulHomeScreen> {
  Map<String, dynamic>? _home;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.get('/linehaul/home') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() { _home = d; _loading = false; });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'No internet connection. Pull down to try again.'; _loading = false; });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: kActionDestructive)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    // Clear the history so Back cannot return to account screens (TC-COU-052)
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
        title: 'Courier',
        showBack: false,
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Log Out', onPressed: _logout)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: kBrand600,
        child: ListView(padding: const EdgeInsets.all(kSpace16), children: [
          if (_loading && home == null)
            const Padding(padding: EdgeInsets.all(kSpace24), child: Center(child: CircularProgressIndicator(color: kBrand600)))
          else if (home == null)
            Padding(
              padding: const EdgeInsets.all(kSpace24),
              child: Column(children: [
                Text(_error ?? 'Could not load your details.', textAlign: TextAlign.center, style: kBodyMd.copyWith(color: kTextSecondary)),
                const SizedBox(height: kSpace12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ]),
            )
          else ...[
            _banner(home),
            const SizedBox(height: kSpace12),
            _details(home),
            const SizedBox(height: kSpace12),
            Container(
              padding: const EdgeInsets.all(kSpace16),
              decoration: BoxDecoration(color: kBrand50, borderRadius: BorderRadius.circular(kRadiusLg)),
              child: Text('Hub-to-hub trips assigned by your logistics company will appear here.',
                  style: kBodyMd.copyWith(color: kBrand700)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _banner(Map<String, dynamic> home) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kSpace20),
        decoration: BoxDecoration(color: kBrand800, borderRadius: BorderRadius.circular(kRadiusLg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          const SizedBox(height: 2),
          Text(home['name'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(home['logistics_company'] as String? ?? '',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          const SizedBox(height: kSpace12),
          Container(
            key: const Key('dutyStatus'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Text(home['duty_status'] as String? ?? 'Off Duty',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _details(Map<String, dynamic> home) {
    final hub = home['home_hub'] as Map?;
    final kg = (home['load_capacity_kg'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row(Icons.warehouse_outlined, 'Home hub', hub == null ? '—' : '${hub['code']} · ${hub['name']}'),
        _row(Icons.local_shipping_outlined, 'Vehicle', home['vehicle_type'] as String? ?? '—'),
        _row(Icons.pin_outlined, 'Plate number', home['plate_number'] as String? ?? '—'),
        _row(Icons.scale_outlined, 'Load capacity', '${_thousands(kg)} kg'),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: kSpace10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: kTextMuted),
          const SizedBox(width: kSpace8),
          SizedBox(width: 110, child: Text(label, style: kBodySm.copyWith(color: kTextMuted))),
          Expanded(child: Text(value, style: kBodyMd.copyWith(color: kTextPrimary))),
        ]),
      );

  static String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
