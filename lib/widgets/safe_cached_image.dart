import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A safe wrapper around [CachedNetworkImage] that guards against
/// null or empty image URLs, which would otherwise throw
/// "No host specified in URI".
class SafeCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Guard: if URL is null or empty, show fallback immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
          );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder:
          (context, url) =>
              placeholder ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
      errorWidget:
          (context, url, error) =>
              this.errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: Icon(Icons.broken_image, color: Colors.grey[400]),
              ),
    );
  }
}
