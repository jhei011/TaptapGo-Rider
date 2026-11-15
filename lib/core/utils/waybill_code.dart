/// What a scanned (or typed) waybill code refers to.
///
/// Two waybills exist on the website:
///  * the logistics waybill: a Code 128 barcode holding the parcel's tracking number;
///  * the seller's waybill: a QR code holding a link to the order's logistics page,
///    e.g. https://logistics.taptapshop.store/orders/12 (route `logistics.orders.scan`).
/// Riders meet both at pickup, so both must work.
class WaybillCode {
  /// The order id when the code is a seller-waybill link, otherwise null.
  final int? orderId;

  /// The tracking number when the code is not an order link, otherwise null.
  final String? trackingNumber;

  const WaybillCode._({this.orderId, this.trackingNumber});

  static final _orderLink = RegExp(r'^https?://[^/\s]+/orders/(\d+)/?(?:[?#].*)?$', caseSensitive: false);

  static WaybillCode parse(String raw) {
    final code = raw.trim();
    final m = _orderLink.firstMatch(code);
    if (m != null) return WaybillCode._(orderId: int.parse(m.group(1)!));
    return WaybillCode._(trackingNumber: code.toUpperCase());
  }

  bool get isOrderLink => orderId != null;
}
