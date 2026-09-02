# Archicad-AutoCAD Text Size Fix Bugfix Design

## Overview

This document formalizes the bug fix for text scaling issues in DWG/DXF files that originate from Archicad and are subsequently edited in AutoCAD. The bug manifests as text displaying at approximately 50% of its intended size in Koto_Viewer, while the same files render correctly in AutoCAD. The fix requires identifying and applying the correct scaling factor based on file metadata or text attributes to ensure proper text rendering, while preserving all existing functionality for files from other CAD software sources.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when a DWG/DXF file originates from Archicad, is edited in AutoCAD, and is then opened in Koto_Viewer
- **Property (P)**: The desired behavior - text should display at 100% of its original size as specified in the file and as displayed in AutoCAD
- **Preservation**: Existing text rendering for direct AutoCAD files, non-text entities, and other CAD software sources that must remain unchanged
- **DxfText**: Single-line text entity class in `lib/src/features/dxf_viewer/models/dxf_models.dart` with a `height` property representing text height in drawing units
- **DxfMText**: Multi-line text entity class in `lib/src/features/dxf_viewer/models/dxf_models.dart` with a `height` property for character height
- **DxfParser**: Parser class in `lib/src/features/dxf_viewer/parser/dxf_parser.dart` that reads DXF code pairs and constructs entity objects
- **_renderText / _renderMText**: Rendering methods in `lib/src/features/dxf_viewer/rendering/dxf_painter.dart` that convert text entities to Flutter canvas drawing commands
- **fitScale**: Scaling factor applied during rendering to convert CAD drawing units to screen pixels
- **headerVars**: Map of DXF header variables (like $MEASUREMENT, $DIMSCALE, $LTSCALE) stored in DxfDocument
- **Text Height (Code 40)**: DXF group code 40 represents text height in drawing units for both TEXT and MTEXT entities

## Bug Details

### Bug Condition

The bug manifests when a user opens a DWG/DXF file in Koto_Viewer that was originally created/exported from Archicad and then edited and saved in AutoCAD. All text (both TEXT and MTEXT entities) displays at approximately 50% of the size it should be, compared to how it appears in AutoCAD.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type DxfDocument
  OUTPUT: boolean
  
  RETURN input.originatedFromArchicad = true
         AND input.editedInAutoCAD = true
         AND hasTextEntities(input)
         AND textDisplaysAtWrongScale(input)
