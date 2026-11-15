import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/attachment_rules.dart';
import '../../core/utils/delivery_rules.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_primary_button.dart';
import '../../widgets/tap.dart';
import '../../widgets/teal_pattern.dart';
import 'rider_job_widgets.dart';

/// Rider, vehicle and document details with editing (Rider Modules R1).
///
/// The vehicle shows its plate as a plate, the license shows whether it is still valid, and each
/// opens a bottom sheet to edit it: a live preview, the field, an upload area for the new document,
/// and Save, which stays disabled until something changed. A failed save keeps the sheet open
/// with the server's message.
class RiderVehicleSection extends StatelessWidget {
  final CourierProvider cp;
  const RiderVehicleSection({super.key, required this.cp});

  @override
  Widget build(BuildContext context) {
    final p = cp.profile;
    if (p == null) {
      return Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Text('Loading rider details…', style: kBodySm.copyWith(color: kTextMuted)),
      );
    }
    final docs = (p['documents'] as Map?)?.cast<String, dynamic>() ?? {};
    final approved = p['status'] == 'approved';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Header: title, company, account status ──
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rider and Vehicle', style: kHeadingSm.copyWith(color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.apartment_rounded, size: 14, color: kTextMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(p['logistics_company'] as String? ?? '—',
                          overflow: TextOverflow.ellipsis, style: kBodySm.copyWith(color: kTextSecondary)),
                    ),
                  ]),
                ]),
              ),
              _Pill(
                text: approved ? 'Active' : _cap(p['status'] as String?),
                bg: approved ? kStatusDeliveredBg : kStatusPendingBg,
                fg: approved ? kStatusDeliveredFg : kStatusPendingFg,
                dot: true,
              ),
            ]),
          ),
          if (p['needs_reverification'] == true)
            Container(
              margin: const EdgeInsets.fromLTRB(kSpace16, 0, kSpace16, kSpace12),
              padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace10),
              decoration: BoxDecoration(color: kStatusPendingBg, borderRadius: BorderRadius.circular(kRadiusMd)),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded, size: 16, color: kStatusPendingFg),
                const SizedBox(width: kSpace8),
                Expanded(
                  child: Text('Changes saved. Your logistics company will re-verify them.',
                      style: kBodySm.copyWith(color: kStatusPendingFg)),
                ),
              ]),
            ),
          Divider(height: 1, color: kBorderDefault),

          // ── Vehicle ──
          _ItemTile(
            icon: _vehicleIcon(p['vehicle_type'] as String?),
            title: 'Vehicle',
            action: 'Edit vehicle',
            actionIcon: Icons.edit_outlined,
            onAction: () => _editVehicle(context, p),
            body: Row(children: [
              Expanded(child: Text(_cap(p['vehicle_type'] as String?), style: kLabelMd.copyWith(color: kTextPrimary))),
              PlateChip(plate: p['plate_number'] as String? ?? '—'),
            ]),
          ),
          Divider(height: 1, indent: kSpace16, endIndent: kSpace16, color: kBorderDefault),

          // ── Driver's license ──
          _ItemTile(
            icon: Icons.badge_outlined,
            title: "Driver's license",
            action: 'Update license',
            actionIcon: Icons.upload_file_outlined,
            onAction: () => _editLicense(context, p),
            body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['driver_license_number'] as String? ?? '—',
                  style: kMonoMd.copyWith(color: kTextPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: kSpace6),
              LicenseValidity(expiry: DateTime.tryParse(p['license_expiry_date'] as String? ?? '')),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: kSpace12),

      // ── Documents on file ──
      Container(
        padding: const EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace8),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Documents', style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: kSpace10),
          _document(context, "Driver's license", docs['driver_license']),
          _document(context, 'Vehicle OR/CR', docs['or_cr']),
        ]),
      ),
    ]);
  }

  Widget _document(BuildContext context, String label, dynamic doc) {
    final d = (doc as Map?)?.cast<String, dynamic>();
    final name = d?['name'] as String?;
    final isPdf = name?.toLowerCase().endsWith('.pdf') ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace8),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: kBrand50, borderRadius: BorderRadius.circular(kRadiusMd)),
          child: Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 19, color: _accent),
        ),
        const SizedBox(width: kSpace12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kLabelMd.copyWith(color: kTextPrimary)),
            Text(name ?? 'Not uploaded', style: kBodySm.copyWith(color: kTextMuted), overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (d?['url'] != null)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(d!['url'] as String), mode: LaunchMode.externalApplication),
            child: const Text('Open'),
          ),
      ]),
    );
  }

  Future<void> _editVehicle(BuildContext context, Map<String, dynamic> p) async {
    final saved = await _showSheet(context, _EditVehicleSheet(cp: cp, profile: p));
    if (saved == true && context.mounted) {
      showResult(context, true, 'Vehicle details saved. Your logistics company will re-verify them.', null);
    }
  }

  Future<void> _editLicense(BuildContext context, Map<String, dynamic> p) async {
    final saved = await _showSheet(context, _EditLicenseSheet(cp: cp, profile: p));
    if (saved == true && context.mounted) showResult(context, true, 'License details saved.', null);
  }
}

