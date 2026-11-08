class AppConstants {
  // For now: your laptop's local server and database, through the USB cable.
  // On the laptop: php artisan serve --host=127.0.0.1 --port=8000
  //   then: adb reverse tcp:8000 tcp:8000   (again after every re-plug)
  // Other servers, without editing this file:
  //   Same Wi-Fi:   flutter run --dart-define=API_BASE=http://192.168.1.39:8000
  //   Live server:  flutter run --dart-define=API_BASE=https://taptapshop.store
  static const String baseUrl = String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8000');
  static const String apiBase = '$baseUrl/api';

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
