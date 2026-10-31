import 'order_item.dart';

class OrderRef { // seller or buyer reference
  final int id; final String name;
  const OrderRef({required this.id, required this.name});
  factory OrderRef.fromJson(Map<String, dynamic> j) =>
      OrderRef(id: j['id'] ?? 0, name: j['name'] ?? '');
}

/// Shipment progress of an order (A10); the buyer also gets the delivery code (A32).
class Shipment {
  final String trackingNumber;
  final String status;
  final String? deliveryOtp;
  final int attempt;
  final String? failedReason;
  final String? podPhotoUrl;
  final Map<String, String> times;

  const Shipment({
    required this.trackingNumber, required this.status, this.deliveryOtp,
    this.attempt = 0, this.failedReason, this.podPhotoUrl, this.times = const {},
  });

  /// Time of the latest step, e.g. delivered, else out for delivery, ...
  String? get latestTime {
    for (final k in ['returned', 'delivered', 'failed', 'out_for_delivery', 'at_hub', 'picked_up']) {
      if (times[k] != null) return times[k];
    }
    return null;
  }

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
    trackingNumber: j['tracking_number'] ?? '',
    status:         j['status'] ?? '',
    deliveryOtp:    j['delivery_otp'],
    attempt:        j['attempt'] ?? 0,
    failedReason:   j['failed_reason'],
    podPhotoUrl:    j['pod_photo_url'],
    times: (j['times'] is Map)
        ? (j['times'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
        : const {},
  );
}

class Order {
  final int id;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double commission;
  final double total;
  final String deliveryProvince;
  final String deliveryMunicipality;
  final String deliveryBarangay;
  final String? deliveryStreet;
  final String? deliveryHouseNo;
  final String? notes;
  final OrderRef? seller;
  final String? buyerName;   // from seller API: buyer_name
  final int?  itemsCount;    // from seller orders list
  final List<OrderItem> items;
  final String? createdAt;
  final Shipment? shipment;

  const Order({
    required this.id, required this.status,
    required this.paymentMethod, required this.paymentStatus,
    required this.subtotal, required this.commission, required this.total,
    required this.deliveryProvince, required this.deliveryMunicipality,
    required this.deliveryBarangay,
    this.deliveryStreet, this.deliveryHouseNo, this.notes,
    this.seller, this.buyerName, this.itemsCount,
    this.items = const [], this.createdAt, this.shipment,
  });

  /// The seller can change or cancel an order only before it goes to the logistics company (A6)
  bool get sellerCanUpdate =>
      shipment == null && const ['pending', 'confirmed', 'ready_for_pickup'].contains(status);

  bool get isCancellable => status == 'pending';
  bool get isDelivered   => status == 'delivered';
  bool get isCancelled   => status == 'cancelled';

  String get shortAddress =>
      [deliveryBarangay, deliveryMunicipality, deliveryProvince]
          .where((s) => s.isNotEmpty).join(', ');

  String get fullAddress =>
      [deliveryHouseNo, deliveryStreet, deliveryBarangay,
       deliveryMunicipality, deliveryProvince]
          .where((s) => s != null && s.isNotEmpty).join(', ');

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:                   j['id'] ?? 0,
    status:               j['status'] ?? 'pending',
    paymentMethod:        j['payment_method'] ?? '',
    paymentStatus:        j['payment_status'] ?? 'unpaid',
    subtotal:             (j['subtotal'] as num?)?.toDouble() ?? 0,
    commission:           (j['commission'] as num?)?.toDouble() ?? 0,
    total:                (j['total'] as num?)?.toDouble() ?? 0,
    deliveryProvince:     j['delivery_province'] ?? '',
    deliveryMunicipality: j['delivery_municipality'] ?? '',
    deliveryBarangay:     j['delivery_barangay'] ?? '',
    deliveryStreet:       j['delivery_street'],
    deliveryHouseNo:      j['delivery_house_no'],
    notes:                j['notes'],
    seller:               j['seller'] != null ? OrderRef.fromJson(j['seller']) : null,
    buyerName:            j['buyer_name'],
    itemsCount:           j['items_count'],
    items: (j['items'] as List<dynamic>?)
            ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>)).toList()
        ?? const [],
    createdAt: j['created_at'],
    shipment: j['shipment'] is Map
        ? Shipment.fromJson((j['shipment'] as Map).cast<String, dynamic>())
        : null,
  );

  Order withStatus(String s) => Order(
    id: id, status: s, paymentMethod: paymentMethod, paymentStatus: paymentStatus,
    subtotal: subtotal, commission: commission, total: total,
    deliveryProvince: deliveryProvince, deliveryMunicipality: deliveryMunicipality,
    deliveryBarangay: deliveryBarangay, deliveryStreet: deliveryStreet,
    deliveryHouseNo: deliveryHouseNo, notes: notes, seller: seller,
    buyerName: buyerName, itemsCount: itemsCount, items: items, createdAt: createdAt,
    shipment: shipment,
  );
}
