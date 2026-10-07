import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';
import 'package:kotoview/src/features/structural_designer/widgets/slab_level_dialog.dart';

const plate = StructuralSlab(
  id: 's',
  polygon: [Offset(0, 0), Offset(4, 0), Offset(4, 4), Offset(0, 4)],
);
void main() {
  test('ceiling top and soffit use base plus height minus finish', () {
    const floor = StoreyLevel(id: 'f', name: 'f', height: 2.9);
    expect(floor.structuralElevationFor(plate), closeTo(2.85, 1e-12));
    expect(floor.slabSoffitElevationFor(plate), closeTo(2.65, 1e-12));
    expect(
      floor.copyWith(elevation: -3).structuralElevationFor(plate),
      closeTo(-.15, 1e-12),
    );
  });
  test(
    'explicit concrete level excludes no further finish and retains top on thickness edit',
    () {
      const floor = StoreyLevel(id: 'f', name: 'f', height: 2.9);
      final s = plate.copyWith(topElevation: 2.9, floorFinish: .1);
      expect(floor.structuralElevationFor(s), 2.9);
      expect(
        floor.slabSoffitElevationFor(s.copyWith(thickness: .3)),
        closeTo(2.6, 1e-12),
      );
    },
  );
  test('JSON, geometry edits and floor cloning preserve level semantics', () {
    final s = StructuralSlab.fromJson(
      jsonDecode(jsonEncode(plate.copyWith(topElevation: 2.85).toJson())),
    );
    expect(s.copyWith(thickness: .3).topElevation, 2.85);
    expect(s.copyWith(clearTopElevation: true).topElevation, isNull);
    final floor = StoreyLevel(id: 'f', name: 'f', slabs: [s]);
    expect(
      floor
          .cloneToNextLevel(newId: 'u', newName: 'u', newElevation: 3)
          .slabs
          .single
          .topElevation,
      closeTo(5.85, 1e-12),
    );
    expect(StructuralSlab.fromJson(plate.toJson()).topElevation, isNull);
  });
  test('3D ceiling slab uses the same top and soffit at every CAD scale', () {
    for (final scale in [1.0, 100.0, 1000.0]) {
      final s = plate.copyWith(
        topElevation: 2.85,
        polygon: plate.polygon.map((p) => p * scale).toList(),
      );
      final floor = StoreyLevel(
        id: 'f',
        name: 'f',
        elevation: -.01,
        height: 2.91,
        slabs: [s],
      );
      final mesh = Structural3dMeshBuilder.buildProjectMesh(
        StructuralProject(storeys: [floor]),
        cadUnitsPerMeter: scale,
      );
      final zs = mesh.triangles.expand((t) => [t.v0.z, t.v1.z, t.v2.z]);
      expect(
        zs.every(
          (z) =>
              (z - 2.85 * scale).abs() < 1e-8 ||
              (z - 2.65 * scale).abs() < 1e-8,
        ),
        isTrue,
      );
    }
  });
  test('DXF labels export the ceiling concrete elevation', () async {
    final dir = await Directory.systemTemp.createTemp('ceiling_export_');
    addTearDown(() => dir.delete(recursive: true));
    final file = await StructuralPersistenceService.exportStoreyToDxfFile(
      storey: StoreyLevel(id: 'f', name: 'f', height: 2.9, slabs: [plate]),
      baseName: 'ceiling',
      outputDirectory: dir,
    );
    expect(await file.readAsString(), contains('T.O.C. +2.85'));
  });
  for (final language in ['bg', 'en']) {
    testWidgets(
      'ceiling level editor validates and accepts decimal comma: $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = await AppLocalizations.delegate.load(Locale(language));
        StructuralSlab? saved;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await showDialog<StructuralSlab>(
                      context: context,
                      builder: (_) => const SlabLevelDialog(
                        storey: StoreyLevel(id: 'f', name: 'f', height: 2.9),
                        slab: plate,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.text(strings.ceilingSlabLevels('2.850', '2.650')),
          findsOneWidget,
        );
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('ceiling-top')), '0');
        await tester.pump();
        await tester.tap(find.text(strings.applyAction));
        await tester.pumpAndSettle();
        expect(saved, isNull);
        expect(find.text(strings.ceilingSlabInvalid), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('ceiling-top')),
          '2,90',
        );
        await tester.pump();
        await tester.tap(find.text(strings.applyAction));
        await tester.pumpAndSettle();
        expect(saved!.topElevation, 2.9);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
