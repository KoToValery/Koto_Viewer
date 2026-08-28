import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_math.dart';

/// Top banner displayed when CAD measurement mode is active.
/// Supports Distance, Area (with polygon vertices & snap), Angle, and Radius/Diameter.
class DxfMeasurementOverlay extends StatelessWidget {
  final DxfMeasureTool currentTool;
  final ValueChanged<DxfMeasureTool> onSelectTool;
  final DxfMeasurement? measurement;
  final bool snapEnabled;
  final VoidCallback onToggleSnap;
  final VoidCallback? onUndoPoint;
  final VoidCallback? onClosePolygon;
  final VoidCallback onClear;
  final VoidCallback onExit;

  const DxfMeasurementOverlay({
    super.key,
    required this.currentTool,
    required this.onSelectTool,
    required this.measurement,
    required this.snapEnabled,
    required this.onToggleSnap,
    this.onUndoPoint,
    this.onClosePolygon,
    required this.onClear,
    required this.onExit,
  });

  Color _getToolColor(DxfMeasureTool tool) {
    switch (tool) {
      case DxfMeasureTool.distance:
        return const Color(0xFFFF5252);
      case DxfMeasureTool.area:
        return const Color(0xFF00E5FF);
      case DxfMeasureTool.angle:
        return const Color(0xFFFFB300);
      case DxfMeasureTool.radius:
        return const Color(0xFF00E676);
      case DxfMeasureTool.annotation:
        return const Color(0xFFFF4081);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getToolColor(currentTool);

    // Build status and result string based on active tool
    String statusText = '';
    switch (currentTool) {
      case DxfMeasureTool.distance:
        if (measurement == null || measurement!.p1Cad == null) {
          statusText = '1. Tap 1st point';
        } else if (measurement!.p2Cad == null) {
          statusText = '2. Tap 2nd point';
        } else {
          final dist = DxfMath.formatDistance(measurement!.distance!);
          statusText = 'Distance: $dist m';
        }
        break;

      case DxfMeasureTool.area:
        final count = measurement?.areaPoints.length ?? 0;
        if (count == 0) {
          statusText = '1. Tap 1st vertex';
        } else if (count == 1) {
          statusText = '2. Tap 2nd vertex';
        } else if (count == 2) {
          statusText = '3. Tap 3rd vertex';
        } else {
          final area = DxfMath.calculatePolygonArea(measurement!.areaPoints);
          final perim = DxfMath.calculatePolygonPerimeter(measurement!.areaPoints, isClosed: true);
          statusText = 'Area: ${DxfMath.formatArea(area)} • Perim: ${DxfMath.formatDistance(perim)} m';
        }
        break;

      case DxfMeasureTool.angle:
        if (measurement == null || measurement!.angleVertex == null) {
          statusText = '1. Tap Vertex';
        } else if (measurement!.angleP1 == null) {
          statusText = '2. Tap Arm 1';
        } else if (measurement!.angleP2 == null) {
          statusText = '3. Tap Arm 2';
        } else {
          final angle = DxfMath.calculateAngleBetweenVectors(
            measurement!.angleVertex!,
            measurement!.angleP1!,
            measurement!.angleP2!,
          );
          statusText = 'Angle: ${angle.toStringAsFixed(1)}°';
        }
        break;

      case DxfMeasureTool.radius:
        if (measurement == null || measurement!.circleCenter == null) {
          final ptsCount = measurement?.circlePoints.length ?? 0;
          statusText = ptsCount > 0
              ? 'Point $ptsCount/3 for curve'
              : 'Tap circle/arc or 3 points';
        } else {
          final rStr = DxfMath.formatDistance(measurement!.radius!);
          final dStr = DxfMath.formatDistance(measurement!.radius! * 2.0);
          statusText = 'R: $rStr • Ø: $dStr m';
        }
        break;

      case DxfMeasureTool.annotation:
        if (measurement == null || measurement!.annotationTip == null) {
          statusText = '1. Tap feature for Arrow Tip';
        } else {
          statusText = '2. Tap position for Text Note';
        }
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 580),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2B).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: The 5 Tools (Full width, all 5 visible simultaneously without scrolling!)
          Row(
            children: DxfMeasureTool.values.map((tool) {
              final isSelected = tool == currentTool;
              final toolColor = _getToolColor(tool);
              final String shortLabel = switch (tool) {
                DxfMeasureTool.distance => 'Distance',
                DxfMeasureTool.area => 'Area',
                DxfMeasureTool.angle => 'Angle',
                DxfMeasureTool.radius => 'Radius',
                DxfMeasureTool.annotation => 'Note',
              };
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelectTool(tool),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? toolColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? toolColor : Colors.white12,
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tool.icon,
                            size: 15,
                            color: isSelected ? toolColor : Colors.white70,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shortLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 6),

          // Row 2: Controls & Contextual Actions (Snap, Reset, Undo, Close, Exit)
          Row(
            children: [
              // Snap Toggle
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggleSnap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: snapEnabled ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
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
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: snapEnabled ? const Color(0xFF00E5FF) : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Reset / Clear
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                tooltip: 'Clear measurement',
                onPressed: onClear,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              const Spacer(),

              // Contextual controls for Area mode (Undo vertex, Close polygon)
              if (currentTool == DxfMeasureTool.area &&
                  measurement != null &&
                  measurement!.areaPoints.isNotEmpty) ...[
                InkWell(
                  onTap: onUndoPoint,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.undo, size: 12, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Undo',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                if (measurement!.areaPoints.length >= 3 && !measurement!.isAreaClosed) ...[
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: onClosePolygon,
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: activeColor, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 13, color: activeColor),
                          const SizedBox(width: 3),
                          Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: activeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
              ],

              // Exit
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                tooltip: 'Exit measurement',
                onPressed: onExit,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row 3: Dedicated Full-Width Status / Result Readout Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: activeColor.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  currentTool.icon,
                  color: activeColor,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: (measurement != null && (measurement!.areaPoints.length >= 3 || measurement!.p2Cad != null))
                          ? activeColor
                          : Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
