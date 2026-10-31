 import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/buyer_provider.dart';
import '../../models/product.dart';
import '../../widgets/taptap_navbar.dart';
import '../../widgets/empty_state.dart';

class BuyerHomeScreen extends StatefulWidget {
  // Props passed down from BuyerShell so search/cart are coordinated
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final TextEditingController? searchCtrl;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onCartTap;

  const BuyerHomeScreen({
    super.key,
    this.scaffoldKey,
    this.searchCtrl,
    this.onSearch,
    this.onCartTap,
  });

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHomeScreen> {
  // Fallback controllers when used standalone (e.g. direct route)
  late final TextEditingController _localSearchCtrl;
  final _scrollCtrl = ScrollController();
  bool _isLastPixel = false;

  TextEditingController get _searchCtrl =>
      widget.searchCtrl ?? _localSearchCtrl;

  @override
  void initState() {
    super.initState();
    _localSearchCtrl = TextEditingController();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _localSearchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only call loadNextPage when we actually reach the bottom edge
    final pos = _scrollCtrl.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 200;
    if (atBottom && !_isLastPixel) {
      _isLastPixel = true;
      context.read<BuyerProvider>().loadNextPage();
    } else if (!atBottom) {
      _isLastPixel = false;
    }
  }

  void _search(String q) {
    if (widget.onSearch != null) {
      widget.onSearch!(q);
    } else {
      final bp = context.read<BuyerProvider>();
      bp.applyFilter(
        search: q.isEmpty ? null : q,
        categoryId: bp.selectedCategory,
      );
    }
  }

  void _clearFilters() {
    _searchCtrl.clear();
    context.read<BuyerProvider>().clearFilters();
  }

  // Derive the page title exactly like the website:
  // "All Products" | "{search query}" | "{category name}"
  String _pageTitle(BuyerProvider bp) {
    if (bp.search?.isNotEmpty == true) return '"${bp.search}"';
    if (bp.selectedCategory != null) {
      final cat = bp.categories
          .expand((c) => [c, ...c.children])
          .where((c) => c.id == bp.selectedCategory)
          .firstOrNull;
      return cat?.name ?? 'Products';
    }
    return 'All Products';
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuyerProvider>();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: BuyerNavBar(
        searchCtrl: _searchCtrl,
        onSearch: _search,
        onCartTap: widget.onCartTap ??
            () => Navigator.pushNamed(context, '/buyer/cart'),
        onMenuTap: () {
          if (widget.scaffoldKey?.currentState != null) {
            widget.scaffoldKey!.currentState!.openDrawer();
          } else {
            Scaffold.of(context).openDrawer();
          }
        },
      ),
      body: Column(children: [
        // ── Page title + product count ────────────────────────────────────
        _PageHeader(
          title: _pageTitle(bp),
          count: bp.total,
          loading: bp.loadingProducts,
          hasFilters: bp.selectedCategory != null ||
              (bp.search?.isNotEmpty ?? false),
        ),

        // ── Product grid ─────────────────────────────────────────────────
        Expanded(child: _buildGrid(bp)),
      ]),
    );
  }

  Widget _buildGrid(BuyerProvider bp) {
    if (bp.loadingProducts) return const LoadingCenter();

    if (bp.productError != null) {
      return ErrorRetry(
        message: bp.productError!,
        onRetry: () => bp.loadProducts(
          search: bp.search,
          categoryId: bp.selectedCategory,
        ),
      );
    }

    if (bp.products.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products found',
        subtitle: 'Try a different search or category',
        buttonLabel: 'Clear Filters',
        onButton: _clearFilters,
      );
    }

    return RefreshIndicator(
      color: C.b600,
      onRefresh: () => bp.loadProducts(
        search: bp.search,
        categoryId: bp.selectedCategory,
      ),
      child: GridView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: bp.products.length + (bp.loadingMore ? 2 : 0),
        itemBuilder: (_, i) {
          if (i >= bp.products.length) {
            return const Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: C.b600),
              ),
            );
          }
          return _ProductCard(product: bp.products[i]);
        },
      ),
    );
  }
}

// ── Page header — "All Products / 2 product(s) found" ─────────────────────────
class _PageHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool loading;
  final bool hasFilters;

  const _PageHeader({
    required this.title,
    required this.count,
    required this.loading,
    required this.hasFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: C.textPrimary,
            ),
          ),
          // Only show product count when a filter or search is active
          if (hasFilters) ...[
            const SizedBox(height: 2),
            Text(
              loading
                  ? 'Loading...'
                  : '$count product${count != 1 ? 's' : ''} found',
              style: const TextStyle(
                fontSize: 12,
                color: C.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Product card — matches website product card layout ─────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  // Static decoration so it's not rebuilt on every frame
  static const _decoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(12)),
    border: Border.fromBorderSide(BorderSide(color: C.border)),
    boxShadow: [
      BoxShadow(
          color: Color(0x080E2A38), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/buyer/product', arguments: p.id),
      child: Container(
        decoration: _decoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Product image ──────────────────────────────────────────────
          Expanded(
            child: Stack(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: p.image != null
                    ? CachedNetworkImage(
                        imageUrl: p.image!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: C.b50,
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: C.b200))),
                        errorWidget: (_, __, ___) => Container(
                            color: C.b50,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined,
                                    color: C.b200, size: 40),
                                SizedBox(height: 6),
                                Text('No Image',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: C.b200,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      )
                    : Container(
                        color: C.b50,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined,
                                color: C.b200, size: 40),
                            SizedBox(height: 6),
                            Text('No Image',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: C.b200,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
              ),

              // Category pill overlay (top-left) — matches website
              if (p.category != null)
                Positioned(
                  top: 7, left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.b900.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.category!.name,
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Stock dot indicator (top-right) — green/amber/red
              Positioned(
                top: 7, right: 7,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _stockColor(p),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ]),
          ),

          // ── Product info ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                p.name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '₱${p.price.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: C.b700),
              ),
              const SizedBox(height: 2),
              Text(
                p.stock == 0
                    ? 'Out of stock'
                    : '${p.stock} left in stock',
                style: TextStyle(
                    fontSize: 10,
                    color: p.stock == 0
                        ? C.danger
                        : p.lowStock
                            ? C.warn
                            : C.textMuted),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Color _stockColor(Product p) {
    if (p.stock == 0) return C.danger;
    if (p.lowStock) return C.warn;
    return C.delivered;
  }
}