Future<bool?> _showSheet(BuildContext context, Widget sheet) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );

Color get _accent => AppPalette.dark ? kTealOnDark : kBrand700;

String _cap(String? s) => s == null || s.isEmpty ? '—' : '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}';

String _usDate(DateTime? d) => d == null
    ? '—'
    : '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

IconData _vehicleIcon(String? type) => switch (type) {
      'motorcycle' || 'scooter' => Icons.two_wheeler_rounded,
      'bicycle' => Icons.pedal_bike_rounded,
      'tricycle' => Icons.electric_rickshaw_rounded,
      _ => Icons.local_shipping_outlined,
    };

// ── Building blocks ─────────────────────────────────────────────────────────────

/// One editable item in the card: icon, title, its details, and the edit action.
class _ItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String action;
  final IconData actionIcon;
  final VoidCallback onAction;
  final Widget body;
  const _ItemTile({required this.icon, required this.title, required this.action, required this.actionIcon,
      required this.onAction, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(kSpace16, kSpace14, kSpace16, kSpace14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kBrand50,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: AppPalette.dark ? kBorderDefault : kBrand100),
            ),
            child: Icon(icon, size: 21, color: _accent),
          ),
          const SizedBox(width: kSpace12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Text(title.toUpperCase(),
                      style: kLabelSm.copyWith(color: kTextMuted, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
                ),
                Tap(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(actionIcon, size: 15, color: _accent),
                      const SizedBox(width: 4),
                      Text(action, style: kLabelMd.copyWith(color: _accent, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: kSpace6),
              body,
            ]),
          ),
        ]),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final bool dot;
  final IconData? icon;
  const _Pill({required this.text, required this.bg, required this.fg, this.dot = false, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

/// A plate number drawn as a plate: white face, dark rim, spaced bold characters.
class PlateChip extends StatelessWidget {
  final String plate;
  final bool large;
  const PlateChip({super.key, required this.plate, this.large = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(large ? 18 : 10, large ? 6 : 3, large ? 18 : 10, large ? 8 : 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCF9),
          borderRadius: BorderRadius.circular(large ? 8 : 6),
          border: Border.all(color: const Color(0xFF1F2937), width: large ? 2 : 1.5),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: large ? 46 : 26,
            height: large ? 3 : 2,
            margin: EdgeInsets.only(bottom: large ? 5 : 2),
            decoration: BoxDecoration(color: kBrand600, borderRadius: BorderRadius.circular(2)),
          ),
          Text(plate,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: large ? 26 : 14,
                fontWeight: FontWeight.w800,
                letterSpacing: large ? 3 : 1.6,
                color: const Color(0xFF111827),
                height: 1.1,
              )),
        ]),
      );
}

/// "Valid until 03/22/2030" (green), "Expires in 12 days" (amber, within 60 days) or "Expired" (red).
class LicenseValidity extends StatelessWidget {
  final DateTime? expiry;
  final bool onDark;
  const LicenseValidity({super.key, required this.expiry, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final e = expiry;
    if (e == null) {
      return _Pill(text: 'No expiry date', bg: kStatusPendingBg, fg: kStatusPendingFg, icon: Icons.help_outline);
    }
    final now = DateTime.now();
    final days = DateTime(e.year, e.month, e.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final (label, bg, fg, icon) = days < 0
        ? ('Expired', kStatusFailedBg, kStatusFailedFg, Icons.error_outline)
        : days <= 60
            ? (days == 0 ? 'Expires today' : 'Expires in $days day${days == 1 ? '' : 's'}', kStatusPendingBg, kStatusPendingFg,
                Icons.schedule_rounded)
            : ('Valid', kStatusDeliveredBg, kStatusDeliveredFg, Icons.verified_outlined);
    return Wrap(spacing: kSpace8, runSpacing: kSpace4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _Pill(text: label, bg: bg, fg: fg, icon: icon),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(days < 0 ? 'Expired on ' : 'Until ',
            style: kBodySm.copyWith(color: onDark ? Colors.white70 : kTextMuted)),
        Text(_usDate(e), style: kLabelMd.copyWith(color: onDark ? Colors.white : kTextPrimary)),
      ]),
    ]);
  }
}

