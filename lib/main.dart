import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/services/theme_service.dart';
import 'providers/auth_provider.dart';
import 'providers/buyer_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/seller_provider.dart';
import 'providers/courier_provider.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_buyer_screen.dart';
import 'screens/auth/register_seller_screen.dart';
import 'screens/auth/register_courier_screen.dart';
import 'screens/auth/rider_activation_screen.dart';

// Role shells
import 'screens/buyer/buyer_shell.dart';
import 'screens/seller/seller_shell.dart';
import 'screens/courier/courier_shell.dart';

// Courier screens (pushed on top of shell)
import 'screens/courier/parcel_detail_screen.dart';

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
  runApp(const BilisHatidApp());
}

class BilisHatidApp extends StatefulWidget {
  const BilisHatidApp({super.key});

  @override
  State<BilisHatidApp> createState() => _BilisHatidAppState();
}

class _BilisHatidAppState extends State<BilisHatidApp> {
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
        builder: (context, themeService, _) => MaterialApp(
          title: 'Bilis Hatid Express Inc.',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeService.flutterMode,
          home: const _AppRoot(),
          routes: {
            // Auth
            '/login':             (_) => const LoginScreen(),
            '/register/buyer':    (_) => const RegisterBuyerScreen(),
            '/register/seller':   (_) => const RegisterSellerScreen(),
            '/register/courier':  (_) => const RegisterCourierScreen(),

            // Role shells
            '/buyer':   (_) => const BuyerShell(),
            '/seller':  (_) => const SellerShell(),
            '/courier': (_) => const CourierShell(),

            // Courier routes
            '/courier/scan': (_) => const _ScanPlaceholder(),

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
            // /courier/parcel — parcelId passed as arguments (int)
            if (settings.name == '/courier/parcel') {
              final id = settings.arguments as int?;
              if (id != null) {
                return MaterialPageRoute(
                  builder: (_) => ParcelDetailScreen(parcelId: id),
                );
              }
            }

            // /courier/parcel/:id — path-based fallback
            if (settings.name != null &&
                settings.name!.startsWith('/courier/parcel/')) {
              final id = int.tryParse(
                  settings.name!.replaceFirst('/courier/parcel/', ''));
              if (id != null) {
                return MaterialPageRoute(
                  builder: (_) => ParcelDetailScreen(parcelId: id),
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
    );
  }
}

/// Splash / boot — checks stored token and redirects accordingly.
class _AppRoot extends StatefulWidget {
  const _AppRoot();
  @override State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThemeService>().load();
      _boot();
    });
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();
    await auth.boot();
    if (!mounted) return;

    switch (auth.status) {
      case AuthStatus.authenticated:
        final role = auth.user?.role;
        if (role == 'courier') {
          Navigator.pushReplacementNamed(context, '/courier');
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E2A38),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.local_shipping,
                  size: 42, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text('Bilis Hatid',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const Text('Express Inc.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4A949C))),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
                color: Color(0xFF4A949C), strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for the /courier/scan route.
/// Will be replaced by the full scanner screen in Phase C.
class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan Parcel')),
        body: const Center(child: Text('Scan — coming in Phase C')),
      );
}
