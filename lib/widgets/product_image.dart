import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';

/// Product image with fallback placeholder
class ProductImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key, this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();
    Widget img = CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      placeholder: (_, __) => Container(
        color: C.b50,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.b200)),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }

  Widget _placeholder() => Container(
    color: C.b50,
    child: const Center(child: Icon(Icons.image_outlined, color: C.b200, size: 36)),
  );
}
