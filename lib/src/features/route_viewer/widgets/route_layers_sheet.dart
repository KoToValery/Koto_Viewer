import 'package:flutter/material.dart';

class RouteLayersSettings {
  final bool showHikingTrails;
  final bool showCyclingTrails;
  final double trackWidth;
  final double trackOpacity;

  const RouteLayersSettings({
    this.showHikingTrails = true,
    this.showCyclingTrails = false,
    this.trackWidth = 4.0,
    this.trackOpacity = 0.9,
  });

  RouteLayersSettings copyWith({
    bool? showHikingTrails,
    bool? showCyclingTrails,
    double? trackWidth,
    double? trackOpacity,
  }) {
    return RouteLayersSettings(
      showHikingTrails: showHikingTrails ?? this.showHikingTrails,
      showCyclingTrails: showCyclingTrails ?? this.showCyclingTrails,
      trackWidth: trackWidth ?? this.trackWidth,
      trackOpacity: trackOpacity ?? this.trackOpacity,
    );
  }
}

class RouteLayersSheet extends StatefulWidget {
  final RouteLayersSettings settings;
  final ValueChanged<RouteLayersSettings> onChanged;

  const RouteLayersSheet({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  static Future<RouteLayersSettings?> show({
    required BuildContext context,
    required RouteLayersSettings currentSettings,
    required ValueChanged<RouteLayersSettings> onChanged,
  }) {
    return showModalBottomSheet<RouteLayersSettings>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RouteLayersSheet(
        settings: currentSettings,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RouteLayersSheet> createState() => _RouteLayersSheetState();
}

class _RouteLayersSheetState extends State<RouteLayersSheet> {
  late RouteLayersSettings _current;

  @override
  void initState() {
    super.initState();
    _current = widget.settings;
  }

  void _update(RouteLayersSettings updated) {
    setState(() => _current = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.layers_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Map Overlays & Style',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(_current),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Base Map Info Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terrain_rounded, size: 20, color: Color(0xFF15803D)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Base: OpenTopoMap',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Topographic contours, hillshading, peaks & mountain relief',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Hiking Trails Switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.hiking_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              title: const Text(
                'Hiking Trails & Markings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Waymarked Trails: official mountain route colors & codes from OSM',
                style: TextStyle(fontSize: 12),
              ),
              value: _current.showHikingTrails,
              onChanged: (val) => _update(_current.copyWith(showHikingTrails: val)),
            ),
            const Divider(height: 16),

            // 2. Cycling Trails Switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.directions_bike_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              title: const Text(
                'MTB & Cycling Routes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Waymarked Trails: dedicated mountain bike and cycling network',
                style: TextStyle(fontSize: 12),
              ),
              value: _current.showCyclingTrails,
              onChanged: (val) => _update(_current.copyWith(showCyclingTrails: val)),
            ),
            const Divider(height: 16),

            // 3. Track Width Slider
            Row(
              children: [
                const Icon(Icons.line_weight_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Track Line Width', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_current.trackWidth.toStringAsFixed(1)} px', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Slider(
              value: _current.trackWidth,
              min: 2.0,
              max: 8.0,
              divisions: 12,
              onChanged: (val) => _update(_current.copyWith(trackWidth: val)),
            ),

            // 4. Track Opacity Slider
            Row(
              children: [
                const Icon(Icons.opacity_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Track Opacity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${(_current.trackOpacity * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Slider(
              value: _current.trackOpacity,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              onChanged: (val) => _update(_current.copyWith(trackOpacity: val)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
