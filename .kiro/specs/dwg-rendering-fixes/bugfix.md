# Bugfix Requirements Document

## Introduction

This document addresses three rendering inconsistencies in Koto Viewer when displaying DWG files (specifically DWG 2018 format files created in ArchiCAD and edited in AutoCAD). The visualization in Koto Viewer does not match the original appearance in AutoCAD/ArchiCAD, affecting linetype patterns, dimension tick colors, and text-to-container proportions in room labels. These issues impact the visual accuracy and professional presentation of CAD drawings.

**Test File:** `C:\Flutter\Koto_Viewer-main\test_files\OVK.dwg`  
**File Origin:** Created in ArchiCAD, edited in AutoCAD, saved as DWG 2018

**Note:** Some of these issues were partially addressed in a previous session but remain incomplete.

---

## Bug Analysis

### Current Behavior (Defect)

**Issue 1: Linetype Scale (Дефект в мащаба на прекъснати линии)**

1.1 WHEN rendering centerlines with dot patterns (осови линии) in DWG files THEN the system displays the patterns at a larger scale than specified in the original file, making the dashes and dots appear coarser than in AutoCAD/ArchiCAD

1.2 WHEN rendering dashed lines (пунктирни линии) in DWG files THEN the system displays the dash patterns at a larger scale than specified in the original file, making them appear coarser than in AutoCAD/ArchiCAD

1.3 WHEN the linetype scale multiplier `(settings.linetypeScale * 1.5)` is applied in the rendering code THEN the resulting visual pattern does not match the AutoCAD/ArchiCAD visualization

**Issue 2: Dimension Tick Color (Дефект в цвета на размерни тикчета)**

1.4 WHEN rendering dimension entities with ticks/arrows (ограничителни чертички на размери) THEN the system displays the ticks in an incorrect color that does not match the color specified in the original DWG file

1.5 WHEN dimension block entities are rendered THEN the color resolution logic does not correctly apply the intended color to dimension tick marks

**Issue 3: Text-to-Container Proportions in Room Labels (Дефект в пропорциите на текст в таблички)**

1.6 WHEN rendering room label tables (таблички с площ и наименование на помещения) containing text THEN the system displays the container frames as too large relative to the text inside them

1.7 WHEN rendering MText entities within room label blocks THEN the text appears very small (drebен) compared to the frame/container, resulting in poor visual proportions

1.8 WHEN MText height scaling is applied (e.g., scaling from 2.5mm paper height to 12.5 model-space height) THEN the resulting text-to-container ratio does not match the AutoCAD/ArchiCAD visualization

---

### Expected Behavior (Correct)

**Issue 1: Linetype Scale**

2.1 WHEN rendering centerlines with dot patterns in DWG files THEN the system SHALL display the patterns at the same visual scale as shown in AutoCAD/ArchiCAD

2.2 WHEN rendering dashed lines in DWG files THEN the system SHALL display the dash patterns at the same visual scale as shown in AutoCAD/ArchiCAD

2.3 WHEN applying linetype scale calculations THEN the system SHALL compute the scale factor such that the resulting pattern matches the original DWG file appearance in AutoCAD/ArchiCAD

**Issue 2: Dimension Tick Color**

2.4 WHEN rendering dimension entities with ticks/arrows THEN the system SHALL display the ticks in the correct color as specified in the original DWG file

2.5 WHEN dimension block entities are rendered THEN the system SHALL correctly resolve and apply the specified color to dimension tick marks according to DWG color resolution rules

**Issue 3: Text-to-Container Proportions in Room Labels**

2.6 WHEN rendering room label tables containing text THEN the system SHALL display the container frames at the correct proportion relative to the text inside them, matching AutoCAD/ArchiCAD visualization

2.7 WHEN rendering MText entities within room label blocks THEN the system SHALL display text at an appropriate size relative to the frame/container