END FUNCTION
```

**Current Implementation Issue:**

The text rendering code applies the text height directly from the DXF file:
- In `_renderText()`: `final fontSize = math.max(entity.height * fitScale, 0.1);`
- In `_renderMText()`: `final fontSize = math.max(entity.height * fitScale, 0.5);`

However, Archicad appears to export text with height values that need a 2x scaling correction factor when the file is subsequently edited in AutoCAD. This could be due to:
1. Different unit interpretations between Archicad and AutoCAD
2. A scaling factor stored in header variables that isn't being applied
3. Text style definitions that include scaling factors not being honored
4. Measurement system differences ($MEASUREMENT header variable)

### Examples

**Example 1: Floor Plan Annotation**
- **File Origin**: Archicad architectural drawing → Edited in AutoCAD → Opened in Koto_Viewer
- **Expected**: Room label "Стая 105" displays at height 3.5mm (as in AutoCAD)
- **Actual**: Text displays at approximately 1.75mm (50% of expected size)
- **DXF Data**: TEXT entity with code 40 (height) = 3.5

**Example 2: Technical Dimension Text**
- **File Origin**: Archicad structural plan → Modified dimensions in AutoCAD → Viewed in Koto_Viewer
- **Expected**: Dimension text "2400" displays at height 2.5mm
- **Actual**: Text displays at approximately 1.25mm (50% of expected size)
- **DXF Data**: MTEXT entity with code 40 (height) = 2.5

**Example 3: Multi-line Text Block**
- **File Origin**: Archicad site plan → Text annotations added in AutoCAD → Opened in Koto_Viewer
- **Expected**: Multi-line MTEXT displays at height 4.0mm per line
- **Actual**: Text displays at approximately 2.0mm per line (50% of expected size)
- **DXF Data**: MTEXT entity with code 40 (height) = 4.0

**Example 4: Direct AutoCAD File (Edge Case - Should NOT be affected)**
- **File Origin**: Created entirely in AutoCAD (no Archicad origin)
- **Expected**: Text displays at correct size (e.g., 3.5mm)
- **Actual**: Text displays correctly at 3.5mm (preservation requirement)
- **DXF Data**: TEXT entity with code 40 (height) = 3.5

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Text rendering for DWG/DXF files created directly in AutoCAD (without Archicad origin) must continue to display at the correct size
- Non-text entities (lines, arcs, circles, polylines, dimensions, hatches, blocks, solids) from Archicad-originated files must continue to render at their correct scale
- Text rendering for files from other CAD software sources (e.g., BricsCAD, DraftSight, LibreCAD) must continue to work correctly
- Text alignment (horizontal and vertical), rotation, positioning, and color rendering must remain unchanged
- Performance characteristics of text rendering should not degrade

**Scope:**
All inputs that do NOT involve the Archicad→AutoCAD workflow should be completely unaffected by this fix. This includes:
- Pure AutoCAD DWG/DXF files (most common case)
- Files from other CAD software
- Non-text entity rendering in all files
- Text styles, fonts, and formatting (beyond height scaling)

## Hypothesized Root Cause

Based on the bug description and code analysis, the most likely issues are:

1. **Missing Scaling Factor from Header Variables**: Archicad may store a text scaling factor in DXF header variables (such as $DIMSCALE, $LTSCALE, or $MEASUREMENT) that should be applied to text height but is currently being ignored. AutoCAD respects these variables when rendering, but Koto_Viewer's parser reads them into `headerVars` but doesn't apply them during text rendering.

2. **Text Style Scale Factor**: The DXF TEXT and MTEXT entities reference text styles (code 7) which may contain a scale factor (code 40 in STYLE table). Archicad-originated files might have text styles with 2.0 scale factors that AutoCAD applies but Koto_Viewer ignores because text style parsing is incomplete.

3. **Measurement System Units**: The $MEASUREMENT header variable indicates Imperial (0) vs Metric (1) units. Archicad might export with one measurement system while storing text heights in another, requiring AutoCAD to apply a conversion factor. Koto_Viewer may not be checking this variable.

4. **Paper Space vs Model Space Scaling**: Archicad might define text heights in paper space units while AutoCAD interprets them in model space, requiring a 2x scaling adjustment. This would affect all text uniformly.

5. **DXF Version Compatibility**: Different DXF format versions (AC1015, AC1018, AC1021, AC1024, AC1027) may interpret text height differently. The file might be exported in one version by Archicad and re-saved in another by AutoCAD, creating a scaling mismatch.

## Correctness Properties

Property 1: Bug Condition - Archicad-AutoCAD Text Displays at Correct Size

_For any_ DWG/DXF file that originates from Archicad and is edited in AutoCAD, when opened in Koto_Viewer, the fixed text rendering code SHALL display all TEXT and MTEXT entities at their correct size (matching AutoCAD's display), applying appropriate scaling factors detected from file metadata.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation - Non-Archicad Text Rendering Unchanged

_For any_ DWG/DXF file that does NOT originate from the Archicad→AutoCAD workflow (pure AutoCAD files, other CAD software, or non-text entities in any file), the fixed code SHALL produce exactly the same text rendering as the original code, preserving correct text sizing for all existing workflows.

**Validates: Requirements 3.1, 3.2, 3.3**

## Fix Implementation

### Changes Required

Assuming our root cause analysis points to header variables or text style scaling factors:

**File**: `lib/src/features/dxf_viewer/parser/dxf_parser.dart`

**Function**: `parseString` and text entity parsing

**Specific Changes**:
1. **Enhance Header Variable Extraction**: Extract and store scaling-related header variables ($DIMSCALE, $LTSCALE, $MEASUREMENT, $INSUNITS) in the DxfDocument for later use during rendering. This is already partially done but needs to be utilized.

2. **Parse Text Style Definitions**: Add parsing for the STYLE table section to extract text style definitions including their scale factors (code 40 in STYLE entries). Store these in a `Map<String, DxfTextStyle>` in DxfDocument.

3. **Detect Archicad Origin**: Implement heuristic detection of Archicad-originated files by checking:
   - DXF comments or application markers in header (code 999, $ACADVER, $DWGCODEPAGE)
   - Specific header variable patterns characteristic of Archicad exports
   - Text style naming conventions
   - Fallback: Check if text styles contain 2.0 scale factors

4. **Calculate Effective Text Height**: Create a helper function `_getEffectiveTextHeight(DxfText/MText entity, DxfDocument document)` that:
   - Looks up the text style referenced by the entity
   - Applies the style's scale factor if present
   - Applies header variable scaling (e.g., $DIMSCALE) if Archicad origin detected
   - Returns the corrected height value

5. **Add Text Style Model**: Create a `DxfTextStyle` class in `dxf_models.dart`:
   ```dart
   class DxfTextStyle {
     final String name;
     final double heightScale;
     final String fontFile;
     final bool isVertical;
     // ... other properties
   }
   ```

**File**: `lib/src/features/dxf_viewer/rendering/dxf_painter.dart`

**Function**: `_renderText` and `_renderMText`

**Specific Changes**:
1. **Apply Corrected Text Height**: Instead of using `entity.height` directly, call the helper function to get the effective height:
   ```dart
   // OLD: final fontSize = math.max(entity.height * fitScale, 0.1);
   // NEW:
   final effectiveHeight = _getEffectiveTextHeight(entity, document);
   final fontSize = math.max(effectiveHeight * fitScale, 0.1);
   ```

2. **Pass Document Context**: The `_renderText` and `_renderMText` methods will need access to the DxfDocument (or at least headerVars and text styles) to look up scaling factors. This may require adding a parameter to these methods and updating call sites.

3. **Preserve Existing Logic**: All alignment, rotation, positioning, and color logic must remain unchanged to satisfy preservation requirements.

**File**: `lib/src/features/dxf_viewer/models/dxf_models.dart`

**Additions**:
1. **Add DxfTextStyle class**: Define the text style model class with all necessary properties.

2. **Update DxfDocument**: Add a `textStyles` field:
   ```dart
   final Map<String, DxfTextStyle> textStyles;
   ```

3. **Add Helper Methods**: Add convenience methods to DxfDocument for scaling factor lookup:
   ```dart
   double getTextScaleFactor() {
     // Check header variables for scaling hints
     // Return appropriate multiplier (e.g., 2.0 for Archicad, 1.0 otherwise)
   }
   
   bool get isArchicadOrigin {
     // Heuristic detection based on header variables or text styles
   }
   ```

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code (exploratory testing), then verify the fix works correctly for Archicad files and preserves existing behavior for all other files.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Create or obtain actual DXF files from the Archicad→AutoCAD workflow and measure the rendered text size in Koto_Viewer. Compare with AutoCAD's rendering. Parse the DXF to inspect header variables and text style definitions. Run these tests on the UNFIXED code to observe failures and understand the root cause.

**Test Cases**:
1. **Basic Archicad→AutoCAD Text**: Parse a DXF with simple TEXT entities from Archicad→AutoCAD workflow, render it, and measure text size (will fail on unfixed code - expect ~50% size)
2. **MTEXT from Archicad**: Parse a DXF with MTEXT entities from Archicad→AutoCAD workflow, verify size is wrong (will fail on unfixed code)
3. **Header Variable Inspection**: Parse Archicad-originated DXF and inspect headerVars map for $DIMSCALE, $LTSCALE, $MEASUREMENT values - check if they differ from pure AutoCAD files
4. **Text Style Inspection**: Parse STYLE table from Archicad DXF and check for scale factors (code 40) - verify if they contain 2.0 or other non-1.0 values
5. **Pure AutoCAD Control**: Parse and render a pure AutoCAD DXF with the same text height values - verify it displays correctly (should pass even on unfixed code)

**Expected Counterexamples**:
- Archicad→AutoCAD text renders at ~50% of expected size while pure AutoCAD text renders correctly
- Possible causes identified through inspection:
  - Text styles contain 2.0 scale factor that isn't being applied
  - Header variables contain scaling hints that are ignored
  - Measurement system mismatch requiring conversion

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds (Archicad→AutoCAD DXF files), the fixed function produces the expected behavior (text at 100% size).

**Pseudocode:**
```
FOR ALL dxfFile WHERE isArchicadToAutoCADFile(dxfFile) DO
  document := DxfParser.parseString_fixed(dxfFile)
  renderedText := renderText_fixed(document.textEntities, document)
  
  FOR EACH textEntity IN document.textEntities DO
    ASSERT textEntity.renderedSize ≈ textEntity.expectedSize (within 5% tolerance)
    ASSERT textEntity.renderedSize ≈ autoCADDisplaySize(textEntity)
  END FOR
