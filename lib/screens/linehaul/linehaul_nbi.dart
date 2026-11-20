import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/api.dart';
import '../../core/theme/app_tokens.dart';
import '../courier/rider_profile_widgets.dart' show DocumentPicker;

/// The linehaul courier's NBI clearance on Home. Like riders: no trips until it is on file
/// and the logistics company has verified it (GET /linehaul/home: nbi_missing, nbi_unverified).
class LinehaulNbiCard extends StatelessWidget {
  final Map<String, dynamic> home;

  /// Called after a new NBI is saved, so Home reloads.
  final VoidCallback onSaved;
  const LinehaulNbiCard({super.key, required this.home, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final missing = home['nbi_missing'] == true;
    final waiting = home['nbi_unverified'] == true;
    if (!missing && !waiting) return const SizedBox.shrink();

    final fg = missing ? kStatusFailedFg : kStatusPendingFg;
    final bg = missing ? kStatusFailedBg : kStatusPendingBg;
    return Container(
      key: Key(missing ? 'linehaulNbiMissing' : 'linehaulNbiWaiting'),
      padding: const EdgeInsets.all(kSpace12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(missing ? Icons.verified_user_outlined : Icons.hourglass_top_rounded, color: fg, size: 20),
          const SizedBox(width: kSpace8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(missing ? 'NBI clearance needed' : 'NBI clearance waiting for verification',
                  style: kLabelMd.copyWith(color: fg)),
              const SizedBox(height: 2),
              Text(
                missing
                    ? 'Upload your NBI clearance. Your logistics company can give you trips once they verify it.'
                    : 'Your logistics company is checking it. You can be given trips once it is verified.',
                style: kBodySm.copyWith(color: fg),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: kSpace8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('linehaulNbiUpload'),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(missing ? 'Upload NBI clearance' : 'Upload a new one'),
            style: TextButton.styleFrom(foregroundColor: fg),
            onPressed: () async {
              final saved = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const LinehaulNbiSheet(),
              );
              if (saved != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved)));
                onSaved();
              }
            },
          ),
        ),
      ]),
    );
  }
}

/// Upload the NBI clearance (POST /linehaul/nbi). Pops with the server's message when saved.
class LinehaulNbiSheet extends StatefulWidget {
  const LinehaulNbiSheet({super.key});

  @override
  State<LinehaulNbiSheet> createState() => _LinehaulNbiSheetState();
}

class _LinehaulNbiSheetState extends State<LinehaulNbiSheet> {
  File? _nbi;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final d = await Api.postMultipart('/linehaul/nbi', fields: const {}, files: {'nbi_clearance': _nbi!})
          as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.pop(context, d['message'] as String? ?? 'NBI clearance saved.');
    } on ApiError catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Could not save. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(kSpace16, kSpace16, kSpace16, kSpace16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('NBI clearance', style: kHeadingSm.copyWith(color: kTextPrimary)),
          const SizedBox(height: 4),
          Text('Upload a photo or PDF of your valid NBI clearance. Your logistics company checks it before giving you trips.',
              style: kBodySm.copyWith(color: kTextSecondary)),
          const SizedBox(height: kSpace12),
          DocumentPicker(
            label: 'Upload your NBI clearance',
            file: _nbi,
            onPicked: (f) => setState(() { _nbi = f; _error = null; }),
            onRemove: () => setState(() => _nbi = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: kSpace8),
            Text(_error!, key: const Key('linehaulNbiError'), style: kBodySm.copyWith(color: kActionDestructive)),
          ],
          const SizedBox(height: kSpace12),
          ElevatedButton(
            key: const Key('linehaulNbiSave'),
            onPressed: !_saving && _nbi != null ? _save : null,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ]),
      );
}
