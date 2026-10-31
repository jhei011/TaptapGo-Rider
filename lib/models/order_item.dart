class OrderItem {
  final int id;
  final int? productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final double subtotal;
  final String? image; // from API: item.product?.image

  const OrderItem({
    required this.id, this.productId, required this.productName,
    required this.productPrice, required this.quantity,
    required this.subtotal, this.image,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id:           j['id'] ?? 0,
    productId:    j['product_id'],
    productName:  j['product_name'] ?? '',
    productPrice: (j['product_price'] as num?)?.toDouble() ?? 0,
    quantity:     j['quantity'] ?? 1,
    subtotal:     (j['subtotal'] as num?)?.toDouble() ?? 0,
    image:        j['image'],
  );
}
