import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_cad_entity_visibility.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_site_orientation.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_workspace_interaction_test.dart' as workspace;

const _line = DxfLine(p1: Offset(0, 2), p2: Offset(7, 2));
const _crossing = DxfLine(p1: Offset(5, 0), p2: Offset(5, 5));
const _label = DxfText(
  text: 'Survey label',
  insertPoint: Offset(1, 2),
  height: .3,
);

DxfDocument _source() => DxfDocument(
  layers: {'0': DxfLayer(name: '0')},
  blocks: const {},
  entities: const [_line, _crossing, _label],
  headerVars: const {},
  bounds: const Rect.fromLTWH(0, 0, 7, 5),
  entityStats: const {},
);

ArchitectProject _project({Set<int> hidden = const {}}) {
  final starter = ArchitectProject.starterWithCatalog(
    name: 'Survey',
    storeyCount: 1,
  );
  final site = starter.siteStorey!.id;
  return starter
      .copyWith(activeStoreyId: site)
      .withCadUnderlayAdded(
        ArchitectCadUnderlayConfig(
          id: 'survey',
          storeyId: site,
          fileName: 'survey.dxf',
          internalCopyPath: '',
          siteHiddenEntities: hidden,
        ),
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'filters CAD hits and publication and preserves indices when aligned',
    () {
      final source = _source();
      final visible = ArchitectCadEntityVisibility.visible(source, const {0});
      expect(visible.entities, [_crossing, _label]);
      expect(source.entities, [_line, _crossing, _label]);
      expect(visible.layoutEntities['Model'], visible.entities);
      expect(
        DxfSnapHelper.findSnapPoint(
          document: visible,
          cadPoint: const Offset(4, 2),
          toleranceCad: .1,
        ),
        isNull,
      );
      expect(
        DxfSnapHelper.hitTestEntities(
          document: source,
          cadPoint: const Offset(5, 2),
          toleranceCad: .1,
          layerVisibility: const {},
        ),
        containsAll([_line, _crossing]),
      );

      final original = _project();
      final hidden = _project(hidden: const {0});
      final restored = ArchitectProject.fromJson(hidden.toJson());
      expect(restored.cadUnderlays.values.single.siteHiddenEntities, {0});
      final reloaded = KcadReader.read(KcadWriter.write(source));
      final reloadedVisible = ArchitectCadEntityVisibility.visible(
        reloaded,
        restored.cadUnderlays.values.single.siteHiddenEntities,
      );
      expect(reloadedVisible.entities.map((e) => e.typeName), ['LINE', 'TEXT']);
      expect((reloadedVisible.entities.first as DxfLine).p1, _crossing.p1);
      final rotated = ArchitectSiteOrientation.align(
        project: restored,
        pivot: Offset.zero,
        deltaRad: .4,
      );
      expect(rotated.cadUnderlays.values.single.siteHiddenEntities, {0});
      final l = AppLocalizationsEn();
      const drawing = ArchitectSavedDrawing(
        id: 'plan:storey_site',
        sourceId: 'storey_site',
        kind: ArchitectDrawingKind.plan,
        sitePlan: true,
      );
      final sources = ArchitectPublicationSources(
        underlays: {'survey': source},
      );
      final before = ArchitectDrawingPublisher.build(
        original,
        drawing,
        100,
        l,
        sources: sources,
      );
      final after = ArchitectDrawingPublisher.build(
        hidden,
        drawing,
        100,
        l,
        sources: sources,
      );
      expect(after.operations.length, before.operations.length - 1);
    },
  );

  testWidgets('pick, cycle, hide and restore from the site menu on a phone', (
    tester,
  ) async {
    final project = _project();
    final model = ArchitectCommandController(project);
    addTearDown(model.dispose);
    await workspace.open(
      tester,
      model,
      underlays: {project.activeStoreyId: _source()},
    );
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    workspace
        .camera(tester)
        .fit(const Rect.fromLTWH(-1, -1, 9, 7), padding: 64);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-site-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide from site plan'));
    await tester.pumpAndSettle();

    Set<int> hidden() =>
        model.project.cadUnderlays.values.single.siteHiddenEntities;
    ArchitectUnderlayPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<ArchitectUnderlayPainter>()
        .first;
    final source = painter().document!;
    final point = workspace.screen(tester, const Offset(5, 2));
    final apply = find.byKey(
      const ValueKey('architect-site-cad-visibility-apply'),
    );
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(hidden(), isEmpty);
    await tester.tap(find.text('Next object'));
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(hidden(), hasLength(1));
    final index = hidden().single;
    expect(
      painter().document!.entities,
      isNot(contains(source.entities[index])),
    );

    await tester.tap(
      find.byKey(const ValueKey('architect-site-cad-show-hidden')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(find.text('Restore'), findsOneWidget);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(hidden(), isEmpty);
    expect(painter().document!.entities, source.entities);
    model.undo();
    await tester.pumpAndSettle();
    expect(hidden(), {index});
    model.redo();
    await tester.pumpAndSettle();
    expect(hidden(), isEmpty);
    await tester.tap(
      find.byKey(const ValueKey('architect-site-cad-show-hidden')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(workspace.screen(tester, const Offset(2.2, 2.12)));
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(hidden(), {2});
    expect(tester.takeException(), isNull);
  });
}
