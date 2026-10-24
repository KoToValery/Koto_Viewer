import 'architect_view_drawing.dart';
import 'architect_section_visibility.dart';
import 'dart:ui';

Offset sectionPoint(Map j) =>
    Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
Map<String, double> sectionPointJson(Offset p) => {'x': p.dx, 'y': p.dy};
double? viewDepthFromJson(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;

/// Each point stores a station and the perpendicular offset of the segment
/// starting there. Offsets share the original marker's far clipping plane.
typedef ArchitectViewSegment = ({
  double station,
  Offset start,
  Offset end,
  double offset,
});
List<ArchitectViewSegment> viewSegments(
  Offset start,
  Offset end,
  Offset normal,
  List<Offset> steps,
) {
  final length = (end - start).distance;
  if (!length.isFinite ||
      length < .01 ||
      !start.dx.isFinite ||
      !start.dy.isFinite ||
      !end.dx.isFinite ||
      !end.dy.isFinite) {
    throw ArgumentError('Invalid view span');
  }
  final axis = (end - start) / length;
  var station = 0.0, offset = 0.0;
  final result =
      <({double station, Offset start, Offset end, double offset})>[];
  void segment(double stop) {
    if (stop > station) {
      result.add((
        station: station,
        start: start + axis * station + normal * offset,
        end: start + axis * stop + normal * offset,
        offset: offset,
      ));
    }
  }

  for (final step in steps) {
    if (!step.dx.isFinite ||
        !step.dy.isFinite ||
        step.dx < station ||
        step.dx >= length ||
        (step.dx > station && step.dx - station < .01)) {
      throw ArgumentError('Invalid view step');
    }
    segment(step.dx);
    station = step.dx;
    offset = step.dy;
  }
  segment(length);
  return result;
}

class ArchitectSlabDetail {
  final String id, slabId;

  /// Distance along the section, in metres. Remains associated when the cut moves.
  final double station;
  final double fallbackElevation;
  final Offset textOffset;
  const ArchitectSlabDetail({
    required this.id,
    required this.slabId,
    required this.station,
    this.fallbackElevation = 0,
    this.textOffset = const Offset(1.5, 1),
  });
  ArchitectSlabDetail copyWith({
    String? slabId,
    double? station,
    Offset? textOffset,
  }) => ArchitectSlabDetail(
    id: id,
    slabId: slabId ?? this.slabId,
    station: station ?? this.station,
    fallbackElevation: fallbackElevation,
    textOffset: textOffset ?? this.textOffset,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'slabId': slabId,
    'station': station,
    'fallbackElevation': fallbackElevation,
    'textOffset': sectionPointJson(textOffset),
  };
  factory ArchitectSlabDetail.fromJson(Map<String, dynamic> j) =>
      ArchitectSlabDetail(
        id: j['id'] as String,
        slabId: j['slabId'] as String,
        station: (j['station'] as num).toDouble(),
        fallbackElevation: (j['fallbackElevation'] as num?)?.toDouble() ?? 0,
        textOffset: sectionPoint(j['textOffset'] as Map),
      );
}

class ArchitectSection {
  final String id, name;
  final Offset start, end;

  /// Far clipping distance in model metres; null keeps legacy unlimited views.
  final double? viewDepth;
  final List<Offset> steps;
  final List<ArchitectSlabDetail> details;
  final ArchitectViewDrawing drawing;
  final ArchitectSectionVisibility visibility;
  const ArchitectSection({
    required this.id,
    required this.start,
    required this.end,
    this.viewDepth,
    this.steps = const [],
    this.name = '',
    this.details = const [],
    this.drawing = const ArchitectViewDrawing(),
    this.visibility = const ArchitectSectionVisibility(),
  });
  double get length => (end - start).distance;
  Offset get axis =>
      length > 1e-9 ? (end - start) / length : const Offset(1, 0);
  List<ArchitectViewSegment> get segments =>
      viewSegments(start, end, viewDirection, steps);
  Offset pointAt(double station) {
    if (steps.isEmpty) return start + axis * station;
    final segment = segments.lastWhere(
      (s) => s.station <= station,
      orElse: () => segments.first,
    );
    return segment.start + axis * (station - segment.station);
  }

  /// Looking left of the ordered cut line makes station increase to screen-right.
  /// Endpoint order persists the viewing direction in existing project files.
  Offset get viewDirection => Offset(-axis.dy, axis.dx);
  ArchitectSection reversed() => copyWith(
    start: end,
    end: start,
    steps: [
      for (final s in segments.reversed)
        if (steps.isNotEmpty &&
            (s.station + (s.end - s.start).distance < length - 1e-8 ||
                s.offset != 0))
          Offset(length - s.station - (s.end - s.start).distance, -s.offset),
    ],
    details: [
      for (final d in details)
        ArchitectSlabDetail(
          id: d.id,
          slabId: d.slabId,
          station: length - d.station,
          fallbackElevation: d.fallbackElevation,
          textOffset: Offset(-d.textOffset.dx, d.textOffset.dy),
        ),
    ],
  );
  ArchitectSection copyWith({
    String? name,
    Offset? start,
    Offset? end,
    List<ArchitectSlabDetail>? details,
    ArchitectViewDrawing? drawing,
    ArchitectSectionVisibility? visibility,
    double? viewDepth,
    bool clearViewDepth = false,
    List<Offset>? steps,
  }) => ArchitectSection(
    id: id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    details: details ?? this.details,
    drawing: drawing ?? this.drawing,
    visibility: visibility ?? this.visibility,
    viewDepth: clearViewDepth ? null : viewDepth ?? this.viewDepth,
    steps: steps ?? this.steps,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': sectionPointJson(start),
    'end': sectionPointJson(end),
    'viewDepth': viewDepth,
    'steps': steps.map(sectionPointJson).toList(),
    'details': details.map((d) => d.toJson()).toList(),
    'drawing': drawing.toJson(),
    if (visibility.categories.isNotEmpty) 'visibility': visibility.toJson(),
  };
  factory ArchitectSection.fromJson(Map<String, dynamic> j) => ArchitectSection(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    visibility: ArchitectSectionVisibility.fromJson(j['visibility']),
    drawing: ArchitectViewDrawing.fromJson(
      Map<String, dynamic>.from(j['drawing'] as Map? ?? {}),
    ),
    start: sectionPoint(j['start'] as Map),
    end: sectionPoint(j['end'] as Map),
    viewDepth: viewDepthFromJson(j['viewDepth']),
    steps: [for (final p in j['steps'] as List? ?? []) sectionPoint(p as Map)],
    details: (j['details'] as List? ?? [])
        .map(
          (d) =>
              ArchitectSlabDetail.fromJson(Map<String, dynamic>.from(d as Map)),
        )
        .toList(),
  );
}
