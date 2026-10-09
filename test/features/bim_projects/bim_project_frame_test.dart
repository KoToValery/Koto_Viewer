import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_loader.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

class DrawingLibrary extends BimProjectLibraryService {
  final DxfDocument doc;
  DrawingLibrary(this.doc);
  @override
  Future<BimWorkProject> prepareUnderlays(
    BimWorkProject project, {
    Map<String, DxfDocument>? loadedDocuments,
  }) async {
    for (final s in project.storeys) {
      loadedDocuments?[s.storeyId] = doc;
    }
    return project;
  }
}

void main() {
  test(
    'Replacement and reference removal keep persisted coordinates and project units',
    () async {
      final p = BimWorkProject(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        structuralOrigin: const Offset(10, 20),
        structuralUnitsPerMeter: 1,
        referenceStoreyId: 'deleted',
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 's1',
            name: 'S1',
            elevation: 2.8,
            underlayFileName: 'new.kcad',
            controlPoint: Offset(1000, 2000),
          ),
        ],
      );
      final roundtrip = BimWorkProject.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      );
      final doc = DxfDocument(
        entities: [
          DxfLine(
            layer: 'walls',
            p1: const Offset(1000, 2000),
            p2: const Offset(3000, 2000),
          ),
        ],
        layers: {'walls': DxfLayer(name: 'walls')},
        blocks: {},
        bounds: const Rect.fromLTWH(1000, 2000, 10000, 10000),
        entityStats: {},
        headerVars: {
          r'$INSUNITS': '4',
          BimUnderlayMetadata.key: jsonEncode({
            'version': BimUnderlayMetadata.version,
            'complete': true,
            'hasResults': false,
            'layers': [],
            'visibility': {'walls': true},
            'axes': [],
          }),
        },
      );
      final loaded = await BimUnderlayLoader.loadAndAlign(
        project: roundtrip,
        libraryService: DrawingLibrary(doc),
      );
      expect(loaded.referenceControlPoint, const Offset(10, 20));
      expect(loaded.cadUnitsPerMeter, 1);
      final line = loaded.underlaysByStorey['s1']!.entities
          .whereType<DxfLine>()
          .single;
      expect(line.p1, const Offset(10, 20));
      expect(line.p2, const Offset(12, 20));
    },
  );
  test(
    'DXF export uses the fixed project origin after a control point revision',
    () async {
      final temp = await Directory.systemTemp.createTemp('fixed_frame_export_');
      addTearDown(() => temp.delete(recursive: true));
      final p = BimWorkProject(
        id: 'p',
        name: 'P',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        structuralOrigin: const Offset(100, 200),
        structuralUnitsPerMeter: 1,
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 's',
            name: 'S',
            elevation: 0,
            controlPoint: Offset(10, 20),
          ),
        ],
      );
      const axis = StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset(100, 200),
        end: Offset(102, 200),
      );
      final file = await BimExportService.exportStoreyDxf(
        project: p,
        structural: const StructuralProject(
          title: 'P',
          gridAxes: [axis],
          storeys: [StoreyLevel(id: 's', name: 'S', elevation: 0)],
        ),
        storeyId: 's',
        outputDirectory: temp,
      );
      final doc = await DxfParser.parseFromFile(file);
      final line = doc.entities.whereType<DxfLine>().single;
      expect(line.p1, const Offset(10, 20));
      expect(line.p2, const Offset(12, 20));
    },
  );
}
