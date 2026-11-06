# Architectural Layout rendering diagnostic

Run from the repository root:

```powershell
flutter --suppress-analytics test --no-pub --concurrency=1 tool/benchmarks/architect_sheet_render_benchmark.dart
```

The fixture in `test/fixtures/architect_layout_two_views_2026_11_05.json` is the
architectural JSON supplied in the user's project ZIP. It contains 20 walls,
three stairs, and two placements of the same plan at 1:100 and 1:200. Four and
eight placements repeat those views, with additional drawings staged beside
the paper.

These are **host CPU diagnostics in Flutter tests**, not Android `FrameTiming`
measurements, raster performance, or a confirmation of the Redmi's 60 Hz target.
No physical phone was connected for this run. The actual device still needs a
profile-mode run measuring UI and raster frame p95 separately.

## Display-list replay

The baseline reconstructs the previous replay path: every vector operation is
visited and every text operation gets a fresh `TextPainter.layout`. The retained
path replays a native vector `ui.Picture`. Both record into a fresh native
picture each sample; there is no rasterized image. Three warmups precede 24
samples. The generated `build/architect_layout_benchmark/render.json` contains
the complete result.

An isolated Windows run on 2026-11-05 produced:

| Placements | Vector operations | Baseline p95, ms | Retained p95, ms | Median improvement |
| --- | ---: | ---: | ---: | ---: |
| 1 | 2,969 | 6.396 | 0.254 | 24.8x |
| 2 | 4,752 | 9.820 | 0.449 | 20.6x |
| 4 | 9,491 | 15.776 | 1.161 | 16.1x |
| 8 | 18,969 | 36.723 | 2.652 | 14.0x |

`coldSceneAndPictureMs` measures preparation in test order. Source-scene and
physical geometry caches remain warm between counts, so those values are not
independent cold-start comparisons.

## Actual viewport actions

The second diagnostic uses the real `ArchitectSheetViewport`, publisher, sheet
composer, saved anchors, scales, and localized titles. Its camera includes every
staged drawing. The count is increased from n-1 to n to time adding one drawing.
Selection, dragging, zooming, and crop editing receive three warmups followed by
16 samples. Pixel-equivalence and offscreen-culling tests are separate from this
timing harness.

Each number below measures a **whole synthetic action**, including widget
rebuilds and multiple `pump` calls. Selection includes deselecting and selecting.
Dragging includes two live moves and release. Crop includes entering the tool,
dragging a boundary, and leaving the tool. These values must not be compared to
a per-frame 16.7 ms budget. Full median/p95 results are written to
`build/architect_layout_benchmark/viewport.json`.

| Placements | Add one, ms | Select median, ms | Drag median, ms | Zoom median, ms | Crop median, ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 145.954 | 8.525 | 14.631 | 1.304 | 44.601 |
| 2 | 38.862 | 8.681 | 9.565 | 0.969 | 40.698 |
| 4 | 3.678 | 5.277 | 8.227 | 1.143 | 33.311 |
| 8 | 3.866 | 5.035 | 7.197 | 1.026 | 27.632 |

There are respectively **1, 2, 2, and 2 source pictures**. Warm selection,
dragging, zooming, and crop actions create no additional native pictures. Crop
preparation creates one small active-layer picture once. At eight placements,
the recorded-picture cache uses 211,072 bytes in this fixture. The first two add
measurements include preparing a new source scale; the other two reuse it.

Physical plan wall layers and section/elevation geometry are cached independently
of annotation scale on the immutable source-project snapshot. The geometry cache
tests verify identity reuse at 1:100 and 1:200, reuse with annotation visibility
changes, and invalidation after editing a wall. Text, dimensions, hatching, and
source scenes continue to use their scale-dependent publication settings.

## Regression checks

`architect_picture_cache_test.dart` covers measured text, native picture reuse,
inactive LRU eviction, disposal, revision invalidation, source sharing, culling,
and pixel comparison against the composed scene with a rotated anchored drawing,
concave crop, off-sheet geometry, and foreground title block.

The Layout interaction, visibility/duplicate, crop/publication, picture-cache,
geometry-cache, and benchmark batch passed all 35 checks. PDF and DXF retain the
semantic vector scenes; the viewport cache does not alter exported geometry.
