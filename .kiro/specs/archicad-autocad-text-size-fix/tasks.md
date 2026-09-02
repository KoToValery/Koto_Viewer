# Implementation Plan

## Overview
This task list implements the fix for text scaling issues in Archicad→AutoCAD DWG/DXF files using the exploratory bugfix workflow. The fix involves parsing text styles, extracting header variables, detecting Archicad origin, calculating effective text height, and applying corrections while preserving all existing behavior.

---

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Archicad-AutoCAD Text Displays at 50% Size
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Scoped PBT Approach**: Test with known Archicad→AutoCAD DXF files to ensure reproducibility
  - Test implementation details from Bug Condition in design:
    - Parse DXF files that originated from Archicad and were edited in AutoCAD
    - Render TEXT and MTEXT entities using current rendering code
    - Measure actual rendered text sizes
    - Assert that text displays at approximately 50% of expected size (bug condition)
    - Compare with AutoCAD's rendering (reference measurements)
  - The test assertions should match the Expected Behavior Properties from design:
    - After fix: text should display at 100% of original size as specified in the file
    - After fix: rendered size should match AutoCAD's display
  - Inspect and document DXF file structure:
    - Extract and log header variables ($DIMSCALE, $LTSCALE, $MEASUREMENT, $INSUNITS)
    - Parse and log STYLE table entries with scale factors (code 40)
    - Identify Archicad origin markers or patterns in header comments
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found:
    - Specific text heights from DXF vs rendered sizes
    - Header variable values that may indicate scaling factors
    - Text style scale factors that are being ignored
    - Measurement system differences
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Archicad Text Rendering Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-buggy inputs:
    - Pure AutoCAD DXF files (no Archicad origin)
    - DXF files from other CAD software (BricsCAD, LibreCAD, DraftSight)
    - Non-text entities in Archicad-originated files (lines, arcs, circles, polylines, dimensions, hatches, blocks)
  - Document observed behavior:
    - Text sizes for pure AutoCAD files (baseline measurements)
    - Text sizes for other CAD software files
    - Rendering output for non-text entities
    - Text attributes: alignment, rotation, positioning, color
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements:
    - Property: For all pure AutoCAD DXF files, text renders at correct size (entity.height * fitScale)
    - Property: For all non-Archicad files, text rendering matches baseline measurements
    - Property: For all non-text entities, rendering output is unchanged
    - Property: For all text entities, alignment/rotation/color rendering is unchanged
    - Property: Text rendering works correctly for edge cases (very small/large heights, special characters, missing styles)
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 3. Fix for Archicad-AutoCAD text scaling

  - [x] 3.1 Parse text style definitions from STYLE table
    - Modify `lib/src/features/dxf_viewer/parser/dxf_parser.dart`
    - Create `DxfTextStyle` class in `lib/src/features/dxf_viewer/models/dxf_models.dart`:
      ```dart
      class DxfTextStyle {
        final String name;
        final double heightScale;
        final String fontFile;
        final bool isVertical;
        // constructor and other properties
      }
      ```
    - Add text style parsing logic in `parseString` to extract STYLE table entries
    - Parse text style properties:
      - Style name (code 2)
      - Height scale factor (code 40)
      - Font file (code 3)
      - Vertical flag (code 70)
    - Store parsed styles in `Map<String, DxfTextStyle>` in DxfDocument
    - Add `textStyles` field to DxfDocument model
    - _Bug_Condition: Files with isBugCondition(input) where input originates from Archicad and was edited in AutoCAD_
    - _Expected_Behavior: Text styles parsed correctly with scale factors available for rendering_
    - _Preservation: Non-Archicad files may not have STYLE table - handle gracefully with defaults_
    - _Requirements: 1.1, 1.2, 2.1, 2.2_

  - [x] 3.2 Enhance header variable extraction
    - Modify `lib/src/features/dxf_viewer/parser/dxf_parser.dart`
    - Ensure header variables are extracted and stored: $DIMSCALE, $LTSCALE, $MEASUREMENT, $INSUNITS
    - Verify headerVars map contains these values after parsing
    - Add helper methods to DxfDocument in `lib/src/features/dxf_viewer/models/dxf_models.dart`:
      ```dart
      double getDimensionScale() {
        return headerVars['$DIMSCALE'] ?? 1.0;
      }
      double getLineTypeScale() {
        return headerVars['$LTSCALE'] ?? 1.0;
      }
      int getMeasurementSystem() {
        return headerVars['$MEASUREMENT'] ?? 1;  // 0=Imperial, 1=Metric
      }
      ```
    - _Bug_Condition: Archicad files may store scaling factors in header variables_
    - _Expected_Behavior: All relevant header variables accessible for scaling calculations_
    - _Preservation: Existing header parsing continues to work for all file types_
    - _Requirements: 1.1, 1.2, 2.1, 2.2_

  - [x] 3.3 Implement Archicad origin detection heuristic
    - Add method to DxfDocument in `lib/src/features/dxf_viewer/models/dxf_models.dart`:
      ```dart
      bool get isArchicadOrigin {
        // Check for Archicad markers in header comments or variables
        // Check for text styles with 2.0 scale factors
        // Check for specific header variable patterns
        // Return true if Archicad origin detected
      }
      ```
    - Detection heuristics to implement:
      1. Check DXF comments (code 999) for "Archicad" mentions
      2. Check if text styles contain 2.0 scale factors (common Archicad pattern)
      3. Check header variables like $ACADVER for Archicad-specific values
      4. Check text style naming conventions (if patterns exist)
    - Use conservative detection - prefer false negatives over false positives to protect preservation requirements
    - _Bug_Condition: Need to identify when isBugCondition applies (Archicad origin)_
    - _Expected_Behavior: Accurate detection of Archicad-originated files_
    - _Preservation: Pure AutoCAD and other CAD files must NOT be misidentified as Archicad_
    - _Requirements: 1.1, 2.1, 3.1, 3.3_

  - [x] 3.4 Create effective text height calculation helper
    - Add helper function to DxfPainter in `lib/src/features/dxf_viewer/rendering/dxf_painter.dart`:
      ```dart
      double _getEffectiveTextHeight(
        double entityHeight,
        String? styleName,
        DxfDocument document
      ) {
        double effectiveHeight = entityHeight;
        
        // Apply text style scale factor if style exists
        if (styleName != null && document.textStyles.containsKey(styleName)) {
          final style = document.textStyles[styleName]!;
          effectiveHeight *= style.heightScale;
        }
        
        // Apply additional scaling for Archicad-originated files
        if (document.isArchicadOrigin) {
          // Apply correction factor based on header variables or fixed 2.0x
          // This is the core fix for the bug condition
          effectiveHeight *= 2.0;  // or use header-based calculation
        }
        
        return effectiveHeight;
      }
      ```
    - Function should:
      1. Look up text style by name from document.textStyles
      2. Apply text style scale factor if present
      3. Check if document.isArchicadOrigin is true
      4. Apply Archicad correction factor (likely 2.0x based on 50% bug)
      5. Consider header variable scaling (DIMSCALE, LTSCALE) if applicable
      6. Return corrected height value
    - _Bug_Condition: Calculates correct height when isBugCondition(input) is true_
    - _Expected_Behavior: Returns height that makes text display at 100% original size_
    - _Preservation: Returns unchanged height (entity.height) for non-Archicad files_
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1_

  - [x] 3.5 Apply corrected text height in TEXT rendering
    - Modify `_renderText` method in `lib/src/features/dxf_viewer/rendering/dxf_painter.dart`
    - Update text height calculation:
      ```dart
      // OLD: final fontSize = math.max(entity.height * fitScale, 0.1);
      // NEW:
      final effectiveHeight = _getEffectiveTextHeight(
        entity.height,
        entity.style,  // may need to add style field to DxfText
        _document
      );
      final fontSize = math.max(effectiveHeight * fitScale, 0.1);
      ```
    - Ensure DxfText entity has style reference field (may need to add during parsing)
    - Pass DxfDocument to _renderText method (update method signature and call sites)
    - Preserve all existing logic for:
      - Text alignment (horizontal and vertical)
      - Text rotation
      - Text positioning
      - Text color and formatting
    - _Bug_Condition: TEXT entities from Archicad files now use corrected height_
    - _Expected_Behavior: TEXT renders at 100% size for Archicad files_
    - _Preservation: TEXT rendering unchanged for non-Archicad files_
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2_

  - [x] 3.6 Apply corrected text height in MTEXT rendering
    - Modify `_renderMText` method in `lib/src/features/dxf_viewer/rendering/dxf_painter.dart`
    - Update text height calculation:
      ```dart
      // OLD: final fontSize = math.max(entity.height * fitScale, 0.5);
      // NEW:
      final effectiveHeight = _getEffectiveTextHeight(
        entity.height,
        entity.style,  // may need to add style field to DxfMText
        _document
      );
      final fontSize = math.max(effectiveHeight * fitScale, 0.5);
      ```
    - Ensure DxfMText entity has style reference field (may need to add during parsing)
    - Pass DxfDocument to _renderMText method (update method signature and call sites)
    - Preserve all existing logic for:
      - Multi-line text layout
      - Text alignment and rotation
      - Text positioning
      - Text color and formatting
    - _Bug_Condition: MTEXT entities from Archicad files now use corrected height_
    - _Expected_Behavior: MTEXT renders at 100% size for Archicad files_
    - _Preservation: MTEXT rendering unchanged for non-Archicad files_
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2_

  - [x] 3.7 Update TEXT/MTEXT entity parsing to capture style references
    - Modify text entity parsing in `lib/src/features/dxf_viewer/parser/dxf_parser.dart`
    - Ensure DxfText captures code 7 (text style name) during parsing
    - Ensure DxfMText captures code 7 (text style name) during parsing
    - Add style field to DxfText class in `dxf_models.dart`:
      ```dart
      class DxfText {
        // existing fields...
        final String? style;  // Add this field
      }
      ```
    - Add style field to DxfMText class in `dxf_models.dart`:
      ```dart
      class DxfMText {
        // existing fields...
        final String? style;  // Add this field
      }
      ```
    - _Bug_Condition: Style references needed to look up scale factors_
    - _Expected_Behavior: All text entities have style references available_
    - _Preservation: Existing parsing continues to work, style is optional field_
    - _Requirements: 2.1, 2.2_

  - [x] 3.8 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Archicad-AutoCAD Text Displays at Correct Size
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - Verify text from Archicad→AutoCAD files now displays at 100% size
    - Verify rendered sizes match AutoCAD's display
    - Compare before/after measurements
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - Document validation results:
      - Text heights now correct for all Archicad-originated test cases
      - Scaling correction applied successfully
      - Visual output matches AutoCAD
    - _Requirements: 2.1, 2.2_

  - [x] 3.9 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Archicad Text Rendering Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - Verify pure AutoCAD files still render text correctly
    - Verify other CAD software files still render text correctly
    - Verify non-text entities render identically
    - Verify text attributes (alignment, rotation, color) unchanged
    - Verify edge cases (very small/large heights, special characters) work correctly
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all preservation tests still pass after fix
    - Document preservation validation:
      - No changes to pure AutoCAD text rendering
      - No changes to other CAD software text rendering
      - No changes to non-text entity rendering
      - No changes to text attributes or formatting
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run complete test suite
  - Verify bug condition test passes (Archicad text at correct size)
  - Verify all preservation tests pass (no regressions)
  - Test with multiple Archicad→AutoCAD DXF files
  - Test with multiple pure AutoCAD DXF files
  - Test with files from other CAD software
  - Visual inspection: Compare rendered output in Koto_Viewer with AutoCAD for same files
  - Performance check: Ensure rendering performance not degraded
  - Ask user to validate with real-world Archicad→AutoCAD files if available
  - Document any questions or edge cases that need user clarification
