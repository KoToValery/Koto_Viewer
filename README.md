<div align="center">

# 📐 KoToViewer

### Universal All-in-One Viewer for 2D CAD, 3D BIM, Medical DICOM, PCB & Documents

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-green.svg)](#supported-platforms)
[![Offline First](https://img.shields.io/badge/Privacy-100%25%20Offline-success.svg)](#privacy--security)

**KoToViewer** is a fast, versatile, offline-first universal viewer built with Flutter. It consolidates engineering drawings, 3D parametric models, medical DICOM imaging, electronic PCB stackups, and office documents into a single, unified, lightweight interface.

[Key Features](#key-features) • [Supported Formats](#supported-formats) • [Privacy & Security](#privacy--security) • [Getting Started](#getting-started) • [Licensing](#licensing)

</div>

---

## 🌟 Key Features

### 🩺 1. Medical Imaging (DICOM)
Engineered for medical professionals, researchers, and students to review clinical imaging offline with complete privacy:
- **Full DICOM Support:** Parse `.dcm` and DICOMDIR studies across multiple modalities (CT, MRI, X-Ray, Ultrasound).
- **Multi-Frame & Series Navigation:** Slice scrolling with real-time thumbnail gallery and automated Cine loop playback.
- **Windowing / Leveling:** Interactive Window Center (WC) and Window Width (WW) controls with clinical presets (*Bone, Soft Tissue, Lung, Brain*).
- **Calibrated Measurements:** Real-world distance measuring using embedded DICOM pixel spacing.
- **Compressed Syntax Handling:** Native JPEG 2000 decompression powered by high-performance **OpenJPEG** integration.
- **Header & Tag Inspector:** Comprehensive metadata exploration (Patient, Study, Series, Photometric Interpretation, Transfer Syntax).

---

### 🧊 2. 3D CAD & BIM Modeling
Hardware-accelerated 3D inspection for mechanical parts, architecture, and 3D printing:
- **Formats:** STEP (`.stp`, `.step`), IGES (`.igs`, `.iges`), IFC (BIM), STL (ASCII & Binary), OBJ (+ MTL), GLTF / GLB, FBX, 3MF.
- **Camera Navigation:** Smooth orbital rotation, pan, zoom, and auto-fit bounding box centering.
- **BIM Inspector (IFC):** Hierarchical building element tree (Storeys, Walls, Slabs, Windows, Structural elements).
- **Render Modes & Themes:** Smooth Shaded, Flat, Wireframe, Hidden-Line, Dark CAD, Blueprint, and Light Studio.

---

### 📐 3. 2D CAD & Engineering Drawings
High-precision 2D CAD drawing inspection engine:
- **Formats:** AutoCAD DXF (R12 through 2018+), DWG (via integrated **GNU LibreDWG** engine), HPGL / PLT, SVG.
- **Layer Management:** Full layer visibility toggles, color overrides, frozen layer recognition, and layer state persistence.
- **Snap & Measurement:** Accurate vertex, midpoint, and center snapping; linear distance, angle, and area calculations.
- **Coordinate Systems:** Built-in geodesic coordinate conversion (BGS 2005, WGS 84, UTM).

---

### ⚡ 4. Electronics & PCB Manufacturing
Dedicated electronics visualizer for hardware engineers and makers:
- **Formats:** Gerber RS-274X, Excellon Drill files (`.drl`, `.txt`), and compressed ZIP archives from EDA suites (*KiCad, Altium, Eagle, EasyEDA*).
- **Composite Board Stackup:** Automatic layer classification (Top/Bottom Copper, Solder Mask, Silkscreen, Drill holes, Board Outline).
- **Interactive Layer Opacity:** Inspect individual traces, solder pads, and vias with customizable layer stacking.

---

### 🗺️ 5. Geospatial & Outdoor Navigation
- **Formats:** GPX, KML, GeoJSON.
- **Interactive Maps:** Route inspection, elevation profiles, waypoint markers, integrated compass, and live GPS tracking.

---

### 📄 6. Office, Text & Vector Graphics
- **Office Documents:** Hardware-accelerated PDF (zoom, text search, print), Word (`.docx`), Excel spreadsheets (`.xlsx`), PowerPoint slides (`.pptx`).
- **Vector Graphics:** Adobe EPS, CorelDRAW (`.cdr`), SVG.
- **Developer & Text Tools:** Source code viewer with syntax highlighting, Markdown (`.md`), Jupyter Notebooks (`.ipynb`), CSV tables.
- **Images & OCR:** Image inspection with on-device text recognition (OCR) via Google ML Kit.

---

## 📁 Supported Formats

| Category | File Extensions | Capabilities |
| :--- | :--- | :--- |
| **Medical** | `.dcm`, `.dicom` | Series navigation, Window/Level, Cine loop, Calibrated ruler, Metadata |
| **3D CAD / BIM** | `.stp`, `.step`, `.igs`, `.iges`, `.ifc`, `.stl`, `.obj`, `.gltf`, `.glb`, `.fbx`, `.3mf` | Orbital 3D camera, Shading modes, BIM element hierarchy |
| **2D CAD** | `.dwg`, `.dxf`, `.plt`, `.hpgl`, `.svg` | Layer management, Snap-to-geometry, Area/Distance, BGS2005/WGS84 |
| **PCB / EDA** | `.gbr`, `.gerber`, `.drl`, `.txt`, `.zip` | Multi-layer composite stackup, Copper/Mask toggles, Drill holes |
| **Geospatial** | `.gpx`, `.kml`, `.geojson` | Map overlay, Elevation profile, Compass, GPS tracking |
| **Documents** | `.pdf`, `.docx`, `.xlsx`, `.pptx`, `.csv` | High-res rendering, spreadsheet grid, slide preview, print |
| **Graphics** | `.cdr`, `.eps`, `.svg`, `.png`, `.jpg`, `.webp`, `.tiff`, `.lottie` | Vector rasterization, zoom, OCR text recognition |
| **Dev & Text** | `.txt`, `.md`, `.json`, `.xml`, `.ipynb`, `.dart`, `.py`, `.cpp`, `.ttf`, `.otf` | Syntax highlighting, Markdown preview, Font preview |

---

## 🔒 Privacy & Security

KoToViewer is engineered with an **offline-first** philosophy:
- **Zero Cloud Uploads:** Files opened in KoToViewer are parsed and rendered 100% locally on your device.
- **Data Privacy:** Sensitive patient health information (HIPAA/GDPR) in DICOM files and confidential proprietary CAD/PCB blueprints never leave your machine.
- **No Analytics / Telemetry:** No tracking, no external ad SDKs, and no telemetry services.

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.8 or newer)
- Desktop / Mobile development toolchains:
  - **Windows:** Visual Studio 2022 (with C++ Desktop workload)
  - **Android:** Android Studio / Android NDK & CMake

### Clone & Run

```bash
# Clone the repository
git clone https://github.com/KoToValery/Koto_Viewer.git
cd Koto_Viewer

# Install Flutter dependencies
flutter pub get

# Run on your target platform
flutter run -d windows
# or
flutter run -d android
```

### Native Dependencies
- **Windows:** The bundled `dwg2dxf.exe` and `libredwg-0.dll` binaries are placed under `windows/libredwg/bin/` and installed automatically during CMake build.
- **Android:** Native shared libraries for LibreDWG and OpenJPEG (`libredwg.so`, `libopenjp2.so`) are located in `android/app/src/main/jniLibs/` and packaged automatically into the APK.

---

## ⚖️ Licensing & Open Source

This project is licensed under the **[GNU General Public License v3.0 (GPLv3)](LICENSE)**.

### Third-Party & Open Source Acknowledgments
- **[GNU LibreDWG](https://www.gnu.org/software/libredwg/):** GNU General Public License v3.0 (GPLv3). Powers DWG conversion.
- **[OpenJPEG](https://github.com/uclouvain/openjpeg):** 2-Clause BSD License. Powers JPEG 2000 DICOM image decompression.
- **[Flutter](https://flutter.dev):** BSD 3-Clause License.

---

<div align="center">

Made with ❤️ by Valery & the KoToViewer Contributors

</div>
