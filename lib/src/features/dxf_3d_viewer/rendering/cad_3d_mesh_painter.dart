import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/mesh_3d.dart';
import 'cad_3d_camera.dart';

/// 3D Shading & Display Modes.
enum Cad3DShadingMode {
  cadShadedEdges('CAD Shaded + Edges', Icons.view_in_ar_rounded),
  smoothShaded('Smooth Shaded', Icons.lightbulb_outline_rounded),
  flatShaded('Flat Shaded', Icons.crop_portrait_rounded),
  wireframe('Wireframe', Icons.grid_3x3_rounded),
  xray('X-Ray (Transparent)', Icons.opacity_rounded);

  final String label;
  final IconData icon;

  const Cad3DShadingMode(this.label, this.icon);
}

/// Canvas Theme for 3D Viewport.
enum Cad3DTheme {
  darkCad('Dark CAD', Color(0xFF1E1E1E), Color(0xFF2E2E2E), Color(0xFF3B82F6)),
  blueprint('Blueprint', Color(0xFF0D253A), Color(0xFF194364), Color(0xFF38BDF8)),
  lightStudio('Light Studio', Color(0xFFF5F5F7), Color(0xFFE2E2E6), Color(0xFF2563EB)),
  pureBlack('Pure Black', Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF00E5FF)),
  pureWhite('Pure White', Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFF0284C7));

  final String label;
  final Color background;
  final Color gridColor;
  final Color defaultMeshColor;

  const Cad3DTheme(this.label, this.background, this.gridColor, this.defaultMeshColor);

  bool get isDark => background.computeLuminance() < 0.5;
}

/// Helper for depth-sorted triangles.
class _RenderTriangle {
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final double depth;
  final Color color;
  final bool isBackface;

  const _RenderTriangle({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.depth,
    required this.color,
    required this.isBackface,
  });
}

/// High-performance Flutter CustomPainter for 3D CAD mesh rendering.
class Cad3DMeshPainter extends CustomPainter {
  final Mesh3D mesh;
  final Cad3DCamera camera;
  final Cad3DShadingMode shadingMode;
  final Cad3DTheme theme;
  final bool showBoundingBox;
  final bool showGrid;
  final Color? customModelColor;
  final bool isInteracting;

