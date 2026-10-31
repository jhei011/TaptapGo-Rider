import 'product.dart';

class CartItem {
  final int id;
  final int quantity;
  final Product? product;

  const CartItem({required this.id, required this.quantity, this.product});

  double get subtotal => (product?.price ?? 0) * quantity;

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    id:       j['id'] ?? 0,
    quantity: j['quantity'] ?? 1,
    product:  j['product'] != null ? Product.fromJson(j['product']) : null,
  );

  CartItem copyWith({int? quantity}) =>
      CartItem(id: id, quantity: quantity ?? this.quantity, product: product);
}