2.8 WHEN applying MText height scaling THEN the system SHALL calculate the scaling factor to maintain proper text-to-container proportions as shown in AutoCAD/ArchiCAD

---

### Unchanged Behavior (Regression Prevention)

**General Rendering Preservation**

3.1 WHEN rendering DWG files with solid lines (continuous linetype) THEN the system SHALL CONTINUE TO display them correctly without pattern scaling issues

3.2 WHEN rendering non-dimension entities (lines, polylines, arcs, circles) THEN the system SHALL CONTINUE TO render them with correct colors and properties

3.3 WHEN rendering text entities that are not inside room label blocks THEN the system SHALL CONTINUE TO display them at the correct size

3.4 WHEN rendering dimension entities that do not have tick marks THEN the system SHALL CONTINUE TO render them correctly

3.5 WHEN user adjusts the linetype scale via the display settings UI slider THEN the system SHALL CONTINUE TO respond to user-specified scale adjustments

3.6 WHEN rendering DWG files that do not contain the specific problematic patterns (centerlines, dashed lines, room labels with specific dimensions) THEN the system SHALL CONTINUE TO render them correctly

3.7 WHEN rendering dimension text that is not MText or has height > 3.5 THEN the system SHALL CONTINUE TO render it without applying the dimension-specific height scaling

3.8 WHEN rendering blocks that are not dimension blocks THEN the system SHALL CONTINUE TO render their entities with correct colors and properties

---

## Bug Condition Analysis

### Bug Condition Functions

**C1(entity) - Linetype Scale Bug Condition:**
```pascal
FUNCTION isLinetypeScaleBug(entity)
  INPUT: entity of type DxfEntity
  OUTPUT: boolean
  
  RETURN (entity.lineType contains dash or dot pattern) AND 
         (visual scale does not match AutoCAD/ArchiCAD)
END FUNCTION
```

**C2(entity) - Dimension Tick Color Bug Condition:**
```pascal
FUNCTION isDimensionTickColorBug(entity)
  INPUT: entity of type DxfDimension or DxfEntity in dimension block
  OUTPUT: boolean
  
  RETURN (entity is dimension tick/arrow) AND 
         (rendered color ≠ specified color in DWG)
END FUNCTION
```

**C3(entity) - Room Label Text Proportion Bug Condition:**
```pascal
FUNCTION isRoomLabelTextProportionBug(entity)
  INPUT: entity of type DxfMText or container block
  OUTPUT: boolean
  
  RETURN (entity is room label with text and frame) AND 
         (text-to-container ratio ≠ AutoCAD/ArchiCAD ratio)
END FUNCTION
```

### Properties (Expected Behavior for Buggy Inputs)

**P1 - Linetype Scale Property:**
```pascal
FOR ALL entity WHERE isLinetypeScaleBug(entity) DO
  result ← renderLinetype'(entity)
  ASSERT visualPatternScale(result) = visualPatternScale(AutoCAD/ArchiCAD)
END FOR
```

**P2 - Dimension Tick Color Property:**
```pascal
FOR ALL entity WHERE isDimensionTickColorBug(entity) DO
  result ← renderDimension'(entity)
  ASSERT tickColor(result) = tickColor(originalDWG)
END FOR
```

**P3 - Room Label Text Proportion Property:**
```pascal
FOR ALL entity WHERE isRoomLabelTextProportionBug(entity) DO
  result ← renderRoomLabel'(entity)
  ASSERT textToContainerRatio(result) ≈ textToContainerRatio(AutoCAD/ArchiCAD)
END FOR
```

### Preservation Goal

```pascal
// Property: Preservation Checking
FOR ALL entity WHERE NOT (isLinetypeScaleBug(entity) OR 
                         isDimensionTickColorBug(entity) OR 
                         isRoomLabelTextProportionBug(entity)) DO
  ASSERT render(entity) = render'(entity)
END FOR
```

This ensures that all other rendering behavior remains unchanged after the fix.
