import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_overshoot_detector.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_overshoot_banner.dart';

void main() {
  group('ArchitectWallLayers junction cleanliness', () {
    test('uncut wall meeting cut wall does not penetrate into cut body', () {
      // Horizontal cut wall from (-3, 0) to (3, 0), thickness 0.25 m
      final cutWall = ArchitectWall(
        id: 'cutWall',
        startPoint: const Offset(-3, 0),
        endPoint: const Offset(3, 0),
        thickness: 0.25,
        height: 2.80,
      );
      // Vertical parapet starting at axis (0, 0) and going down to (0, -3), height 1.0 m (uncut at 1.2 m)
      final uncutWall = ArchitectWall(
        id: 'uncutWall',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(0, -3),
        thickness: 0.25,
        height: 1.0,
      );

      final layers = ArchitectWallLayers.build(
        [cutWall, uncutWall],
        const [],
        cutPlaneHeight: 1.20,
      );

      // Verify uncutBody does not contain points inside the cut wall core/body
      // Center of cut wall is (0, 0).
      expect(layers.body.contains(const Offset(0, 0)), isTrue);
      expect(layers.uncutBody.contains(const Offset(0, 0)), isFalse);

      // Point just below cut wall face: cut wall bottom face is y = -0.125
      expect(layers.uncutBody.contains(const Offset(0, -0.124)), isFalse);
      expect(layers.uncutBody.contains(const Offset(0, -0.50)), isTrue);
    });

    test('painter does not draw manual end cap lines across walls at T-junction or corner', () {
      final wHoriz = ArchitectWall(
        id: 'wH',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(5, 0),
        thickness: 0.25,
      );
      final wVert = ArchitectWall(
        id: 'wV',
        startPoint: const Offset(3, 0),
        endPoint: const Offset(3, -3),
        thickness: 0.25,
      );
      final project = ArchitectProject(
        id: 'p',
        name: 'test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [
          ArchitectStorey(
            id: 's',
            name: 'Story',
            elevation: 0,
            height: 3,
            walls: [wHoriz, wVert],
          ),
        ],
        activeStoreyId: 's',
      );

      final painter = Architect2dPainter(
        project: project,
        activeTool: ArchitectTool.select,
        zoomScale: 1.0,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(800, 600));
      expect(recorder.endRecording(), isNotNull);
    });
  });

  group('ArchitectWallOvershootDetector', () {
    test('detects overshoot at endPoint of wall and creates trim command', () {
      // Wall 1: horizontal, drawn from (0, 0) to (4.15, 0) (overshoots by 15 cm past x = 4.0)
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4.15, 0),
        thickness: 0.25,
      );
      // Wall 2: vertical, from (4.0, 0) to (4.0, 3.0)
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4.0, 0),
        endPoint: const Offset(4.0, 3.0),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0,
        height: 2.8,
        walls: [wall1, wall2],
      );

      final overshoots = ArchitectWallOvershootDetector.detectForWall(
        wall1,
        storey.walls,
      );

      expect(overshoots.length, 1);
      final os = overshoots.first;
      expect(os.wall.id, 'w1');
      expect(os.atStart, isFalse);
      expect(os.overshootCm, 15);
      expect(os.intersectionPoint.dx, closeTo(4.0, 0.001));
      expect(os.intersectionPoint.dy, closeTo(0.0, 0.001));

      // Test creating trim commands
      final commands = ArchitectWallOvershootDetector.createTrimCommands(
        storeyId: storey.id,
        overshoot: os,
      );

      expect(commands.length, 1);
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );
      final updated = commands.first.apply(project);
      final trimmed = updated.activeStorey.walls.firstWhere((w) => w.id == 'w1');

      expect(trimmed.endPoint.dx, closeTo(4.0, 0.001));
      expect(trimmed.endPoint.dy, closeTo(0.0, 0.001));
      expect(trimmed.length, closeTo(4.0, 0.001));
    });

    test('detects overshoot at startPoint of wall and creates trim command', () {
      // Wall 1: horizontal, drawn backwards from (4.0, 0) to (0.0, 0)
      // Wall 2: vertical, starting at (4.0, -0.20) and going up to (4.0, 3.0)
      // w2 overshoots by 20 cm before the corner (startPoint = (4.0, -0.20))
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4.0, 0),
        thickness: 0.25,
      );
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4.0, -0.20),
        endPoint: const Offset(4.0, 3.0),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0,
        height: 2.8,
        walls: [wall1, wall2],
      );

      final overshoots = ArchitectWallOvershootDetector.detectForWall(
        wall2,
        storey.walls,
      );

      expect(overshoots.length, 1);
      final os = overshoots.first;
      expect(os.wall.id, 'w2');
      expect(os.atStart, isTrue);
      expect(os.overshootCm, 20);

      final commands = ArchitectWallOvershootDetector.createTrimCommands(
        storeyId: storey.id,
        overshoot: os,
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );
      final updated = commands.first.apply(project);
      final trimmed = updated.activeStorey.walls.firstWhere((w) => w.id == 'w2');

      expect(trimmed.startPoint.dx, closeTo(4.0, 0.001));
      expect(trimmed.startPoint.dy, closeTo(0.0, 0.001));
    });

    test('detects X-crossing overshoot where both walls cross each other and trims both', () {
      // Wall 1: horizontal, from (0, 0) to (4.15, 0)
      // Wall 2: vertical, from (4.0, -0.25) to (4.0, 3.0)
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4.15, 0),
        thickness: 0.25,
      );
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4.0, -0.25),
        endPoint: const Offset(4.0, 3.0),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0,
        height: 2.8,
        walls: [wall1, wall2],
      );

      final overshoots = ArchitectWallOvershootDetector.detectForWall(
        wall1,
        storey.walls,
      );
      expect(overshoots.length, 1);
      final os = overshoots.first;
      expect(os.otherAlsoOvershoots, isTrue);
      expect(os.otherAtStart, isTrue);

      final commands = ArchitectWallOvershootDetector.createTrimCommands(
        storeyId: storey.id,
        overshoot: os,
      );
      expect(commands.length, 2);

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );
      var updated = project;
      for (final cmd in commands) {
        updated = cmd.apply(updated);
      }

      final t1 = updated.activeStorey.walls.firstWhere((w) => w.id == 'w1');
      final t2 = updated.activeStorey.walls.firstWhere((w) => w.id == 'w2');

      expect(t1.endPoint.dx, closeTo(4.0, 0.001));
      expect(t1.endPoint.dy, closeTo(0.0, 0.001));
      expect(t2.startPoint.dx, closeTo(4.0, 0.001));
      expect(t2.startPoint.dy, closeTo(0.0, 0.001));
    });

    test('ignores perfectly snapped junctions and intentional long through-walls', () {
      // Wall 1: perfectly snapped to corner (4.0, 0)
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4.0, 0),
        thickness: 0.25,
      );
      // Wall 2: through-wall extending 3 m past corner
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4.0, -3.0),
        endPoint: const Offset(4.0, 3.0),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0,
        height: 2.8,
        walls: [wall1, wall2],
      );

      final os1 = ArchitectWallOvershootDetector.detectForWall(wall1, storey.walls);
      expect(os1, isEmpty);

      final os2 = ArchitectWallOvershootDetector.detectForWall(wall2, storey.walls);
      expect(os2, isEmpty);
    });

    test('wall cut flush with outer face/insulation of perpendicular wall is NOT flagged as overshoot', () {
      // Vertical wall along x = 2.0 with outer face at x = 1.75 (25 cm thick, or core + insulation)
      final wallV = ArchitectWall(
        id: 'wallV',
        startPoint: const Offset(2.0, 0.0),
        endPoint: const Offset(2.0, 3.0),
        thickness: 0.25,
        referenceLine: WallReferenceLine.inner, // inner face at x = 2.0, outer face at x = 1.75
        exteriorSide: WallExteriorSide.left,
      );
      // Horizontal wall spanning across the top, starting flush with the outer face at x = 1.75
      final wallH = ArchitectWall(
        id: 'wallH',
        startPoint: const Offset(1.75, 3.125),
        endPoint: const Offset(6.0, 3.125),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0,
        height: 2.8,
        walls: [wallV, wallH],
      );

      final overshoots = ArchitectWallOvershootDetector.detectForWall(wallH, storey.walls);
      expect(overshoots, isEmpty, reason: 'Flush cut along insulation must not trigger overshoot banner');
    });

    test('wall protruding beyond outer face is trimmed flush to the face avoiding a gap', () {
      // Vertical wall along x = 2.0 with outer face at x = 1.75 (thickness: 0.25, referenceLine: inner)
      final wallV = ArchitectWall(
        id: 'wallV',
        startPoint: const Offset(2.0, 0.0),
        endPoint: const Offset(2.0, 3.0),
        thickness: 0.25,
        referenceLine: WallReferenceLine.inner,
        exteriorSide: WallExteriorSide.left,
      );
      // Horizontal wall carelessly drawn 20 cm past the outer face (startPoint at x = 1.55 instead of 1.75)
      final wallH = ArchitectWall(
        id: 'wallH',
        startPoint: const Offset(1.55, 3.125),
        endPoint: const Offset(6.0, 3.125),
        thickness: 0.25,
      );

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Floor 1',
        elevation: 0,
        height: 2.8,
        walls: [wallV, wallH],
      );

      final overshoots = ArchitectWallOvershootDetector.detectForWall(wallH, storey.walls);
      expect(overshoots.length, 1);
      final os = overshoots.first;
      // Overshoot should be 20 cm (the distance protruding into open air past outer face), not 45 cm
      expect(os.overshootCm, 20);
      // Trim point should be at the outer face x = 1.75, NOT at axis x = 2.0 which would leave a hole
      expect(os.intersectionPoint.dx, closeTo(1.75, 0.001));

      final commands = ArchitectWallOvershootDetector.createTrimCommands(
        storeyId: storey.id,
        overshoot: os,
      );
      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );
      final updated = commands.first.apply(project);
      final trimmed = updated.activeStorey.walls.firstWhere((w) => w.id == 'wallH');
      expect(trimmed.startPoint.dx, closeTo(1.75, 0.001));
    });
  });

  group('ArchitectWallOvershootBanner widget', () {
    testWidgets('renders localized overshoot banner and responds to trim and dismiss', (tester) async {
      final wall1 = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4.18, 0),
        thickness: 0.25,
      );
      final wall2 = ArchitectWall(
        id: 'w2',
        startPoint: const Offset(4.0, 0),
        endPoint: const Offset(4.0, 3.0),
        thickness: 0.25,
      );

      final overshoot = ArchitectWallOvershoot(
        wall: wall1,
        atStart: false,
        otherWall: wall2,
        intersectionPoint: const Offset(4.0, 0),
        overshootMeters: 0.18,
      );

      var trimmed = false;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Scaffold(
            body: ArchitectWallOvershootBanner(
              overshoot: overshoot,
              onTrim: () => trimmed = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Bulgarian text
      expect(find.text('Изскачащ край: 18 cm'), findsOneWidget);
      expect(find.text('Изчисти'), findsOneWidget);

      // Tap trim
      await tester.tap(find.byKey(const ValueKey('architect-overshoot-trim')));
      await tester.pump();
      expect(trimmed, isTrue);

      // Tap dismiss
      await tester.tap(find.byKey(const ValueKey('architect-overshoot-dismiss')));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });
}
