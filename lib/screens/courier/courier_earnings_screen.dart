import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_skeleton.dart';
import '../../widgets/bh_empty_state.dart';
import '../../widgets/bh_offline_banner.dart';
import 'rider_job_widgets.dart';

/// Earnings, job history and COD to remit (Rider Modules R7).
class CourierEarningsScreen extends StatefulWidget {
  const CourierEarningsScreen({super.key});
  @override
  State<CourierEarningsScreen> createState() => _CourierEarningsState();
}

class _CourierEarningsState extends State<CourierEarningsScreen> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() =>
      context.read<CourierProvider>().loadEarnings(from: _range?.start, to: _range?.end);

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _reload();
    }
  }

  Future<void> _remit(double balance) async {
    final amount = TextEditingController(text: balance.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remit COD'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('COD balance: ${peso(balance)}', style: kBodySm.copyWith(color: kTextSecondary)),
          const SizedBox(height: kSpace10),
          TextField(
            key: const Key('remitAmountField'),
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: const InputDecoration(labelText: 'Amount handed to your logistics company', prefixText: '₱'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(amount.text)),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final cp = context.read<CourierProvider>();
    final ok = await cp.remit(value);
    if (mounted) {
      showResult(context, ok, 'Remittance submitted. It stays Pending until your logistics company confirms it.', cp.error);
    }
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
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: BhOfflineBanner(
        child: cp.loadingEarnings && cp.earnings == null
            ? const Padding(
                padding: EdgeInsets.all(kSpace16),
                child: SkeletonList(count: 4),
              )
            : RefreshIndicator(
                onRefresh: _reload,
                color: kBrand600,
                child: cp.earnings == null
                    ? ListView(children: const [
                        BhEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No earnings data',
                          subtitle: 'Complete pickups and deliveries to see your earnings here',
                        ),
                      ])
                    : _buildBody(cp.earnings!, cp.cod),
              ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data, Map<String, dynamic>? cod) {
    double n(String k, [Map<String, dynamic>? m]) => ((m ?? data)[k] as num?)?.toDouble() ?? 0.0;
    final history = data['history'] as List? ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(kSpace16),
      children: [
        // ── Totals ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(kSpace16),
          decoration: BoxDecoration(color: kBrand800, borderRadius: BorderRadius.circular(kRadiusLg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Earnings', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
            Text(peso(n('total_earnings')),
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: kSpace12),
            Row(children: [
              _total('Today', n('today_earnings')),
              _total('This week', n('week_earnings')),
              _total('This month', n('month_earnings')),
            ]),
            const SizedBox(height: kSpace8),
            Text('₱30.00 per pickup · ₱50.00 per delivery · ₱0.00 per failed attempt',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
          ]),
        ),
        const SizedBox(height: kSpace14),

        // ── COD to remit ──────────────────────────────────────────────────
        if (cod != null) _codCard(cod, n('balance', cod), n('pending_total', cod)),
        const SizedBox(height: kSpace14),

        // ── History ───────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Text('History', style: kHeadingSm.copyWith(color: kTextPrimary))),
          TextButton.icon(
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(_range == null
                ? 'Last 30 days'
                : '${formatTime(_range!.start.toIso8601String()).split(',').first} – ${formatTime(_range!.end.toIso8601String()).split(',').first}'),
            onPressed: _pickRange,
          ),
        ]),
        const SizedBox(height: kSpace8),
        if (history.isEmpty)
          const BhEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No jobs in this period',
            subtitle: 'Finished pickups, deliveries and failed attempts appear here',
          )
        else
          ...history.map((h) {
            final row = (h as Map).cast<String, dynamic>();
            return Container(
              margin: const EdgeInsets.only(bottom: kSpace8),
              padding: const EdgeInsets.all(kSpace12),
              decoration: cardDecoration(),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${row['result']} · ${row['tracking_number']}',
                        style: kLabelMd.copyWith(color: kTextPrimary)),
                    Text(formatTime(row['date'] as String?), style: kBodySm.copyWith(color: kTextMuted)),
                  ]),
                ),
                Text(peso((row['pay'] as num?) ?? 0), style: kHeadingSm.copyWith(color: kBrand700)),
              ]),
            );
          }),
      ],
    );
  }

  Widget _total(String label, double value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
          Text(peso(value), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _codCard(Map<String, dynamic> cod, double balance, double pending) {
    final collected = cod['collected'] as List? ?? [];
    final remittances = cod['remittances'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('COD balance', style: kHeadingSm.copyWith(color: kTextPrimary))),
          Text(peso(balance), style: kHeadingMd.copyWith(color: kBrand700)),
        ]),
        if (pending > 0)
          Text('${peso(pending)} remitted, waiting for confirmation',
              style: kBodySm.copyWith(color: kStatusPendingFg)),
        const SizedBox(height: kSpace8),
        for (final c in collected.take(10))
          Builder(builder: (_) {
            final row = (c as Map).cast<String, dynamic>();
            return Padding(
              padding: const EdgeInsets.only(bottom: kSpace4),
              child: Row(children: [
                Expanded(child: Text('Order #${row['order_id']} · ${row['tracking_number']}',
                    style: kBodySm.copyWith(color: kTextSecondary))),
                Text(peso((row['amount'] as num?) ?? 0), style: kBodySm.copyWith(color: kTextPrimary)),
              ]),
            );
          }),
        for (final r in remittances.take(5))
          Builder(builder: (_) {
            final row = (r as Map).cast<String, dynamic>();
            final short = (row['shortfall'] as num?) ?? 0;
            return Text(
              'Remitted ${peso((row['amount'] as num?) ?? 0)} · ${row['status'] == 'pending' ? 'Pending' : 'Confirmed'}'
              '${short > 0 ? ' · ${peso(short)} short' : ''}',
              style: kBodySm.copyWith(color: kTextMuted),
            );
          }),
        const SizedBox(height: kSpace10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Remit COD'),
            onPressed: balance > 0 && pending == 0 ? () => _remit(balance) : null,
            style: ElevatedButton.styleFrom(backgroundColor: kBrand600, foregroundColor: Colors.white, elevation: 0),
          ),
        ),
      ]),
    );
  }
}
