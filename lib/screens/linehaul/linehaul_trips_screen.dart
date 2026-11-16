import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_empty_state.dart';
import '../../widgets/bh_primary_button.dart';
import '../../widgets/tap.dart';
import '../courier/rider_job_widgets.dart' show cardDecoration;
import '../../widgets/reveal.dart';

/// What Navigate searches for in the maps app: the hub's street address. A hub name such as
/// "Dvidhub Hub" is not a place on the map and made Google Maps suggest another town, so the
/// name is used only when a hub has no address.
String hubMapsQuery(Map hub) {
  final address = (hub['address'] as String?)?.trim() ?? '';
  if (address.isNotEmpty) return address;
  return [hub['name'], hub['municipality'], hub['province']]
      .whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
}

/// Linehaul courier panel: hub-to-hub trips. A trip is one truck run from an origin hub to the next hub
/// with the parcels hub staff loaded for this courier (GET /api/linehaul/trips).
///
///   Loading → (Start trip) → On the road → (Arrived) → Unloading → Completed when the hub receives every parcel.
class LinehaulTripsScreen extends StatefulWidget {
  /// `active` (loading, on the road, unloading) or `history` (completed).
  final String scope;
  const LinehaulTripsScreen({super.key, this.scope = 'active'});

  @override
  State<LinehaulTripsScreen> createState() => LinehaulTripsScreenState();
}

/// How often open trips are refreshed while the app is in front: hub staff keep adding
/// parcels while a truck loads, and the destination hub ticks them off while it unloads.
const kTripRefresh = Duration(seconds: 30);

class LinehaulTripsScreenState extends State<LinehaulTripsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _trips;
  String? _error;
  bool _loading = true;
  Timer? _poll;

  bool get _history => widget.scope == 'history';

  @override
  void initState() {
    super.initState();
    reload();
    if (!_history) {
      WidgetsBinding.instance.addObserver(this);
      _poll = Timer.periodic(kTripRefresh, (_) => reload(quiet: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload(quiet: true);
  }

  /// [quiet]: a background refresh keeps the list on screen and ignores errors.
  Future<void> reload({bool quiet = false}) async {
    if (!quiet) setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.get('/linehaul/trips', query: {'scope': widget.scope}) as List;
      if (!mounted) return;
      setState(() { _trips = d.cast<Map<String, dynamic>>(); _loading = false; });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'No internet connection. Pull down to try again.'; _loading = false; });
    }
  }

  Future<void> _open(Map<String, dynamic> trip) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LinehaulTripDetailScreen(tripId: trip['id'] as int)));
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final trips = _trips;
    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
          title: _history ? 'Trip History' : 'My Trips',
          subtitle: _history ? 'Trips your destination hubs completed' : 'Hub-to-hub runs assigned to you',
          showBack: false),
      body: RefreshIndicator(
        onRefresh: reload,
        color: kBrand600,
        child: _loading && trips == null
            ? const Center(child: CircularProgressIndicator(color: kBrand600))
            : trips == null
                ? ListView(children: [
                    const SizedBox(height: 80),
                    BhEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load your trips',
                      subtitle: _error,
                      action: OutlinedButton(onPressed: reload, child: const Text('Retry')),
                    ),
                  ])
                : trips.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        BhEmptyState(
                          icon: _history ? Icons.history : Icons.local_shipping_outlined,
                          title: _history ? 'No completed trips yet' : 'No trips right now',
                          subtitle: _history
                              ? 'Trips appear here once the destination hub receives every parcel.'
                              : 'When hub staff send parcels to the next hub with you, the trip appears here.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(kSpace16),
                        itemCount: trips.length,
                        separatorBuilder: (_, i) => const SizedBox(height: kSpace12),
                        itemBuilder: (_, i) => Reveal(
                          key: ValueKey('trip-${trips[i]['id']}'),
                          index: i,
                          child: LinehaulTripCard(trip: trips[i], onTap: () => _open(trips[i])),
                        ),
                      ),
      ),
    );
  }
}

