import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../models/architect_project.dart';
import 'architect_command_controller.dart';
import '../../bim_editing/properties/bim_numeric_rule.dart';

enum ArchitectPropertyMeasure {
  radians,
  length,
  area,
  angle,
  count,
  scalar,
  paperWeight,
}

class ArchitectPropertyDescriptor {
  final String id;
  final ArchitectPropertyMeasure measure;
  final double minimum, maximum;
  const ArchitectPropertyDescriptor(
    this.id, {
    this.measure = ArchitectPropertyMeasure.length,
    this.minimum = .001,
    this.maximum = double.infinity,
  });
  double scale(ArchitectProject p) => switch (measure) {
    ArchitectPropertyMeasure.radians => math.pi / 180,
    ArchitectPropertyMeasure.length => p.units.scaleToMeters,
    ArchitectPropertyMeasure.area => p.units.isImperial ? .3048 * .3048 : 1,
    ArchitectPropertyMeasure.paperWeight => 8.0,
    _ => 1,
  };
  String unit(ArchitectProject p) => switch (measure) {
    ArchitectPropertyMeasure.length => p.units.symbol,
    ArchitectPropertyMeasure.area => p.units.isImperial ? 'sq ft' : 'm²',
    ArchitectPropertyMeasure.angle || ArchitectPropertyMeasure.radians => '°',
    ArchitectPropertyMeasure.paperWeight => 'mm',
    _ => '',
  };
  double? parse(String text, ArchitectProject p) => BimNumericRule(
    minimum: minimum,
    maximum: maximum,
    integer: measure == ArchitectPropertyMeasure.count,
    unitToModel: scale(p),
  ).parse(text);
  static ArchitectPropertyDescriptor of(String id) =>
      ArchitectPropertyDescriptor(
        id,
        measure: switch (id) {
          'targetArea' => ArchitectPropertyMeasure.area,
          'rotationDeg' || 'hatchAngle' || 'tiltAngle' => ArchitectPropertyMeasure.angle,
          'angle' => ArchitectPropertyMeasure.radians,
          'stepCount' => ArchitectPropertyMeasure.count,
          'hatchScale' || 'slopePercent' => ArchitectPropertyMeasure.scalar,
          'strokeWidth' => ArchitectPropertyMeasure.paperWeight,
          _ => ArchitectPropertyMeasure.length,
        },
        minimum: switch (id) {
          'elevation' ||
          'rotationDeg' ||
          'baseOffset' ||
          'offsetDistance' => -double.infinity,
          'tiltAngle' => -80,
          'hatchAngle' => -180,
          'sillHeight' || 'insulationThicknessOverride' => 0,
          'hatchScale' => .1,
          'stepCount' => 1,
          _ => .001,
        },
        maximum: switch (id) {
          'hatchAngle' => 180,
          'tiltAngle' => 80,
          'hatchScale' => 20,
          'stepCount' => 1000,
          _ => double.infinity,
        },
      );
}

/// Owns an unpublished document. Every preview is rebuilt from the baseline.
class ArchitectPropertiesSession extends ChangeNotifier {
  final ArchitectProject original;
  ArchitectProject _preview;
  final Map<String, ArchitectProject Function(ArchitectProject)> _changes = {};
  ArchitectPropertiesSession(this.original) : _preview = original;
  ArchitectProject get preview => _preview;
  bool get isDirty => _changes.isNotEmpty;
  void stage(
    String key,
    ArchitectProject Function(ArchitectProject)? edit, {
    ArchitectProject Function(ArchitectProject)? prepare,
  }) {
    final next = {..._changes};
    if (edit == null) {
      next.remove(key);
    } else {
      next[key] = edit;
    }
    var candidate = original;
    for (final operation in next.values) {
      candidate = operation(candidate);
    }
    candidate = prepare?.call(candidate) ?? candidate;
    _changes
      ..clear()
      ..addAll(next);
    _preview = candidate;
    notifyListeners();
  }

  void cancel() {
    _changes.clear();
    _preview = original;
    notifyListeners();
  }

  void commit(ArchitectCommandController controller) {
    if (!identical(controller.project, original)) {
      throw StateError('Stale properties session');
    }
    if (isDirty) controller.commit(_preview);
  }
}
