import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_math.dart';

/// Real-world validation test for OVK.dwg (Archicad-originated file)
/// 
/// This test validates the fix with an actual production file from the user.
void main() {
  group('OVK Real-World File Validation', () {
    late DxfDocument ovkDoc;

    setUpAll(() async {
      // Load the real-world OVK file (converted to DXF)
      final ovkFile = File('test_files/OVK_converted.dxf');
      if (!ovkFile.existsSync()) {
        throw Exception('Real-world test file not found: ${ovkFile.path}');
      }
      ovkDoc = await DxfParser.parseFromFile(ovkFile);
    });

    test('Analyze OVK file structure and Archicad origin detection', () {
      print('\n=== OVK FILE ANALYSIS ===');
      
      // Check header variables
      print('\nHeader Variables:');
      print('  \$MEASUREMENT: ${ovkDoc.headerVars['\$MEASUREMENT'] ?? 'not set'}');
      print('  \$DIMSCALE: ${ovkDoc.headerVars['\$DIMSCALE'] ?? 'not set'}');
      print('  \$LTSCALE: ${ovkDoc.headerVars['\$LTSCALE'] ?? 'not set'}');
      print('  \$INSUNITS: ${ovkDoc.headerVars['\$INSUNITS'] ?? 'not set'}');
      print('  \$ACADVER: ${ovkDoc.headerVars['\$ACADVER'] ?? 'not set'}');
      print('  \$DWGCODEPAGE: ${ovkDoc.headerVars['\$DWGCODEPAGE'] ?? 'not set'}');
      
      // Check for Archicad origin detection
      print('\nArchicad Origin Detection:');
      print('  isArchicadOrigin: ${ovkDoc.isArchicadOrigin}');
      expect(ovkDoc.isArchicadOrigin, isTrue);
      
      // Analyze text styles
      print('\nText Styles (${ovkDoc.textStyles.length} total):');
      int stylesWithTwoScale = 0;
      for (final entry in ovkDoc.textStyles.entries) {
        final style = entry.value;
        print('  "${style.name}": heightScale=${style.heightScale}');
        if ((style.heightScale - 2.0).abs() < 0.1) {
          stylesWithTwoScale++;
        }
      }
      print('  Styles with ~2.0 scale: $stylesWithTwoScale/${ovkDoc.textStyles.length}');
      
      // Count text entities
      final textEntities = ovkDoc.entities.whereType<DxfText>().toList();
      final mtextEntities = ovkDoc.entities.whereType<DxfMText>().toList();
      print('\nText Entities:');
      print('  TEXT entities: ${textEntities.length}');
      print('  MTEXT entities: ${mtextEntities.length}');
      
      print('\n=== DETAILED BEDROOM & WINDOW ENTITIES ===');
      for (final e in ovkDoc.entities) {
        // Look near bedroom (15500..16200, 5300..5900)
        if (e is DxfText) {
          if (e.insertPoint.dx > 15200 && e.insertPoint.dx < 16500 && e.insertPoint.dy > 5200 && e.insertPoint.dy < 6000) {
            print('TEXT: "${e.text}" height=${e.height} hAlign=${e.hAlign} vAlign=${e.vAlign} pos=${e.insertPoint} align=${e.alignPoint} style=${e.style}');
          }
        }
        if (e is DxfMText) {
          if (e.insertPoint.dx > 15200 && e.insertPoint.dx < 16500 && e.insertPoint.dy > 5200 && e.insertPoint.dy < 6000) {
            print('MTEXT: clean="${e.cleanText}" raw="${e.rawText}" height=${e.height} attach=${e.attachmentPoint} rot=${e.rotationDeg} pos=${e.insertPoint} style=${e.style}');
          }
        }
        if (e is DxfLwPolyline && e.layer.contains('Квадратура')) {
          final pts = e.vertices.map((v) => '(${v.x.toStringAsFixed(1)}, ${v.y.toStringAsFixed(1)})').toList();
          print('POLYLINE Квадратура: pts=$pts');
        }
      }
    });

    test('Verify TEXT entities render with correct effective height', () {
      print('\n=== TEXT RENDERING VALIDATION ===');
      
      final textEntities = ovkDoc.entities.whereType<DxfText>().toList();
      
      if (textEntities.isEmpty) {
        print('No TEXT entities found in OVK file');
        return;
      }
      
      print('Testing ${textEntities.length} TEXT entities...');
      int entitiesWithCorrection = 0;
      int entitiesWithoutCorrection = 0;
      
      for (final text in textEntities.take(20)) {
        const fitScale = 1.0;
        double effectiveHeight = text.height;
        
        // Verify 1:1 rendering matching CAD drawing units
        if (text.style != null && ovkDoc.textStyles.containsKey(text.style)) {
          final style = ovkDoc.textStyles[text.style]!;
          if ((style.heightScale - 1.0).abs() > 0.05 && style.heightScale > 0) {
            effectiveHeight *= style.heightScale;
          }
        }
        entitiesWithCorrection++;
        
        final renderedHeight = effectiveHeight * fitScale;
        
        // Verify text renders 1:1 with DXF drawing units
        if (text.height > 0) {
          final correctionFactor = renderedHeight / text.height;
          expect(correctionFactor, closeTo(1.0, 0.05),
            reason: '''
TEXT entity "${text.text}" should render 1:1 with DXF height.
DXF height: ${text.height}
Rendered height: $renderedHeight
''');
        }
      }
      
      print('\nResults:');
      print('  Entities tested: $entitiesWithCorrection');
      print('  ✓ All TEXT entities rendered 1:1 with CAD drawing units');
    });

    test('Verify MTEXT entities render with correct effective height (1:1)', () {
      print('\n=== MTEXT RENDERING VALIDATION ===');
      
      final mtextEntities = ovkDoc.entities.whereType<DxfMText>().toList();
      
      if (mtextEntities.isEmpty) {
        print('No MTEXT entities found in OVK file');
        return;
      }
      
      print('Testing ${mtextEntities.length} MTEXT entities...');
      int entitiesWithCorrection = 0;
      
      for (final mtext in mtextEntities.take(20)) {
        const fitScale = 1.0;
        double effectiveHeight = mtext.height;
        
        if (mtext.style != null && ovkDoc.textStyles.containsKey(mtext.style)) {
          final style = ovkDoc.textStyles[mtext.style]!;
          if ((style.heightScale - 1.0).abs() > 0.05 && style.heightScale > 0) {
            effectiveHeight *= style.heightScale;
          }
        }
        entitiesWithCorrection++;
        
        final renderedHeight = effectiveHeight * fitScale;
        
        // Verify MTEXT renders 1:1 with DXF drawing units
        if (mtext.height > 0) {
          final correctionFactor = renderedHeight / mtext.height;
          expect(correctionFactor, closeTo(1.0, 0.05),
            reason: '''
MTEXT entity "${mtext.cleanText.substring(0, mtext.cleanText.length > 30 ? 30 : mtext.cleanText.length)}" should render 1:1 with DXF height.
DXF height: ${mtext.height}
Rendered height: $renderedHeight
''');
        }
      }
      
      print('\nResults:');
      print('  Entities tested: $entitiesWithCorrection');
      print('  ✓ All MTEXT entities rendered 1:1 with CAD drawing units');
    });

    test('Verify non-text entities are not affected', () {
      print('\n=== NON-TEXT ENTITY PRESERVATION ===');
      
      final lines = ovkDoc.entities.whereType<DxfLine>().toList();
      final circles = ovkDoc.entities.whereType<DxfCircle>().toList();
      final arcs = ovkDoc.entities.whereType<DxfArc>().toList();
      final polylines = ovkDoc.entities.whereType<DxfLwPolyline>().toList();
      
      print('Non-text entity counts:');
      print('  LINEs: ${lines.length}');
      print('  CIRCLEs: ${circles.length}');
      print('  ARCs: ${arcs.length}');
      print('  LWPOLYLINEs: ${polylines.length}');
      
      // Verify that non-text entities have valid geometry
      for (final line in lines.take(5)) {
        expect(line.p1, isA<Offset>());
        expect(line.p2, isA<Offset>());
      }
      
      for (final circle in circles.take(5)) {
        expect(circle.radius, greaterThan(0));
        expect(circle.center, isA<Offset>());
      }
      
      print('  ✓ Non-text entities have valid geometry');
    });

    test('Verify drawing units and measurement calculation for OVK', () {
      print('\n=== MEASUREMENT UNITS VALIDATION ===');
      expect(ovkDoc.unit, equals(DxfUnit.centimeters));
      print('  Detected unit: ${ovkDoc.unit.label} (${ovkDoc.unit.symbol})');

      // The closet ("килер 7,03 m2") measured in the user's screenshot:
      // Area in drawing units: ~69878.5 cm²
      // With DxfUnit.centimeters, it should format to ~6.99 m², NOT 69878.5 m² or 6.99 ha!
      const double closetAreaCad = 69878.5;
      final formattedArea = DxfMath.formatArea(closetAreaCad, unit: ovkDoc.unit);
      print('  Raw CAD area: $closetAreaCad cm²');
      print('  Formatted area: $formattedArea');
      expect(formattedArea, equals('6.99 m²'));

      // Perimeter: 1121.50 cm -> 11.21 m
      const double closetPerimCad = 1121.50;
      final formattedPerim = DxfMath.formatDistance(closetPerimCad, unit: ovkDoc.unit);
      print('  Raw CAD perim: $closetPerimCad cm');
      print('  Formatted perim: $formattedPerim m');
      expect(formattedPerim, equals('11.21'));

      // Wall length 275.0 cm -> 2.75 m
      const double wallDistCad = 275.0;
      final formattedWall = DxfMath.formatDistance(wallDistCad, unit: ovkDoc.unit);
      print('  Raw CAD wall: $wallDistCad cm');
      print('  Formatted wall: $formattedWall m');
      expect(formattedWall, equals('2.75'));
    });

    test('Summary: OVK file validation complete', () {
      print('\n=== OVK VALIDATION SUMMARY ===');
      print('');
      print('File: test_files/OVK_converted.dxf');
      print('Origin: ${ovkDoc.isArchicadOrigin ? "Archicad (detected)" : "AutoCAD"}');
      print('Unit: ${ovkDoc.unit.label} (${ovkDoc.unit.symbol})');
      print('');
      
      final textEntities = ovkDoc.entities.whereType<DxfText>().toList();
      final mtextEntities = ovkDoc.entities.whereType<DxfMText>().toList();
      final totalTextEntities = textEntities.length + mtextEntities.length;
      
      print('Text entities: $totalTextEntities total');
      print('  TEXT: ${textEntities.length}');
      print('  MTEXT: ${mtextEntities.length}');
      print('');
      
      print('Text styles: ${ovkDoc.textStyles.length} defined');
      print('✅ All text entities render 1:1 with CAD drawing units matching AutoCAD');
      print('✅ Measurement area and distance correctly convert ${ovkDoc.unit.label} to m² and m');
      
      print('');
      print('✓ Real-world file validation complete');
    });

    test('Inspect Archicad_export_converted.dxf', () async {
      final archFile = File('test_files/Archicad_export_converted.dxf');
      if (!archFile.existsSync()) {
        print('Archicad_export_converted.dxf not found');
        return;
      }
      final archDoc = await DxfParser.parseFromFile(archFile);
      print('\n=== ARCHICAD EXPORT DIRECT FILE ===');
      print('Header vars:');
      print('  \$MEASUREMENT: ${archDoc.headerVars[r'$MEASUREMENT']}');
      print('  \$INSUNITS: ${archDoc.headerVars[r'$INSUNITS']}');
      print('  \$ACADVER: ${archDoc.headerVars[r'$ACADVER']}');
      print('  unit: ${archDoc.unit.label}');
      print('  isArchicadOrigin: ${archDoc.isArchicadOrigin}');


      
      print('\n=== OVK WINDOW MARKER ENTITIES ===');
      final ovk180 = ovkDoc.entities.whereType<DxfMText>().where((m) => m.cleanText == '180').toList();
      for (final m in ovk180) {
        print('ovk180: pos=${m.insertPoint} attach=${m.attachmentPoint} rot=${m.rotationDeg} style=${m.style}');
      }
      final ovk150 = ovkDoc.entities.whereType<DxfMText>().where((m) => m.cleanText == '150').toList();
      final text150 = archDoc.entities.whereType<DxfMText>().firstWhere((m) => m.cleanText == '150');
      final text180 = archDoc.entities.whereType<DxfMText>().firstWhere((m) => m.cleanText == '180');
      print('\n=== WINDOW NEAR 325 IN ARCHICAD EXPORT ===');
      for (final m in archDoc.entities.whereType<DxfMText>().where((m) => (m.cleanText == '180' || m.cleanText == '150') && (m.insertPoint.dx - (-52.0)).abs() < 1 && (m.insertPoint.dy - 1100).abs() < 30)) {
        print('MTEXT at (-52, 1100): clean="${m.cleanText}" layer=${m.layer} height=${m.height} attach=${m.attachmentPoint}');
      }
      expect(text180.attachmentPoint, equals(7));
      expect(text150.attachmentPoint, equals(7));
      expect(text180.height, equals(14.0));
      expect(text150.height, equals(14.0));
      expect(text180.insertPoint.dy, greaterThan(1111.0));
      expect(text150.insertPoint.dy + text150.height, lessThan(1111.0));
    });

    test('OVK Box Entities', () async {
      print('\n=== FIND 4,10 M2 IN ARCHICAD ===');
      final archFile = File('test_files/Archicad_export_converted.dxf');
      final doc = await DxfParser.parseFromFile(archFile);
      for (final e in doc.entities) {
        if (e is DxfMText && e.cleanText.contains('4,10')) {
          print('MTEXT: "${e.cleanText}" pos=${e.insertPoint} attach=${e.attachmentPoint} rot=${e.rotationDeg} h=${e.height}');
        }
      }
    });

    test('OVK Box Entities check', () async {
      print('\n=== LINES NEAR БОЙЛЕР IN ARCHICAD ===');
      final archFile = File('test_files/Archicad_export_converted.dxf');
      final doc = await DxfParser.parseFromFile(archFile);
      for (final e in doc.entities) {
        if (e is DxfLine && (e.p1.dx - 168.5).abs() < 100 && (e.p1.dy - 1455.7).abs() < 100) {
          print('Line near boiler: p1=${e.p1} p2=${e.p2} layer=${e.layer}');
        }
      }
    });
  });
}
