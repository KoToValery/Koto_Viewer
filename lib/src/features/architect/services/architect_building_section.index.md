# Architect Building Section — LLM Semantic Navigation Map
> **Path**: `lib/src/features/architect/services/architect_building_section.dart`  
> **Total Lines**: ~2,637 | **Primary Class**: `ArchitectBuildingSection`  
> **Companion Document**: Used by LLMs to locate section generation, boolean clipping, and junction logic in 1 step.

---

## 1. Master Section Registry & Line Spans

| Section ID | Tag | Approx Lines | Description & Primary Responsibilities |
| :--- | :--- | :--- | :--- |
| `[SEC-00-IMPORTS]` | `[TAG:IMPORTS]` | L1 – L33 | Core models, mesh boolean, geometry, and rendering imports |
| `[SEC-01-REGIONS]` | `[TAG:SECTION_REGION]` | L34 – L185 | `ArchitectSectionRegion` data class and bounding geometry |
| `[SEC-02-ROOF_MAT]` | `[TAG:ROOF_MATERIAL]` | L186 – L340 | Roof member materials to `SlabMaterial` mappings |
| `[SEC-03-BUILD_MAIN]` | `[TAG:SECTION_BUILD]` | L341 – L1320 | Main `ArchitectBuildingSection.build(...)` method |
| ↳ `[SUB-03A]` | `[TAG:ROOF_SLICING]` | L370 – L434 | Roof slicing and envelope extraction |
| ↳ `[SUB-03B]` | `[TAG:SLAB_JUNCTIONS]` | L435 – L510 | Cut wall analysis & symbiotic slab/foundation junctions |
| ↳ `[SUB-03C]` | `[TAG:OPENING_SLICING]` | L530 – L780 | Cut window and door apertures, sills, and sub-assembly profiles |
| ↳ `[SUB-03D]` | `[TAG:SPANDREL_INFILL]` | L809 – L952 | Continuous drop beams, RC lintels (щурцове $h=14\text{ cm}$), and aerated concrete infill |
| ↳ `[SUB-03E]` | `[TAG:TIE_BEAMS]` | L953 – L1010 | Automatic intermediate RC tie beams (бетонни пояси) on tall masonry walls |
| ↳ `[SUB-03F]` | `[TAG:COMPOSITIONS]` | L1011 – L1200 | Layered wall solids and multi-material section slicing |
| ↳ `[SUB-03G]` | `[TAG:BEAMS_COLUMNS]` | L1201 – L1300 | Columns, drop beams, and stairs slicing |
| `[SEC-04-ELEVATION]` | `[TAG:ELEVATION_PROJECT]` | L1321 – L1970 | Elevation line projection, hidden line removal, openings |
| `[SEC-05-OPENINGS]` | `[TAG:FIND_OPENINGS]` | L1971 – L2390 | `_findCutOpeningsOnWall`, frame section profiles, glass panes |
| `[SEC-06-DATA]` | `[TAG:DATA_CLASSES]` | L2391 – L2637 | `_CutOpeningSpan`, helper point & segment data structures |

---

## 2. Key Features & Structural Schemes

- **Flat Slab (`flatSlab`)**:
  - Openings in masonry walls automatically receive **RC Lintels (`SlabMaterial.concrete`, $h=14\text{ cm}$)** directly above the window/door head, and **Aerated Concrete (`SlabMaterial.aeratedConcrete`)** spandrel infill up to the slab underside with the dedicated `aeratedConcrete` hatch.
- **Beam & Slab (`beamAndSlab`)**:
  - Exterior walls receive continuous perimeter RC drop beams (`SlabMaterial.concrete`) under the upper slab spanning wall piers and openings.
  - Windows receive RC lintels ($h=14\text{ cm}$) and aerated concrete infill in any gap between lintel top and beam soffit.
- **Timber Joist Floor (`roundLogs` & `studFrame`)**:
  - Intermediate floors automatically resolve to timber joist floors (`SlabMaterial.timber` core, acoustic wool, OSB subfloor, ceiling lining) instead of 20 cm RC slabs.
- **Sandwich Panels (`sandwichPanels`)**:
  - Industrial walls on ground slabs receive elevated RC plinth curbs ($+35\text{ cm}$ above grade), horizontal DPC waterproofing, and starter profile flashing with exterior drip edge.
- **Intermediate RC Tie Beams (Бетонни пояси)**:
  - Masonry walls (`brick` or `aeratedConcrete`) exceeding $3.00\text{ m}$ clear height automatically receive $0.20\text{ m}$ reinforced concrete tie beams at every $3.00\text{ m}$ elevation step per Eurocode 6 & 8, after which the masonry wall continues upward.
