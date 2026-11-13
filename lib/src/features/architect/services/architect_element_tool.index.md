# Architect Element Tool — Reference & Navigation Map
> **Path**: `lib/src/features/architect/services/architect_element_tool.dart`  
> **Primary class**: `ArchitectElementTool`  
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols, anchors, and behavior in the current source with `rg -n`.

---

## 1. How to use this map

1. Use this map to find the relevant section tag, class, or method name.
2. Search the current Dart source with `rg -n "\[TAG:<NAME>\]|<SymbolName>" lib/src/features/architect/services/architect_element_tool.dart`.
3. For behavior changes, read the target implementation and its immediate callers/callees; follow the Reference-First protocol in `AGENTS.md` / `GEMINI.md`.

---

## 2. Source section registry

| Section ID | Tag | Description & Primary Responsibilities |
| :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:ARCH_TOOL_IMPORTS]` | Package, model, service, and widget imports |
| `[SEC-01-ELEMENTS]` | `[TAG:ELEMENT_TOOL]` | Drafting, picking and element operations |
| `[SEC-02-TRANSFORMS]` | `[TAG:ELEMENT_TRANSFORMS]` | Duplicate, rotate, flip and mirror |
| ↳ `[SUB]` | `[TAG:ELEMENT_MIRROR]` | Model-space reflection and local handedness |
| ↳ `[SUB]` | `[TAG:ELEMENT_MIRROR_BATCH]` | Reflection with group and dimension associations |
| `[SEC-03-HELPERS]` | `[TAG:ELEMENT_HELPERS]` | Deletion, connected chains and distance |

---

## 3. Classes, Enums & Top-Level Declarations

| Symbol | Kind | Members | Signature / Heritage |
| :--- | :--- | :--- | :--- |
| `ArchitectElementTool` | class | 50 | `class ArchitectElementTool extends ChangeNotifier` |

---

## 4. Method & Action Directory

| Method / Handler | Class | Section Tag | Summary / Signature |
| :--- | :--- | :--- | :--- |
| `mirrorElementById` | `ArchitectElementTool` | `[TAG:ELEMENT_MIRROR]` | Reflect coordinates and local curve/side data for one element |
| `mirrorElementsByIds` | `ArchitectElementTool` | `[TAG:ELEMENT_MIRROR_BATCH]` | Reflect a selection; remap dimension hosts and copy groups |
| `duplicateElementById`, `duplicateElementsByIds` | `ArchitectElementTool` | `[TAG:ELEMENT_TRANSFORMS]` | Copy geometry and hosted openings |
| `setWindowParams` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setWindowParams( |
| `setWindowStyle` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setWindowStyle(ArchitectFenestrationStyle style) |
| `setDoorStyle` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setDoorStyle(ArchitectFenestrationStyle style) |
| `setColumnParams` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setColumnParams( |
| `setBeamParams` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setBeamParams( |
| `setStairParams` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setStairParams( |
| `setOpeningType` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setOpeningType(OpeningType type) |
| `setDecorativeParams` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void setDecorativeParams( |
| `nextColumnLabel` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | Calculates the next sequential column label (e.g. C1, C2, C3 or K1, K2...). |
| `addSlabPoint` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | bool addSlabPoint(Offset point) |
| `updateSlabCandidate` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void updateSlabCandidate(Offset? candidate) |
| `cancelSlabDrafting` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | void cancelSlabDrafting() |
| `hitTestElementsForTool` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | Filter before hit testing so overlapping objects of other tools cannot |
| `hitTestForTool` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | String? hitTestForTool( ArchitectStorey storey, Offset point, double scale, |
| `hitTestElement` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | String? hitTestElement( ArchitectStorey storey, Offset point, double scale, |
| `hitTestElements` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | Iterable<String> hitTestElements( ArchitectStorey storey, Offset point, dou |
| `_hitsInnerContour` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | static bool _hitsInnerContour( List<List<Offset>> holes, Offset point, doub |
| `deleteElementById` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | ArchitectStorey deleteElementById(ArchitectStorey storey, String elementId) |
| `rotateElementById` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | ArchitectStorey rotateElementById(ArchitectStorey storey, String elementId) |
| `flipElementById` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | ArchitectStorey flipElementById(ArchitectStorey storey, String elementId) |
| `rotateElementsByIds` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | ArchitectStorey rotateElementsByIds( ArchitectStorey storey, Set<String> el |
| `flipElementsByIds` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | ArchitectStorey flipElementsByIds( ArchitectStorey storey, Set<String> elem |
| `deleteElementsByIds` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | ArchitectStorey deleteElementsByIds( ArchitectStorey storey, Set<String> el |
| `findConnectedWallChain` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | Set<String> findConnectedWallChain( ArchitectStorey storey, String startWal |
| `_pointToSegmentDistance` | `ArchitectElementTool` | `[TAG:ELEMENT_TOOL]` | static double _pointToSegmentDistance(Offset p, Offset a, Offset b) |

---

## 5. Key State Fields & Controllers Registry (25 fields)

- `windowWidth` (`double`)
- `windowHeight` (`double`)
- `windowSill` (`double`)
- `windowHasCasing` (`bool`)
- `activeWindowStyle` (`ArchitectFenestrationStyle?`)
- `activeDoorStyle` (`ArchitectFenestrationStyle?`)
- `columnShape` (`ColumnShape`)
- `columnWidth` (`double`)
- `columnDepth` (`double`)
- `beamWidth` (`double`)
- `beamDepth` (`double`)
- `stairWidth` (`double`)
- `stairSteps` (`int`)
- `stairDesign` (`ArchitectStairDesign`)
- `openingType` (`OpeningType`)
- `decorativeDepth` (`double`)
- `decorativeSpanLength` (`double`)
- `decorativeFrameWidth` (`double`)
- `decorativeNormalOffset` (`double`)
- `decorativeMaterial` (`ArchitectDecorativeMaterial`)
- `activeDecorativePreset` (`ArchitectDecorativeElement?`)
- `slabDraftPoints` (`List<Offset>`)
- `slabCandidatePoint` (`Offset?`)
- `measureStart` (`Offset?`)
- `measureEnd` (`Offset?`)

## 6. Mirror reference pattern

- Interaction: `ArchitectWorkspaceScreen._startMirrorSession`, `_previewMirrorSnap`, `_pickMirrorSnap`, and `_executeMirror` use `ArchitectTransformPointInput` and the floating placement HUD. Preview and commit both call `MirrorArchitectElements`.
- Mutation: `MirrorArchitectElements.apply` calls `mirrorElementsByIds`, which delegates to `mirrorElementById`. Model coordinates are reflected with `BimTransform2D.mirror`; CAD curves and dimension references use `ArchitectMirrorGeometry`.
- Local geometry: bulges, ellipse sweeps, wall reference sides/tilt, door swing, stair handedness, roof slope arrows, and decorative basis vectors must reflect with their control points. Polygon reversal also remaps edge bulges.
- Associations: `ArchitectMirrorGeometry.dimensionReferences` rebinds copied witnesses to copied hosts, remaps polygon vertices/edges, reverses wall-face sides, and detaches a reflected dimension from untransformed hosts. `ArchitectDimensionChain.resolve` then uses the existing transaction preparation path.
- History and persistence: the existing `ArchitectCommandController` transaction and workspace save path remain in use. `ArchitectStair`, `ArchitectCadPrimitive`, `ArchitectWall`, and decorative model JSON already store the transformed fields.
- Regression coverage: `architect_mirror_geometry_regression_test.dart` checks sampled curves, physical surfaces, handedness, dimensions, serialization, and undo/redo. `architect_mirror_elements_test.dart` checks snapping, preview, cancellation, and commit.

## Ellipse reference pattern

`hitTestElements` uses `ArchitectEllipseGeometry.bounds` and `distanceTo` for
rotated full and partial ellipses. The helper preserves the persisted
`startPoint` centre contract and the previous renderer's missing-radius defaults.
Placement validation belongs to `PlaceArchitectCadPrimitive`; the workspace
owns three-point drafting and the explicit painter preview.
