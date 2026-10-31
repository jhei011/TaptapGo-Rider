import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/rider_job.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_offline_banner.dart';
import '../../widgets/bh_empty_state.dart';
import 'rider_job_widgets.dart';

/// My Jobs: active pickup and delivery jobs, and recently finished ones.
class CourierOrdersScreen extends StatefulWidget {
  const CourierOrdersScreen({super.key});
  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersState();
}

class _CourierOrdersState extends State<CourierOrdersScreen> {
  String _filter = 'active';

  // Tab filter definitions (kept as data source for chip labels)
  static const _tabDefs = [
    _Tab('Active', 'active'),
    _Tab('Pickups', 'pickup'),
    _Tab('Deliveries', 'delivery'),
    _Tab('Finished', 'finished'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CourierProvider>().loadJobs());
  }

  List<RiderJob> _filtered(CourierProvider cp) => switch (_filter) {
        'pickup'   => cp.activeJobs.where((j) => j.isPickup).toList(),
        'delivery' => cp.activeJobs.where((j) => j.isDelivery).toList(),
        'finished' => cp.recentJobs,
        _          => cp.activeJobs,
      };

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CourierProvider>();
    final jobs = _filtered(cp);

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: const BhAppBar(title: 'My Jobs', showBack: false),
      body: BhOfflineBanner(
        child: cp.loadingJobs && cp.activeJobs.isEmpty && cp.recentJobs.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 5),
              )
            : Column(
                children: [
                  // ── Filter chip row ──────────────────────────────────
                  _FilterChipRow(
                    tabs: _tabDefs,
                    selected: _filter,
                    onSelect: (f) => setState(() => _filter = f),
                  ),

                  // ── Job list ─────────────────────────────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cp.loadJobs,
                      color: kBrand600,
                      child: jobs.isEmpty
                          ? ListView(children: [
                              BhEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: _filter == 'finished' ? 'No finished jobs yet' : 'No active jobs',
                                subtitle: 'Go Online on Home to receive job offers',
                              ),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(kSpace14, kSpace14, kSpace14, 80),
                              itemCount: jobs.length,
                              itemBuilder: (_, i) => RiderJobCard(job: jobs[i]),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Filter chip row ───────────────────────────────────────────────────────────
class _FilterChipRow extends StatelessWidget {
  final List<_Tab> tabs;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterChipRow({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurfaceRaised,
      padding: const EdgeInsets.symmetric(
          horizontal: kSpace14, vertical: kSpace10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = tab.key == selected;
            return Padding(
              padding: const EdgeInsets.only(right: kSpace8),
              child: GestureDetector(
                onTap: () => onSelect(tab.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace12, vertical: kSpace8),
                  decoration: BoxDecoration(
                    color: isSelected ? kBrand500 : kSurfaceBase,
                    borderRadius: BorderRadius.circular(kRadiusFull),
                    border: Border.all(
                      color: isSelected ? kBrand500 : kBorderDefault,
                    ),
                  ),
                  child: Text(
                    tab.label,
                    style: kLabelMd.copyWith(
                      color:
                          isSelected ? Colors.white : kTextSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Tab {
  final String label;
  final String key;
  const _Tab(this.label, this.key);
}
