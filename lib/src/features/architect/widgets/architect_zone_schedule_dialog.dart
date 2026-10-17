import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';

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
  final ArchitectStorey storey;
  final ValueChanged<ArchitectZone> onZoneUpdated;
  final ValueChanged<Offset?> onTableOriginChanged;

  const ArchitectZoneScheduleDialog({
    super.key,
    required this.storey,
    required this.onZoneUpdated,
    required this.onTableOriginChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required ArchitectStorey storey,
    required ValueChanged<ArchitectZone> onZoneUpdated,
    required ValueChanged<Offset?> onTableOriginChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ArchitectZoneScheduleDialog(
        storey: storey,
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
  void _copyScheduleToClipboard() {
    final l10n = context.l10n;
    final buffer = StringBuffer();

    // Headers
    buffer.writeln([
      l10n.architectZoneScheduleColNo,
      l10n.architectZoneScheduleColName,
      l10n.architectZoneScheduleColArea,
      l10n.architectZoneScheduleColPerimeter,
      l10n.architectZoneScheduleColFloor,
      l10n.architectZoneScheduleColWalls,
      l10n.architectZoneScheduleColCeiling,
      l10n.architectZoneScheduleColHeight,
    ].join('\t'));

    double totalArea = 0.0;
    final sortedZones = List<ArchitectZone>.from(widget.storey.zones)
      ..sort((a, b) => a.number.compareTo(b.number));

    for (int i = 0; i < sortedZones.length; i++) {
      final z = sortedZones[i];
      totalArea += z.area;
      buffer.writeln([
        z.number.isNotEmpty ? z.number : '${i + 1}',
        z.name,
        z.area.toStringAsFixed(2),
        z.perimeter.toStringAsFixed(2),
        z.resolvedFloorFinish(l10n),
        z.resolvedWallFinish(l10n),
        z.resolvedCeilingFinish(l10n),
        z.clearHeight.toStringAsFixed(2),
      ].join('\t'));
    }

    buffer.writeln();
    buffer.writeln('${l10n.architectZoneScheduleTotalArea}:\t${totalArea.toStringAsFixed(2)} m²');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.architectZoneScheduleCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _togglePlacementOnDrawing() {
    final l10n = context.l10n;
    final currentOrigin = widget.storey.zoneScheduleOrigin;
    if (currentOrigin != null) {
      widget.onTableOriginChanged(null);
      setState(() {});
    } else {
      // Default table placement near the top-left of the storey walls or (0, 0)
      double minX = 0;
      double minY = 0;
      if (widget.storey.walls.isNotEmpty) {
        minX = widget.storey.walls.first.startPoint.dx;
        minY = widget.storey.walls.first.startPoint.dy;
        for (final w in widget.storey.walls) {
          if (w.startPoint.dx < minX) minX = w.startPoint.dx;
          if (w.endPoint.dx < minX) minX = w.endPoint.dx;
          if (w.startPoint.dy < minY) minY = w.startPoint.dy;
          if (w.endPoint.dy < minY) minY = w.endPoint.dy;
        }
      }
      final defaultOrigin = Offset(minX - 14.0, minY);
      widget.onTableOriginChanged(defaultOrigin);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.architectZoneScheduleTablePlaced),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    final heightController =
        TextEditingController(text: zone.clearHeight.toStringAsFixed(2));

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
                '${zone.name} (${zone.area.toStringAsFixed(1)} m²)',
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
                        style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      child: TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: l10n.architectZoneName,
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
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: floorController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l10n.architectZoneFloorFinish,
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
                const SizedBox(height: 12),
                TextField(
                  controller: wallController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l10n.architectZoneWallFinish,
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
                const SizedBox(height: 12),
                TextField(
                  controller: ceilingController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l10n.architectZoneCeilingFinish,
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
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                floorFinish: floorController.text.trim(),
                wallFinish: wallController.text.trim(),
                ceilingFinish: ceilingController.text.trim(),
                clearHeight: newH,
              );
              widget.onZoneUpdated(updated);
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
    final l10n = context.l10n;
    final zones = widget.storey.zones;
    final sortedZones = List<ArchitectZone>.from(zones)
      ..sort((a, b) => a.number.compareTo(b.number));
    final totalArea = zones.fold<double>(0.0, (sum, z) => sum + z.area);
    final isPlacedOnDrawing = widget.storey.zoneScheduleOrigin != null;

    return Dialog(
      backgroundColor: const Color(0xF7151824),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x3338BDF8)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar: Title, Room count & Area badge, Close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.architectZoneScheduleTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${l10n.architectZoneScheduleRoomCount}: ${zones.length}  •  ${l10n.architectZoneScheduleTotalArea}: ${totalArea.toStringAsFixed(2)} m²',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(color: Color(0x22FFFFFF), height: 1),
              const SizedBox(height: 12),

              // 2. Schedule Data Table
              Expanded(
                child: zones.isEmpty
                    ? Center(
                        child: Text(
                          l10n.architectZoneScheduleNoRooms,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF1E293B),
                              ),
                              dataRowMinHeight: 38,
                              dataRowMaxHeight: 46,
                              columnSpacing: 18,
                              horizontalMargin: 12,
                              columns: [
                                DataColumn(
                                  label: Text(
                                    l10n.architectZoneScheduleColNo,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l10n.architectZoneScheduleColName,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: Text(
                                    l10n.architectZoneScheduleColArea,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: Text(
                                    l10n.architectZoneScheduleColPerimeter,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l10n.architectZoneScheduleColFloor,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l10n.architectZoneScheduleColWalls,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    l10n.architectZoneScheduleColCeiling,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: Text(
                                    l10n.architectZoneScheduleColHeight,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(''),
                                ),
                              ],
                              rows: [
                                for (int i = 0; i < sortedZones.length; i++)
                                  _buildDataRow(sortedZones[i], i, l10n),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 12),
              const Divider(color: Color(0x22FFFFFF), height: 1),
              const SizedBox(height: 12),

              // 3. Action Buttons Row: Copy Table, Place on Drawing, Close
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0x6638BDF8)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(l10n.architectZoneScheduleCopy),
                    onPressed: zones.isEmpty ? null : _copyScheduleToClipboard,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlacedOnDrawing
                          ? const Color(0x33FF5252)
                          : const Color(0x3300E676),
                      foregroundColor: isPlacedOnDrawing
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF00E676),
                      side: BorderSide(
                        color: isPlacedOnDrawing
                            ? const Color(0x66FF5252)
                            : const Color(0x6600E676),
                      ),
                    ),
                    icon: Icon(
                      isPlacedOnDrawing
                          ? Icons.layers_clear_rounded
                          : Icons.post_add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isPlacedOnDrawing
                          ? l10n.architectZoneScheduleRemoveFromDrawing
                          : l10n.architectZoneSchedulePlaceOnDrawing,
                    ),
                    onPressed: zones.isEmpty ? null : _togglePlacementOnDrawing,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.architectZoneCancel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(ArchitectZone z, int index, dynamic l10n) {
    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: z.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: z.color.withValues(alpha: 0.5)),
            ),
            child: Text(
              z.number.isNotEmpty ? z.number : '${index + 1}',
              style: TextStyle(
                color: z.color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(z.category.icon, size: 16, color: z.color),
              const SizedBox(width: 6),
              Text(
                z.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            '${z.area.toStringAsFixed(2)} m²',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Text(
            '${z.perimeter.toStringAsFixed(2)} m',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            z.resolvedFloorFinish(l10n),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            z.resolvedWallFinish(l10n),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            z.resolvedCeilingFinish(l10n),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            '${z.clearHeight.toStringAsFixed(2)} m',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            color: const Color(0xFF38BDF8),
            tooltip: l10n.architectZoneProperties,
            onPressed: () => _editZoneFinishes(z),
          ),
        ),
      ],
    );
  }
}
