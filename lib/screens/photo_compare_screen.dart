import 'dart:io';
import 'package:flutter/material.dart';

class PhotoCompareScreen extends StatefulWidget {
  final File before;
  final File after;

  const PhotoCompareScreen({
    super.key,
    required this.before,
    required this.after,
  });

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  double slider = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Progress')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                slider += details.delta.dx / constraints.maxWidth;
                slider = slider.clamp(0.0, 1.0);
              });
            },
            child: Stack(
              children: [
                // BEFORE (full background)
                Positioned.fill(
                  child: Image.file(
                    widget.before,
                    fit: BoxFit.cover,
                  ),
                ),

                // AFTER (clipped)
                Positioned.fill(
                  child: ClipPath(
                    clipper: _CompareClipper(slider),
                    child: Image.file(
                      widget.after,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Slider line
                Positioned(
                  left: slider * constraints.maxWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: Colors.white),
                ),

                // Handle
                Positioned(
                  left: slider * constraints.maxWidth - 12,
                  top: constraints.maxHeight / 2 - 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompareClipper extends CustomClipper<Path> {
  final double slider;

  _CompareClipper(this.slider);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTRB(
        0,
        0,
        size.width * slider,
        size.height,
      ));
  }

  @override
  bool shouldReclip(_CompareClipper oldClipper) {
    return oldClipper.slider != slider;
  }
}