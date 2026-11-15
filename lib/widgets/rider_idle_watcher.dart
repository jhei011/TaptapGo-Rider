import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/services/rider_idle_policy.dart';
import '../providers/auth_provider.dart';

/// Runs the rider's 30-minute idle logout (see [RiderIdlePolicy]) for the signed-in
/// rider or linehaul courier: touches restart the 30 minutes, the app going to the
/// background pauses it, and coming back applies the rule. One policy (one timer) for
/// the whole app.
class RiderIdleWatcher extends StatefulWidget {
  final Widget child;

  /// Tests replace the server check and the timeout.
  final RiderIdlePolicy Function(AuthProvider auth)? policyFor;

  const RiderIdleWatcher({super.key, required this.child, this.policyFor});

  @override
  State<RiderIdleWatcher> createState() => _RiderIdleWatcherState();
}

class _RiderIdleWatcherState extends State<RiderIdleWatcher> with WidgetsBindingObserver {
  late final AuthProvider _auth;
  RiderIdlePolicy? _policy;
  String? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthProvider>();
    _auth.addListener(_sync);
    _sync();
  }

  /// Starts the policy for a signed-in rider or courier, stops it otherwise.
  void _sync() {
    final role = _auth.authenticated ? _auth.user?.role : null;
    final rider = role == 'courier' || role == 'linehaul';
    if (!rider) {
      _policy?.stop();
      _policy = null;
      _role = null;
      return;
    }
    if (_policy != null && _role == role) return;
    _policy?.stop();
    _role = role;
    _policy = (widget.policyFor ?? _defaultPolicy)(_auth)..start();
  }

  RiderIdlePolicy _defaultPolicy(AuthProvider auth) => RiderIdlePolicy(
        checkWork: auth.user?.role == 'linehaul' ? linehaulWorkCheck : riderWorkCheck,
        onIdleTimeout: auth.endIdleSession,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _policy?.resumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _policy?.paused();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_sync);
    _policy?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _policy?.activity(),
        child: widget.child,
      );
}
