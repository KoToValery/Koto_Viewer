import 'package:flutter/material.dart';
import '../models/pcb_models.dart';

/// Pad & Pin Numbering Synchronization Engine for PCB layouts.
///
/// If the loaded Gerber design contains native pad numbers (from modern standards
/// like Gerber X2 / X3 with %TO.P...% or %TA.PinNumber...% attributes),
/// this service synchronizes those authentic pin numbers across coincident layers
/// and drill holes.
///
/// If the file is from an older standard (RS-274X) without native pad numbering,
/// NO programmatic/heuristic numbers are generated to avoid misleading the user.
class PcbPadNumberingService {
  const PcbPadNumberingService._();

  /// Synchronizes authentic pad numbers across layers in [PcbProject].
  static PcbProject assignPadNumbers(PcbProject project) {
    // 1. Collect all unique flash pad positions and apertures across copper and mask layers
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

    // 2. Check if the project contains any authentic native pad numbers from the file standard
    final bool hasNativePadNumbers = uniquePads.values.any((p) => p.existingPinNumber != null);
    if (!hasNativePadNumbers) {
      // Do NOT invent or programmatically generate numbering if the design does not
      // contain native pad numbers from the new standard (it is misleading).
      return project;
    }

    final allPads = uniquePads.values.toList();
    final Map<String, String> nativePadNumbers = {};
    for (final pad in allPads) {
      if (pad.existingPinNumber != null) {
        nativePadNumbers[_padKey(pad.position)] = pad.existingPinNumber!;
      }
    }

    // 3. Propagate authentic native pin numbers across coincident layers and drill holes
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
          final pinNum = nativePadNumbers[posKey] ?? cmd.pinNumber;
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
          if (pad.existingPinNumber == null) continue;
          final d = (pad.position - drill.position).distance;
          if (d < closestDist) {
            closestDist = d;
            matchedPin = pad.existingPinNumber;
          }
        }
        final newPin = matchedPin ?? drill.pinNumber;
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

