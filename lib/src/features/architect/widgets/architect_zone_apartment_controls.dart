import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';

class ArchitectZoneApartmentControls extends StatelessWidget {
  final ArchitectZone zone;
  final List<ArchitectZone> zones;
  final ValueChanged<ArchitectZone> onChanged;
  final VoidCallback? onRooms;
  final ValueChanged<String>? onOpenApartment;
  const ArchitectZoneApartmentControls({
    super.key,
    required this.zone,
    required this.zones,
    required this.onChanged,
    this.onRooms,
    this.onOpenApartment,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final apartments = zones.where((z) => z.isApartment).toList();
    final parent = apartments
        .where((z) => z.id == zone.apartmentId)
        .firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<ArchitectZoneKind>(
          key: const ValueKey('zone-kind'),
          value: zone.kind,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E2230),
          style: const TextStyle(color: Colors.white),
          items: [
            DropdownMenuItem(
              value: ArchitectZoneKind.room,
              child: Text(l.architectRoom),
            ),
            DropdownMenuItem(
              value: ArchitectZoneKind.apartment,
              child: Text(l.architectApartment),
            ),
          ],
          onChanged: (kind) {
            if (kind != null) {
              onChanged(
                zone.copyWith(
                  kind: kind,
                  isAutoBoundary: kind == ArchitectZoneKind.apartment
                      ? false
                      : zone.isAutoBoundary,
                ),
              );
            }
          },
        ),
        if (zone.isApartment)
          Tooltip(
            message: l.architectApartmentRoomsHelp,
            child: OutlinedButton.icon(
              key: const ValueKey('apartment-rooms'),
              onPressed: onRooms,
              icon: const Icon(Icons.checklist),
              label: Text(
                '${l.architectApartmentRooms} · ${zones.where((z) => !z.isApartment && z.apartmentId == zone.id).length}',
              ),
            ),
          )
        else if (apartments.isNotEmpty)
          Tooltip(
            message: l.architectApartmentRoomsHelp,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    parent == null
                        ? l.architectUnassignedRooms
                        : '${l.architectApartment} ${parent.number}',
                    key: const ValueKey('zone-apartment'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (parent != null)
                  IconButton(
                    tooltip: l.architectApartment,
                    onPressed: () => onOpenApartment?.call(parent.id),
                    icon: const Icon(Icons.apartment, color: Colors.white70),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
