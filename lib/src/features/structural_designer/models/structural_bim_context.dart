import 'package:flutter/widgets.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import 'structural_element.dart';

/// Context provided to [StructuralDesignerScreen] when operating inside a
/// multi-storey BiM work project (rather than a standalone single-drawing demo).
class StructuralBimContext {
  /// Map of storeyId to the aligned, coordinate-transformed [DxfDocument].
  final Map<String, DxfDocument> underlaysByStorey;

  /// Combined bounding box enclosing all transformed floor underlays.
  final Rect projectBounds;

  /// Drawing units per meter ratio in the project coordinate system.
  final double cadUnitsPerMeter;

  /// Callback invoked whenever structural elements or project settings change (for autosave).
  final void Function(StructuralProject) onProjectChanged;

  /// Callback invoked when layer visibility is modified on a specific storey underlay.
  final void Function(String storeyId, Map<String, bool>) onLayerVisibilityChanged;

  /// Callback invoked when wall detection is executed on a specific storey underlay.
  final void Function(String storeyId) onWallsDetected;

  /// Callback invoked to present project/storey DXF or ZIP export options.
  final Future<void> Function(BuildContext context, StructuralProject project, String storeyId) onExport;

  /// Callback to navigate back or open the project's storey & underlay management screen.
  final VoidCallback onManageStoreys;

  const StructuralBimContext({
    required this.underlaysByStorey,
    required this.projectBounds,
    required this.cadUnitsPerMeter,
    required this.onProjectChanged,
    required this.onLayerVisibilityChanged,
    required this.onWallsDetected,
    required this.onExport,
    required this.onManageStoreys,
  });
}
