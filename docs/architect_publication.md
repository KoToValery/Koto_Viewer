# Architectural scales and sheets

The workspace scale selector changes the annotation/publishing scale, independently
of camera zoom. The print preview, sheet canvas and PDF consume the same vector
scene. The normal editing canvas additionally keeps its selection and drafting
helpers. Physical monitor calibration is not part of this implementation.

## Units and typography

Model geometry remains in metres. Project units format user-facing lengths and
areas; imported CAD geometry is converted through `BimCoordinateFrame` before
publishing. Paper dimensions, margins, frames and annotation profiles use mm.
`ArchitectDrawingScale` owns the metre/mm conversion.

Text heights refer to capital-letter height. The bundled Noto Sans regular and
bold fonts have cap height 714/1000 em; the renderer and PDF exporter compensate
for that ratio. Fonts and the OFL license ship in `assets/fonts/`, without a
network dependency. Tiny model-space text is measured at a normalized size to
avoid paragraph-engine rounding collapsing wrapped lines.

Profiles use `scale/role` keys. Individual overrides use
`view/element/role/scale` keys and take precedence over profiles. Missing values
use 1.5 mm through 1:50 and 2.2 mm at larger denominators. Room names default to
1.2 times that height, titles to 1.5 times. Legacy free-text em sizes are migrated
to cap-height overrides at the inherited scale, retaining their visual size.

## Persistence and ownership

`ArchitectProject.document` stores view scales, profiles, overrides, saved
drawings, sheets, placements and reusable title-block templates in the existing
atomic `architectural.json` persistence flow. Document edits use the existing
Undo/Redo controller. Camera/view-scale navigation stays outside editing history.

A placement stores a paper frame and a fixed source anchor in view metres.
Changing scale regenerates annotations, rather than resizing a bitmap. Model
updates never recenter the frame or change the anchor. Missing sources are
marked on the sheet and block export. Double-opening a placement navigates to
its source view.

An optional placement-local crop polygon uses paper mm relative to the frame
origin. Legacy placements without it keep rectangular clipping. Editing the
boundary rebases the frame and compensates the source anchor, including rotated
views, so the drawing does not move as the boundary changes. Scale changes resize
both the frame and its crop around the top-left corner while regenerating paper
annotations. Visibility overrides belong to each placement and inherit unset
values from the saved drawing; editing one placement never edits its siblings.
Saved drawing names remain shared and have a separate Rename action.

Vector operations retain semantic roles, source ID sets and clips. Shared wall,
section and elevation contours retain multiple candidate contributors. This is
publication provenance, not a completed line-edit/reconciliation engine. A later
correction-variant feature must reject ambiguous correspondence instead of
matching the nearest unrelated line.

## Sheets and output

The sheet editor supports A4–A0 and custom sizes, free source placement,
independent scale/rotation/crop, placement visibility, live frame snapping,
margin alignment, locking, duplication and deletion. A full sheet does not block
insertion: overlapping or off-sheet placements may be staged on the editor's
pasteboard and arranged later. Explicit Fit view restores the whole source;
failure preserves the current placement. Frame and source-anchor coordinates
can be edited in Properties. Title-block templates consist of bordered/unbordered cells
(including zero-height/width rules), text and dynamic fields. Long values wrap;
overflow is highlighted in preview and blocks export until the cell is enlarged.

Rectangle and simple polygon crop boundaries share the planar BIM editing
geometry. The editor and PDF consume the same vector clip path, including text
and hatches. Preflight considers actual crop regions and titles separately, so
intersecting bounding rectangles alone do not create false overlap errors.
Draft conflicts remain editable, while unresolved printable-area/title-block
conflicts and missing sources still block final export. Source scene caches
include canonical effective visibility, scale, locale and underlay inputs;
changing only a paper transform or crop reuses the source scene.
During a pointer preview, the static sheet and the active drawing content are
cached separately. Moving translates the content layer; cropping applies the
live boundary to the uncropped layer. Neither gesture records the other views
again. Entering crop mode preserves the camera zoom.

The PDF writer emits paths and embedded text, with independent page sizes for
each selected sheet. Curves are approximated by vector segments up to 0.2 mm
long; collinear segments are consolidated. No screenshot of the model is used.
Printing receives the completed PDF with fixed layout and the selected paper
format. Printer-driver scaling and a physical 100% print still require checking
on the target printer. DXF/plot publication and non-destructive drawing
corrections remain separate follow-up stages.

## Validation

`test/features/architect/architect_publication_test.dart` covers unit conversion,
physical text height, overrides, wrapping, legacy migration, scale-preserving
Undo, plans/sections/elevations, CAD alignment/layers, source deletion, mixed-size
PDF/Cyrillic output and a phone placement workflow. It writes a PDF and screen
render under ignored `build/architect_publication/` for visual comparison with
a PDF renderer.

The sheet geometry, crop publication, interaction and visibility/duplication
tests cover legacy and malformed crops, concave boundaries, source anchors at
arbitrary rotation, custom scales, free insertion on a full sheet, off-sheet
staging, screen-space snapping, multi-pointer cancellation, one-step crop Undo,
instance visibility and cached pointer previews. Mobile publication tests also
exercise the crop controls in both locales/themes with enlarged text. Set
`ARCHITECT_MOBILE_QA=true` with `--dart-define` to write their screen captures.
