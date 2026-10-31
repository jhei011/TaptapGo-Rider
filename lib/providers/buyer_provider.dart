import 'package:flutter/foundation.dart' hide Category;
import '../core/services/buyer_service.dart';
import '../core/services/api.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/order.dart';
import '../models/user.dart';

class BuyerProvider extends ChangeNotifier {
  // Products
  List<Product> _products = [];
  int _total = 0, _lastPage = 1, _currentPage = 1;
  bool _loadingProducts = false, _loadingMore = false;
  String? _productError;
  String? _search;
  int? _selectedCategory;

  // Categories
  List<Category> _categories = [];

  // Orders
  List<Order> _orders = [];
  bool _loadingOrders = false;

  // Profile
  User? _profile;

  List<Product>  get products         => _products;
  int            get total            => _total;
  bool           get loadingProducts  => _loadingProducts;
  bool           get loadingMore      => _loadingMore;
  String?        get productError     => _productError;
  bool           get hasMore          => _currentPage < _lastPage;
  String?        get search           => _search;
  int?           get selectedCategory => _selectedCategory;
  List<Category> get categories       => _categories;
  List<Order>    get orders           => _orders;
  bool           get loadingOrders    => _loadingOrders;
  User?          get profile          => _profile;

  Future<void> loadCategories() async {
    debugPrint('>>> loadCategories START');
    try {
      final cats = await BuyerService.categories();
      debugPrint('>>> loadCategories SUCCESS: ${cats.length} categories');
      _categories = cats;
      notifyListeners();
    } on ApiError catch (e) {
      debugPrint('>>> loadCategories ApiError: ${e.message}');
    } catch (e) {
      debugPrint('>>> loadCategories unexpected: $e');
    }
    debugPrint('>>> loadCategories END');
  }

  Future<void> loadProducts({String? search, int? categoryId, bool reset = true}) async {
    if (reset) {
      _loadingProducts = true; _productError = null;
      _products = []; _currentPage = 1;
      _search = search; _selectedCategory = categoryId;
    } else {
      _loadingMore = true;
    }
    notifyListeners();
    try {
      final r = await BuyerService.products(
          search: _search, categoryId: _selectedCategory, page: _currentPage);
      final newProducts = r['data'] as List<Product>;
      _products = reset ? newProducts : [..._products, ...newProducts];
      _total = r['total'] as int;
      _lastPage = r['last_page'] as int;
      _currentPage = r['current_page'] as int;
    } on ApiError catch (e) { _productError = e.message; }
    catch (_)               { _productError = 'Failed to load products.'; }
    _loadingProducts = false; _loadingMore = false; notifyListeners();
  }

  Future<void> loadNextPage() async {
    if (_loadingMore || !hasMore) return;
    _currentPage++;
    await loadProducts(reset: false);
  }

  void applyFilter({String? search, int? categoryId}) =>
      loadProducts(search: search, categoryId: categoryId);
  void clearFilters() => loadProducts();

  Future<void> loadOrders() async {
    _loadingOrders = true; notifyListeners();
    try { _orders = await BuyerService.orders(); }
    catch (_) {}
    _loadingOrders = false; notifyListeners();
  }

  Future<bool> cancelOrder(int id) async {
    try {
      await BuyerService.cancelOrder(id);
      final idx = _orders.indexWhere((o) => o.id == id);
      if (idx != -1) { _orders[idx] = _orders[idx].withStatus('cancelled'); notifyListeners(); }
      return true;
    } catch (_) { return false; }
  }

  Future<void> loadProfile() async {
    try { _profile = await BuyerService.profile(); notifyListeners(); }
    catch (_) {}
  }
}
