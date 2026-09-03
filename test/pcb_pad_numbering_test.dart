import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pcb_viewer/models/pcb_models.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/gerber_parser.dart';
import 'package:kotoview/src/features/pcb_viewer/services/pcb_pad_numbering_service.dart';
import 'package:kotoview/src/features/pcb_viewer/rendering/pcb_multi_layer_painter.dart';

void main() {
  group('PCB Pad & Pin Numbering Tests', () {
    test('GerberParser extracts Gerber X2 pin numbers and net attributes', () {
      const gerberX2 = '''%FSLAX24Y24*%
%MOMM*%
%ADD10C,1.000*%
%TO.C,R4*%
%TO.P,1*%
%TO.N,GND*%
D10*
X100000Y200000D03*
%TO.P,2*%
%TO.N,VCC*%
X100000Y220000D03*
%TD*%
M02*''';

      final doc = GerberParser.parse(Uint8List.fromList(utf8.encode(gerberX2)), fileName: 'copper_top.gtl');
      expect(doc.commands.length, equals(2));
      expect(doc.commands[0].type, equals(PcbCommandType.flash));
      expect(doc.commands[0].pinNumber, equals('1'));
      expect(doc.commands[0].netName, equals('GND'));
      expect(doc.commands[0].componentRef, equals('R4'));

      expect(doc.commands[1].pinNumber, equals('2'));
      expect(doc.commands[1].netName, equals('VCC'));
    });

    test('GerberParser extracts Gerber X2 %TO.P,<refdes>,<pin>% format', () {
      const gerberX2Standard = '''%FSLAX24Y24*%
%MOMM*%
%ADD10C,1.000*%
%TO.P,U1,1*%
D10*
X100000Y200000D03*
%TO.P,U1,2*%
X100000Y220000D03*
%TD*%
M02*''';

      final doc = GerberParser.parse(Uint8List.fromList(utf8.encode(gerberX2Standard)), fileName: 'copper_top.gtl');
      expect(doc.commands.length, equals(2));
      expect(doc.commands[0].pinNumber, equals('1'));
      expect(doc.commands[0].componentRef, equals('U1'));
      expect(doc.commands[1].pinNumber, equals('2'));
      expect(doc.commands[1].componentRef, equals('U1'));
    });

    test('PcbPadNumberingService does NOT generate programmatic pad numbering for legacy files', () {
      const aperture = PcbAperture(id: 10, type: PcbApertureType.rectangle, dimX: 1.2, dimY: 0.8);
      final pad1 = PcbCommand.flash(p1: const Offset(10.0, 10.0), aperture: aperture);
      final pad2 = PcbCommand.flash(p1: const Offset(12.0, 10.0), aperture: aperture);

      final doc = PcbDocument(
        fileName: 'top_copper.gbr',
        layerType: PcbLayerType.copperTop,
        commands: [pad1, pad2],
        drillHoles: const [],
        boundingBox: const PcbBoundingBox(minX: 0, minY: 0, maxX: 30, maxY: 30),
      );

      final project = PcbProject(
        projectName: 'LegacyBoard',
        sourcePath: '/test/board.zip',
        layers: [
          PcbLayerItem(fileName: 'top_copper.gbr', type: PcbLayerType.copperTop, document: doc, order: 10),
        ],
        boundingBox: const PcbBoundingBox(minX: 0, minY: 0, maxX: 30, maxY: 30),
      );

      // Should NOT invent fake 1 and 2 numbers!
      final resultProject = PcbPadNumberingService.assignPadNumbers(project);
      final cmds = resultProject.layers.first.document.commands;
      expect(cmds[0].pinNumber, isNull);
      expect(cmds[1].pinNumber, isNull);
      expect(resultProject.hasPadNumbers, isFalse);
    });

    test('PcbPadNumberingService synchronizes authentic pad numbers and does not invent fake drill numbers', () {
      const aperture = PcbAperture(id: 11, type: PcbApertureType.circle, dimX: 1.5);
      final padWithNativePin = PcbCommand.flash(
        p1: const Offset(10.0, 10.0),
        aperture: aperture,
        pinNumber: '1',
      );

      final copperDoc = PcbDocument(
        fileName: 'top_copper.gbr',
        layerType: PcbLayerType.copperTop,
        commands: [padWithNativePin],
        drillHoles: const [],
        boundingBox: const PcbBoundingBox(minX: 0, minY: 0, maxX: 100, maxY: 100),
      );

      final drillDoc = PcbDocument(
        fileName: 'drills.drl',
        layerType: PcbLayerType.drill,
        commands: const [],
        drillHoles: const [
          PcbDrillHole(position: Offset(10.0, 10.0), diameterMm: 0.8, toolId: 1),
          PcbDrillHole(position: Offset(50.0, 50.0), diameterMm: 1.0, toolId: 2),
        ],
        boundingBox: const PcbBoundingBox(minX: 0, minY: 0, maxX: 100, maxY: 100),
      );

      final project = PcbProject(
        projectName: 'X2Board',
        sourcePath: '/test/board.zip',
        layers: [
          PcbLayerItem(fileName: 'top_copper.gbr', type: PcbLayerType.copperTop, document: copperDoc, order: 10),
          PcbLayerItem(fileName: 'drills.drl', type: PcbLayerType.drill, document: drillDoc, order: 80),
        ],
        boundingBox: const PcbBoundingBox(minX: 0, minY: 0, maxX: 100, maxY: 100),
      );

      final numbered = PcbPadNumberingService.assignPadNumbers(project);
      expect(numbered.hasPadNumbers, isTrue);

      final drills = numbered.layers.firstWhere((l) => l.type == PcbLayerType.drill).document.drillHoles;
      // Coincident drill hole gets authentic matched pin '1'
      expect(drills[0].pinNumber, equals('1'));
      // Unmatched drill hole does NOT get a fake '1'
      expect(drills[1].pinNumber, isNull);
    });

    test('PcbMultiLayerPainter repaints when showPadNumbers toggles', () {
      final project = PcbProject(
        projectName: 'Test',
        sourcePath: '/test',
        layers: const [],
        boundingBox: PcbBoundingBox.defaultBox,
      );

      final painter1 = PcbMultiLayerPainter(
        project: project,
        theme: PcbTheme.fr4Green,
        showPadNumbers: true,
      );

      final painter2 = PcbMultiLayerPainter(
        project: project,
        theme: PcbTheme.fr4Green,
        showPadNumbers: false,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}
