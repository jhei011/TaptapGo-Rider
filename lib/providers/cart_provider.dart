import 'package:flutter/foundation.dart';
import '../core/services/buyer_service.dart';
import '../core/services/api.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _loading = false;
  String? _error;

  List<CartItem> get items   => _items;
  bool           get loading => _loading;
  String?        get error   => _error;
  bool           get isEmpty => _items.isEmpty;
  int            get count   => _items.fold(0, (s, i) => s + i.quantity);

  double get subtotal   => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get commission => double.parse((subtotal * 0.05).toStringAsFixed(2));
  double get total      => subtotal + commission;

  Future<void> load() async {
    _loading = true; _error = null; notifyListeners();
    try   { _items = await BuyerService.cart(); }
    catch (e) { _error = e.toString(); }
    _loading = false; notifyListeners();
  }

  Future<bool> add(int productId, int qty) async {
    try {
      await BuyerService.addToCart(productId, qty);
      await load(); return true;
    } on ApiError catch (e) { _error = e.message; notifyListeners(); return false; }
    catch (_) { _error = 'Failed to add'; notifyListeners(); return false; }
  }

  Future<bool> update(int itemId, int qty) async {
    try {
      await BuyerService.updateCartItem(itemId, qty);
      final idx = _items.indexWhere((i) => i.id == itemId);
      if (idx != -1) { _items[idx] = _items[idx].copyWith(quantity: qty); notifyListeners(); }
      return true;
    } catch (_) { return false; }
  }

  Future<bool> remove(int itemId) async {
    try {
      await BuyerService.removeCartItem(itemId);
      _items.removeWhere((i) => i.id == itemId);
      notifyListeners(); return true;
    } catch (_) { return false; }
  }

  Future<bool> clear() async {
    try {
      await BuyerService.clearCart();
      _items = []; notifyListeners(); return true;
    } catch (_) { return false; }
  }

  void clearError() { _error = null; notifyListeners(); }
}
