# DXF Parser — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_viewer/parser/dxf_parser.dart`
> **Primary class**: `DxfParser`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete method names with `rg -n`.

## 1. How to use this map

1. Use this map to locate the DXF section parser or entity decoder you need.
2. Search the current Dart source, for example: `rg -n "_parseEntity|_parseHatchBoundaryPaths|_cleanMText" lib/src/features/dxf_viewer/parser/dxf_parser.dart`; shared text formatting lives in `CadTextDecoder`.
3. Inspect `_parseEntity` and the matching `DxfEntity` model in `dxf_models.dart` before changing group-code parsing.

## 2. Key parser classes & methods

| Stage | Concrete symbols | Responsibility |
| --- | --- | --- |
| Entry & tokenization | `DxfParser`, `_DxfPair`, `parseFromFile`, `parseString`, `_parseFilePathCompute`, `_parsePairs` | DWG dispatches to `DwgReaderService` before DXF/KCAD parsing or caching; DXF retains group-code decoding |
| Header & tables | `_parseHeaderSection`, `_parseTablesSection`, `_parseDimStyleTable`, `_parseLtypeTable`, `_parseLayerTable`, `_parseStyleTable` | Header extents/units (`$EXTMIN`, `$EXTMAX`, `$INSUNITS`) and CAD tables |
| Blocks & entities | `_parseBlocksSection`, `_parseEntitiesSection`, `_parseEntity` | Block definitions and per-entity group-code dispatch |
| Text & hatches | `_cleanCadText`, `_cleanMText`, `_parseHatchBoundaryPaths`, `_parseHatchPatternLines` | Shared `CadTextDecoder` text cleanup and DXF hatch parsing |

`[TAG:SOURCE_LAYER_STATES]` is used by
`ArchitectUnderlayService` through `parseString(preserveSourceLayers: true)`
to retain the source layer table and avoid the viewer's empty-visibility recovery.

## Direct DWG path

`[TAG:DWG_DIRECT_READ]` routes original DWGs through `DwgReaderService` and
`DwgDocumentAdapter`. Native objects arrive through stdout (Windows) or a
service pipe (Android); this path uses no intermediate DXF/KCAD files. The
existing `DxfDocument`/entity classes are reused as in-memory viewer models.
