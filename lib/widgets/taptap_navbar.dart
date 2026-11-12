import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/cart_provider.dart';

/// Buyer-facing navbar — matches the Laravel .navbar exactly:
/// [☰ logo TaptapGo] [──── search ────] [🛒 Cart] [👤 name ▾]
class BuyerNavBar extends StatefulWidget implements PreferredSizeWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onCartTap;
  final VoidCallback? onMenuTap; // burger icon → opens Drawer
  final Widget? bottom;
  final double bottomHeight;

  const BuyerNavBar({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.onCartTap,
    this.onMenuTap,
    this.bottom,
    this.bottomHeight = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + bottomHeight);

  @override
  State<BuyerNavBar> createState() => _BuyerNavBarState();
}

class _BuyerNavBarState extends State<BuyerNavBar> {
  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().count;

    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: C.navbarGrad),
      ),
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(children: [
        // ── Burger menu ──────────────────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 22),
          onPressed: widget.onMenuTap ?? () => Scaffold.of(context).openDrawer(),
          tooltip: 'Categories',
        ),

        // ── Search bar ───────────────────────────────────────────────────
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F4),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: widget.searchCtrl,
                  onSubmitted: widget.onSearch,
                  style: const TextStyle(color: C.textPrimary, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: C.textSecondary, fontSize: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => widget.onSearch(widget.searchCtrl.text),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 28, height: 28,
                  decoration: const BoxDecoration(
                    color: C.b600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search, color: Colors.white, size: 15),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 4),
      ]),
      actions: [
        // ── Cart ──────────────────────────────────────────────────────────
        IconButton(
          onPressed: widget.onCartTap,
          tooltip: 'Cart',
          icon: Badge(
            isLabelVisible: cartCount > 0,
            label: Text('$cartCount',
                style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: C.danger,
            child: const Icon(Icons.shopping_cart_outlined,
                color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 4),
      ],
      elevation: 2,
      shadowColor: Colors.black38,
    );
  }
}


/// Simple gradient navbar for non-buyer screens (seller, courier, auth)
class TaptapNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottom;
  final double bottomHeight;

  const TaptapNavBar({
    super.key,
    this.title = 'TaptapGo',
    this.actions,
    this.showBack = true,
    this.bottom,
    this.bottomHeight = 0,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + bottomHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: C.navbarGrad),
      ),
      leading: showBack && Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      automaticallyImplyLeading: false,
      title: RichText(
        text: const TextSpan(children: [
          TextSpan(
            text: 'Taptap',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          TextSpan(
            text: 'Go',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: Color(0xFFCDEAE7), // C.grad4 — matches TaptapShop "Shop" color
              letterSpacing: 0.2,
            ),
          ),
        ]),
      ),
      actions: actions,
      bottom: bottom != null
          ? PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: bottom!,
            )
          : null,
      elevation: 2,
      shadowColor: Colors.black38,
    );
  }
}
