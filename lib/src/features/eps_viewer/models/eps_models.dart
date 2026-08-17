import 'package:flutter/material.dart';

/// EPS Bounding Box (llx, lly, urx, ury in PostScript points).
class EpsBoundingBox {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const EpsBoundingBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get width => (maxX - minX).abs();
  double get height => (maxY - minY).abs();

  static const EpsBoundingBox defaultBox = EpsBoundingBox(
    minX: 0,
    minY: 0,
    maxX: 612, // Standard Letter width 8.5" * 72
    maxY: 792, // Standard Letter height 11" * 72
  );
}

/// EPS Document Metadata.
class EpsMetadata {
  final String? title;
  final String? creator;
  final String? creationDate;
  final EpsBoundingBox boundingBox;
  final int pathCount;

  const EpsMetadata({
    this.title,
    this.creator,
    this.creationDate,
    required this.boundingBox,
    required this.pathCount,
  });
}

/// Vector command type in EPS path.
enum EpsCommandType {
  moveTo,
  lineTo,
  cubicCurveTo,
  closePath,
}

/// Vector path command.
class EpsPathCommand {
  final EpsCommandType type;
  final Offset p1;
  final Offset? p2;
  final Offset? p3;

  const EpsPathCommand.moveTo(this.p1)
      : type = EpsCommandType.moveTo,
        p2 = null,
        p3 = null;

  const EpsPathCommand.lineTo(this.p1)
      : type = EpsCommandType.lineTo,
        p2 = null,
        p3 = null;

  const EpsPathCommand.cubicCurveTo(this.p1, this.p2, this.p3)
      : type = EpsCommandType.cubicCurveTo;

  const EpsPathCommand.closePath()
      : type = EpsCommandType.closePath,
        p1 = Offset.zero,
        p2 = null,
        p3 = null;
}

/// Styled EPS Vector Path.
class EpsPath {
  final List<EpsPathCommand> commands;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;

  const EpsPath({
    required this.commands,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.0,
  });
}

/// Parsed EPS Vector Document.
class EpsDocument {
  final EpsMetadata metadata;
  final List<EpsPath> paths;

  const EpsDocument({
    required this.metadata,
    required this.paths,
  });
}

/// Canvas Theme for EPS Vector Rendering.
enum EpsCanvasTheme {
  darkCad('Dark CAD', Color(0xFF1E1E1E), Color(0xFF2C2C2C), true),
  blueprint('Blueprint', Color(0xFF0F2042), Color(0xFF1B3566), true),
  lightStudio('Light Studio', Color(0xFFF8FAFC), Color(0xFFE2E8F0), false),
  pureBlack('Pure Black', Colors.black, Color(0xFF222222), true),
  pureWhite('Pure White', Colors.white, Color(0xFFE5E7EB), false);

  final String label;
  final Color background;
  final Color gridColor;
  final bool isDark;

  const EpsCanvasTheme(this.label, this.background, this.gridColor, this.isDark);
}
