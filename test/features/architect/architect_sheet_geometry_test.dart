import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_layout.dart';

const _place = ArchitectDrawingPlacement(
  id: 'v',
  drawingId: 'plan:s',
  frame: Rect.fromLTWH(20, 30, 100, 80),
  anchor: Offset(1.2, -3.4),
  scale: 50,
  showTitle: false,
);

ArchitectProject _project({List<ArchitectSheetTemplate>? templates}) =>
    ArchitectProject(
      id: 'p',
      name: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      storeys: const [],
      activeStoreyId: 's',
      document: ArchitectDocument(
        templates: templates ?? const [ArchitectSheetTemplate(id: 'empty')],
      ),
    );

void _near(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy placement inherits rectangular crop and drawing visibility', () {
    final old = _place.toJson()
      ..remove('crop')
      ..remove('visibilityOverrides');
    final restored = ArchitectDrawingPlacement.fromJson(old);
    expect(restored.crop, isNull);
    expect(restored.visibilityOverrides, isEmpty);
    expect(ArchitectSheetGeometry.clipPath(restored).getBounds(), _place.frame);
    expect(ArchitectSheetGeometry.valid(restored), isTrue);
  });

  test('crop and instance visibility survive JSON and duplication', () {
    final cropped = _place.copyWith(
      crop: const [Offset.zero, Offset(100, 0), Offset(70, 80), Offset(0, 80)],
      visibilityOverrides: const {'axes': false, 'zones': true},
    );
    final restored = ArchitectDrawingPlacement.fromJson(
      jsonDecode(jsonEncode(cropped.toJson())) as Map,
    );
    expect(restored.toJson(), cropped.toJson());
    final duplicate = restored.copyWith(id: 'copy');
    expect(duplicate.id, 'copy');
    expect(duplicate.crop, cropped.crop);
    expect(duplicate.visibilityOverrides, cropped.visibilityOverrides);
    expect(duplicate.copyWith(clearCrop: true).crop, isNull);
  });

  for (final rotation in [0.0, 90.0, 37.0, -25.0]) {
    test('crop rebasing preserves source position at $rotation degrees', () {
      final original = _place.copyWith(rotation: rotation);
      final cropped = ArchitectSheetGeometry.withContour(original, const [
        Offset(35, 45),
        Offset(95, 45),
        Offset(95, 70),
        Offset(60, 70),
        Offset(60, 95),
        Offset(35, 95),
      ]);
      expect(cropped.frame, const Rect.fromLTRB(35, 45, 95, 95));
      expect(cropped.scale, original.scale);
      expect(ArchitectSheetGeometry.valid(cropped), isTrue);
      for (final source in [
        original.anchor,
        const Offset(2.3, -1.7),
        const Offset(-1.1, 3.2),
      ]) {
        _near(
          ArchitectSheetGeometry.sourceToPaper(cropped, source),
          ArchitectSheetGeometry.sourceToPaper(original, source),
        );
      }
      final paper = ArchitectSheetGeometry.sourceToPaper(
        cropped,
        const Offset(2.3, -1.7),
      );
      _near(
        ArchitectSheetGeometry.paperToSource(cropped, paper),
        const Offset(2.3, -1.7),
      );
    });
  }

  test('rectangle conversion uses the crop bounds without source movement', () {
    final polygon = ArchitectSheetGeometry.withContour(_place, const [
      Offset(35, 45),
      Offset(95, 45),
      Offset(60, 95),
    ]);
    final rectangle = ArchitectSheetGeometry.withContour(
      polygon,
      ArchitectSheetGeometry.contour(polygon),
      rectangle: true,
    );
    expect(rectangle.crop, isNull);
    expect(rectangle.frame, polygon.frame);
    expect(rectangle.anchor, polygon.anchor);
  });

  test('scale reduces footprint and preserves the same source region', () {
    final original = _place.copyWith(
      rotation: 37,
      crop: const [Offset.zero, Offset(100, 0), Offset(70, 80), Offset(0, 80)],
    );
    final scaled = ArchitectSheetGeometry.changeScale(original, 100);
    expect(scaled.frame, const Rect.fromLTWH(20, 30, 50, 40));
    expect(scaled.anchor, original.anchor);
    expect(scaled.rotation, original.rotation);
    for (var i = 0; i < original.crop!.length; i++) {
      _near(
        ArchitectSheetGeometry.paperToSource(
          scaled,
          scaled.crop![i] + scaled.frame.topLeft,
        ),
        ArchitectSheetGeometry.paperToSource(
          original,
          original.crop![i] + original.frame.topLeft,
        ),
      );
    }
    expect(
      () => ArchitectSheetGeometry.changeScale(original, 0),
      throwsArgumentError,
    );
  });

  test('numeric frame sizing reshapes crop without changing drawing scale', () {
    final original = _place.copyWith(
      crop: const [Offset.zero, Offset(100, 0), Offset(70, 80), Offset(0, 80)],
    );
    final resized = ArchitectSheetGeometry.resizeFrame(
      original,
      const Rect.fromLTWH(40, 50, 200, 40),
    );
    expect(resized.crop![2], const Offset(140, 40));
    expect(resized.scale, original.scale);
    expect(resized.anchor, original.anchor);
  });

  test('invalid contours cannot be committed or published', () {
    const crossing = [
      Offset(20, 30),
      Offset(100, 90),
      Offset(100, 30),
      Offset(20, 90),
    ];
    expect(
      () => ArchitectSheetGeometry.withContour(_place, crossing),
      throwsArgumentError,
    );
    expect(
      ArchitectSheetGeometry.valid(_place.copyWith(crop: const [])),
      isFalse,
    );
  });

  test(
    'malformed persisted crop is rejected without crashing project loading',
    () {
      for (final value in [
        'bad',
        [1, 2, 3],
        [
          [0],
          [1, 2],
          [3, 4],
        ],
        [
          [0, 0],
          [double.nan, 1],
          [1, 1],
        ],
      ]) {
        final restored = ArchitectDrawingPlacement.fromJson({
          ..._place.toJson(),
          'crop': value,
        });
        expect(restored.crop, isEmpty);
        expect(ArchitectSheetGeometry.valid(restored), isFalse);
      }
    },
  );

  test(
    'disjoint crops with overlapping bounds are valid; actual overlap is not',
    () {
      final l = lookupAppLocalizations(const Locale('en'));
      final first = _place.copyWith(
        frame: const Rect.fromLTWH(10, 10, 50, 50),
        crop: const [Offset.zero, Offset(40, 0), Offset(0, 40)],
      );
      final second = first.copyWith(
        id: 'second',
        crop: const [Offset(50, 50), Offset(50, 20), Offset(20, 50)],
      );
      const sheet = ArchitectSheet(id: 'sheet', templateId: 'empty');
      expect(
        ArchitectSheetLayout.issues(
          _project(),
          sheet.copyWith(placements: [first, second]),
          l,
        ),
        isEmpty,
      );
      expect(
        ArchitectSheetLayout.issues(
          _project(),
          sheet.copyWith(
            placements: [
              first,
              second.copyWith(crop: first.crop),
            ],
          ),
          l,
        ),
        contains(l.architectSheetOverlap),
      );
    },
  );

  test('title block checks use the actual concave crop', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final p = _project(
      templates: const [
        ArchitectSheetTemplate(
          id: 'small',
          items: [
            ArchitectTitleItem(id: 'cell', rect: Rect.fromLTWH(0, 0, 40, 30)),
          ],
        ),
      ],
    );
    final place = _place.copyWith(
      frame: const Rect.fromLTWH(100, 80, 90, 60),
      crop: const [
        Offset.zero,
        Offset(90, 0),
        Offset(90, 20),
        Offset(20, 20),
        Offset(20, 60),
        Offset(0, 60),
      ],
    );
    final sheet = ArchitectSheet(
      id: 'sheet',
      templateId: 'small',
      widthMm: 200,
      heightMm: 150,
      placements: [place],
    );
    expect(ArchitectSheetLayout.issues(p, sheet, l), isEmpty);
    expect(
      ArchitectSheetLayout.issues(
        p,
        sheet.copyWith(placements: [place.copyWith(clearCrop: true)]),
        l,
      ),
      contains(l.architectSheetTitleOverlap),
    );
  });

  test('free areas include the full-height region beside the title block', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final p = _project(
      templates: const [
        ArchitectSheetTemplate(
          id: 'small',
          items: [
            ArchitectTitleItem(id: 'cell', rect: Rect.fromLTWH(0, 0, 40, 30)),
          ],
        ),
      ],
    );
    const sheet = ArchitectSheet(
      id: 'sheet',
      templateId: 'small',
      widthMm: 200,
      heightMm: 150,
    );
    final areas = ArchitectSheetLayout.freeAreas(p, sheet, l);
    expect(areas.any((area) => area.contains(const Offset(20, 130))), isTrue);
    final block = ArchitectSheetLayout.titleBlock(p, sheet)!;
    expect(areas.every((area) => !area.overlaps(block)), isTrue);
  });

  test(
    'fit tries every candidate, keeps rotation and restores the full source',
    () {
      ArchitectVectorScene build(int scale) {
        final canvas = ArchitectVectorCanvas();
        canvas.drawRect(
          Rect.fromLTWH(0, 0, 60 * 50 / scale, 110 * 50 / scale),
          Paint()..style = PaintingStyle.stroke,
        );
        return ArchitectVectorScene(canvas.operations, scale);
      }

      final fitted = ArchitectSheetLayout.fitAreas(
        _place.copyWith(
          crop: const [Offset.zero, Offset(100, 0), Offset(0, 80)],
        ),
        const [Rect.fromLTWH(10, 10, 200, 30), Rect.fromLTWH(20, 20, 80, 130)],
        build,
        title: (_) => '',
      );
      expect(fitted.scale, 50);
      expect(fitted.frame.topLeft, const Offset(20, 20));
      expect(fitted.crop, isNull);
    },
  );
}
