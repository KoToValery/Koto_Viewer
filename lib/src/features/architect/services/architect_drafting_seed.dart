import 'dart:convert';

import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart' show ArchitectTool;

/// Session-only defaults for drawing another element of a picked type.
/// Identity, geometry, hosted elements and user-entered names never transfer.
class ArchitectDraftingSeed {
  final ArchitectTool tool;
  final Map<String, dynamic> values;

  ArchitectDraftingSeed._(this.tool, Map<String, dynamic> record)
    : values = Map.unmodifiable(
        jsonDecode(jsonEncode(record)) as Map<String, dynamic>,
      );

  static ArchitectTool? toolFor(ArchitectProject project, String id) {
    for (final (tool, record) in _records(project.toJson())) {
      if (record['id'] == id) return tool;
    }
    return null;
  }

  static ArchitectDraftingSeed? fromSelection(
    ArchitectProject project,
    String id,
  ) {
    for (final (tool, record) in _records(project.toJson())) {
      if (record['id'] == id) return ArchitectDraftingSeed._(tool, record);
    }
    return null;
  }

  /// Fields controlled by the live drafting UI take precedence over the seed.
  /// The host hydrates these controls when drawing starts, so later edits work.
  ArchitectProject apply(ArchitectProject previous, ArchitectProject next) {
    final existing = {
      for (final (_, record) in _records(previous.toJson())) record['id'],
    };
    final json = next.toJson();
    var changed = false;
    final keys = _inherited[tool] ?? const <String>{};
    for (final (kind, record) in _records(json)) {
      if (kind != tool || existing.contains(record['id'])) continue;
      for (final key in keys) {
        if (values.containsKey(key)) {
          record[key] = values[key];
          changed = true;
        }
      }
    }
    return changed ? ArchitectProject.fromJson(json) : next;
  }

  // Only properties not already supplied by the live tool's controls belong here.
  static const _inherited = <ArchitectTool, Set<String>>{
    ArchitectTool.wall: {
      'height',
      'baseOffset',
      'followStoreyHeight',
      'coreMaterial',
      'insulationMaterial',
      'parapet',
      'parapetFinish',
      'cutDisplayMode',
    },
    ArchitectTool.door: {'frameThickness', 'leafThickness', 'openAngleDeg'},
    ArchitectTool.window: {'frameThickness', 'panesCount', 'isFlipped'},
    ArchitectTool.column: {'height', 'baseOffset', 'cutDisplayMode'},
    ArchitectTool.beam: {'baseOffset', 'cutDisplayMode'},
    ArchitectTool.slab: {
      'thickness',
      'assemblyId',
      'coreTopOffset',
      'slopeDirection',
    },
    ArchitectTool.opening: {},
    ArchitectTool.stair: {},
    ArchitectTool.component: {'elevationOffset', 'visibleInSection'},
    ArchitectTool.zone: {
      'floorFinish',
      'wallFinish',
      'ceilingFinish',
      'clearHeight',
      'targetArea',
      'customColorValue',
    },
    ArchitectTool.dimension: {},
    ArchitectTool.level: {},
    ArchitectTool.text: {'fontSize'},
    ArchitectTool.cadLine: {'colorValue', 'colorPresetId', 'strokeWidth'},
    ArchitectTool.cadRect: {'colorValue', 'colorPresetId', 'strokeWidth'},
    ArchitectTool.cadCircle: {'colorValue', 'colorPresetId', 'strokeWidth'},
    ArchitectTool.hatch: {'hatchScale', 'hatchAngle', 'hatchBorder'},
    ArchitectTool.axis: {'bubbleAtStart', 'bubbleAtEnd'},
    ArchitectTool.section: {'viewDepth', 'visibility'},
    ArchitectTool.elevation: {'viewDepth'},
  };

  static const _collections = <String, ArchitectTool>{
    'walls': ArchitectTool.wall,
    'doors': ArchitectTool.door,
    'windows': ArchitectTool.window,
    'columns': ArchitectTool.column,
    'beams': ArchitectTool.beam,
    'slabs': ArchitectTool.slab,
    'roofs': ArchitectTool.roof,
    'openings': ArchitectTool.opening,
    'stairs': ArchitectTool.stair,
    'components': ArchitectTool.component,
    'zones': ArchitectTool.zone,
    'dimensions': ArchitectTool.dimension,
    'elevationMarkers': ArchitectTool.level,
    'annotations': ArchitectTool.text,
    'gridAxes': ArchitectTool.axis,
    'sections': ArchitectTool.section,
    'elevations': ArchitectTool.elevation,
  };

  static Iterable<(ArchitectTool, Map<String, dynamic>)> _records(
    Map<String, dynamic> json,
  ) sync* {
    for (final entry in _collections.entries) {
      for (final record in (json[entry.key] as List? ?? const [])) {
        final value = record as Map<String, dynamic>;
        yield (entry.value, value);
        if (entry.value == ArchitectTool.wall) yield* _records(value);
      }
    }
    for (final record in (json['cadPrimitives'] as List? ?? const [])) {
      final value = record as Map<String, dynamic>;
      final tool = switch (value['type']) {
        'rect' => ArchitectTool.cadRect,
        'circle' => ArchitectTool.cadCircle,
        'hatch' => ArchitectTool.hatch,
        _ => ArchitectTool.cadLine,
      };
      yield (tool, value);
    }
    for (final storey in (json['storeys'] as List? ?? const [])) {
      yield* _records(storey as Map<String, dynamic>);
    }
  }
}