/// One trip in a list: code, status, origin → destination, parcels and weight.
class LinehaulTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback? onTap;
  const LinehaulTripCard({super.key, required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final origin = trip['origin'] as Map? ?? const {};
    final dest = trip['destination'] as Map? ?? const {};
    final count = (trip['parcel_count'] as num?)?.toInt() ?? 0;
    final received = (trip['received_count'] as num?)?.toInt() ?? 0;
    final weight = (trip['total_weight_kg'] as num?)?.toDouble() ?? 0;
    final capacity = (trip['capacity_kg'] as num?)?.toInt();
    final over = trip['over_capacity'] == true;
    final status = trip['status'] as String? ?? '';
    return Tap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(trip['code'] as String? ?? '', style: kMonoMd.copyWith(fontWeight: FontWeight.w700, color: kTextPrimary))),
            TripStatusChip(status: status, label: trip['status_label'] as String? ?? status),
          ]),
          const SizedBox(height: kSpace12),
          _Route(origin: origin, dest: dest),
          const SizedBox(height: kSpace12),
          Wrap(spacing: kSpace16, runSpacing: kSpace6, children: [
            _fact(Icons.inventory_2_outlined, status == 'receiving' || status == 'closed'
                ? '$received of $count received' : '$count parcel${count == 1 ? '' : 's'}'),
            // The load against the truck's capacity; red when hub staff loaded more than it carries
            _fact(over ? Icons.warning_amber_rounded : Icons.scale_outlined,
                capacity == null ? '${_kg(weight)} kg' : '${_kg(weight)} of ${_kg(capacity.toDouble())} kg',
                key: const Key('tripLoad'), color: over ? kStatusFailedFg : null),
            if ((trip['vehicle_plate'] as String?)?.isNotEmpty ?? false) _fact(Icons.pin_outlined, trip['vehicle_plate'] as String),
          ]),
          if (over) ...[
            const SizedBox(height: kSpace8),
            Text('Over your truck\'s capacity. Ask the hub to take parcels off before you leave.',
                key: const Key('overCapacity'), style: kBodySm.copyWith(color: kStatusFailedFg)),
          ],
        ]),
      ),
    );
  }

  Widget _fact(IconData icon, String text, {Key? key, Color? color}) => Row(key: key, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color ?? kTextMuted),
        const SizedBox(width: kSpace4),
        Text(text, style: kBodySm.copyWith(color: color ?? kTextSecondary, fontWeight: color == null ? null : FontWeight.w600)),
      ]);
}

String _kg(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// Origin hub → destination hub.
class _Route extends StatelessWidget {
  final Map origin;
  final Map dest;
  const _Route({required this.origin, required this.dest});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _hub('From', origin)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace8),
          child: Icon(Icons.arrow_forward_rounded, color: AppPalette.dark ? kTealOnDark : kBrand600),
        ),
        Expanded(child: _hub('To', dest)),
      ]);

  Widget _hub(String label, Map h) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: kLabelSm.copyWith(color: kTextMuted)),
        Text(h['code'] as String? ?? '—', style: kHeadingSm),
        Text(h['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: kBodySm.copyWith(color: kTextSecondary)),
      ]);
}

/// Loading (amber), On the road (blue), Unloading (purple), Completed (green).
class TripStatusChip extends StatelessWidget {
  final String status;
  final String label;
  const TripStatusChip({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'draft' => (kStatusPendingBg, kStatusPendingFg),
      'dispatched' => (kStatusOnWayBg, kStatusOnWayFg),
      'receiving' => (kStatusPickupBg, kStatusPickupFg),
      'closed' => (kStatusDeliveredBg, kStatusDeliveredFg),
      _ => (kStatusCancelledBg, kStatusCancelledFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// One trip: route, timeline, the parcels on the truck, and the courier's next step.
class LinehaulTripDetailScreen extends StatefulWidget {
  final int tripId;
  const LinehaulTripDetailScreen({super.key, required this.tripId});

  @override
  State<LinehaulTripDetailScreen> createState() => _LinehaulTripDetailScreenState();
}

class _LinehaulTripDetailScreenState extends State<LinehaulTripDetailScreen> {
  Map<String, dynamic>? _trip;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Parcels added while loading, and ticked off while unloading, show up without pulling down
    _poll = Timer.periodic(kTripRefresh, (_) {
      final status = _trip?['status'];
      if (!_busy && (status == null || status == 'draft' || status == 'dispatched' || status == 'receiving')) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Opens the hub in the phone's maps app (as the rider's Navigate does).
  Future<void> _navigate(Map hub) async {
    final query = hubMapsQuery(hub);
    final uri = Platform.isAndroid
        ? Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No maps app on this phone can open this.')));
    }
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('/linehaul/trips/${widget.tripId}') as Map<String, dynamic>;
      if (mounted) setState(() { _trip = d; _error = null; });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No internet connection. Pull down to try again.');
    }
  }

  Future<void> _act(String action, String confirmTitle, String confirmBody) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final d = await Api.post('/linehaul/trips/${widget.tripId}/$action', body: const {}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _trip = (d['trip'] as Map).cast<String, dynamic>());
      messenger.showSnackBar(SnackBar(content: Text(d['message'] as String? ?? 'Saved.')));
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No internet connection. Try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(title: trip?['code'] as String? ?? 'Trip'),
      body: RefreshIndicator(
        onRefresh: _load,
        color: kBrand600,
        child: trip == null
            ? ListView(children: [
                const SizedBox(height: 80),
                if (_error == null)
                  const Center(child: CircularProgressIndicator(color: kBrand600))
                else
                  BhEmptyState(icon: Icons.error_outline, title: 'Could not load this trip', subtitle: _error,
                      action: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
              ])
            : ListView(padding: const EdgeInsets.all(kSpace16), children: [
                LinehaulTripCard(trip: trip),
                const SizedBox(height: kSpace12),
                _timeline(trip),
                const SizedBox(height: kSpace12),
                _parcels(trip),
                const SizedBox(height: kSpace16),
                ..._actions(trip),
              ]),
      ),
    );
  }

  /// Navigate to the origin hub while the truck loads, to the destination once on the road.
  Widget? _navigateButton(Map<String, dynamic> trip) {
    final hub = switch (trip['status']) {
      'draft' => trip['origin'] as Map?,
      'dispatched' => trip['destination'] as Map?,
      _ => null,
    };
    if (hub == null) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace10),
      child: OutlinedButton.icon(
        key: const Key('navigateHub'),
        icon: const Icon(Icons.navigation_outlined, size: 18),
        label: Text('Navigate to ${hub['code'] ?? 'hub'}'),
        onPressed: () => _navigate(hub),
      ),
    );
  }