  const Cad3DMeshPainter({
    required this.mesh,
    required this.camera,
    this.shadingMode = Cad3DShadingMode.smoothShaded,
    this.theme = Cad3DTheme.darkCad,
    this.showBoundingBox = false,
    this.showGrid = true,
    this.customModelColor,
    this.isInteracting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || mesh.triangles.isEmpty) return;

    final baseColor = customModelColor ?? theme.defaultMeshColor;
    final center = mesh.bounds.center;
    final maxDim = math.max(mesh.bounds.maxDimension, 1e-4);
    // Base fit scale: fit the model to ~55% of the viewport dimension
    final modelScale = (math.min(size.width, size.height) * 0.55) / maxDim;

    // 1. Draw 3D Ground Grid if enabled
    if (showGrid) {
      _drawGroundGrid(canvas, size, center, modelScale);
    }

    // 2. Transform, Light, and Depth-Sort Triangles
    // Professional 3-point Studio Lighting + Camera Headlight in View Space:
    // In view space, camera looks along +Y. Surfaces facing camera have norm.y <= 0.
    // Lights placed on camera side have Ly < 0, guaranteeing positive front illumination.
    final keyLight = const Vector3(0.55, -0.65, 0.52).normalized(); // Top-Right-Front
    final fillLight = const Vector3(-0.60, -0.45, 0.35).normalized(); // Top-Left-Front
    const headLight = Vector3(0.0, -1.0, 0.0); // Camera Headlight (view axis)
    final bounceLight = const Vector3(0.0, -0.30, -0.85).normalized(); // Ground Bounce

    // Blinn-Phong specular half-vector for key light (view direction V = (0, -1, 0))
    final keyHalf = (keyLight + const Vector3(0.0, -1.0, 0.0)).normalized();
    final List<_RenderTriangle> renderList = [];

    // Interactive adaptive LOD: when rotating/panning large models, stride for 60 FPS responsiveness
    final int totalTris = mesh.triangles.length;
    final int stride = (isInteracting && totalTris > 40000)
        ? (totalTris / 25000).ceil()
        : 1;

    final double screenW = size.width;
    final double screenH = size.height;
    const double margin = 50.0;

    for (int i = 0; i < totalTris; i += stride) {
      final tri = mesh.triangles[i];

      // Offset by model center so model rotates around its geometric centroid
      final v0Local = tri.v0 - center;
      final v1Local = tri.v1 - center;
      final v2Local = tri.v2 - center;

      // Transform to view coordinates
      final tv0 = camera.transformPoint(v0Local);
      final tv1 = camera.transformPoint(v1Local);
      final tv2 = camera.transformPoint(v2Local);

      // Fast view-space normal calculation
      final edge1 = tv1 - tv0;
      final edge2 = tv2 - tv0;
      final viewNormal = edge1.cross(edge2);
      final bool isBackface = viewNormal.y >= 0;

      // Backface Culling for closed solids in opaque shading modes
      if (isBackface &&
          !tri.isDoubleSided &&
          shadingMode != Cad3DShadingMode.wireframe &&
          shadingMode != Cad3DShadingMode.xray) {
        continue;
      }

      // Centroid depth in view space (larger Y is further away)
      final avgDepth = (tv0.y + tv1.y + tv2.y) / 3.0;

      // Project vertices to 2D screen coordinates
      final p0 = camera.projectToScreen(tv0, size, modelScale);
      final p1 = camera.projectToScreen(tv1, size, modelScale);
      final p2 = camera.projectToScreen(tv2, size, modelScale);

      // Viewport Frustum Culling: discard triangles completely outside the screen
      final minX = math.min(p0.dx, math.min(p1.dx, p2.dx));
      if (minX > screenW + margin) continue;
      final maxX = math.max(p0.dx, math.max(p1.dx, p2.dx));
      if (maxX < -margin) continue;
      final minY = math.min(p0.dy, math.min(p1.dy, p2.dy));
      if (minY > screenH + margin) continue;
      final maxY = math.max(p0.dy, math.max(p1.dy, p2.dy));
      if (maxY < -margin) continue;

      // Multi-source lighting calculation:
      // Determine effective normal facing toward the camera (two-sided lighting)
      final normLen = viewNormal.length;
      Vector3 norm = normLen > 1e-9 ? viewNormal / normLen : const Vector3(0, -1, 0);

      // If authored normal is present, utilize it for smooth shading
      if (tri.normal.lengthSquared > 1e-6) {
        final authNorm = camera.transformPoint(tri.normal).normalized();
        if (authNorm.lengthSquared > 0.5 && shadingMode == Cad3DShadingMode.smoothShaded) {
          norm = authNorm;
        }
      }

      // Ensure normal faces camera so both sides of thin geometry (e.g. roofs, wings) are lit
      if (norm.y > 0) {
        norm = -norm;
      }

      // Diffuse Lambertian terms (norm.y <= 0 and L.y < 0 => positive illumination)
      final double diffKey = math.max(0.0, norm.dot(keyLight));
      final double diffFill = math.max(0.0, norm.dot(fillLight));
      final double diffHead = math.max(0.0, norm.dot(headLight));
      final double diffBounce = math.max(0.0, norm.dot(bounceLight));

      const double ambient = 0.22;
      final double diffuseFactor = (ambient +
          diffKey * 0.45 +
          diffFill * 0.22 +
          diffHead * 0.25 +
          diffBounce * 0.12).clamp(0.20, 1.15);

      // Blinn-Phong Specular Highlights
      double specTotal = 0.0;
      if (shadingMode != Cad3DShadingMode.xray && shadingMode != Cad3DShadingMode.wireframe) {
        final double specKey = math.max(0.0, norm.dot(keyHalf));
        final double specHead = math.max(0.0, -norm.y);
        final double keyHighlight = math.pow(specKey, 20.0).toDouble() * 0.38;
        final double headHighlight = math.pow(specHead, 45.0).toDouble() * 0.16;
        specTotal = keyHighlight + headHighlight;
      }

      final effectiveColor = customModelColor ?? tri.color ?? baseColor;
      Color faceColor;
      if (shadingMode == Cad3DShadingMode.xray) {
        faceColor = effectiveColor.withValues(alpha: 0.25);
      } else if (shadingMode == Cad3DShadingMode.wireframe) {
        faceColor = Colors.transparent;
      } else {
        final double rLit = (effectiveColor.r * diffuseFactor + specTotal).clamp(0.0, 1.0);
        final double gLit = (effectiveColor.g * diffuseFactor + specTotal).clamp(0.0, 1.0);
        final double bLit = (effectiveColor.b * diffuseFactor + specTotal).clamp(0.0, 1.0);
        faceColor = Color.from(
          alpha: effectiveColor.a,
          red: rLit,
          green: gLit,
          blue: bLit,
        );
      }

      renderList.add(_RenderTriangle(
        p0: p0,
        p1: p1,
        p2: p2,
        depth: avgDepth,
        color: faceColor,
        isBackface: isBackface,
      ));
    }

    // Depth Sorting (Back to Front: largest depth first)
    renderList.sort((a, b) => b.depth.compareTo(a.depth));

    // 3. Render Triangles (GPU Batched drawVertices or Path)
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    final bool drawEdges = shadingMode == Cad3DShadingMode.cadShadedEdges ||
        shadingMode == Cad3DShadingMode.wireframe ||
        shadingMode == Cad3DShadingMode.xray;

    if (shadingMode == Cad3DShadingMode.wireframe) {
      edgePaint.color = baseColor;
    } else if (theme.isDark) {
      edgePaint.color = Colors.white.withValues(alpha: 0.22);
    } else {
      edgePaint.color = Colors.black.withValues(alpha: 0.25);
    }

    if (!drawEdges && shadingMode != Cad3DShadingMode.wireframe) {
      // GPU Batched Rendering via Canvas.drawVertices in chunks of up to 10,000 triangles
      const int batchSize = 10000;
      final positions = <Offset>[];
      final colors = <Color>[];

      for (int i = 0; i < renderList.length; i++) {
        final tri = renderList[i];
        positions.add(tri.p0);
        positions.add(tri.p1);
        positions.add(tri.p2);
        colors.add(tri.color);
        colors.add(tri.color);
        colors.add(tri.color);

        if ((i + 1) % batchSize == 0 || i == renderList.length - 1) {
          final vertices = ui.Vertices(
            ui.VertexMode.triangles,
            positions,
            colors: colors,
          );
          canvas.drawVertices(vertices, BlendMode.srcOver, fillPaint);
          positions.clear();
          colors.clear();
        }
      }
    } else {
      // Fallback for modes requiring edge outlines, wireframe, or x-ray
      for (final tri in renderList) {
        final path = Path()
          ..moveTo(tri.p0.dx, tri.p0.dy)
          ..lineTo(tri.p1.dx, tri.p1.dy)
          ..lineTo(tri.p2.dx, tri.p2.dy)
          ..close();

        if (shadingMode != Cad3DShadingMode.wireframe) {
          fillPaint.color = tri.color;
          canvas.drawPath(path, fillPaint);
        }

        if (drawEdges) {
          canvas.drawPath(path, edgePaint);
        }
      }
    }

    // 4. Draw 3D Bounding Box Dimensions Cage if enabled
    if (showBoundingBox) {
      _drawBoundingBox(canvas, size, center, modelScale);
    }

    // 5. Draw 3D Orientation XYZ Axis Gizmo in corner
    _drawOrientationGizmo(canvas, size);
  }

