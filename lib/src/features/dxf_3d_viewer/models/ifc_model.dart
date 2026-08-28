import 'package:flutter/material.dart';
import 'mesh_3d.dart';

/// Single building element inside an IFC BIM model.
class IfcElement {
  final int id;
  final String globalId;
  final String name;
  final String ifcType;
  final String category;
  final String storeyName;
  final String layer;
  final Color color;
  final List<Triangle3D> triangles;
  final BoundingBox3D bounds;
  final Map<String, String> properties;

  IfcElement({
    required this.id,
    required this.globalId,
    required this.name,
    required this.ifcType,
    required this.category,
    required this.storeyName,
    this.layer = '',
    required this.color,
    required this.triangles,
    BoundingBox3D? bounds,
    Map<String, String>? properties,
  })  : bounds = bounds ?? BoundingBox3D.fromPoints(
          triangles.expand((t) => [t.v0, t.v1, t.v2]).toList(),
        ),
        properties = properties ?? const {};
}

/// Building storey level (e.g. Ground Floor, Level 1, Roof).
class IfcStorey {
  final int id;
  final String name;
  final double elevation;
  final List<int> elementIds;

  const IfcStorey({
    required this.id,
    required this.name,
    required this.elevation,
    required this.elementIds,
  });
}

/// Representation of a parsed IFC BIM model with interactive storey, category, and layer filtering.
class IfcModel {
  final String projectName;
  final String schema;
  final List<IfcElement> elements;
  final List<IfcStorey> storeys;
  final Set<String> categories;
  final Set<String> layers;

  final Set<String> hiddenStoreys = {};
  final Set<String> hiddenCategories = {};
  final Set<String> hiddenLayers = {};

  IfcModel({
    required this.projectName,
    required this.schema,
    required this.elements,
    required this.storeys,
    required this.categories,
    Set<String>? layers,
    Set<String>? hiddenLayers,
  }) : layers = layers ?? {} {
    if (hiddenLayers != null) {
      this.hiddenLayers.addAll(hiddenLayers);
    }
  }

  /// Category display colors for BIM UI icons and badges.
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'wall':
        return const Color(0xFFE5E2DC);
      case 'slab':
      case 'floor':
        return const Color(0xFFB8BCC2);
      case 'column':
        return const Color(0xFF7D8B9B);
      case 'beam':
        return const Color(0xFF6C7C8C);
      case 'window':
        return const Color(0xFF38BDF8);
      case 'door':
        return const Color(0xFFA07452);
      case 'roof':
        return const Color(0xFFBA5545);
      case 'stair':
        return const Color(0xFF9E9FA4);
      case 'railing':
        return const Color(0xFF5A626A);
      case 'furniture':
        return const Color(0xFF4E7D96);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  /// Category icon for BIM UI.
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'wall':
        return Icons.crop_square_rounded;
      case 'slab':
      case 'floor':
        return Icons.layers_rounded;
      case 'column':
        return Icons.view_column_rounded;
      case 'beam':
        return Icons.horizontal_rule_rounded;
      case 'window':
        return Icons.window_rounded;
      case 'door':
        return Icons.meeting_room_rounded;
      case 'roof':
        return Icons.roofing_rounded;
      case 'stair':
        return Icons.stairs_rounded;
      case 'railing':
        return Icons.fence_rounded;
      case 'furniture':
        return Icons.chair_rounded;
      default:
        return Icons.domain_rounded;
    }
  }

  /// Converts the visible elements of the IFC model into a renderable 3D Mesh.
  Mesh3D toMesh3D() {
    final List<Triangle3D> visibleTriangles = [];

    for (final element in elements) {
      if (hiddenStoreys.contains(element.storeyName)) continue;
      if (hiddenCategories.contains(element.category)) continue;
      if (element.layer.isNotEmpty && hiddenLayers.contains(element.layer)) continue;

      visibleTriangles.addAll(element.triangles);
    }

    return Mesh3D(
      name: projectName,
      triangles: visibleTriangles,
    );
  }

  int get totalTriangles => elements.fold(0, (sum, el) => sum + el.triangles.length);

  Map<String, int> get categoryCounts {
    final map = <String, int>{};
    for (final c in categories) {
      map[c] = 0;
    }
    for (final el in elements) {
      map[el.category] = (map[el.category] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get storeyCounts {
    final map = <String, int>{};
    for (final s in storeys) {
      map[s.name] = 0;
    }
    for (final el in elements) {
      if (el.storeyName.isNotEmpty) {
        map[el.storeyName] = (map[el.storeyName] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<String, int> get layerCounts {
    final map = <String, int>{};
    for (final l in layers) {
      map[l] = 0;
    }
    for (final el in elements) {
      if (el.layer.isNotEmpty) {
        map[el.layer] = (map[el.layer] ?? 0) + 1;
      }
    }
    return map;
  }

  void toggleStorey(String storeyName, bool isVisible) {
    if (isVisible) {
      hiddenStoreys.remove(storeyName);
    } else {
      hiddenStoreys.add(storeyName);
    }
  }

  void toggleCategory(String category, bool isVisible) {
    if (isVisible) {
      hiddenCategories.remove(category);
    } else {
      hiddenCategories.add(category);
    }
  }

  void toggleLayer(String layerName, bool isVisible) {
    if (isVisible) {
      hiddenLayers.remove(layerName);
    } else {
      hiddenLayers.add(layerName);
    }
  }

  void isolateStorey(String storeyName) {
    hiddenStoreys.clear();
    for (final s in storeys) {
      if (s.name != storeyName) {
        hiddenStoreys.add(s.name);
      }
    }
  }

  void isolateCategory(String category) {
    hiddenCategories.clear();
    for (final c in categories) {
      if (c != category) {
        hiddenCategories.add(c);
      }
    }
  }

  void isolateLayer(String layerName) {
    hiddenLayers.clear();
    for (final l in layers) {
      if (l != layerName) {
        hiddenLayers.add(l);
      }
    }
  }

  void showAll() {
    hiddenStoreys.clear();
    hiddenCategories.clear();
    hiddenLayers.clear();
  }
}
