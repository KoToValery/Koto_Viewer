import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';

/// Standard architectural functional room categories.
enum ArchitectZoneCategory {
  living(
    color: Color(0xFFFFA726), // Warm Amber
    icon: Icons.weekend_rounded,
  ),
  bedroom(
    color: Color(0xFF5C6BC0), // Indigo
    icon: Icons.bed_rounded,
  ),
  kitchen(
    color: Color(0xFF26A69A), // Teal / Emerald
    icon: Icons.kitchen_rounded,
  ),
  corridor(
    color: Color(0xFF78909C), // Slate Grey
    icon: Icons.alt_route_rounded,
  ),
  bathroom(
    color: Color(0xFF29B6F6), // Cyan / Sky Blue
    icon: Icons.bathtub_rounded,
  ),
  terrace(
    color: Color(0xFF66BB6A), // Leaf Green
    icon: Icons.deck_rounded,
  ),
  storage(
    color: Color(0xFF8D6E63), // Brown
    icon: Icons.inventory_2_rounded,
  ),
  office(
    color: Color(0xFFAB47BC), // Purple
    icon: Icons.laptop_mac_rounded,
  ),
  custom(
    color: Color(0xFF7E57C2), // Deep Purple
    icon: Icons.dashboard_rounded,
  );

  final Color color;
  final IconData icon;

  const ArchitectZoneCategory({required this.color, required this.icon});

  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case ArchitectZoneCategory.living:
        return l10n.architectZoneCatLiving;
      case ArchitectZoneCategory.bedroom:
        return l10n.architectZoneCatBedroom;
      case ArchitectZoneCategory.kitchen:
        return l10n.architectZoneCatKitchen;
      case ArchitectZoneCategory.corridor:
        return l10n.architectZoneCatCorridor;
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneCatBathroom;
      case ArchitectZoneCategory.terrace:
        return l10n.architectZoneCatTerrace;
      case ArchitectZoneCategory.storage:
        return l10n.architectZoneCatStorage;
      case ArchitectZoneCategory.office:
        return l10n.architectZoneCatOffice;
      case ArchitectZoneCategory.custom:
        return l10n.architectZoneCatCustom;
    }
  }
}

/// A functional architectural zone (room / space / spatial partition)
/// defined by a parametric 2D polygon with dynamic vertices, grips,
/// room finishes (floor, wall, ceiling), and automated schedule metadata.
class ArchitectZone {
  final String id;
  final String
  number; // Room number for schedules/drawings (e.g. "1", "01", "101")
  final String name;
  final ArchitectZoneCategory category;
  final List<Offset> polygon; // Coordinates in model meters
  final String floorFinish; // Floor covering / настилка
  final String wallFinish; // Wall finish / финиш стени
  final String ceilingFinish; // Ceiling finish / финиш таван
  final double clearHeight; // Clear room height in meters (default 2.60 m)
  final bool isAutoBoundary; // Automatic dynamic room boundary vs manual fixed
  final Offset?
  seedPoint; // Internal seed point for dynamic boundary detection & merge
  final double? targetArea; // Optional target program area in m²
  final int? customColorValue;

  const ArchitectZone({
    required this.id,
    this.number = '1',
    required this.name,
    required this.category,
    required this.polygon,
    this.floorFinish = '',
    this.wallFinish = '',
    this.ceilingFinish = '',
    this.clearHeight = 2.60,
    this.isAutoBoundary = true,
    this.seedPoint,
    this.targetArea,
    this.customColorValue,
  });

  Color get color =>
      customColorValue != null ? Color(customColorValue!) : category.color;

  /// Localized default or user-specified floor finish.
  String resolvedFloorFinish(AppLocalizations l10n) {
    if (floorFinish.trim().isNotEmpty) return floorFinish;
    switch (category) {
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneFloorTerracotta;
      case ArchitectZoneCategory.kitchen:
      case ArchitectZoneCategory.corridor:
      case ArchitectZoneCategory.storage:
        return l10n.architectZoneFloorGranite;
      case ArchitectZoneCategory.terrace:
        return l10n.architectZoneFloorGranite;
      case ArchitectZoneCategory.living:
      case ArchitectZoneCategory.bedroom:
      case ArchitectZoneCategory.office:
      case ArchitectZoneCategory.custom:
        return l10n.architectZoneFloorLaminate;
    }
  }

