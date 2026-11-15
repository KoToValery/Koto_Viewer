import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_line_editing.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_angle_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectCommandController _beamProjectCommands({
  ArchitectStructuralScheme scheme = ArchitectStructuralScheme.flatSlab,
  List<ArchitectBeam> beams = const [],
}) => ArchitectCommandController(
  ArchitectProject(
    id: 'p-beam',
    name: 'Beams',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    structuralScheme: scheme,
    activeStoreyId: 's',
    storeys: [
      ArchitectStorey(
        id: 's',
        name: 'Ground',
        height: 3.0,
        beams: beams,
      ),
    ],
  ),
);

Future<void> _enterKeypadNumber(
  WidgetTester tester,
  Finder chip,
  List<String> keys,
) async {
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
  for (final k in keys) {
    if (k == '±') {
      await tester.tap(find.text('±'));
    } else {
      await tester.tap(find.byKey(ValueKey('bim-number-key-$k')));
    }
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Beam scheme defaults & linear endpoint commands', () {
    test('beamDefaultsForScheme returns defaults for all schemes', () {
      expect(
        ArchitectElementTool.beamDefaultsForScheme(
          ArchitectStructuralScheme.flatSlab,
        ),
        (width: 0.25, depth: 0.40),
      );
      expect(
        ArchitectElementTool.beamDefaultsForScheme(
          ArchitectStructuralScheme.beamAndSlab,
        ),
        (width: 0.25, depth: 0.50),
      );
      expect(
        ArchitectElementTool.beamDefaultsForScheme(
          ArchitectStructuralScheme.sandwichPanels,
        ),
        (width: 0.20, depth: 0.40),
      );
      expect(
        ArchitectElementTool.beamDefaultsForScheme(
          ArchitectStructuralScheme.roundLogs,
        ),
        (width: 0.18, depth: 0.24),
      );
      expect(
        ArchitectElementTool.beamDefaultsForScheme(
          ArchitectStructuralScheme.studFrame,
        ),
        (width: 0.14, depth: 0.24),
      );
    });

    test(
      'applyBeamSchemeDefaults and setBeamParams propagate to placeBeam',
      () {
        final tool = ArchitectElementTool()
          ..applyBeamSchemeDefaults(
            ArchitectStructuralScheme.beamAndSlab,
            resetVertical: true,
          );
        expect(tool.beamWidth, 0.25);
        expect(tool.beamDepth, 0.50);
        expect(tool.beamBaseOffset, 2.20);

        tool.setBeamParams(width: 0.30, depth: 0.60, baseOffset: -0.20);
        final res = tool.placeBeam(
          storey: const ArchitectStorey(id: 's', name: 'Ground'),
          start: Offset.zero,
          end: const Offset(4, 0),
        );
        expect(res, isNotNull);
        final beam = res!.$2;
        expect(beam.width, 0.30);
        expect(beam.depth, 0.60);
        expect(beam.baseOffset, -0.20);
        expect(beam.label, 'B 30/60');
      },
    );

    test(
      'UpdateArchitectBeam and ArchitectLineEditing.adapt update endpoints with undo',
      () {
        final beam = const ArchitectBeam(
          id: 'b1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          width: 0.30,
          depth: 0.55,
          baseOffset: 2.15,
          label: 'Г-1',
        );
        final controller = _beamProjectCommands(beams: [beam]);
        addTearDown(controller.dispose);

        final adapted = ArchitectLineEditing.adapt(
          controller.project,
          UpdateArchitectWall(
            storeyId: 's',
            wall: ArchitectLineEditing.beamSegment(beam).copyWith(
              startPoint: const Offset(-1.5, 0),
              endPoint: const Offset(5.2, 0),
            ),
          ),
        );
        expect(adapted, isA<UpdateArchitectBeam>());
        controller.execute(adapted);

        final moved = controller.project.activeStorey.beams.single;
        expect(moved.startPoint, const Offset(-1.5, 0));
        expect(moved.endPoint, const Offset(5.2, 0));
        expect(moved.width, 0.30);
        expect(moved.depth, 0.55);
        expect(moved.baseOffset, 2.15);
        expect(moved.label, 'Г-1');

        controller.undo();
        final undone = controller.project.activeStorey.beams.single;
        expect(undone.startPoint, Offset.zero);
        expect(undone.endPoint, const Offset(4, 0));

        controller.redo();
        expect(
          controller.project.activeStorey.beams.single.endPoint,
          const Offset(5.2, 0),
        );

        expect(
          () => controller.execute(
            const UpdateArchitectBeam(
              storeyId: 's',
              beamId: 'b1',
              startPoint: Offset.zero,
              endPoint: Offset(0.01, 0),
            ),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('Beam quick menu (placement & selection)', () {
    testWidgets(
      'Placement sub-bar uses scheme defaults, keypad W/D/baseOffset, and places configured beam',
      (tester) async {
        final model = _beamProjectCommands(
          scheme: ArchitectStructuralScheme.beamAndSlab,
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.choose(tester, Icons.horizontal_rule_rounded);
        await tester.pumpAndSettle();

        expect(find.text('25x40 cm'), findsNothing);
        expect(find.text('25x50 cm'), findsNothing);
        expect(find.text('25x60 cm'), findsNothing);

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('beam-width-input')),
            matching: find.text('25 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('beam-depth-input')),
            matching: find.text('50 cm'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('beam-base-offset-input')),
            matching: find.text('220 cm'),
          ),
          findsOneWidget,
        );

        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-width-input')),
          ['3', '0'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-depth-input')),
          ['6', '0'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-base-offset-input')),
          ['1', '5', '±'],
        );

        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(4, 0));
        await tester.pumpAndSettle();

        final beam = model.project.activeStorey.beams.single;
        expect(beam.width, closeTo(0.30, 1e-6));
        expect(beam.depth, closeTo(0.60, 1e-6));
        expect(beam.baseOffset, closeTo(-0.15, 1e-6));
        expect(beam.label, 'B 30/60');
      },
    );

    testWidgets(
      'Selecting an existing beam opens quick menu, edits W/D/offset with undo, and preserves custom label',
      (tester) async {
        const autoBeam = ArchitectBeam(
          id: 'b-auto',
          startPoint: Offset(-2, 0),
          endPoint: Offset(2, 0),
          width: 0.25,
          depth: 0.50,
          baseOffset: 2.20,
          label: 'B 25/50',
        );
        const customBeam = ArchitectBeam(
          id: 'b-custom',
          startPoint: Offset(-2, 2),
          endPoint: Offset(2, 2),
          width: 0.25,
          depth: 0.45,
          baseOffset: 2.00,
          label: 'Г1',
        );
        final model = _beamProjectCommands(beams: [autoBeam, customBeam]);
        addTearDown(model.dispose);
        await workspace.open(tester, model);

        // Quick-tap in Pan/navigation mode selects the auto-labeled beam.
        await workspace.wallTap(tester, const Offset(0, 0));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, 'b-auto');
        expect(find.byKey(const ValueKey('beam-width-input')), findsOneWidget);
        expect(find.byKey(const ValueKey('beam-depth-input')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('beam-base-offset-input')),
          findsOneWidget,
        );

        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-width-input')),
          ['3', '5'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-depth-input')),
          ['6', '5'],
        );
        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-base-offset-input')),
          ['2', '5', '±'],
        );

        final edited = model.project.activeStorey.beams.first;
        expect(edited.width, closeTo(0.35, 1e-6));
        expect(edited.depth, closeTo(0.65, 1e-6));
        expect(edited.baseOffset, closeTo(-0.25, 1e-6));
        expect(edited.label, 'B 35/65');

        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.beams.first.baseOffset, 2.20);

        // Select custom-labeled beam in Select mode and verify label stays 'Г1'.
        await tool_ui.choose(tester, Icons.near_me_outlined);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(0, 2));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, 'b-custom');

        await _enterKeypadNumber(
          tester,
          find.byKey(const ValueKey('beam-depth-input')),
          ['7', '0'],
        );
        final editedCustom = model.project.activeStorey.beams.last;
        expect(editedCustom.depth, closeTo(0.70, 1e-6));
        expect(editedCustom.label, 'Г1');
      },
    );
  });

  group('Beam two-way endpoint dragging with offset lines', () {
    testWidgets(
      'Selected beam drags both start and end via offset handles (extending and shortening) with leader line and undo',
      (tester) async {
        const beam = ArchitectBeam(
          id: 'b1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          width: 0.25,
          depth: 0.50,
          baseOffset: 2.20,
          label: 'B 25/50',
        );
        final model = _beamProjectCommands(beams: [beam]);
        addTearDown(model.dispose);
        await workspace.open(tester, model);

        // Disable magnetic snap to avoid accidental snap shifts on exact test coords,
        // and zoom out slightly so both extended endpoints stay well inside the viewport.
        await tool_ui.setMagnetic(tester, false);
        workspace.camera(tester).fit(const Rect.fromLTRB(-3, -2, 7, 2));
        await tester.pumpAndSettle();

        // Quick-tap midpoint of beam in Pan mode -> selects beam and shows offset handles + lock.
        await workspace.wallTap(tester, const Offset(2, 0));
        await tester.pumpAndSettle();

        final painter = workspace.overlay(tester);
        expect(painter.selectedElementId, 'b1');
        expect(painter.handleOffsetLength, greaterThan(0));
        expect(
          find.byKey(const ValueKey('architect-wall-angle-lock')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ArchitectWallAngleControl>(
                find.byType(ArchitectWallAngleControl),
              )
              .locked,
          isTrue,
        );

        final scale = workspace.camera(tester).scale;
        final clearance = painter.handleOffsetLength / scale;
        final endHandle = Offset(4 + clearance, 0);
        final dragEnd = await tester.startGesture(
          workspace.screen(tester, endHandle),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        // Pull outward with slight Y drift; locked mode keeps Y = 0 while extending endPoint.
        await dragEnd.moveTo(
          workspace.screen(tester, Offset(5.6 + clearance, 0.08)),
        );
        await tester.pump();
        expect(
          workspace.overlay(tester).wallEndpointLeaderLine,
          isNotNull,
        );
        await dragEnd.up();
        await tester.pumpAndSettle();

        var b = model.project.activeStorey.beams.single;
        expect(b.startPoint, Offset.zero);
        expect(b.endPoint.dx, closeTo(5.6, 0.01));
        expect(b.endPoint.dy, closeTo(0.0, 1e-6));
        expect(b.width, 0.25);
        expect(b.depth, 0.50);
        expect(b.baseOffset, 2.20);

        // Now drag START offset handle outward to x = -1.2 (stretching leftwards).
        final startHandle = Offset(0 - clearance, 0);
        final dragStartOut = await tester.startGesture(
          workspace.screen(tester, startHandle),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        await dragStartOut.moveTo(
          workspace.screen(tester, Offset(-1.2 - clearance, -0.06)),
        );
        await tester.pump();
        expect(
          workspace.overlay(tester).wallEndpointLeaderLine,
          isNotNull,
        );
        await dragStartOut.up();
        await tester.pumpAndSettle();

        b = model.project.activeStorey.beams.single;
        expect(b.startPoint.dx, closeTo(-1.2, 0.01));
        expect(b.startPoint.dy, closeTo(0.0, 1e-6));
        expect(b.endPoint.dx, closeTo(5.6, 0.01));

        // Now pull START offset handle inward to x = 1.0 (shortening from left end).
        final shiftedStartHandle = Offset(b.startPoint.dx - clearance, 0);
        final dragStartIn = await tester.startGesture(
          workspace.screen(tester, shiftedStartHandle),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        await dragStartIn.moveTo(
          workspace.screen(tester, Offset(1.0 - clearance, 0)),
        );
        await tester.pump();
        await dragStartIn.up();
        await tester.pumpAndSettle();

        b = model.project.activeStorey.beams.single;
        expect(b.startPoint.dx, closeTo(1.0, 0.01));
        expect(b.endPoint.dx, closeTo(5.6, 0.01));

        // Undo brings startPoint back to -1.2; redo restores 1.0.
        await tester.tap(find.byKey(const ValueKey('architect-undo')));
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.beams.single.startPoint.dx,
          closeTo(-1.2, 0.01),
        );
        await tester.tap(find.byKey(const ValueKey('architect-redo')));
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.beams.single.startPoint.dx,
          closeTo(1.0, 0.01),
        );
      },
    );

    testWidgets(
      'Unlocking beam angle allows diagonal endpoint drag via offset handle',
      (tester) async {
        const beam = ArchitectBeam(
          id: 'b1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
        );
        final model = _beamProjectCommands(beams: [beam]);
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.setMagnetic(tester, false);
        await tester.pumpAndSettle();

        await workspace.wallTap(tester, const Offset(2, 0));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('architect-wall-angle-lock')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ArchitectWallAngleControl>(
                find.byType(ArchitectWallAngleControl),
              )
              .locked,
          isFalse,
        );

        final clearance =
            workspace.overlay(tester).handleOffsetLength /
            workspace.camera(tester).scale;
        final dragEnd = await tester.startGesture(
          workspace.screen(tester, Offset(4 + clearance, 0)),
        );
        await tester.pump();
        await dragEnd.moveTo(
          workspace.screen(tester, Offset(5.0 + clearance, 2.0)),
        );
        await tester.pump();
        await dragEnd.up();
        await tester.pumpAndSettle();

        final updated = model.project.activeStorey.beams.single;
        expect(updated.startPoint, Offset.zero);
        expect(updated.endPoint.dx, closeTo(5.0, 0.02));
        expect(updated.endPoint.dy, closeTo(2.0, 0.02));
      },
    );

    testWidgets(
      'Unselected beam endpoint can be grabbed directly in Select mode',
      (tester) async {
        const beam = ArchitectBeam(
          id: 'b1',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
        );
        final model = _beamProjectCommands(beams: [beam]);
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.setMagnetic(tester, false);
        await tester.pumpAndSettle();

        await tool_ui.choose(tester, Icons.near_me_outlined);
        await tester.pumpAndSettle();

        final g = await tester.startGesture(
          workspace.screen(tester, const Offset(4, 0)),
        );
        await tester.pump();
        await g.moveTo(workspace.screen(tester, const Offset(6, 0)));
        await tester.pump();
        await g.up();
        await tester.pumpAndSettle();

        final updated = model.project.activeStorey.beams.single;
        expect(updated.startPoint, Offset.zero);
        expect(updated.endPoint.dx, closeTo(6.0, 0.02));
        expect(updated.endPoint.dy, closeTo(0.0, 1e-6));
      },
    );
  });

  group('Beam slope option (model, 3D, section, quick menu & properties)', () {
    test(
      'ArchitectBeam slopeDegrees serializes cleanly and computes rise, cut/overhead range & vertical depth',
      () {
        const legacyJson = {
          'id': 'b-legacy',
          'startPoint': {'x': 0.0, 'y': 0.0},
          'endPoint': {'x': 4.0, 'y': 0.0},
          'width': 0.25,
          'depth': 0.50,
          'baseOffset': 2.20,
        };
        final legacy = ArchitectBeam.fromJson(legacyJson);
        expect(legacy.slopeDegrees, 0.0);
        expect(legacy.endBaseOffset, closeTo(2.20, 1e-6));

        const sloped = ArchitectBeam(
          id: 'b-sloped',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          width: 0.25,
          depth: 0.50,
          baseOffset: 0.20,
          slopeDegrees: 30.0,
        );
        final decoded = ArchitectBeam.fromJson(sloped.toJson());
        expect(decoded.slopeDegrees, closeTo(30.0, 1e-6));
        expect(decoded.endBaseOffset, closeTo(0.20 + 4.0 * math.tan(math.pi / 6), 1e-4));
        expect(decoded.verticalDepth, closeTo(0.50 / math.cos(math.pi / 6), 1e-4));
        expect(decoded.slopedLength, closeTo(4.0 / math.cos(math.pi / 6), 1e-4));

        // Cut plane at 1.50 m passes through the rising span, while 0.10 m sees it overhead.
        expect(sloped.isCutAt(1.50), isTrue);
        expect(sloped.isOverheadAt(1.50), isFalse);
        expect(sloped.isOverheadAt(0.10), isTrue);
        expect(sloped.isCutAt(0.10), isFalse);

        final tool = ArchitectElementTool()
          ..setBeamParams(slopeDegrees: -12.5);
        final placed = tool.placeBeam(
          storey: const ArchitectStorey(id: 's', name: 'Ground'),
          start: Offset.zero,
          end: const Offset(3, 0),
        );
        expect(placed!.$2.slopeDegrees, closeTo(-12.5, 1e-6));
        tool.applyBeamSchemeDefaults(
          ArchitectStructuralScheme.flatSlab,
          resetVertical: true,
        );
        expect(tool.beamSlopeDegrees, 0.0);
      },
    );

    test(
      'Sloped beam propagates to 3D mesh and building section geometry',
      () {
        const sloped = ArchitectBeam(
          id: 'b-3d',
          startPoint: Offset(0, 0),
          endPoint: Offset(4, 0),
          width: 0.30,
          depth: 0.50,
          baseOffset: 2.00,
          slopeDegrees: 15.0,
        );
        final sectionCut = ArchitectSection(
          id: 'sec-beam',
          name: 'A-A',
          start: const Offset(-1, 0),
          end: const Offset(5, 0),
        );
        final project = ArchitectProject(
          id: 'p-slope-3d',
          name: 'Slope3D',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's',
          storeys: const [
            ArchitectStorey(
              id: 's',
              name: 'Ground',
              elevation: 0.0,
              height: 4.0,
              beams: [sloped],
            ),
          ],
          sections: [sectionCut],
        );

        final mesh = Architect3dBuilder.buildProjectMesh(project);
        final tris = mesh.triangles;
        expect(tris, isNotEmpty);
        final startZ = <double>[];
        final endZ = <double>[];
        for (final t in tris) {
          for (final v in [t.v0, t.v1, t.v2]) {
            if ((v.x - 0.0).abs() < 1e-4) startZ.add(v.z);
            if ((v.x - 4.0).abs() < 1e-4) endZ.add(v.z);
          }
        }
        expect(startZ, isNotEmpty);
        expect(endZ, isNotEmpty);
        expect(startZ.reduce(math.min), closeTo(2.00, 1e-4));
        expect(
          startZ.reduce(math.max),
          closeTo(2.00 + sloped.verticalDepth, 1e-4),
        );
        expect(endZ.reduce(math.min), closeTo(sloped.endBaseOffset, 1e-4));
        expect(
          endZ.reduce(math.max),
          closeTo(sloped.endBaseOffset + sloped.verticalDepth, 1e-4),
        );

        final sec = ArchitectBuildingSection.build(project, sectionCut);
        final beamRegion = sec.regions.singleWhere((r) => r.sourceId == 'b-3d');
        final bounds = beamRegion.path.getBounds();
        expect(bounds.top, closeTo(2.00, 0.02));
        expect(
          bounds.bottom,
          closeTo(sloped.endBaseOffset + sloped.verticalDepth, 0.02),
        );
      },
    );

    testWidgets(
      'Beam placement and selection sub-bars expose keypad Slope (positive & negative with undo)',
      (tester) async {
        final model = _beamProjectCommands();
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.choose(tester, Icons.horizontal_rule_rounded);
        await tester.pumpAndSettle();

        final slopeChip = find.byKey(const ValueKey('beam-slope-input'));
        await tester.ensureVisible(slopeChip);
        expect(
          find.descendant(of: slopeChip, matching: find.text('0°')),
          findsOneWidget,
        );

        await _enterKeypadNumber(tester, slopeChip, ['1', '5']);
        expect(
          find.descendant(of: slopeChip, matching: find.text('15°')),
          findsOneWidget,
        );

        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(4, 0));
        await tester.pumpAndSettle();

        final placed = model.project.activeStorey.beams.single;
        expect(placed.slopeDegrees, closeTo(15.0, 1e-6));

        // Switch to Pan mode and select the beam to edit slope negatively.
        await tool_ui.choose(tester, Icons.pan_tool_rounded);
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(2, 0));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, placed.id);

        await tester.ensureVisible(slopeChip);
        await _enterKeypadNumber(tester, slopeChip, ['1', '0', '±']);
        expect(
          model.project.activeStorey.beams.single.slopeDegrees,
          closeTo(-10.0, 1e-6),
        );

        await tester.tap(find.byKey(const ValueKey('architect-undo')));
        await tester.pumpAndSettle();
        expect(
          model.project.activeStorey.beams.single.slopeDegrees,
          closeTo(15.0, 1e-6),
        );
      },
    );

    testWidgets(
      'Beam properties dialog exposes and edits slopeDegrees',
      (tester) async {
        const beam = ArchitectBeam(
          id: 'b-prop',
          startPoint: Offset(-2, 0),
          endPoint: Offset(2, 0),
          slopeDegrees: 5.0,
        );
        final model = _beamProjectCommands(beams: [beam]);
        addTearDown(model.dispose);
        await workspace.open(tester, model);

        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, 'b-prop');

        await tester.tap(
          find.byKey(const ValueKey('architect-selection-properties')),
        );
        await tester.pumpAndSettle();

        final slopeField = find.byKey(
          const ValueKey('architect-property-slopeDegrees'),
        );
        await tester.ensureVisible(slopeField);
        expect(slopeField, findsOneWidget);
        await tester.tap(slopeField);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bim-number-key-1')));
        await tester.tap(find.byKey(const ValueKey('bim-number-key-8')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('bim-numeric-dialog-apply')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
        await tester.pumpAndSettle();

        expect(
          model.project.activeStorey.beams.single.slopeDegrees,
          closeTo(18.0, 1e-6),
        );
      },
    );
  });
}
