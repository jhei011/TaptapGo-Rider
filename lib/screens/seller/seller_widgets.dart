// Shared widgets and enums used across all seller screens
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Navigation pages for the seller panel
enum SellerPage { dashboard, products, orders, profile }

/// Gradient AppBar used on every seller screen
class SellerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onMenuTap;
  final List<Widget>? actions;

  const SellerAppBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.transparent,
    flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: C.navbarGrad)),
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    leading: IconButton(
      icon: const Icon(Icons.menu, color: Colors.white),
      onPressed: onMenuTap,
    ),
    title: Text(title,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17)),
    actions: actions,
    elevation: 2,
    shadowColor: Colors.black38,
  );
}
