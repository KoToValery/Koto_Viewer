import 'package:flutter/material.dart';
import '../models/structural_element.dart';

class GridAxisPresentation {
  final bool reference;
  final Color color;
  final String levels;
  const GridAxisPresentation(this.reference, this.color, this.levels);
  static const referencePalette = [
    Color(0xFF71B6E8),
    Color(0xFF8BC79B),
    Color(0xFFB898DC),
    Color(0xFFE2B37E),
    Color(0xFF74C8C7),
  ];
  static GridAxisPresentation forStorey(
    StructuralGridAxis axis,
    StoreyLevel current,
    List<StoreyLevel> storeys,
  ) {
    final floors = [...storeys]
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final sources = floors
        .where((s) => axis.sourceStoreyIds.contains(s.id))
        .toList();
    final reference =
        axis.sourceStoreyIds.isNotEmpty &&
        !axis.sourceStoreyIds.contains(current.id);
    final origin = sources.firstOrNull;
    final index = origin == null ? 0 : floors.indexOf(origin);
    return GridAxisPresentation(
      reference,
      reference
          ? (index < referencePalette.length
                    ? referencePalette[index]
                    : HSLColor.fromAHSL(
                        1,
                        (210 + index * 137.507764) % 360,
                        .55,
                        .72,
                      ).toColor())
                .withValues(alpha: .5)
          : const Color(0xFFFF453A),
      sources.map((s) => s.elevationLabel).join(', '),
    );
  }
}
