import 'dart:ui';
import '../models/architect_wall.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_zone.dart';
import '../models/architect_project.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class ArchitectZoneScheduleGroup {
  final ArchitectZone? apartment;
  final List<ArchitectZone> rooms;
  const ArchitectZoneScheduleGroup(this.apartment, this.rooms);
  String get id => apartment?.id ?? 'unassigned';
  double get netArea => rooms.fold(0, (area, room) => area + room.area);
  String title(AppLocalizations l) => apartment == null
      ? l.architectUnassignedRooms
      : '${l.architectApartment} ${apartment!.number}${apartment!.name.isEmpty || apartment!.name == l.architectApartment ? '' : ' · ${apartment!.name}'}';
  ArchitectStorey tableStorey(ArchitectStorey storey, AppLocalizations l) =>
      storey.copyWith(
        name: apartment == null && !storey.zones.any((z) => z.isApartment)
            ? storey.name
            : title(l),
        zones: rooms,
      );
}

class ArchitectApartmentZones {
  /// Only the requested measurement lines participate: exterior faces and
  /// interior core axes. Do not silently snap a gross outline to a clear face.
  static Offset? snapBoundary(
    Offset raw,
    List<ArchitectWall> walls,
    double tolerance,
  ) {
    Offset? best;
    var distance = tolerance;
    final nearby = <(Offset, Offset)>[];
    for (final wall in walls) {
      final offset =
          wall.centerLineOffset +
          (wall.isExterior
              ? wall.exteriorSign * wall.thickness / 2
              : -wall.exteriorSign * wall.coreAsymmetry / 2);
      final arc = wall.arc;
      final a =
          arc?.pointAt(0, leftOffset: offset) ??
          wall.startPoint + wall.normalVector * offset;
      final b =
          arc?.pointAt(1, leftOffset: offset) ??
          wall.endPoint + wall.normalVector * offset;
      final point = arc == null
          ? BimLineGeometry.closest(raw, a, b)
          : arc.pointAt(arc.parameter(raw).clamp(0.0, 1.0), leftOffset: offset);
      final d = (point - raw).distance;
      if (d <= distance) {
        best = point;
        distance = d;
      }
      if (arc == null && d <= tolerance) nearby.add((a, b));
    }
    Offset? junction;
    var junctionDistance = tolerance;
    for (var i = 0; i < nearby.length; i++) {
      for (var j = i + 1; j < nearby.length; j++) {
        final q = BimLineGeometry.intersection(
          nearby[i].$1,
          nearby[i].$2,
          nearby[j].$1,
          nearby[j].$2,
          firstFinite: false,
          secondFinite: false,
        );
        if (q != null && (q - raw).distance <= junctionDistance) {
          junction = q;
          junctionDistance = (q - raw).distance;
        }
      }
    }
    return junction ?? best;
  }

  static List<ArchitectZoneScheduleGroup> groups(ArchitectStorey storey) {
    final apartments = storey.zones.where((z) => z.isApartment).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final ids = apartments.map((a) => a.id).toSet();
    final rooms = storey.zones.where((z) => !z.isApartment).toList();
    final unassigned = rooms
        .where((r) => !ids.contains(r.apartmentId))
        .toList();
    return [
      if (unassigned.isNotEmpty || apartments.isEmpty)
        ArchitectZoneScheduleGroup(null, unassigned),
      for (final apartment in apartments)
        ArchitectZoneScheduleGroup(
          apartment,
          rooms.where((r) => r.apartmentId == apartment.id).toList(),
        ),
    ];
  }
}
