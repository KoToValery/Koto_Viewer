# Architectural openings and vertical services — 2026-11-05

The **Services / Инсталации** tool category contains openings and the riser
catalog. Thirteen new parametric definitions use the existing component placement,
rotation, properties, persistence and Undo paths. Built-in display names, category
names, tooltips and cap choices are localized in both supported ARB languages.

## Drawing and geometry

- Opening labels are suppressed for legacy and newly placed openings, including
  vector publication. Neutral outlines and inset diagonal marks replace orange
  lettering. Round penetrations support diameters down to 20 mm, with a matching
  circular preview and a short centre cross. Their persisted boundary contains
  48 vertices and retains the `circular` type.
- Vent blocks have open channels, an actual separating web and optional web
  transition. The compact section has 200 × 170 and 90 × 170 mm clear channels.
  Transition passages are coordination geometry, not a manufacturer's production
  drawing of their internal baffles.
- The combined 500 × 250 mm riser contains a hollow Ø110 drain, Ø50 pipe, two
  insulated Ø32 water pipes, a 25 mm enclosure and an inspection-cover symbol.
  This enclosure is a project layout, not a claimed single manufacturer's product.
- Sewer, water, dry-riser and sleeve definitions have actual bores, not solid
  cylinders. Nominal pipe sizes and enclosure dimensions can be edited.
- The chimney uses a 360 × 360 mm body, Ø180 clear ceramic liner, insulation and
  outer casing. Caps are separate geometry: open, flat, pitched and conical.
  All hood variants have a ventilated opening and supports. XYZ in the editor
  describes the body; caps and roof flashing project beyond it.
- Automatic chimney height uses the highest intersected roof surface over the
  entire chimney footprint, across storeys, plus an editable extension (default
  800 mm). Fixed height is also available. This is a geometry setting, not an
  automatic determination of the chimney's required design height.
- Derived slab holes follow visible services through their actual vertical
  extent. They are shared by slab meshes, plan contours and section intervals.
  Moving, hiding or deleting a service updates holes without mutating slabs.
- Roof envelopes are cut around intersecting services. Chimneys have a separately
  editable roof clearance (default 50 mm) and an apron following the roof slope.
  These inputs describe geometry; project-specific clearances remain a design
  decision. Services are retained in clean 3D/facade meshes and sections.
- Services remain visible when the furniture layer is switched off.

## Continuous services and fireplace

Ventilation stacks, the combined plumbing shaft, sewer stack, separate Ø110 roof
vent and chimney now default to one continuous system through all occupied levels.
`allStoreys` selects the lowest occupied floor as the bottom datum; switching it
off starts the system at its placement floor. `autoHeight` follows the highest
intersected roof, with an adjustable extension. Without a roof the system reaches
above the highest occupied floor. Fixed height remains available.

Plans derive the symbol on each intersected level from a single persisted source.
Roof lines also show penetrations of roof planes assigned to other storeys.
Moving, hiding or deleting the source updates every plan, slab and roof opening;
Undo and JSON round trips retain the relationship. Edit the source on its placement
level. The projections create no additional stored components or duplicate 3D solids.

Ventilation heads have raised, open-sided caps. Sewer and vent pipes retain their
open bores above the roof. Roof intersections share the same openings, weather
aprons and upstands in plan, 3D and sections. Water pipes within the combined
shaft terminate below the roof; only the drainage/ventilation continues upward.

