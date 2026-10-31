import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/courier_provider.dart';
import 'rider_job_widgets.dart';

/// Rider, vehicle and document details with editing (Rider Modules R1).
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

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rider and Vehicle', style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: kSpace10),
          if (p['needs_reverification'] == true) ...[
            Container(
              padding: const EdgeInsets.all(kSpace10),
              decoration: BoxDecoration(color: kStatusPendingBg, borderRadius: BorderRadius.circular(kRadiusMd)),
              child: Text('Changes saved. Your logistics company will re-verify them.',
                  style: kBodySm.copyWith(color: kStatusPendingFg)),
            ),
            const SizedBox(height: kSpace10),
          ],
          _row('Company', p['logistics_company'] ?? '—'),
          _row('Account', p['status'] == 'approved' ? 'Active' : (p['status'] ?? '—')),
          _row('License no.', p['driver_license_number'] ?? '—'),
          _row('License expiry', _usDate(p['license_expiry_date'] as String?)),
          _row('Vehicle', _cap(p['vehicle_type'] as String?)),
          _row('Plate number', p['plate_number'] ?? '—'),
          const SizedBox(height: kSpace8),
          Wrap(spacing: kSpace8, runSpacing: kSpace8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.two_wheeler_outlined, size: 16),
              label: const Text('Edit vehicle'),
              onPressed: () => _editVehicle(context, p),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.badge_outlined, size: 16),
              label: const Text('Update license'),
              onPressed: () => _editLicense(context, p),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: kSpace12),
      Container(
        padding: const EdgeInsets.all(kSpace16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Documents', style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: kSpace8),
          _document(context, "Driver's license", docs['driver_license']),
          _document(context, 'Vehicle OR/CR', docs['or_cr']),
        ]),
      ),
    ]);
  }

  Widget _document(BuildContext context, String label, dynamic doc) {
    final d = (doc as Map?)?.cast<String, dynamic>();
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Row(children: [
        const Icon(Icons.description_outlined, size: 18, color: kBrand600),
        const SizedBox(width: kSpace8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kLabelMd.copyWith(color: kTextPrimary)),
            Text(d?['name'] ?? 'Not uploaded', style: kBodySm.copyWith(color: kTextMuted), overflow: TextOverflow.ellipsis),
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
    final plate = TextEditingController(text: p['plate_number'] as String? ?? '');
    File? orCr;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Edit vehicle'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              key: const Key('plateField'),
              controller: plate,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Plate number'),
            ),
            const SizedBox(height: kSpace12),
            DocumentPicker(label: 'New OR/CR (optional)', file: orCr, onPicked: (f) => setDialog(() => orCr = f)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (save != true || !context.mounted) return;
    final newPlate = plate.text.trim().toUpperCase();
    final ok = await cp.updateVehicle(
      plateNumber: newPlate.isEmpty || newPlate == p['plate_number'] ? null : newPlate,
      orCr: orCr,
    );
    if (context.mounted) showResult(context, ok, 'Vehicle details saved. Your logistics company will re-verify them.', cp.error);
  }

  Future<void> _editLicense(BuildContext context, Map<String, dynamic> p) async {
    DateTime? expiry = DateTime.tryParse(p['license_expiry_date'] as String? ?? '');
    File? document;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Update license'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 16),
              label: Text('Expiry: ${expiry == null ? 'choose a date' : _usDate(expiry!.toIso8601String())}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: expiry ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
                );
                if (picked != null) setDialog(() => expiry = picked);
              },
            ),
            const SizedBox(height: kSpace12),
            DocumentPicker(label: "New driver's license (optional)", file: document, onPicked: (f) => setDialog(() => document = f)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (save != true || !context.mounted) return;
    final ok = await cp.updateLicense(expiry: expiry, document: document);
    if (context.mounted) showResult(context, ok, 'License details saved.', cp.error);
  }

  static String _usDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _cap(String? s) => s == null || s.isEmpty ? '—' : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: kSpace6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: kBodySm.copyWith(color: kTextMuted))),
          Expanded(child: Text(value, style: kLabelMd.copyWith(color: kTextPrimary))),
        ]),
      );
}

/// Take Photo (camera) or Choose File (gallery / Files app, JPG, PNG or PDF), with a preview (M7).
class DocumentPicker extends StatelessWidget {
  final String label;
  final File? file;
  final ValueChanged<File> onPicked;
  const DocumentPicker({super.key, required this.label, required this.file, required this.onPicked});

  Future<void> _camera() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
    if (shot != null) onPicked(File(shot.path));
  }

  Future<void> _files() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
    final path = picked?.files.single.path;
    if (path != null) onPicked(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final f = file;
    final isImage = f != null && RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(f.path);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: kLabelMd.copyWith(color: kTextSecondary)),
      const SizedBox(height: kSpace6),
      if (f != null) ...[
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Image.file(f, height: 110, fit: BoxFit.cover),
          )
        else
          Row(children: [
            const Icon(Icons.picture_as_pdf_outlined, color: kBrand600),
            const SizedBox(width: kSpace6),
            Expanded(child: Text(f.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis)),
          ]),
        const SizedBox(height: kSpace6),
      ],
      Row(children: [
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.photo_camera_outlined, size: 16), label: const Text('Take photo'), onPressed: _camera)),
        const SizedBox(width: kSpace8),
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.folder_open_outlined, size: 16), label: const Text('Choose file'), onPressed: _files)),
      ]),
    ]);
  }
}
