import 'package:flutter/material.dart';

/// The TaptapGo logo with "Taptap" in white and "Go" in mint, for the navy header — the
/// rider-app counterpart of TaptapShop's TaptapBrand, using the same wordmark as the login screen.
class TaptapGoBrand extends StatelessWidget {
  final double logoSize;
  const TaptapGoBrand({super.key, this.logoSize = 32});

  static const logoAsset = 'assets/images/taptapgo_app_icon.png';

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'TaptapGo',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(logoSize * 0.22),
            child: Image.asset(logoAsset, width: logoSize, height: logoSize, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(children: [
              TextSpan(text: 'Taptap', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              // Same "Go" as the login screen's wordmark
              TextSpan(text: 'Go', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF8FE0D2), fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
      );
}
