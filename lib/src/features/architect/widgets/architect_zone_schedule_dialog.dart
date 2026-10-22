import '../services/architect_apartment_zones.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import '../models/architect_zone_presets.dart';
import 'architect_zone_preset_field.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ZONE_SCHEDULE_DIALOG ===
//    - ArchitectZoneScheduleDialog (StatefulWidget)
//      * Table views (№, Room, Area, Perimeter, Floor, Walls, Ceiling, Height)
//      * Clipboard TSV export
//      * Drawing canvas table placement toggle
// =============================================================================

// === SECTION: ZONE_SCHEDULE_DIALOG ===

/// Interactive architectural room schedule table dialog.
/// Displays room areas, perimeters, floor/wall/ceiling finishes, clear heights,
/// and total net area summaries with drawing canvas placement and clipboard export.
class ArchitectZoneScheduleDialog extends StatefulWidget {
  final ArchitectUnit units;
  final String? initialApartmentId;
  final ArchitectZonePresets presets;
  final ArchitectStorey storey;
  final ValueChanged<ArchitectZone> onZoneUpdated;
  final ValueChanged<Offset?> onTableOriginChanged;

  const ArchitectZoneScheduleDialog({
    super.key,
    required this.storey,
    this.units = ArchitectUnit.meters,
    this.initialApartmentId,
    this.presets = const ArchitectZonePresets(),
    required this.onZoneUpdated,
    required this.onTableOriginChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required ArchitectStorey storey,
    ArchitectUnit units = ArchitectUnit.meters,
    String? initialApartmentId,
    ArchitectZonePresets presets = const ArchitectZonePresets(),
    required ValueChanged<ArchitectZone> onZoneUpdated,
    required ValueChanged<Offset?> onTableOriginChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ArchitectZoneScheduleDialog(
        storey: storey,
        units: units,
        initialApartmentId: initialApartmentId,
        presets: presets,
        onZoneUpdated: onZoneUpdated,
        onTableOriginChanged: onTableOriginChanged,
      ),
    );
  }

  @override
  State<ArchitectZoneScheduleDialog> createState() =>
      _ArchitectZoneScheduleDialogState();
}

