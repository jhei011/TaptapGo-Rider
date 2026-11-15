import 'package:flutter/widgets.dart';
import 'app_tokens.dart';

/// Keeps [AppPalette.dark] in step with the theme the app is showing (light, dark, or the
/// phone's setting), like TaptapShop's RebuildOnThemeChange.
///
/// Screens read colours straight from the tokens, so a theme change alone doesn't redraw them.
/// When the mode flips, this rebuilds everything below it, keeping each screen's state (the open
/// tab, scroll positions, what's typed).
class PaletteSync extends StatelessWidget {
  final bool dark;
  final Widget child;
  const PaletteSync({super.key, required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppPalette.dark != dark) {
      AppPalette.dark = dark;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }
      (context as Element).visitChildren(mark);
    }
    return child;
  }
}
