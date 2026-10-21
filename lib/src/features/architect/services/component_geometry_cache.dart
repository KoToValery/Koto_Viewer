// === SECTION: ARCHITECTURAL COMPONENT GEOMETRY CACHE & GLTF CONVERSION ===
// Table of Contents:
// 1. GEOMETRY CACHE KEY (ComponentGeometryKey)
// 2. COMPONENT GEOMETRY CACHE SERVICE (ComponentGeometryCache)
// 3. GLTF COORDINATE CONVERSION HELPER (Z-up to Y-up)

import '../../cad_3d/models/mesh_3d.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';

// ===========================================================================
// 1. GEOMETRY CACHE KEY (ComponentGeometryKey)
// ===========================================================================

/// Immutable cache key that quantizes dimensions to 1 millimetre (1e-3 m).
class ComponentGeometryKey {
  final String definitionId;
  final int quantizedWidthMm;
  final int quantizedDepthMm;
  final int quantizedHeightMm;
  final String customParamsKey;

  ComponentGeometryKey({
    required this.definitionId,
    required double width,
    required double depth,
    required double height,
    Map<String, dynamic> customParams = const {},
  })  : quantizedWidthMm = (width * 1000.0).round(),
        quantizedDepthMm = (depth * 1000.0).round(),
        quantizedHeightMm = (height * 1000.0).round(),
        customParamsKey = _serializeParams(customParams);

  static String _serializeParams(Map<String, dynamic> params) {
    if (params.isEmpty) return '';
    final sortedKeys = params.keys.where((k) => k != 'width' && k != 'depth' && k != 'height').toList()..sort();
    return sortedKeys.map((k) => '$k=${params[k]}').join('&');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComponentGeometryKey &&
          runtimeType == other.runtimeType &&
          definitionId == other.definitionId &&
          quantizedWidthMm == other.quantizedWidthMm &&
          quantizedDepthMm == other.quantizedDepthMm &&
          quantizedHeightMm == other.quantizedHeightMm &&
          customParamsKey == other.customParamsKey;

  @override
  int get hashCode => Object.hash(
        definitionId,
        quantizedWidthMm,
        quantizedDepthMm,
        quantizedHeightMm,
        customParamsKey,
      );

  @override
  String toString() =>
      'ComponentKey($definitionId: ${quantizedWidthMm}x${quantizedDepthMm}x${quantizedHeightMm}mm)';
}

// ===========================================================================
// 2. COMPONENT GEOMETRY CACHE SERVICE (ComponentGeometryCache)
// ===========================================================================

/// Fast in-memory cache for compiled 3D meshes and 2D CAD blocks.
class ComponentGeometryCache {
  static final ComponentGeometryCache instance = ComponentGeometryCache._internal();
  ComponentGeometryCache._internal();

  final Map<ComponentGeometryKey, CachedComponentGeometry> _cache = {};
  static const int _maxCacheSize = 250;

  /// Retrieves or synchronously generates and caches component geometry.
  CachedComponentGeometry getOrCompute(
    ArchitectComponentDefinition definition,
    Map<String, dynamic> parameters,
  ) {
    final w = (parameters['width'] as num?)?.toDouble() ??
        (definition.defaultParameters['width'] as num?)?.toDouble() ??
        0.60;
    final d = (parameters['depth'] as num?)?.toDouble() ??
        (definition.defaultParameters['depth'] as num?)?.toDouble() ??
        0.60;
    final h = (parameters['height'] as num?)?.toDouble() ??
        (definition.defaultParameters['height'] as num?)?.toDouble() ??
        0.80;

    final key = ComponentGeometryKey(
      definitionId: definition.id,
      width: w,
      depth: d,
      height: h,
      customParams: parameters,
    );

    final existing = _cache[key];
    if (existing != null) return existing;

    final computed = definition.generateGeometry(parameters);

    if (_cache.length >= _maxCacheSize) {
      // Evict oldest entries
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = computed;
    return computed;
  }

  /// Convenience lookup from an instance.
  CachedComponentGeometry? getForInstance(
    ArchitectComponentInstance instance,
    ArchitectComponentDefinition definition,
  ) {
    return getOrCompute(definition, instance.parameters);
  }

  /// Clears the memory cache (e.g. after editing definitions or unit change).
  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
}

// ===========================================================================
// 3. GLTF COORDINATE CONVERSION HELPER (Z-up to Y-up)
// ===========================================================================

/// Coordinate system converter for glTF export and Filament engine rendering.
///
/// In Architectural generators:
/// - X: East / Width
/// - Y: North / Depth
/// - Z: Up / Elevation
///
/// In glTF specification:
/// - X_gltf = X
/// - Y_gltf = Z (Up)
/// - Z_gltf = -Y
class ComponentGltfCoordinateConverter {
  /// Converts a Z-up 3D vector to Y-up glTF coordinate system.
  static Vector3 toGltfVector(Vector3 v) {
    return Vector3(v.x, v.z, -v.y);
  }

  /// Converts a complete Z-up [Mesh3D] to a Y-up glTF [Mesh3D].
  static Mesh3D toGltfMesh(Mesh3D meshZUp) {
    final convertedTriangles = <Triangle3D>[];
    for (final t in meshZUp.triangles) {
      convertedTriangles.add(
        Triangle3D(
          v0: toGltfVector(t.v0),
          v1: toGltfVector(t.v1),
          v2: toGltfVector(t.v2),
          normal: toGltfVector(t.normal),
          color: t.color,
          isDoubleSided: t.isDoubleSided,
          material: t.material,
          textureCoordinates: t.textureCoordinates,
          vertexNormals: t.vertexNormals?.map(toGltfVector).toList(),
          vertexColors: t.vertexColors,
          linearVertexColors: t.linearVertexColors,
        ),
      );
    }
    return Mesh3D(
      name: '${meshZUp.name}_gltf',
      triangles: convertedTriangles,
    );
  }
}
