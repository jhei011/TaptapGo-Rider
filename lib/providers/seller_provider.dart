import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import '../core/services/seller_service.dart';
import '../core/services/buyer_service.dart';
import '../core/services/api.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/order.dart';
import '../models/user.dart';

class SellerProvider extends ChangeNotifier {
  Map<String, dynamic>? _dashboard;
  List<Product>  _products    = [];
  List<Order>    _orders      = [];
  List<Category> _categories  = [];
  User?          _profile;
  bool _loadingDash = false, _loadingProducts = false, _loadingOrders = false;
  String? _error;

  Map<String, dynamic>? get dashboard        => _dashboard;
  List<Product>          get products         => _products;
  List<Order>            get orders           => _orders;
  List<Category>         get categories       => _categories;
  User?                  get profile          => _profile;
  bool                   get loadingDash      => _loadingDash;
  bool                   get loadingProducts  => _loadingProducts;
  bool                   get loadingOrders    => _loadingOrders;
  String?                get error            => _error;

  Future<void> loadDashboard() async {
    _loadingDash = true; _error = null; notifyListeners();
    try { _dashboard = await SellerService.dashboard(); }
    on ApiError catch (e) { _error = e.message; }
    catch (_) { _error = 'Failed to load dashboard.'; }
    _loadingDash = false; notifyListeners();
  }

  Future<void> loadProducts() async {
    _loadingProducts = true; _error = null; notifyListeners();
    try { _products = await SellerService.products(); }
    on ApiError catch (e) { _error = e.message; }
    catch (_) { _error = 'Failed to load products.'; }
    _loadingProducts = false; notifyListeners();
  }

  Future<void> loadOrders() async {
    _loadingOrders = true; _error = null; notifyListeners();
    try { _orders = await SellerService.orders(); }
    on ApiError catch (e) { _error = e.message; }
    catch (_) { _error = 'Failed to load orders.'; }
    _loadingOrders = false; notifyListeners();
  }

  Future<void> loadCategories() async {
    try { _categories = await BuyerService.categories(); notifyListeners(); }
    catch (_) {}
  }

  Future<void> loadProfile() async {
    try { _profile = await SellerService.profile(); notifyListeners(); }
    on ApiError catch (e) { _error = e.message; notifyListeners(); }
    catch (_) {}
  }

  Future<bool> createProduct({
    required String name, String? description,
    required double price, required int stock,
    int? categoryId, String status = 'active', File? image,
  }) async {
    try {
      final p = await SellerService.storeProduct(
          name: name, description: description, price: price,
          stock: stock, categoryId: categoryId, status: status, image: image);
      _products = [p, ..._products]; notifyListeners(); return true;
    } on ApiError catch (e) { _error = e.message; notifyListeners(); return false; }
    catch (_) { _error = 'Failed.'; notifyListeners(); return false; }
  }

  Future<bool> editProduct(int id, {
    String? name, String? description, double? price,
    int? stock, int? categoryId, String? status, File? image,
  }) async {
    try {
      final p = await SellerService.updateProduct(id,
          name: name, description: description, price: price,
          stock: stock, categoryId: categoryId, status: status, image: image);
      final idx = _products.indexWhere((x) => x.id == id);
      if (idx != -1) _products[idx] = p;
      notifyListeners(); return true;
    } on ApiError catch (e) { _error = e.message; notifyListeners(); return false; }
    catch (_) { _error = 'Failed.'; notifyListeners(); return false; }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await SellerService.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners(); return true;
    } on ApiError catch (e) { _error = e.message; notifyListeners(); return false; }
    catch (_) { return false; }
  }

  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      await SellerService.updateOrderStatus(orderId, status);
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) { _orders[idx] = _orders[idx].withStatus(status); notifyListeners(); }
      return true;
    } on ApiError catch (e) { _error = e.message; notifyListeners(); return false; }
    catch (_) { return false; }
  }

  Future<bool> saveProfile(Map<String, dynamic> body) async {
    try {
      await SellerService.updateProfile(body);
      await loadProfile(); return true;
    } on ApiError catch (e) { _error = e.message; notifyListeners(); return false; }
    catch (_) { _error = 'Failed.'; notifyListeners(); return false; }
  }

  void clearError() { _error = null; notifyListeners(); }
}
