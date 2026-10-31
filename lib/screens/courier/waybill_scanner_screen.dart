import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import 'rider_job_widgets.dart';

/// Scans the barcode on a waybill (Rider Modules RID-PICK-002, 005, 006, 007).
///
/// Opened from a pickup job it returns the tracking number it read. Opened from the
/// Scan tab ([confirmPickups]) it confirms the pickup of the matching job itself and
/// shows the result before the next scan. The tracking number can always be typed instead.
class WaybillScannerScreen extends StatefulWidget {
  final bool confirmPickups;

  /// Builds the camera view and calls the callback with each code read. Tests replace it.
  final Widget Function(BuildContext context, void Function(String code) onCode)? cameraBuilder;

  const WaybillScannerScreen({super.key, this.confirmPickups = false, this.cameraBuilder});

  @override
  State<WaybillScannerScreen> createState() => _WaybillScannerScreenState();
}

class _WaybillScannerScreenState extends State<WaybillScannerScreen> {
  MobileScannerController? _controller;
  final _typed = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameraBuilder == null) {
      _controller = MobileScannerController(
        formats: const [BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _typed.dispose();
    super.dispose();
  }

  /// A code from the camera; ignored while the last one is being handled or its result is shown.
  void _onScanned(String raw) {
    if (_busy || _done || _result != null) return;
    _submit(raw);
  }

  Future<void> _submit(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    if (!widget.confirmPickups) {
      _done = true;
      Navigator.pop(context, code);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _result = null; });
    final cp = context.read<CourierProvider>();
    final job = await cp.pickupByScan(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultOk = job != null;
      _result = job != null
          ? 'Picked up ${job.trackingNumber}. You earned ${peso(job.earned)}.'
          : (cp.error ?? 'The pickup could not be confirmed.');
    });
  }

  void _scanNext() => setState(() { _result = null; _typed.clear(); });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kSurfaceRaised,
        appBar: const BhAppBar(title: 'Scan Waybill'),
        body: Column(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              widget.cameraBuilder?.call(context, _onScanned) ??
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      for (final b in capture.barcodes) {
                        final value = b.rawValue;
                        if (value != null && value.trim().isNotEmpty) return _onScanned(value);
                      }
                    },
                    errorBuilder: (context, error) => CameraUnavailable(
                        permissionDenied: error.errorCode == MobileScannerErrorCode.permissionDenied),
                  ),
              if (_busy) const ColoredBox(color: Color(0x88000000), child: Center(child: CircularProgressIndicator(color: Colors.white))),
              if (_result != null) _resultCard(),
            ]),
          ),
          _typePanel(),
        ]),
      );

  Widget _resultCard() => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const Key('scanResult'),
          margin: const EdgeInsets.all(kSpace16),
          padding: const EdgeInsets.all(kSpace16),
          decoration: BoxDecoration(
            color: _resultOk ? kBrand50 : kStatusFailedBg,
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(_resultOk ? Icons.check_circle : Icons.error_outline, color: _resultOk ? kBrand700 : kStatusFailedFg),
              const SizedBox(width: kSpace8),
              Expanded(child: Text(_result!, style: kBodyMd.copyWith(color: _resultOk ? kBrand700 : kStatusFailedFg))),
            ]),
            const SizedBox(height: kSpace10),
            ElevatedButton(onPressed: _scanNext, child: const Text('Scan next')),
          ]),
        ),
      );

  Widget _typePanel() => SafeArea(
        top: false,
        child: Container(
          color: kSurfaceBase,
          padding: const EdgeInsets.all(kSpace16),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const Key('scanTypedField'),
                controller: _typed,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: _busy ? null : _submit,
                decoration: const InputDecoration(
                    labelText: 'Or type the tracking number', hintText: 'TRK-0000000', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: kSpace8),
            ElevatedButton(
              onPressed: _busy ? null : () => _submit(_typed.text),
              child: Text(widget.confirmPickups ? 'Confirm' : 'Use'),
            ),
          ]),
        ),
      );
}

/// Shown instead of the camera when it cannot be used, e.g. camera access is set to
/// Don't Allow (RID-PICK-006). Typing the tracking number below still works.
class CameraUnavailable extends StatelessWidget {
  final bool permissionDenied;
  const CameraUnavailable({super.key, required this.permissionDenied});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: kSurfaceRaised,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpace24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography_outlined, size: 48, color: kTextMuted),
              const SizedBox(height: kSpace12),
              Text(
                permissionDenied ? 'Camera access is needed to scan the waybill.' : 'The camera could not be started.',
                textAlign: TextAlign.center,
                style: kHeadingSm.copyWith(color: kTextPrimary),
              ),
              const SizedBox(height: kSpace8),
              Text(
                permissionDenied
                    ? 'Allow camera access for TaptapGo in Settings, or type the tracking number below.'
                    : 'Type the tracking number below instead.',
                textAlign: TextAlign.center,
                style: kBodySm.copyWith(color: kTextSecondary),
              ),
              if (permissionDenied) ...[
                const SizedBox(height: kSpace12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Open Settings'),
                  // Opens this app's page in the phone's Settings
                  onPressed: Geolocator.openAppSettings,
                ),
              ],
            ]),
          ),
        ),
      );
}