// ── Sheets ──────────────────────────────────────────────────────────────────────

/// Rounded sheet with a grab handle, a header (icon, title, subtitle, close), a scrolling body,
/// and the buttons pinned at the bottom above the keyboard.
class _SheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget footer;
  const _SheetFrame({required this.icon, required this.title, required this.subtitle, required this.children,
      required this.footer});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: kSurfaceBase,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(color: kBorderStrong, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace20, kSpace8, kSpace8, kSpace12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: kPrimaryGradient, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: kHeadingLg.copyWith(color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: kBodySm.copyWith(color: kTextSecondary, height: 1.35)),
                ]),
              ),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, color: kTextMuted),
                onPressed: () => Navigator.pop(context, false),
              ),
            ]),
          ),
          Divider(height: 1, color: kBorderDefault),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kSpace20, kSpace16, kSpace20, kSpace16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(kSpace20, kSpace12, kSpace20, kSpace16),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              border: Border(top: BorderSide(color: kBorderDefault)),
            ),
            child: SafeArea(top: false, child: footer),
          ),
        ]),
      ),
    );
  }
}

/// Error line (if any) above Cancel / Save.
Widget _footer(BuildContext context,
    {required String saveLabel, required bool saving, required VoidCallback? onSave, String? error}) {
  return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (error != null) ...[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace10),
        decoration: BoxDecoration(color: kStatusFailedBg, borderRadius: BorderRadius.circular(kRadiusMd)),
        child: Row(children: [
          Icon(Icons.error_outline, size: 17, color: kStatusFailedFg),
          const SizedBox(width: kSpace8),
          Expanded(child: Text(error, style: kBodySm.copyWith(color: kStatusFailedFg))),
        ]),
      ),
      const SizedBox(height: kSpace12),
    ],
    Row(children: [
      Expanded(
        flex: 2,
        child: OutlinedButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: kTextPrimary,
            side: BorderSide(color: kBorderDefault),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
          ),
          child: const Text('Cancel'),
        ),
      ),
      const SizedBox(width: kSpace12),
      Expanded(
        flex: 3,
        child: BhPrimaryButton(label: saveLabel, loading: saving, onPressed: onSave, icon: Icons.check_rounded),
      ),
    ]),
  ]);
}

Widget _sectionLabel(String text, {String? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: kSpace8),
      child: Row(children: [
        Expanded(child: Text(text, style: kLabelMd.copyWith(color: kTextPrimary, fontWeight: FontWeight.w700))),
        if (trailing != null) Text(trailing, style: kBodySm.copyWith(color: kTextMuted)),
      ]),
    );

Widget _note(IconData icon, String text) => Container(
      padding: const EdgeInsets.all(kSpace12),
      decoration: BoxDecoration(
        color: kSurfaceSunken,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: _accent),
        const SizedBox(width: kSpace8),
        Expanded(child: Text(text, style: kBodySm.copyWith(color: kTextSecondary, height: 1.4))),
      ]),
    );

class _EditVehicleSheet extends StatefulWidget {
  final CourierProvider cp;
  final Map<String, dynamic> profile;
  const _EditVehicleSheet({required this.cp, required this.profile});

  @override
  State<_EditVehicleSheet> createState() => _EditVehicleSheetState();
}

class _EditVehicleSheetState extends State<_EditVehicleSheet> {
  late final String _current = widget.profile['plate_number'] as String? ?? '';
  late final _plate = TextEditingController(text: _current);
  File? _orCr;
  bool _saving = false;
  String? _error;

  String get _newPlate => _plate.text.replaceAll(' ', '').trim().toUpperCase();
  bool get _plateChanged => _newPlate.isNotEmpty && _newPlate != _current;
  bool get _canSave => !_saving && (_plateChanged || _orCr != null);

