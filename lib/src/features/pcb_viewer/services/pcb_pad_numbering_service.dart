import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pcb_models.dart';

/// Intelligent Pad & Pin Numbering Engine for PCB layouts.
/// Automatically detects component geometries and assigns accurate pin numbers.
class PcbPadNumberingService {
  const PcbPadNumberingService._();

  /// Enriches all layers in [PcbProject] with pad numbers.
  static PcbProject assignPadNumbers(PcbProject project) {
    // 1. Collect all unique flash pad positions and apertures across all copper and drill layers
    // Keying by physical coordinate avoids duplicate numbering for pads spanning multiple layers.
    final Map<String, _PadRef> uniquePads = {};

    for (int layerIdx = 0; layerIdx < project.layers.length; layerIdx++) {
      final layer = project.layers[layerIdx];
      final doc = layer.document;
      final isCopper = doc.layerType == PcbLayerType.copperTop ||
          doc.layerType == PcbLayerType.copperBottom ||
          doc.layerType == PcbLayerType.solderMaskTop ||
          doc.layerType == PcbLayerType.solderMaskBottom ||
          doc.layerType == PcbLayerType.generic;

      if (!isCopper) continue;

      for (int cmdIdx = 0; cmdIdx < doc.commands.length; cmdIdx++) {
        final cmd = doc.commands[cmdIdx];
        if (cmd.type == PcbCommandType.flash && cmd.isDark && cmd.aperture != null) {
          final posKey = _padKey(cmd.p1);
          if (!uniquePads.containsKey(posKey)) {
            uniquePads[posKey] = _PadRef(
              position: cmd.p1,
              aperture: cmd.aperture!,
              existingPinNumber: cmd.pinNumber,
            );
          } else if (cmd.pinNumber != null && uniquePads[posKey]!.existingPinNumber == null) {
            uniquePads[posKey] = uniquePads[posKey]!.copyWith(existingPinNumber: cmd.pinNumber);
          }
        }
      }
    }

    if (uniquePads.isEmpty) {
      return project;
    }

    final allPads = uniquePads.values.toList();

    // 2. Cluster pads by geometric proximity
    final Map<String, String> assignedPadNumbers = {};
    _clusterAndNumberPads(allPads, assignedPadNumbers);

    // 3. Update layers with newly assigned pin numbers and drill holes
    final updatedLayers = <PcbLayerItem>[];
    for (int layerIdx = 0; layerIdx < project.layers.length; layerIdx++) {
      final layer = project.layers[layerIdx];
      final doc = layer.document;

      bool layerModified = false;
      final updatedCmds = <PcbCommand>[];

      for (int cmdIdx = 0; cmdIdx < doc.commands.length; cmdIdx++) {
        final cmd = doc.commands[cmdIdx];
        if (cmd.type == PcbCommandType.flash) {
          final posKey = _padKey(cmd.p1);
          final pinNum = assignedPadNumbers[posKey] ?? cmd.pinNumber;
          if (pinNum != cmd.pinNumber) {
            layerModified = true;
            updatedCmds.add(cmd.copyWithPinNumber(pinNum));
          } else {
            updatedCmds.add(cmd);
          }
        } else {
          updatedCmds.add(cmd);
        }
      }

      final updatedDrills = <PcbDrillHole>[];
      for (final drill in doc.drillHoles) {
        String? matchedPin;
        double closestDist = 0.25; // 0.25 mm tolerance
        for (final pad in allPads) {
          final d = (pad.position - drill.position).distance;
          if (d < closestDist) {
            closestDist = d;
            matchedPin = assignedPadNumbers[_padKey(pad.position)] ?? pad.existingPinNumber;
          }
        }
        final newPin = matchedPin ?? drill.pinNumber ?? '1';
        if (newPin != drill.pinNumber) {
          layerModified = true;
        }
        updatedDrills.add(drill.copyWith(pinNumber: newPin));
      }

      if (layerModified) {
        updatedLayers.add(PcbLayerItem(
          fileName: layer.fileName,
          type: layer.type,
          document: PcbDocument(
            fileName: doc.fileName,
            layerType: doc.layerType,
            commands: updatedCmds,
            drillHoles: updatedDrills,
            boundingBox: doc.boundingBox,
          ),
          customColor: layer.customColor,
          isVisible: layer.isVisible,
          opacity: layer.opacity,
          order: layer.order,
        ));
      } else {
        updatedLayers.add(layer);
      }
    }

    return PcbProject(
      projectName: project.projectName,
      sourcePath: project.sourcePath,
      layers: updatedLayers,
      boundingBox: project.boundingBox,
      bomEntries: project.bomEntries,
      images: project.images,
      archiveFiles: project.archiveFiles,
      viewSide: project.viewSide,
    );
  }

  static String _padKey(Offset pos) => '${pos.dx.toStringAsFixed(3)}_${pos.dy.toStringAsFixed(3)}';

