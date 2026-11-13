# Architectural objects

Object placement follows the existing service/column placement review pattern.
`_placingComponent` owns furniture and service previews only in explicit drawing
mode, without selection, Drag or a geometry command. A tap or precision hold
sets the pose; the nearby confirm control creates one undoable object. Cancel
and a repeated Object tool tap discard the pose and return to navigation.
The generic `_selectDraftingElement` shortcut and selection/context hold timers
cannot steal this placement gesture. Context editing never displays a placement
ghost or the placement parameter bar.

The compact palette keeps Object as a real toggle and exposes Library as a
separate control. Catalog search, category/source menus and preview controls use
the active theme. The default preview is a plan; elevation and 3D use distinct
mesh projections. Built-in objects expose dimensions before placement. All new
labels and help are in the Bulgarian and English ARB catalogs.

Selected object body movement follows `_tryStartElementDrag`, the same preview
and pointer-release commit used by selected walls, including manual single
selection. `MoveArchitectElement` now translates components and respects their
lock; both direct movement and the existing two-point Drag use this command.
Duplication now copies components through `ArchitectElementTool`, preserving
their parameters, rotation and metadata. Existing `ArchitectRotation` handles
object rotation. Unsupported object reflection is not offered as a command.
The two-point Drag controls avoid selected component bounds, keeping the
base-point pick clear of the Cancel button.

`ArchitectComponentPlacement` chooses the nearest actual wall face within a
screen-sized magnetic tolerance, using the wall's reference offset and local
normal. Disabling the magnet preserves the freely chosen position/rotation.
The previous fixed half-metre, first-wall-in-list attachment has been removed.
Service extrusion uses a finer contour tolerance so small round pipes retain
their declared diameter. Drain basin heights now match their catalog heights.

Replace is available in the radial context menu and selection actions. The
catalog initially shows the selected object's category. Replacement preserves
the ID, insertion position, rotation, elevation, custom name, visibility and
document/layer associations, and uses the replacement's catalog parameters.
Cancel changes nothing; a stale document rejects the result. Replacement is
one commit through the normal history/autosave path and does not arm placement.

Service component geometry now carries explicit `openingPaths`. The shared
opening painter clips a sparse cross to each real void, excluding casings,
dividers and the pipes inside a combined shaft. Plans, catalog previews and
the vector publication recorder share the same marks. Geometry scaling also
scales those clips; the 3D solids are unaffected by the annotation.

Regression coverage: `architect_object_workflow_test.dart`, plus the existing
component library, service, tool-toggle and Drag tests. Visual review images
can be generated with `OBJECT_REVIEW_IMAGES=1` in `build/object_review/`.

## Verification

- 47 focused object/service/library mobile tests pass, including 14 new object
  workflow tests. The final object/service run passes all 37 tests.
- The broader 194-test run passes 190 tests. Four selection-context tests for
  doors, windows, slabs and roofs also fail in the separate unchanged HEAD
  snapshot; their behavior is outside this object change.
- Targeted Dart analysis reports no errors or warnings. Its redundant-import
  information was removed. This SDK treats information as nonfatal by default
  and does not accept `--no-fatal-infos`.
- Bulgarian/English phone placement and library screenshots, the component
  studio and the service opening-symbol sheet were rendered and reviewed.
