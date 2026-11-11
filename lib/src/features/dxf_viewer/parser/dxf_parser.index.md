# DXF Parser — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_viewer/parser/dxf_parser.dart`
> **Primary class**: `DxfParser`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method names with `rg -n`.

## 1. How to use this map

1. Use this map to locate the DXF section parser or entity decoder you need.
2. Search the current Dart source, for example: `rg -n "_parseEntity|_parseHatchBoundaryPaths|_stripMTextFormattingCodes" lib/src/features/dxf_viewer/parser/dxf_parser.dart`.
3. Inspect `_parseEntity` and the matching `DxfEntity` model in `dxf_models.dart` before changing group-code parsing.

## 2. Key parser classes & methods

| Stage | Concrete symbols | Responsibility |
| --- | --- | --- |
| Entry & tokenization | `DxfParser`, `_DxfPair`, `parseFromFile`, `parseString`, `_parseFilePathCompute`, `_parsePairs` | File/string parsing and group-code pair decoding |
| Header & tables | `_parseHeaderSection`, `_parseTablesSection`, `_parseDimStyleTable`, `_parseLtypeTable`, `_parseLayerTable`, `_parseStyleTable` | Header extents/units (`$EXTMIN`, `$EXTMAX`, `$INSUNITS`) and CAD tables |
| Blocks & entities | `_parseBlocksSection`, `_parseEntitiesSection`, `_parseEntity` | Block definitions and per-entity group-code dispatch |
| Text & hatches | `_stripMTextFormattingCodes`, `_parseHatchBoundaryPaths`, `_parseHatchPatternLines` | MTEXT formatting cleanup and hatch boundary/pattern parsing |
