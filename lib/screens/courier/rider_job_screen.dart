import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/pending_delivery_store.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/attachment_rules.dart';
import '../../core/utils/delivery_rules.dart';
import '../../models/rider_job.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import '../../widgets/bh_status_chip.dart';
import 'rider_job_widgets.dart';
import 'waybill_scanner_screen.dart';

/// One pickup or delivery job: details, navigation and the next step
/// (Rider Modules R3 Job Assignment, R4 Pickup, R5 Delivery, R6 Failed Delivery).
class RiderJobScreen extends StatefulWidget {
  final int jobId;
  const RiderJobScreen({super.key, required this.jobId});

  @override
  State<RiderJobScreen> createState() => _RiderJobScreenState();
}

class _RiderJobScreenState extends State<RiderJobScreen> {
  RiderJob? _job;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  final _tracking = TextEditingController();
  final _trackingFocus = FocusNode();
  final _otp = TextEditingController();
  final _cod = TextEditingController();
  File? _photo;

  late final CourierProvider _cp;
  bool _hadPending = false;

  static const _failReasons = {
    'buyer_not_home': 'Buyer not home',
    'wrong_address': 'Wrong address',
    'refused': 'Refused',
  };

  @override
  void initState() {
    super.initState();
    _cp = context.read<CourierProvider>();
    _hadPending = _cp.pendingFor(widget.jobId) != null;
    _cp.addListener(_onProviderChanged);
    _load();
  }

  @override
  void dispose() {
    _cp.removeListener(_onProviderChanged);
    _tracking.dispose();
    _trackingFocus.dispose();
    _otp.dispose();
    _cod.dispose();
    super.dispose();
  }

  /// A delivery saved offline was sent in the background: show the job's new status.
  void _onProviderChanged() {
    final hasPending = _cp.pendingFor(widget.jobId) != null;
    if (_hadPending && !hasPending && !_busy) _load();
    _hadPending = hasPending;
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    final cp = context.read<CourierProvider>();
    final job = await cp.loadJob(widget.jobId);
    if (!mounted) return;
    setState(() {
      _job = job;
      _loading = false;
      _loadError = job == null ? (cp.error ?? 'Job not found.') : null;
      _restoreSaved(cp.pendingFor(widget.jobId));
    });
  }

  /// After the app is reopened, a delivery saved offline comes back with its photo, code and amount (RID-DLV-009).
  void _restoreSaved(PendingDelivery? saved) {
    if (saved == null || _photo != null) return;
    _otp.text = saved.otp;
    _cod.text = saved.codAmount ?? '';
    final photo = File(saved.photoPath);
    if (photo.existsSync()) _photo = photo;
  }

