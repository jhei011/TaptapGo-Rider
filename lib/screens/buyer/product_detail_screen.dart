import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/buyer_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/api.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/empty_state.dart';
import 'buyer_messages_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override State<ProductDetailScreen> createState() => _ProdDetailState();
}

class _ProdDetailState extends State<ProductDetailScreen> {
  Product? _product;
  List<Product> _related = [];
  bool _loading = true;
  String? _error;
  int _qty = 1;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await BuyerService.productDetail(widget.productId);
      if (mounted) {
        setState(() {
        _product = r['product'] as Product;
        _related = r['related'] as List<Product>;
        _loading = false;
      });
      }
    } on ApiError catch (e) { if (mounted) setState(() { _error = e.message; _loading = false; }); }
    catch (_) { if (mounted) setState(() { _error = 'Failed to load.'; _loading = false; }); }
  }

  Future<void> _addToCart() async {
    final cart = context.read<CartProvider>();
    final ok = await cart.add(_product!.id, _qty);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Added to cart!'),
        backgroundColor: C.b700,
        action: SnackBarAction(label: 'View Cart', textColor: C.grad4,
            onPressed: () => Navigator.pop(context)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(cart.error ?? 'Failed'), backgroundColor: C.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: C.navbarGrad)),
        iconTheme: const IconThemeData(color: Colors.white)),
      body: const LoadingCenter(),
    );
    }
    if (_error != null || _product == null) {
      return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: C.navbarGrad)),
        iconTheme: const IconThemeData(color: Colors.white)),
      body: ErrorRetry(message: _error ?? 'Product not found', onRetry: _load),
    );
    }

    final p = _product!;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: C.navbarGrad),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/buyer/cart'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product image
          AspectRatio(
            aspectRatio: 1.1,
            child: p.image != null
                ? CachedNetworkImage(
                    imageUrl: p.image!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: C.b50),
                    errorWidget: (_, __, ___) => Container(color: C.b50, child: const Icon(Icons.image_outlined, color: C.b200, size: 64)),
                  )
                : Container(color: C.b50, child: const Icon(Icons.image_outlined, color: C.b200, size: 64)),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Category badge
              if (p.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: C.b50, borderRadius: BorderRadius.circular(20)),
                  child: Text(p.category!.name,
                      style: const TextStyle(fontSize: 11, color: C.b700, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 10),

              // Name
              Text(p.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.textPrimary)),
              const SizedBox(height: 4),

              // Seller
              if (p.seller != null) Row(children: [
                const Icon(Icons.store_outlined, size: 14, color: C.b600),
                const SizedBox(width: 4),
                Text('Sold by ${p.seller!.name}',
                    style: const TextStyle(fontSize: 12, color: C.textSecondary)),
              ]),
              const SizedBox(height: 10),

              // Price
              Text('₱${p.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: C.b700)),
              const SizedBox(height: 6),

              // Stock
              Row(children: [
                Icon(p.inStock ? Icons.check_circle_outline : Icons.cancel_outlined,
                    size: 16, color: p.inStock ? C.delivered : C.danger),
                const SizedBox(width: 4),
                Text(
                  p.inStock
                      ? '${p.stock} left in stock${p.lowStock ? " — Low stock!" : ""}'
                      : 'Out of stock',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: p.lowStock ? C.danger : (p.inStock ? C.delivered : C.danger),
                  ),
                ),
              ]),

              const Divider(height: 24),

              // Description
              const Text('Description',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.textPrimary)),
              const SizedBox(height: 6),
              Text(
                p.description?.isNotEmpty == true ? p.description! : 'No description provided.',
                style: const TextStyle(fontSize: 14, color: C.textSecondary, height: 1.55),
              ),

              if (p.inStock) ...[
                const Divider(height: 24),
                // Quantity
                const Text('Quantity',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.textPrimary)),
                const SizedBox(height: 10),
                Row(children: [
                  _qtyBtn(Icons.remove_rounded, () { if (_qty > 1) setState(() => _qty--); }),
                  SizedBox(
                    width: 48,
                    child: Center(child: Text('$_qty',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  ),
                  _qtyBtn(Icons.add_rounded, () { if (_qty < p.stock) setState(() => _qty++); }),
                  const SizedBox(width: 12),
                  Text('max ${p.stock}',
                      style: const TextStyle(fontSize: 12, color: C.textMuted)),
                ]),
                const SizedBox(height: 18),

                // Add to cart button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(10)),
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // View cart button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/buyer/cart'),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('View Cart'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.b700, side: const BorderSide(color: C.b600),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (p.seller != null) ...[
                  const SizedBox(height: 10),
                  // Message Seller button — matches website product detail
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _messageSeller(p),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message Seller'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.textSecondary,
                        side: const BorderSide(color: C.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ]),
          ),

          // Related products
          if (_related.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text('Related Products',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.textPrimary)),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: _related.length,
                itemBuilder: (_, i) {
                  final rp = _related[i];
                  return GestureDetector(
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: rp.id))),
                    child: Container(
                      width: 130,
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: rp.image != null
                                ? CachedNetworkImage(imageUrl: rp.image!, width: double.infinity, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(color: C.b50))
                                : Container(color: C.b50, child: const Icon(Icons.image_outlined, color: C.b200)),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.all(8), child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(rp.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('₱${rp.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.b700)),
                        ])),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ]),
      ),
    );
  }

  Future<void> _messageSeller(Product p) async {
    if (p.seller == null) return;
    try {
      final conv = await ChatService.start(
        sellerId: p.seller!.id,
        productId: p.id,
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationId: conv.id,
          otherPartyName: p.seller!.name,
          productName: p.name,
        ),
      ));
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: C.danger));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start conversation.'),
            backgroundColor: C.danger));
    }
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: C.gray100, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: C.textPrimary),
    ),
  );
}
