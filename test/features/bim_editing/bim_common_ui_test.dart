import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/bim_editing/properties/bim_numeric_rule.dart';
import 'package:kotoview/src/features/bim_editing/properties/bim_distance_unit.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'package:kotoview/src/features/bim_editing/scene/bim_element_adapter.dart';

void main() {
  test(
    'numeric property bounds apply in model units and reject nonfinite/integer errors',
    () {
      const rule = BimNumericRule(minimum: .001, maximum: 10, unitToModel: .01);
      expect(rule.parse(' 25,50 '), .255);
      expect(rule.parse('0.05'), isNull);
      expect(rule.parse('1100'), isNull);
      expect(rule.parse('NaN'), isNull);
      expect(rule.parse('Infinity'), isNull);
      expect(
        const BimNumericRule(
          integer: true,
          minimum: 1,
          maximum: 1000,
        ).parse('1.5'),
        isNull,
      );
      expect(const BimNumericRule(integer: true).parse('19'), 19);
      expect(const BimNumericRule().parse('-2,5'), -2.5);
    },
  );
  test(
    'shared unit serialization names and metre conversions remain stable',
    () {
      expect(BimDistanceUnit.values.map((u) => u.name), [
        'meters',
        'centimeters',
        'millimeters',
        'feet',
        'inches',
      ]);
      for (final unit in BimDistanceUnit.values) {
        expect(unit.fromUnit(unit.toUnit(2.75)), closeTo(2.75, 1e-12));
      }
      expect(BimDistanceUnit.centimeters.format(.255), '26 cm');
      expect(BimDistanceUnit.feet.format(.3048), '1′ 0″');
    },
  );
  for (final language in ['en', 'bg']) {
    testWidgets('common action catalog uses $language ARB messages', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final action in BimEditAction.values) {
        expect(BimEditActions.label(action, l), isNotEmpty);
      }
      expect(
        BimEditActions.label(BimEditAction.duplicate, l),
        l.dragDuplicateAction,
      );
    });
  }
  test('common menu capabilities disable reference-only element actions', () {
    const ref = BimElementRef(
      documentId: 'doc',
      storeyId: 'floor',
      elementId: 'element',
    );
    final editable = BimElementSnapshot(
      reference: ref,
      kind: BimEditingGeometryKind.profile,
      anchor: Offset.zero,
      capabilities: {
        BimEditingCapability.translate,
        BimEditingCapability.duplicate,
      },
    );
    expect(
      BimEditActions.available(editable),
      containsAll([BimEditAction.move, BimEditAction.duplicate]),
    );
    expect(
      BimEditActions.available(editable),
      isNot(contains(BimEditAction.rotate)),
    );
    final reference = BimElementSnapshot(
      reference: ref,
      kind: BimEditingGeometryKind.profile,
      anchor: Offset.zero,
      readOnly: true,
      capabilities: editable.capabilities,
    );
    expect(BimEditActions.available(reference), isEmpty);
  });
}
