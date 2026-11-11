/// A pickup (seller → hub) or delivery (hub → buyer) job from /api/courier/jobs.
class RiderJob {
  final int id;
  final String type; // pickup | delivery
  final String status; // assigned | done | failed
  final String shipmentStatus; // awaiting_pickup | picked_up | at_hub | out_for_delivery | delivered | failed_delivery | return_to_sender
  final int attempt;
  final int maxAttempts;
  final String trackingNumber;
  final int orderId;
  final int parcels;
  final double pay;
  final double earned;
  final String? result;
  final String paymentMethod;
  final double codAmount;
  final JobStop pickup;
  final JobStop dropoff;
  final List<JobItem> items;
  final String? failedReason;
  final Map<String, String> times;
  final String? podPhotoUrl;

  /// 'forward' (seller → buyer) or 'reverse' (a return: buyer → seller).
  final String direction;
  final String? returnNumber;

  const RiderJob({
    required this.id, required this.type, required this.status,
    required this.shipmentStatus, required this.attempt, required this.maxAttempts,
    required this.trackingNumber, required this.orderId, required this.parcels,
    required this.pay, required this.earned, this.result,
    required this.paymentMethod, required this.codAmount,
    required this.pickup, required this.dropoff, this.items = const [],
    this.failedReason, this.times = const {}, this.podPhotoUrl,
    this.direction = 'forward', this.returnNumber,
  });

  bool get isPickup => type == 'pickup';
  bool get isDelivery => type == 'delivery';
  bool get isActive => status == 'assigned';
  bool get isCod => paymentMethod == 'cod';

  /// A buyer → seller return trip. The buyer (not the seller) is at the pickup,
  /// the seller receives the parcel, there is no delivery code and nothing to
  /// collect, and the trip is not paid from the order (RiderJobService::pay).
  bool get isReturn => direction == 'reverse';

  /// COD is only collected on a forward delivery.
  bool get collectsCod => isCod && !isReturn;

  bool get canConfirmPickup => isPickup && isActive && shipmentStatus == 'awaiting_pickup';
  bool get canStartDelivery => isDelivery && isActive && shipmentStatus == 'at_hub';
  bool get canFinishDelivery => isDelivery && isActive && shipmentStatus == 'out_for_delivery';

  /// The stop the rider is heading to now.
  JobStop get destination => isPickup ? pickup : dropoff;

  factory RiderJob.fromJson(Map<String, dynamic> j) => RiderJob(
        id: j['id'] ?? 0,
        type: j['type'] ?? 'pickup',
        status: j['status'] ?? '',
        shipmentStatus: j['shipment_status'] ?? '',
        attempt: j['attempt'] ?? 1,
        maxAttempts: j['max_attempts'] ?? 3,
        trackingNumber: j['tracking_number'] ?? '',
        orderId: j['order_id'] ?? 0,
        parcels: j['parcels'] ?? 1,
        pay: (j['pay'] as num?)?.toDouble() ?? 0,
        earned: (j['earned'] as num?)?.toDouble() ?? 0,
        result: j['result'],
        paymentMethod: j['payment_method'] ?? '',
        codAmount: (j['cod_amount'] as num?)?.toDouble() ?? 0,
        pickup: JobStop.fromJson((j['pickup'] as Map?)?.cast<String, dynamic>() ?? const {}),
        dropoff: JobStop.fromJson((j['dropoff'] as Map?)?.cast<String, dynamic>() ?? const {}),
        items: (j['items'] as List? ?? [])
            .map((i) => JobItem.fromJson((i as Map).cast<String, dynamic>()))
            .toList(),
        failedReason: j['failed_reason'],
        times: (j['times'] is Map)
            ? (j['times'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
            : const {},
        podPhotoUrl: j['pod_photo_url'],
        direction: j['direction'] ?? 'forward',
        returnNumber: j['return_number'],
      );
}

class JobStop {
  final String name;
  final String? contact;
  final String? phone;
  final String address;
  final String area;

  const JobStop({required this.name, this.contact, this.phone, required this.address, required this.area});

  factory JobStop.fromJson(Map<String, dynamic> j) => JobStop(
        name: j['name'] ?? '',
        contact: j['contact'],
        phone: j['phone'],
        address: j['address'] ?? '',
        area: j['area'] ?? '',
      );
}

class JobItem {
  final String name;
  final int quantity;
  const JobItem({required this.name, required this.quantity});
  factory JobItem.fromJson(Map<String, dynamic> j) =>
      JobItem(name: j['name'] ?? '', quantity: j['quantity'] ?? 1);
}

/// A 60-second job offer from /api/courier/offers.
class JobOffer {
  final int id;
  final DateTime expiresAt;
  final RiderJob job;

  const JobOffer({required this.id, required this.expiresAt, required this.job});

  int secondsLeft([DateTime? now]) =>
      expiresAt.difference(now ?? DateTime.now()).inSeconds.clamp(0, 60);

  factory JobOffer.fromJson(Map<String, dynamic> j) {
    // Count down from the server's remaining seconds, so a wrong phone clock does not matter
    final secondsLeft = (j['seconds_left'] as num?)?.toInt() ?? 0;
    return JobOffer(
      id: j['id'] ?? 0,
      expiresAt: DateTime.now().add(Duration(seconds: secondsLeft)),
      job: RiderJob.fromJson((j['job'] as Map).cast<String, dynamic>()),
    );
  }
}
