import 'package:flutter/material.dart';

/// Thin bottom panel shown while the user is in tap-to-build route mode.
///
/// Shows the running pin count, an undo button, a clear button, and a
/// save button. The screen owns all the state — this is presentation only.
class TapRouteBuilderPanel extends StatelessWidget {
  final int pinCount;
  final double routeKm;
  final bool isRouting;
  final bool canSave;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const TapRouteBuilderPanel({
    super.key,
    required this.pinCount,
    required this.routeKm,
    required this.isRouting,
    required this.canSave,
    required this.onUndo,
    required this.onClear,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hint = pinCount == 0
        ? 'Tap the map to drop your first pin (Start)'
        : pinCount == 1
        ? 'Tap again to drop the next pin'
        : '$pinCount pins · ${routeKm.toStringAsFixed(2)} km';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  pinCount == 0 ? Icons.touch_app : Icons.route,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isRouting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: 'Undo last pin',
                  onPressed: pinCount > 0 ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Clear all pins',
                  onPressed: pinCount > 0 ? onClear : null,
                  icon: const Icon(Icons.delete_outline),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: canSave && !isRouting ? onSave : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single waypoint pin marker, with an X badge to remove it.
class WaypointPin extends StatelessWidget {
  /// Letter or number to show inside the pin.
  final String label;

  /// First pin (Start) is green, last pin (End) is red, others blue.
  final Color color;

  final VoidCallback onRemove;

  const WaypointPin({
    super.key,
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Main pin body
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        // X badge in top-right
        Positioned(
          right: -8,
          top: -8,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}