  static void _clusterAndNumberPads(List<_PadRef> pads, Map<String, String> assigned) {
    final int n = pads.length;
    final List<bool> visited = List.filled(n, false);

    for (int i = 0; i < n; i++) {
      if (visited[i]) continue;

      // Find all connected pads in this component cluster (distance <= 2.6mm)
      // Standard pitch is 2.54mm. Using 2.6mm to capture DIP/headers but avoid
      // merging completely distinct dense components that are slightly further.
      final List<int> clusterIndices = [i];
      visited[i] = true;

      int head = 0;
      while (head < clusterIndices.length) {
        final currIdx = clusterIndices[head++];
        final pCurr = pads[currIdx].position;

        for (int j = 0; j < n; j++) {
          if (visited[j]) continue;
          final dist = (pads[j].position - pCurr).distance;
          if (dist <= 2.7) {
            visited[j] = true;
            clusterIndices.add(j);
          }
        }
      }

      final clusterPads = clusterIndices.map((idx) => pads[idx]).toList();

      // If the cluster has over 40 pins and isn't distinctly a header, it's likely a merged blob
      // from extreme density. We just leave it without assigned numbers to avoid random 1-150 guessing.
      if (clusterPads.length > 50) {
        for (final p in clusterPads) {
          if (p.existingPinNumber != null) {
            assigned[_padKey(p.position)] = p.existingPinNumber!;
          }
        }
        continue;
      }

      // Assign numbers based on cluster size and geometry
      if (clusterPads.length == 1) {
        // Standalone Test point or Single pad
        assigned[_padKey(clusterPads[0].position)] = clusterPads[0].existingPinNumber ?? '1';
      } else if (clusterPads.length == 2) {
        // 2-pad Passive (Resistor / Capacitor / Diode)
        final p0 = clusterPads[0].position;
        final p1 = clusterPads[1].position;

        // Standard: Pin 1 is Top or Left, Pin 2 is Bottom or Right
        final bool p0IsPin1 = (p0.dx < p1.dx - 0.2) || ((p0.dx - p1.dx).abs() <= 0.2 && p0.dy > p1.dy);

        assigned[_padKey(clusterPads[0].position)] = clusterPads[0].existingPinNumber ?? (p0IsPin1 ? '1' : '2');
        assigned[_padKey(clusterPads[1].position)] = clusterPads[1].existingPinNumber ?? (p0IsPin1 ? '2' : '1');
      } else if (clusterPads.length == 3) {
        // 3-pin Transistor / SOT-23 / Regulator
        final sorted = List<_PadRef>.from(clusterPads)
          ..sort((a, b) => a.position.dx != b.position.dx
              ? a.position.dx.compareTo(b.position.dx)
              : b.position.dy.compareTo(a.position.dy));
        for (int k = 0; k < sorted.length; k++) {
          assigned[_padKey(sorted[k].position)] = sorted[k].existingPinNumber ?? '${k + 1}';
        }
      } else {
        // Multi-pin IC / DIP / Header / Connector (4, 6, 8, 14, 16, 18, 20, 24, 28, 32...)
        _numberMultiPinCluster(clusterPads, assigned);
      }
    }
  }

  static void _numberMultiPinCluster(List<_PadRef> cluster, Map<String, String> assigned) {
    final xs = cluster.map((p) => p.position.dx).toList()..sort();
    final ys = cluster.map((p) => p.position.dy).toList()..sort();

    final xSpan = xs.last - xs.first;
    final ySpan = ys.last - ys.first;

    if (xSpan > ySpan && cluster.length >= 4) {
      // Horizontal orientation: top row and bottom row
      final midY = (ys.last + ys.first) / 2.0;
      final topRow = cluster.where((p) => p.position.dy >= midY).toList()
        ..sort((a, b) => a.position.dx.compareTo(b.position.dx));
      final botRow = cluster.where((p) => p.position.dy < midY).toList()
        ..sort((a, b) => a.position.dx.compareTo(b.position.dx));

      if (topRow.isNotEmpty && botRow.isNotEmpty && (topRow.length - botRow.length).abs() <= 2) {
        // Standard DIP / Dual row logic
        int pinCounter = 1;
        // Count right on bottom, then left on top for standard CCW DIP orientation
        for (final p in botRow) {
          assigned[_padKey(p.position)] = p.existingPinNumber ?? '$pinCounter';
          pinCounter++;
        }
        for (final p in topRow.reversed) {
          assigned[_padKey(p.position)] = p.existingPinNumber ?? '$pinCounter';
          pinCounter++;
        }
        return;
      }
    } else if (ySpan >= xSpan && cluster.length >= 4) {
      // Vertical orientation: left column and right column
      final midX = (xs.last + xs.first) / 2.0;
      final leftCol = cluster.where((p) => p.position.dx <= midX).toList()
        ..sort((a, b) => b.position.dy.compareTo(a.position.dy)); // Top to bottom (CAD Y up)
      final rightCol = cluster.where((p) => p.position.dx > midX).toList()
        ..sort((a, b) => a.position.dy.compareTo(b.position.dy)); // Bottom to top

      if (leftCol.isNotEmpty && rightCol.isNotEmpty && (leftCol.length - rightCol.length).abs() <= 2) {
        // Standard DIP IC pinout: Pin 1 at top-left, count down left, up right
        int pinCounter = 1;
        for (final p in leftCol) {
          assigned[_padKey(p.position)] = p.existingPinNumber ?? '$pinCounter';
          pinCounter++;
        }
        for (final p in rightCol) {
          assigned[_padKey(p.position)] = p.existingPinNumber ?? '$pinCounter';
          pinCounter++;
        }
        return;
      }
    }

    // Default: Sort by X then Y and number 1..N
    final sorted = List<_PadRef>.from(cluster)
      ..sort((a, b) => a.position.dx != b.position.dx
          ? a.position.dx.compareTo(b.position.dx)
          : a.position.dy.compareTo(b.position.dy));

    for (int k = 0; k < sorted.length; k++) {
      assigned[_padKey(sorted[k].position)] = sorted[k].existingPinNumber ?? '${k + 1}';
    }
  }
}

class _PadRef {
  final Offset position;
  final PcbAperture aperture;
  final String? existingPinNumber;

  const _PadRef({
    required this.position,
    required this.aperture,
    this.existingPinNumber,
  });

  _PadRef copyWith({String? existingPinNumber}) {
    return _PadRef(
      position: position,
      aperture: aperture,
      existingPinNumber: existingPinNumber ?? this.existingPinNumber,
    );
  }
}

