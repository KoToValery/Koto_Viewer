import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';

class _TestToolPaletteHarness extends StatefulWidget {
  final ArchitectTool initialTool;
  final ValueChanged<ArchitectTool>? onToolChangedCallback;

  const _TestToolPaletteHarness({
    this.initialTool = ArchitectTool.select,
    this.onToolChangedCallback,
  });

  @override
  State<_TestToolPaletteHarness> createState() => _TestToolPaletteHarnessState();
}

class _TestToolPaletteHarnessState extends State<_TestToolPaletteHarness> {
  late ArchitectTool _tool = widget.initialTool;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        bottomNavigationBar: ArchitectToolPalette(
          activeTool: _tool,
          onToolChanged: (t) {
            setState(() => _tool = t);
            widget.onToolChangedCallback?.call(t);
          },
          activeZoneCategory: ArchitectZoneCategory.living,
          onZoneCategoryChanged: (_) {},
          wallThickness: 0.25,
          onWallThicknessChanged: (_) {},
          wallMode: WallDraftingMode.singleLine,
          onWallModeChanged: (_) {},
          doorWidth: 0.9,
          onDoorWidthChanged: (_) {},
          doorHeight: 2.1,
          onDoorHeightChanged: (_) {},
          doorSill: 0.0,
          onDoorSillChanged: (_) {},
          isHingeLeft: true,
          onHingeSideChanged: (_) {},
        ),
      ),
    );
  }
}

void main() {
  group('ArchitectToolPalette Tool Toggle/Deactivate Tests', () {
    testWidgets('Tapping an active tool button deactivates it back to ArchitectTool.select',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final toolEvents = <ArchitectTool>[];

      await tester.pumpWidget(
        _TestToolPaletteHarness(
          initialTool: ArchitectTool.wall,
          onToolChangedCallback: toolEvents.add,
        ),
      );
      await tester.pumpAndSettle();

      final wallBtn = find.byKey(const ValueKey('architect-tool-wall'));
      expect(wallBtn, findsOneWidget);

      // Tapping wall button when wall is active must deactivate it to select
      await tester.tap(wallBtn);
      await tester.pumpAndSettle();

      expect(toolEvents.last, equals(ArchitectTool.select));

      // Tapping wall button again when it is inactive must activate wall
      await tester.tap(wallBtn);
      await tester.pumpAndSettle();

      expect(toolEvents.last, equals(ArchitectTool.wall));

      // Tapping wall button a second time deactivates it again
      await tester.tap(wallBtn);
      await tester.pumpAndSettle();

      expect(toolEvents.last, equals(ArchitectTool.select));
    });

    testWidgets('Tapping another tool activates it, and repeated tap deactivates it',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final toolEvents = <ArchitectTool>[];

      await tester.pumpWidget(
        _TestToolPaletteHarness(
          initialTool: ArchitectTool.select,
          onToolChangedCallback: toolEvents.add,
        ),
      );
      await tester.pumpAndSettle();

      // In 'plan' category by default, zone tool is available
      final zoneBtn = find.byKey(const ValueKey('architect-tool-zone'));
      expect(zoneBtn, findsOneWidget);

      // Tap zone to activate
      await tester.tap(zoneBtn);
      await tester.pumpAndSettle();

      expect(toolEvents.last, equals(ArchitectTool.zone));

      // Tap zone again to deactivate
      await tester.tap(zoneBtn);
      await tester.pumpAndSettle();

      expect(toolEvents.last, equals(ArchitectTool.select));
    });

    testWidgets('Tapping select icon when select is already active keeps select',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final toolEvents = <ArchitectTool>[];

      await tester.pumpWidget(
        _TestToolPaletteHarness(
          initialTool: ArchitectTool.select,
          onToolChangedCallback: toolEvents.add,
        ),
      );
      await tester.pumpAndSettle();

      final selectBtn = find.byKey(const ValueKey('architect-tool-select'));
      expect(selectBtn, findsOneWidget);

      await tester.tap(selectBtn);
      await tester.pumpAndSettle();

      expect(toolEvents.last, equals(ArchitectTool.select));
    });
  });
}
