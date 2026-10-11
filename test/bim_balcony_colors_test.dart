import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/slab_colors.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';

void main() {
  test(
    'all outdoor plates share one colour despite old saved palette values',
    () {
      for (final kind in ['balcony', 'terrace', 'loggia']) {
        for (final stored in [
          null,
          Colors.red.toARGB32(),
          Colors.blue.toARGB32(),
        ]) {
          final slab = StructuralSlab(
            id: 'bim_slab_upper_projection_${kind}_3',
            colorValue: stored,
            polygon: const [
              Offset(0, 0),
              Offset(2, 0),
              Offset(2, 2),
              Offset(0, 2),
            ],
          );
          expect(
            SlabColors.forSlab(slab, fallback: Colors.purple),
            SlabColors.balcony,
          );
          final model = StructuralProject(
            storeys: [
              StoreyLevel(id: 'upper', name: 'Upper', slabs: [slab]),
            ],
          );
          final mesh = Structural3dMeshBuilder.buildProjectMesh(model);
          expect(
            mesh.triangles.map((t) => t.color?.withValues(alpha: 1)).toSet(),
            {SlabColors.balcony},
          );
        }
      }
      const main = StructuralSlab(
        id: 'bim_slab_upper_main_0',
        colorValue: 0xFFFFB300,
        polygon: [],
      );
      expect(
        SlabColors.forSlab(main, fallback: Colors.blue),
        const Color(0xFFFFB300),
      );
    },
  );
}
