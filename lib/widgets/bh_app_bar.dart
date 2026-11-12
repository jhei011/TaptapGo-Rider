import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

/// Token-based AppBar that adapts to light and dark brightness.
///
/// When [title] is the special sentinel value [BhAppBar.kWordmark], the title
/// area renders the TaptapGo branded wordmark instead of plain text — matching
/// the login screen style.
///
/// Implements [PreferredSizeWidget] so it can be used directly as
/// `Scaffold.appBar`.
class BhAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Pass this as [title] to show the TaptapGo wordmark instead of text.
  static const String kWordmark = '__taptapgo_wordmark__';

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

    final bgColor  = isDark ? kDarkSurfaceBase : kSurfaceBase;
    final fgColor  = isDark ? kDarkTextPrimary : kTextPrimary;
    final canPop   = Navigator.of(context).canPop();

    // Wordmark: "Taptap" bold navy + "Go" bold italic teal — same as login
    Widget titleWidget = title == kWordmark
        ? RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'Taptap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kBrand900,
                  letterSpacing: -0.3,
                ),
              ),
              TextSpan(
                text: 'Go',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: isDark ? const Color(0xFF5DB8BE) : kBrand600,
                  letterSpacing: -0.3,
                ),
              ),
            ]),
          )
        : Text(
            title,
            style: kHeadingMd.copyWith(color: fgColor),
          );

    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleTextStyle: kHeadingMd.copyWith(color: fgColor),
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
      title: titleWidget,
      actions: actions,
      bottom: bottom,
    );
  }
}
