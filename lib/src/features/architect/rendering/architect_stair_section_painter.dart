import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_stair_section.dart';
import 'architect_canvas_palette.dart';
import 'architect_stair_mesh.dart';
import 'architect_wall_hatch.dart';

class ArchitectStairSectionPainter extends CustomPainter {
  final ArchitectStairSection section;
  final double cutHeight;
  final ArchitectCanvasPalette palette;
  ArchitectStairSectionPainter(this.section, {required this.cutHeight,
    this.palette = const ArchitectCanvasPalette.light()});
  @override
  void paint(Canvas canvas, Size size) {
    if (section.isEmpty) return;
    final b = section.bounds.inflate(.25);
    final scale = math.min(size.width / b.width, size.height / b.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, -scale);
    canvas.translate(-b.center.dx, -b.center.dy);
    final ink = palette.foreground(const Color(0xFF263238));
    final concrete = section.regions[StairSolidMaterial.concrete];
    if (concrete != null) {
      canvas.drawPath(concrete, Paint()..color = ink.withValues(alpha: .05));
      ArchitectWallHatch.paint(canvas, const ArchitectWall(id: 'hatch',
        startPoint: Offset.zero, endPoint: Offset(1, 0), coreMaterialOverride: WallCoreMaterial.concrete),
        concrete, scale, ink.withValues(alpha: .55));
      canvas.drawPath(concrete, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2.4 / scale);
    }
    final finish = section.regions[StairSolidMaterial.finish];
    if (finish != null) {
      canvas.drawPath(finish, Paint()..color = palette.isDark ? const Color(0xFF887E6B) : ArchitectStairMesh.finishColor);
      canvas.drawPath(finish, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = .7 / scale);
    }
    final metal = section.regions[StairSolidMaterial.metal];
    if (metal != null) canvas.drawPath(metal, Paint()..color = ink);
    final guide = Paint()..color = const Color(0xFFCC5555)..strokeWidth = .7 / scale;
    for (var x = b.left; x < b.right; x += 9 / scale) {
      canvas.drawLine(Offset(x, cutHeight), Offset(math.min(x + 5 / scale, b.right), cutHeight), guide);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(ArchitectStairSectionPainter old) => old.section != section ||
    old.cutHeight != cutHeight || old.palette.isDark != palette.isDark;
}
