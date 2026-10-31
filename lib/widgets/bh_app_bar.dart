import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// Token-based AppBar that adapts to light and dark brightness.
///
/// Implements [PreferredSizeWidget] so it can be used directly as
/// `Scaffold.appBar`.
class BhAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BhAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
    this.bottom,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final bgColor   = isDark ? kDarkSurfaceBase : kSurfaceBase;
    final fgColor   = isDark ? kDarkTextPrimary : kTextPrimary;
    final titleStyle = kHeadingMd.copyWith(color: fgColor);

    final canPop = Navigator.of(context).canPop();

    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleTextStyle: titleStyle,
      shape: Border(
        bottom: BorderSide(
          color: isDark ? kDarkBorderSubtle : kBorderSubtle,
          width: 1,
        ),
      ),
      leading: showBack && canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(title),
      actions: actions,
      bottom: bottom,
    );
  }
}
