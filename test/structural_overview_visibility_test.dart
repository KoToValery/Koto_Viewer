import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/vertical_capacity_models.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_overview_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'overview symbol remains legible at fit while model section and orientation stay unchanged',
    () {
      const c = StructuralColumn(
        id: 'c',
        center: Offset(50, 30),
        width: .25,
        height: .5,
        shape: ColumnShape.lShape,
        thickness: .15,
        rotationRad: .4,
        isMirrored: true,
      );
      final original = List<Offset>.of(c.polygonVertices);
      for (final pixelScale in [.1, 1.0, 4.0, 80.0]) {
        final physical = original.map((p) => p * pixelScale).toList();
        final symbol = StructuralOverviewLayout.columnSymbol(physical);
        final physicalBounds = StructuralOverviewLayout.boundsOf(physical);
        final bounds = StructuralOverviewLayout.boundsOf(symbol);
        expect(bounds.longestSide, greaterThanOrEqualTo(12 - 1e-9));
        expect(
          (bounds.center - physicalBounds.center).distance,
          lessThan(1e-9),
        );
        expect(
          bounds.width / bounds.height,
          closeTo(physicalBounds.width / physicalBounds.height, 1e-9),
        );
        expect(c.polygonVertices, original);
        if (physicalBounds.longestSide >= 12) expect(symbol, same(physical));
      }
    },
  );
  test(
    'overview names stay outside every section, inside viewport and apart',
    () {
      final entries = [
        for (var row = 0; row < 5; row++)
          for (var col = 0; col < 6; col++)
            SupportOverviewEntry(
              id: '$row-$col',
              label: 'C$row$col',
              anchor: Offset(35 + col * 50, 80 + row * 55),
              symbolBounds: Rect.fromCenter(
                center: Offset(35 + col * 50, 80 + row * 55),
                width: 12,
                height: 12,
              ),
              labelSize: const Size(28, 20),
              color: const Color(0xFF82B1FF),
            ),
      ];
      const viewport = Rect.fromLTWH(0, 0, 360, 400);
      final labels = StructuralOverviewLayout.arrange(
        entries,
        viewport,
        reserved: [const Rect.fromLTWH(10, 10, 290, 50)],
      );
      expect(labels, hasLength(30));
      for (var i = 0; i < labels.length; i++) {
        expect(viewport.contains(labels[i].rect.topLeft), isTrue);
        expect(viewport.contains(labels[i].rect.bottomRight), isTrue);
        expect(
          entries.any((e) => e.symbolBounds.overlaps(labels[i].rect)),
          isFalse,
        );
        for (var j = i + 1; j < labels.length; j++) {
          expect(labels[i].rect.overlaps(labels[j].rect), isFalse);
        }
      }
    },
  );
  test(
    'selection and alerts take priority in dense areas; no badge pile-up',
    () {
      final entries = [
        for (var i = 0; i < 20; i++)
          SupportOverviewEntry(
            id: 'c$i',
            label: 'C$i',
            anchor: const Offset(90, 100),
            symbolBounds: const Rect.fromLTWH(84, 94, 12, 12),
            labelSize: const Size(38, 22),
            color: const Color(0xFF82B1FF),
            priority: i == 19 ? 3 : 0,
          ),
      ];
      final labels = StructuralOverviewLayout.arrange(
        entries,
        const Rect.fromLTWH(0, 0, 180, 200),
      );
      expect(labels.length, lessThan(20));
      expect(labels.first.entry.id, 'c19');
      for (var i = 0; i < labels.length; i++) {
        for (var j = i + 1; j < labels.length; j++) {
          expect(labels[i].rect.overlaps(labels[j].rect), isFalse);
        }
      }
    },
  );
  test(
    'fit overview paints visible columns and wall stripes even at millimetre scale',
    () async {
      for (final cadScale in [1.0, 1000.0]) {
        final columns = [
          for (final (name, p) in [
            ('C1', const Offset(10, 10)),
            ('C2', const Offset(50, 10)),
            ('C3', const Offset(90, 10)),
            ('C4', const Offset(10, 70)),
            ('C5', const Offset(50, 70)),
            ('C6', const Offset(90, 70)),
          ])
            StructuralColumn(
              id: name,
              name: name,
              center: p * cadScale,
              width: .25 * cadScale,
              height: .3 * cadScale,
            ),
        ];
        final walls = [
          StructuralShearWall(
            id: 'W1',
            name: 'W1',
            start: Offset(25, 25) * cadScale,
            end: Offset(45, 25) * cadScale,
            thickness: .25 * cadScale,
          ),
          StructuralShearWall(
            id: 'W2',
            name: 'W2',
            start: Offset(70, 35) * cadScale,
            end: Offset(70, 55) * cadScale,
            thickness: .25 * cadScale,
            referenceLine: ShearWallReferenceLine.rightFace,
          ),
        ];
        final floor = StoreyLevel(
          id: 'f',
          name: 'f',
          elevation: 3,
          columns: columns,
          shearWalls: walls,
        );
        final checks = [
          for (var i = 0; i < 3; i++)
            SupportSpanCheck(
              segment: (columns[i].center, columns[i + 3].center),
              spanM: 60,
              thicknessM: .2,
              allowableSpanM: 3.74,
            ),
        ];
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFF161B22), BlendMode.src);
        // Architectural wall underlay of nearly the same physical width.
        for (final c in columns) {
          final p = Offset(
            50 + c.center.dx / cadScale * 4,
            450 - c.center.dy / cadScale * 4,
          );
          canvas.drawLine(
            p - const Offset(30, 0),
            p + const Offset(30, 0),
            Paint()
              ..color = const Color(0xFF777777)
              ..strokeWidth = 1,
          );
        }
        final painter = Structural2dPainter(
          currentStorey: floor,
          cadUnitsPerMeter: cadScale,
          supportSpanChecks: checks,
          showCantileverHeatmap: false,
          cadScale: 4 / cadScale,
          cadToScene: (p) =>
              Offset(50 + p.dx / cadScale * 4, 450 - p.dy / cadScale * 4),
        );
        painter.paint(canvas, const Size(560, 480));
        final picture = recorder.endRecording();
        final image = await picture.toImage(560, 480);
        final data = await image.toByteData(format: ImageByteFormat.rawRgba);
        final pixels = data!.buffer.asUint8List();
        int matching(Rect region, bool Function(int, int, int) predicate) {
          var count = 0;
          for (var y = region.top.toInt(); y < region.bottom; y++) {
            for (var x = region.left.toInt(); x < region.right; x++) {
              final index = (y * 560 + x) * 4;
              if (predicate(
                pixels[index],
                pixels[index + 1],
                pixels[index + 2],
              )) {
                count++;
              }
            }
          }
          return count;
        }

        expect(
          matching(
            const Rect.fromLTWH(80, 400, 20, 20),
            (r, g, b) => r < 100 && b > 200 && g > 80,
          ),
          greaterThan(20),
        );
        expect(
          matching(
            const Rect.fromLTWH(175, 345, 60, 10),
            (r, g, b) => g > 150 && r < 80 && b > 100,
          ),
          greaterThan(100),
        );
        if (cadScale == 1) {
          final png = await image.toByteData(format: ImageByteFormat.png);
          await File(
            '.dart_tool/structural_overview_visibility.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
      }
    },
  );
}
