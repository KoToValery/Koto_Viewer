import 'package:flutter/material.dart';
import '../rendering/dxf_math.dart';
import '../rendering/dxf_painter.dart';

/// Top banner displayed when measurement mode is active.
class DxfMeasurementOverlay extends StatelessWidget {
  final DxfMeasurement? measurement;
  final VoidCallback onClear;
  final VoidCallback onExit;

  const DxfMeasurementOverlay({
    super.key,
    required this.measurement,
    required this.onClear,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    String statusText = 'Tap first point on the drawing';
    if (measurement != null) {
      if (measurement!.p2Cad == null) {
        statusText = 'Tap second point to measure distance';
      } else {
        final dist = DxfMath.formatDistance(measurement!.distance!);
        final angle = DxfMath.formatAngle(measurement!.angleDeg!);
        statusText = 'Dist: $dist  |  ∠: $angle  |  ΔX: ${DxfMath.formatDistance(measurement!.deltaX!)}  ΔY: ${DxfMath.formatDistance(measurement!.deltaY!)}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.straighten,
              color: Color(0xFFFF5252),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          if (measurement != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              tooltip: 'Reset measurement',
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
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
