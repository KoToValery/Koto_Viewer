# GLB materials in the shared CAD viewport

The imported `Mesh3D` keeps model-space coordinates and CPU triangles. For normal
GPU shading, meshes containing `MeshMaterial` data are packaged into a temporary,
self-contained GLB and loaded with Thermion/Filament gltfio. This reuses the native
PBR implementation for PNG/JPEG textures, samplers, UV transforms, metallic/roughness,
normal, occlusion and emissive maps, unlit materials, and OPAQUE/MASK/BLEND alpha.

Only the render copy is centered and scaled to the shared viewport's 20-unit
extent. The original geometry, dimensions and drawing data do not change. Raw
linear vertex colors are retained separately from display colors so material
factors are applied once, and alpha masks are evaluated after texturing. Smooth
mode keeps imported vertex normals; flat mode uses geometric face normals.

Camera gestures only update the existing camera. Material assets are replaced on
scene/style changes and destroyed through the same queue as uploads and viewport
teardown. The glTF asset owns its textures, samplers and materials. The existing
procedural path handles architectural meshes without imported materials, custom
color overrides, wireframe and x-ray modes.

The Canvas fallback decodes base-color textures with bounded image resolution,
uses UV transforms and wrap modes, and retains/interpolates attributes when
subdividing large triangles. A textured scene bypasses the older CPU rasterizer,
which has no UV support. This fallback approximates shading and uses alpha
blending; full PBR lighting, normal maps and per-pixel alpha cutoffs belong to the
native GPU path. It is also the fallback on platforms without the native texture
backend. No new product UI strings are introduced.

## Compression

Required Draco/Meshopt compression remains rejected by the CPU importer. The
pinned native engine includes these codecs, but loading only a compressed native
scene would leave the app without decoded triangles for fallback rendering,
feature contours and geometric inspection. A shared geometry decoder is separate
work; adding a native-only display path would not complete BIM library support.
Uncompressed GLB 2.0 is the supported library input for this iteration.

## Verification

`test/cad_3d_material_rendering_test.dart` verifies GPU asset round-tripping,
material/vertex factor separation, mask alpha, PBR bindings, flat/smooth normals,
mixed imported/procedural materials, texture pixels after subdivision, and
viewport texture replacement.

The real Windows plugin test includes a generated textured cube with red, green,
blue and transparent quadrants. It validates captured GPU pixels, CAD edges,
wireframe, x-ray, resizing, reopening and swapchain cleanup:

```powershell
flutter build windows --profile --no-pub --target tool/qa/cad_3d_gpu_smoke.dart --dart-define=CAD_3D_MATERIAL_QA=true
```

Run the resulting executable from the repository root. It exits automatically;
captures and its JSON report are written to `build/cad-3d-qa/`.

The material run completed all five render cycles (12 textured triangles,
1264×681 final capture, 314 distinct colors). Captures and its report are also
preserved under `build/cad-3d-material-qa/`. Viewport teardown left no swapchains.
The separate Windows host exit still reports native status `0xC000041D` after
the render checks succeed; this is not counted as a clean end-to-end process run.
The same exit status reproduces with the ordinary architectural scene without
GLB materials (120 triangles, five successful render cycles), so it is independent
of the imported-material path. The test uses Flutter's native exit API after
draining and destroying the shared test engine; the Windows plugin/host shutdown
still needs a separate fix.

The scoped analyzer is clean. The parser/geometry suite has 47 passing tests and
the material suite has six passing tests, including asynchronous texture loading
and scene replacement. Ten additional viewport tests pass; the existing
`preview plates use each storey footprint and concave zones keep their area`
test still fails because its expected preview plate is absent.
