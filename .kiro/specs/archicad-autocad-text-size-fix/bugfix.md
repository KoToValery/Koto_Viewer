# Bugfix Requirements Document

## Introduction

This document addresses a text scaling bug in Koto_Viewer's DWG/DXF conversion functionality. When converting files that originate from Archicad and are subsequently edited in AutoCAD, all text appears at approximately 50% of its intended size, making it difficult to read. This issue specifically affects the Archicad → AutoCAD workflow, while direct AutoCAD files convert correctly.

The bug impacts user readability and document fidelity, requiring users to manually zoom or adjust their viewing to read text that should display at its original size.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN importing a DWG/DXF file that was originally exported from Archicad and then edited/saved in AutoCAD THEN the system displays all text at approximately 50% of the original size

1.2 WHEN rendering text entities from Archicad-originated DWG/DXF files THEN the system applies incorrect scaling that affects all text sizes uniformly

### Expected Behavior (Correct)

2.1 WHEN importing a DWG/DXF file that was originally exported from Archicad and then edited/saved in AutoCAD THEN the system SHALL display text at 100% of its original size as specified in the file

2.2 WHEN rendering text entities from Archicad-originated DWG/DXF files THEN the system SHALL correctly interpret and apply the text height attributes to maintain original text dimensions

### Unchanged Behavior (Regression Prevention)

3.1 WHEN importing DWG/DXF files created directly in AutoCAD (without Archicad origin) THEN the system SHALL CONTINUE TO display text at the correct size

3.2 WHEN rendering non-text entities (lines, shapes, dimensions, blocks) from Archicad-originated files THEN the system SHALL CONTINUE TO display these elements at their correct scale

3.3 WHEN converting files from other CAD software sources THEN the system SHALL CONTINUE TO maintain correct text sizing for those sources
