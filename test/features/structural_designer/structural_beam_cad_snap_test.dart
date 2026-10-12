import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_magnetic_alignment_helper.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  for (final units in [1.0, 100.0, 1000.0]) {
    test(
      'Beam snaps to CAD line endpoints, edges and crossings in $units units/m',
      () {
        final doc = DxfDocument(
          layers: {'0': DxfLayer(name: '0')},
          blocks: {},
          headerVars: {},
          bounds: Rect.fromLTWH(0, -4 * units, 8 * units, 8 * units),
          entityStats: {},
          entities: [
            DxfLine(p1: Offset(3.437, 0) * units, p2: Offset(8, 0) * units),
            DxfLine(
              p1: Offset(6.713, -4) * units,
              p2: Offset(6.713, 4) * units,
            ),
          ],
        );
        const floor = StoreyLevel(id: 's', name: 's', elevation: 0, height: 3);
        for (final query in <(Offset, Offset, DxfSnapType)>[
          (
            const Offset(3.457, .03),
            const Offset(3.437, 0),
            DxfSnapType.endpoint,
          ),
          (
            const Offset(4.323, .03),
            const Offset(4.323, 0),
            DxfSnapType.nearest,
          ),
          (
            const Offset(6.733, .03),
            const Offset(6.713, 0),
            DxfSnapType.intersection,
          ),
        ]) {
          final result = StructuralMagneticAlignmentHelper.alignBeamEndpoint(
            rawPoint: query.$1 * units,
            beamStart: Offset(1, 0) * units,
            toleranceCad: .1 * units,
            activeStorey: floor,
            cadUnitsPerMeter: units,
            dxfDocument: doc,
          );
          expect(result, isNotNull);
          expect(
            (result!.snappedPoint / units - query.$2).distance,
            lessThan(1e-10),
          );
          expect(result.objectSnap!.type, query.$3);
          expect(result.guideLines, isNotEmpty);
        }
      },
    );
  }
  test(
    'Beam CAD snapping ignores invisible lines and respects capture radius',
    () {
      final doc = DxfDocument(
        layers: {'hidden': DxfLayer(name: 'hidden')..isVisible = false},
        blocks: {},
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 8, 8),
        entityStats: {},
        entities: [
          const DxfLine(layer: 'hidden', p1: Offset(3, 2), p2: Offset(8, 2)),
        ],
      );
      const floor = StoreyLevel(id: 's', name: 's', elevation: 0, height: 3);
      expect(
        StructuralMagneticAlignmentHelper.alignBeamEndpoint(
          rawPoint: const Offset(3.02, 2.03),
          toleranceCad: .1,
          activeStorey: floor,
          dxfDocument: doc,
        ),
        isNull,
      );
      doc.layers['hidden']!.isVisible = true;
      expect(
        StructuralMagneticAlignmentHelper.alignBeamEndpoint(
          rawPoint: const Offset(3.02, 3.03),
          toleranceCad: .1,
          activeStorey: floor,
          dxfDocument: doc,
        ),
        isNull,
      );
    },
  );
}
