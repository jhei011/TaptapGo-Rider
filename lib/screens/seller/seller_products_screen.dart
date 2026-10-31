import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/seller_provider.dart';
import '../../models/product.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grad_button.dart';
import 'seller_shell.dart';
import 'seller_widgets.dart';

class SellerProductsScreen extends StatefulWidget {
  final SellerShellState? shell;
  const SellerProductsScreen({super.key, this.shell});
  @override State<SellerProductsScreen> createState() => _SellerProductsState();
}

class _SellerProductsState extends State<SellerProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SellerProvider>().loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SellerProvider>();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: SellerAppBar(
        title: 'My Products',
        onMenuTap: () {
          widget.shell?.openDrawer();
          if (widget.shell == null) Scaffold.of(context).openDrawer();
        },
      ),
      body: sp.loadingProducts
          ? const LoadingCenter()
          : Column(children: [
              // ── Header bar: count + Add Product button ─────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('My Products',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: C.textPrimary)),
                      Text('Manage your product listings',
                          style: TextStyle(
                              fontSize: 12, color: C.textSecondary)),
                    ]),
                    GradButton(
                      label: 'Add Product',
                      icon: Icons.add,
                      height: 38,
                      width: 130,
                      onPressed: () => Navigator.pushNamed(
                          context, '/seller/products/add').then((_) {
                        sp.loadProducts();
                        sp.loadDashboard();
                      }),
                    ),
                  ],
                ),
              ),

              // ── Product list ────────────────────────────────────────
              Expanded(
                child: sp.products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products yet',
                        subtitle: 'Start by adding your first product',
                        buttonLabel: 'Add Product',
                        onButton: () => Navigator.pushNamed(
                            context, '/seller/products/add').then((_) =>
                            sp.loadProducts()),
                      )
                    : RefreshIndicator(
                        onRefresh: sp.loadProducts,
                        color: C.b600,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: sp.products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ProductCard(
                            product: sp.products[i],
                            onEdit: () => Navigator.pushNamed(
                                context,
                                '/seller/products/edit',
                                arguments: sp.products[i].id).then((_) =>
                                sp.loadProducts()),
                            onDelete: () =>
                                _confirmDelete(context, sp.products[i], sp),
                          ),
                        ),
                      ),
              ),
            ]),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, Product p, SellerProvider sp) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      final success = await sp.deleteProduct(p.id);
      if (ctx.mounted && !success) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(sp.error ?? 'Failed'),
            backgroundColor: C.danger));
      }
    }
  }
}

// ── Product card ───────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060E2A38), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image
        ClipRRect(
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(14)),
          child: SizedBox(
            width: 90, height: 90,
            child: p.image != null
                ? CachedNetworkImage(
                    imageUrl: p.image!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: C.b50),
                    errorWidget: (_, __, ___) => Container(
                        color: C.b50,
                        child: const Icon(Icons.image_outlined,
                            color: C.b200, size: 28)))
                : Container(
                    color: C.b50,
                    child: const Icon(Icons.image_outlined,
                        color: C.b200, size: 28)),
          ),
        ),

        // Info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: C.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  StatusPill(status: p.status, small: true),
                ]),
                const SizedBox(height: 4),
                if (p.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: C.b50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(p.category!.name,
                        style: const TextStyle(
                            fontSize: 10,
                            color: C.b700,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 4),
                Text('₱${p.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: C.b700,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(
                    p.stock <= 5
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    size: 12,
                    color: p.stock <= 5 ? C.danger : C.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text('${p.stock} in stock',
                      style: TextStyle(
                          fontSize: 11,
                          color: p.stock <= 5 ? C.danger : C.textSecondary,
                          fontWeight: p.stock <= 5
                              ? FontWeight.w600
                              : FontWeight.w400)),
                ]),
              ],
            ),
          ),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            // Edit
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: C.b50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 16, color: C.b700),
              ),
            ),
            const SizedBox(height: 8),
            // Delete
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: C.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: C.danger),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