  /// Localized default or user-specified wall finish.
  String resolvedWallFinish(AppLocalizations l10n) {
    if (wallFinish.trim().isNotEmpty) return wallFinish;
    switch (category) {
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneWallFaience;
      case ArchitectZoneCategory.kitchen:
        return '${l10n.architectZoneWallLatex} / ${l10n.architectZoneWallFaience}';
      case ArchitectZoneCategory.living:
      case ArchitectZoneCategory.bedroom:
      case ArchitectZoneCategory.corridor:
      case ArchitectZoneCategory.office:
      case ArchitectZoneCategory.storage:
      case ArchitectZoneCategory.terrace:
      case ArchitectZoneCategory.custom:
        return l10n.architectZoneWallLatex;
    }
  }

  /// Localized default or user-specified ceiling finish.
  String resolvedCeilingFinish(AppLocalizations l10n) {
    if (ceilingFinish.trim().isNotEmpty) return ceilingFinish;
    switch (category) {
      case ArchitectZoneCategory.bathroom:
        return l10n.architectZoneCeilingGypsum;
      default:
        return l10n.architectZoneCeilingLatex;
    }
  }

  /// Standard floor finish presets for architectural schedules.
  static List<String> standardFloorFinishes(AppLocalizations l10n) => [
    l10n.architectZoneFloorLaminate,
    l10n.architectZoneFloorGranite,
    l10n.architectZoneFloorTerracotta,
    l10n.architectZoneFloorParquet,
    l10n.architectZoneFloorCarpet,
    l10n.architectZoneFloorConcrete,
  ];

  /// Standard wall finish presets for architectural schedules.
  static List<String> standardWallFinishes(AppLocalizations l10n) => [
    l10n.architectZoneWallLatex,
    l10n.architectZoneWallFaience,
    l10n.architectZoneWallPlaster,
    l10n.architectZoneWallWallpaper,
    l10n.architectZoneWallExposedBrick,
  ];

  /// Standard ceiling finish presets for architectural schedules.
  static List<String> standardCeilingFinishes(AppLocalizations l10n) => [
    l10n.architectZoneCeilingLatex,
    l10n.architectZoneCeilingGypsum,
    l10n.architectZoneCeilingSuspended,
    l10n.architectZoneCeilingConcrete,
  ];

  /// Calculates net polygon area in square meters using Shoelace formula.
  double get area {
    if (polygon.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      sum += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return sum.abs() / 2.0;
  }

  /// Calculates total boundary perimeter in meters.
  double get perimeter {
    if (polygon.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      sum += (p2 - p1).distance;
    }
    return sum;
  }

  /// Calculates geometric centroid (visual center) for room label badge.
  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    if (polygon.length < 3) {
      double sx = 0, sy = 0;
      for (final p in polygon) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / polygon.length, sy / polygon.length);
    }

    double cx = 0.0;
    double cy = 0.0;
    double signedArea = 0.0;

    for (int i = 0; i < polygon.length; i++) {
      final p0 = polygon[i];
      final p1 = polygon[(i + 1) % polygon.length];
      final a = (p0.dx * p1.dy) - (p1.dx * p0.dy);
      signedArea += a;
      cx += (p0.dx + p1.dx) * a;
      cy += (p0.dy + p1.dy) * a;
    }

