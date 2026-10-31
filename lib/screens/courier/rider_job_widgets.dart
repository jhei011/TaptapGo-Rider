import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/rider_job.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_status_chip.dart';

String peso(num v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₱$whole.${parts[1]}';
}

String formatTime(String? iso) {
  final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${months[t.month - 1]} ${t.day}, $h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

void showResult(BuildContext context, bool ok, String success, String? error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(ok ? success : (error ?? 'Something went wrong. Please try again.')),
    backgroundColor: ok ? kBrand700 : kActionDestructive,
  ));
}

BoxDecoration cardDecoration() => BoxDecoration(
      color: kSurfaceBase,
      borderRadius: BorderRadius.circular(kRadiusLg),
      border: Border.all(color: kBorderDefault),
      boxShadow: const [BoxShadow(color: Color(0x060E2A38), blurRadius: 6, offset: Offset(0, 2))],
    );

// ── Active / completed job card ───────────────────────────────────────────────
class RiderJobCard extends StatelessWidget {
  final RiderJob job;
  const RiderJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final stop = job.destination;
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace10),
      decoration: cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: () => Navigator.pushNamed(context, '/courier/job', arguments: job.id),
        child: Padding(
          padding: const EdgeInsets.all(kSpace16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: kBrand50, borderRadius: BorderRadius.circular(kSpace10)),
                child: Icon(job.isPickup ? Icons.storefront_outlined : Icons.home_outlined, size: 18, color: kBrand700),
              ),
              const SizedBox(width: kSpace10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job.isPickup ? 'Pickup · ${job.trackingNumber}' : 'Delivery · ${job.trackingNumber}',
                      style: kHeadingSm.copyWith(color: kTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(job.isDelivery ? 'Attempt ${job.attempt} of ${job.maxAttempts}' : 'Order #${job.orderId}',
                      style: kBodySm.copyWith(color: kTextSecondary)),
                ]),
              ),
              BhStatusChip(status: job.status == 'failed' ? 'failed_delivery' : job.shipmentStatus, size: BhChipSize.small),
            ]),
            const SizedBox(height: kSpace10),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: kBrand600),
              const SizedBox(width: kSpace4),
              Expanded(
                child: Text('${stop.name} · ${stop.area}',
                    style: kBodySm.copyWith(color: kTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: kSpace8),
              Text(job.isCod ? 'COD ${peso(job.codAmount)}' : 'Paid',
                  style: kLabelMd.copyWith(color: kBrand700)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Job offer with a live countdown ───────────────────────────────────────────
class JobOfferCard extends StatefulWidget {
  final JobOffer offer;
  final CourierProvider cp;
  const JobOfferCard({super.key, required this.offer, required this.cp});

  @override
  State<JobOfferCard> createState() => _JobOfferCardState();
}

class _JobOfferCardState extends State<JobOfferCard> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    final cp = widget.cp;
    final ok = accept ? await cp.acceptOffer(widget.offer) : await cp.declineOffer(widget.offer);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, ok, accept ? 'Job accepted.' : 'Job declined.', cp.error);
    if (!ok) cp.loadOffers();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.offer.job;
    final left = widget.offer.secondsLeft();
    final expired = left <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: kSpace10),
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration().copyWith(border: Border.all(color: kBrand400, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(job.isPickup ? 'New pickup job' : 'New delivery job',
                style: kHeadingSm.copyWith(color: kTextPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: expired ? kStatusFailedBg : kStatusPendingBg,
              borderRadius: BorderRadius.circular(kRadiusFull),
            ),
            child: Text(expired ? 'Expired' : '${left}s left',
                style: kLabelMd.copyWith(color: expired ? kStatusFailedFg : kStatusPendingFg)),
          ),
        ]),
        const SizedBox(height: kSpace10),
        _line(Icons.storefront_outlined, 'Pickup', '${job.pickup.name} · ${job.pickup.area}'),
        _line(Icons.home_outlined, 'Drop-off', job.dropoff.area),
        _line(Icons.payments_outlined, 'COD', job.isCod ? peso(job.codAmount) : 'None (prepaid)'),
        _line(Icons.account_balance_wallet_outlined, 'Pay', '${peso(job.pay)} ${job.isPickup ? 'pickup' : 'delivery'}'),
        const SizedBox(height: kSpace12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy || expired ? null : () => _respond(false),
              style: OutlinedButton.styleFrom(foregroundColor: kTextSecondary, side: const BorderSide(color: kBorderDefault)),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: kSpace10),
          Expanded(
            child: ElevatedButton(
              onPressed: _busy || expired ? null : () => _respond(true),
              style: ElevatedButton.styleFrom(backgroundColor: kBrand600, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Accept'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: kSpace4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: kBrand600),
          const SizedBox(width: kSpace6),
          SizedBox(width: 64, child: Text(label, style: kBodySm.copyWith(color: kTextMuted))),
          Expanded(child: Text(value, style: kBodySm.copyWith(color: kTextPrimary))),
        ]),
      );
}
