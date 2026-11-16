import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/push_service.dart';
import '../core/theme/app_tokens.dart';
import '../providers/auth_provider.dart';

/// Turns push notifications on for whoever is logged in, and shows the ones that arrive
/// while the app is open as a banner with a View button (Android only shows a
/// notification itself when the app is in the background or closed).
class PushWatcher extends StatefulWidget {
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;
  const PushWatcher({super.key, required this.messengerKey, required this.child});

  @override
  State<PushWatcher> createState() => _PushWatcherState();
}

class _PushWatcherState extends State<PushWatcher> {
  late final AuthProvider _auth;
  StreamSubscription<PushMessage>? _sub;
  int? _registeredFor;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_onAuthChanged);
    _sub = PushService.received.listen(_show);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final user = _auth.user;
    if (_auth.authenticated && user != null) {
      // Once per login (also after the app is reopened with a saved login)
      if (_registeredFor != user.id) {
        _registeredFor = user.id;
        PushService.register();
      }
    } else if (_auth.status == AuthStatus.unauthenticated) {
      _registeredFor = null;
      PushService.clear();
    }
  }

  void _show(PushMessage m) {
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: kBrand700,
        content: Row(children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              if (m.body.isNotEmpty)
                Text(m.body, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
            ]),
          ),
        ]),
        action: m.tap == null
            ? null
            : SnackBarAction(label: 'View', textColor: Colors.white, onPressed: () => PushService.pendingTap.value = m.tap),
      ));
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