The fireplace has a 550 × 600 × 2640 mm coordination envelope, combustion chamber,
recessed glazed door, thin metal frame, grate and Ø180 smoke passage. Its envelope
is based on [compact Schiedel KINGFIRE modules](https://www.schiedel.com/de/produkte/oefen/integriertes-system/kingfire-lineare-sc),
with height references from the [manufacturer's catalog](https://www.schiedel.com/downloads/de-AT/Preislisten/SA%20PL%20Neubau%202026%20scr.pdf).
The procedural interior is coordination geometry, not a manufacturer-certified
replica. Above the placement floor, only the 360 × 360 mm insulated chimney continues
to the roof. A slab intersecting the taller fireplace enclosure receives the larger
body opening; higher slabs receive the smaller chimney opening. Shared fireplace/
chimney contact faces are removed. The chimney cap uses the same four variants.

[Continuous plans, section and fireplace](images/architect_services_continuity_2026_11_05.png)

## Catalog references

Dimensions were checked against publicly available catalogs on 2026-11-05.
Envelopes and nominal sizes are used as references; the procedural models do not
claim to be manufacturer-certified BIM objects or complete installation designs.

| Model | Reference dimensions | Source |
| --- | --- | --- |
| Concrete vent block, single | 300 × 250 × 200 mm per course | [CAMINO manufacturer catalog](https://davitekbetonstroy.com/серия-камино-camino/) |
| Concrete vent block, double | 500 × 300 × 200 mm per course | [CAMINO manufacturer catalog](https://davitekbetonstroy.com/серия-камино-camino/) |
| Concrete transition pair | Two 500 × 300 × 200 mm courses | [Reliks Vibro manufacturer catalog, ventilation bodies](https://www.reliks-vibro.com/Katalog_2018.pdf) |
| Compact vent / transition | LS 1: 220 × 355 × 330 mm; 200 × 170 and 90 × 170 mm channels | [Schiedel LS catalog, 2026](https://www.schiedel.com/downloads/bg-BG/ценови%20листи/ценова-листа-вентилационни-системи-лс-2026.pdf) |
| Drain pipes | DN/OD 110 and 50 | [Ostendorf product data](https://www.ostendorf-kunststoffe.com/en/downloads/product-data/) |
| Dry riser pipe | DN100, outside diameter 114.3 mm | [Viking product data, nominal pipe dimensions](https://www.vikinggroupinc.com/media/3545) |
| Chimney body and flue | ABSOLUT 18: 360 × 360 mm body, Ø180 flue | [Schiedel planning handbook](https://www.schiedel.com/downloads/de-DE/Planungsunterlagen/2022-05-planungshandbuch-absolut.pdf) |

The vent blocks are deliberately separate from the smoke chimney. The
[Gildia Stroy product information](https://tashev-galving.com/files/manual/161%20BDI%20113.pdf)
explicitly excludes using those concrete ventilation blocks as chimney bodies.

## Verification

`test/features/architect/architect_services_test.dart` checks legacy openings
without text, round placement and JSON, every catalog bore, all four cap variants,
upper-storey roof height, derived slab holes through move/delete, component placement
and Undo, section geometry and narrow Bulgarian/English property controls.

Set `SERVICE_REVIEW_IMAGES=1` when running that test to generate a plan/cap review
sheet and phone properties images under `build/services_review/`.

Reviewed snapshots: [catalog and cap shapes](images/architect_services_catalog_2026_11_05.png)
and [Bulgarian phone controls](images/architect_services_phone_2026_11_05_bg.png).
The final verification group passed 130 tests, including service continuity,
roof and panel geometry, slab and section junctions, mobile forms, tool categories
and selection. Analysis reported no errors or warnings; existing informational
style notices remain.

The follow-up verification covers all seven continuous system types across basement,
ground, upper floor and roof; roof planes owned by a different level; roof openings
in vector recording; one source/one 3D solid; move, hide, delete, Undo and JSON;
fireplace chamber/flue geometry and enlarged body penetrations; water pipe ends;
both localized phone property forms; and roof badges avoiding openings while retaining
their interactive target. See
`test/features/architect/architect_service_continuity_test.dart` and the expanded
`architect_services_test.dart` for these checks.

The broader regression run also covers existing component geometry, slab assemblies,
roof junctions, section junctions, tool categories and selection scoping. Two
pre-existing assertions need separate attention: floor drains report a 57 mm mesh
for a 60 mm declared height; the drafting-seed wall snapshot expects
`exteriorResolved: false` after the command controller has resolved it to `true`.
