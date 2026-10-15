import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';

final toolsByIcon = {
  Icons.pan_tool_rounded: ArchitectTool.select,
  Icons.line_weight_rounded: ArchitectTool.wall,
  Icons.meeting_room_rounded: ArchitectTool.door,
  Icons.window_rounded: ArchitectTool.window,
  Icons.view_column_rounded: ArchitectTool.column,
  Icons.horizontal_rule_rounded: ArchitectTool.beam,
  Icons.layers_rounded: ArchitectTool.slab,
  Icons.crop_free_rounded: ArchitectTool.opening,
  Icons.stairs_rounded: ArchitectTool.stair,
  Icons.space_dashboard_rounded: ArchitectTool.zone,
  Icons.straighten_rounded: ArchitectTool.dimension,
  Icons.change_history_rounded: ArchitectTool.level,
  Icons.title_rounded: ArchitectTool.text,
  Icons.timeline_rounded: ArchitectTool.cadLine,
  Icons.crop_square_rounded: ArchitectTool.cadRect,
  Icons.radio_button_unchecked_rounded: ArchitectTool.cadCircle,
  Icons.grid_on_rounded: ArchitectTool.axis,
  Icons.square_foot_rounded: ArchitectTool.measure,
};

Future<void> prepare(WidgetTester tester, IconData icon) async {
  if (find.byIcon(icon).evaluate().isEmpty) {
    final category = ArchitectToolCategory.of(toolsByIcon[icon]!);
    await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('architect-category-${category.name}')),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byIcon(icon));
}

Future<void> choose(WidgetTester tester, IconData icon) async {
  await prepare(tester, icon);
  await tester.tap(find.byIcon(icon));
}
