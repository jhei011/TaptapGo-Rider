import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/courier_provider.dart';
import '../../widgets/bh_app_bar.dart';
import 'rider_job_widgets.dart';

/// Scans the barcode on a waybill (RID-PICK-002, 005, 006, 007).
///
/// Opened from a pickup job → returns the tracking number it read.
/// Opened from the Scan tab (confirmPickups) → confirms the pickup and
/// shows the result before the next scan.
/// The tracking number can always be typed instead.
class WaybillScannerScreen extends StatefulWidget {
  final bool confirmPickups;

  /// Test stub — replaces the real camera view.
  final Widget Function(BuildContext context, void Function(String code) onCode)?
      cameraBuilder;

  const WaybillScannerScreen(
      {super.key, this.confirmPickups = false, this.cameraBuilder});

  @override
  State<WaybillScannerScreen> createState() => _WaybillScannerScreenState();
}

class _WaybillScannerScreenState extends State<WaybillScannerScreen> {
  // Controller is only created when the real camera is used (not in tests).
  // autoStart = true (default) so the widget starts the camera itself.
  MobileScannerController? _controller;

  final _typed = TextEditingController();
  bool _busy   = false;
  bool _done   = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameraBuilder == null) {
      _controller = MobileScannerController(
        formats: const [
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.qrCode,
        ],
        detectionSpeed: DetectionSpeed.noDuplicates,
        // autoStart defaults to true — the MobileScanner widget starts it.
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _typed.dispose();
    super.dispose();
  }

  // ── barcode handling ──────────────────────────────────────────────────────

  /// Called by the MobileScanner widget via onDetect.
  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        _onScanned(v);
        return;
      }
    }
  }

  /// Ignore codes while busy, finished, or a result is already on screen.
  void _onScanned(String raw) {
    if (_busy || _done || _result != null) return;
    _submit(raw);
  }

  Future<void> _submit(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;

    // When not confirming pickups just hand the code back to the caller.
    if (!widget.confirmPickups) {
      _done = true;
      if (mounted) Navigator.pop(context, code);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _result = null; });

    final cp  = context.read<CourierProvider>();
    final job = await cp.pickupByScan(code);

    if (!mounted) return;
    setState(() {
      _busy      = false;
      _resultOk  = job != null;
      _result    = job != null
          ? 'Picked up ${job.trackingNumber}. You earned ${peso(job.earned)}.'
          : (cp.error ?? 'The pickup could not be confirmed.');
    });
  }

  void _scanNext() => setState(() { _result = null; _typed.clear(); });

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kSurfaceRaised,
        appBar: const BhAppBar(title: 'Scan Waybill'),
        body: Column(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              _cameraView(),
              if (_busy)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
              if (_result != null) _resultCard(),
            ]),
          ),
          _typePanel(),
        ]),
      );

  Widget _cameraView() {
    // Test stub
    if (widget.cameraBuilder != null) {
      return widget.cameraBuilder!(context, _onScanned);
    }

    return MobileScanner(
      controller: _controller,
      // v7 correct pattern: use onDetect callback on the widget.
      // The controller's barcodes stream must not be subscribed to manually
      // when the widget also uses onDetect — that causes a double-listen crash.
      onDetect: _onDetect,
      errorBuilder: (context, error) => CameraUnavailable(
        permissionDenied:
            error.errorCode == MobileScannerErrorCode.permissionDenied,
      ),
    );
  }

  // ── result card ───────────────────────────────────────────────────────────

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(
                  _resultOk ? Icons.check_circle : Icons.error_outline,
                  color: _resultOk ? kBrand700 : kStatusFailedFg,
                ),
                const SizedBox(width: kSpace8),
                Expanded(
                  child: Text(
                    _result!,
                    style: kBodyMd.copyWith(
                        color: _resultOk ? kBrand700 : kStatusFailedFg),
                  ),
                ),
              ]),
              const SizedBox(height: kSpace10),
              ElevatedButton(
                  onPressed: _scanNext, child: const Text('Scan next')),
            ],
          ),
        ),
      );

  // ── type-in panel ─────────────────────────────────────────────────────────

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
                  labelText: 'Or type the tracking number',
                  hintText: 'TRK-0000000',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
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

// ── CameraUnavailable ─────────────────────────────────────────────────────────
/// Shown when the camera cannot start — permission denied (RID-PICK-006) or
/// hardware error. The type-in panel below still works.
class CameraUnavailable extends StatelessWidget {
  final bool permissionDenied;
  const CameraUnavailable({super.key, required this.permissionDenied});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: kSurfaceRaised,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpace24),
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography_outlined,
                  size: 48, color: kTextMuted),
              const SizedBox(height: kSpace12),
              Text(
                permissionDenied
                    ? 'Camera access is needed to scan the waybill.'
                    : 'The camera could not be started.',
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
                  onPressed: Geolocator.openAppSettings,
                ),
              ],
            ]),
          ),
        ),
      );
}
