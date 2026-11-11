# Wall & Axis Detector — Reference & Navigation Map
> **Path**: `lib/src/features/structural_designer/analysis/wall_axis_detector.dart`
> **Primary class**: `WallAxisDetector`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method names with `rg -n`.

## 1. How to use this map

1. Use this map to locate the detection stage or helper you need.
2. Search the current Dart source, for example: `rg -n "_autoDetectScale|_findParallelPairs|_bridgeOpenings" lib/src/features/structural_designer/analysis/wall_axis_detector.dart`.
3. Follow the project's geometric-first detection principle (avoid hardcoded layer/word filters as primary identification).

## 2. Key detection methods

| Stage | Concrete symbols | Responsibility |
| --- | --- | --- |
| Public API & grid conversion | `WallAxisDetector`, `detect`, `convertToStructuralGridAxes`, `applyToDocument`, `extractGridAxesFromDocument` | Detection entrypoint and grid axis extraction/application |
| Scale & layer filtering | `_autoDetectScale`, `_getUnitNameFromScale`, `_isClutterOrBorderLayer`, `_isInsulationOrCladdingGroup`, `_isSheetBorder` | Automatic unit/scale detection and border/clutter filtering |
| Segment extraction | `_extractSegments`, `_extractSegmentsFromEntity`, `_extractSegmentsFromInsert`, `_resolveLineweight` | Extracting geometric segments from DXF entities and nested inserts |
| Parallel pairs & merging | `_mergeCollinearSegments`, `_bucketByAngle`, `_findParallelPairs` | Collinear segment merging and parallel wall pair matching |
| Opening bridges & corners | `_bridgeOpenings`, `_snapCornersAndJunctions`, `computeClosureSegmentsForPairs`, `_collectWallContourWithEndCaps` | Bridging door/window gaps and snapping L/T corners |
