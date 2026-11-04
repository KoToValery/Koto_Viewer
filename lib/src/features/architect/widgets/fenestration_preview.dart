import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../models/architect_door.dart';
import '../models/architect_window.dart';
import '../models/architect_fenestration_style.dart';
import '../rendering/fenestration_3d_builder.dart';

enum FenestrationPreviewMode { elevation, plan, threeD }

/// Library and editor previews use the same model renderers as placed openings.
class FenestrationPreview extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final FenestrationPreviewMode mode;
  final bool dimensions;
  final String? selectedPaneId;
  final Cad3DCamera? camera;
  const FenestrationPreview({
    super.key,
    required this.style,
    this.mode = FenestrationPreviewMode.elevation,
    this.dimensions = false,
    this.selectedPaneId,
    this.camera,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == FenestrationPreviewMode.threeD) {
      final mesh = Mesh3D(
        name: style.name,
        triangles: Fenestration3dBuilder.buildOpening3D(
          style: style,
          wallStart: const Offset(-3, 0),
          wallEnd: const Offset(3, 0),
          wallThickness: .37,
          coreThickness: .25,
          insulationThickness: .12,
          exteriorSign: 1,
          offsetRatio: .5,
          width: style.defaultWidth,
          height: style.defaultHeight,
          sillHeight: style.defaultSillHeight,
          storeyElevation: 0,
        ),
      );
      return ColoredBox(
        color: Colors.white,
        child: CustomPaint(
          painter: Cad3DMeshPainter(
            mesh: mesh,
            camera: camera ?? Cad3DCamera(yaw: -.6, pitch: .25, zoom: 1.5),
            theme: Cad3DTheme.pureWhite,
            showGrid: false,
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.white,
      child: CustomPaint(
        painter: _FenestrationPreviewPainter(
          style,
          mode,
          dimensions,
          selectedPaneId,
        ),
      ),
    );
  }
}

class _FenestrationPreviewPainter extends CustomPainter {
  final ArchitectFenestrationStyle style;
  final FenestrationPreviewMode mode;
  final bool dimensions;
  final String? selectedPaneId;
  _FenestrationPreviewPainter(
    this.style,
    this.mode,
    this.dimensions,
    this.selectedPaneId,
  );
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (mode == FenestrationPreviewMode.elevation) {
      style.paintElevation2D(
        canvas: canvas,
        size: size,
        selectedPaneId: selectedPaneId,
        showDimensions: dimensions,
      );
      return;
    }
    final w = style.defaultWidth;
    final bounds = Rect.fromLTRB(
      -.65,
      -.65,
      w + .65,
      style.kind == FenestrationKind.door ? math.max(.8, w + .25) : .75,
    );
    final scale = math.min(
      (size.width - 16) / bounds.width,
      (size.height - 16) / bounds.height,
    );
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    final wallStroke = Paint()
      ..color = const Color(0xFF40464B)
      ..strokeWidth = 1.5 / scale
      ..style = PaintingStyle.stroke;
    for (final r in [
      Rect.fromLTRB(-.6, -.185, 0, .185),
      Rect.fromLTRB(w, -.185, w + .6, .185),
    ]) {
      canvas.drawRect(r, Paint()..color = const Color(0xFFF5F5F5));
      canvas.drawRect(r, wallStroke);
    }
    if (style.kind == FenestrationKind.door) {
      ArchitectDoor(
        id: 'preview',
        wallId: 'wall',
        offsetRatio: .5,
        uuid: 'preview',
        width: w,
        height: style.defaultHeight,
        sillHeight: style.defaultSillHeight,
        style: style,
      ).paint2D(
        canvas: canvas,
        wallStart: const Offset(-.6, 0),
        wallEnd: Offset(w + .6, 0),
        wallThickness: .37,
        zoomScale: scale,
        showAnnotations: dimensions,
      );
    } else {
      ArchitectWindow(
        id: 'preview',
        wallId: 'wall',
        offsetRatio: .5,
        uuid: 'preview',
        width: w,
        height: style.defaultHeight,
        sillHeight: style.defaultSillHeight,
        style: style,
      ).paint2D(
        canvas: canvas,
        wallStart: const Offset(-.6, 0),
        wallEnd: Offset(w + .6, 0),
        wallThickness: .37,
        coreThickness: .25,
        insulationThickness: .12,
        zoomScale: scale,
        showAnnotations: dimensions,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FenestrationPreviewPainter old) =>
      old.style != style ||
      old.mode != mode ||
      old.dimensions != dimensions ||
      old.selectedPaneId != selectedPaneId;
}
