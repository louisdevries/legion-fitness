import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_service.dart';

/// Result returned when the user successfully builds a route.
class BuiltRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final String summary;

  BuiltRoute({
    required this.points,
    required this.distanceMeters,
    required this.summary,
  });
}

/// Controller that lets the parent screen coordinate pin-drop mode with the
/// sheet. The parent owns this and passes it in.
class AddressBuilderController {
  final ValueNotifier<bool> awaitingPin = ValueNotifier(false);
  final ValueNotifier<String> pinPrompt = ValueNotifier('');

  void Function(LatLng point)? _onPicked;
  void Function()? _onCancelled;

  void requestPin({
    required String prompt,
    required void Function(LatLng) onPicked,
    required void Function() onCancelled,
  }) {
    pinPrompt.value = prompt;
    _onPicked = onPicked;
    _onCancelled = onCancelled;
    awaitingPin.value = true;
  }

  void deliverPick(LatLng point) {
    final cb = _onPicked;
    _onPicked = null;
    _onCancelled = null;
    awaitingPin.value = false;
    cb?.call(point);
  }

  void cancelPick() {
    final cb = _onCancelled;
    _onPicked = null;
    _onCancelled = null;
    awaitingPin.value = false;
    cb?.call();
  }

  void dispose() {
    awaitingPin.dispose();
    pinPrompt.dispose();
  }
}

class _Waypoint {
  final TextEditingController controller = TextEditingController();
  GeocodeResult? selected;
  List<GeocodeResult> suggestions = [];
  bool loading = false;
  Timer? debounce;

  void dispose() {
    controller.dispose();
    debounce?.cancel();
  }
}

class AddressRouteBuilderSheet extends StatefulWidget {
  final LatLng? userLocation;
  final AddressBuilderController controller;
  final Future<void> Function(BuiltRoute route) onRouteBuilt;
  final VoidCallback onClose;

  const AddressRouteBuilderSheet({
    super.key,
    required this.userLocation,
    required this.controller,
    required this.onRouteBuilt,
    required this.onClose,
  });

  @override
  State<AddressRouteBuilderSheet> createState() =>
      _AddressRouteBuilderSheetState();
}

class _AddressRouteBuilderSheetState extends State<AddressRouteBuilderSheet> {
  final List<_Waypoint> _waypoints = [_Waypoint(), _Waypoint()];
  bool _building = false;

  @override
  void dispose() {
    for (final w in _waypoints) {
      w.dispose();
    }
    super.dispose();
  }

