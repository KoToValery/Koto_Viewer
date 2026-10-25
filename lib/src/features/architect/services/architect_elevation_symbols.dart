import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_elevation.dart';
import '../models/architect_fenestration_style.dart';
import '../models/architect_project.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';

/// Closed-leaf operation symbols, independent of the leaf's 3D opening angle.
/// Coordinates retain depth so foreground building parts can hide the symbols.
class ArchitectElevationOperation {
  final String id;
  final List<Vector3> aperture;
  final Path lines;
  const ArchitectElevationOperation(this.id, this.aperture, this.lines);

  static List<ArchitectElevationOperation> build(
    ArchitectProject project,
    ArchitectElevation view, {
    Set<String> excludedOpeningIds = const {},
  }) {
    final result = <ArchitectElevationOperation>[];
    for (final storey in project.storeys) {
      for (final wall in storey.walls) {
        final u = wall.unitVector, n = wall.normalVector;
        final facing =
            n.dx * view.viewDirection.dx + n.dy * view.viewDirection.dy;
        if (facing.abs() < 1e-5 || wall.length < .01) continue;
        void opening(
          String id,
          double ratio,
          double width,
          double height,
          double sill,
          double frame,
          ArchitectFenestrationStyle? style, {
          bool? hingeLeft,
          int panes = 1,
        }) {
          final frameDepth = style?.frameDepth ?? wall.thickness;
          final center =
              (style == null ? wall.centerStart : wall.coreCenterStart) +
              u * (wall.length * ratio) -
              n * (facing.sign * frameDepth / 2);
          final bottom = storey.elevation + wall.baseOffset + sill;
          Vector3 projectPoint(double x, double z) {
            final p = center + u * x - view.centre;
            return Vector3(
              p.dx * view.right.dx + p.dy * view.right.dy,
              z,
              p.dx * view.viewDirection.dx + p.dy * view.viewDirection.dy,
            );
          }

          Offset point(double x, double z) {
            final p = projectPoint(x, z);
            return Offset(p.x, p.y);
          }

          final lines = Path();
          void leaf(PaneType type, Rect rect, double inset) {
            if (type == PaneType.fixedGlazing || type == PaneType.solidPanel) {
              return;
            }
            if (rect.width <= 2 * inset || rect.height <= 2 * inset) return;
            final r = rect.deflate(inset);
            void chevron(Offset a, Offset tip, Offset b) {
              final p = point(a.dx, a.dy),
                  q = point(tip.dx, tip.dy),
                  t = point(b.dx, b.dy);
              lines.moveTo(p.dx, p.dy);
              lines.lineTo(q.dx, q.dy);
              lines.lineTo(t.dx, t.dy);
            }

            if (type == PaneType.casementRight) {
              chevron(r.topRight, r.centerLeft, r.bottomRight);
            } else if (type != PaneType.topHopper) {
              final left = type != PaneType.doorLeaf || (hingeLeft ?? true);
              chevron(
                left ? r.topLeft : r.topRight,
                left ? r.centerRight : r.centerLeft,
                left ? r.bottomLeft : r.bottomRight,
              );
            }
            if (type == PaneType.topHopper || type == PaneType.tiltAndTurn) {
              // z increases upward: bottom hinges, apex at top centre.
              chevron(r.topLeft, r.bottomCenter, r.topRight);
            }
          }

          final face = style?.frameFaceWidth ?? frame;
          final rect = Rect.fromLTRB(
            -width / 2 + face,
            bottom + (hingeLeft == null ? face : 0),
            width / 2 - face,
            bottom + height - face,
          );
          void subdivide(FenestrationSubdivision node, Rect r) {
            if (!node.isSplit) {
              final pane = node.pane;
              if (pane != null) leaf(pane.paneType, r, pane.sashProfileWidth);
              return;
            }
            var current = 0.0;
            for (var i = 0; i < node.children.length; i++) {
              final fraction = node.ratios[i];
              final child = node.isVertical
                  ? Rect.fromLTWH(
                      r.left + current,
                      r.top,
                      r.width * fraction,
                      r.height,
                    )
                  : Rect.fromLTWH(
                      r.left,
                      r.top + current,
                      r.width,
                      r.height * fraction,
                    );
              subdivide(node.children[i], child);
              current += node.isVertical ? child.width : child.height;
            }
          }

          if (style != null) {
            subdivide(style.rootSubdivision, rect);
          } else if (hingeLeft != null) {
            leaf(PaneType.doorLeaf, rect, .025);
          } else if (panes > 1) {
            // The legacy model explicitly defines one pane as fixed.
            for (var i = 0; i < panes; i++) {
              leaf(
                i < panes / 2 ? PaneType.casementLeft : PaneType.casementRight,
                Rect.fromLTWH(
                  rect.left + i * rect.width / panes,
                  rect.top,
                  rect.width / panes,
                  rect.height,
                ),
                .025,
              );
            }
          }
          if (lines.computeMetrics().isEmpty) return;
          result.add(
            ArchitectElevationOperation(id, [
              projectPoint(-width / 2, bottom),
              projectPoint(width / 2, bottom),
              projectPoint(width / 2, bottom + height),
              projectPoint(-width / 2, bottom + height),
            ], lines),
          );
        }

        for (final w in wall.windows) {
          if (excludedOpeningIds.contains(w.id)) continue;
          opening(
            w.id,
            w.offsetRatio,
            w.width,
            w.height,
            w.sillHeight,
            w.frameThickness,
            w.resolvedStyle,
            panes: w.panesCount,
          );
        }
        for (final d in wall.doors) {
          if (excludedOpeningIds.contains(d.id)) continue;
          opening(
            d.id,
            d.offsetRatio,
            d.width,
            d.height,
            d.sillHeight,
            d.frameThickness,
            d.resolvedStyle,
            hingeLeft: d.isHingeLeft,
          );
        }
      }
    }
    return result;
  }
}

class ArchitectElevationSlope {
  final String id;
  final Offset start, end;
  final double percent;
  const ArchitectElevationSlope(this.id, this.start, this.end, this.percent);

  static List<ArchitectElevationSlope> build(
    ArchitectProject project,
    ArchitectElevation view,
    Map<String, Path> visible,
  ) {
    final result = <ArchitectElevationSlope>[];
    for (final storey in project.storeys) {
      for (final roof in storey.roofs) {
        final path = visible[roof.id];
        if (path == null || roof.slopePercent.abs() < .01) continue;
        final box = path.getBounds();
        // Find an actual visible point, including concave/partly hidden roofs.
        Offset? anchor;
        var score = double.infinity;
        for (var x = 0; x < 21; x++) {
          for (var y = 0; y < 21; y++) {
            final p = Offset(
              box.left + box.width * (x + .5) / 21,
              box.top + box.height * (y + .5) / 21,
            );
            final distance = (p - box.center).distanceSquared;
            if (distance < score && path.contains(p)) {
              anchor = p;
              score = distance;
            }
          }
        }
        if (anchor == null) continue;
        final d = roof.slopeDirection;
        final downhill = Offset(
          -(d.dx * view.right.dx + d.dy * view.right.dy),
          -math.tan(roof.slopeRadians),
        );
        if (downhill.distance < 1e-6) continue;
        final half =
            downhill / downhill.distance * (box.width * .18).clamp(.25, .65);
        final centre = anchor + Offset(0, box.height < .6 ? .45 : 0);
        result.add(
          ArchitectElevationSlope(
            roof.id,
            centre - half,
            centre + half,
            roof.slopePercent.abs(),
          ),
        );
      }
    }
    return result;
  }
}
