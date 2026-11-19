# ArchitectRoofGeometry reference map

| Method or tag | Responsibility |
| --- | --- |
| `generateAutoRoof` | Generates roof planes from supporting walls or slabs. |
| `decomposeMultiPitchPolygon` | Computes grouped pitched planes from an eaves polygon. |
| `wallBearingLine` | Locates a roof plane's wall bearing in plan. |
| `buildSectionSlices` | Computes roof intervals along the section line and emits layered material and timber profiles. |
| `[TAG:ROOF_FRAMING_SECTIONS]` | Slices `ArchitectRoofFraming` solids also used by `[TAG:ROOF_DIAGONAL_TIMBER]` in `architect_3d_builder.dart`. The ridge profile owns shared material at a cut through the end of the ridge. |
| `roofUndersideZAt` | Queries the resolved roof underside in world coordinates. |

`ArchitectBuildingSection` uses structural weights and timber hatches for the new diagonal member. See `architect_building_section.index.md` for plotting and publication references.
