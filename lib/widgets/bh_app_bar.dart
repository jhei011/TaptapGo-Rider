import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_tokens.dart';
import 'taptapgo_brand.dart';
import 'teal_pattern.dart';

/// The TaptapGo header: the navy-to-teal gradient with its soft circle design, rounded bottom
/// corners and round "glass" icon buttons.
///
/// * Main tabs (`showBack: false`): the logo on the left, actions on the right, and the page's
///   name as a large title inside the header, with an optional [subtitle] under it.
/// * Pages opened on top (`showBack: true`): a back button and the page's name in one row.
/// * Pass [BhAppBar.kWordmark] as [title] for the logo row alone (the Home tab).
///
/// Implements [PreferredSizeWidget] so it can be used directly as `Scaffold.appBar`.
class BhAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Pass this as [title] to show only the logo row, with no page name.
  static const String kWordmark = '__taptapgo_wordmark__';

  /// Height of the large title block on main tabs (title, plus subtitle when given).
  static const double titleHeight = 46;
  static const double _subtitleHeight = 20;

  /// Space under the content, inside the rounded corners.
  static const double _bottomPad = 10;
  static const double _radius = 22;

  const BhAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.actions,
    this.bottom,
  });

  final String title;

  /// One short line under a main tab's title.
  final String? subtitle;

  /// Pages opened on top of another: shows a back arrow (when there is a page to go back to)
  /// and the title in the same row. Main tabs pass false.
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  bool get _hasTitle => title != kWordmark && title.trim().isNotEmpty;
  bool get _largeTitle => _hasTitle && !showBack;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight +
      (bottom?.preferredSize.height ?? 0) +
      (_largeTitle ? titleHeight + (subtitle != null ? _subtitleHeight : 0) : 0) +
      _bottomPad);

  @override
  Widget build(BuildContext context) {
    final canBack = showBack && Navigator.of(context).canPop();

    // Round, softly lit icon buttons (bell, back, log out…)
    final glass = IconButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      highlightColor: Colors.white.withValues(alpha: 0.18),
      fixedSize: const Size(40, 40),
      minimumSize: const Size(40, 40),
      padding: EdgeInsets.zero,
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.16))),
    );

    final Widget lead;
    if (_hasTitle && showBack) {
      // Back + the page's name
      lead = Row(children: [
        if (canBack) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
          ),
        ),
      ]);
    } else {
      lead = Row(children: [
        if (canBack) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
        ],
        // The logo takes the free space, so the actions (e.g. the bell) sit at the right edge
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: TaptapGoBrand()),
          ),
        ),
      ]);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.transparent,
        elevation: 3,
        shadowColor: const Color(0x660E2A38),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(_radius))),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: const TealDecoration(BoxDecoration(
            gradient: kHeaderGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(_radius)),
          )),
          child: SafeArea(
            bottom: false,
            child: IconButtonTheme(
              data: IconButtonThemeData(style: glass),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white, size: 22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: _bottomPad),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      height: kToolbarHeight,
                      child: Padding(
                        padding: EdgeInsets.only(left: canBack ? 10 : 16, right: 12),
                        child: Row(children: [
                          Expanded(child: lead),
                          for (final a in actions ?? const <Widget>[]) ...[const SizedBox(width: 8), a],
                        ]),
                      ),
                    ),
                    if (_largeTitle) _LargeTitle(title: title, subtitle: subtitle),
                    if (bottom != null) bottom!,
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's name as a large white title inside the header, fading up into place once.
class _LargeTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _LargeTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: BhAppBar.titleHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.1)),
                ),
              ),
            ),
            if (subtitle != null)
              SizedBox(
                height: BhAppBar._subtitleHeight,
                child: Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13)),
              ),
          ]),
        ),
      );
}
