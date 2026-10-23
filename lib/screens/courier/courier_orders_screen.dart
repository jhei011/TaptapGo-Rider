import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/courier_provider.dart';
import '../../models/order.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_parcel_card.dart';
import '../../widgets/bh_offline_banner.dart';
import '../../widgets/bh_empty_state.dart';

class CourierOrdersScreen extends StatefulWidget {
  const CourierOrdersScreen({super.key});
  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersState();
}

class _CourierOrdersState extends State<CourierOrdersScreen> {
  String? _filterStatus;

  // Tab filter definitions (kept as data source for chip labels/statuses)
  static const _tabDefs = [
    _Tab('All', null),
    _Tab('Pickup', 'ready_for_pickup'),
    _Tab('On the Way', 'out_for_delivery'),
    _Tab('Delivered', 'delivered'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CourierProvider>().loadOrders());
  }

  List<Order> _filtered(List<Order> orders, String? status) {
    if (status == null) return orders;
    return orders.where((o) => o.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CourierProvider>();
    final filtered = _filtered(cp.orders, _filterStatus);

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: const BhAppBar(title: 'My Parcels', showBack: false),
      body: BhOfflineBanner(
        child: cp.loadingOrders
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 5),
              )
            : Column(
                children: [
                  // ── Filter chip row ──────────────────────────────────
                  _FilterChipRow(
                    tabs: _tabDefs,
                    selected: _filterStatus,
                    onSelect: (status) =>
                        setState(() => _filterStatus = status),
                  ),

                  // ── Order list ───────────────────────────────────────
                  Expanded(
                    child: filtered.isEmpty
                        ? BhEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: _filterStatus == null
                                ? 'No parcels yet'
                                : 'No ${AppConstants.orderStatusLabel(_filterStatus!).toLowerCase()} parcels',
                            subtitle: 'Assigned parcels will appear here',
                          )
                        : RefreshIndicator(
                            onRefresh: cp.loadOrders,
                            color: kBrand600,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  kSpace14, kSpace14, kSpace14, 80),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) =>
                                  BhParcelCard(order: filtered[i], cp: cp),
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
  final String? selected;
  final ValueChanged<String?> onSelect;

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
            final isSelected = tab.status == selected;
            return Padding(
              padding: const EdgeInsets.only(right: kSpace8),
              child: GestureDetector(
                onTap: () => onSelect(tab.status),
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
  final String? status;
  const _Tab(this.label, this.status);
}
