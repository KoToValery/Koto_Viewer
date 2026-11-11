# Architect Building Section — Reference & Navigation Map
> **Path**: `lib/src/features/architect/services/architect_building_section.dart`
> **Primary class**: `ArchitectBuildingSection`
> **Important**: Treat this map as a discovery aid, not a specification. Verify concrete symbols and behavior in the current source with `rg -n`.

## 1. How to use this map

1. Use this map to locate section slicing, elevation projection, or constructive junction logic.
2. Search the current Dart source, for example: `rg -n "\[TAG:SPANDREL_INFILL\]|_findCutOpeningsOnWall|ArchitectBuildingSection" lib/src/features/architect/services/architect_building_section.dart`.
3. Inspect the actual implementation in `ArchitectBuildingSection.build` and related roof/slab/wall helpers before modifying section geometry or hatching rules.

## 2. Source section registry

| Source anchor / topic | Responsibility |
| --- | --- |
| `ArchitectSectionRegion` | Section cut region bounds and orientation data |
| `ArchitectBuildingSection` | Main section and elevation builder (`build(...)`) |
| `[TAG:SPANDREL_INFILL]` | Continuous drop beams, RC lintels, and aerated concrete infill |
| `[TAG:TIE_BEAMS]` | Intermediate RC tie beams on tall masonry walls |
| `_findCutOpeningsOnWall` | Cut window/door aperture detection and frame section profiles |

## 3. Structural scheme behaviors to verify in source

- **Flat slab**: Masonry openings receive RC lintels and aerated concrete spandrel infill up to the slab underside.
- **Beam & slab**: Exterior walls receive continuous perimeter drop beams under the upper slab plus lintels/infill where needed.
- **Timber joist floors** (round-log / stud-frame schemes): Intermediate floors resolve to timber joist assemblies instead of RC slabs.
- **Sandwich panels**: Industrial walls on ground slabs receive elevated RC plinth curbs, horizontal DPC, and starter profile flashing.
- **Intermediate RC tie beams**: Tall masonry walls receive intermediate concrete tie beams per Eurocode height steps (`[TAG:TIE_BEAMS]`).
