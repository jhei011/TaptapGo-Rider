import 'api.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/user.dart';

class BuyerService {
  static Future<List<Category>> categories() async {
    final d = await Api.get('/categories') as List;
    final flat = d.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
    return Category.buildTree(flat);
  }

  static Future<Map<String, dynamic>> products({
    String? search, int? categoryId, int page = 1,
  }) async {
    final q = <String, String>{'page': '$page'};
    if (search     != null && search.isNotEmpty) q['search']   = search;
    if (categoryId != null)                      q['category'] = '$categoryId';
    final d = await Api.get('/buyer/products', query: q) as Map<String, dynamic>;
    return {
      'data'        : (d['data'] as List).map((p) => Product.fromJson(p as Map<String, dynamic>)).toList(),
      'total'       : d['total'] ?? 0,
      'last_page'   : d['last_page'] ?? 1,
      'current_page': d['current_page'] ?? 1,
    };
  }

  static Future<Map<String, dynamic>> productDetail(int id) async {
    final d = await Api.get('/buyer/products/$id') as Map<String, dynamic>;
    return {
      'product': Product.fromJson(d['product'] as Map<String, dynamic>),
      'related': (d['related'] as List).map((p) => Product.fromJson(p as Map<String, dynamic>)).toList(),
    };
  }

  // Cart
  static Future<List<CartItem>> cart() async {
    final d = await Api.get('/buyer/cart') as List;
    return d.map((i) => CartItem.fromJson(i as Map<String, dynamic>)).toList();
  }
  static Future<void> addToCart(int productId, int qty) =>
      Api.post('/buyer/cart/$productId', body: {'quantity': qty});
  static Future<void> updateCartItem(int id, int qty) =>
      Api.patch('/buyer/cart/$id', body: {'quantity': qty});
  static Future<void> removeCartItem(int id) => Api.delete('/buyer/cart/$id');
  static Future<void> clearCart() => Api.delete('/buyer/cart');

  // Orders
  static Future<List<Order>> orders() async {
    final d = await Api.get('/buyer/orders') as List;
    return d.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
  }
  static Future<void> cancelOrder(int id) => Api.patch('/buyer/orders/$id/cancel');

  static Future<void> checkout({
    required String province, required String municipality,
    required String barangay, String? street, String? houseNo,
    required String paymentMethod, String? notes,
  }) => Api.post('/buyer/checkout', body: {
    'delivery_province'    : province,
    'delivery_municipality': municipality,
    'delivery_barangay'    : barangay,
    if (street  != null) 'delivery_street'  : street,
    if (houseNo != null) 'delivery_house_no': houseNo,
    'payment_method': paymentMethod,
    if (notes != null) 'notes': notes,
  });

  // Profile
  static Future<User> profile() async {
    final d = await Api.get('/buyer/profile') as Map<String, dynamic>;
    return User.fromJson(d);
  }
  static Future<void> updateProfile(Map<String, dynamic> body) =>
      Api.put('/buyer/profile/update', body: body);
}
