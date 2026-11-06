import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_painter_helper.dart';

void main() {
  group('ArchitectZoneScheduleTable Selection & Bounds', () {
    test('scheduleTables returns table even when storey.zones is empty', () {
      final starter = ArchitectProject.starter(name: 'Test');
      final storey = starter.activeStorey.copyWith(
        zoneScheduleOrigin: const Offset(10, 10),
        zones: const [], // No zones!
      );
      final project = starter.updateActiveStorey(storey);

      final tables = ArchitectZonePainterHelper.scheduleTables(
        project: project,
        storey: storey,
        zoomScale: 1.0,
      );

      // Table should be generated so it can be rendered and hit-tested
      expect(tables.isNotEmpty, isTrue);
      final table = tables.first;
      expect(table.origin, const Offset(10, 10));
      expect(table.bounds.width, greaterThan(0));
      expect(table.bounds.height, greaterThan(0));
      expect(table.bounds.contains(const Offset(10.5, 10.5)), isTrue);
    });

    test('Clearing zoneScheduleOrigin removes table from scheduleTables', () {
      final starter = ArchitectProject.starter(name: 'Test');
      var storey = starter.activeStorey.copyWith(
        zoneScheduleOrigin: const Offset(10, 10),
        zones: const [],
      );

      var tables = ArchitectZonePainterHelper.scheduleTables(
        storey: storey,
        zoomScale: 1.0,
      );
      expect(tables.isNotEmpty, isTrue);

      // Remove table (as done by _removeZoneScheduleTable)
      storey = storey.copyWith(clearZoneScheduleOrigin: true);

      tables = ArchitectZonePainterHelper.scheduleTables(
        storey: storey,
        zoomScale: 1.0,
      );
      expect(tables.isEmpty, isTrue);
    });
  });
}
