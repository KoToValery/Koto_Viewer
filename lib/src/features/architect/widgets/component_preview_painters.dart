import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../cad_3d/models/mesh_3d.dart';
import '../models/architect_component.dart';

class ComponentPlanPreviewPainter extends CustomPainter {
  final ArchitectComponentBlock2D block;
  final double width;
  final double depth;

  const ComponentPlanPreviewPainter(this.block, this.width, this.depth);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final bounds = block.bounds;
    final scaleX = (size.width * 0.80) / math.max(bounds.width, .001);
    final scaleY = (size.height * 0.80) / math.max(bounds.height, .001);
    final scale = math.min(scaleX, scaleY);

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.scale(scale, scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    // 1. Whiteout mask
    canvas.drawPath(block.boundsMask, Paint()..color = Colors.white);

    // 2. Outer contour
    canvas.drawPath(
      block.outline,
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 1.4 / scale
        ..style = PaintingStyle.stroke,
    );

    // 3. Details
    final detailPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 0.9 / scale
      ..style = PaintingStyle.stroke;
    for (final p in block.detailPaths) {
      canvas.drawPath(p, detailPaint);
    }

    // 4. Insertion point indicator at (0, 0)
    canvas.drawCircle(
      Offset.zero,
      4.0 / scale,
      Paint()..color = const Color(0xFF00E5FF),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ComponentPlanPreviewPainter oldDelegate) =>
      oldDelegate.block != block;
}

// ===========================================================================
// 3. LIVE 3D ORBIT PREVIEW PAINTER
// ===========================================================================

class ComponentMeshPreviewPainter extends CustomPainter {
  final Mesh3D mesh;
  final double pitch;
  final double yaw;

  const ComponentMeshPreviewPainter(this.mesh, this.pitch, this.yaw);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || mesh.triangles.isEmpty) return;

    final bounds = mesh.bounds;
    final center = bounds.center;

    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final spanX = bounds.max.x - bounds.min.x;
    final spanY = bounds.max.y - bounds.min.y;
    final spanZ = bounds.max.z - bounds.min.z;
    final projectedWidth = cosY.abs() * spanX + sinY.abs() * spanY;
    final projectedHeight =
        sinP.abs() * (sinY.abs() * spanX + cosY.abs() * spanY) +
        cosP.abs() * spanZ;
    final scale = math.min(
      size.width * .82 / math.max(projectedWidth, .001),
      size.height * .82 / math.max(projectedHeight, .001),
    );

    // Rotate points around center
    Offset project(Vector3 p) {
      final dx = p.x - center.x;
      final dy = p.y - center.y;
      final dz = p.z - center.z;

      // Yaw rotation (Z-up)
      final x1 = dx * cosY - dy * sinY;
      final y1 = dx * sinY + dy * cosY;
      final z1 = dz;

      // Pitch rotation
      final x2 = x1;
      final z2 = y1 * sinP + z1 * cosP;

      return Offset(
        size.width / 2.0 + x2 * scale,
        size.height / 2.0 - z2 * scale,
      );
    }

    final camera = Vector3(-sinY * cosP, -cosY * cosP, sinP);
    final faces = <_PreviewFace>[
      for (final t in mesh.triangles)
        if (t.isDoubleSided || t.normal.dot(camera) > 1e-9)
          _PreviewFace(
            [t.v0, t.v1, t.v2],
            t.normal,
            t.color ?? const Color(0xFFECEFF1),
          ),
    ];
    if (faces.isEmpty) return;
    // Centroid sorting lets long rear triangles cover nearer geometry. Splitting
    // at face planes produces a valid drawing order for tables, legs and cavities.
    final sortedFaces = _PreviewBsp(faces).ordered(camera);

    final lightDir = Vector3(0.5, 0.4, 0.8).normalized();

    for (final t in sortedFaces) {
      final n = t.normal;

      final dot = math.max(0.25, n.dot(lightDir));
      final baseColor = t.color;
      final shadedColor = Color.fromARGB(
        (baseColor.a * 255.0).round().clamp(0, 255),
        ((baseColor.r * 255.0).round().clamp(0, 255) * dot).round().clamp(
          0,
          255,
        ),
        ((baseColor.g * 255.0).round().clamp(0, 255) * dot).round().clamp(
          0,
          255,
        ),
        ((baseColor.b * 255.0).round().clamp(0, 255) * dot).round().clamp(
          0,
          255,
        ),
      );

      final path = Path()..addPolygon(t.points.map(project).toList(), true);

      canvas.drawPath(
        path,
        Paint()
          ..color = shadedColor
          ..isAntiAlias = false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ComponentMeshPreviewPainter oldDelegate) =>
      oldDelegate.mesh != mesh ||
      oldDelegate.pitch != pitch ||
      oldDelegate.yaw != yaw;
}

class _PreviewFace {
  final List<Vector3> points;
  final Vector3 normal;
  final Color color;
  _PreviewFace(this.points, this.normal, this.color);
}

class _PreviewBsp {
  final List<_PreviewFace> planeFaces = [];
  late final Vector3 normal;
  late final Vector3 origin;
  _PreviewBsp? front, back;
  static const epsilon = 1e-8;

  _PreviewBsp(List<_PreviewFace> faces) {
    final plane = faces.first;
    normal = plane.normal;
    origin = plane.points.first;
    final frontFaces = <_PreviewFace>[], backFaces = <_PreviewFace>[];
    for (final face in faces) {
      final distances = [for (final p in face.points) normal.dot(p - origin)];
      final hasFront = distances.any((d) => d > epsilon);
      final hasBack = distances.any((d) => d < -epsilon);
      if (!hasFront && !hasBack) {
        planeFaces.add(face);
      } else if (!hasBack) {
        frontFaces.add(face);
      } else if (!hasFront) {
        backFaces.add(face);
      } else {
        final positive = <Vector3>[], negative = <Vector3>[];
        for (var i = 0; i < face.points.length; i++) {
          final j = (i + 1) % face.points.length;
          final a = face.points[i], b = face.points[j];
          final da = distances[i], db = distances[j];
          if (da >= -epsilon) positive.add(a);
          if (da <= epsilon) negative.add(a);
          if ((da > epsilon && db < -epsilon) ||
              (da < -epsilon && db > epsilon)) {
            final point = a + (b - a) * (da / (da - db));
            positive.add(point);
            negative.add(point);
          }
        }
        if (positive.length >= 3) {
          frontFaces.add(_PreviewFace(positive, face.normal, face.color));
        }
        if (negative.length >= 3) {
          backFaces.add(_PreviewFace(negative, face.normal, face.color));
        }
      }
    }
    if (frontFaces.isNotEmpty) front = _PreviewBsp(frontFaces);
    if (backFaces.isNotEmpty) back = _PreviewBsp(backFaces);
  }

  Iterable<_PreviewFace> ordered(Vector3 camera) sync* {
    final near = normal.dot(camera) > 0 ? front : back;
    final far = normal.dot(camera) > 0 ? back : front;
    if (far != null) yield* far.ordered(camera);
    yield* planeFaces;
    if (near != null) yield* near.ordered(camera);
  }
}
