# Planning colors and solid fills

Verified against the primary sources on 2026-10-25.

## References and interpretation

- Bulgaria: [Ordinance No. 8, Annex 2, published by MRRB](https://www.mrrb.bg/static/media/ups/articles/attachments/3d8c97afdd5ed98f9d3d4623e1e90dfa.pdf). Table 1, printed pages 10-17, covers OUP; table 2, printed pages 17-20, covers PUP. Both tables explicitly reference four-digit RAL colors.
- Germany: [PlanZV, Anlage](https://www.gesetze-im-internet.de/planzv_90/anlage.html) supplies the color groups for FNP and B-Plan. It specifies named tones and allows color gradations; it does not assign mandatory RGB or RAL numbers to these groups. [Section 2](https://www.gesetze-im-internet.de/planzv_90/__2.html) also requires linework, density and colors to remain legible against the plan base.
- [RAL's digital-color guidance](https://www.ral-farben.de/en/ral-digital-colour-library) distinguishes digital previews from physical color standards and recommends calibration and physical samples for color decisions.

The bundled RGB swatches are **authored working approximations**. They are not a licensed RAL colorimetric dataset, certified measurements, or official prescribed RGB values. The app preserves each selected palette reference separately from its ARGB preview. For calibrated reproduction, use the custom RGB/HEX controls with values from an appropriate licensed/calibrated workflow; doing so clears the preset reference instead of mislabelling a custom RGB value as a prescribed RAL match.

## Bulgaria: keep OUP and PUP separate

| Use | OUP reference | PUP reference |
| --- | --- | --- |
| Residential functions/zones | RAL 8023, O.2.1 and O.4.1-O.4.4 | RAL 1019 for Zhm/Zhg; RAL 1019+ for Zhs/Zhk, P.2.1-P.2.4 |
| Industrial use | RAL 4005, O.2.3 and O.4.5-O.4.7 | RAL 4008+, P.2.5-P.2.7 |
| Public services | RAL 3000, O.2.2 and O.4.11 | RAL 3012+, P.2.11 and P.3.1 |
| Green space | RAL 6017, O.2.6 and O.4.8 | RAL 6018+, P.2.8 and P.3.5 |
| Water | RAL 5015, O.2.11 | RAL 5015+, P.3.7 |
| Transport land | RAL 7004, O.2.12 | RAL 7004+, P.3.2 |
| Utilities | RAL 7005, O.2.13 | RAL 7005+, P.3.3 |

The OUP palette also includes storage, agricultural and forest colors. PUP additionally includes street hierarchy, pedestrian areas, special-purpose/cultural land and existing/proposed building colors. Every entry carries its table reference in `architect_drawing_color.dart`.

The `+`, `++`, and `-` annotations are tonal variants in the Bulgarian table, **not additional four-digit RAL numbers**. The application does not assert that its white-mixing/darkening previews are a mathematically prescribed conversion.

These are color palettes, not complete regulatory plan symbols. Resort/villa/mixed zones can require combinations of base colors, stripes or colored borders. For example PUP P.2.10 uses RAL 1021 with a RAL 6010 boundary. OUP mixed zones use alternating stripes; PUP mixed zones use a predominant base color and a secondary colored contour. Zone color fills apply to the building component of PRZ/PZ, not indiscriminately to every PUP drawing.

## Germany: PlanZV color groups

| Reference | Use | Specified color family |
| --- | --- | --- |
| 1.1 | Residential, W | Medium red |
| 1.2 | Mixed use, M | Medium brown |
| 1.3 | Commercial/industrial, G | Medium gray |
| 1.4 | Special building use, S | Medium orange |
| 4.1 | Public services | Medium carmine red |
| 5.1 / 6.1 | Roads/transport | Golden ochre |
| 5.2.1 | Railway land | Medium violet |
| 7 | Utilities | Light yellow |
| 9 | Green spaces | Medium green |
| 10.1 | Water | Medium blue |
| 12.1 | Agriculture | Yellow-green |
| 12.2 | Forest | Blue-green |

## Persistence and rendering

- A solid fill is a built-in `solidFill` hatch pattern, retaining the same contour, openings and editing commands as a hatched area.
- `colorValue` stores ARGB. Optional `colorPresetId` preserves the palette/use reference and derives its code from the catalog. Free RGB changes clear an incompatible reference; opacity changes retain it.
- Hatch strokes and solid fills use the selected color directly, independent of dark/light canvas hue adjustments.
- Explicit solid-fill vector operations have the `cadFill` role and preserve their opacity through publication/PDF; the existing automatic lightening for other annotation/model fills is unaffected.
- Fill interiors remain in the model layer below walls and annotations. The selection layer redraws their outline only, avoiding compounded transparency and overlays that obscure geometry.
- The print pipeline retains contour holes and vector paths. It does not automatically construct a legal planning legend, zone designation or complete PUP/OUP/PlanZV symbol from a color choice alone.
