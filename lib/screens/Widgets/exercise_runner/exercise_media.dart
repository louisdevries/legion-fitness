import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ExerciseMedia extends StatelessWidget {
  final String mediaUrl;
  final bool mediaReady;

  const ExerciseMedia({
    super.key,
    required this.mediaUrl,
    required this.mediaReady,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: !mediaReady
            ? const Center(child: CircularProgressIndicator())
            : _hasValidUrl
            ? CachedNetworkImage(
          imageUrl: mediaUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => _placeholder(),
        )
            : _placeholder(),
      ),
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