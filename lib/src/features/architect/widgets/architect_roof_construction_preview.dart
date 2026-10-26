import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_section.dart';
import '../models/architect_wall.dart';
import '../models/architect_slab_assembly.dart';
import '../rendering/architect_hatch_geometry.dart';
import '../rendering/architect_section_hatch.dart';
import '../rendering/architect_roof_drainage_mesh.dart';
import '../rendering/architect_stair_mesh.dart';
import '../services/architect_stair_section.dart';
import '../services/architect_roof_geometry.dart';

/// Uses the same section geometry as the drawing, with unsaved editor values.
class ArchitectRoofConstructionPreview extends StatelessWidget {
  final ArchitectRoofAssembly assembly;
  final double slope, overhang, upperSlope;
  final double? support, breakDistance;
  final bool mansard;
  final ArchitectRoofEavesCut eavesCut;
  final ArchitectRoofDrainage drainage;
  final ArchitectProject? project;
  final ArchitectRoofPlane? roof;
  const ArchitectRoofConstructionPreview({
    super.key,
    required this.assembly,
    required this.slope,
    required this.overhang,
    required this.eavesCut,
    this.support,
    this.breakDistance,
    this.upperSlope = 25,
    this.mansard = false,
    this.project,
    this.roof,
    this.drainage = const ArchitectRoofDrainage(),
  });

  @override
  Widget build(BuildContext context) {
    if(assembly.panels!=null) {
      try {assembly.panels!.validate(slope:slope,mansard:mansard);}
      on ArgumentError {return Center(child:Text(slope<assembly.panels!.minimumSlope?
        context.l10n.roofPanelSlopeInvalid:context.l10n.roofPanelInvalid));}
    }
    final source = roof;
    final template =
        source ??
        ArchitectRoofPlane(
          id: 'preview-roof',
          storeyId: 'preview',
          points: const [
            Offset(0, 0),
            Offset(0, 4),
            Offset(3, 4),
            Offset(3, 0),
          ],
          baseElevationOffset: 2.8,
          attachToWalls: false,
        );
    final target = template.copyWith(
      assembly: assembly,
      slopeDegrees: slope,
      eavesOverhang: overhang,
      eavesCut: eavesCut,
      isMansard: mansard,
      upperSlopeDegrees: upperSlope,
      breakDistance: breakDistance,
      clearBreakDistance: breakDistance == null,
      manualSupportDistance: support,
      clearManualSupportDistance: support == null,
      drainage: drainage,
    );
    final fallback = ArchitectStorey(
      id: 'preview',
      name: '',
      height: 2.8,
      roofs: [target],
      walls: [
        ArchitectWall(
          id: 'preview-support',
          startPoint: Offset(support ?? overhang, 0),
          endPoint: Offset(support ?? overhang, 4),
          thickness: .25,
        ),
      ],
    );
    final original = project;
    final floor = original?.storeys
        .where((s) => s.id == source?.storeyId)
        .firstOrNull;
    final nextFloor =
        floor?.copyWith(
          roofs: [for (final r in floor.roofs) r.id == target.id ? target : r],
        ) ??
        fallback;
    final p = original == null || floor == null
        ? ArchitectProject(
            id: 'preview',
            name: '',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            storeys: [nextFloor],
            activeStoreyId: nextFloor.id,
          )
        : original.copyWith(
            storeys: [
              for (final s in original.storeys)
                s.id == floor.id ? nextFloor : s,
            ],
          );
    final (a, b) = target.eavesEdge;
    final center = (a + b) / 2;
    final direction = target.slopeDirection;
    final cut = ArchitectSection(
      id: 'preview-cut',
      start: center - direction * (target.maxSlopeRun + 1),
      end: center + direction * (target.maxSlopeRun + 1),
    );
    final slices = ArchitectRoofGeometry.buildSectionSlices(
      project: p,
      storey: nextFloor,
      sectionLine: cut,
      lowerStorey: ArchitectRoofGeometry.supportingWallStorey(p, nextFloor),
    );
    final members = [
      for (final s in slices.where((s) => s.roofId == target.id)) ...s.members,
    ];
    final gutter = ArchitectStairSection.build(
      [
        StairSolid(
          StairSolidMaterial.metal,
          ArchitectRoofDrainageMesh.build(
            p,
            nextFloor,
            target,
            includeDownpipes: false,
            details: false,
          ),
        ),
      ],
      cut.start,
      cut.axis,
      endpointTolerance: 1e-5,
    ).regions[StairSolidMaterial.metal];
    if (gutter != null && !gutter.getBounds().isEmpty) {
      members.add(
        ArchitectRoofSectionMember(
          roofId: target.id,
          kind: ArchitectRoofMemberKind.metalFlashing,
          path: gutter,
          polygon: const [],
          material: ArchitectRoofMaterial.metalSeam,
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('roof-construction-preview'),
        painter: ArchitectRoofConstructionPainter(members),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class ArchitectRoofConstructionPainter extends CustomPainter {
  final List<ArchitectRoofSectionMember> members;
  ArchitectRoofConstructionPainter(this.members);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (members.isEmpty || size.isEmpty) return;
    final bounds = members
        .map((m) => m.path.getBounds())
        .reduce((a, b) => a.expandToInclude(b));
    final scale = math.min(
      (size.width - 16) / math.max(bounds.width, .1),
      (size.height - 16) / math.max(bounds.height, .1),
    );
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, -scale)
      ..setEntry(0, 3, size.width / 2 - bounds.center.dx * scale)
      ..setEntry(1, 3, size.height / 2 + bounds.center.dy * scale);
    final ink = Paint()
      ..color = const Color(0xff353535)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final member in members) {
      final path = member.path.transform(matrix.storage);
      canvas.drawPath(path, Paint()..color = Colors.white);
      canvas.drawPath(path, ink);
      if (member.drawTimberDiagonals && member.polygon.length == 4) {
        Offset point(Offset p) => MatrixUtils.transformPoint(matrix, p);
        final points = member.polygon.map(point).toList();
        canvas.drawLine(points[0], points[2], ink);
        canvas.drawLine(points[1], points[3], ink);
        continue;
      }
      final material = switch (member.material) {
        ArchitectRoofMaterial.timberBoarding ||
        ArchitectRoofMaterial.osb => SlabMaterial.parquet,
        ArchitectRoofMaterial.rcSlab => SlabMaterial.concrete,
        ArchitectRoofMaterial.mineralWool => SlabMaterial.mineralWool,
        ArchitectRoofMaterial.xps => SlabMaterial.xps,
        ArchitectRoofMaterial.pir => SlabMaterial.roofInsulation,
        ArchitectRoofMaterial.clayTiles ||
        ArchitectRoofMaterial.concreteTiles ||
        ArchitectRoofMaterial.bitumenShingles => SlabMaterial.tile,
        _ => SlabMaterial.custom,
      };
      final pattern = member.material==ArchitectRoofMaterial.steel
        ?ArchitectSectionHatch.preset('metal'):ArchitectSectionHatch.slab(material);
      if (pattern == null || path.getBounds().height < 3) continue;
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        ArchitectHatchGeometry.path(
          boundary: path,
          pattern: pattern,
          unitsPerMm: 1.2,
          visibleBounds: Offset.zero & size,
        ),
        Paint()
          ..color = const Color(0xff909090)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .4,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArchitectRoofConstructionPainter oldDelegate) => true;
}