END FOR
```

**Testing Approach**: Use real Archicad→AutoCAD DXF files as test fixtures. Measure expected text sizes from AutoCAD screenshots or DXF specifications. After fix, verify text renders at correct size.

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (pure AutoCAD files, other CAD software, non-text entities), the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL dxfFile WHERE NOT isArchicadToAutoCADFile(dxfFile) DO
  document_original := DxfParser.parseString_original(dxfFile)
  document_fixed := DxfParser.parseString_fixed(dxfFile)
  
  ASSERT renderDocument_original(document_original) = renderDocument_fixed(document_fixed)
END FOR

FOR ALL entity WHERE entity.type != TEXT AND entity.type != MTEXT DO
  ASSERT renderEntity_original(entity) = renderEntity_fixed(entity)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Observe behavior on UNFIXED code first for pure AutoCAD files and other CAD software files to establish baseline, then write property-based tests capturing that exact behavior and verify it's preserved after fix.

**Test Cases**:
1. **Pure AutoCAD Text Preservation**: Collect DXF files created entirely in AutoCAD, measure text sizes in unfixed Koto_Viewer, then verify fixed version produces identical results
2. **Other CAD Software Preservation**: Test with DXF files from BricsCAD, LibreCAD, DraftSight - verify text rendering unchanged
3. **Non-Text Entity Preservation**: Verify that lines, arcs, circles, polylines, dimensions, hatches, blocks all render identically before and after fix in Archicad-originated files
4. **Text Attributes Preservation**: Verify alignment, rotation, color, positioning logic unchanged for all text entities
5. **Edge Cases**: Test with unusual text heights (very small: 0.1mm, very large: 1000mm), special characters, empty text, missing text styles

### Unit Tests

- Test header variable extraction from DXF HEADER section ($DIMSCALE, $LTSCALE, $MEASUREMENT)
- Test text style parsing from STYLE table section
- Test Archicad origin detection heuristic with known Archicad and AutoCAD samples
- Test effective text height calculation with various combinations of style scales and header variables
- Test TEXT entity rendering with corrected height values
- Test MTEXT entity rendering with corrected height values
- Test that text from different origins (AutoCAD, Archicad, other) gets appropriate scaling

### Property-Based Tests

- Generate random DxfDocument instances with various header variable combinations and verify scaling logic consistency
- Generate random text entities with different heights and styles, verify rendering produces proportional sizes
- Generate random DXF files from different CAD sources, verify preservation of existing behavior for non-Archicad files
- Test across many combinations of text styles, heights, alignments, and rotations to ensure no regressions

### Integration Tests

- Full end-to-end test: Load Archicad→AutoCAD DXF file, parse it, render it to canvas, verify visual output matches AutoCAD
- Full end-to-end test: Load pure AutoCAD DXF file, verify visual output unchanged from before fix
- Test with real-world architectural drawings containing mixed entity types (text, dimensions, geometry)
- Test file loading → parsing → rendering → display pipeline for both bug and non-bug cases
- Visual regression testing: Compare rendered images before and after fix for preservation cases
