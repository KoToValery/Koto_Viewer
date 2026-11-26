# DXF Models — Reference & Navigation Map
> **Path**: `lib/src/features/dxf_viewer/models/dxf_models.dart`
> **Primary classes**: `DxfDocument`, `DxfEntity`
> **Important**: Header TOC tags in this file are topic labels. Treat this map as a discovery aid and search concrete class or enum names with `rg -n`.

## 1. How to use this map

1. Use this map to locate the DXF entity, compiled cache, or measurement model you need.
2. Search the current Dart source, for example: `rg -n "class DxfInsert|class DxfDocument" lib/src/features/dxf_viewer/models/dxf_models.dart`.
3. Verify the class definition and fields directly in source before changing serialization, bounds, or painter callers.

## 2. Model & entity directory

`DxfDocument` accepts already-resolved layer lineweights for view-only subsets.
The architectural site visibility tool keeps the source table styles when it
builds filtered model-space documents.

| Category | Concrete classes / enums | Responsibility |
| --- | --- | --- |
| Tables & vertices | `DxfPolylineVertex`, `DxfTextStyle`, `DxfDimStyle`, `DxfLayer` | Vertex bulges, styles, and layer metadata |
| Compiled render caches | `DxfCompiledLine`, `DxfCompiledSubpath`, `DxfCompiledBlock` | Precompiled geometry caches for fast rendering |
| Blocks & entity base | `DxfBlock`, `DxfEntity` | Block definitions and shared entity properties |
| Curves & points | `DxfLine`, `DxfPoint`, `DxfCircle`, `DxfArc`, `DxfEllipse`, `DxfLwPolyline`, `DxfPolyline`, `DxfSpline` | Linear and curved CAD geometry entities |
| Text & annotations | `DxfText`, `DxfMText` | Single-line and multiline CAD text entities |
| Fills & hatches | `DxfSolid`, `DxfHatchPatternLine`, `DxfHatch` | Solid fills and associative hatch boundaries/patterns |
| Attributes & inserts | `DxfAttribute`, `DxfAttdef`, `DxfInsert` | Block references (`INSERT`) and attributes |
| Dimensions & viewports | `DxfDimension`, `DxfLeader`, `DxfMLeader`, `DxfViewport` | Dimensions, leaders, and paper-space viewports |
| Document & measure tools | `DxfDocument`, `DxfUnit`, `DxfMeasureTool`, `DxfAnnotation`, `DxfMeasurement` | Master document model, unit conversion, and measurements |

`DxfHatch.isWipeout` keeps opaque background-mask semantics on polygon geometry
from native DWG. `DxfBlock.orderedCompiled` retains source entity order when masks
are present, including nested inserts and constant attribute templates. Both
compiled caches are cleared by `clearCompiled` before isolate transfer.
Explicit KCAD v6 output and `DxfDocumentTransformer` preserve the mask flag.

`[TAG:DXF_M_SUBPATH_POINTS]` counts the geometry in a `DxfCompiledSubpath` as
the block definition is batched by style. The Viewer uses that count to limit
the memory committed to transformed paths.
