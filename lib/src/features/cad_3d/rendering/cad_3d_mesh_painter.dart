import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/mesh_3d.dart';
import 'cad_3d_camera.dart';
import 'cad_3d_feature_edges.dart';

/// 3D Shading & Display Modes.
enum Cad3DShadingMode {
  cadShadedEdges(Icons.view_in_ar_rounded),
  smoothShaded(Icons.lightbulb_outline_rounded),
  flatShaded(Icons.crop_portrait_rounded),
  wireframe(Icons.grid_3x3_rounded),
  xray(Icons.opacity_rounded);

  final IconData icon;

  const Cad3DShadingMode(this.icon);
}

/// Canvas Theme for 3D Viewport.
enum Cad3DTheme {
  darkCad(Color(0xFF1E1E1E), Color(0xFF2E2E2E), Color(0xFF3B82F6)),
  blueprint(Color(0xFF0D253A), Color(0xFF194364), Color(0xFF38BDF8)),
  lightStudio(Color(0xFFF5F5F7), Color(0xFFE2E2E6), Color(0xFF2563EB)),
  pureBlack(Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF00E5FF)),
  pureWhite(Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFF0284C7));

  final Color background;
  final Color gridColor;
  final Color defaultMeshColor;

  const Cad3DTheme(this.background, this.gridColor, this.defaultMeshColor);

  bool get isDark => background.computeLuminance() < 0.5;
}

/// Helper for depth-sorted triangles.
class _RenderTriangle {
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final double depth;
  final Color color;
  final int edgeMask;
  final MeshTextureBinding? texture;
  final List<Offset>? uvs;
  final List<Color>? vertexColors;
  final String alphaMode;

  const _RenderTriangle({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.depth,
    required this.color,
    this.edgeMask = 7,
    this.texture,
    this.uvs,
    this.vertexColors,
    this.alphaMode = 'OPAQUE',
  });
}

/// High-performance Flutter CustomPainter for 3D CAD mesh rendering.
class Cad3DMeshPainter extends CustomPainter {
  final Mesh3D mesh;
  final Cad3DCamera camera;
  final Cad3DShadingMode shadingMode;
  final Cad3DTheme theme;
  final bool showGrid;
  final Color? customModelColor;
  final bool isInteracting;
  final ui.Image? gpuImage;
  final bool overlayOnly;
  final Map<MeshTexture, ui.Image> textureImages;

