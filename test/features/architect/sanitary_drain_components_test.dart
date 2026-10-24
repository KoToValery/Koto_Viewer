import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/components/definitions/sanitary_components.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';

void main() {
  group('Sanitary Drain Parametric Components', () {
    test('SanitaryLinearDrain generates valid 2D details and 3D watertight solids', () {
      final drain = SanitaryLinearDrain();
      expect(drain.id, equals('sanitary_linear_drain'));
      expect(drain.category.name, equals('sanitary'));

      final geom = drain.generateGeometry({'width': 0.80, 'depth': 0.09, 'height': 0.06});
      expect(geom.mesh3d.triangles.isNotEmpty, isTrue);
      expect(geom.block2d.detailPaths.isNotEmpty, isTrue);
      expect(geom.block2d.bounds.width, closeTo(0.80, 0.01));
      expect(geom.block2d.bounds.height, closeTo(0.09, 0.01));
    });

    test('SanitaryFloorDrain generates valid 2D details and 3D solid geometry', () {
      final drain = SanitaryFloorDrain();
      expect(drain.id, equals('sanitary_floor_drain'));
      expect(drain.category.name, equals('sanitary'));

      final geom = drain.generateGeometry({'width': 0.15, 'depth': 0.15, 'height': 0.06});
      expect(geom.mesh3d.triangles.isNotEmpty, isTrue);
      expect(geom.block2d.detailPaths.isNotEmpty, isTrue);
      expect(geom.block2d.bounds.width, closeTo(0.15, 0.01));
      expect(geom.block2d.bounds.height, closeTo(0.15, 0.01));
    });

    test('ComponentLibraryService registers linear drain and floor drain in standard catalog', () {
      final service = ComponentLibraryService.instance;
      final defs = service.getAllDefinitions();
      expect(defs.any((d) => d.id == 'sanitary_linear_drain'), isTrue);
      expect(defs.any((d) => d.id == 'sanitary_floor_drain'), isTrue);
    });
  });
}
