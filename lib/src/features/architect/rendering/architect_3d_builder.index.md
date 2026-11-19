# Architect3dBuilder reference map

| Method or tag | Responsibility |
| --- | --- |
| `buildProjectMeshAsync` | Prepares specialized wall solids before scene assembly. |
| `buildProjectMesh` | Builds preview or projection geometry and maps triangles to source elements. |
| `joinedRoofs` | Runs the ordinary projection roof shell pass for trimmed volumes and grouped slopes with shared edges. |
| `[TAG:ROOF_DIAGONAL_TIMBER]` | Builds hip and valley beams through `ArchitectRoofFraming`, splits triangle ownership between adjoining slopes and omits internal seam faces. |
| `buildRoofBody` | Builds closed per-roof bodies for BIM exchange using the same framing layout. |
| `_buildRoofMesh` | Builds roof layers and timber, including the rafter solids from the shared layout. |
| `_appendLandscape3D` | Adds terrain and vegetation to the scene. |

`[TAG:ROOF_FRAMING_SECTIONS]` in `architect_roof_geometry.dart` uses the same beam and rafter solids for section cuts.
