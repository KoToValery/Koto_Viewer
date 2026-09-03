import 'dart:typed_data';
import 'package:flutter/material.dart';

/// PCB Layer Classification.
enum PcbLayerType {
  copperTop('Top Copper Layer', Color(0xFFD32F2F)),
  copperBottom('Bottom Copper Layer', Color(0xFF1976D2)),
  solderMaskTop('Top Solder Mask (Openings)', Color(0xFF8B5CF6)),
  solderMaskBottom('Bottom Solder Mask (Openings)', Color(0xFF7C3AED)),
  silkscreenTop('Top Silkscreen', Color(0xFFFFFFFF)),
  silkscreenBottom('Bottom Silkscreen', Color(0xFFFFF9C4)),
  edgeCuts('Board Outline / Edge Cuts', Color(0xFFD81B60)),
  drill('CNC Drill Holes', Color(0xFF00ACC1)),
  generic('PCB Gerber Layer', Color(0xFF43A047));

  final String displayName;
  final Color defaultAccent;

  const PcbLayerType(this.displayName, this.defaultAccent);
}

/// Aperture geometry shapes in Gerber RS-274X.
enum PcbApertureType {
  circle,
  rectangle,
  obround,
  polygon,
}

/// Aperture definition.
class PcbAperture {
  final int id;
  final PcbApertureType type;
  final double dimX;
  final double dimY;
  final double? holeDiameter;
  final List<Offset>? polygonPoints;

  const PcbAperture({
    required this.id,
    required this.type,
    required this.dimX,
    this.dimY = 0.0,
    this.holeDiameter,
    this.polygonPoints,
  });

  double get diameter => dimX;
}

/// Geometric command type in a Gerber layer.
enum PcbCommandType {
  line,
  arc,
  flash,
  region,
}

/// Vector element or flash pad.
class PcbCommand {
  final PcbCommandType type;
  final Offset p1;
  final Offset? p2;
  final Offset? center;
  final double? radius;
  final double? startAngle;
  final double? endAngle;
  final PcbAperture? aperture;
  final List<Offset>? regionPoints;
  final List<List<Offset>>? regionContours;
  final bool isDark;
  final String? pinNumber;
  final String? netName;
  final String? componentRef;

  const PcbCommand.line({
    required this.p1,
    required this.p2,
    this.aperture,
    this.isDark = true,
  })  : type = PcbCommandType.line,
        center = null,
        radius = null,
        startAngle = null,
        endAngle = null,
        regionPoints = null,
        regionContours = null,
        pinNumber = null,
        netName = null,
        componentRef = null;

  const PcbCommand.arc({
    required this.p1,
    required this.p2,
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
    this.aperture,
    this.isDark = true,
  })  : type = PcbCommandType.arc,
        regionPoints = null,
        regionContours = null,
        pinNumber = null,
        netName = null,
        componentRef = null;

  const PcbCommand.flash({
    required this.p1,
    required this.aperture,
    this.isDark = true,
    this.pinNumber,
    this.netName,
    this.componentRef,
  })  : type = PcbCommandType.flash,
        p2 = null,
        center = null,
        radius = null,
        startAngle = null,
        endAngle = null,
        regionPoints = null,
        regionContours = null;

  const PcbCommand.region({
    this.regionPoints,
    this.regionContours,
    this.isDark = true,
  })  : type = PcbCommandType.region,
        p1 = Offset.zero,
        p2 = null,
        center = null,
        radius = null,
        startAngle = null,
        endAngle = null,
        aperture = null,
        pinNumber = null,
        netName = null,
        componentRef = null;

  PcbCommand copyWithPinNumber(String? newPin, {String? newNet, String? newComp}) {
    if (type == PcbCommandType.flash) {
      return PcbCommand.flash(
        p1: p1,
        aperture: aperture,
        isDark: isDark,
        pinNumber: newPin ?? pinNumber,
        netName: newNet ?? netName,
        componentRef: newComp ?? componentRef,
      );
    }
    return this;
  }
}

/// Single Excellon CNC drill hole.
class PcbDrillHole {
  final Offset position;
  final double diameterMm;
  final int toolId;
  final String? pinNumber;
  final String? netName;

  const PcbDrillHole({
    required this.position,
    required this.diameterMm,
    required this.toolId,
    this.pinNumber,
    this.netName,
  });

  PcbDrillHole copyWith({String? pinNumber, String? netName}) {
    return PcbDrillHole(
      position: position,
      diameterMm: diameterMm,
      toolId: toolId,
      pinNumber: pinNumber ?? this.pinNumber,
      netName: netName ?? this.netName,
    );
  }
}

/// Bounding Box in mm for the PCB.
class PcbBoundingBox {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const PcbBoundingBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get widthMm => (maxX - minX).abs();
  double get heightMm => (maxY - minY).abs();
  double get widthInches => widthMm / 25.4;
  double get heightInches => heightMm / 25.4;

  static const PcbBoundingBox defaultBox = PcbBoundingBox(
    minX: 0,
    minY: 0,
    maxX: 100,
    maxY: 80,
  );
}

/// Complete parsed PCB Document (Gerber layer or Drill file).
class PcbDocument {
  final String fileName;
  final PcbLayerType layerType;
  final String? formatComment;
  final List<PcbCommand> commands;
  final List<PcbDrillHole> drillHoles;
  final PcbBoundingBox boundingBox;

