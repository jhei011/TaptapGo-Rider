import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grad_button.dart';

class BuyerCartScreen extends StatelessWidget {
  const BuyerCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: C.navbarGrad),
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: GestureDetector(
          onTap: () => Navigator.pushNamedAndRemoveUntil(
              context, '/buyer', (_) => false),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/taptapgo-logo.png',
                width: 31, height: 31),
            const SizedBox(width: 7),
            RichText(
              text: const TextSpan(children: [
                TextSpan(text: 'Taptap',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                TextSpan(text: 'Shop',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: C.grad4)),
              ]),
            ),
          ]),
        ),
        elevation: 2,
        shadowColor: Colors.black38,
      ),
      // ── Order Summary floats at the bottom ─────────────────────────────
      bottomSheet: cart.isEmpty || cart.loading ? null : Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                offset: Offset(0, -4))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Summary',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: C.textPrimary)),
            const SizedBox(height: 8),
            ...cart.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.product?.name ?? 'Unknown'} ×${item.quantity}',
                      style: const TextStyle(
                          fontSize: 12, color: C.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('₱${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            )),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: C.heroGrad,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85))),
                  Text('₱${cart.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GradButton(
              label: 'Proceed to Checkout',
              icon: Icons.credit_card_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, '/buyer/checkout'),
            ),
          ],
        ),
      ),
      body: cart.loading
          ? const LoadingCenter()
          : cart.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  subtitle: 'Browse products and add items to your cart',
                  buttonLabel: 'Start Shopping',
                  onButton: () => Navigator.pop(context),
                )
              : Column(children: [
                  // ── Scrollable cart items ──────────────────────────
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cart.load,
                      color: C.b600,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 280),
                        children: [
                          // "My Cart (X item/s)" header + Clear Cart
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.shopping_cart_outlined,
                                    size: 20, color: C.b600),
                                const SizedBox(width: 8),
                                const Text('My Cart',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: C.textPrimary)),
                                const SizedBox(width: 6),
                                Text('(${cart.items.length} item/s)',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: C.textSecondary)),
                              ]),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmClear(context, cart),
                                icon: const Icon(Icons.delete_outline,
                                    size: 15, color: C.danger),
                                label: const Text('Clear Cart',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: C.danger,
                                        fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Cart item cards
                          ...cart.items.map((item) {
                            final p = item.product;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: C.border),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x060E2A38),
                                      blurRadius: 8,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Image
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 68, height: 68,
                                      child: p?.image != null
                                          ? CachedNetworkImage(
                                              imageUrl: p!.image!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                      color: C.b50,
                                                      child: const Icon(
                                                          Icons
                                                              .image_outlined,
                                                          color: C.b200)),
                                            )
                                          : Container(
                                              color: C.b50,
                                              child: const Icon(
                                                  Icons.image_outlined,
                                                  color: C.b200)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p?.name ?? 'Unknown',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: C.textPrimary),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        if (p?.category != null)
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: C.b50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      20),
                                            ),
                                            child: Text(
                                                p!.category!.name,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: C.b700,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '₱${(p?.price ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: C.b700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Qty + subtotal + remove
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            cart.remove(item.id),
                                        child: const Icon(Icons.close,
                                            size: 18, color: C.danger),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Subtotal',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: C.textMuted)),
                                      Text(
                                        '₱${item.subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: C.textPrimary),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: C.border),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _qtyBtn(Icons.remove, () {
                                              if (item.quantity > 1) {
                                                cart.update(item.id,
                                                    item.quantity - 1);
                                              } else {
                                                cart.remove(item.id);
                                              }
                                            }),
                                            Container(
                                              width: 32,
                                              height: 30,
                                              alignment: Alignment.center,
                                              decoration:
                                                  const BoxDecoration(
                                                border: Border.symmetric(
                                                  vertical: BorderSide(
                                                      color: C.border),
                                                ),
                                              ),
                                              child: Text(
                                                  '${item.quantity}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight
                                                          .w700)),
                                            ),
                                            _qtyBtn(Icons.add, () {
                                              final max =
                                                  p?.stock ?? 99;
                                              if (item.quantity < max) {
                                                cart.update(item.id,
                                                    item.quantity + 1);
                                              }
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      color: C.gray100,
      child: Icon(icon, size: 14, color: C.textPrimary),
    ),
  );

  Future<void> _confirmClear(BuildContext ctx, CartProvider cart) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear',
                  style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok == true) cart.clear();
  }
}