  @override
  void initState() {
    super.initState();
    _plate.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final ok = await widget.cp.updateVehicle(plateNumber: _plateChanged ? _newPlate : null, orCr: _orCr);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() { _saving = false; _error = widget.cp.error ?? 'Could not save. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.profile['vehicle_type'] as String?;
    return _SheetFrame(
      icon: _vehicleIcon(type),
      title: 'Edit vehicle',
      subtitle: 'Update your plate number or upload a newer OR/CR.',
      footer: _footer(context, saveLabel: 'Save changes', saving: _saving, onSave: _canSave ? _save : null, error: _error),
      children: [
        // Live preview of the plate
        Container(
          padding: const EdgeInsets.symmetric(vertical: kSpace20, horizontal: kSpace16),
          decoration: TealDecoration(BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.circular(kRadiusLg))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_vehicleIcon(type), size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(_cap(type).toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: kSpace12),
            PlateChip(plate: _newPlate.isEmpty ? '— — —' : _newPlate, large: true),
            const SizedBox(height: kSpace10),
            Text(_plateChanged ? 'New plate · was $_current' : 'Current plate',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: kSpace20),

        _sectionLabel('Plate number', trailing: '${_newPlate.length}/8'),
        TextField(
          key: const Key('plateField'),
          controller: _plate,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 8,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
            TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
          ],
          style: kBodyLg.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5, color: kTextPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. 123ABC',
            counterText: '',
            prefixIcon: Icon(Icons.pin_outlined),
            helperText: 'Letters and numbers, exactly as on your OR/CR.',
          ),
        ),
        const SizedBox(height: kSpace20),

        _sectionLabel('Official Receipt / Certificate of Registration', trailing: 'Optional'),
        DocumentPicker(
          label: 'Upload your latest OR/CR',
          file: _orCr,
          onPicked: (f) => setState(() { _orCr = f; _error = null; }),
          onRemove: () => setState(() => _orCr = null),
        ),
        const SizedBox(height: kSpace16),
        _note(Icons.verified_user_outlined,
            'Your logistics company re-verifies vehicle changes. You can keep working while they review.'),
      ],
    );
  }
}

class _EditLicenseSheet extends StatefulWidget {
  final CourierProvider cp;
  final Map<String, dynamic> profile;
  const _EditLicenseSheet({required this.cp, required this.profile});

  @override
  State<_EditLicenseSheet> createState() => _EditLicenseSheetState();
}

class _EditLicenseSheetState extends State<_EditLicenseSheet> {
  late final DateTime? _original = DateTime.tryParse(widget.profile['license_expiry_date'] as String? ?? '');
  late DateTime? _expiry = _original;
  File? _document;
  bool _saving = false;
  String? _error;

  // Today is still valid; yesterday or earlier is refused here as well as on the server
  String? get _dateProblem => DeliveryRules.licenseExpiryProblem(_expiry);
  bool get _changed => _document != null || (_expiry != null && _expiry != _original);
  bool get _canSave => !_saving && _changed && _dateProblem == null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 15)),
      helpText: 'License expiry date',
    );
    if (picked != null) setState(() { _expiry = picked; _error = null; });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final ok = await widget.cp.updateLicense(expiry: _expiry, document: _document);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() { _saving = false; _error = widget.cp.error ?? 'Could not save. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final problem = _expiry == _original ? null : _dateProblem;
    return _SheetFrame(
      icon: Icons.badge_outlined,
      title: 'Update license',
      subtitle: 'Renewed your license? Set the new expiry date and upload a photo of it.',
      footer: _footer(context, saveLabel: 'Save license', saving: _saving, onSave: _canSave ? _save : null, error: _error),
      children: [
        // The license as a card
        Container(
          padding: const EdgeInsets.all(kSpace16),
          decoration: TealDecoration(BoxDecoration(
            gradient: kHeroGradient,
            borderRadius: BorderRadius.circular(kRadiusLg),
            boxShadow: const [BoxShadow(color: Color(0x290E2A38), blurRadius: 14, offset: Offset(0, 6))],
          )),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text("DRIVER'S LICENSE",
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              const Spacer(),
              Container(
                width: 34,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF2D27A), Color(0xFFC9A54A)]),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ]),
            const SizedBox(height: kSpace14),
            Text(p['name'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: kSpace4),
            Text(p['driver_license_number'] as String? ?? '—',
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: kSpace14),
            LicenseValidity(expiry: _expiry, onDark: true),
          ]),
        ),
        const SizedBox(height: kSpace20),

        _sectionLabel('Expiry date'),
        Tap(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(kRadiusInput),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace14),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              borderRadius: BorderRadius.circular(kRadiusInput),
              border: Border.all(color: problem != null ? kStatusFailedFg : kInputBorder, width: problem != null ? 1.5 : 1),
            ),
            child: Row(children: [
              Icon(Icons.event_outlined, color: kTextMuted, size: 20),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Text(_expiry == null ? 'Choose a date' : _usDate(_expiry),
                    style: kBodyLg.copyWith(
                        color: _expiry == null ? kTextMuted : kTextPrimary, fontWeight: FontWeight.w600)),
              ),
              Text('Change', style: kLabelMd.copyWith(color: _accent, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: kSpace6, left: 2),
          child: Text(problem ?? 'Use the date printed on your license card.',
              style: kBodySm.copyWith(color: problem != null ? kStatusFailedFg : kTextMuted)),
        ),
        const SizedBox(height: kSpace20),

        _sectionLabel('Photo of your license', trailing: 'Optional'),
        DocumentPicker(
          label: 'Upload the front of your license',
          file: _document,
          onPicked: (f) => setState(() { _document = f; _error = null; }),
          onRemove: () => setState(() => _document = null),
        ),
      ],
    );
  }
}

