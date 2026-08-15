import 'package:flutter/material.dart';
import '../rendering/dxf_math.dart';
import '../rendering/dxf_painter.dart';

/// Top banner displayed when measurement mode is active.
class DxfMeasurementOverlay extends StatelessWidget {
  final DxfMeasurement? measurement;
  final bool snapEnabled;
  final VoidCallback onToggleSnap;
  final VoidCallback onClear;
  final VoidCallback onExit;

  const DxfMeasurementOverlay({
    super.key,
    required this.measurement,
    required this.snapEnabled,
    required this.onToggleSnap,
    required this.onClear,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    String statusText = 'Tap 1st point';
    if (measurement != null) {
      if (measurement!.p2Cad == null) {
        statusText = 'Tap 2nd point';
      } else {
        final dist = DxfMath.formatDistance(measurement!.distance!);
        statusText = 'L: $dist';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.straighten,
              color: Color(0xFFFF5252),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 10),

          // Snap to point toggle button
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onToggleSnap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: snapEnabled
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: snapEnabled ? const Color(0xFF00E5FF) : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grain,
                    size: 13,
                    color: snapEnabled ? const Color(0xFF00E5FF) : Colors.white54,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Snap ${snapEnabled ? "ON" : "OFF"}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: snapEnabled ? const Color(0xFF00E5FF) : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (measurement != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
              tooltip: 'Reset measurement',
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
            tooltip: 'Exit measure mode',
            onPressed: onExit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