  const Cad3DMeshPainter({
    required this.mesh,
    required this.camera,
    this.shadingMode = Cad3DShadingMode.smoothShaded,
    this.theme = Cad3DTheme.darkCad,
    this.showGrid = true,
    this.customModelColor,
    this.isInteracting = false,
    this.gpuImage,
    this.overlayOnly = false,
    this.textureImages = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        mesh.triangles.isEmpty ||
        !camera.yaw.isFinite ||
        !camera.pitch.isFinite ||
        !camera.zoom.isFinite ||
        !_isDrawablePoint(camera.panOffset) ||
        (camera.isFlyMode && !_isFiniteVector(camera.eyePosition))) {
      return;
    }
    if (overlayOnly) {
      _drawOrientationGizmo(canvas, size);
      return;
    }

    final baseColor = customModelColor ?? theme.defaultMeshColor;
    final center = mesh.bounds.center;
    final maxDim = math.max(mesh.bounds.maxDimension, 1e-4);
    if (!_isFiniteVector(center) || !maxDim.isFinite) return;
    // Base fit scale: fit the model to ~55% of the viewport dimension
    final modelScale = (math.min(size.width, size.height) * 0.55) / maxDim;
    if (!modelScale.isFinite || modelScale <= 0) return;

    // 1. Draw 3D Ground Grid if enabled
    if (showGrid) {
      _drawGroundGrid(canvas, size, center, modelScale);
    }

    // Present the native software depth-buffered fallback frame when ready.
    if (gpuImage != null) {
      canvas.drawImageRect(
        gpuImage!,
        Rect.fromLTWH(
          0,
          0,
          gpuImage!.width.toDouble(),
          gpuImage!.height.toDouble(),
        ),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
      _drawOrientationGizmo(canvas, size);
      return;
    }

    // 2. Transform, Light, and Depth-Sort Triangles
    // Professional 3-point Studio Lighting + Camera Headlight in View Space:
    // In view space, camera looks along +Y. Surfaces facing camera have norm.y <= 0.
    // Lights placed on camera side have Ly < 0, guaranteeing positive front illumination.
    final keyLight = const Vector3(
      0.55,
      -0.65,
      0.52,
    ).normalized(); // Top-Right-Front
    final fillLight = const Vector3(
      -0.60,
      -0.45,
      0.35,
    ).normalized(); // Top-Left-Front
    const headLight = Vector3(0.0, -1.0, 0.0); // Camera Headlight (view axis)
    final bounceLight = const Vector3(
      0.0,
      -0.30,
      -0.85,
    ).normalized(); // Ground Bounce

    // Blinn-Phong specular half-vector for key light (view direction V = (0, -1, 0))
    final keyHalf = (keyLight + const Vector3(0.0, -1.0, 0.0)).normalized();
    final List<_RenderTriangle> renderList = [];

    // Retrieve display triangles (with hierarchical element group frustum culling when groups are present)
    final displayTriangles = _getActiveDisplayTriangles(
      mesh,
      center,
      size,
      modelScale,
      margin: 50.0,
    );
    final featureEdges = shadingMode == Cad3DShadingMode.cadShadedEdges
        ? Cad3DFeatureEdges.masks(
            mesh.groups?.isNotEmpty == true
                ? mesh.triangles
                : _getDisplayTriangles(mesh),
            maxDim,
          )
        : null;
    final int totalTris = displayTriangles.length;
    const int stride = 1;

    final double screenW = size.width;
    final double screenH = size.height;
    const double margin = 50.0;

    for (int i = 0; i < totalTris; i += stride) {
      final tri = displayTriangles[i];
      if (!_hasFiniteVertices(tri)) continue;

      // Offset by model center so model rotates around its geometric centroid
      final v0Local = tri.v0 - center;
      final v1Local = tri.v1 - center;
      final v2Local = tri.v2 - center;

      // Transform to view coordinates
      final tv0 = camera.transformVertex(v0Local);
      final tv1 = camera.transformVertex(v1Local);
      final tv2 = camera.transformVertex(v2Local);
      if (!_isFiniteVector(tv0) ||
          !_isFiniteVector(tv1) ||
          !_isFiniteVector(tv2)) {
        continue;
      }

      // Human-scale near plane (~15-20cm, 12.0 screen units ahead of eye):
      // Only discard triangle if ALL three vertices are completely behind the human eye
      if (camera.isFlyMode) {
        final double nearPlane = (-camera.cameraDist + 12.0) / modelScale;
        if (tv0.y <= nearPlane && tv1.y <= nearPlane && tv2.y <= nearPlane) {
          continue;
        }
      }

      // Project vertices to 2D screen coordinates
      final p0 = camera.projectToScreen(tv0, size, modelScale);
      final p1 = camera.projectToScreen(tv1, size, modelScale);
      final p2 = camera.projectToScreen(tv2, size, modelScale);
      // Canvas vertices are encoded as float32. Reject invalid projections
      // before culling: comparisons with NaN would otherwise let them through.
      if (!_isDrawablePoint(p0) ||
          !_isDrawablePoint(p1) ||
          !_isDrawablePoint(p2)) {
        continue;
      }

      // Viewport Frustum Culling: discard triangles completely outside the screen
      final minX = math.min(p0.dx, math.min(p1.dx, p2.dx));
      if (minX > screenW + margin) continue;
      final maxX = math.max(p0.dx, math.max(p1.dx, p2.dx));
      if (maxX < -margin) continue;
      final minY = math.min(p0.dy, math.min(p1.dy, p2.dy));
      if (minY > screenH + margin) continue;
      final maxY = math.max(p0.dy, math.max(p1.dy, p2.dy));
      if (maxY < -margin) continue;

      // Perspective-accurate 2D screen backface culling:
      // In Flutter canvas space (X right, Y down where screenY = centerY - sz*scale),
      // front-facing triangles have cross2d < 0, and back-facing triangles have cross2d >= 0.
      final cross2d =
          (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);
      final bool isBackface = cross2d >= 0;
      final bool isTransparent = (tri.color != null && tri.color!.a < 0.99);

      // Backface Culling for closed solids in opaque shading modes
      if (isBackface &&
          !tri.isDoubleSided &&
          !isTransparent &&
          shadingMode != Cad3DShadingMode.wireframe &&
          shadingMode != Cad3DShadingMode.xray) {
        continue;
      }
      // Fast view-space normal calculation for lighting
      final edge1 = tv1 - tv0;
      final edge2 = tv2 - tv0;
      final viewNormal = edge1.cross(edge2);

      // Centroid and boundary depth in view space (larger Y is further away).
      // Blending the centroid depth with the maximum depth prevents background surfaces
      // (like pitched roof slopes or exterior walls) from falsely sorting in front of interior elements.
      final avgDepth = (tv0.y + tv1.y + tv2.y) / 3.0;
      final maxDepth = math.max(tv0.y, math.max(tv1.y, tv2.y));

      // Scale-aware depth bias:
      // Depth in camera space increases with distance (+Y is away from camera).
      // A small positive bias brings thin finishing surfaces, cladding, and decals
      // slightly forward in depth sorting relative to their backing walls.
      // Scaling by maxDim * 0.0015 ensures uniform depth offset regardless of model units (mm, m, in).
      final double scaledBias = tri.depthBias > 0.0
          ? (tri.depthBias >= 10.0 ? 1.0 : tri.depthBias) * (maxDim * 0.0015)
          : 0.0;
      final depth = (avgDepth * 0.65 + maxDepth * 0.35) - scaledBias;

      // Multi-source lighting calculation:
      // Determine effective normal facing toward the camera (two-sided lighting)
      final normLen = viewNormal.length;
      Vector3 norm = normLen > 1e-9
          ? viewNormal / normLen
          : const Vector3(0, -1, 0);

      // If authored normal is present, utilize it for smooth shading
      if (tri.normal.lengthSquared > 1e-6) {
        final authNorm = camera.transformPoint(tri.normal).normalized();
        if (authNorm.lengthSquared > 0.5 &&
            shadingMode == Cad3DShadingMode.smoothShaded) {
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
      final double diffuseFactor =
          (ambient +
                  diffKey * 0.45 +
                  diffFill * 0.22 +
                  diffHead * 0.25 +
                  diffBounce * 0.12)
              .clamp(0.20, 1.15);

      // Blinn-Phong Specular Highlights
      double specTotal = 0.0;
      if (shadingMode != Cad3DShadingMode.xray &&
          shadingMode != Cad3DShadingMode.wireframe) {
        final double specKey = math.max(0.0, norm.dot(keyHalf));
        final double specHead = math.max(0.0, -norm.y);
        final double keyHighlight = math.pow(specKey, 20.0).toDouble() * 0.38;
        final double headHighlight = math.pow(specHead, 45.0).toDouble() * 0.16;
        specTotal = keyHighlight + headHighlight;
      }

      final effectiveColor = customModelColor ?? tri.color ?? baseColor;
      Color shade(Color color) {
        if (shadingMode == Cad3DShadingMode.xray) {
          return color.withValues(alpha: 0.25);
        }
        if (shadingMode == Cad3DShadingMode.wireframe) {
          return Colors.transparent;
        }
        if (tri.material?.unlit == true && customModelColor == null) {
          return color;
        }
        final double rLit = (color.r * diffuseFactor + specTotal).clamp(
          0.0,
          1.0,
        );
        final double gLit = (color.g * diffuseFactor + specTotal).clamp(
          0.0,
          1.0,
        );
        final double bLit = (color.b * diffuseFactor + specTotal).clamp(
          0.0,
          1.0,
        );
        return Color.from(alpha: color.a, red: rLit, green: gLit, blue: bLit);
      }

      renderList.add(
        _RenderTriangle(
          p0: p0,
          p1: p1,
          p2: p2,
          depth: depth,
          color: shade(effectiveColor),
          alphaMode: tri.material?.alphaMode ?? 'OPAQUE',
          vertexColors: customModelColor == null
              ? tri.vertexColors?.map(shade).toList()
              : null,
          edgeMask: featureEdges?[tri] ?? 7,
          texture:
              customModelColor == null &&
                  shadingMode != Cad3DShadingMode.xray &&
                  shadingMode != Cad3DShadingMode.wireframe
              ? tri.material?.baseColorTexture
              : null,
          uvs: tri.textureCoordinates[tri.material?.baseColorTexture?.texCoord],
        ),
      );
    }

    // Depth Sorting (Back to Front: largest depth first)
    renderList.sort((a, b) => b.depth.compareTo(a.depth));

    // 3. Render Triangles (GPU Batched drawVertices or Path)
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    final bool drawEdges =
        shadingMode == Cad3DShadingMode.cadShadedEdges ||
        shadingMode == Cad3DShadingMode.wireframe ||
        shadingMode == Cad3DShadingMode.xray;

    if (shadingMode == Cad3DShadingMode.wireframe) {
      edgePaint.color = baseColor;
    } else if (theme.isDark) {
      edgePaint.color = Colors.white.withValues(alpha: 0.22);
    } else {
      edgePaint.color = Colors.black.withValues(alpha: 0.25);
    }

    final hasTextures = renderList.any(
      (t) => textureImages.containsKey(t.texture?.texture),
    );
    final shaders = <MeshTexture, ui.ImageShader>{};
    bool drawTexture(_RenderTriangle tri) {
      final binding = tri.texture;
      final image = textureImages[binding?.texture];
      final uvs = tri.uvs;
      if (binding == null || image == null || uvs == null || uvs.length != 3) {
        return false;
      }
      ui.TileMode tileMode(int wrap) => switch (wrap) {
        33071 => ui.TileMode.clamp,
        33648 => ui.TileMode.mirror,
        _ => ui.TileMode.repeated,
      };
      final shader = shaders.putIfAbsent(
        binding.texture,
        () => ui.ImageShader(
          image,
          tileMode(binding.texture.wrapS),
          tileMode(binding.texture.wrapT),
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
          filterQuality: binding.texture.magFilter == 9728
              ? FilterQuality.none
              : FilterQuality.low,
        ),
      );
      final cos = math.cos(binding.rotation), sin = math.sin(binding.rotation);
      final mapped = [
        for (final uv in uvs)
          Offset(
            (binding.offset.dx +
                    cos * uv.dx * binding.scale.dx -
                    sin * uv.dy * binding.scale.dy) *
                image.width,
            (binding.offset.dy +
                    sin * uv.dx * binding.scale.dx +
                    cos * uv.dy * binding.scale.dy) *
                image.height,
          ),
      ];
      // Fall back to the face color when UV data or its transform is invalid.
      if (!mapped.every(_isDrawablePoint)) return false;
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        [tri.p0, tri.p1, tri.p2],
        textureCoordinates: mapped,
        colors: tri.vertexColors ?? [tri.color, tri.color, tri.color],
      );
      final paint = Paint()..shader = shader;
      if (tri.alphaMode == 'OPAQUE') {
        // OPAQUE glTF materials ignore texture alpha, even for PNG images.
        paint.colorFilter = const ColorFilter.matrix([
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          0,
          255,
        ]);
      }
      canvas.drawVertices(vertices, BlendMode.modulate, paint);
      vertices.dispose();
      return true;
    }

    if (!hasTextures &&
        !drawEdges &&
        shadingMode != Cad3DShadingMode.wireframe) {
      // GPU Batched Rendering via Canvas.drawVertices in chunks of up to 10,000 triangles
      const int batchSize = 10000;
      final positions = <Offset>[];
      final colors = <Color>[];

      for (int i = 0; i < renderList.length; i++) {
        final tri = renderList[i];
        positions.add(tri.p0);
        positions.add(tri.p1);
        positions.add(tri.p2);
        colors.addAll(tri.vertexColors ?? [tri.color, tri.color, tri.color]);

        if ((i + 1) % batchSize == 0 || i == renderList.length - 1) {
          final vertices = ui.Vertices(
            ui.VertexMode.triangles,
            positions,
            colors: colors,
          );
          canvas.drawVertices(vertices, BlendMode.srcOver, fillPaint);
          vertices.dispose();
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
          if (!drawTexture(tri)) {
            if (tri.vertexColors != null) {
              final vertices = ui.Vertices(ui.VertexMode.triangles, [
                tri.p0,
                tri.p1,
                tri.p2,
              ], colors: tri.vertexColors);
              canvas.drawVertices(vertices, BlendMode.srcOver, fillPaint);
              vertices.dispose();
            } else {
              fillPaint.color = tri.color;
              canvas.drawPath(path, fillPaint);
            }
          }
        }

        if (drawEdges) {
          final edges = Path();
          if ((tri.edgeMask & 1) != 0) {
            edges.moveTo(tri.p0.dx, tri.p0.dy);
            edges.lineTo(tri.p1.dx, tri.p1.dy);
          }
          if ((tri.edgeMask & 2) != 0) {
            edges.moveTo(tri.p1.dx, tri.p1.dy);
            edges.lineTo(tri.p2.dx, tri.p2.dy);
          }
          if ((tri.edgeMask & 4) != 0) {
            edges.moveTo(tri.p2.dx, tri.p2.dy);
            edges.lineTo(tri.p0.dx, tri.p0.dy);
          }
          canvas.drawPath(edges, edgePaint);
        }
      }
    }

    for (final shader in shaders.values) {
      shader.dispose();
    }

    // 4. Draw 3D Orientation XYZ Axis Gizmo in corner
    _drawOrientationGizmo(canvas, size);
  }

  void _drawGroundGrid(
    Canvas canvas,
    Size size,
    Vector3 center,
    double modelScale,
  ) {
    final gridPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    final double gridSize = mesh.bounds.maxDimension * 1.5;
    final double zBottom = mesh.bounds.min.z - center.z;
    const int lines = 10;
    final double step = gridSize / lines;

    final double nearPlane = -1188.0 / modelScale;
    for (int i = -lines; i <= lines; i++) {
      final tv1 = camera.transformVertex(Vector3(i * step, -gridSize, zBottom));
      final tv2 = camera.transformVertex(Vector3(i * step, gridSize, zBottom));
      if (!camera.isFlyMode || (tv1.y > nearPlane && tv2.y > nearPlane)) {
        final p1 = camera.projectToScreen(tv1, size, modelScale);
        final p2 = camera.projectToScreen(tv2, size, modelScale);
        if (_isDrawablePoint(p1) && _isDrawablePoint(p2)) {
          canvas.drawLine(p1, p2, gridPaint);
        }
      }

      final tv3 = camera.transformVertex(Vector3(-gridSize, i * step, zBottom));
      final tv4 = camera.transformVertex(Vector3(gridSize, i * step, zBottom));
      if (!camera.isFlyMode || (tv3.y > nearPlane && tv4.y > nearPlane)) {
        final p3 = camera.projectToScreen(tv3, size, modelScale);
        final p4 = camera.projectToScreen(tv4, size, modelScale);
        if (_isDrawablePoint(p3) && _isDrawablePoint(p4)) {
          canvas.drawLine(p3, p4, gridPaint);
        }
      }
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
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

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
      Paint()
        ..color = theme.background.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill,
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

  static final Expando<List<Triangle3D>> _subdivisionCache =
      Expando<List<Triangle3D>>();

  static bool _isFiniteVector(Vector3 v) =>
      v.x.isFinite && v.y.isFinite && v.z.isFinite;

  static bool _hasFiniteVertices(Triangle3D t) =>
      _isFiniteVector(t.v0) && _isFiniteVector(t.v1) && _isFiniteVector(t.v2);

  static bool _isDrawablePoint(Offset p) {
    const maxFloat32 = 3.4028234663852886e38;
    return p.dx.isFinite &&
        p.dy.isFinite &&
        p.dx.abs() <= maxFloat32 &&
        p.dy.abs() <= maxFloat32;
  }

  static final Expando<List<Triangle3D>> _textureSubdivisionCache =
      Expando<List<Triangle3D>>();

  static List<Triangle3D> _getDisplayTriangles(Mesh3D mesh) {
    final cached = _subdivisionCache[mesh];
    if (cached != null) return cached;

    if (mesh.triangles.isEmpty) {
      _subdivisionCache[mesh] = mesh.triangles;
      return mesh.triangles;
    }

    final double maxDim = math.max(mesh.bounds.maxDimension, 1e-4);
    // Adaptive threshold: a triangle is considered large if its edge exceeds ~15% of model size,
    // capped at 1200mm for millimeter-scale architectural models (e.g. big walls, roofs, slabs).
    final double threshold = math.min(1000.0, maxDim * 0.15);
    final double maxEdgeLen = math.min(600.0, maxDim * 0.08);

    final double thresholdSq = threshold * threshold;
    bool hasLarge = false;
    int largeCount = 0;
    for (final t in mesh.triangles) {
      if ((t.v1 - t.v0).lengthSquared > thresholdSq ||
          (t.v2 - t.v1).lengthSquared > thresholdSq ||
          (t.v0 - t.v2).lengthSquared > thresholdSq) {
        hasLarge = true;
        largeCount++;
      }
    }

    if (!hasLarge) {
      _subdivisionCache[mesh] = mesh.triangles;
      debugPrint(
        '[Cad3D] Mesh "${mesh.name}" (${mesh.triangles.length} tris): No large triangles > ${threshold.toStringAsFixed(0)}mm. Subdivision skipped.',
      );
      return mesh.triangles;
    }

    final sw = Stopwatch()..start();
    final subdivided = _subdivideTris(mesh.triangles, maxEdgeLen);
    sw.stop();
    debugPrint(
      '[Cad3D] Subdivided $largeCount large triangles (> ${threshold.toStringAsFixed(0)}mm) '
      'in "${mesh.name}": ${mesh.triangles.length} -> ${subdivided.length} triangles in ${sw.elapsedMilliseconds}ms',
    );

    _subdivisionCache[mesh] = subdivided;
    return subdivided;
  }

  static List<Triangle3D> _subdivideTris(
    List<Triangle3D> tris,
    double maxEdgeLen,
  ) {
    final result = <Triangle3D>[];
    final maxEdgeLenSq = maxEdgeLen * maxEdgeLen;
    for (final tri in tris) {
      _subdivideSingle(tri, maxEdgeLenSq, 0, result);
    }
    return result;
  }

  static void _subdivideSingle(
    Triangle3D tri,
    double maxEdgeLenSq,
    int depth,
    List<Triangle3D> out,
  ) {
    if (!_hasFiniteVertices(tri)) return;
    if (depth >= 5) {
      out.add(tri);
      return;
    }
    final e01 = (tri.v1 - tri.v0).lengthSquared;
    final e12 = (tri.v2 - tri.v1).lengthSquared;
    final e20 = (tri.v0 - tri.v2).lengthSquared;
    if (e01 <= maxEdgeLenSq && e12 <= maxEdgeLenSq && e20 <= maxEdgeLenSq) {
      out.add(tri);
      return;
    }
    if (tri.textureCoordinates.isNotEmpty ||
        tri.material != null ||
        tri.vertexNormals != null ||
        tri.vertexColors != null) {
      const a = Vector3(1, 0, 0), b = Vector3(0, 1, 0), c = Vector3(0, 0, 1);
      final (left, right) = e01 >= e12 && e01 >= e20
          ? ([a, (a + b) * .5, c], [(a + b) * .5, b, c])
          : e12 >= e01 && e12 >= e20
          ? ([a, b, (b + c) * .5], [a, (b + c) * .5, c])
          : ([a, b, (c + a) * .5], [(c + a) * .5, b, c]);
      _subdivideSingle(
        _interpolatedPart(tri, left),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
      _subdivideSingle(
        _interpolatedPart(tri, right),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
      return;
    }
    if (e01 >= e12 && e01 >= e20) {
      final mid = (tri.v0 + tri.v1) * 0.5;
      _subdivideSingle(
        Triangle3D(
          v0: tri.v0,
          v1: mid,
          v2: tri.v2,
          color: tri.color,
          isDoubleSided: tri.isDoubleSided,
          normal: tri.normal,
          depthBias: tri.depthBias,
        ),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
      _subdivideSingle(
        Triangle3D(
          v0: mid,
          v1: tri.v1,
          v2: tri.v2,
          color: tri.color,
          isDoubleSided: tri.isDoubleSided,
          normal: tri.normal,
          depthBias: tri.depthBias,
        ),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
    } else if (e12 >= e01 && e12 >= e20) {
      final mid = (tri.v1 + tri.v2) * 0.5;
      _subdivideSingle(
        Triangle3D(
          v0: tri.v0,
          v1: tri.v1,
          v2: mid,
          color: tri.color,
          isDoubleSided: tri.isDoubleSided,
          normal: tri.normal,
          depthBias: tri.depthBias,
        ),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
      _subdivideSingle(
        Triangle3D(
          v0: tri.v0,
          v1: mid,
          v2: tri.v2,
          color: tri.color,
          isDoubleSided: tri.isDoubleSided,
          normal: tri.normal,
          depthBias: tri.depthBias,
        ),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
    } else {
      final mid = (tri.v2 + tri.v0) * 0.5;
      _subdivideSingle(
        Triangle3D(
          v0: tri.v0,
          v1: tri.v1,
          v2: mid,
          color: tri.color,
          isDoubleSided: tri.isDoubleSided,
          normal: tri.normal,
          depthBias: tri.depthBias,
        ),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
      _subdivideSingle(
        Triangle3D(
          v0: mid,
          v1: tri.v1,
          v2: tri.v2,
          color: tri.color,
          isDoubleSided: tri.isDoubleSided,
          normal: tri.normal,
          depthBias: tri.depthBias,
        ),
        maxEdgeLenSq,
        depth + 1,
        out,
      );
    }
  }

  static Triangle3D _interpolatedPart(Triangle3D t, List<Vector3> weights) {
    Vector3 vector(List<Vector3> values, Vector3 w) =>
        values[0] * w.x + values[1] * w.y + values[2] * w.z;
    final points = [
      for (final w in weights) vector([t.v0, t.v1, t.v2], w),
    ];
    List<List<double>> interpolate(List<List<double>> values) => [
      for (final w in weights)
        [
          for (var i = 0; i < 4; i++)
            values[0][i] * w.x + values[1][i] * w.y + values[2][i] * w.z,
        ],
    ];
    final colorValues = t.vertexColors == null
        ? null
        : interpolate([
            for (final c in t.vertexColors!) [c.r, c.g, c.b, c.a],
          ]);
    return Triangle3D(
      v0: points[0],
      v1: points[1],
      v2: points[2],
      normal: t.normal,
      color: t.color,
      isDoubleSided: t.isDoubleSided,
      depthBias: t.depthBias,
      material: t.material,
      vertexNormals: t.vertexNormals == null
          ? null
          : [for (final w in weights) vector(t.vertexNormals!, w).normalized()],
      vertexColors: colorValues == null
          ? null
          : [
              for (final c in colorValues)
                Color.from(red: c[0], green: c[1], blue: c[2], alpha: c[3]),
            ],
      linearVertexColors: t.linearVertexColors == null
          ? null
          : interpolate(t.linearVertexColors!),
      textureCoordinates: {
        for (final entry in t.textureCoordinates.entries)
          entry.key: [
            for (final w in weights)
              entry.value[0] * w.x +
                  entry.value[1] * w.y +
                  entry.value[2] * w.z,
          ],
      },
    );
  }

  List<Triangle3D> _getActiveDisplayTriangles(
    Mesh3D mesh,
    Vector3 center,
    Size size,
    double modelScale, {
    double margin = 50.0,
  }) {
    if (mesh.groups != null && mesh.groups!.isNotEmpty) {
      final active = <Triangle3D>[];
      for (final group in mesh.groups!) {
        if (_isBoxVisible(
          group.bounds,
          center,
          camera,
          size,
          modelScale,
          margin,
        )) {
          final textured =
              textureImages.isNotEmpty &&
              (shadingMode == Cad3DShadingMode.smoothShaded ||
                  shadingMode == Cad3DShadingMode.flatShaded) &&
              group.triangles.any((t) => t.material?.baseColorTexture != null);
          active.addAll(
            textured
                ? _textureSubdivisionCache[group] ??= _subdivideTris(
                    group.triangles,
                    math.max(mesh.bounds.maxDimension, 1e-4) * .08,
                  )
                : group.triangles,
          );
        }
      }
      return active;
    }
    return _getDisplayTriangles(mesh);
  }

  static bool _isBoxVisible(
    BoundingBox3D b,
    Vector3 center,
    Cad3DCamera camera,
    Size size,
    double modelScale,
    double margin,
  ) {
    final corners = [
      Vector3(b.min.x, b.min.y, b.min.z),
      Vector3(b.max.x, b.min.y, b.min.z),
      Vector3(b.min.x, b.max.y, b.min.z),
      Vector3(b.max.x, b.max.y, b.min.z),
      Vector3(b.min.x, b.min.y, b.max.z),
      Vector3(b.max.x, b.min.y, b.max.z),
      Vector3(b.min.x, b.max.y, b.max.z),
      Vector3(b.max.x, b.max.y, b.max.z),
    ];

    double minScreenX = double.infinity, maxScreenX = -double.infinity;
    double minScreenY = double.infinity, maxScreenY = -double.infinity;
    int inFrontCount = 0;
    final double nearPlane = -1188.0 / modelScale;
    for (final c in corners) {
      final tv = camera.transformVertex(c - center);
      if (camera.isFlyMode) {
        if (tv.y > nearPlane) inFrontCount++;
      }
      final p = camera.projectToScreen(tv, size, modelScale);
      if (p.dx < minScreenX) minScreenX = p.dx;
      if (p.dx > maxScreenX) maxScreenX = p.dx;
      if (p.dy < minScreenY) minScreenY = p.dy;
      if (p.dy > maxScreenY) maxScreenY = p.dy;
    }

    if (camera.isFlyMode && inFrontCount == 0) return false;

    if (maxScreenX < -margin || minScreenX > size.width + margin) return false;
    if (maxScreenY < -margin || minScreenY > size.height + margin) return false;
    return true;
  }

  @override
  bool shouldRepaint(covariant Cad3DMeshPainter oldDelegate) {
    return true;
  }
}
