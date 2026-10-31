import 'dart:io';
import 'api.dart';
import '../../models/product.dart';
import '../../models/order.dart';
import '../../models/user.dart';

class SellerService {
  static Future<Map<String, dynamic>> dashboard() async =>
      await Api.get('/seller/dashboard') as Map<String, dynamic>;

  static Future<List<Product>> products() async {
    final d = await Api.get('/seller/products') as List;
    return d.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }

  static Future<Product> storeProduct({
    required String name, String? description,
    required double price, required int stock,
    int? categoryId, String status = 'active', File? image,
  }) async {
    final fields = <String, String>{
      'name': name,
      if (description != null) 'description': description,
      'price': '$price', 'stock': '$stock',
      if (categoryId != null) 'category_id': '$categoryId',
      'status': status,
    };
    dynamic d;
    if (image != null) {
      d = await Api.postMultipart('/seller/products', fields: fields, files: {'image': image});
    } else {
      d = await Api.post('/seller/products', body: {
        'name': name, if (description != null) 'description': description,
        'price': price, 'stock': stock,
        if (categoryId != null) 'category_id': categoryId,
        'status': status,
      });
    }
    return Product.fromJson(d as Map<String, dynamic>);
  }

  static Future<Product> updateProduct(int id, {
    String? name, String? description, double? price,
    int? stock, int? categoryId, String? status, File? image,
  }) async {
    final fields = <String, String>{
      if (name        != null) 'name': name,
      if (description != null) 'description': description,
      if (price       != null) 'price': '$price',
      if (stock       != null) 'stock': '$stock',
      if (categoryId  != null) 'category_id': '$categoryId',
      if (status      != null) 'status': status,
    };
    dynamic d;
    if (image != null) {
      d = await Api.postMultipart('/seller/products/$id',
          fields: {...fields, '_method': 'PUT'}, files: {'image': image});
    } else {
      d = await Api.put('/seller/products/$id', body: {
        if (name        != null) 'name': name,
        if (description != null) 'description': description,
        if (price       != null) 'price': price,
        if (stock       != null) 'stock': stock,
        if (categoryId  != null) 'category_id': categoryId,
        if (status      != null) 'status': status,
      });
    }
    return Product.fromJson(d as Map<String, dynamic>);
  }

  static Future<void> deleteProduct(int id) => Api.delete('/seller/products/$id');

  static Future<List<Order>> orders() async {
    final d = await Api.get('/seller/orders') as List;
    return d.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
  }

  static Future<void> updateOrderStatus(int id, String status) =>
      Api.patch('/seller/orders/$id/status', body: {'status': status});

  static Future<User> profile() async {
    final d = await Api.get('/seller/profile') as Map<String, dynamic>;
    return User.fromJson(d);
  }

  static Future<void> updateProfile(Map<String, dynamic> body) =>
      Api.put('/seller/profile/update', body: body);
}
