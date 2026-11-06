import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/services/architect_ifc_export.dart';
import 'package:kotoview/src/features/architect/services/architect_ifc_step_writer.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/ifc_parser.dart';

const _polygon = [Offset(0, 0), Offset(6, 0), Offset(6, 5), Offset(0, 5)];

ArchitectProject _project() {
  const wall = ArchitectWall(
    id: 'wall-1',
    startPoint: Offset.zero,
    endPoint: Offset(6, 0),
    thickness: .3,
    followStoreyHeight: false,
    layers: [
      ArchitectMaterialLayer(
        id: 'finish',
        material: ArchitectMaterial.plaster,
        role: ArchitectLayerRole.finish,
        thickness: .05,
      ),
      ArchitectMaterialLayer(
        id: 'core',
        material: ArchitectMaterial.brick,
        role: ArchitectLayerRole.core,
        thickness: .25,
      ),
    ],
    doors: [
      ArchitectDoor(
        id: 'door-1',
        wallId: 'wall-1',
        offsetRatio: .25,
        width: .9,
        uuid: 'door-uuid',
      ),
    ],
    windows: [
      ArchitectWindow(
        id: 'window-1',
        wallId: 'wall-1',
        offsetRatio: .7,
        width: 1.2,
        uuid: 'window-uuid',
      ),
    ],
  );
  final lower = ArchitectStorey(
    id: 'ground',
    name: 'Етаж 1',
    elevation: -.25,
    walls: const [
      wall,
      ArchitectWall(
        id: 'guard',
        startPoint: Offset(0, 5),
        endPoint: Offset(5, 5),
        height: 1.1,
        followStoreyHeight: false,
        railing: ArchitectRailingDesign(kind: ArchitectRailingKind.glassPosts),
      ),
    ],
    slabs: const [
      ArchitectSlab(
        id: 'slab-1',
        polygon: _polygon,
        thickness: .2,
        assemblyId: 'bare',
        holes: [
          [Offset(2, 2), Offset(3, 2), Offset(3, 3), Offset(2, 3)],
        ],
      ),
    ],
    columns: const [
      ArchitectColumn(id: 'col-1', position: Offset(1, 1), rotationDeg: 30),
      ArchitectColumn(
        id: 'col-2',
        position: Offset(4, 4),
        shape: ColumnShape.circular,
      ),
    ],
    beams: const [
      ArchitectBeam(
        id: 'beam-1',
        startPoint: Offset(1, 1),
        endPoint: Offset(4, 4),
        width: .3,
        depth: .45,
      ),
    ],
    stairs: const [
      ArchitectStair(
        id: 'stair-1',
        startPoint: Offset(8, 0),
        endPoint: Offset(8, 4),
        design: ArchitectStairDesign(
          shape: StairShape.halfTurn,
          showRailing: false,
          startOffset: .1,
        ),
      ),
    ],
    zones: const [
      ArchitectZone(
        id: 'room-1',
        name: 'Дневна',
        number: '101',
        category: ArchitectZoneCategory.living,
        polygon: _polygon,
      ),
    ],
    components: const [
      ArchitectComponentInstance(
        id: 'unknown-component',
        definitionId: 'unavailable-in-library',
        position: Offset(12, 0),
      ),
    ],
  );
  final upper = ArchitectStorey(
    id: 'upper',
    name: 'Етаж 2',
    elevation: 2.55,
    walls: const [
      ArchitectWall(
        id: 'upper-wall',
        startPoint: Offset(0, 0),
        endPoint: Offset(6, 0),
        height: 2.8,
        followStoreyHeight: false,
      ),
    ],
    roofs: [
      ArchitectRoofPlane(
        id: 'roof-1',
        storeyId: 'upper',
        points: _polygon,
        attachToWalls: false,
        slopeDegrees: 25,
        baseElevationOffset: 2.8,
        eavesOverhang: 0,
        assembly: const ArchitectRoofAssembly(
          id: 'roof-type',
          preset: ArchitectRoofPreset.custom,
          timber: ArchitectRoofTimberSpec.none,
          layers: [
            ArchitectRoofLayer(
              id: 'roof-concrete',
              role: ArchitectRoofLayerRole.structure,
              material: ArchitectRoofMaterial.rcSlab,
              thickness: .2,
            ),
          ],
        ),
      ),
    ],
  );
  return ArchitectProject(
    id: 'ifc-fixture-project',
    name: 'Тест сграда',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026, 11, 5),
    slabAssemblies: const [
      ArchitectSlabAssembly(id: 'bare', usage: SlabUsage.intermediate),
    ],
    storeys: [lower, upper],
    activeStoreyId: lower.id,
  );
}

