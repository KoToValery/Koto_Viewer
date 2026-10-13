import 'dart:math' as math;
import 'dart:ui';

/// Represents a structural grid / axis line (осова линия).
/// Rendered with an architectural dash-dot pattern and an end circular bubble with label.
class BimGridAxis {
  final String id;
  final String name; // e.g. "1", "2", "A", "B"
  final Offset start;
  final Offset end;
  final bool bubbleAtStart;
  final bool bubbleAtEnd;

  /// Empty means a legacy/project-wide axis. Otherwise these floors supplied
  /// this shared alignment; the axis is a reference on every other floor.
  final List<String> sourceStoreyIds;

  const BimGridAxis({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.bubbleAtStart = true,
    this.bubbleAtEnd = true,
    this.sourceStoreyIds = const [],
  });

  double get length {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get angleRad => math.atan2(end.dy - start.dy, end.dx - start.dx);

  bool get isVertical => math.cos(angleRad).abs() <= math.sin(angleRad).abs();

  Offset get direction {
    final len = length;
    if (len < 1e-6) return const Offset(1, 0);
    return Offset((end.dx - start.dx) / len, (end.dy - start.dy) / len);
  }

  Offset get normal {
    final dir = direction;
    return Offset(-dir.dy, dir.dx);
  }

  Rect get bounds {
    final minX = math.min(start.dx, end.dx);
    final maxX = math.max(start.dx, end.dx);
    final minY = math.min(start.dy, end.dy);
    final maxY = math.max(start.dy, end.dy);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculates orthogonal projection of [pt] onto the infinite axis line.
  Offset projectPoint(Offset pt) {
    final dir = direction;
    final v = pt - start;
    final dot = v.dx * dir.dx + v.dy * dir.dy;
    return start + dir * dot;
  }

  /// Shortest distance from [pt] to the finite axis segment.
  double distanceToSegment(Offset pt) {
    final dir = direction;
    final v = pt - start;
    final dot = v.dx * dir.dx + v.dy * dir.dy;
    final clampedDot = dot.clamp(0.0, length);
    final proj = start + dir * clampedDot;
    return (pt - proj).distance;
  }

  /// Calculates intersection point with another axis line, or null if parallel.
  Offset? intersectionWith(BimGridAxis other) {
    final p1 = start;
    final p2 = end;
    final p3 = other.start;
    final p4 = other.end;

    final d =
        (p1.dx - p2.dx) * (p3.dy - p4.dy) - (p1.dy - p2.dy) * (p3.dx - p4.dx);
    if (d.abs() < 1e-6) return null; // Parallel

    final t =
        ((p1.dx - p3.dx) * (p3.dy - p4.dy) -
            (p1.dy - p3.dy) * (p3.dx - p4.dx)) /
        d;
    return Offset(p1.dx + t * (p2.dx - p1.dx), p1.dy + t * (p2.dy - p1.dy));
  }

  /// Checks whether this axis is parallel to [other] within an angular tolerance (~2.8 degrees).
  bool isParallelTo(BimGridAxis other, {double toleranceRad = 0.05}) {
    final d1 = direction;
    final d2 = other.direction;
    // Cross product of 2D unit vectors equals sin(theta)
    final cross = (d1.dx * d2.dy - d1.dy * d2.dx).abs();
    return cross < math.sin(toleranceRad);
  }

  /// Aligns this axis's start and end extents with [reference] along their common direction,
  /// preserving this axis's line position and orientation.
  BimGridAxis alignWith(BimGridAxis reference) {
    final refStart = reference.start;
    final refEnd = reference.end;
    final refDir = reference.direction;
    final refNormal = reference.normal;

    // Perpendicular offset of this axis's midpoint from reference's start
    final mid = (start + end) / 2.0;
    final dPerp =
        (mid - refStart).dx * refNormal.dx + (mid - refStart).dy * refNormal.dy;

    // Preserve orientation (whether this axis points in same or opposite direction as reference)
    final dot = direction.dx * refDir.dx + direction.dy * refDir.dy;

    final Offset newStart;
    final Offset newEnd;
    if (dot >= 0) {
      newStart = refStart + refNormal * dPerp;
      newEnd = refEnd + refNormal * dPerp;
    } else {
      newStart = refEnd + refNormal * dPerp;
      newEnd = refStart + refNormal * dPerp;
    }

    return copyWith(start: newStart, end: newEnd);
  }

  /// Computes the centerline bisector between two line segments (wall faces).
  static BimGridAxis? fromTwoSegments({
    required String id,
    required String name,
    required Offset a1,
    required Offset a2,
    required Offset b1,
    required Offset b2,
    double extensionLength = 1.5,
  }) {
    final vA = a2 - a1;
    final vB = b2 - b1;
    final lenA = vA.distance;
    final lenB = vB.distance;
    if (lenA < 1e-4 || lenB < 1e-4) return null;

    final uA = vA / lenA;
    var uB = vB / lenB;
    if (uA.dx * uB.dx + uA.dy * uB.dy < 0) {
      uB = -uB;
    }

    final avgDir = uA + uB;
    final avgLen = avgDir.distance;
    if (avgLen < 1e-4) return null;
    final dir = avgDir / avgLen;

    final midA = (a1 + a2) / 2.0;
    final midB = (b1 + b2) / 2.0;
    final center = (midA + midB) / 2.0;

    final projs = [
      a1,
      a2,
      b1,
      b2,
    ].map((p) => (p - center).dx * dir.dx + (p - center).dy * dir.dy).toList();
    final minProj = projs.reduce(math.min) - extensionLength;
    final maxProj = projs.reduce(math.max) + extensionLength;

    return BimGridAxis(
      id: id,
      name: name,
      start: center + dir * minProj,
      end: center + dir * maxProj,
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );
  }

  BimGridAxis copyWith({
    String? id,
    String? name,
    Offset? start,
    Offset? end,
    bool? bubbleAtStart,
    bool? bubbleAtEnd,
    List<String>? sourceStoreyIds,
  }) {
    return BimGridAxis(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      bubbleAtStart: bubbleAtStart ?? this.bubbleAtStart,
      bubbleAtEnd: bubbleAtEnd ?? this.bubbleAtEnd,
      sourceStoreyIds: sourceStoreyIds ?? this.sourceStoreyIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': {'dx': start.dx, 'dy': start.dy},
    'end': {'dx': end.dx, 'dy': end.dy},
    'bubbleAtStart': bubbleAtStart,
    'bubbleAtEnd': bubbleAtEnd,
    if (sourceStoreyIds.isNotEmpty) 'sourceStoreyIds': sourceStoreyIds,
  };

  factory BimGridAxis.fromJson(Map<String, dynamic> json) {
    return BimGridAxis(
      id: json['id'] as String,
      name: json['name'] as String? ?? '1',
      start: Offset(
        (json['start']['dx'] as num).toDouble(),
        (json['start']['dy'] as num).toDouble(),
      ),
      end: Offset(
        (json['end']['dx'] as num).toDouble(),
        (json['end']['dy'] as num).toDouble(),
      ),
      bubbleAtStart: json['bubbleAtStart'] as bool? ?? true,
      bubbleAtEnd: json['bubbleAtEnd'] as bool? ?? true,
      sourceStoreyIds: (json['sourceStoreyIds'] as List? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}

// Existing native import paths retain this name without duplicating geometry.
typedef StructuralGridAxis = BimGridAxis;

/// Sorts parallel axes along their normal direction and renames them.
/// Axes closer to vertical -> Numbers (1, 2, 3...)
/// Axes closer to horizontal -> Letters (А, Б, В... in BG, A, B, C... in EN).
List<BimGridAxis> resequenceGridAxes(
  List<BimGridAxis> axes, {
  required bool isBulgarian,
}) {
  if (axes.isEmpty) return axes;

  const bgLetters = [
    'А',
    'Б',
    'В',
    'Г',
    'Д',
    'Е',
    'Ж',
    'З',
    'И',
    'К',
    'Л',
    'М',
    'Н',
    'О',
    'П',
    'Р',
    'С',
    'Т',
    'У',
    'Ф',
    'Х',
    'Ц',
    'Ч',
    'Ш',
    'Щ',
  ];
  const enLetters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];
  final letters = isBulgarian ? bgLetters : enLetters;

  // Group axes into parallel sets
  final groups = <List<BimGridAxis>>[];
  for (final axis in axes) {
    bool foundGroup = false;
    for (final group in groups) {
      if (group.first.isParallelTo(axis, toleranceRad: 0.15)) {
        group.add(axis);
        foundGroup = true;
        break;
      }
    }
    if (!foundGroup) {
      groups.add([axis]);
    }
  }

  final result = <BimGridAxis>[];
  var numberIndex = 0, letterIndex = 0;

  for (int gIdx = 0; gIdx < groups.length; gIdx++) {
    final group = groups[gIdx];
    final refAxis = group.first;
    var normal = refAxis.normal;
    // Standardize normal direction to point in positive direction (left-to-right / bottom-to-top)
    if (normal.dx.abs() >= normal.dy.abs()) {
      if (normal.dx < 0) normal = -normal;
    } else {
      if (normal.dy < 0) normal = -normal;
    }

    // Sort axes in this group by position along the normal
    group.sort((a, b) {
      final midA = (a.start + a.end) / 2.0;
      final midB = (b.start + b.end) / 2.0;
      final coordA = midA.dx * normal.dx + midA.dy * normal.dy;
      final coordB = midB.dx * normal.dx + midB.dy * normal.dy;
      return coordA.compareTo(coordB);
    });

    final refAngle = refAxis.angleRad;
    final isVertical = (math.cos(refAngle).abs() <= math.sin(refAngle).abs());

    final bool useNumbers;
    if (groups.length == 1) {
      useNumbers = int.tryParse(refAxis.name) != null || isVertical;
    } else {
      useNumbers = isVertical;
    }

    for (int i = 0; i < group.length; i++) {
      final index = useNumbers ? numberIndex++ : letterIndex++;
      final newName = useNumbers
          ? '${index + 1}'
          : (index < letters.length
                ? letters[index]
                : '${letters[index % letters.length]}${(index ~/ letters.length) + 1}');
      result.add(group[i].copyWith(name: newName));
    }
  }

  return result;
}
