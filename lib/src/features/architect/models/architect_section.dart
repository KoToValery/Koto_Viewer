import 'architect_view_drawing.dart';
import 'dart:ui';

Offset sectionPoint(Map j) =>
    Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
Map<String, double> sectionPointJson(Offset p) => {'x': p.dx, 'y': p.dy};
double? viewDepthFromJson(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;

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
  final List<ArchitectSlabDetail> details;
  final ArchitectViewDrawing drawing;
  const ArchitectSection({
    required this.id,
    required this.start,
    required this.end,
    this.viewDepth,
    this.name = '',
    this.details = const [],
    this.drawing = const ArchitectViewDrawing(),
  });
  double get length => (end - start).distance;
  Offset get axis =>
      length > 1e-9 ? (end - start) / length : const Offset(1, 0);
  Offset pointAt(double station) => start + axis * station;

  /// Looking left of the ordered cut line makes station increase to screen-right.
  /// Endpoint order persists the viewing direction in existing project files.
  Offset get viewDirection => Offset(-axis.dy, axis.dx);
  ArchitectSection reversed() => copyWith(
    start: end,
    end: start,
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
    double? viewDepth,
    bool clearViewDepth = false,
  }) => ArchitectSection(
    id: id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    details: details ?? this.details,
    drawing: drawing ?? this.drawing,
    viewDepth: clearViewDepth ? null : viewDepth ?? this.viewDepth,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': sectionPointJson(start),
    'end': sectionPointJson(end),
    'viewDepth': viewDepth,
    'details': details.map((d) => d.toJson()).toList(),
    'drawing': drawing.toJson(),
  };
  factory ArchitectSection.fromJson(Map<String, dynamic> j) => ArchitectSection(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    drawing: ArchitectViewDrawing.fromJson(
      Map<String, dynamic>.from(j['drawing'] as Map? ?? {}),
    ),
    start: sectionPoint(j['start'] as Map),
    end: sectionPoint(j['end'] as Map),
    viewDepth: viewDepthFromJson(j['viewDepth']),
    details: (j['details'] as List? ?? [])
        .map(
          (d) =>
              ArchitectSlabDetail.fromJson(Map<String, dynamic>.from(d as Map)),
        )
        .toList(),
  );
}
