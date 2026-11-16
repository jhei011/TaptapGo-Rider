import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/api.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../courier/rider_job_widgets.dart' show cardDecoration;
import 'linehaul_trips_screen.dart';
import '../../widgets/teal_pattern.dart';
import '../../core/services/rider_idle_policy.dart';
import '../../widgets/confirm_logout.dart';
import '../../widgets/panel_label.dart';
import '../../widgets/reveal.dart';
import '../../widgets/change_password_sheet.dart';

/// Home tab of the Linehaul Courier panel: a linehaul driver who moves parcels between hubs
/// (Account Creation, Courier role: TC-COU-032). Couriers get no rider job offers or rider screens.
/// Shows the duty status, the current trips and the courier's truck.
class LinehaulHomeScreen extends StatefulWidget {
  /// Opens the Trips tab (set by LinehaulShell).
  final VoidCallback? onOpenTrips;
  const LinehaulHomeScreen({super.key, this.onOpenTrips});

  @override
  State<LinehaulHomeScreen> createState() => LinehaulHomeScreenState();
}

class LinehaulHomeScreenState extends State<LinehaulHomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _home;
  List<Map<String, dynamic>> _trips = const [];
  String? _error;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Duty status and current trips change when hub staff load the truck
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(kTripRefresh, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    _loadTrips();
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

  /// Current trips; the home screen still works if they cannot be loaded.
  Future<void> _loadTrips() async {
    try {
      final d = await Api.get('/linehaul/trips') as List;
      if (mounted) setState(() => _trips = d.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _trips = const []);
    }
  }

  Future<void> _openTrip(Map<String, dynamic> trip) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LinehaulTripDetailScreen(tripId: trip['id'] as int)));
    if (mounted) _load();
  }

  Future<void> _logout() async {
    // An active trip gets a warning (the server is asked; no answer counts as active)
    final ok = await confirmRiderLogout(context,
        unsentDeliveries: 0, checkWork: linehaulWorkCheck, message: "You'll need to sign in again to see your trips.");
    if (!ok || !mounted) return;
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
        // Logo row only, like the rider's Home (the card below says which panel this is)
        title: BhAppBar.kWordmark,
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
            Reveal(child: _banner(home)),
            const SizedBox(height: kSpace12),
            Reveal(index: 1, child: _tripsSection()),
            const SizedBox(height: kSpace12),
            Reveal(index: 2, child: _details(home)),
            const SizedBox(height: kSpace16),
            // Couriers have no Profile tab: their account action lives here
            const Reveal(index: 3, child: ChangePasswordButton()),
          ],
        ]),
      ),
    );
  }

  Widget _banner(Map<String, dynamic> home) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kSpace20),
        decoration: TealDecoration(BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.circular(kRadiusLg))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          const SizedBox(height: 2),
          Text(home['name'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          // Which panel this is (riders have the Rider Panel)
          const PanelLabel(icon: Icons.local_shipping_rounded, text: 'Linehaul Courier Panel'),
          const SizedBox(height: 2),
          // The courier's logistics company; "TaptapGo" when none is on record (same as the Rider Panel)
          Text(
              (home['logistics_company'] as String?)?.trim().isNotEmpty == true
                  ? (home['logistics_company'] as String).trim()
                  : 'TaptapGo',
              key: const Key('linehaulCompany'),
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

  Widget _tripsSection() {
    if (_trips.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: BoxDecoration(color: kBrand50, borderRadius: BorderRadius.circular(kRadiusLg)),
        child: Text('Hub-to-hub trips assigned by your logistics company will appear here.',
            style: kBodyMd.copyWith(color: AppPalette.dark ? kTealOnDark : kBrand700)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Current trips', style: kHeadingSm)),
        if (widget.onOpenTrips != null)
          TextButton(onPressed: widget.onOpenTrips, child: const Text('See all')),
      ]),
      const SizedBox(height: kSpace4),
      for (final t in _trips.take(3)) ...[
        LinehaulTripCard(trip: t, onTap: () => _openTrip(t)),
        const SizedBox(height: kSpace8),
      ],
    ]);
  }

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
