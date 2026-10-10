import 'dart:ui';
import '../../structural_designer/models/structural_element.dart';
import 'architect_wall.dart';
import 'architect_zone.dart';

/// Supported distance units for architectural project dimensions.
enum ArchitectUnit {
  meters(1.0, 'm'),
  centimeters(0.01, 'cm'),
  millimeters(0.001, 'mm');

  final double scaleToMeters;
  final String symbol;
  const ArchitectUnit(this.scaleToMeters, this.symbol);
}

/// Represents an architectural storey level with its height, elevation, walls, and zones.
class ArchitectStorey {
  final String id;
  final String name;
  final double elevation; // in meters (кота готов под)
  final double height; // clear floor-to-floor height in meters
  final double floorFinishThickness; // default 0.05 m
  final List<ArchitectWall> walls;
  final List<ArchitectZone> zones;

  const ArchitectStorey({
    required this.id,
    required this.name,
    this.elevation = 0.0,
    this.height = 2.80,
    this.floorFinishThickness = 0.05,
    this.walls = const [],
    this.zones = const [],
  });

  String get elevationLabel {
    if (elevation.abs() < 1e-4) return '±0.00';
    final sign = elevation > 0 ? '+' : '';
    return '$sign${elevation.toStringAsFixed(2)}';
  }

  ArchitectStorey copyWith({
    String? id,
    String? name,
    double? elevation,
    double? height,
    double? floorFinishThickness,
    List<ArchitectWall>? walls,
    List<ArchitectZone>? zones,
  }) =>
      ArchitectStorey(
        id: id ?? this.id,
        name: name ?? this.name,
        elevation: elevation ?? this.elevation,
        height: height ?? this.height,
        floorFinishThickness: floorFinishThickness ?? this.floorFinishThickness,
        walls: walls ?? this.walls,
        zones: zones ?? this.zones,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'elevation': elevation,
        'height': height,
        'floorFinishThickness': floorFinishThickness,
        'walls': walls.map((w) => w.toJson()).toList(),
        'zones': zones.map((z) => z.toJson()).toList(),
      };

  factory ArchitectStorey.fromJson(Map<String, dynamic> json) =>
      ArchitectStorey(
        id: json['id'] as String,
        name: json['name'] as String,
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        height: (json['height'] as num?)?.toDouble() ?? 2.80,
        floorFinishThickness:
            (json['floorFinishThickness'] as num?)?.toDouble() ?? 0.05,
        walls: (json['walls'] as List<dynamic>?)
                ?.map((w) => ArchitectWall.fromJson(w as Map<String, dynamic>))
                .toList() ??
            const [],
        zones: (json['zones'] as List<dynamic>?)
                ?.map((z) => ArchitectZone.fromJson(z as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// The root model for an architectural concept project.
class ArchitectProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ArchitectUnit units;
  final List<ArchitectStorey> storeys;
  final String activeStoreyId;
  final List<StructuralGridAxis> gridAxes;

  const ArchitectProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.units = ArchitectUnit.meters,
    required this.storeys,
    required this.activeStoreyId,
    this.gridAxes = const [],
  });

  ArchitectStorey get activeStorey =>
      storeys.firstWhere((s) => s.id == activeStoreyId,
          orElse: () => storeys.isNotEmpty ? storeys.first : _emptyStorey);

  static const _emptyStorey = ArchitectStorey(
    id: 'default',
    name: 'Партер ±0.00',
    elevation: 0.0,
  );

  ArchitectProject updateActiveStorey(ArchitectStorey updated) {
    final updatedStoreys = storeys
        .map((s) => s.id == updated.id ? updated : s)
        .toList();
    return copyWith(storeys: updatedStoreys, updatedAt: DateTime.now());
  }

  ArchitectProject copyWithGridAxes(List<StructuralGridAxis> newAxes) {
    return copyWith(gridAxes: newAxes, updatedAt: DateTime.now());
  }

  ArchitectProject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    ArchitectUnit? units,
    List<ArchitectStorey>? storeys,
    String? activeStoreyId,
    List<StructuralGridAxis>? gridAxes,
  }) =>
      ArchitectProject(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        units: units ?? this.units,
        storeys: storeys ?? this.storeys,
        activeStoreyId: activeStoreyId ?? this.activeStoreyId,
        gridAxes: gridAxes ?? this.gridAxes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'units': units.name,
        'storeys': storeys.map((s) => s.toJson()).toList(),
        'activeStoreyId': activeStoreyId,
        'gridAxes': gridAxes.map((a) => a.toJson()).toList(),
      };

  factory ArchitectProject.fromJson(Map<String, dynamic> json) =>
      ArchitectProject(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        units: ArchitectUnit.values.firstWhere(
          (u) => u.name == json['units'],
          orElse: () => ArchitectUnit.meters,
        ),
        storeys: (json['storeys'] as List<dynamic>?)
                ?.map((s) => ArchitectStorey.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        activeStoreyId: json['activeStoreyId'] as String? ?? '',
        gridAxes: (json['gridAxes'] as List<dynamic>?)
                ?.map((a) =>
                    StructuralGridAxis.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// Factory creating a quick starter template project.
  factory ArchitectProject.starter({
    required String name,
    int storeyCount = 2,
    double typicalHeight = 2.80,
    double groundHeight = 3.00,
    int axesX = 4,
    int axesY = 3,
    double spacingX = 4.0,
    double spacingY = 5.0,
  }) {
    final now = DateTime.now();
    final storeys = <ArchitectStorey>[];
    double currentElevation = 0.0;

    for (int i = 0; i < storeyCount; i++) {
      final h = i == 0 ? groundHeight : typicalHeight;
      final name = i == 0
          ? 'Партер ±0.00'
          : 'Етаж $i (+${currentElevation.toStringAsFixed(2)})';
      storeys.add(ArchitectStorey(
        id: 'storey_$i',
        name: name,
        elevation: currentElevation,
        height: h,
      ));
      currentElevation += h;
    }

    final axes = <StructuralGridAxis>[];
    if (axesX > 0 && axesY > 0) {
      final totalWidth = (axesX - 1) * spacingX;
      final totalHeight = (axesY - 1) * spacingY;
      const margin = 1.5;

      for (int i = 0; i < axesX; i++) {
        final x = i * spacingX;
        axes.add(StructuralGridAxis(
          id: 'axis_x_$i',
          name: '${i + 1}',
          start: Offset(x, -margin),
          end: Offset(x, totalHeight + margin),
          bubbleAtStart: true,
          bubbleAtEnd: true,
        ));
      }

      final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
      for (int j = 0; j < axesY; j++) {
        final y = j * spacingY;
        final label = j < letters.length ? letters[j] : 'Y$j';
        axes.add(StructuralGridAxis(
          id: 'axis_y_$j',
          name: label,
          start: Offset(-margin, y),
          end: Offset(totalWidth + margin, y),
          bubbleAtStart: true,
          bubbleAtEnd: true,
        ));
      }
    }

    return ArchitectProject(
      id: 'proj_${now.millisecondsSinceEpoch}',
      name: name,
      createdAt: now,
      updatedAt: now,
      storeys: storeys,
      activeStoreyId: storeys.isNotEmpty ? storeys.first.id : 'default',
      gridAxes: axes,
    );
  }
}
