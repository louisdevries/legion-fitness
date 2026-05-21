import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ExerciseMedia extends StatelessWidget {
  final String mediaUrl;
  final bool mediaReady;
  // When true the widget expands to fill its parent (landscape mode).
  // When false it renders at a fixed portrait height.
  final bool expand;
  // BoxFit to use when rendering the image.
  // Use BoxFit.contain (portrait) to show the full image without cropping.
  // Use BoxFit.cover (landscape) to fill the panel.
  final BoxFit fit;

  const ExerciseMedia({
    super.key,
    required this.mediaUrl,
    required this.mediaReady,
    this.expand = false,
    this.fit = BoxFit.cover,
  });

  bool get _hasValidUrl {
    if (mediaUrl.isEmpty) return false;
    try {
      final uri = Uri.parse(mediaUrl);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!mediaReady) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_hasValidUrl) {
      content = CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      content = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: expand
          ? SizedBox.expand(child: content)
          : SizedBox(height: 260, width: double.infinity, child: content),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 64, color: Colors.grey),
          SizedBox(height: 8),
          Text('No image available',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
