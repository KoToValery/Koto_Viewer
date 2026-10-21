import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';

Future<void> showArchitectApartmentRooms(
  BuildContext context,
  ArchitectZone apartment,
  List<ArchitectZone> zones,
) {
  final rooms =
      ArchitectZone.normalizeMemberships(
          zones,
        ).where((z) => !z.isApartment && z.apartmentId == apartment.id).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .78,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              '${l.architectApartment} ${apartment.number}',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            Row(
              children: [
                Expanded(
                  child: Text('${l.architectApartmentRooms} · ${rooms.length}'),
                ),
                Tooltip(
                  message: l.architectApartmentRoomsHelp,
                  child: Chip(label: Text(l.architectApartmentAutoAssignment)),
                ),
              ],
            ),
            Expanded(
              child: rooms.isEmpty
                  ? Center(child: Text(l.architectApartmentNoRooms))
                  : ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (_, index) {
                        final room = rooms[index];
                        return ListTile(
                          key: ValueKey('apartment-room-${room.id}'),
                          leading: const Icon(Icons.meeting_room_outlined),
                          title: Text(
                            '${room.number} · ${room.name}',
                            maxLines: 2,
                          ),
                        );
                      },
                    ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.close),
            ),
          ],
        ),
      ),
    ),
  );
}
