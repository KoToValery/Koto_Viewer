import 'package:flutter/foundation.dart';
import '../models/architect_project.dart';
import '../models/architect_view_drawing.dart';
import 'architect_command_controller.dart';

enum ArchitectWorkspaceView { plan, elevation, section }

/// Adapts the existing 2D tools to a view's drawing, while publishing changes
/// through the original project controller, history and autosave.
class ArchitectWorkspaceViewController extends ChangeNotifier {
  final ArchitectCommandController source;

  /// Applies session drafting defaults to newly created elements in this view.
  ArchitectProject Function(ArchitectProject previous, ArchitectProject next)?
  prepareCreation;

  /// A command preview is visible without publishing history or autosave.
  ArchitectProject? editPreview;
  bool Function(ArchitectProject next)? previewEdit;
  ArchitectWorkspaceView view = ArchitectWorkspaceView.plan;
  String? viewId;
  ArchitectProject? _cachedSource, _cachedProjection;

  ArchitectWorkspaceViewController(this.source) {
    source.addListener(notifyListeners);
  }

  bool get isPlan => view == ArchitectWorkspaceView.plan;
  bool get hasView => isPlan || drawing != null;
  ArchitectViewDrawing? get drawing => switch (view) {
    ArchitectWorkspaceView.plan => null,
    ArchitectWorkspaceView.elevation =>
      source.project.elevations
          .where((e) => e.id == viewId)
          .firstOrNull
          ?.drawing,
    ArchitectWorkspaceView.section => _sectionDrawing,
  };

  ArchitectViewDrawing? get _sectionDrawing {
    final cut = source.project.sections
        .where((e) => e.id == viewId)
        .firstOrNull;
    return cut?.drawing.reflectedHorizontally(cut.length);
  }

  void select(ArchitectWorkspaceView type, String? id) {
    view = type;
    viewId = id;
    _cachedSource = null;
    notifyListeners();
  }

  ArchitectProject get project {
    return editPreview ?? documentProject;
  }

  ArchitectProject get documentProject {
    final original = source.project;
    if (isPlan) return original;
    if (identical(original, _cachedSource)) return _cachedProjection!;
    final data = drawing ?? const ArchitectViewDrawing();
    _cachedSource = original;
    return _cachedProjection = original.copyWith(
      activeStoreyId: 'view:$viewId',
      storeys: [
        ArchitectStorey(
          id: 'view:$viewId',
          name: '',
          dimensions: data.dimensions,
          elevationMarkers: data.elevationMarkers,
          annotations: data.annotations,
          cadPrimitives: data.cadPrimitives,
        ),
      ],
      gridAxes: [],
      elevations: [],
      sections: [],
      clearNorthSymbol: true,
    );
  }

  void commit(ArchitectProject next, {bool applyDraftingDefaults = false}) {
    if (applyDraftingDefaults) {
      next = prepareCreation?.call(documentProject, next) ?? next;
    }
    if (!applyDraftingDefaults && (previewEdit?.call(next) ?? false)) return;
    if (isPlan) {
      source.commit(next);
      return;
    }
    if (!hasView) return;
    final floor = next.activeStorey;
    final data = ArchitectViewDrawing(
      dimensions: floor.dimensions,
      elevationMarkers: floor.elevationMarkers,
      annotations: floor.annotations,
      cadPrimitives: floor.cadPrimitives,
    );
    final original = source.project;
    source.commit(
      original.copyWith(
        document: next.document,
        levelUnits: next.levelUnits,
        levelDecimals: next.levelDecimals,
        lineStyles: next.lineStyles,
        hatchPatterns: next.hatchPatterns,
        layers: next.layers,
        elementLayers: next.elementLayers,
        elevations: [
          for (final e in original.elevations)
            if (view == ArchitectWorkspaceView.elevation && e.id == viewId)
              e.copyWith(drawing: data)
            else
              e,
        ],
        sections: [
          for (final e in original.sections)
            if (view == ArchitectWorkspaceView.section && e.id == viewId)
              e.copyWith(drawing: data.reflectedHorizontally(e.length))
            else
              e,
        ],
      ),
    );
  }

  ArchitectProject execute(
    ArchitectModelCommand command, {
    bool applyDraftingDefaults = false,
  }) => executeBatch([command], applyDraftingDefaults: applyDraftingDefaults);

  ArchitectProject executeBatch(
    Iterable<ArchitectModelCommand> commands, {
    bool applyDraftingDefaults = false,
  }) {
    var next = project;
    for (final command in commands) {
      next = command.apply(next);
    }
    commit(next, applyDraftingDefaults: applyDraftingDefaults);
    return project;
  }

  bool get canUndo => source.canUndo;
  bool get canRedo => source.canRedo;
  void undo() => source.undo();
  void redo() => source.redo();
  void restore(ArchitectProject next) => source.restore(next);
  void activateStorey(String id) => source.activateStorey(id);
  void setDistanceDecimals(int decimals) =>
      source.setDistanceDecimals(decimals);
  void setUnits(ArchitectUnit units) => source.setUnits(units);
  void setDimensionScale(ArchitectDimensionScale scale) =>
      source.setDimensionScale(scale);
  @override
  void dispose() {
    source.removeListener(notifyListeners);
    super.dispose();
  }
}
