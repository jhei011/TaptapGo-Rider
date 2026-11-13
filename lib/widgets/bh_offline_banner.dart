import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Wraps [child] with an animated amber offline banner.
///
/// The banner slides in from the top when the device has no network
/// connectivity and slides out when connectivity is restored.
class BhOfflineBanner extends StatefulWidget {
  const BhOfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<BhOfflineBanner> createState() => _BhOfflineBannerState();
}

class _BhOfflineBannerState extends State<BhOfflineBanner> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOffline = results.contains(ConnectivityResult.none) &&
          results.length == 1;
    });
  }

  void _onChanged(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _isOffline = results.contains(ConnectivityResult.none) &&
          results.length == 1;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Takes no space while online, and opens smoothly when the connection drops
    return Column(
      children: [
        AnimatedContainer(
          height: _isOffline ? 36 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: Semantics(
            label: 'Offline warning: data may be outdated',
            child: Container(
              width: double.infinity,
              height: 36,
              // TaptapShop's warning amber
              color: const Color(0xFFB8802C),
              alignment: Alignment.center,
              child: const Text(
                "⚡ You're offline — data may be outdated",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