    signedArea *= 0.5;
    if (signedArea.abs() < 1e-6) {
      // Degenerate polygon fallback: arithmetic mean
      double sx = 0, sy = 0;
      for (final p in polygon) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / polygon.length, sy / polygon.length);
    }

    return Offset(cx / (6.0 * signedArea), cy / (6.0 * signedArea));
  }

  /// A point inside the contour, unlike the centroid of some concave rooms.
  Offset? get interiorPoint {
    if (seedPoint != null && containsPoint(seedPoint!)) return seedPoint;
    if (containsPoint(centroid)) return centroid;
    // At least one edge has free interior immediately on one side.
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      final delta = b - a;
      if (delta.distance < 1e-8) continue;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance;
      for (final inset in [.05, .01, .001]) {
        for (final sign in [-1.0, 1.0]) {
          final candidate = (a + b) / 2 + normal * (inset * sign);
          if (containsPoint(candidate)) return candidate;
        }
      }
    }
    return null;
  }

  /// Bounding rectangle in meters.
  Rect get bounds {
    if (polygon.isEmpty) return Rect.zero;
    double minX = polygon.first.dx;
    double maxX = polygon.first.dx;
    double minY = polygon.first.dy;
    double maxY = polygon.first.dy;

    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Point-in-polygon ray-casting hit-test.
  bool containsPoint(Offset pt) {
    if (polygon.length < 3) return false;
    if (!bounds.inflate(0.01).contains(pt)) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersect =
          ((pi.dy > pt.dy) != (pj.dy > pt.dy)) &&
          (pt.dx < (pj.dx - pi.dx) * (pt.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // ===========================================================================
  // DYNAMIC SLAB-STYLE POLYGON OPERATIONS
  // ===========================================================================

  /// Moves a single vertex at [index] to [newPos].
  ArchitectZone moveVertex(int index, Offset newPos) {
    if (index < 0 || index >= polygon.length) return this;
    final updated = List<Offset>.from(polygon);
    updated[index] = newPos;
    return copyWith(polygon: updated);
  }

  /// Inserts a new vertex along edge [edgeIndex] at [newPos] (edge split).
  ArchitectZone insertVertex(int edgeIndex, Offset newPos) {
    if (edgeIndex < 0 || edgeIndex >= polygon.length) return this;
    final updated = List<Offset>.from(polygon);
    updated.insert(edgeIndex + 1, newPos);
    return copyWith(polygon: updated);
  }

  /// Deletes/merges vertex at [index]. Requires at least 4 vertices to keep polygon valid.
  ArchitectZone? removeVertex(int index) {
    if (polygon.length <= 3) return null;
    if (index < 0 || index >= polygon.length) return this;
    final updated = List<Offset>.from(polygon)..removeAt(index);
    return copyWith(polygon: updated);
  }

  /// Translates all vertices of the zone by [delta].
  ArchitectZone translate(Offset delta) {
    final updated = polygon.map((p) => p + delta).toList();
    return copyWith(polygon: updated);
  }

  /// Checks if polygon has self-intersecting edges.
  bool get hasSelfIntersections {
    final n = polygon.length;
    if (n < 4) return false;

    for (int i = 0; i < n; i++) {
      final a1 = polygon[i];
      final a2 = polygon[(i + 1) % n];
      for (int j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue;
        final b1 = polygon[j];
        final b2 = polygon[(j + 1) % n];
        if (_linesIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  static bool _linesIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double ccw(Offset a, Offset b, Offset c) =>
        (c.dy - a.dy) * (b.dx - a.dx) - (b.dy - a.dy) * (c.dx - a.dx);

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  ArchitectZone copyWith({
    String? id,
    String? number,
    String? name,
    ArchitectZoneCategory? category,
    List<Offset>? polygon,
    String? floorFinish,
    String? wallFinish,
    String? ceilingFinish,
    double? clearHeight,
    bool? isAutoBoundary,
    Offset? seedPoint,
    bool clearSeedPoint = false,
    double? targetArea,
    int? customColorValue,
  }) {
    return ArchitectZone(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      category: category ?? this.category,
      polygon: polygon ?? this.polygon,
      floorFinish: floorFinish ?? this.floorFinish,
      wallFinish: wallFinish ?? this.wallFinish,
      ceilingFinish: ceilingFinish ?? this.ceilingFinish,
      clearHeight: clearHeight ?? this.clearHeight,
      isAutoBoundary: isAutoBoundary ?? this.isAutoBoundary,
      seedPoint: clearSeedPoint ? null : (seedPoint ?? this.seedPoint),
      targetArea: targetArea ?? this.targetArea,
      customColorValue: customColorValue ?? this.customColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'category': category.name,
    'polygon': polygon.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'floorFinish': floorFinish,
    'wallFinish': wallFinish,
    'ceilingFinish': ceilingFinish,
    'clearHeight': clearHeight,
    'isAutoBoundary': isAutoBoundary,
    if (seedPoint != null)
      'seedPoint': {'x': seedPoint!.dx, 'y': seedPoint!.dy},
    'targetArea': targetArea,
    'customColorValue': customColorValue,
  };

  factory ArchitectZone.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String? ?? 'custom';
    final category = ArchitectZoneCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => ArchitectZoneCategory.custom,
    );

    final polyList =
        (json['polygon'] as List<dynamic>?)
            ?.map(
              (pt) => Offset(
                (pt['x'] as num).toDouble(),
                (pt['y'] as num).toDouble(),
              ),
            )
            .toList() ??
        const [];

    Offset? seed;
    if (json['seedPoint'] != null) {
      final sp = json['seedPoint'] as Map<String, dynamic>;
      seed = Offset((sp['x'] as num).toDouble(), (sp['y'] as num).toDouble());
    }

    return ArchitectZone(
      id: json['id'] as String,
      number: json['number'] as String? ?? '1',
      name: json['name'] as String? ?? '',
      category: category,
      polygon: polyList,
      floorFinish: json['floorFinish'] as String? ?? '',
      wallFinish: json['wallFinish'] as String? ?? '',
      ceilingFinish: json['ceilingFinish'] as String? ?? '',
      clearHeight: (json['clearHeight'] as num?)?.toDouble() ?? 2.60,
      isAutoBoundary: json['isAutoBoundary'] as bool? ?? true,
      seedPoint: seed,
      targetArea: (json['targetArea'] as num?)?.toDouble(),
      customColorValue: json['customColorValue'] as int?,
    );
  }
}
