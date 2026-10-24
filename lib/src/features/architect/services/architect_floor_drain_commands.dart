// === SECTION: FLOOR DRAIN COMMANDS ===
// Place and update commands for ArchitectFloorDrain. Kept apart from the
// shared command controller so the drain feature stays self-contained.

import '../models/architect_contour.dart';
import '../models/architect_floor_drain.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';

void _validate(ArchitectFloorDrain drain) {
  ArchitectModelCommand.point(drain.position);
  if (!ArchitectContour.valid(drain.polygon, drain.holes)) {
    throw ArgumentError('Invalid floor outline');
  }
  final slopeOk =
      drain.slopePercent.isFinite &&
      drain.slopePercent >= ArchitectDrainDefaults.slopeMin &&
      drain.slopePercent <= ArchitectDrainDefaults.slopeMax;
  final sizeOk = drain.isLinear
      ? drain.size >= ArchitectDrainDefaults.linearMin &&
            drain.size <= ArchitectDrainDefaults.linearMax &&
            drain.width >= ArchitectDrainDefaults.linearWidthMin &&
            drain.width <= ArchitectDrainDefaults.linearWidthMax
      : drain.size >= ArchitectDrainDefaults.roundMin &&
            drain.size <= ArchitectDrainDefaults.roundMax;
  if (!slopeOk || !sizeOk || !drain.angle.isFinite) {
    throw ArgumentError('Invalid drain dimensions');
  }
  // The grate must sit completely on the floor.
  final (a, b) = drain.axis;
  if (!drain.containsPoint(a) || !drain.containsPoint(b)) {
    throw ArgumentError('Drain is outside the floor');
  }
}

class PlaceArchitectFloorDrain extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectFloorDrain drain;
  const PlaceArchitectFloorDrain({required this.storeyId, required this.drain});

  @override
  ArchitectProject apply(ArchitectProject project) {
    _validate(drain);
    ArchitectModelCommand.newId(project, drain.id);
    final floor = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(floorDrains: [...floor.floorDrains, drain]),
    );
  }
}

class UpdateArchitectFloorDrain extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectFloorDrain drain;
  const UpdateArchitectFloorDrain({required this.storeyId, required this.drain});

  @override
  ArchitectProject apply(ArchitectProject project) {
    _validate(drain);
    final floor = ArchitectModelCommand.storey(project, storeyId);
    if (!floor.floorDrains.any((d) => d.id == drain.id)) {
      throw ArgumentError('Unknown floor drain: ${drain.id}');
    }
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(
        floorDrains: [
          for (final d in floor.floorDrains) d.id == drain.id ? drain : d,
        ],
      ),
    );
  }
}
