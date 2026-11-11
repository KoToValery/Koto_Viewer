# Initial Scheme Generator — Reference & Navigation Map
> **Path**: `lib/src/features/structural_designer/analysis/initial_scheme_generator.dart`
> **Primary class**: `InitialSchemeGenerator`
> **Important**: Header TOC tags in this file are topic summaries while the body uses `// === SECTION: ... ===` comments inside `_generateLayout`. Treat this map as a discovery aid and search concrete symbols or section titles with `rg -n`.

## 1. How to use this map

1. Use this map to find the synthesis stage or model class you need.
2. Search the current Dart source, for example: `rg -n "_generateLayout|SHEAR WALL PLACEMENT|COLUMN LAYOUT" lib/src/features/structural_designer/analysis/initial_scheme_generator.dart`.
3. Inspect the target section inside `InitialSchemeGenerator` and its callers before altering column/wall/beam synthesis rules.

## 2. Key classes, sections & synthesis stages

| Section / symbol | Responsibility |
| --- | --- |
| `InitialSchemeOptions`, `InitialSchemeProposal`, `_WallRun` (`[SEC-01-OPTIONS]`) | Configuration options, proposal output, and wall run structures |
| `InitialSchemeGenerator.generate`, `_continueLowerStorey`, `_generateInMetres`, `_generateLayout` | Public entrypoint, lower-storey continuation, metric normalization, layout synthesis |
| `// === SECTION: STAIRCASE, SHAFTS & CORE BOUNDARY WALLS ===` | Staircase, shaft, and core boundary shear wall generation |
| `// === SECTION: SHEAR WALL PLACEMENT & SEISMIC PAIRING ===` | Shear wall placement and X/Y seismic pairing |
| `// === SECTION: COLUMN LAYOUT & SPAN OPTIMIZATION ===` | Column grid placement and span optimization |
| `// === SECTION: BEAMS & FINAL SCHEME VALIDATION ===` | Perimeter/tie beams and final structural validation |
