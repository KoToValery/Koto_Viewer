import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../services/architect_zone_tool.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ZONE_PROPERTIES_CARD ===
//    - ArchitectZonePropertiesCard (StatefulWidget)
//      * Header: Number badge, Category dropdown, Area chip, Delete & Close
//      * Finishes summary bar: Floor, Wall, Ceiling (tap to edit details)
//      * Dynamic boundaries switch (Auto dynamic vs Manual fixed)
//      * Edit details dialog (Number, Name, Finishes presets, Clear height)
// =============================================================================

// === SECTION: ZONE_PROPERTIES_CARD ===

/// Floating property inspector for the currently selected functional zone / room space.
/// Optimized for mobile: sleek, minimal vertical footprint, dropdown room category selector,
/// dynamic boundary toggle, and finishes inspector.
class ArchitectZonePropertiesCard extends StatefulWidget {
  final ArchitectZone zone;
  final ArchitectZoneTool? tool;
  final ValueChanged<ArchitectZone> onZoneUpdated;
  final VoidCallback onDeleteZone;
  final VoidCallback onClose;
  final VoidCallback? onOpenScheduleTable;

  const ArchitectZonePropertiesCard({
    super.key,
    required this.zone,
    this.tool,
    required this.onZoneUpdated,
    required this.onDeleteZone,
    required this.onClose,
    this.onOpenScheduleTable,
  });

  @override
  State<ArchitectZonePropertiesCard> createState() =>
      _ArchitectZonePropertiesCardState();
}

class _ArchitectZonePropertiesCardState
    extends State<ArchitectZonePropertiesCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zone = widget.zone;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1E26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: zone.color.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Row: Room №, Category Dropdown, Name edit, Area chip, Delete, Close
          Row(
            children: [
              // Room Number Badge (tap to edit)
              InkWell(
                onTap: () => _showEditZoneDetailsDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: zone.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: zone.color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '№ ${zone.number}',
                    style: TextStyle(
                      color: zone.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Category Selector Dropdown (Space-efficient, zero hardcoded names)
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ArchitectZoneCategory>(
                    value: zone.category,
                    isDense: true,
                    dropdownColor: const Color(0xFF1E2230),
                    borderRadius: BorderRadius.circular(10),
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    items: ArchitectZoneCategory.values.map((cat) {
                      return DropdownMenuItem<ArchitectZoneCategory>(
                        value: cat,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16, color: cat.color),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                cat.localizedName(l10n),
                                style: TextStyle(
                                  color: cat == zone.category
                                      ? cat.color
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newCat) {
                      if (newCat != null && newCat != zone.category) {
                        final currentCat = zone.category;
                        final isDefaultName =
                            zone.name == currentCat.defaultBgName ||
                                zone.name == currentCat.defaultEnName ||
                                zone.name == currentCat.localizedName(l10n);
                        widget.onZoneUpdated(zone.copyWith(
                          category: newCat,
                          name: isDefaultName
                              ? newCat.localizedName(l10n)
                              : zone.name,
                        ));
                      }
                    },
                  ),
                ),
              ),

              // Edit details pencil (if custom name is set)
              IconButton(
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                tooltip: l10n.architectZoneName,
                onPressed: () => _showEditZoneDetailsDialog(context),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),

              // Net Area Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${zone.area.toStringAsFixed(2)} m²',
                  style: TextStyle(
                    color: zone.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Schedule table shortcut
              if (widget.onOpenScheduleTable != null)
                IconButton(
                  icon: const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF38BDF8),
                    size: 19,
                  ),
                  tooltip: l10n.architectZoneScheduleTitle,
                  onPressed: widget.onOpenScheduleTable,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),

              // Delete zone button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 19,
                ),
                tooltip: l10n.architectDeleteZone,
                onPressed: widget.onDeleteZone,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),

              // Close inspector button
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white60,
                  size: 19,
                ),
                onPressed: widget.onClose,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 2. Finishes Summary Bar (Floor, Walls, Ceiling) - Tap to edit in dialog
          InkWell(
            onTap: () => _showEditZoneDetailsDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF38BDF8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${l10n.architectZoneScheduleColFloor}: ${zone.resolvedFloorFinish(l10n)}  •  '
                      '${l10n.architectZoneScheduleColWalls}: ${zone.resolvedWallFinish(l10n)}  •  '
                      '${l10n.architectZoneScheduleColCeiling}: ${zone.resolvedCeilingFinish(l10n)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // 3. Dynamic Boundary Mode (Auto follows walls vs Manual fixed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: zone.isAutoBoundary
                  ? const Color(0x1A00E5FF)
                  : const Color(0x1AFFB74D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: zone.isAutoBoundary
                    ? const Color(0x4400E5FF)
                    : const Color(0x44FFB74D),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  zone.isAutoBoundary
                      ? Icons.auto_awesome_rounded
                      : Icons.edit_note_rounded,
                  color: zone.isAutoBoundary
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFFFFB74D),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    zone.isAutoBoundary
                        ? l10n.architectZoneBoundaryAuto
                        : l10n.architectZoneBoundaryManual,
                    style: TextStyle(
                      color: zone.isAutoBoundary
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFFFFB74D),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: zone.isAutoBoundary,
                    activeThumbColor: const Color(0xFF00E5FF),
                    onChanged: (val) {
                      widget.onZoneUpdated(zone.copyWith(isAutoBoundary: val));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditZoneDetailsDialog(BuildContext context) {
    final l10n = context.l10n;
    final zone = widget.zone;
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(zone.category.icon, color: zone.color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${zone.name} (${zone.area.toStringAsFixed(2)} m²)',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Number & Name
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: numberController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.architectZoneNumberPrompt,
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0x22FFFFFF),
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.architectZoneName,
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0x22FFFFFF),
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

                  // Floor Finish
                  TextField(
                    controller: floorController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.architectZoneFloorFinish,
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0x22FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final preset
                            in ArchitectZone.standardFloorFinishes(l10n))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              label: Text(preset,
                                  style: const TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(
                                    () => floorController.text = preset);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Wall Finish
                  TextField(
                    controller: wallController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.architectZoneWallFinish,
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0x22FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final preset
                            in ArchitectZone.standardWallFinishes(l10n))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              label: Text(preset,
                                  style: const TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(
                                    () => wallController.text = preset);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Ceiling Finish
                  TextField(
                    controller: ceilingController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.architectZoneCeilingFinish,
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0x22FFFFFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final preset
                            in ArchitectZone.standardCeilingFinishes(l10n))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              label: Text(preset,
                                  style: const TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(
                                    () => ceilingController.text = preset);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Clear Height
                  TextField(
                    controller: heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.architectZoneClearHeight,
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0x22FFFFFF),
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
              },
              child: Text(l10n.architectZoneSave),
            ),
          ],
        ),
      ),
    );
  }
}