  const PcbDocument({
    required this.fileName,
    required this.layerType,
    this.formatComment,
    required this.commands,
    required this.drillHoles,
    required this.boundingBox,
  });

  int get trackCount => commands.where((c) => c.type == PcbCommandType.line || c.type == PcbCommandType.arc).length;
  int get padCount => commands.where((c) => c.type == PcbCommandType.flash).length;
  int get regionCount => commands.where((c) => c.type == PcbCommandType.region).length;
  int get holeCount => drillHoles.length;
  bool get hasPadNumbers =>
      commands.any((c) => c.pinNumber != null && c.pinNumber!.isNotEmpty) ||
      drillHoles.any((d) => d.pinNumber != null && d.pinNumber!.isNotEmpty);
}

/// Side of the PCB to view.
enum PcbViewSide {
  top('Top Side (Components)'),
  bottom('Bottom Side (Solder)'),
  composite('Composite (All Layers)');

  final String label;
  const PcbViewSide(this.label);
}

/// A single layer within a multi-layer PCB project.
class PcbLayerItem {
  final String fileName;
  final PcbLayerType type;
  final PcbDocument document;
  bool isVisible;
  double opacity;
  Color? customColor;
  int order;

  PcbLayerItem({
    required this.fileName,
    required this.type,
    required this.document,
    this.isVisible = true,
    this.opacity = 1.0,
    this.customColor,
    this.order = 0,
  });

  String get displayName {
    if (fileName.isNotEmpty && fileName != 'layer.gbr') {
      return '$fileName (${type.displayName})';
    }
    return type.displayName;
  }
}

/// Bill of Materials (BOM) entry.
class PcbBomEntry {
  final String designator;
  final String value;
  final String footprint;
  final String description;
  final int quantity;
  final String? partNumber;

  const PcbBomEntry({
    required this.designator,
    required this.value,
    this.footprint = '',
    this.description = '',
    this.quantity = 1,
    this.partNumber,
  });
}

class PcbImageItem {
  final String fileName;
  final Uint8List bytes;

  const PcbImageItem({
    required this.fileName,
    required this.bytes,
  });
}

class PcbArchiveFileItem {
  final String fileName;
  final int sizeInBytes;
  final Uint8List bytes;

  const PcbArchiveFileItem({
    required this.fileName,
    required this.sizeInBytes,
    required this.bytes,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Complete Multi-Layer PCB Project (e.g. from a Proteus / Altium / KiCad ZIP archive).
class PcbProject {
  final String projectName;
  final String sourcePath;
  final List<PcbLayerItem> layers;
  final List<PcbBomEntry> bomEntries;
  final List<PcbImageItem> images;
  final List<PcbArchiveFileItem> archiveFiles;
  final PcbBoundingBox boundingBox;
  PcbViewSide viewSide;

  PcbProject({
    required this.projectName,
    required this.sourcePath,
    required this.layers,
    this.bomEntries = const [],
    this.images = const [],
    this.archiveFiles = const [],
    required this.boundingBox,
    this.viewSide = PcbViewSide.top,
  });

  int get totalLayers => layers.length;
  int get visibleLayers => layers.where((l) => l.isVisible).length;
  int get totalComponents => bomEntries.fold(0, (sum, e) => sum + e.quantity);
  int get totalImages => images.length;
  int get totalArchiveFiles => archiveFiles.length;
  bool get hasPadNumbers => layers.any((l) => l.document.hasPadNumbers);

  PcbLayerItem? get edgeCutsLayer =>
      layers.cast<PcbLayerItem?>().firstWhere((l) => l?.type == PcbLayerType.edgeCuts, orElse: () => null);

  List<PcbLayerItem> get drillLayers =>
      layers.where((l) => l.type == PcbLayerType.drill).toList();
}

/// Theme for PCB Rendering.
enum PcbTheme {
  fr4Green(
    'FR4 Green',
    Color(0xFF0F3822),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFFFFFFF),
    Color(0xFFE11D48),
  ),
  matteBlack(
    'Matte Black',
    Color(0xFF141414),
    Color(0xFFD97706),
    Color(0xFF262626),
    Color(0xFFF3F4F6),
    Color(0xFFEF4444),
  ),
  arduinoBlue(
    'Arduino Blue',
    Color(0xFF0C274E),
    Color(0xFFFBBF24),
    Color(0xFF2563EB),
    Color(0xFFFFFFFF),
    Color(0xFFEC4899),
  ),
  sparkfunRed(
    'SparkFun Red',
    Color(0xFF3F0B0B),
    Color(0xFFFDE047),
    Color(0xFFDC2626),
    Color(0xFFFFFFFF),
    Color(0xFF38BDF8),
  ),
  darkCad(
    'Dark CAD',
    Color(0xFF18181B),
    Color(0xFF38BDF8),
    Color(0xFF059669),
    Color(0xFFFBBF24),
    Color(0xFFF43F5E),
  ),
  highContrast(
    'High Contrast',
    Colors.black,
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Colors.white,
    Color(0xFFFF00FF),
  );

  final String label;
  final Color substrate;
  final Color copper;
  final Color mask;
  final Color silk;
  final Color outline;

  const PcbTheme(
    this.label,
    this.substrate,
    this.copper,
    this.mask,
    this.silk,
    this.outline,
  );
}
