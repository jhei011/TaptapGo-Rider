import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/demo/demo_api.dart';
import 'core/theme/app_theme.dart';
import 'core/services/location_service.dart';
import 'core/services/theme_service.dart';
import 'providers/auth_provider.dart';
import 'providers/buyer_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/seller_provider.dart';
import 'providers/courier_provider.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_buyer_screen.dart';
import 'screens/auth/register_courier_screen.dart';
import 'screens/auth/register_seller_screen.dart';
import 'screens/auth/rider_activation_screen.dart';

// Role shells
import 'screens/buyer/buyer_shell.dart';
import 'screens/seller/seller_shell.dart';
import 'screens/courier/courier_shell.dart';
import 'screens/linehaul/linehaul_home_screen.dart';

// Courier screens (pushed on top of shell)
import 'screens/courier/rider_job_screen.dart';
import 'screens/courier/rider_notifications_screen.dart';
import 'screens/courier/waybill_scanner_screen.dart';

// Shared widgets
import 'widgets/taptapgo_splash_new.dart';

// Buyer sub-screens (kept for multi-role login support)
import 'screens/buyer/product_detail_screen.dart';
import 'screens/buyer/buyer_cart_screen.dart';
import 'screens/buyer/checkout_screen.dart';
import 'screens/buyer/buyer_orders_screen.dart';
import 'screens/buyer/buyer_profile_screen.dart';
import 'screens/buyer/buyer_edit_profile_screen.dart';

// Seller sub-screens
import 'screens/seller/add_edit_product_screen.dart';
import 'screens/seller/seller_edit_profile_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BuyerProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => CourierProvider()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) => Listener(
          onPointerDown: (_) => context.read<AuthProvider>().resetIdleTimer(),
          child: MaterialApp(
          title: 'TaptapGo',
          debugShowCheckedModeBanner: false,
          // Marks every demo screen, so sample data cannot be mistaken for real results
          builder: kDemoMode
              ? (context, child) => Banner(message: 'DEMO', location: BannerLocation.topEnd, child: child!)
              : null,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeService.flutterMode,
          home: const _SplashGate(),
          routes: {
            // Auth
            '/login':             (_) => const LoginScreen(),
            '/register/buyer':    (_) => const RegisterBuyerScreen(),
            '/register/seller':   (_) => const RegisterSellerScreen(),
            // Riders cannot self-register (TC-RID-029); this screen explains the
            // activation flow managed by the logistics partner.
            '/register/courier':  (_) => const RegisterCourierScreen(),

            // Role shells
            '/buyer':   (_) => const BuyerShell(),
            '/seller':  (_) => const SellerShell(),
            '/courier': (_) => const CourierShell(),
            '/linehaul': (_) => const LinehaulHomeScreen(),

            // Courier routes
            '/courier/scan':          (_) => const WaybillScannerScreen(confirmPickups: true),
            '/courier/notifications': (_) => const RiderNotificationsScreen(),

            // Buyer routes
            '/buyer/cart':         (_) => const BuyerCartScreen(),
            '/buyer/checkout':     (_) => const CheckoutScreen(),
            '/buyer/orders':       (_) => const BuyerOrdersScreen(),
            '/buyer/profile':      (_) => const BuyerProfileScreen(),
            '/buyer/profile/edit': (_) => const BuyerEditProfileScreen(),

            // Seller routes
            '/seller/products/add':  (_) => const AddEditProductScreen(),
            '/seller/profile/edit':  (_) => const SellerEditProfileScreen(),
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

            // /seller/products/edit/:id
            if (settings.name != null &&
                settings.name!.startsWith('/seller/products/edit/')) {
              final id = int.tryParse(
                  settings.name!.replaceFirst('/seller/products/edit/', ''));
              if (id != null) {
                return MaterialPageRoute(
                  builder: (_) => AddEditProductScreen(productId: id),
                );
              }
            }

            // /buyer/product — productId passed as arguments
            if (settings.name == '/buyer/product') {
              final id = settings.arguments as int?;
              if (id != null) {
                return MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(productId: id),
                );
              }
            }

            // /buyer/product/:id — legacy path-based route
            if (settings.name != null &&
                settings.name!.startsWith('/buyer/product/')) {
              final id = int.tryParse(
                  settings.name!.replaceFirst('/buyer/product/', ''));
              if (id != null) {
                return MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(productId: id),
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
    );
  }
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
        } else if (role == 'buyer') {
          Navigator.pushReplacementNamed(context, '/buyer');
        } else if (role == 'seller') {
          Navigator.pushReplacementNamed(context, '/seller');
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
