import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_empty_state.dart';
import '../../widgets/bh_offline_banner.dart';

class CourierEarningsScreen extends StatefulWidget {
  const CourierEarningsScreen({super.key});
  @override
  State<CourierEarningsScreen> createState() => _CourierEarningsState();
}

class _CourierEarningsState extends State<CourierEarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CourierProvider>().loadEarnings());
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CourierProvider>();

    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(
        title: 'Earnings',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cp.loadEarnings,
          ),
        ],
      ),
      body: BhOfflineBanner(
        child: cp.loadingEarnings
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 4),
              )
            : RefreshIndicator(
                onRefresh: cp.loadEarnings,
                color: kBrand600,
                child: cp.earnings == null
                    ? const BhEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No earnings data',
                        subtitle:
                            'Complete deliveries to see your earnings here',
                      )
                    : _buildBody(cp.earnings!),
              ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final total = (data['total_earnings'] as num?)?.toDouble() ?? 0.0;
    final today = (data['today_earnings'] as num?)?.toDouble() ?? 0.0;
    final week = (data['week_earnings'] as num?)?.toDouble() ?? 0.0;
    final month = (data['month_earnings'] as num?)?.toDouble() ?? 0.0;
    final history = data['history'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(kSpace16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero total card ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Earnings',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 4),
                Text('₱${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: kSpace16),
                Row(children: [
                  _heroPeriod('Today', '₱${today.toStringAsFixed(2)}'),
                  const SizedBox(width: kSpace10),
                  _heroPeriod('This Week', '₱${week.toStringAsFixed(2)}'),
                  const SizedBox(width: kSpace10),
                  _heroPeriod('This Month', '₱${month.toStringAsFixed(2)}'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Delivery history ──────────────────────────────────────────
          Text('Delivery History',
              style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: kSpace10),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(kSpace24),
              decoration: BoxDecoration(
                color: kSurfaceBase,
                borderRadius: BorderRadius.circular(kRadiusLg),
                border: Border.all(color: kBorderDefault),
              ),
              child: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 36, color: kTextMuted),
                  SizedBox(height: kSpace8),
                  Text('No delivery history yet',
                      style: TextStyle(color: kTextMuted, fontSize: 13)),
                ]),
              ),
            )
          else
            ...history.map<Widget>((item) {
              final m = item as Map<String, dynamic>;
              return _HistoryItem(data: m);
            }),
          const SizedBox(height: kSpace20),
        ],
      ),
    );
  }

  Widget _heroPeriod(String label, String amount) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(kSpace10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 2),
              Text(amount,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      );
}

// ── History Item ──────────────────────────────────────────────────────────────
class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final orderId = data['order_id'] ?? data['id'] ?? '—';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final status = data['status'] as String? ?? 'delivered';
    final createdAt = data['created_at'] as String?;
    final buyer = data['buyer_name'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: kSpace8),
      padding: const EdgeInsets.all(kSpace14),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorderDefault),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: kStatusDeliveredBg,
              borderRadius: BorderRadius.circular(kSpace10)),
          child: const Icon(Icons.check_circle_outline,
              size: 20, color: kStatusDeliveredFg),
        ),
        const SizedBox(width: kSpace12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parcel #$orderId',
                style: kHeadingSm.copyWith(color: kTextPrimary)),
            if (buyer != null)
              Text(buyer, style: kBodySm.copyWith(color: kTextSecondary)),
            if (createdAt != null)
              Text(_fmt(createdAt), style: kLabelSm.copyWith(color: kTextMuted)),
          ],
        )),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₱${amount.toStringAsFixed(2)}',
                style: kHeadingSm.copyWith(color: kBrand700)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: kStatusDeliveredBg,
                borderRadius: BorderRadius.circular(kSpace10),
              ),
              child: Text(
                AppConstants.orderStatusLabel(status),
                style: kLabelSm.copyWith(color: kStatusDeliveredFg),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