  void _drawGroundGrid(Canvas canvas, Size size, Vector3 center, double modelScale) {
    final gridPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    final double gridSize = mesh.bounds.maxDimension * 1.5;
    final double zBottom = mesh.bounds.min.z - center.z;
    const int lines = 10;
    final double step = gridSize / lines;

    for (int i = -lines; i <= lines; i++) {
      final p1 = camera.projectToScreen(
        camera.transformPoint(Vector3(i * step, -gridSize, zBottom)),
        size,
        modelScale,
      );
      final p2 = camera.projectToScreen(
        camera.transformPoint(Vector3(i * step, gridSize, zBottom)),
        size,
        modelScale,
      );
      canvas.drawLine(p1, p2, gridPaint);

      final p3 = camera.projectToScreen(
        camera.transformPoint(Vector3(-gridSize, i * step, zBottom)),
        size,
        modelScale,
      );
      final p4 = camera.projectToScreen(
        camera.transformPoint(Vector3(gridSize, i * step, zBottom)),
        size,
        modelScale,
      );
      canvas.drawLine(p3, p4, gridPaint);
    }
  }

  void _drawBoundingBox(Canvas canvas, Size size, Vector3 center, double modelScale) {
    final min = mesh.bounds.min - center;
    final max = mesh.bounds.max - center;

    // 8 vertices of the bounding box
    final corners = [
      Vector3(min.x, min.y, min.z), // 0
      Vector3(max.x, min.y, min.z), // 1
      Vector3(max.x, max.y, min.z), // 2
      Vector3(min.x, max.y, min.z), // 3
      Vector3(min.x, min.y, max.z), // 4
      Vector3(max.x, min.y, max.z), // 5
      Vector3(max.x, max.y, max.z), // 6
      Vector3(min.x, max.y, max.z), // 7
    ];

    final projected = corners
        .map((v) => camera.projectToScreen(camera.transformPoint(v), size, modelScale))
        .toList();

    final boxPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 12 edges
    const edges = [
      [0, 1], [1, 2], [2, 3], [3, 0], // Bottom
      [4, 5], [5, 6], [6, 7], [7, 4], // Top
      [0, 4], [1, 5], [2, 6], [3, 7], // Vertical
    ];

    for (final edge in edges) {
      canvas.drawLine(projected[edge[0]], projected[edge[1]], boxPaint);
    }
  }

