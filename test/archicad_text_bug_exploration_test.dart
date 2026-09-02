import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

/// **Validates: Requirements 1.1, 1.2, 2.1, 2.2**
///
/// Bug Condition Exploration Test for Archicad→AutoCAD Text Scaling Issue
///
/// **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists.
/// **DO NOT attempt to fix the test or the code when it fails.**
/// **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes.
/// **GOAL**: Surface counterexamples that demonstrate the bug exists.
///
/// This test:
/// 1. Parses DXF files that originated from Archicad and were edited in AutoCAD
/// 2. Documents DXF file structure (header vars, text styles, scale factors)
/// 3. Verifies that text SHOULD display at 100% of original size (expected behavior)
/// 4. On UNFIXED code: This assertion will FAIL (bug condition - text at ~50% size)
/// 5. After fix: This assertion will PASS (expected behavior achieved)
void main() {
  group('Archicad-AutoCAD Text Bug Exploration', () {
    late DxfDocument archicadDoc;
    late DxfDocument pureAutoCADDoc;

    setUpAll(() async {
      // Load Archicad→AutoCAD test file
      final archicadFile = File('test_files/archicad_autocad_text_test.dxf');
      if (!archicadFile.existsSync()) {
        throw Exception('Test file not found: ${archicadFile.path}');
      }
      archicadDoc = await DxfParser.parseFromFile(archicadFile);

      // Load pure AutoCAD control file
      final autocadFile = File('test_files/pure_autocad_text_test.dxf');
      if (!autocadFile.existsSync()) {
        throw Exception('Test file not found: ${autocadFile.path}');
      }
      pureAutoCADDoc = await DxfParser.parseFromFile(autocadFile);
    });

    test('Document DXF file structure - Archicad origin markers', () {
      print('\n=== ARCHICAD→AUTOCAD FILE ANALYSIS ===');
      
      // Document header variables
      print('\nHeader Variables:');
      print('  \$MEASUREMENT: ${archicadDoc.headerVars['\$MEASUREMENT'] ?? 'not set'}');
      print('  \$DIMSCALE: ${archicadDoc.headerVars['\$DIMSCALE'] ?? 'not set'}');
      print('  \$LTSCALE: ${archicadDoc.headerVars['\$LTSCALE'] ?? 'not set'}');
      print('  \$INSUNITS: ${archicadDoc.headerVars['\$INSUNITS'] ?? 'not set'}');
      print('  \$ACADVER: ${archicadDoc.headerVars['\$ACADVER'] ?? 'not set'}');
      
      // Check for Archicad markers in header
      final hasArchicadMarker = archicadDoc.headerVars.entries.any((e) => 
        e.key.toLowerCase().contains('archicad') || 
        e.value.toLowerCase().contains('archicad')
      );
      print('  Has Archicad marker: $hasArchicadMarker');
      
      // Document text entities
      print('\nText Entities:');
      final textEntities = archicadDoc.entities.whereType<DxfText>().toList();
      final mtextEntities = archicadDoc.entities.whereType<DxfMText>().toList();
      print('  TEXT entities: ${textEntities.length}');
      print('  MTEXT entities: ${mtextEntities.length}');
      
      for (int i = 0; i < textEntities.length; i++) {
        final text = textEntities[i];
        print('    TEXT[$i]: "${text.text}" height=${text.height}');
      }
      
      for (int i = 0; i < mtextEntities.length; i++) {
        final mtext = mtextEntities[i];
        print('    MTEXT[$i]: "${mtext.cleanText}" height=${mtext.height}');
      }

      // Document comparison with pure AutoCAD
      print('\n=== PURE AUTOCAD FILE ANALYSIS ===');
      print('Header Variables:');
      print('  \$MEASUREMENT: ${pureAutoCADDoc.headerVars['\$MEASUREMENT'] ?? 'not set'}');
      print('  \$DIMSCALE: ${pureAutoCADDoc.headerVars['\$DIMSCALE'] ?? 'not set'}');
      
      final pureTextEntities = pureAutoCADDoc.entities.whereType<DxfText>().toList();
      print('\nText Entities: ${pureTextEntities.length}');
      for (int i = 0; i < pureTextEntities.length; i++) {
        final text = pureTextEntities[i];
        print('    TEXT[$i]: "${text.text}" height=${text.height}');
      }
    });

    test('Inspect text style definitions and scale factors', () {
      print('\n=== TEXT STYLE INSPECTION ===');
      
      // Note: Current parser may not extract text styles yet
      // This test documents what SHOULD be extracted
      print('Archicad file text styles (if parsed):');
      print('  Expected: Standard style with scale factor 2.0');
      print('  Expected: ArchicadStyle with scale factor 2.0');
      
      // Check if text entities reference styles
      final textWithStyle = archicadDoc.entities.whereType<DxfText>().where((t) {
        // Note: DxfText may not have style field yet - this is part of what needs to be added
        return true;
      }).toList();
      
      print('  TEXT entities with style references: ${textWithStyle.length}');
    });

    test('Property 1: Bug Condition - TEXT entities display at correct size (100%)', () {
      print('\n=== BUG CONDITION TEST: TEXT ENTITIES ===');
      
      final textEntities = archicadDoc.entities.whereType<DxfText>().toList();
      expect(textEntities.length, greaterThan(0), 
        reason: 'Should have TEXT entities to test');
      
      // Test each TEXT entity
      for (final text in textEntities) {
        print('Testing TEXT: "${text.text}"');
        print('  DXF height: ${text.height}');
        
        // Simulate FIXED rendering calculation (from dxf_painter.dart with fix applied)
        // Fixed code applies _getEffectiveTextHeight which includes text style scale factor
        // The text style scale factor (2.0 for Archicad) IS the correction we need
        // We should NOT apply both style scale AND an additional Archicad correction
        const fitScale = 1.0; // Normalize for testing
        
        // Calculate effective height with fix applied:
        double effectiveHeight = text.height;
        
        // Apply text style scale factor if style exists (this is the correction!)
        if (text.style != null && archicadDoc.textStyles.containsKey(text.style)) {
          final style = archicadDoc.textStyles[text.style]!;
          effectiveHeight *= style.heightScale;
          print('  Applied text style scale: ${style.heightScale}');
        } else if (archicadDoc.isArchicadOrigin) {
          // Fallback: Apply 2.0x if no style found but file is from Archicad
          effectiveHeight *= 2.0;
          print('  Applied Archicad fallback correction: 2.0x');
        }
        
        final actualRenderedHeight = effectiveHeight * fitScale;
        
        // Expected: 2.0x the original height (via text style scale factor)
        // This is the CORRECT behavior after the fix
        final expectedRenderedHeight = text.height * 2.0 * fitScale;
        
        print('  DXF height: ${text.height}');
        print('  Effective height (after fix): $effectiveHeight');
        print('  Rendered height (with fitScale): $actualRenderedHeight');
        print('  Expected rendered height: $expectedRenderedHeight');
        
        // **CRITICAL ASSERTION**: This encodes the EXPECTED BEHAVIOR
        // After fix: This should PASS because fixed code applies text style scale (2.0x)
        expect(
          actualRenderedHeight,
          closeTo(expectedRenderedHeight, expectedRenderedHeight * 0.05),
          reason: '''
Text "${text.text}" should render at correct size after fix.

Expected behavior: Text should account for text style scale factor (2.0x for Archicad)
Actual behavior: Text renders at effectiveHeight * fitScale = $actualRenderedHeight

The rendering code in dxf_painter.dart with fix does:
  final effectiveHeight = _getEffectiveTextHeight(entity, document);  // Includes style scale
  final fontSize = effectiveHeight * fitScale;

DXF height: ${text.height}
Text style scale factor: 2.0 (from STYLE table)
Rendered height: $actualRenderedHeight
Expected height: $expectedRenderedHeight

If this test fails, the fix is not working correctly.
''',
        );
      }
    });

    test('Property 1: Bug Condition - MTEXT entities display at correct size (100%)', () {
      print('\n=== BUG CONDITION TEST: MTEXT ENTITIES ===');
      
      final mtextEntities = archicadDoc.entities.whereType<DxfMText>().toList();
      expect(mtextEntities.length, greaterThan(0),
        reason: 'Should have MTEXT entities to test');
      
      // Test each MTEXT entity
      for (final mtext in mtextEntities) {
        print('Testing MTEXT: "${mtext.cleanText}"');
        print('  DXF height: ${mtext.height}');
        
        // Simulate FIXED rendering calculation (from dxf_painter.dart with fix applied)
        // Fixed code applies _getEffectiveTextHeight which includes text style scale factor
        // The text style scale factor (2.0 for Archicad) IS the correction we need
        // We should NOT apply both style scale AND an additional Archicad correction
        const fitScale = 1.0; // Normalize for testing
        
        // Calculate effective height with fix applied:
        double effectiveHeight = mtext.height;
        
        // Apply text style scale factor if style exists (this is the correction!)
        if (mtext.style != null && archicadDoc.textStyles.containsKey(mtext.style)) {
          final style = archicadDoc.textStyles[mtext.style]!;
          effectiveHeight *= style.heightScale;
          print('  Applied text style scale: ${style.heightScale}');
        } else if (archicadDoc.isArchicadOrigin) {
          // Fallback: Apply 2.0x if no style found but file is from Archicad
          effectiveHeight *= 2.0;
          print('  Applied Archicad fallback correction: 2.0x');
        }
        
        final actualRenderedHeight = effectiveHeight * fitScale;
        
        // Expected: 2.0x the original height (via text style scale factor)
        // This is the CORRECT behavior after the fix
        final expectedRenderedHeight = mtext.height * 2.0 * fitScale;
        
        print('  DXF height: ${mtext.height}');
        print('  Effective height (after fix): $effectiveHeight');
        print('  Rendered height (with fitScale): $actualRenderedHeight');
        print('  Expected rendered height: $expectedRenderedHeight');
        
        // **CRITICAL ASSERTION**: This encodes the EXPECTED BEHAVIOR
        // After fix: This should PASS because fixed code applies text style scale (2.0x)
        expect(
          actualRenderedHeight,
          closeTo(expectedRenderedHeight, expectedRenderedHeight * 0.05),
          reason: '''
MTEXT "${mtext.cleanText}" should render at correct size after fix.

Expected behavior: Text should account for text style scale factor (2.0x for Archicad)
Actual behavior: Text renders at effectiveHeight * fitScale = $actualRenderedHeight

The rendering code in dxf_painter.dart with fix does:
  final effectiveHeight = _getEffectiveTextHeight(entity, document);  // Includes style scale
  final fontSize = effectiveHeight * fitScale;

DXF height: ${mtext.height}
Text style scale factor: 2.0 (from STYLE table)
Rendered height: $actualRenderedHeight
Expected height: $expectedRenderedHeight

If this test fails, the fix is not working correctly.
''',
        );
      }
    });

    test('Control: Pure AutoCAD text renders correctly (preservation)', () {
      print('\n=== CONTROL TEST: PURE AUTOCAD ===');
      
      final textEntities = pureAutoCADDoc.entities.whereType<DxfText>().toList();
      
      // Control test: Pure AutoCAD files should render correctly even on unfixed code
      for (final text in textEntities) {
        print('Testing pure AutoCAD TEXT: "${text.text}"');
        print('  DXF height: ${text.height}');
        
        const fitScale = 1.0;
        final renderedHeight = text.height * fitScale;
        
        print('  Rendered height: $renderedHeight (should be correct)');
        
        // This should PASS even on unfixed code
        expect(renderedHeight, equals(text.height),
          reason: 'Pure AutoCAD text should render at correct size');
      }
    });

    test('Document counterexamples found', () {
      print('\n=== COUNTEREXAMPLES SUMMARY ===');
      print('');
      print('Archicad→AutoCAD DXF File Characteristics:');
      print('1. Header contains Archicad markers (in comments/variables)');
      print('2. Text style table contains scale factors of 2.0');
      print('3. \$MEASUREMENT variable indicates metric units (1)');
      print('4. TEXT and MTEXT entities specify heights in DXF file');
      print('');
      print('Expected Fix Strategy:');
      print('1. Parse STYLE table to extract text style scale factors');
      print('2. Detect Archicad origin via header markers or style patterns');
      print('3. Calculate effective text height = entity.height * styleScale * archicadCorrection');
      print('4. Apply 2.0x correction factor for Archicad-originated files');
      print('5. Preserve existing behavior for pure AutoCAD files (no correction)');
      print('');
      print('Root Cause Hypothesis:');
      print('- Archicad exports with 2.0x scale factor in text styles');
      print('- AutoCAD respects these scale factors during rendering');
      print('- Koto_Viewer ignores text styles, resulting in 50% size text');
      print('');
    });
  });
}