class _ArchitectZoneScheduleDialogState
    extends State<ArchitectZoneScheduleDialog> {
  late List<ArchitectZone> _zones = List.of(widget.storey.zones);
  late String? _groupId = widget.initialApartmentId;
  late bool _placed = widget.storey.zoneScheduleOrigin != null;
  List<ArchitectZoneScheduleGroup> get _groups =>
      ArchitectApartmentZones.groups(widget.storey.copyWith(zones: _zones));
  ArchitectZoneScheduleGroup get _group =>
      _groups.where((g) => g.id == _groupId).firstOrNull ?? _groups.first;

  void _copyScheduleToClipboard() {
    final l = context.l10n;
    final group = _group;
    final buffer = StringBuffer(group.title(l))..writeln();
    buffer.writeln(
      [
        l.architectZoneNumberPrompt,
        l.architectZoneName,
        l.architectAreaWithUnit(widget.units.isImperial ? 'ft' : 'm'),
        l.architectZoneScheduleColPerimeter,
        l.architectZoneFloorFinish,
        l.architectZoneWallFinish,
        l.architectZoneCeilingFinish,
        l.architectZoneScheduleColHeight,
      ].join('\t'),
    );
    for (final room in group.rooms) {
      buffer.writeln(
        [
          room.number,
          room.name,
          widget.units.formatArea(room.area),
          widget.units.format(room.perimeter),
          room.resolvedFloorFinish(l),
          room.resolvedWallFinish(l),
          room.resolvedCeilingFinish(l),
          widget.units.format(room.clearHeight),
        ].join('\t'),
      );
    }
    if (group.apartment != null) {
      buffer.writeln(
        '${l.architectApartmentGross}\t${widget.units.formatArea(group.apartment!.area)}',
      );
    }
    buffer.writeln(
      '${l.architectApartmentNet}\t${widget.units.formatArea(group.netArea)}',
    );
    Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  void _togglePlacementOnDrawing() {
    widget.onTableOriginChanged(
      _placed
          ? null
          : Offset(
              widget.storey.zones.first.bounds.right + 1,
              widget.storey.zones.first.bounds.top,
            ),
    );
    setState(() => _placed = !_placed);
  }

  void _editZoneFinishes(ArchitectZone zone) {
    final l10n = context.l10n;
    final numberController = TextEditingController(text: zone.number);
    final nameController = TextEditingController(text: zone.name);
    final floorController = TextEditingController(
      text: zone.floorFinish.isNotEmpty
          ? zone.floorFinish
          : zone.resolvedFloorFinish(l10n),
    );
    final wallController = TextEditingController(
      text: zone.wallFinish.isNotEmpty
          ? zone.wallFinish
          : zone.resolvedWallFinish(l10n),
    );
    final ceilingController = TextEditingController(
      text: zone.ceilingFinish.isNotEmpty
          ? zone.ceilingFinish
          : zone.resolvedCeilingFinish(l10n),
    );
    final heightController = TextEditingController(
      text: BimDistanceUnit.trimZeros(zone.clearHeight.toStringAsFixed(2)),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(zone.category.icon, color: zone.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${zone.name} (${BimDistanceUnit.trimZeros(zone.area.toStringAsFixed(2))} m²)',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: numberController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.architectZoneScheduleColNo,
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0x33FFFFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ArchitectZonePresetField(
                        controller: nameController,
                        label: l10n.architectZoneName,
                        presets: [
                          for (final c in ArchitectZoneCategory.values)
                            widget.presets.categoryName(c, l10n),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ArchitectZonePresetField(
                  controller: floorController,
                  label: l10n.architectZoneFloorFinish,
                  presets: widget.presets.finishes('floor', l10n),
                ),
                const SizedBox(height: 12),
                ArchitectZonePresetField(
                  controller: wallController,
                  label: l10n.architectZoneWallFinish,
                  presets: widget.presets.finishes('wall', l10n),
                ),
                const SizedBox(height: 12),
                ArchitectZonePresetField(
                  controller: ceilingController,
                  label: l10n.architectZoneCeilingFinish,
                  presets: widget.presets.finishes('ceiling', l10n),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l10n.architectZoneClearHeight,
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0x33FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.architectZoneCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final newH = double.tryParse(heightController.text) ?? 2.60;
              final updated = zone.copyWith(
                number: numberController.text.trim(),
                name: nameController.text.trim(),
                floorFinish:
                    floorController.text.trim() ==
                        zone.resolvedFloorFinish(l10n)
                    ? zone.floorFinish
                    : floorController.text.trim(),
                wallFinish:
                    wallController.text.trim() == zone.resolvedWallFinish(l10n)
                    ? zone.wallFinish
                    : wallController.text.trim(),
                ceilingFinish:
                    ceilingController.text.trim() ==
                        zone.resolvedCeilingFinish(l10n)
                    ? zone.ceilingFinish
                    : ceilingController.text.trim(),
                clearHeight: newH,
              );
              widget.onZoneUpdated(updated);
              _zones = [
                for (final z in _zones) z.id == updated.id ? updated : z,
              ];
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Text(l10n.architectZoneSave),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final group = _group;
    final rows = [...group.rooms]..sort((a, b) => a.number.compareTo(b.number));
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.architectZoneScheduleTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              DropdownButton<String>(
                key: const ValueKey('zone-schedule-group'),
                isExpanded: true,
                value: group.id,
                items: [
                  for (final g in _groups)
                    DropdownMenuItem(
                      value: g.id,
                      child: Text(g.title(l), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => setState(() => _groupId = id),
              ),
              if (group.apartment != null)
                Text(
                  '${l.architectApartmentGross}: ${widget.units.formatArea(group.apartment!.area)}',
                ),
              Text(
                '${l.architectApartmentNet}: ${widget.units.formatArea(group.netArea)} · ${l.architectZoneScheduleRoomCount}: ${rows.length}',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataTextStyle: const TextStyle(color: Colors.black87),
                        headingTextStyle: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        columns: [
                          DataColumn(label: Text(l.architectZoneNumberPrompt)),
                          DataColumn(label: Text(l.architectZoneName)),
                          DataColumn(
                            label: Text(
                              l.architectAreaWithUnit(
                                widget.units.isImperial ? 'ft' : 'm',
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(l.architectZoneScheduleColPerimeter),
                            numeric: true,
                          ),
                          DataColumn(label: Text(l.architectZoneFloorFinish)),
                          DataColumn(label: Text(l.architectZoneWallFinish)),
                          DataColumn(label: Text(l.architectZoneCeilingFinish)),
                          DataColumn(
                            label: Text(l.architectZoneScheduleColHeight),
                            numeric: true,
                          ),
                        ],
                        rows: [
                          for (final room in rows)
                            DataRow(
                              cells: [
                                DataCell(Text(room.number)),
                                DataCell(
                                  Text(room.name),
                                  onTap: () => _editZoneFinishes(room),
                                ),
                                DataCell(
                                  Text(widget.units.formatArea(room.area)),
                                ),
                                DataCell(
                                  Text(widget.units.format(room.perimeter)),
                                ),
                                DataCell(
                                  Text(room.resolvedFloorFinish(l)),
                                  onTap: () => _editZoneFinishes(room),
                                ),
                                DataCell(
                                  Text(room.resolvedWallFinish(l)),
                                  onTap: () => _editZoneFinishes(room),
                                ),
                                DataCell(
                                  Text(room.resolvedCeilingFinish(l)),
                                  onTap: () => _editZoneFinishes(room),
                                ),
                                DataCell(
                                  Text(widget.units.format(room.clearHeight)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: _copyScheduleToClipboard,
                    child: Text(l.architectZoneScheduleCopy),
                  ),
                  TextButton(
                    onPressed: widget.storey.zones.isEmpty
                        ? null
                        : _togglePlacementOnDrawing,
                    child: Text(
                      _placed
                          ? l.architectZoneScheduleRemoveFromDrawing
                          : l.architectZoneSchedulePlaceOnDrawing,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