  void _drawOrientationGizmo(Canvas canvas, Size size) {
    const double gizmoRadius = 36.0;
    final gizmoCenter = Offset(48.0, size.height - 48.0);

    // Coordinate unit vectors
    final xAxis = camera.transformPoint(const Vector3(1.0, 0.0, 0.0));
    final yAxis = camera.transformPoint(const Vector3(0.0, 1.0, 0.0));
    final zAxis = camera.transformPoint(const Vector3(0.0, 0.0, 1.0));

    void drawAxis(Vector3 v, Color color, String label) {
      final p = Offset(
        gizmoCenter.dx + v.x * gizmoRadius,
        gizmoCenter.dy - v.z * gizmoRadius,
      );

      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(gizmoCenter, p, paint);
      canvas.drawCircle(p, 3.5, Paint()..color = color..style = PaintingStyle.fill);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(p.dx + (v.x >= 0 ? 4 : -12), p.dy + (v.z >= 0 ? -12 : 4)),
      );
    }

    // Background circle
    canvas.drawCircle(
      gizmoCenter,
      gizmoRadius + 10,
      Paint()..color = theme.background.withValues(alpha: 0.8)..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      gizmoCenter,
      gizmoRadius + 10,
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Draw Axes (X: Red, Y: Green, Z: Blue)
    drawAxis(xAxis, const Color(0xFFEF4444), 'X');
    drawAxis(yAxis, const Color(0xFF10B981), 'Y');
    drawAxis(zAxis, const Color(0xFF3B82F6), 'Z');
  }

  @override
  bool shouldRepaint(covariant Cad3DMeshPainter oldDelegate) {
    return true;
  }
}
