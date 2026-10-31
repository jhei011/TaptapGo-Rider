import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/buyer_provider.dart';
import '../../providers/cart_provider.dart';
import 'buyer_home_screen.dart';
import 'buyer_orders_screen.dart';
import 'buyer_messages_screen.dart';
import 'buyer_profile_screen.dart';

class BuyerShell extends StatefulWidget {
  const BuyerShell({super.key});
  @override State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl  = TextEditingController();
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuyerProvider>().loadCategories();
      context.read<BuyerProvider>().loadProducts();
      context.read<CartProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final bp = context.read<BuyerProvider>();
    bp.applyFilter(
      search: q.isEmpty ? null : q,
      categoryId: bp.selectedCategory,
    );
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  void _selectCategory(int? categoryId) {
    _searchCtrl.clear();
    context.read<BuyerProvider>().applyFilter(categoryId: categoryId);
    // Switch to home tab if not already there
    if (_idx != 0) setState(() => _idx = 0);
    Navigator.pop(context); // close drawer
  }

  void _onTabTapped(int i) {
    setState(() => _idx = i);
    if (i == 1) context.read<BuyerProvider>().loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuyerProvider>();
    context.watch<CartProvider>();
    context.watch<AuthProvider>();

    return Scaffold(
      key: _scaffoldKey,

      // ── Left drawer — category sidebar ──────────────────────────────────
      drawer: _CategoryDrawer(
        bp: bp,
        onSelectCategory: _selectCategory,
        onClearFilters: () {
          _searchCtrl.clear();
          context.read<BuyerProvider>().clearFilters();
          if (_idx != 0) setState(() => _idx = 0);
          Navigator.pop(context);
        },
      ),

      // ── Body — IndexedStack keeps all tabs alive ─────────────────────
      body: IndexedStack(
        index: _idx,
        children: [
          BuyerHomeScreen(
            scaffoldKey: _scaffoldKey,
            searchCtrl: _searchCtrl,
            onSearch: _onSearch,
            onCartTap: () => Navigator.pushNamed(context, '/buyer/cart'),
          ),
          const BuyerOrdersScreen(),
          const BuyerMessagesScreen(),
          const BuyerProfileScreen(),
        ],
      ),

      // ── TikTok-style bottom navigation bar ────────────────────────────
      bottomNavigationBar: _BottomNav(
        currentIndex: _idx,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ── TikTok-style bottom nav ────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: C.border, width: 0.8)),
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined,     activeIcon: Icons.home,           label: 'Home',     index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders',   index: 1, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.chat_bubble_outline,   activeIcon: Icons.chat_bubble,  label: 'Messages', index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline,    activeIcon: Icons.person,         label: 'Profile',  index: 3, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: isActive ? C.b700 : C.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? C.b700 : C.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category Drawer ────────────────────────────────────────────────────────────
class _CategoryDrawer extends StatefulWidget {
  final BuyerProvider bp;
  final void Function(int? categoryId) onSelectCategory;
  final VoidCallback onClearFilters;

  const _CategoryDrawer({
    required this.bp,
    required this.onSelectCategory,
    required this.onClearFilters,
  });

  @override
  State<_CategoryDrawer> createState() => _CategoryDrawerState();
}

class _CategoryDrawerState extends State<_CategoryDrawer> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final bp      = widget.bp;
    final parents = bp.categories.where((c) => c.parentId == null).toList();
    final selected = bp.selectedCategory;

    // Auto-expand parent whose child is selected
    for (final p in parents) {
      if (p.children.any((c) => c.id == selected)) {
        _expanded.add(p.id);
      }
    }

    return Drawer(
      width: 280,
      child: Column(children: [

        // ── Header ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: C.sidebarGrad),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16, right: 16, bottom: 16,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Image.asset('assets/images/taptapgo-logo.png',
                  width: 30, height: 30),
              const SizedBox(width: 8),
              RichText(text: const TextSpan(children: [
                TextSpan(text: 'Taptap',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                TextSpan(text: 'Go',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic, color: Color(0xFF8FE0D2))),
              ])),
            ]),
            const SizedBox(height: 12),
            const Text('SHOP BY CATEGORY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: C.grad4, letterSpacing: 1.3)),
          ]),
        ),

        // ── Category list ──────────────────────────────────────────────
        Expanded(
          child: bp.categories.isEmpty
              ? const Center(child: CircularProgressIndicator(color: C.b600))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _ParentRow(
                      icon: Icons.storefront_outlined,
                      label: 'All Products',
                      isActive: selected == null,
                      hasChildren: false,
                      isExpanded: false,
                      onTap: widget.onClearFilters,
                      onChevronTap: null,
                    ),
                    const Divider(height: 1, color: C.border),
                    ...parents.map((parent) {
                      final hasChildren   = parent.children.isNotEmpty;
                      final isExpanded    = _expanded.contains(parent.id);
                      final isParentActive = selected == parent.id;
                      final isChildActive  = parent.children.any((c) => c.id == selected);
                      final isActive = isParentActive || isChildActive;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ParentRow(
                            icon: _faToIcon(parent.icon),
                            label: parent.name,
                            isActive: isActive,
                            hasChildren: hasChildren,
                            isExpanded: isExpanded,
                            onTap: () => widget.onSelectCategory(parent.id),
                            onChevronTap: hasChildren
                                ? () => setState(() {
                                    if (isExpanded) {
                                      _expanded.remove(parent.id);
                                    } else {
                                      _expanded.add(parent.id);
                                    }
                                  })
                                : null,
                          ),
                          if (hasChildren && isExpanded)
                            ...parent.children.map((child) => _ChildRow(
                              label: child.name,
                              isActive: selected == child.id,
                              onTap: () => widget.onSelectCategory(child.id),
                            )),
                          const Divider(height: 1, color: C.border),
                        ],
                      );
                    }),
                  ],
                ),
        ),
      ]),
    );
  }

  IconData _faToIcon(String? faClass) {
    switch (faClass) {
      case 'fa-motorcycle': case 'fa-motor-cycle': return Icons.two_wheeler;
      case 'fa-book': case 'fa-book-open': case 'fa-books': return Icons.menu_book_outlined;
      case 'fa-laptop': case 'fa-computer': case 'fa-microchip': case 'fa-tv': return Icons.devices_outlined;
      case 'fa-utensils': case 'fa-bowl-food': case 'fa-burger': case 'fa-pizza-slice': return Icons.restaurant_outlined;
      case 'fa-chair': case 'fa-couch': case 'fa-desk': return Icons.chair_outlined;
      case 'fa-spa': case 'fa-heart-pulse': case 'fa-stethoscope': case 'fa-pills': return Icons.spa_outlined;
      case 'fa-house': case 'fa-home': case 'fa-seedling': case 'fa-leaf': return Icons.home_outlined;
      case 'fa-gem': case 'fa-ring': case 'fa-watch': return Icons.watch_outlined;
      case 'fa-baby': case 'fa-baby-carriage': case 'fa-child': return Icons.child_care_outlined;
      case 'fa-person': case 'fa-male': case 'fa-person-walking': return Icons.person_outline;
      case 'fa-school': case 'fa-graduation-cap': case 'fa-pencil': return Icons.school_outlined;
      case 'fa-paw': case 'fa-dog': case 'fa-cat': return Icons.pets_outlined;
      case 'fa-dumbbell': case 'fa-person-running': case 'fa-football': case 'fa-basketball': return Icons.sports_outlined;
      case 'fa-shirt': case 'fa-vest': case 'fa-female': case 'fa-person-dress': return Icons.checkroom_outlined;
      case 'fa-store': case 'fa-shop': return Icons.storefront_outlined;
      case 'fa-car': case 'fa-truck': return Icons.directions_car_outlined;
      case 'fa-mobile': case 'fa-mobile-screen': case 'fa-phone': return Icons.phone_android_outlined;
      case 'fa-camera': case 'fa-image': return Icons.camera_alt_outlined;
      case 'fa-music': case 'fa-headphones': return Icons.headphones_outlined;
      case 'fa-gamepad': case 'fa-dice': return Icons.sports_esports_outlined;
      case 'fa-paint-brush': case 'fa-palette': return Icons.palette_outlined;
      case 'fa-suitcase': case 'fa-plane': return Icons.luggage_outlined;
      case 'fa-hammer': case 'fa-screwdriver': case 'fa-wrench': return Icons.build_outlined;
      default: return Icons.sell_outlined;
    }
  }
}

// ── Parent category row ────────────────────────────────────────────────────────
class _ParentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onChevronTap;

  const _ParentRow({
    required this.icon, required this.label, required this.isActive,
    required this.hasChildren, required this.isExpanded,
    required this.onTap, required this.onChevronTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isActive ? C.b50 : Colors.transparent,
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 3, height: 48,
          color: isActive ? C.b600 : Colors.transparent,
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: isActive ? C.b100 : const Color(0xFFEEF0EF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17,
                      color: isActive ? C.b700 : C.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? C.b800 : C.textPrimary,
                    ))),
              ]),
            ),
          ),
        ),
        if (hasChildren)
          InkWell(
            onTap: onChevronTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, size: 18,
                    color: isActive ? C.b600 : C.textSecondary),
              ),
            ),
          )
        else
          const SizedBox(width: 14),
      ]),
    );
  }
}

// ── Child category row ─────────────────────────────────────────────────────────
class _ChildRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ChildRow({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isActive ? C.b50 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 5, height: 5,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isActive ? C.b600 : C.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? C.b700 : C.textSecondary,
                ))),
            if (isActive) const Icon(Icons.check, size: 14, color: C.b600),
          ]),
        ),
      ),
    );
  }
}