int _count(String text, String type) =>
    RegExp('=$type\\(').allMatches(text).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('bg'));
  });

  test(
    'stable compressed GUIDs are legal, namespaced and order independent',
    () {
      final a = architectIfcGuid('project', 'wall');
      expect(a, matches(RegExp(r'^[0-3][0-9A-Za-z_$]{21}$')));
      expect(a, architectIfcGuid('project', 'wall'));
      expect(a, isNot(architectIfcGuid('another-project', 'wall')));
      expect(a, isNot(architectIfcGuid('project', 'another-wall')));
    },
  );

  test(
    'closed source with cap T junction and inconsistent winding becomes a closed BRep',
    () {
      const points = [
        [0.0, 0.0, 0.0],
        [1.0, 0.0, 0.0],
        [1.0, 1.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
        [1.0, 0.0, 1.0],
        [1.0, 1.0, 1.0],
        [0.0, 1.0, 1.0],
        [.5, 0.0, 0.0],
      ];
      const faces = [
        [0, 2, 1],
        [0, 3, 2],
        [6, 5, 4],
        [4, 6, 7],
        [0, 8, 5],
        [8, 1, 5],
        [0, 5, 4],
        [3, 7, 6],
        [3, 6, 2],
        [0, 4, 7],
        [0, 7, 3],
        [1, 2, 6],
        [1, 6, 5],
      ];
      final result = architectWriteIfc({
        'id': 'topology-project',
        'name': '',
        'timestamp': 1793836800,
        'schema': 'ifc4',
        'storeys': [
          {
            'id': 's',
            'name': '',
            'elevation': 0.0,
            'height': 3.0,
            'elements': [
              {
                'id': 'topology-cube',
                'kind': 'wall',
                'name': '',
                'shapes': [
                  {
                    'type': 'mesh',
                    'triangles': [
                      for (final f in faces) [for (final i in f) points[i]],
                    ],
                  },
                ],
              },
            ],
          },
        ],
      });
      final text = utf8.decode(result['bytes']);
      expect(text, contains('IFCFACETEDBREP'));
      expect(text, isNot(contains('IFCOPENSHELL')));
      expect(
        (result['notices'] as List).where(
          (n) => n['code'] == 'surfaceFallback',
        ),
        isEmpty,
      );
      Directory(
        'build/architect_export_validation',
      ).createSync(recursive: true);
      File(
        'build/architect_export_validation/architect_topology_ifc4.ifc',
      ).writeAsBytesSync(result['bytes']);
    },
  );

  for (final schema in ArchitectIfcSchema.values) {
    test(
      '${schema.name}: mixed open and closed components have one additive Body',
      () {
        const cube = [
          [0.0, 0.0, 0.0],
          [1.0, 0.0, 0.0],
          [1.0, 1.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0],
          [1.0, 0.0, 1.0],
          [1.0, 1.0, 1.0],
          [0.0, 1.0, 1.0],
        ];
        const cubeFaces = [
          [0, 2, 1],
          [0, 3, 2],
          [4, 5, 6],
          [4, 6, 7],
          [0, 1, 5],
          [0, 5, 4],
          [3, 7, 6],
          [3, 6, 2],
          [0, 4, 7],
          [0, 7, 3],
          [1, 2, 6],
          [1, 6, 5],
        ];
        final triangles = [
          for (final f in cubeFaces) [for (final i in f) cube[i]],
          [
            [3.0, 0.0, 0.0],
            [4.0, 0.0, 0.0],
            [4.0, 1.0, 0.0],
          ],
          [
            [3.0, 0.0, 0.0],
            [4.0, 1.0, 0.0],
            [3.0, 1.0, 0.0],
          ],
        ];
        for (final hybrid in [false, true]) {
          final result = architectWriteIfc({
            'id': 'mixed-project',
            'name': '',
            'timestamp': 1793836800,
            'schema': schema.name,
            'storeys': [
              {
                'id': 's',
                'name': '',
                'elevation': 0.0,
                'height': 3.0,
                'elements': [
                  {
                    'id': 'mixed-components',
                    'kind': 'door',
                    'name': '',
                    'height': 1.0,
                    'width': 4.0,
                    'shapes': [
                      {'type': 'mesh', 'triangles': triangles},
                      if (hybrid)
                        {
                          'type': 'extrusion',
                          'depth': 1.0,
                          'polygon': [
                            [6.0, 0.0],
                            [7.0, 0.0],
                            [7.0, 1.0],
                            [6.0, 1.0],
                          ],
                        },
                    ],
                  },
                ],
              },
            ],
          });
          final text = utf8.decode(result['bytes']);
          expect(RegExp("'Body',").allMatches(text).length, 1);
          expect(
            text,
            contains(
              schema == ArchitectIfcSchema.ifc4
                  ? "'Body','SurfaceOrSolidModel'"
                  : hybrid
                  ? "'Body','MappedRepresentation'"
                  : "'Body','SurfaceModel'",
            ),
          );
          Directory(
            'build/architect_export_validation',
          ).createSync(recursive: true);
          File(
            'build/architect_export_validation/architect_mixed_${hybrid ? 'hybrid_' : ''}${schema.name}.ifc',
          ).writeAsBytesSync(result['bytes']);
        }
      },
    );
  }

  for (final schema in ArchitectIfcSchema.values) {
    test(
      '${schema.name}: actual BIM classes, storeys, layers and voids',
      () async {
        final project = _project();
        final before = jsonEncode(project.toJson());
        final result = await ArchitectIfcExport.exportProject(
          project,
          l,
          schema: schema,
        );
        final text = utf8.decode(result.bytes);
        expect(
          text,
          contains(
            "FILE_SCHEMA(('${schema == ArchitectIfcSchema.ifc2x3 ? 'IFC2X3' : 'IFC4'}'))",
          ),
        );
        expect(_count(text, 'IFCBUILDINGSTOREY'), 2);
        expect(_count(text, 'IFCDOOR'), 1);
        expect(_count(text, 'IFCWINDOW'), 1);
        expect(_count(text, 'IFCSLAB'), greaterThanOrEqualTo(3));
        expect(_count(text, 'IFCCOLUMN'), 2);
        expect(_count(text, 'IFCBEAM'), 1);
        expect(_count(text, 'IFCROOF'), 1);
        expect(_count(text, 'IFCSTAIR'), 1);
        expect(_count(text, 'IFCSTAIRFLIGHT'), 2);
        expect(_count(text, 'IFCRAILING'), 1);
        expect(_count(text, 'IFCSPACE'), 1);
        expect(_count(text, 'IFCRELVOIDSELEMENT'), 3);
        expect(_count(text, 'IFCRELFILLSELEMENT'), 2);
        expect(text, contains('IFCMATERIALLAYERSETUSAGE'));
        expect(text, contains('.METRE.'));
        expect(text, contains(r'\X2\0415\X0\'));
        expect(
          result.notices
              .where((n) => n.code == 'missingGeometry')
              .map((n) => n.elementId),
          ['unknown-component'],
        );
        expect(result.parametricCount, greaterThan(4));
        expect(jsonEncode(project.toJson()), before);
        if (schema == ArchitectIfcSchema.ifc2x3) {
          expect(_count(text, 'IFCWALLSTANDARDCASE'), greaterThan(0));
          expect(_count(text, 'IFCDOORSTYLE'), 1);
        } else {
          expect(_count(text, 'IFCWALLSTANDARDCASE'), 0);
          expect(_count(text, 'IFCDOORTYPE'), 1);
        }
        final reopened = IfcParser.parseFromText(text);
        expect(reopened.elements.expand((e) => e.triangles), isNotEmpty);
        final directory = Directory('build/architect_export_validation')
          ..createSync(recursive: true);
        File(
          '${directory.path}/architect_all_categories_${schema.name}.ifc',
        ).writeAsBytesSync(result.bytes);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  test(
    'supplied two-view project exports each physical source once',
    () async {
      final raw = jsonDecode(
        File(
          'test/fixtures/architect_layout_two_views_2026_11_05.json',
        ).readAsStringSync(),
      );
      final project = ArchitectProject.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      final result = await ArchitectIfcExport.exportProject(project, l);
      final text = utf8.decode(result.bytes);
      expect(_count(text, 'IFCWALLSTANDARDCASE') + _count(text, 'IFCWALL'), 20);
      expect(_count(text, 'IFCSTAIR'), 3);
      expect(_count(text, 'IFCBUILDINGSTOREY'), 1);
      expect(result.notices.where((n) => n.code == 'missingGeometry'), isEmpty);
      expect(
        result.notices
            .where((n) => n.code == 'unhostedOpening')
            .map((n) => n.elementId),
        project.storeys.single.openings.map((o) => o.id),
      );
      File(
        'build/architect_export_validation/architect_supplied_ifc2x3.ifc',
      ).writeAsBytesSync(result.bytes);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'element GUID survives storey relocation; duplicate IDs fail explicitly',
    () async {
      const wall = ArchitectWall(
        id: 'stable-wall',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
      );
      final first = _project().copyWith(
        storeys: [
          const ArchitectStorey(id: 'one', name: '', walls: [wall]),
          const ArchitectStorey(id: 'two', name: '', elevation: 3),
        ],
      );
      final moved = first.copyWith(
        storeys: [
          const ArchitectStorey(
            id: 'two',
            name: '',
            elevation: 3,
            walls: [wall],
          ),
          const ArchitectStorey(id: 'one', name: ''),
        ],
      );
      final guid = architectIfcGuid(first.id, 'element:stable-wall');
      for (final project in [first, moved]) {
        final result = await ArchitectIfcExport.exportProject(project, l);
        expect(
          utf8.decode(result.bytes),
          contains("IFCWALLSTANDARDCASE('$guid'"),
        );
      }
      final duplicate = first.copyWith(
        storeys: [
          const ArchitectStorey(id: 'one', name: '', walls: [wall]),
          const ArchitectStorey(id: 'two', name: '', walls: [wall]),
        ],
      );
      await expectLater(
        ArchitectIfcExport.exportProject(duplicate, l),
        throwsA(
          isA<ArchitectExportElementError>().having(
            (e) => e.elementId,
            'source id',
            'stable-wall',
          ),
        ),
      );
    },
  );

  test('hosted source opening IDs survive contour order changes', () async {
    const a = ArchitectOpening(
      id: 'cut-a',
      boundary: [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
    );
    const b = ArchitectOpening(
      id: 'cut-b',
      boundary: [Offset(3, 1), Offset(4, 1), Offset(4, 2), Offset(3, 2)],
    );
    final base = _project().copyWith(
      storeys: [
        const ArchitectStorey(
          id: 'one',
          name: '',
          slabs: [
            ArchitectSlab(id: 'floor', polygon: _polygon, assemblyId: 'bare'),
          ],
          openings: [a, b],
        ),
      ],
    );
    for (final openings in [
      [a, b],
      [b, a],
    ]) {
      final project = base.copyWith(
        storeys: [base.storeys.single.copyWith(openings: openings)],
      );
      final result = await ArchitectIfcExport.exportProject(project, l);
      final text = utf8.decode(result.bytes);
      for (final id in ['cut-a', 'cut-b']) {
        expect(
          text,
          contains(
            "IFCOPENINGELEMENT('${architectIfcGuid(base.id, 'element:floor:opening:$id')}'",
          ),
        );
      }
      expect(result.notices.where((n) => n.code == 'unhostedOpening'), isEmpty);
    }
  });

  test(
    'complex roofs and curved walls retain typed original solid bodies',
    () async {
      final storey = ArchitectStorey(
        id: 'complex',
        name: 'Complex',
        walls: const [
          ArchitectWall(
            id: 'curved-wall',
            startPoint: Offset(0, 0),
            endPoint: Offset(4, 0),
            arcBulge: .2,
            height: 2.8,
            followStoreyHeight: false,
          ),
        ],
        roofs: [
          ArchitectRoofPlane(
            id: 'mansard',
            storeyId: 'complex',
            points: [
              const Offset(10, 0),
              const Offset(15, 0),
              const Offset(15, 6),
              const Offset(10, 6),
            ],
            isMansard: true,
            slopeDegrees: 60,
            upperSlopeDegrees: 25,
            attachToWalls: false,
          ),
          ArchitectRoofPlane(
            id: 'panel-roof',
            storeyId: 'complex',
            points: [
              const Offset(20, 0),
              const Offset(25, 0),
              const Offset(25, 5),
              const Offset(20, 5),
            ],
            attachToWalls: false,
            assembly: ArchitectRoofAssembly.fromPreset(
              ArchitectRoofPreset.sandwichPitched,
            ),
          ),
        ],
      );
      final result = await ArchitectIfcExport.exportProject(
        _project().copyWith(storeys: [storey]),
        l,
        schema: ArchitectIfcSchema.ifc4,
      );
      final text = utf8.decode(result.bytes);
      expect(_count(text, 'IFCWALL'), 1);
      expect(_count(text, 'IFCROOF'), 2);
      expect(
        result.notices.where((n) => n.code == 'geometryFallback'),
        isNotEmpty,
      );
      expect(result.notices.where((n) => n.code == 'missingGeometry'), isEmpty);
      File(
        'build/architect_export_validation/architect_complex_ifc4.ifc',
      ).writeAsBytesSync(result.bytes);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'cancellation aborts before geometry and identifies invalid source',
    () async {
      await expectLater(
        ArchitectIfcExport.exportProject(
          _project(),
          l,
          isCancelled: () => true,
        ),
        throwsA(isA<ArchitectExportCancelled>()),
      );
      final invalid = _project().copyWith(
        storeys: [
          const ArchitectStorey(
            id: 'bad',
            name: '',
            slabs: [ArchitectSlab(id: 'bad-slab', polygon: [], thickness: .2)],
          ),
        ],
      );
      await expectLater(
        ArchitectIfcExport.exportProject(invalid, l),
        throwsA(
          isA<ArchitectExportElementError>().having(
            (e) => e.elementId,
            'source id',
            'bad-slab',
          ),
        ),
      );
      for (final column in const [
        ArchitectColumn(id: 'bad-column', position: Offset.zero, width: 0),
        ArchitectColumn(id: 'bad-column', position: Offset.zero, depth: -.1),
      ]) {
        final invalidColumn = _project().copyWith(
          storeys: [
            ArchitectStorey(id: 'bad', name: '', columns: [column]),
          ],
        );
        await expectLater(
          ArchitectIfcExport.exportProject(invalidColumn, l),
          throwsA(
            isA<ArchitectExportElementError>().having(
              (e) => e.elementId,
              'source id',
              'bad-column',
            ),
          ),
        );
      }
    },
  );
}