  void _onQueryChanged(_Waypoint wp, String value) {
    wp.debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        wp.selected = null;
        wp.suggestions = [];
        wp.loading = false;
      });
      return;
    }
    setState(() => wp.loading = true);
    wp.debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await GeocodingService.autocomplete(
        value,
        proximity: widget.userLocation,
      );
      if (!mounted) return;
      setState(() {
        wp.suggestions = results;
        wp.loading = false;
      });
    });
  }

  void _selectSuggestion(_Waypoint wp, GeocodeResult result) {
    setState(() {
      wp.selected = result;
      wp.controller.text = result.displayName;
      wp.suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _addWaypoint() {
    setState(() => _waypoints.add(_Waypoint()));
  }

  void _removeWaypoint(int index) {
    if (_waypoints.length <= 2) return;
    setState(() {
      _waypoints[index].dispose();
      _waypoints.removeAt(index);
    });
  }

  String _labelForRow(int index) {
    final isFirst = index == 0;
    final isLast = index == _waypoints.length - 1;
    return isFirst
        ? "Start"
        : isLast
        ? "End"
        : "Stop $index";
  }

  void _requestPinForRow(int index) {
    final wp = _waypoints[index];
    final label = _labelForRow(index);
    FocusScope.of(context).unfocus();

    widget.controller.requestPin(
      prompt: "Tap a location for $label",
      onPicked: (point) async {
        setState(() => wp.loading = true);
        final result = await GeocodingService.reverseGeocode(point);
        if (!mounted) return;
        setState(() {
          wp.selected = result;
          wp.controller.text = result.displayName;
          wp.suggestions = [];
          wp.loading = false;
        });
      },
      onCancelled: () {},
    );
  }

  Future<void> _buildAndConfirm() async {
    final selected =
    _waypoints.where((w) => w.selected != null).toList();
    if (selected.length < 2) return;

    setState(() => _building = true);
    try {
      final waypointLatLngs =
      selected.map((w) => w.selected!.location).toList();
      final routed =
      await GeocodingService.routeThroughWaypoints(waypointLatLngs);

      if (routed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Couldn't build a route between those points. Try different addresses."),
          ),
        );
        return;
      }

      double meters = 0;
      for (int i = 0; i < routed.length - 1; i++) {
        meters += const Distance().as(
          LengthUnit.Meter,
          routed[i],
          routed[i + 1],
        );
      }

      final summary =
      selected.map((w) => w.selected!.shortName).join(' → ');

      await widget.onRouteBuilt(BuiltRoute(
        points: routed,
        distanceMeters: meters,
        summary: summary,
      ));
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyCount =
        _waypoints.where((w) => w.selected != null).length;
    final canBuild = readyCount >= 2 && !_building;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.awaitingPin,
      builder: (ctx, awaiting, _) {
        if (awaiting) {
          return _buildCompactPinPrompt();
        }
        return _buildFullSheet(readyCount, canBuild);
      },
    );
  }

  Widget _buildCompactPinPrompt() {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Colors.white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: widget.controller.pinPrompt,
                  builder: (ctx, prompt, _) => Text(
                    prompt,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.controller.cancelPick,
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullSheet(int readyCount, bool canBuild) {
    final mediaHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Use about 75% of the screen height; shrink if keyboard is up.
    final maxHeight = (mediaHeight * 0.75) - (keyboardHeight * 0.5);

    return Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight.clamp(280.0, mediaHeight * 0.85),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.alt_route),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Build route by address",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                      tooltip: "Close",
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Type to search, or use 📍 to tap a spot on the map.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: _waypoints.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == _waypoints.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: _addWaypoint,
                          icon: const Icon(Icons.add),
                          label: const Text("Add waypoint"),
                        ),
                      );
                    }
                    return _buildWaypointRow(i);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canBuild ? _buildAndConfirm : null,
                    icon: _building
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.check),
                    label: Text(
                      _building
                          ? "Building..."
                          : (readyCount < 2
                          ? "Pick at least 2 addresses"
                          : "Build & save route ($readyCount stops)"),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointRow(int index) {
    final wp = _waypoints[index];
    final isFirst = index == 0;
    final isLast = index == _waypoints.length - 1;
    final label = _labelForRow(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst
                      ? Colors.green
                      : isLast
                      ? Colors.red
                      : Colors.blue,
                ),
                child: Text(
                  isFirst
                      ? "A"
                      : isLast
                      ? "B"
                      : "$index",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: "Pick on map",
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_location_alt_outlined,
                    color: Colors.blue),
                onPressed: () => _requestPinForRow(index),
              ),
              if (_waypoints.length > 2)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () => _removeWaypoint(index),
                ),
            ],
          ),
          TextField(
            controller: wp.controller,
            decoration: InputDecoration(
              hintText: "Search address, or use 📍 to tap on map",
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: wp.loading
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child:
                  CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : (wp.selected != null
                  ? const Icon(Icons.check_circle,
                  color: Colors.green)
                  : null),
            ),
            onChanged: (v) {
              if (wp.selected != null) {
                wp.selected = null;
              }
              _onQueryChanged(wp, v);
            },
          ),
          if (wp.suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: wp.suggestions
                    .map(
                      (s) => InkWell(
                    onTap: () => _selectSuggestion(wp, s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}