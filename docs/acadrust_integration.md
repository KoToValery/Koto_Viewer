# Direct DWG opening with acadrust

**Original DWG → acadrust objects → in-memory viewer model**

Opening and importing DWG does not produce or consume intermediate DXF/KCAD
files. Recent files and project references retain the original DWG path. DXF
and KCAD remain separately supported formats. Processed BIM working models may
still be persisted by their owning project module after the original DWG has
been read; that is separate from the source-opening path.

## Runtime

`FileOpenerService` passes the original DWG to the viewer. `DxfParser.parseFromFile`
dispatches DWG to `DwgReaderService` before any DXF/KCAD parsing or caching.
`DwgDocumentAdapter` constructs the existing viewer classes from native geometry,
layers, styles, blocks, attributes, dimensions and layouts. The historical names
`DxfDocument` and `DxfViewerScreen` are in-memory classes, not file conversions.
`CadTextDecoder` provides shared native/DXF text cleanup.

- Windows: `koto-acadrust.exe --read <source.dwg>` streams native objects over
  stdout; diagnostics use stderr. Parsing stays in a child process.
- Android: `readDwg` calls `AndroidDwgReaderClient`, which binds to
  `:dwg_converter`. A `ParcelFileDescriptor` pipe carries the object stream;
  Binder carries only the request and a small status reply. The JNI library is
  loaded only in the worker. No intermediate CAD or JSON file is created.
- JNI uses real UTF-16 paths, including supplementary Unicode characters.
  Rust catches panics at the boundary and parses on an 8 MB worker stack.
- Both paths have a two-minute deadline and 256 MB transport limit. Android
  cancellation terminates a hung worker. Unsupported entity families fail
  explicitly rather than displaying a partial drawing.

The versioned internal IPC stream currently uses UTF-8 JSON containing native
objects. It contains neither DXF group codes nor KCAD serialization. Dart
decoding and spatial indexing run in an isolate. There is no conversion fallback
when opening DWG. Missing native support reports a localized drawing-loading
error. `DwgConverterService` remains only for explicit DXF export/share operations
and legacy compatibility tests; its caches do not affect DWG opening.

