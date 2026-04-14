import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ExerciseMedia extends StatelessWidget {
  final String? mediaUrl;
  final bool mediaReady;

  const ExerciseMedia({
    super.key,
    required this.mediaUrl,
    required this.mediaReady,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: mediaReady && mediaUrl != null
          ? CachedNetworkImage(
        imageUrl: mediaUrl!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      )
          : const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}