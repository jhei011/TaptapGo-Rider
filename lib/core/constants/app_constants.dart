class AppConstants {
  // Physical device: your PC's local IP on the same Wi-Fi as the phone
  // Run Laravel with: php artisan serve --host=0.0.0.0 --port=8000
  static const String baseUrl = 'http://192.168.1.39:8000';
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
    'out_for_delivery', 'delivered', 'cancelled',
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