  /// Reads the waybill barcode and confirms the pickup with it (RID-PICK-002). Without a
  /// code (camera not allowed, or Back) the rider types the tracking number instead.
  Future<void> _scanWaybill(RiderJob job) async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const WaybillScannerScreen()));
    if (!mounted) return;
    if (code == null) {
      _trackingFocus.requestFocus();
      return;
    }
    _tracking.text = code;
    await _act((cp) => cp.confirmPickup(job.id, code), 'Parcel picked up.');
  }

  Future<void> _act(Future<RiderJob?> Function(CourierProvider cp) action, String success) async {
    // A second tap before the button redraws as disabled must not send the action twice
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final cp = context.read<CourierProvider>();
    final job = await action(cp);
    if (!mounted) return;
    final conflict = job == null && cp.lastErrorWasConflict;
    setState(() {
      _busy = false;
      if (job != null) _job = job;
    });
    showResult(context, job != null, success, cp.error);
    // The job changed on the server (e.g. already picked up): show what the server has now
    if (conflict) await _load();
  }

  static const _declineReasons = [
    'Too far from my area',
    'Vehicle problem',
    'Cannot make it in time',
    'Parcel too big for my vehicle',
  ];

  /// Gives the job back before the rider holds the parcel; logistics sees the reason.
  Future<void> _decline(RiderJob job) async {
    if (_busy) return;
    String? choice;
    final other = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final text = choice == 'other' ? other.text.trim() : choice;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace16 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text("Can't take this job?", style: kHeadingSm.copyWith(color: kTextPrimary)),
                const SizedBox(height: kSpace4),
                Text('The job goes back to your logistics company, who will give it to another rider.',
                    style: kBodySm.copyWith(color: kTextSecondary)),
                const SizedBox(height: kSpace8),
                RadioGroup<String>(
                  groupValue: choice,
                  onChanged: (v) => setSheet(() => choice = v),
                  child: Column(children: [
                    for (final r in _declineReasons) RadioListTile<String>(value: r, title: Text(r)),
                    const RadioListTile<String>(value: 'other', title: Text('Other reason')),
                  ]),
                ),
                if (choice == 'other')
                  TextField(
                    key: const Key('declineOtherField'),
                    controller: other,
                    maxLength: 255,
                    autofocus: true,
                    onChanged: (_) => setSheet(() {}),
                    decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                  ),
                const SizedBox(height: kSpace8),
                ElevatedButton(
                  key: const Key('declineConfirm'),
                  onPressed: text == null || text.isEmpty ? null : () => Navigator.pop(ctx, text),
                  style: ElevatedButton.styleFrom(backgroundColor: kActionDestructive, foregroundColor: Colors.white),
                  child: const Text('Give back job'),
                ),
              ]),
            ),
          );
        },
      ),
    );
    other.dispose();
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final cp = context.read<CourierProvider>();
    final ok = await cp.declineJob(job.id, reason);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, ok, 'Job given back to your logistics company.', cp.error);
    if (ok) {
      Navigator.of(context).pop();
    } else if (cp.lastErrorWasConflict) {
      await _load();
    }
  }

  Widget _declineButton(RiderJob job) => Padding(
        padding: const EdgeInsets.only(top: kSpace8),
        child: TextButton(
          key: const Key('declineJob'),
          onPressed: _busy ? null : () => _decline(job),
          style: TextButton.styleFrom(foregroundColor: kActionDestructive),
          child: const Text("Can't take this job"),
        ),
      );

  // ── External apps ─────────────────────────────────────────────────────────
  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showResult(context, false, '', 'No app on this phone can open this.');
  }

  void _navigate(String address) => _open(Platform.isAndroid
      ? Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'));

  Future<void> _takePhoto() async {
    // Proof of delivery is taken live with the camera; the gallery is not offered (M14)
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
    if (shot == null) return;
    final photo = File(shot.path);
    // A photo over 5 MB, or one that is not a real JPG/PNG, is refused before it is sent (A16)
    final problem = await AttachmentRules.validate(photo, kind: AttachmentKind.image);
    if (!mounted) return;
    if (problem != null) {
      showResult(context, false, '', problem);
      return;
    }
    setState(() => _photo = photo);
  }

  Future<void> _chooseFailReason(RiderJob job) async {
    String? reason;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kSpace16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Why did the delivery fail?', style: kHeadingSm.copyWith(color: kTextPrimary)),
              const SizedBox(height: kSpace4),
              Text(
                job.isReturn
                    ? 'Attempt ${job.attempt} of ${job.maxAttempts}. The parcel goes back to the '
                        'hub, and your logistics company decides what happens next.'
                    : 'Attempt ${job.attempt} of ${job.maxAttempts}. Choosing Refused sends the parcel '
                        'straight back to the seller (Return to Sender).',
                style: kBodySm.copyWith(color: kTextSecondary),
              ),
              const SizedBox(height: kSpace8),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setSheet(() => reason = v),
                child: Column(children: [
                  for (final e in _failReasons.entries)
                    RadioListTile<String>(value: e.key, title: Text(e.value)),
                ]),
              ),
              const SizedBox(height: kSpace8),
              ElevatedButton(
                onPressed: reason == null ? null : () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: kActionDestructive, foregroundColor: Colors.white),
                child: const Text('Mark as Failed'),
              ),
            ]),
          ),
        ),
      ),
    );
    if (confirmed == true && reason != null) {
      await _act((cp) => cp.fail(widget.jobId, reason!), 'Delivery marked as failed.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      backgroundColor: kSurfaceRaised,
      appBar: BhAppBar(title: job == null
          ? 'Job'
          : job.isReturn
              ? (job.isPickup ? 'Return Pickup' : 'Return Delivery')
              : (job.isPickup ? 'Pickup Job' : 'Delivery Job')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrand600))
          : job == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(kSpace24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_loadError ?? 'Job not found.', textAlign: TextAlign.center, style: kBodyMd.copyWith(color: kTextSecondary)),
                      const SizedBox(height: kSpace12),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kBrand600,
                  child: ListView(padding: const EdgeInsets.all(kSpace16), children: [
                    _header(job),
                    const SizedBox(height: kSpace12),
                    _progress(job),
                    const SizedBox(height: kSpace12),
                    _stopCard(job),
                    const SizedBox(height: kSpace12),
                    _detailsCard(job),
                    const SizedBox(height: kSpace12),
                    _actions(job),
                    const SizedBox(height: kSpace24),
                  ]),
                ),
    );
  }

  Widget _header(RiderJob job) => Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tracking number', style: kLabelSm.copyWith(color: kTextMuted)),
              SelectableText(job.trackingNumber, style: kHeadingMd.copyWith(color: kTextPrimary)),
              const SizedBox(height: kSpace4),
              Text(
                job.isDelivery
                    ? 'Order #${job.orderId} · attempt ${job.attempt} of ${job.maxAttempts}'
                    : 'Order #${job.orderId} · ${job.parcels} parcel${job.parcels == 1 ? '' : 's'}',
                style: kBodySm.copyWith(color: kTextSecondary),
              ),
              if (job.isReturn) ...[
                const SizedBox(height: kSpace6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kStatusPendingBg,
                    borderRadius: BorderRadius.circular(kRadiusFull),
                  ),
                  child: Text(
                    'Return ${job.returnNumber ?? ''} · Buyer → seller'.trim(),
                    style: kLabelSm.copyWith(color: kStatusPendingFg),
                  ),
                ),
              ],
            ]),
          ),
          BhStatusChip(status: job.status == 'failed' ? 'failed_delivery' : job.shipmentStatus),
        ]),
      );

  /// Where the parcel is in the flow, with every step already reached filled in (A10).
  Widget _progress(RiderJob job) {
    final steps = job.isPickup
        ? [
            ('Assigned', 'assigned'),
            (job.isReturn ? 'Collected from buyer' : 'Picked up', 'picked_up'),
            ('At hub', 'at_hub'),
          ]
        : [
            ('Assigned', 'assigned'),
            ('Out for delivery', 'out_for_delivery'),
            (job.isReturn ? 'Returned to seller' : 'Delivered', 'delivered'),
          ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace14),
      decoration: cardDecoration(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 10, left: 4, right: 4),
                color: job.times[steps[i].$2] != null ? kBrand600 : kBorderDefault,
              ),
            ),
          _step(steps[i].$1, reached: job.times[steps[i].$2] != null),
        ],
      ]),
    );
  }

  Widget _step(String label, {required bool reached}) => SizedBox(
        width: 84,
        child: Column(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: reached ? kBrand600 : kSurfaceBase,
              shape: BoxShape.circle,
              border: Border.all(color: reached ? kBrand600 : kBorderStrong),
            ),
            child: Icon(Icons.check, size: 13, color: reached ? Colors.white : kTextMuted),
          ),
          const SizedBox(height: kSpace4),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: kLabelSm.copyWith(
                  color: reached ? kTextPrimary : kTextMuted,
                  fontWeight: reached ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );

  Widget _stopCard(RiderJob job) {
    final stop = job.destination;
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          job.isPickup
              ? (job.isReturn ? 'Pick up from buyer' : 'Pick up from seller')
              : (job.isReturn ? 'Deliver back to seller' : 'Deliver to buyer'),
          style: kLabelSm.copyWith(color: kTextMuted),
        ),
        const SizedBox(height: kSpace4),
        Text(stop.name, style: kHeadingSm.copyWith(color: kTextPrimary)),
        if (stop.phone != null) Text(stop.phone!, style: kBodySm.copyWith(color: kTextSecondary)),
        const SizedBox(height: kSpace4),
        Text(stop.address, style: kBodySm.copyWith(color: kTextSecondary)),
        const SizedBox(height: kSpace12),
        Wrap(spacing: kSpace8, runSpacing: kSpace8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.navigation_outlined, size: 16),
            label: const Text('Navigate'),
            onPressed: stop.address.isEmpty ? null : () => _navigate(stop.address),
          ),
          if (stop.phone != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.call_outlined, size: 16),
              label: const Text('Call'),
              onPressed: () => _open(Uri(scheme: 'tel', path: stop.phone)),
            ),
          if (stop.phone != null && job.isDelivery)
            OutlinedButton.icon(
              icon: const Icon(Icons.sms_outlined, size: 16),
              label: const Text('Message'),
              onPressed: () => _open(Uri(scheme: 'sms', path: stop.phone)),
            ),
        ]),
      ]),
    );
  }

  Widget _detailsCard(RiderJob job) {
    final times = <String, String>{
      'Assigned': 'assigned', 'Picked up': 'picked_up', 'At hub': 'at_hub',
      'Out for delivery': 'out_for_delivery', 'Delivered': 'delivered', 'Failed': 'failed',
    };
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (job.isReturn) ...[
          _row('Trip', 'Return · nothing to collect'),
          if (job.returnNumber != null) _row('Return no.', job.returnNumber!),
          _row('Your pay', job.status == 'assigned' ? 'No pay for a return trip' : peso(job.earned)),
        ] else ...[
          _row('Payment', job.isCod ? 'COD ${peso(job.codAmount)}' : '${peso(0)} COD · Paid (${job.paymentMethod.toUpperCase()})'),
          _row('Your pay', job.status == 'assigned' ? '${peso(job.pay)} when done' : peso(job.earned)),
        ],
        if (job.result != null) _row('Result', job.result!),
        if (job.failedReason != null) _row('Failed reason', job.failedReason!),
        for (final item in job.items) _row('Item', '${item.quantity} × ${item.name}'),
        const Divider(height: kSpace20),
        for (final e in times.entries)
          if (job.times[e.value] != null) _row(e.key, formatTime(job.times[e.value])),
        if (job.podPhotoUrl != null) ...[
          const SizedBox(height: kSpace8),
          ClipRRect(
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Image.network(job.podPhotoUrl!, height: 160, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ],
      ]),
    );
  }

  Widget _actions(RiderJob job) {
    if (job.canConfirmPickup) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _pickupForm(job),
        _declineButton(job),
      ]);
    }
    if (job.canStartDelivery) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _primary('Start delivery (Out for Delivery)', Icons.local_shipping_outlined,
            () => _act((cp) => cp.startDelivery(job.id), 'Parcel is out for delivery.')),
        _declineButton(job),
      ]);
    }
    if (job.canFinishDelivery) return _deliveryForm(job);
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(color: kBrand50, borderRadius: BorderRadius.circular(kRadiusLg)),
      child: Text(
        job.isActive
            ? (job.isPickup ? 'Waiting for the next step.' : 'Waiting at the hub for this parcel.')
            : 'This job is finished: ${job.result ?? job.status}.',
        style: kBodyMd.copyWith(color: kBrand700),
      ),
    );
  }

  Widget _pickupForm(RiderJob job) => Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Confirm pickup', style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: kSpace4),
          Text('Scan the barcode on the waybill, or type the tracking number printed on it.',
              style: kBodySm.copyWith(color: kTextSecondary)),
          const SizedBox(height: kSpace10),
          _primary('Scan waybill', Icons.qr_code_scanner, () => _scanWaybill(job)),
          const SizedBox(height: kSpace10),
          TextField(
            key: const Key('trackingField'),
            controller: _tracking,
            focusNode: _trackingFocus,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Tracking number', hintText: 'TRK-0000000', border: OutlineInputBorder()),
          ),
          const SizedBox(height: kSpace10),
          OutlinedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Confirm pickup'),
            onPressed: _busy ? null : () {
              if (_tracking.text.trim().isEmpty) {
                showResult(context, false, '', 'Type the tracking number on the waybill.');
                return;
              }
              _act((cp) => cp.confirmPickup(job.id, _tracking.text), 'Parcel picked up.');
            },
          ),
        ]),
      );

  /// A delivery that could not be sent: kept on the phone and sent when the connection is back (RID-DLV-009).
  Widget _pendingBanner(PendingDelivery saved) => Container(
        key: const Key('pendingBanner'),
        margin: const EdgeInsets.only(bottom: kSpace12),
        padding: const EdgeInsets.all(kSpace12),
        decoration: BoxDecoration(
          color: saved.error == null ? const Color(0xFFFEF9C3) : kStatusFailedBg,
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(saved.error == null ? Icons.cloud_off_outlined : Icons.error_outline,
                size: 18, color: saved.error == null ? const Color(0xFF854D0E) : kStatusFailedFg),
            const SizedBox(width: kSpace8),
            Expanded(
              child: Text(
                saved.error == null
                    ? 'Not sent yet. This delivery is saved on this phone with the photo, code and amount, '
                        'and will be sent when you are back online.'
                    : 'The saved delivery was refused: ${saved.error} Correct it and tap Mark as Delivered again.',
                style: kBodySm.copyWith(color: saved.error == null ? const Color(0xFF854D0E) : kStatusFailedFg),
              ),
            ),
          ]),
          if (saved.error == null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cp.syncing ? null : _cp.syncPending,
                child: Text(_cp.syncing ? 'Sending…' : 'Retry now'),
              ),
            ),
        ]),
      );

  Widget _deliveryForm(RiderJob job) => Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_cp.pendingFor(job.id) case final saved?) _pendingBanner(saved),
          Text('Proof of delivery', style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: kSpace10),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(kRadiusMd),
              child: Image.file(_photo!, height: 160, fit: BoxFit.cover),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_photo == null ? 'Take photo' : 'Retake photo'),
            onPressed: _busy ? null : _takePhoto,
          ),
          const SizedBox(height: kSpace10),
          if (job.isReturn)
            Text(
              'Return trip: the seller receives the parcel, so there is no delivery code '
              'and nothing to collect. Take the photo and hand it over.',
              style: kBodySm.copyWith(color: kTextSecondary),
            )
          else ...[
            TextField(
              key: const Key('otpField'),
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                  labelText: 'Delivery code from the buyer', counterText: '', border: OutlineInputBorder()),
            ),
            if (job.collectsCod) ...[
              const SizedBox(height: kSpace10),
              TextField(
                key: const Key('codField'),
                controller: _cod,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                decoration: InputDecoration(
                  labelText: 'COD collected (${peso(job.codAmount)})',
                  helperText: 'Must match the order total exactly.',
                  prefixText: '₱',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
          const SizedBox(height: kSpace12),
          _primary(job.isReturn ? 'Mark as Returned' : 'Mark as Delivered', Icons.check_circle_outline, () {
            final problem = _photo == null
                ? 'Take a proof-of-delivery photo.'
                : !job.isReturn && _otp.text.length != 6
                    ? 'Enter the 6-digit delivery code from the buyer.'
                    : job.collectsCod
                        ? DeliveryRules.codProblem(expected: job.codAmount, entered: _cod.text)
                        : null;
            if (problem != null) {
              showResult(context, false, '', problem);
              return;
            }
            _act(
                (cp) => cp.deliver(job,
                    photo: _photo!,
                    otp: job.isReturn ? '' : _otp.text,
                    codAmount: job.collectsCod ? _cod.text.trim() : null),
                job.isReturn ? 'Returned to the seller.' : 'Parcel delivered.');
          }),
          const SizedBox(height: kSpace8),
          OutlinedButton(
            onPressed: _busy ? null : () => _chooseFailReason(job),
            style: OutlinedButton.styleFrom(foregroundColor: kActionDestructive, side: const BorderSide(color: kActionDestructive)),
            child: const Text('Mark as Failed'),
          ),
        ]),
      );

  Widget _primary(String label, IconData icon, VoidCallback onPressed) => ElevatedButton.icon(
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 18),
        label: Text(label),
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrand600, foregroundColor: Colors.white, elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: kSpace6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: kBodySm.copyWith(color: kTextMuted))),
          Expanded(child: Text(value, style: kBodySm.copyWith(color: kTextPrimary))),
        ]),
      );
}
