// === SECTION: ARCHITECTURAL UPPER OVERHANG MODEL ===
import 'dart:ui';
import '../../../core/l10n/generated/app_localizations.dart';

/// Semantic classification of an upper floor overhang.
enum ArchitectOverhangKind {
  /// Enclosed heated living space/room projecting beyond the lower exterior facade.
  erker,

  /// Open or semi-open platform (terrace, balcony, loggia) with parapet/railing.
  balcony;

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case ArchitectOverhangKind.erker:
        return l10n.architectOverhangErker;
      case ArchitectOverhangKind.balcony:
        return l10n.architectOverhangBalcony;
    }
  }
}

/// Represents an erker or balcony from an upper floor projected onto the active floor plan.
class ArchitectOverhang {
  final String id;
  final ArchitectOverhangKind kind;
  final List<Offset> polygon;
  final Path? path;
  final String? customLabel;
  final double area; // in square meters
  final double overhangDepth; // projection distance in meters
  final String sourceStoreyId;
  final String sourceStoreyName;
  final double sourceStoreyElevation;

  const ArchitectOverhang({
    required this.id,
    required this.kind,
    required this.polygon,
    this.path,
    this.customLabel,
    this.area = 0.0,
    this.overhangDepth = 0.0,
    required this.sourceStoreyId,
    required this.sourceStoreyName,
    required this.sourceStoreyElevation,
  });

  String displayLabel(AppLocalizations l10n) {
    if (customLabel != null && customLabel!.trim().isNotEmpty) {
      return customLabel!.trim();
    }
    return kind.localizedLabel(l10n);
  }

  Offset get centroid {
    if (polygon.isNotEmpty) {
      double cx = 0, cy = 0;
      for (final p in polygon) {
        cx += p.dx;
        cy += p.dy;
      }
      return Offset(cx / polygon.length, cy / polygon.length);
    }
    if (path != null) {
      final bounds = path!.getBounds();
      return bounds.center;
    }
    return Offset.zero;
  }

  ArchitectOverhang copyWith({
    String? id,
    ArchitectOverhangKind? kind,
    List<Offset>? polygon,
    Path? path,
    String? customLabel,
    double? area,
    double? overhangDepth,
    String? sourceStoreyId,
    String? sourceStoreyName,
    double? sourceStoreyElevation,
  }) => ArchitectOverhang(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    polygon: polygon ?? this.polygon,
    path: path ?? this.path,
    customLabel: customLabel ?? this.customLabel,
    area: area ?? this.area,
    overhangDepth: overhangDepth ?? this.overhangDepth,
    sourceStoreyId: sourceStoreyId ?? this.sourceStoreyId,
    sourceStoreyName: sourceStoreyName ?? this.sourceStoreyName,
    sourceStoreyElevation: sourceStoreyElevation ?? this.sourceStoreyElevation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'polygon': polygon.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'customLabel': customLabel,
    'area': area,
    'overhangDepth': overhangDepth,
    'sourceStoreyId': sourceStoreyId,
    'sourceStoreyName': sourceStoreyName,
    'sourceStoreyElevation': sourceStoreyElevation,
  };

  factory ArchitectOverhang.fromJson(Map<String, dynamic> json) =>
      ArchitectOverhang(
        id: json['id'] as String,
        kind: ArchitectOverhangKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => ArchitectOverhangKind.erker,
        ),
        polygon: (json['polygon'] as List<dynamic>?)
                ?.map((p) => Offset(
                      (p['x'] as num).toDouble(),
                      (p['y'] as num).toDouble(),
                    ))
                .toList() ??
            const [],
        customLabel: json['customLabel'] as String?,
        area: (json['area'] as num?)?.toDouble() ?? 0.0,
        overhangDepth: (json['overhangDepth'] as num?)?.toDouble() ?? 0.0,
        sourceStoreyId: json['sourceStoreyId'] as String? ?? '',
        sourceStoreyName: json['sourceStoreyName'] as String? ?? '',
        sourceStoreyElevation:
            (json['sourceStoreyElevation'] as num?)?.toDouble() ?? 0.0,
      );
}
