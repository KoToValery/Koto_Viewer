import 'dart:ui';

Offset sectionPoint(Map j) =>
    Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
Map<String, double> sectionPointJson(Offset p) => {'x': p.dx, 'y': p.dy};

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
  final List<ArchitectSlabDetail> details;
  const ArchitectSection({
    required this.id,
    required this.start,
    required this.end,
    this.name = '',
    this.details = const [],
  });
  double get length => (end - start).distance;
  Offset get axis =>
      length > 1e-9 ? (end - start) / length : const Offset(1, 0);
  Offset pointAt(double station) => start + axis * station;
  ArchitectSection copyWith({
    String? name,
    Offset? start,
    Offset? end,
    List<ArchitectSlabDetail>? details,
  }) => ArchitectSection(
    id: id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    details: details ?? this.details,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': sectionPointJson(start),
    'end': sectionPointJson(end),
    'details': details.map((d) => d.toJson()).toList(),
  };
  factory ArchitectSection.fromJson(Map<String, dynamic> j) => ArchitectSection(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    start: sectionPoint(j['start'] as Map),
    end: sectionPoint(j['end'] as Map),
    details: (j['details'] as List? ?? [])
        .map(
          (d) =>
              ArchitectSlabDetail.fromJson(Map<String, dynamic>.from(d as Map)),
        )
        .toList(),
  );
}
