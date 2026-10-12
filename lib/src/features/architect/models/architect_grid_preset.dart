// === SECTION: ARCHITECTURAL GRID PRESET MODELS ===
import 'dart:ui';
import '../models/architect_grid_axis.dart';

/// Preset classification for modular architectural structural grid axes.
enum GridPresetType {
  /// Parking & residential bays: 7.20 m x 6.60 m (3 parking spots x 2.40 m with 6.60 m aisle).
  parking,

  /// Residential standard span: 3.60 m x 6.00 m.
  residential,

  /// Single-family house / villa: 4.50 m x 4.50 m.
  villa,

  /// Modular office / commercial building: 6.00 m x 6.00 m.
  modular,

  /// Custom parametric user-defined grid.
  custom,

  /// Blank canvas without pre-generated grid axes.
  none,
}

/// A pre-configured structural grid template.
class ArchitectGridPreset {
  final String id;
  final String name;
  final String description;
  final GridPresetType type;
  final double spacingX; // in meters
  final double spacingY; // in meters
  final int axesX; // count of X axes (1, 2, 3...)
  final int axesY; // count of Y axes (A, B, C...)

  const ArchitectGridPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.spacingX = 6.00,
    this.spacingY = 6.00,
    this.axesX = 4,
    this.axesY = 3,
  });

  /// Standard presets convenient for architectural and structural drafting.
  static List<ArchitectGridPreset> standardPresets() => const [
    ArchitectGridPreset(
      id: 'preset_parking_72_66',
      name: '7.20 / 6.60',
      description: '',
      type: GridPresetType.parking,
      spacingX: 7.20,
      spacingY: 6.60,
      axesX: 4,
      axesY: 3,
    ),
    ArchitectGridPreset(
      id: 'preset_res_36_60',
      name: '3.60 / 6.00',
      description: '',
      type: GridPresetType.residential,
      spacingX: 3.60,
      spacingY: 6.00,
      axesX: 5,
      axesY: 3,
    ),
    ArchitectGridPreset(
      id: 'preset_villa_45_45',
      name: '4.50 / 4.50',
      description: '',
      type: GridPresetType.villa,
      spacingX: 4.50,
      spacingY: 4.50,
      axesX: 3,
      axesY: 3,
    ),
    ArchitectGridPreset(
      id: 'preset_modular_60_60',
      name: '6.00 / 6.00',
      description: '',
      type: GridPresetType.modular,
      spacingX: 6.00,
      spacingY: 6.00,
      axesX: 4,
      axesY: 4,
    ),
    ArchitectGridPreset(
      id: 'preset_custom',
      name: '',
      description: '',
      type: GridPresetType.custom,
      spacingX: 4.00,
      spacingY: 5.00,
      axesX: 4,
      axesY: 3,
    ),
    ArchitectGridPreset(
      id: 'preset_none',
      name: '',
      description: '',
      type: GridPresetType.none,
      spacingX: 0.0,
      spacingY: 0.0,
      axesX: 0,
      axesY: 0,
    ),
  ];

  /// Generates the list of [StructuralGridAxis] elements for this preset.
  List<StructuralGridAxis> generateAxes({
    int? customAxesX,
    int? customAxesY,
    double? customSpacingX,
    double? customSpacingY,
    List<double>? spacingsX,
    List<double>? spacingsY,
  }) {
    if (type == GridPresetType.none) return const [];

    final nx = spacingsX != null ? spacingsX.length + 1 : customAxesX ?? axesX;
    final ny = spacingsY != null ? spacingsY.length + 1 : customAxesY ?? axesY;
    final dx = customSpacingX ?? spacingX;
    final dy = customSpacingY ?? spacingY;

    if (nx <= 0 || ny <= 0 || dx <= 0 || dy <= 0) return const [];

    final xSteps = spacingsX ?? List.filled(nx - 1, dx);
    final ySteps = spacingsY ?? List.filled(ny - 1, dy);
    if ([...xSteps, ...ySteps].any((d) => !d.isFinite || d <= 0)) {
      throw ArgumentError('Invalid grid spacing');
    }
    final xs = [0.0];
    final ys = [0.0];
    for (final d in xSteps) {
      xs.add(xs.last + d);
    }
    for (final d in ySteps) {
      ys.add(ys.last + d);
    }
    final totalWidth = xs.last;
    final totalHeight = ys.last;
    const margin = 1.50; // bubble extension margin in meters

    final axes = <StructuralGridAxis>[];

    // Vertical axes (numbered 1, 2, 3...)
    for (int i = 0; i < nx; i++) {
      final x = xs[i];
      axes.add(
        StructuralGridAxis(
          id: 'axis_x_${i + 1}',
          name: '${i + 1}',
          start: Offset(x, -margin),
          end: Offset(x, totalHeight + margin),
          bubbleAtStart: true,
          bubbleAtEnd: true,
        ),
      );
    }

    // Horizontal axes (lettered A, B, C...)
    const letters = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
    ];
    for (int j = 0; j < ny; j++) {
      final y = ys[j];
      final label = j < letters.length ? letters[j] : 'Y${j + 1}';
      axes.add(
        StructuralGridAxis(
          id: 'axis_y_$j',
          name: label,
          start: Offset(-margin, y),
          end: Offset(totalWidth + margin, y),
          bubbleAtStart: true,
          bubbleAtEnd: true,
        ),
      );
    }

    return axes;
  }
}