File-manager VIEW/SEND requests use the existing `MainActivity`/`IntentService`
path, with competing default deep-link route handling disabled following
[Flutter's custom-handler guidance](https://docs.flutter.dev/ui/navigation/deep-linking).

## Build

The native library is pinned to acadrust **0.6.8**. Normal Android builds package
the checked-in JNI libraries in `src/acadrust_converter/prebuilt/android` for
ARM64, ARMv7 and x86_64. **Rust is not required on a second development computer.**
Commit/sync that directory, its checksum manifest, the native sources and Gradle
configuration together. CMake checks binary hashes and normalized source hashes
so missing/stale bundles fail the build instead of silently dropping DWG support.

Rebuilding native code requires Rust targets `aarch64-linux-android`,
`armv7-linux-androideabi`, `x86_64-linux-android`, and the NDK. Windows native
builds need Rust MSVC and Visual Studio C++ tools. This project uses
NDK 28.2/API 24; Gradle 8.14 uses JDK 21. Local toolchains under `build/` do not
change the system PATH or Java installation.

```powershell
./tools/build_acadrust.ps1
./tools/build_acadrust.ps1 -Test
./tools/build_acadrust_android.ps1
./tools/bundle_acadrust_android.ps1
python tools/collect_acadrust_licenses.py --cargo-home <cargo-home>
```

CMake packages the Windows executable; Gradle packages the bundled Android JNI
libraries with dependency notices. Android ELF segments use 16 KB alignment.
Cargo.lock is committed. Native developers can use the Gradle property
`-PkotoRebuildAcadrust=true` to compile from Rust instead of using the bundle;
this explicit mode fails if Cargo is unavailable. Run the bundle script and
commit updated binaries after changing Rust/JNI source.

## Verification

```powershell
flutter test --no-pub --dart-define=RUN_DIRECT_DWG_INTEGRATION=true test/dwg_direct_reader_test.dart
flutter test --no-pub test/dwg_document_adapter_test.dart
./tools/test_acadrust_android.ps1 -Serial emulator-5554
```

Seven real DWGs are opened through the public API. Tests first assert no CAD
intermediates/cache directory appeared, then compare entity counts, layers,
blocks, bounds, texts and attributes against the previous export path as a test
oracle. Missing gitignored local fixtures are skipped. Corrupt inputs must fail
without creating derived files. Adapter tests cover all existing viewer entity
families and layout ownership. Existing DXF tests cover shared text decoding.

ART/JNI test snapshots are stored solely as test artifacts under
`build/acadrust/android-jni-test/device-output`. The application uses memory
pipes. `tool/qa/dwg_direct_smoke.dart` is a dedicated headless Android test entry
point for the complete Flutter → service → JNI → Rust → model path. Product APKs
use `lib/main.dart`; the smoke entry point is never used for distribution.

Android native failures retain the numeric status and bounded UTF-8 diagnostic
in the worker log, the method-channel reply and AppErrorHandler's exception log.
`DWG_READER_UNAVAILABLE` identifies library loading failures;
`DWG_JNI_FAILED` identifies binding/runtime exceptions;
`DWG_DECODE_FAILED` identifies a native read error (including the OS error or
incomplete-read statistics). These failures never start a conversion fallback.
`test/android_dwg_reader_test.dart` checks transport and diagnostic preservation.
The JNI harness accepts `-FixtureDirectory` for local reproduction inputs.
`DWG_PHONE_REPRO=true` on the headless smoke entry tests the two reported local
drawings from the app's private cache, plus a control drawing and a corrupt input.

Native WIPEOUT records retain mask polygons, inverted clip holes and opaque
canvas-background semantics. Drawings with masks retain entity/block order
through spatial queries and compiled rendering; ordinary drawings keep batching.
Explicit KCAD output uses version 6 to preserve the mask flag, while the reader
still accepts versions 1–5. This does not introduce a KCAD intermediate when
opening a source DWG.

## Architectural and BIM DWG export

Architecture's exchange dialog offers DWG drawings and DWG sheets with the same
selection, progress, cancel and save/ZIP behavior as DXF. `ArchitectDwgExport`
reuses publication vectors, including real project units, localized text, layer
styles and native sheet layouts/viewports. The project snapshot is not mutated.
BIM project export offers the current storey with its original underlay coordinates
and structural layers. Standalone structural export also writes the current
storey and effective axes. Structural CAD headers retain their physical units.

`DwgExportService` sends the publication's in-memory CAD stream to acadrust's
`DwgWriter` and returns a real R2018 (`AC1032`) binary. Windows uses stdin/stdout
with `--write-dwg`; Android uses input/output FD pipes in the isolated service.
Binder only carries descriptors, cancellation and bounded diagnostics. Native
encoding validates the complete input and re-reads the binary before publishing
any bytes. Both transports retain size/deadline limits and cancellation.

Architectural export creates no intermediate CAD files. BIM reuses its existing
CAD merger in a job-owned temporary directory, removed after export; an original
DWG underlay can participate in that explicit export. Original DWG **opening**
still uses direct native reading without DXF/KCAD intermediates.

Regenerate and commit all three Android JNI libraries with the source updates
using the build/bundle scripts above. `test/dwg_module_export_test.dart` is an
opt-in real Windows integration test (`RUN_DWG_EXPORT_INTEGRATION=true`).
`test/dwg_export_service_test.dart` covers Android transport/failure/cancel paths;
`tool/qa/dwg_export_smoke.dart` verifies real Android architecture/sheet/BIM
exports and a 22,000-entity exchange larger than Binder's message limit.

## Zoom rendering

`DxfPainter` limits hatch pattern enumeration to the buffered scene viewport,
including block and paper viewport transforms, and batches each line family.
Pattern origins, dash phases, boundary holes and full-drawing exports remain
intact. Native LTYPE gaps/dots are adapted to the same positive-length convention
as the existing DXF parser. No new conversion or drawing mutation is involved.

The Viewer gives hatch patterns a work budget per hatch and per paint. Patterns
that exceed it appear as a light fill following the original boundaries and
holes.

`test/dxf_hatch_viewport_test.dart` checks raster parity and bounded work.
The opt-in Windows benchmark measures file opening, paint recording and offscreen
rasterization separately.

```powershell
flutter test --no-pub --dart-define="DWG_ZOOM_INPUT=<original.dwg>" tool/qa/dwg_zoom_benchmark_test.dart
```

`DWG_ZOOM_OUTPUT=<directory>` optionally saves the rendered zoom levels as PNGs.
Use `DWG_ZOOM_COMPARE_HATCHES=true` to compare detailed and interactive hatch
rendering in separate cases within the same process. Each case reopens the file
and writes any requested PNGs to its own subdirectory. Use
`DWG_ZOOM_INTERACTIVE_HATCHES=true` to run only the interactive case or
`DWG_ZOOM_REPEATS` to set the number of samples per zoom (2–12, default 4).
