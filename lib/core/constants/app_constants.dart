import 'package:flutter/foundation.dart' show kReleaseMode;

class AppConstants {
  // Which server the app talks to.
  //   Release builds (flutter build apk --release / appbundle): the live server,
  //     https://taptapshop.store, unless API_BASE is given.
  //   Debug builds: your laptop's local server through the USB cable
  //     (php artisan serve --host=127.0.0.1 --port=8000, then adb reverse tcp:8000 tcp:8000).
  // Any other server, without editing this file:
  //   Same Wi-Fi:   flutter run --dart-define=API_BASE=http://192.168.1.39:8000
  //   Staging:      flutter build apk --release --dart-define=API_BASE=https://staging.example
  static const String liveServer = 'https://taptapshop.store';
  static const String baseUrl = String.fromEnvironment('API_BASE',
      defaultValue: kReleaseMode ? liveServer : 'http://127.0.0.1:8000');
  static const String apiBase = '$baseUrl/api';

  /// Google sign-in: the OAuth *web* client id of the TaptapShop Google Cloud project
  /// (the one TaptapShop uses and the backend accepts as token audience,
  /// ApiGoogleAuthController). Not a secret. Android additionally needs an Android
  /// OAuth client for com.taptapgo.app + the signing SHA-1 in that same project.
  static const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '75167460858-ddqjfmj6tb1kgbecrid5btsvi4lphu4m.apps.googleusercontent.com');

  // For Android emulator swap to: 'http://10.0.2.2:8000'

  static const String appName    = 'TaptapGo';
  static const String appShort   = 'TaptapGo';
  static const String tokenKey   = 'auth_token';

  static const String roleBuyer   = 'buyer';
  static const String roleSeller  = 'seller';
  static const String roleCourier = 'courier';

  static const List<String> orderStatuses = [
    'pending', 'confirmed', 'ready_for_pickup',
    'awaiting_pickup', 'picked_up', 'at_hub',
    'out_for_delivery', 'delivered', 'cancelled',
    'failed_delivery', 'return_to_sender',
  ];

  static String orderStatusLabel(String s) => const {
    'pending'          : 'Pending',
    'confirmed'        : 'Confirmed',
    'ready_for_pickup' : 'Ready for Pickup',
    'assigned'         : 'Rider Assigned',
    'parceled_in'      : 'At Hub',
    'sorted'           : 'At Hub',
    'in_transit'       : 'Picked Up',
    'out_for_delivery' : 'Out for Delivery',
    'delivered'        : 'Delivered',
    'cancelled'        : 'Cancelled',
    'failed_delivery'  : 'Failed Delivery',
    'return_to_sender' : 'Return to Sender',
  }[s] ?? s;

  static const List<String> paymentMethods = ['cod', 'gcash', 'bank_transfer'];

  static String paymentLabel(String m) => const {
    'cod'           : 'Cash on Delivery',
    'gcash'         : 'GCash',
    'bank_transfer' : 'Bank Transfer',
  }[m] ?? m;
}