/// Take Photo (camera) or Choose File (gallery / Files app, JPG, PNG or PDF), with a preview (M7).
/// Drawn as an upload area: a dashed box with the two choices, or the chosen file with Remove.
class DocumentPicker extends StatelessWidget {
  final String label;
  final File? file;
  final ValueChanged<File> onPicked;
  final VoidCallback? onRemove;
  const DocumentPicker({super.key, required this.label, required this.file, required this.onPicked, this.onRemove});

  Future<void> _camera(BuildContext context) async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
    if (shot == null || !context.mounted) return;
    await _accept(context, File(shot.path));
  }

  Future<void> _files(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) return;
    await _accept(context, File(path));
  }

  /// JPG, PNG or PDF, checked by the file's content, and at most 5 MB (A16, M7).
  Future<void> _accept(BuildContext context, File file) async {
    final problem = await AttachmentRules.validate(file);
    if (!context.mounted) return;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(problem), backgroundColor: kActionDestructive),
      );
      return;
    }
    onPicked(file);
  }

  @override
  Widget build(BuildContext context) {
    final f = file;
    if (f != null) return _chosen(context, f);

    return CustomPaint(
      foregroundPainter: _DashedBorder(color: AppPalette.dark ? kBorderStrong : kBrand200, radius: kRadiusLg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(kSpace16, kSpace20, kSpace16, kSpace16),
        decoration: BoxDecoration(
          color: AppPalette.dark ? kSurfaceSunken : kBrand50.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: kSurfaceBase, shape: BoxShape.circle, border: Border.all(color: kBorderDefault)),
            child: Icon(Icons.cloud_upload_outlined, color: _accent, size: 22),
          ),
          const SizedBox(height: kSpace10),
          Text(label, textAlign: TextAlign.center, style: kLabelMd.copyWith(color: kTextPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('JPG, PNG or PDF · up to 5 MB', style: kBodySm.copyWith(color: kTextMuted)),
          const SizedBox(height: kSpace14),
          Row(children: [
            Expanded(child: _choice(Icons.photo_camera_outlined, 'Take photo', () => _camera(context))),
            const SizedBox(width: kSpace8),
            Expanded(child: _choice(Icons.folder_open_outlined, 'Choose file', () => _files(context))),
          ]),
        ]),
      ),
    );
  }

  Widget _choice(IconData icon, String text, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          backgroundColor: kSurfaceBase,
          foregroundColor: _accent,
          side: BorderSide(color: kBorderDefault),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusButton)),
        ),
      );

  Widget _chosen(BuildContext context, File f) {
    final name = f.path.split(Platform.pathSeparator).last;
    final isImage = RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f.path);
    final kb = (f.existsSync() ? f.lengthSync() : 0) / 1024;
    return Container(
      padding: const EdgeInsets.all(kSpace10),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kStatusDeliveredFg.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: SizedBox(
            width: 64,
            height: 64,
            child: isImage
                ? Image.file(f, fit: BoxFit.cover)
                : ColoredBox(color: kBrand50, child: Icon(Icons.picture_as_pdf_outlined, color: _accent, size: 28)),
          ),
        ),
        const SizedBox(width: kSpace12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.check_circle_rounded, size: 15, color: kStatusDeliveredFg),
              const SizedBox(width: 4),
              Text('Ready to upload', style: kLabelSm.copyWith(color: kStatusDeliveredFg, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kLabelMd.copyWith(color: kTextPrimary)),
            Text(kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(0)} KB',
                style: kBodySm.copyWith(color: kTextMuted)),
          ]),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          TextButton(onPressed: () => _files(context), child: const Text('Replace')),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, color: kActionDestructive, size: 20),
              onPressed: onRemove,
            ),
        ]),
      ]),
    );
  }
}

/// Dashed rounded outline for the upload area (TaptapShop's _DashedBorder).
class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
