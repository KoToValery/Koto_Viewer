import 'dart:ui';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';

/// Editable dimensions are finished dimensions in metres, in the stair's local
/// frame. The frame's handedness is supplied by ArchitectStairDesign.turnLeft.
class ArchitectStairFlightSpec {
  final String id;
  final Offset origin, axis;
  final double width;
  final int risers;
  final double? fixedRun;
  final bool countLocked;
  const ArchitectStairFlightSpec({
    required this.id,
    required this.origin,
    required this.axis,
    required this.width,
    required this.risers,
    this.fixedRun,
    this.countLocked = false,
  });
  Offset get normal => Offset(-axis.dy, axis.dx);
  double run(double going) => (risers - 1) * going;
  Offset end(double going) => origin + axis * run(going);
  List<Offset> footprint(double going) => [
    origin - normal * width / 2,
    end(going) - normal * width / 2,
    end(going) + normal * width / 2,
    origin + normal * width / 2,
  ];
  ArchitectStairFlightSpec copyWith({
    Offset? origin,
    Offset? axis,
    double? width,
    int? risers,
    double? fixedRun,
    bool clearFixedRun = false,
    bool? countLocked,
  }) => ArchitectStairFlightSpec(
    id: id,
    origin: origin ?? this.origin,
    axis: axis ?? this.axis,
    width: width ?? this.width,
    risers: risers ?? this.risers,
    fixedRun: clearFixedRun ? null : fixedRun ?? this.fixedRun,
    countLocked: countLocked ?? this.countLocked,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': stairPointJson(origin),
    'axis': stairPointJson(axis),
    'width': width,
    'risers': risers,
    'fixedRun': fixedRun,
    'countLocked': countLocked,
  };
  factory ArchitectStairFlightSpec.fromJson(Map<String, dynamic> j) =>
      ArchitectStairFlightSpec(
        id: j['id'] as String,
        origin: stairReadPoint(j['origin']),
        axis: stairReadPoint(j['axis']),
        width: (j['width'] as num).toDouble(),
        risers: (j['risers'] as num).toInt(),
        fixedRun: (j['fixedRun'] as num?)?.toDouble(),
        countLocked: j['countLocked'] as bool? ?? false,
      );
}

class ArchitectStairLandingSpec {
  final String id;
  final List<Offset> polygon;
  ArchitectStairLandingSpec({required this.id, required List<Offset> polygon})
    : polygon = List.unmodifiable(polygon);
  ArchitectStairLandingSpec copyWith({List<Offset>? polygon}) =>
      ArchitectStairLandingSpec(id: id, polygon: polygon ?? this.polygon);
  Map<String, dynamic> toJson() => {
    'id': id,
    'polygon': polygon.map(stairPointJson).toList(),
  };
  factory ArchitectStairLandingSpec.fromJson(Map<String, dynamic> j) =>
      ArchitectStairLandingSpec(
        id: j['id'] as String,
        polygon: (j['polygon'] as List).map(stairReadPoint).toList(),
      );
}

/// Landing i connects flights i and i+1. A trailing landing is allowed while
/// drafting, but a committed layout always ends with a flight.
class ArchitectStairLayout {
  static const currentVersion = 1;
  final List<ArchitectStairFlightSpec> flights;
  final List<ArchitectStairLandingSpec> landings;
  final List<Offset> cell;
  final bool goingLocked;
  ArchitectStairLayout({
    required List<ArchitectStairFlightSpec> flights,
    List<ArchitectStairLandingSpec> landings = const [],
    List<Offset> cell = const [],
    this.goingLocked = false,
  }) : flights = List.unmodifiable(flights),
       landings = List.unmodifiable(landings),
       cell = List.unmodifiable(cell);
  int get risers => flights.fold(0, (n, f) => n + f.risers);
  ArchitectStairLayout copyWith({
    List<ArchitectStairFlightSpec>? flights,
    List<ArchitectStairLandingSpec>? landings,
    List<Offset>? cell,
    bool? goingLocked,
  }) => ArchitectStairLayout(
    flights: flights ?? this.flights,
    landings: landings ?? this.landings,
    cell: cell ?? this.cell,
    goingLocked: goingLocked ?? this.goingLocked,
  );
  void validate() {
    if (flights.isEmpty ||
        risers > 500 ||
        landings.length != flights.length - 1) {
      throw ArgumentError('Incomplete stair layout');
    }
    final ids = <String>{};
    for (final f in flights) {
      if (!ids.add(f.id) ||
          f.id.isEmpty ||
          !stairFinitePoint(f.origin) ||
          !stairFinitePoint(f.axis) ||
          (f.axis.distance - 1).abs() > 1e-6 ||
          !f.width.isFinite ||
          f.width <= 0 ||
          f.risers < 2 ||
          (f.fixedRun != null && (!f.fixedRun!.isFinite || f.fixedRun! <= 0))) {
        throw ArgumentError('Invalid stair flight');
      }
    }
    for (final l in landings) {
      if (!ids.add(l.id) ||
          l.id.isEmpty ||
          l.polygon.length < 3 ||
          !BimPolygonGeometry.valid(l.polygon)) {
        throw ArgumentError('Invalid stair landing');
      }
    }
    if (cell.isNotEmpty && !BimPolygonGeometry.valid(cell)) {
      throw ArgumentError('Invalid stair cell');
    }
  }

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'flights': flights.map((f) => f.toJson()).toList(),
    'landings': landings.map((l) => l.toJson()).toList(),
    'cell': cell.map(stairPointJson).toList(),
    'goingLocked': goingLocked,
  };
  factory ArchitectStairLayout.fromJson(Map<String, dynamic> j) {
    if (j['version'] != currentVersion)
      throw ArgumentError('Unknown stair layout version');
    final result = ArchitectStairLayout(
      flights: (j['flights'] as List)
          .map(
            (f) => ArchitectStairFlightSpec.fromJson(
              Map<String, dynamic>.from(f as Map),
            ),
          )
          .toList(),
      landings: (j['landings'] as List)
          .map(
            (l) => ArchitectStairLandingSpec.fromJson(
              Map<String, dynamic>.from(l as Map),
            ),
          )
          .toList(),
      cell: (j['cell'] as List? ?? []).map(stairReadPoint).toList(),
      goingLocked: j['goingLocked'] as bool? ?? false,
    );
    result.validate();
    return result;
  }
}

bool stairFinitePoint(Offset p) => p.dx.isFinite && p.dy.isFinite;
Map<String, double> stairPointJson(Offset p) => {'x': p.dx, 'y': p.dy};
Offset stairReadPoint(dynamic value) {
  final j = value as Map;
  return Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}
