import '../models/architect_project.dart';
import '../models/architect_contour.dart';
import '../models/architect_roof_settings.dart';
import 'architect_command_controller.dart';
import 'architect_roof_geometry.dart';

/// Applies one reviewed edit atomically, without copying unedited member data.
class ApplyArchitectRoofSettings extends ArchitectModelCommand {
  final String storeyId, roofId;
  final ArchitectRoofLayersResult settings;
  const ApplyArchitectRoofSettings({
    required this.storeyId,
    required this.roofId,
    required this.settings,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final floor = ArchitectModelCommand.storey(project, storeyId);
    final source = floor.roofs.where((r) => r.id == roofId).firstOrNull;
    if (source == null) throw ArgumentError('Unknown roof');
    final changes = settings.changes;
    if (changes.isEmpty) return project;
    final group = source.roofGroupId;
    final grouped = settings.applyToGroup && group != null && group.isNotEmpty;
    final roofs = [
      for (final roof in floor.roofs)
        if (roof.id == roofId || (grouped && roof.roofGroupId == group))
          _patch(project, floor, roof, roof.id == roofId)
        else
          roof,
    ];
    return ArchitectModelCommand.replace(project, floor.copyWith(roofs: roofs));
  }

  ArchitectRoofPlane _patch(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
    bool target,
  ) {
    final s = settings, c = s.changes, old = roof.drainage;
    final drainage = old.copyWith(
      showGutter: c.contains(ArchitectRoofSetting.gutterVisible)
          ? s.drainage.showGutter
          : null,
      showDownpipes: c.contains(ArchitectRoofSetting.pipesVisible)
          ? s.drainage.showDownpipes
          : null,
      profile: c.contains(ArchitectRoofSetting.gutterProfile)
          ? s.drainage.profile
          : null,
      material: c.contains(ArchitectRoofSetting.gutterMaterial)
          ? s.drainage.material
          : null,
      gutterWidth: c.contains(ArchitectRoofSetting.gutterWidth)
          ? s.drainage.gutterWidth
          : null,
      gutterDepth: c.contains(ArchitectRoofSetting.gutterDepth)
          ? s.drainage.gutterDepth
          : null,
      downpipes: target && c.contains(ArchitectRoofSetting.pipes)
          ? s.drainage.downpipes
          : null,
    );
    drainage.validate();
    var next = roof.copyWith(
      assembly: c.contains(ArchitectRoofSetting.assembly)
          ? s.assembly.copyWith()
          : null,
      slopeDegrees: c.contains(ArchitectRoofSetting.slope)
          ? s.slopeDegrees
          : null,
      eavesOverhang: c.contains(ArchitectRoofSetting.overhang)
          ? s.eavesOverhang
          : null,
      eavesCut: c.contains(ArchitectRoofSetting.eavesCut) ? s.eavesCut : null,
      baseElevationOffset: c.contains(ArchitectRoofSetting.elevation)
          ? s.baseElevationOffset
          : null,
      attachToWalls: c.contains(ArchitectRoofSetting.attachment)
          ? s.attachToWalls
          : null,
      manualSupportDistance: c.contains(ArchitectRoofSetting.support)
          ? s.manualSupportDistance
          : null,
      clearManualSupportDistance:
          c.contains(ArchitectRoofSetting.support) &&
          s.manualSupportDistance == null,
      upperSlopeDegrees:
          roof.isMansard && c.contains(ArchitectRoofSetting.upperSlope)
          ? s.upperSlopeDegrees
          : null,
      breakDistance:
          roof.isMansard && c.contains(ArchitectRoofSetting.breakDistance)
          ? s.breakDistance
          : null,
      clearBreakDistance:
          roof.isMansard &&
          c.contains(ArchitectRoofSetting.breakDistance) &&
          s.breakDistance == null,
      isSlopeLocked:
          !s.applyToGroup &&
              roof.roofGroupId != null &&
              c.contains(ArchitectRoofSetting.slope)
          ? false
          : null,
      drainage: drainage,
    );
    if (!next.slopeDegrees.isFinite ||
        next.slopeDegrees < 0 ||
        next.slopeDegrees > 80 ||
        !next.eavesOverhang.isFinite ||
        next.eavesOverhang < 0 ||
        !next.baseElevationOffset.isFinite ||
        next.assembly.layers.isEmpty ||
        next.assembly.layers.any(
          (l) => !l.thickness.isFinite || l.thickness <= 0,
        ) ||
        (next.isMansard &&
            (!next.upperSlopeDegrees.isFinite ||
                next.upperSlopeDegrees < 0 ||
                next.upperSlopeDegrees > 85)) ||
        (next.isMansard &&
            c.contains(ArchitectRoofSetting.breakDistance) &&
            next.breakDistance != null &&
            (!next.breakDistance!.isFinite ||
                next.breakDistance! < next.minimumBreakDistance ||
                next.breakDistance! > next.maximumBreakDistance)) ||
        (next.manualSupportDistance != null &&
            (!next.manualSupportDistance!.isFinite ||
                next.manualSupportDistance! < 0 ||
                next.manualSupportDistance! > next.maxSlopeRun))) {
      throw ArgumentError('Invalid roof settings');
    }
    if (c.contains(ArchitectRoofSetting.attachment) &&
        next.attachToWalls &&
        !roof.attachToWalls) {
      next = next.copyWith(
        baseElevationOffset:
            ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
              roof: next,
              storey: floor,
              lowerStorey: ArchitectRoofGeometry.supportingWallStorey(
                project,
                floor,
              ),
            ),
      );
    }
    return next;
  }
}

/// Replaces only the reviewed roof IDs; unrelated roofs are retained.
class CreateReviewedArchitectRoofs extends ArchitectModelCommand {
  final String storeyId;
  final List<ArchitectRoofPlane> roofs;
  final Set<String> replaceIds;
  const CreateReviewedArchitectRoofs({
    required this.storeyId,
    required this.roofs,
    this.replaceIds = const {},
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final floor = ArchitectModelCommand.storey(project, storeyId);
    if (roofs.isEmpty ||
        !replaceIds.every((id) => floor.roofs.any((r) => r.id == id))) {
      throw ArgumentError('Invalid roof replacement');
    }
    final ids = <String>{};
    for (final roof in roofs) {
      ArchitectModelCommand.newId(project, roof.id);
      if (!ids.add(roof.id) ||
          roof.storeyId != storeyId ||
          !ArchitectContour.valid(roof.points, roof.holes)) {
        throw ArgumentError('Invalid new roofs');
      }
      roof.drainage.validate();
    }
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(
        roofs: [
          for (final old in floor.roofs)
            if (!replaceIds.contains(old.id)) old,
          ...roofs,
        ],
      ),
    );
  }
}