  List<Widget> _actions(Map<String, dynamic> trip) {
    final nav = _navigateButton(trip);
    return [if (nav != null) nav, ..._stepActions(trip)];
  }

  List<Widget> _stepActions(Map<String, dynamic> trip) {
    final dest = (trip['destination'] as Map?)?['code'] ?? 'the next hub';
    final origin = (trip['origin'] as Map?)?['code'] ?? 'the hub';
    if (trip['can_depart'] == true) {
      return [
        BhPrimaryButton(
          label: 'Start Trip',
          icon: Icons.local_shipping,
          loading: _busy,
          onPressed: _busy ? null : () => _act('depart', 'Start trip?',
              'Confirm every parcel is on the truck before leaving $origin. Hub staff can no longer add parcels to this trip.'),
        ),
      ];
    }
    if (trip['can_arrive'] == true) {
      return [
        BhPrimaryButton(
          label: 'Arrived at $dest',
          icon: Icons.flag_outlined,
          loading: _busy,
          onPressed: _busy ? null : () => _act('arrive', 'Arrived at $dest?',
              'The hub will now receive the parcels from your truck.'),
        ),
      ];
    }
    final note = switch (trip['status']) {
      'receiving' => '$dest is receiving the parcels. The trip completes when every parcel is received.',
      'closed' => 'Trip completed. $dest received every parcel.',
      _ => null,
    };
    return note == null
        ? const []
        : [
            Container(
              padding: const EdgeInsets.all(kSpace12),
              decoration: BoxDecoration(color: kBrand50, borderRadius: BorderRadius.circular(kRadiusLg)),
              child: Text(note, style: kBodyMd.copyWith(color: AppPalette.dark ? kTealOnDark : kBrand700)),
            ),
          ];
  }

  Widget _timeline(Map<String, dynamic> trip) {
    String when(String key) {
      final v = trip[key] as String?;
      if (v == null) return '—';
      final t = DateTime.tryParse(v)?.toLocal();
      if (t == null) return '—';
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
      return '${m[t.month - 1]} ${t.day}, $h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    }

    Widget row(String label, String key) => Padding(
          padding: const EdgeInsets.only(bottom: kSpace8),
          child: Row(children: [
            Icon(trip[key] != null ? Icons.check_circle : Icons.radio_button_unchecked, size: 18,
                color: trip[key] != null ? kStatusDeliveredFg : kTextMuted),
            const SizedBox(width: kSpace8),
            Expanded(child: Text(label, style: kBodyMd)),
            Text(when(key), style: kBodySm.copyWith(color: kTextSecondary)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace8),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Trip progress', style: kHeadingSm),
        const SizedBox(height: kSpace10),
        row('Loaded at origin hub', 'created_at'),
        row('Trip started', 'dispatched_at'),
        row('Arrived at destination', 'arrived_at'),
        row('All parcels received', 'closed_at'),
      ]),
    );
  }

  Widget _parcels(Map<String, dynamic> trip) {
    final parcels = (trip['parcels'] as List? ?? const []).cast<Map>();
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Parcels on this trip (${parcels.length})', style: kHeadingSm),
        const SizedBox(height: kSpace8),
        if (parcels.isEmpty) Text('No parcels.', style: kBodySm.copyWith(color: kTextMuted)),
        for (final p in parcels)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace6),
            child: Row(children: [
              Icon(p['received'] == true ? Icons.inventory : Icons.inventory_2_outlined, size: 18,
                  color: p['received'] == true ? kStatusDeliveredFg : kTextMuted),
              const SizedBox(width: kSpace8),
              Expanded(child: Text(p['tracking_number'] as String? ?? '—', style: kMonoMd.copyWith(color: kTextPrimary))),
              if (p['weight_kg'] != null) Text('${_kg((p['weight_kg'] as num).toDouble())} kg', style: kBodySm.copyWith(color: kTextSecondary)),
              if (p['received'] == true) ...[
                const SizedBox(width: kSpace8),
                Text('Received', style: kLabelSm.copyWith(color: kStatusDeliveredFg)),
              ],
            ]),
          ),
      ]),
    );
  }
}
