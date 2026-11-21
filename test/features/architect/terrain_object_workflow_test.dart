import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';

void main() {
  group('Package 1 — Terrain Object Lifecycle, Datum & Spline Contours', () {
    test(
      'boundaryRect creates outer boundary with autoInterpolateElevation that does not pull contours to 0.00',
      () {
        final tool = ArchitectLandscapeTool()
          ..terrainState = ArchitectTerrainState.existing
          ..terrainMode = ArchitectTerrainDraftMode.boundaryRect
          ..terrainDatumElevation = 540.0;

        var project = ArchitectProject.starterWithCatalog(
          name: 'Terrain Test',
          storeyCount: 1,
        );
        project = project.copyWith(activeStoreyId: project.siteStorey!.id);

        expect(
          tool.handleTap(
            toolName: 'terrain',
            worldPoint: const Offset(0, 0),
            project: project,
          ),
          isNull,
        );
        final afterRect = tool.handleTap(
          toolName: 'terrain',
          worldPoint: const Offset(20, 20),
          project: project,
        );
        expect(afterRect, isNotNull);
        expect(afterRect!.existingTerrain.hasOuterBoundary, isTrue);
        expect(
          afterRect.existingTerrain.boundaries.single.autoInterpolateElevation,
          isTrue,
        );

        // Add two contours at +1.00 and +3.00 relative (541.00 and 543.00 abs).
        final withContours = afterRect.copyWith(
          existingTerrain: afterRect.existingTerrain.copyWith(
            contours: const [
              ArchitectTerrainContour(
                id: 'c1',
                points: [Offset(0, 5), Offset(20, 5)],
                elevation: 1.0,
                rawAbsoluteElevation: 541.0,
              ),
              ArchitectTerrainContour(
                id: 'c2',
                points: [Offset(0, 15), Offset(20, 15)],
                elevation: 3.0,
                rawAbsoluteElevation: 543.0,
              ),
            ],
          ),
        );

        // Midpoint at (10, 10) must be ~2.00, NOT pulled toward 0.00 by outer boundary!
        final zMid = withContours.existingTerrain.evaluateElevationAt(
          const Offset(10, 10),
        );
        expect(zMid, isNotNull);
        expect(zMid!, closeTo(2.0, 0.25));
      },
    );

    test(
      'updateSurfaceDatum recalculates relative elevations from rawAbsoluteElevation',
      () {
        final project = ArchitectProject.starterWithCatalog(
          name: 'Datum Test',
          storeyCount: 1,
        ).copyWith(
          existingTerrain: const ArchitectTerrainSurface(
            state: ArchitectTerrainState.existing,
            datumElevation: 540.0,
            contours: [
              ArchitectTerrainContour(
                id: 'c1',
                points: [Offset(0, 0), Offset(10, 0)],
                elevation: 2.5,
                rawAbsoluteElevation: 542.5,
              ),
            ],
            spots: [
              ArchitectTerrainSpot(
                id: 's1',
                position: Offset(5, 5),
                elevation: -1.0,
                rawAbsoluteElevation: 539.0,
              ),
            ],
          ),
        );

        final updated = ArchitectLandscapeTool.updateSurfaceDatum(
          project,
          state: ArchitectTerrainState.existing,
          newDatum: 542.0,
        );

        expect(updated.existingTerrain.datumElevation, closeTo(542.0, 1e-6));
        expect(
          updated.existingTerrain.contours.single.elevation,
          closeTo(0.5, 1e-4),
        );
        expect(
          updated.existingTerrain.contours.single.rawAbsoluteElevation,
          closeTo(542.5, 1e-4),
        );
        expect(
          updated.existingTerrain.spots.single.elevation,
          closeTo(-3.0, 1e-4),
        );
      },
    );

    test(
      'cloneExistingToProposed copies boundaries, contours and spots with independent IDs',
      () {
        final project = ArchitectProject.starterWithCatalog(
          name: 'Clone Test',
          storeyCount: 1,
        ).copyWith(
          existingTerrain: const ArchitectTerrainSurface(
            state: ArchitectTerrainState.existing,
            datumElevation: 100.0,
            boundaries: [
              ArchitectTerrainBoundary(
                id: 'b1',
                polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
                autoInterpolateElevation: true,
              ),
            ],
            contours: [
              ArchitectTerrainContour(
                id: 'c1',
                points: [Offset(1, 2), Offset(5, 4), Offset(9, 2)],
                elevation: 1.5,
                rawAbsoluteElevation: 101.5,
                isSpline: true,
              ),
            ],
          ),
        );

        final cloned = ArchitectLandscapeTool.cloneExistingToProposed(project);
        expect(cloned.proposedTerrain.state, ArchitectTerrainState.proposed);
        expect(cloned.proposedTerrain.datumElevation, 100.0);
        expect(cloned.proposedTerrain.boundaries.length, 1);
        expect(cloned.proposedTerrain.boundaries.single.id, isNot('b1'));
        expect(cloned.proposedTerrain.contours.single.id, isNot('c1'));
        expect(cloned.proposedTerrain.contours.single.isSpline, isTrue);
        // Spline contour resolvedPolyline produces smooth interpolated points passing through input vertices.
        final sampled = cloned.proposedTerrain.contours.single.resolvedPolyline();
        expect(sampled.length, greaterThan(3));
      },
    );
  });
}
