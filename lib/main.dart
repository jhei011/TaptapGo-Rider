import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/demo/demo_api.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette_sync.dart';
import 'core/services/location_service.dart';
import 'core/services/theme_service.dart';
import 'providers/auth_provider.dart';
import 'providers/courier_provider.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_courier_screen.dart';
import 'screens/auth/rider_activation_screen.dart';

// TaptapGo is the rider app: the Rider panel and the Linehaul Courier panel only.
// Buyers and sellers use TaptapShop.
import 'screens/courier/courier_shell.dart';
import 'screens/linehaul/linehaul_shell.dart';

// Courier screens (pushed on top of shell)
import 'screens/courier/rider_job_screen.dart';
import 'screens/courier/rider_notifications_screen.dart';
import 'screens/courier/waybill_scanner_screen.dart';

// Shared widgets
import 'widgets/push_watcher.dart';
import 'widgets/rider_idle_watcher.dart';
import 'widgets/taptapgo_splash_new.dart';

void main() {
  if (kDemoMode) {
    // No account or server: every request is answered on the device (see DemoApi)
    final demo = DemoApi();
    LocationService.source = DemoLocation();
    http.runWithClient(() => runApp(const TaptapGoApp()), () => demo.client);
    return;
  }
  runApp(const TaptapGoApp());
}

class TaptapGoApp extends StatefulWidget {
  const TaptapGoApp({super.key});

  @override
  State<TaptapGoApp> createState() => _TaptapGoAppState();
}

class _TaptapGoAppState extends State<TaptapGoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourierProvider()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: ForcedLogoutWatcher(
        navigatorKey: _navigatorKey,
        // 30 minutes without activity signs the rider out, but never while the server shows
        // a job, offer or trip for them (or cannot be asked), and never from the background
        child: RiderIdleWatcher(
        // Push notifications for whoever is logged in (new jobs, trips)
        child: PushWatcher(
        messengerKey: _messengerKey,
        child: Consumer<ThemeService>(
        builder: (context, themeService, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          title: 'TaptapGo',
          debugShowCheckedModeBanner: false,
          // Every screen's colours follow the theme shown (light, dark or the phone's setting).
          // Demo builds also mark every screen, so sample data cannot be mistaken for real results.
          builder: (context, child) => PaletteSync(
            dark: Theme.of(context).brightness == Brightness.dark,
            child: kDemoMode
                ? Banner(message: 'DEMO', location: BannerLocation.topEnd, child: child!)
                : child!,
          ),
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeService.flutterMode,
          home: const _SplashGate(),
          routes: {
            // Auth
            '/login':             (_) => const LoginScreen(),
            // Riders cannot self-register (TC-RID-029); this screen explains the
            // activation flow managed by the logistics partner.
            '/register/courier':  (_) => const RegisterCourierScreen(),

            // Role shells
            '/courier': (_) => const CourierShell(),
            '/linehaul': (_) => const LinehaulShell(),

            // Courier routes
            '/courier/scan':          (_) => const WaybillScannerScreen(confirmPickups: true),
            '/courier/notifications': (_) => const RiderNotificationsScreen(),
          },
          onGenerateRoute: (settings) {
            // /courier/job — rider job id passed as arguments (int)
            if (settings.name == '/courier/job') {
              final id = settings.arguments as int?;
              if (id != null) {
                return MaterialPageRoute(
                  builder: (_) => RiderJobScreen(jobId: id),
                );
              }
            }

            // /rider/activate?token=XXX
            if (settings.name == '/rider/activate') {
              final token = settings.arguments as String?
                  ?? Uri.tryParse(settings.name ?? '')
                      ?.queryParameters['token'];
              if (token != null && token.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => RiderActivationScreen(token: token),
                );
              }
            }

            return null;
          },
        ),
      ),
      ),
      ),
      ),
    );
  }
}

/// When the app signs the rider out on its own (expired login, suspended or removed
/// account), stops the rider's background polling and returns to the login
/// screen, which shows the reason.
class ForcedLogoutWatcher extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const ForcedLogoutWatcher({super.key, required this.navigatorKey, required this.child});

  @override
  State<ForcedLogoutWatcher> createState() => _ForcedLogoutWatcherState();
}

class _ForcedLogoutWatcherState extends State<ForcedLogoutWatcher> {
  late final AuthProvider _auth;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _seen = _auth.forcedLogouts;
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_auth.forcedLogouts == _seen) return;
    _seen = _auth.forcedLogouts;
    context.read<CourierProvider>().stop();
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Boots auth in the background while the new animated splash plays,
/// then navigates to the correct role shell (or login) when both are done.
class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _authDone = false;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final themeService = context.read<ThemeService>();
      final authProvider = context.read<AuthProvider>();
      await themeService.load();
      await authProvider.boot();
      if (mounted) setState(() => _authDone = true);
      _maybeNavigate();
    });
  }

  void _onSplashFinished() {
    setState(() => _splashDone = true);
    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (!_authDone || !_splashDone) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.authenticated:
        final role = auth.user?.role;
        if (role == 'courier') {
          Navigator.pushReplacementNamed(context, '/courier');
        } else if (role == 'linehaul') {
          Navigator.pushReplacementNamed(context, '/linehaul');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      case AuthStatus.unauthenticated:
      case AuthStatus.unknown:
        Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) => TapTapGoSplashScreen(
        onFinished: _onSplashFinished,
      );
}
