import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_vector_scene.dart';
import 'architect_drawing_publisher.dart';
import 'architect_dxf_writer.dart';
import 'architect_export_job.dart';
import 'architect_sheet_composer.dart';
import 'architect_sheet_geometry.dart';
import 'architect_sheet_layout.dart';

/// Editable, vector-only architectural DXF. Source coordinates are converted
/// once from Canvas Y-down to CAD Y-up; lengths use the project's actual units.
abstract final class ArchitectDxfExport {
  static Future<Map<String, Uint8List>> exportViews(
    ArchitectProject project,
    List<ArchitectSavedDrawing> drawings,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (drawings.isEmpty) throw ArgumentError('No drawings');
    final result = <String, Uint8List>{};
    for (var i = 0; i < drawings.length; i++) {
      final drawing = drawings[i];
      await architectExportCheckpoint(
        i / drawings.length,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      final scene = ArchitectDrawingPublisher.build(
        project,
        drawing,
        drawing.scale,
        l,
        sources: sources,
      );
      final entities = await _prepare(
        scene,
        factor: drawing.scale / 1000 / project.units.scaleToMeters,
        isCancelled: isCancelled,
      );
      final name = _unique(
        result,
        '${project.name}_${ArchitectSheetComposer.drawingName(drawing, l)}',
      );
      final bytes = await ArchitectDxfWriter.writeInWorker(<String, Object?>{
        'units': _units(project.units),
        'views': [
          <String, Object?>{'entities': entities},
        ],
      }, isCancelled: isCancelled);
      architectCheckExportCancelled(isCancelled);
      result[name] = bytes;
    }
    await architectExportCheckpoint(
      1,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return result;
  }

  static Future<Map<String, Uint8List>> exportSheets(
    ArchitectProject project,
    List<ArchitectSheet> sheets,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (sheets.isEmpty) throw ArgumentError('No sheets');
    final issues = [
      for (final sheet in sheets)
        for (final issue in ArchitectSheetComposer.issues(project, sheet, l))
          '${sheet.number}: $issue',
    ];
    if (issues.isNotEmpty) throw StateError(issues.join('\n'));
    final result = <String, Uint8List>{};
    final scenes = <Object, ArchitectVectorScene>{};
    var finished = 0;
    final work = sheets.fold<int>(0, (n, s) => n + s.placements.length + 1);
    for (final sheet in sheets) {
      final views = <Map<String, Object?>>[], ports = <Map<String, Object?>>[];
      for (final place in sheet.placements) {
        await architectExportCheckpoint(
          finished++ / work,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        final drawing = project.document.drawings.firstWhere(
          (d) => d.id == place.drawingId,
        );
        final effective = drawing.copyWith(
          visibility: {...drawing.visibility, ...place.visibilityOverrides},
        );
        final key = ArchitectDrawingPublisher.sceneKey(
          effective,
          place.scale,
          l,
          sources: sources,
        );
        final scene = scenes.putIfAbsent(
          key,
          () => ArchitectDrawingPublisher.build(
            project,
            effective,
            place.scale,
            l,
            sources: sources,
          ),
        );
        views.add({
          'entities': await _prepare(
            scene,
            factor: place.scale / 1000 / project.units.scaleToMeters,
            isCancelled: isCancelled,
          ),
        });
        final target = ArchitectSheetGeometry.paperToSource(
          place,
          place.frame.center,
        );
        final scale = 1000 * project.units.scaleToMeters / place.scale;
        ports.add({
          'center': [
            place.frame.center.dx,
            sheet.heightMm - place.frame.center.dy,
          ],
          'width': place.frame.width,
          'height': place.frame.height,
          'viewHeight': place.frame.height / scale,
          'target': [
            project.units.toUnit(target.dx),
            -project.units.toUnit(target.dy),
          ],
          'rotation': -place.rotation,
          if (place.crop != null)
            'crop': [
              for (final p in ArchitectSheetGeometry.contour(place))
                [p.dx, sheet.heightMm - p.dy],
            ],
        });
      }
      // Keep full sheet context for dynamic scale fields while omitting the
      // model views themselves; native viewports display those in CAD.
      final paper = ArchitectSheetComposer.compose(
        project,
        sheet,
        l,
        sources: sources,
        excludePlacements: sheet.placements.map((p) => p.id).toSet(),
      );
      final paperOps = <ArchitectVectorOp>[
        for (var i = 0; i < paper.operations.length; i++)
          if (i != 0) paper.operations[i], // Paper background is CAD's paper.
      ];
      final paperEntities = await _prepare(
        ArchitectVectorScene(paperOps, 1),
        yOrigin: sheet.heightMm,
        isCancelled: isCancelled,
      );
      // Captions live in paper space and remain editable independently of views.
      for (final place in sheet.placements.where((p) => p.showTitle)) {
        final drawing = project.document.drawings.firstWhere(
          (d) => d.id == place.drawingId,
        );
        final title =
            '${place.number}  ${ArchitectSheetComposer.drawingName(drawing, l)}  1:${place.scale}';
        final canvas = ArchitectVectorCanvas();
        final tp = ArchitectSheetLayout.textPainter(
          title,
          2.2,
          place.frame.width,
        );
        tp.paint(canvas, place.frame.bottomLeft + const Offset(0, 1));
        paperEntities.addAll(
          await _prepare(
            ArchitectVectorScene(canvas.operations, 1),
            yOrigin: sheet.heightMm,
            isCancelled: isCancelled,
          ),
        );
      }
      final bytes = await ArchitectDxfWriter.writeInWorker(<String, Object?>{
        'units': _units(project.units),
        'sheet': <String, Object?>{
          'name': _layoutName(sheet.number),
          'width': sheet.widthMm,
          'height': sheet.heightMm,
        },
        'views': views,
        'viewports': ports,
        'paperEntities': paperEntities,
      }, isCancelled: isCancelled);
      architectCheckExportCancelled(isCancelled);
      result[_unique(result, '${project.name}_${sheet.number}')] = bytes;
      await architectExportCheckpoint(
        finished++ / work,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    }
    await architectExportCheckpoint(
      1,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return result;
  }

  static int _units(ArchitectUnit unit) => switch (unit) {
    ArchitectUnit.meters => 6,
    ArchitectUnit.centimeters => 5,
    ArchitectUnit.millimeters => 4,
    ArchitectUnit.feet => 2,
    ArchitectUnit.inches => 1,
  };
  static String _layoutName(String name) {
    final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|,;=]'), '_').trim();
    return clean.isEmpty || clean.toLowerCase() == 'model' ? 'Layout1' : clean;
  }

  static String _unique(Map<String, Uint8List> files, String stem) {
    var safe = stem.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    if (safe.isEmpty) safe = 'drawing';
    var name = '$safe.dxf', index = 2;
    while (files.keys.any((k) => k.toLowerCase() == name.toLowerCase())) {
      name = '${safe}_${index++}.dxf';
    }
    return name;
  }
}

class _Contour {
  _Contour(this.points, this.closed);
  final List<Offset> points;
  final bool closed;
}

List<_Contour> _flatten(Path path) {
  final result = <_Contour>[];
  for (final metric in path.computeMetrics()) {
    if (metric.length <= 1e-10) continue;
    final points = <Offset>[];
    Offset at(double d) => metric.getTangentForOffset(d)!.position;
    void flatten(double a, double b, int depth) {
      final p = at(a), q = at(b), delta = q - p;
      final length = delta.distance;
      double error(Offset point) => length < 1e-12
          ? (point - p).distance
          : ((point - p).dx * delta.dy - (point - p).dy * delta.dx).abs() /
                length;
      if (depth >= 20 ||
          ((b - a - length).abs() < .00001 &&
              [
                at(a + (b - a) * .25),
                at((a + b) / 2),
                at(a + (b - a) * .75),
              ].every((v) => error(v) < .00001))) {
        points.add(p);
        return;
      }
      if (depth >= 14 || (b - a <= .04 && error(at((a + b) / 2)) < .002)) {
        points.add(p);
        return;
      }
      final m = (a + b) / 2;
      flatten(a, m, depth + 1);
      flatten(m, b, depth + 1);
    }

    flatten(0, metric.length, 0);
    points.add(at(metric.length));
    final clean = <Offset>[];
    for (final p in points) {
      if (clean.isNotEmpty && (clean.last - p).distance < 1e-7) continue;
      while (clean.length > 1) {
        final a = clean[clean.length - 2],
            b = clean.last,
            ab = b - a,
            bc = p - b;
        if ((ab.dx * bc.dy - ab.dy * bc.dx).abs() >
                1e-7 * (ab.distance + bc.distance) ||
            ab.dx * bc.dx + ab.dy * bc.dy < 0) {
          break;
        }
        clean.removeLast();
      }
      clean.add(p);
    }
    if (metric.isClosed &&
        clean.length > 1 &&
        (clean.first - clean.last).distance < 1e-5) {
      clean.removeLast();
    }
    if (clean.length >= 2) result.add(_Contour(clean, metric.isClosed));
  }
  return result;
}

String _layer(String role) => switch (role.toLowerCase()) {
  'walls' || 'wall' || 'wallmaterial' => 'A-WALL',
  'doors' || 'door' => 'A-DOOR',
  'windows' || 'window' => 'A-WINDOW',
  'slabs' || 'slab' => 'A-SLAB',
  'roof' || 'roofs' => 'A-ROOF',
  'dimensions' || 'dimension' => 'A-DIMS',
  'annotations' || 'ordinary' || 'roomname' || 'table' => 'A-TEXT',
  'axis' || 'axes' => 'A-GRID',
  'zone' || 'zones' => 'A-SPACE',
  'stairs' || 'stair' => 'A-STAIR',
  'column' || 'columns' => 'S-COLUMN',
  'beam' || 'beams' => 'S-BEAM',
  _ => 'A-${role.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toUpperCase()}',
};

int _color(Color c) {
  int channel(double v) => (v * 255).round().clamp(0, 255);
  return (channel(c.r) << 16) | (channel(c.g) << 8) | channel(c.b);
}

Future<List<Map<String, Object?>>> _prepare(
  ArchitectVectorScene scene, {
  double factor = 1,
  double yOrigin = 0,
  bool Function()? isCancelled,
}) async {
  final result = <Map<String, Object?>>[];
  final patterns = <_Pattern>[];
  Object? lastPatternKey;
  _Pattern? lastPattern;
  var lastPatternIndex = -2;
  final clipContours = Map<Path, List<_Contour>>.identity();
  List<_Contour> mask(Path clip) =>
      clipContours.putIfAbsent(clip, () => _flatten(clip));
  List<double> point(Offset p) => [p.dx * factor, yOrigin - p.dy * factor];
  Map<String, Object?> style(
    ArchitectVectorOp op,
    Color color,
    double weight,
  ) => {
    'layer': _layer(op.role),
    'color': _color(color),
    'opacity': color.a,
    'weight': weight,
    'sources': op.sources.toList()..sort(),
  };
  List<Map<String, Object?>> loops(Path path) {
    final contours = _flatten(
      path,
    ).where((c) => c.closed && c.points.length >= 3).toList();
    return [
      for (var i = 0; i < contours.length; i++)
        {
          'points': [for (final p in contours[i].points) point(p)],
          'outer': contours
              .where(
                (other) =>
                    !identical(other, contours[i]) &&
                    (Path()..addPolygon(other.points, true)).contains(
                      contours[i].points.first,
                    ),
              )
              .length
              .isEven,
        },
    ];
  }

  for (var index = 0; index < scene.operations.length; index++) {
    if (index % 32 == 0) {
      await architectExportCheckpoint(0, isCancelled: isCancelled);
    }
    final op = scene.operations[index];
    if (op is ArchitectVectorText) {
      // Noto Sans hhea ascent 1069 and OS/2 cap height 714 per 1000 em.
      // The publisher anchors the font box; MTEXT top attachment anchors the
      // capital top. Preserve the baseline after converting that convention.
      final capOffset = op.size * (1.069 - ArchitectDrawingScale.fontCapRatio);
      final textAt =
          op.position +
          Offset(-math.sin(op.rotation), math.cos(op.rotation)) * capOffset;
      final data = <String, Object?>{
        'type': 'text',
        ...style(op, op.color, .18),
        'at': point(textAt),
        'height': op.size * ArchitectDrawingScale.fontCapRatio * factor,
        // The publisher already resolved line breaks and alignment. Width 0
        // is CAD's unrestricted reference width, preventing a second wrap.
        'width': 0.0,
        'rotation': -op.rotation * 180 / math.pi,
        'text': op.text,
        'underline': op.decoration.contains(TextDecoration.underline),
        'overline': op.decoration.contains(TextDecoration.overline),
        'strike': op.decoration.contains(TextDecoration.lineThrough),
        'style': op.weight.value >= 600
            ? (op.fontStyle == FontStyle.italic
                  ? 'KOTO_BOLD_ITALIC'
                  : 'KOTO_BOLD')
            : (op.fontStyle == FontStyle.italic
                  ? 'KOTO_ITALIC'
                  : 'KOTO_REGULAR'),
      };
      if (op.clip != null) {
        final bounds = op.bounds;
        if (!op.clip!.getBounds().overlaps(bounds)) continue;
        // Preserve real text inside native clipped blocks, never bitmap glyphs.
        final contours = mask(op.clip!).where((c) => c.closed).toList();
        if (contours.length == 1) {
          data['clipPolygons'] = [contours.single.points.map(point).toList()];
        } else {
          final mesh = ArchitectPathSolid.extrude(
            op.clip!,
            0,
            1,
            const Color(0xff000000),
          );
          data['clipPolygons'] = [
            for (final t in mesh)
              if ((t.v0.z - 1).abs() < 1e-7 &&
                  (t.v1.z - 1).abs() < 1e-7 &&
                  (t.v2.z - 1).abs() < 1e-7)
                [
                  point(Offset(t.v0.x, t.v0.y)),
                  point(Offset(t.v1.x, t.v1.y)),
                  point(Offset(t.v2.x, t.v2.y)),
                ],
          ];
        }
      }
      result.add(data);
    } else if (op is ArchitectVectorPath) {
      if (op.color.a <= 0) continue;
      if (op.fill) {
        final region = op.clip == null
            ? op.path
            : Path.combine(PathOperation.intersect, op.path, op.clip!);
        final rings = loops(region);
        if (rings.isNotEmpty) {
          result.add({
            'type': 'hatch',
            ...style(op, op.color, op.width),
            'loops': rings,
          });
        }
      } else {
        final contours = _flatten(op.path);
        if (op.clip != null && contours.every((c) => !c.closed)) {
          final key = (op.clip!, op.color.toARGB32(), op.width, op.role);
          if (lastPatternKey != key || lastPatternIndex != index - 1) {
            lastPattern = _Pattern(op.clip!, style(op, op.color, op.width));
            patterns.add(lastPattern);
            result.add(lastPattern.packet);
          }
          lastPatternKey = key;
          lastPatternIndex = index;
          final group = lastPattern!;
          group.sources.addAll(op.sources);
          for (final c in contours) {
            for (var i = 1; i < c.points.length; i++) {
              group.lines.add((c.points[i - 1], c.points[i]));
            }
          }
        } else {
          for (final c in contours) {
            if (op.clip == null) {
              result.add({
                'type': 'polyline',
                ...style(op, op.color, op.width),
                'points': c.points.map(point).toList(),
                'closed': c.closed,
              });
            } else {
              final points = [...c.points, if (c.closed) c.points.first];
              for (var i = 1; i < points.length; i++) {
                for (final (a, b) in _clipLine(
                  points[i - 1],
                  points[i],
                  op.clip!,
                  rings: mask(op.clip!),
                )) {
                  result.add({
                    'type': 'polyline',
                    ...style(op, op.color, op.width),
                    'points': [point(a), point(b)],
                    'closed': false,
                  });
                }
              }
            }
          }
        }
      }
    }
  }
  for (final group in patterns) {
    final rings = loops(group.clip);
    if (rings.isEmpty) continue;
    final box = group.clip.getBounds();
    final period = math.max(
      100.0,
      math.sqrt(box.width * box.width + box.height * box.height) * factor * 8,
    );
    final lines = <List<double>>[];
    var prepared = 0;
    for (final (a, b) in group.lines) {
      if (prepared++ % 64 == 0) {
        await architectExportCheckpoint(0, isCancelled: isCancelled);
      }
      for (final (p, q) in _clipLine(
        a,
        b,
        group.clip,
        rings: mask(group.clip),
      )) {
        final dx = (q.dx - p.dx) * factor, dy = -(q.dy - p.dy) * factor;
        final length = math.sqrt(dx * dx + dy * dy);
        if (length < 1e-9) continue;
        final origin = point(p);
        lines.add([
          math.atan2(dy, dx) * 180 / math.pi,
          origin[0],
          origin[1],
          -dy / length * period,
          dx / length * period,
          length,
          -period,
        ]);
      }
    }
    if (lines.isNotEmpty) {
      group.packet.addAll({
        'type': 'hatch',
        ...group.style,
        'sources': group.sources.toList()..sort(),
        'loops': rings,
        'pattern': lines,
      });
    }
  }
  result.removeWhere((packet) => packet.isEmpty);
  return result;
}

class _Pattern {
  _Pattern(this.clip, this.style);
  final Path clip;
  final Map<String, Object?> style;
  final packet = <String, Object?>{};
  final lines = <(Offset, Offset)>[];
  final sources = <String>{};
}

Iterable<(Offset, Offset)> _clipLine(
  Offset a,
  Offset b,
  Path clip, {
  List<_Contour>? rings,
}) sync* {
  final delta = b - a;
  if (delta.distanceSquared < 1e-18) return;
  final contours = rings ?? _flatten(clip);
  final ts = <double>[0, 1];
  bool boundary(Offset p) {
    for (final ring in contours) {
      for (var i = 0; i < ring.points.length; i++) {
        final c = ring.points[i],
            d = ring.points[(i + 1) % ring.points.length] - c;
        final t =
            ((p - c).dx * d.dx + (p - c).dy * d.dy) /
            math.max(1e-20, d.distanceSquared);
        if (t >= -1e-7 && t <= 1 + 1e-7 && (p - c - d * t).distance < 1e-5) {
          return true;
        }
      }
    }
    return false;
  }

  for (final ring in contours) {
    for (var i = 0; i < ring.points.length; i++) {
      final c = ring.points[i],
          s = ring.points[(i + 1) % ring.points.length] - c;
      final cross = delta.dx * s.dy - delta.dy * s.dx;
      if (cross.abs() < 1e-14) continue;
      final d = c - a;
      final t = (d.dx * s.dy - d.dy * s.dx) / cross,
          u = (d.dx * delta.dy - d.dy * delta.dx) / cross;
      if (t > 0 && t < 1 && u >= -1e-8 && u <= 1 + 1e-8) ts.add(t);
    }
  }
  ts.sort();
  for (var i = 1; i < ts.length; i++) {
    if (ts[i] - ts[i - 1] < 1e-10) continue;
    final mid = a + delta * ((ts[i] + ts[i - 1]) / 2);
    if (clip.contains(mid) || boundary(mid)) {
      yield (a + delta * ts[i - 1], a + delta * ts[i]);
    }
  }
}
