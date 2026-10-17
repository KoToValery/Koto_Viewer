import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../services/architect_zone_tool.dart';

/// Floating property inspector and transformation toolbar for the currently selected functional zone.
/// Features GPS_Mapping-style angle straightening (90° squarify with undo), rotation slider & quick buttons,
/// whole-zone translation, boundary offset resize, and full undo/redo.
class ArchitectZonePropertiesCard extends StatefulWidget {
  final ArchitectZone zone;
  final ArchitectZoneTool tool;
  final ValueChanged<ArchitectZone> onZoneUpdated;
  final VoidCallback onDeleteZone;
  final VoidCallback onClose;
  final VoidCallback? onOpenScheduleTable;

  const ArchitectZonePropertiesCard({
    super.key,
    required this.zone,
    required this.tool,
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
  void _syncZoneFromTool() {
    final updated = widget.tool.commitEditingZone();
    if (updated != null) {
      widget.onZoneUpdated(updated);
      widget.tool.startEditingZone(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zone = widget.zone;
    final tool = widget.tool;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
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
          // 1. Top Row: Category Icon, Number badge, Name edit, Area chip, Finishes edit, Schedule, Delete, Close
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(zone.category.icon, size: 18, color: zone.color),
              ),
              const SizedBox(width: 8),
              // Room Number Badge (tap to edit details)
              InkWell(
                onTap: () => _showEditZoneDetailsDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
              // Name Edit
              Expanded(
                child: InkWell(
                  onTap: () => _showEditZoneDetailsDialog(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            zone.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Area Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${zone.area.toStringAsFixed(2)} m²',
                  style: TextStyle(
                    color: zone.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Finishes & Properties Dialog Button
              IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
                tooltip: l10n.architectZoneFinishes,
                onPressed: () => _showEditZoneDetailsDialog(context),
                visualDensity: VisualDensity.compact,
              ),
              if (widget.onOpenScheduleTable != null)
                IconButton(
                  icon: const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF00E676),
                    size: 20,
                  ),
                  tooltip: l10n.architectZoneScheduleTitle,
                  onPressed: widget.onOpenScheduleTable,
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: l10n.architectDeleteZone,
                onPressed: widget.onDeleteZone,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white60,
                  size: 20,
                ),
                onPressed: widget.onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 2. Boundary Mode: Dynamic Auto (default) vs Manual Correction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.isAutoBoundary
                            ? l10n.architectZoneBoundaryAuto
                            : l10n.architectZoneBoundaryManual,
                        style: TextStyle(
                          color: zone.isAutoBoundary
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFFFFB74D),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        zone.isAutoBoundary
                            ? l10n.architectZoneBoundaryAutoDesc
                            : l10n.architectZoneBoundaryManualDesc,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
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

          const SizedBox(height: 6),

          // 3. Finishes Summary Row (Floor, Walls, Ceiling)
          InkWell(
            onTap: () => _showEditZoneDetailsDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.architectZoneFloorFinish}: ${zone.resolvedFloorFinish(l10n)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${l10n.architectZoneWallFinish}: ${zone.resolvedWallFinish(l10n)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // 4. Category Quick Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final cat in ArchitectZoneCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      avatar: Icon(cat.icon, size: 12, color: cat.color),
                      label: Text(
                        cat.localizedName(l10n),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: zone.category == cat,
                      onSelected: (sel) {
                        if (sel) {
                          final currentCat = zone.category;
                          final isDefaultName = zone.name == currentCat.defaultBgName ||
                              zone.name == currentCat.defaultEnName ||
                              zone.name == currentCat.localizedName(l10n);
                          widget.onZoneUpdated(zone.copyWith(
                            category: cat,
                            name: isDefaultName ? cat.localizedName(l10n) : zone.name,
                          ));
                        }
                      },

                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 12),

          // 3. GPS_Mapping Transformation Row: Squarify (90° Auto-align), Move Whole Object, Undo/Redo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Auto-Align (Squarify 90°)
                ElevatedButton.icon(
                  onPressed: () {
                    final ok = tool.autoAlignZone();
                    if (ok) {
                      _syncZoneFromTool();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.architectZoneAutoAlignSuccess),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.square_foot_rounded, size: 15),
                  label: Text(l10n.architectZoneAutoAlign),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (tool.canUndoAutoAlign) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      final ok = tool.undoAutoAlignZone();
                      if (ok) _syncZoneFromTool();
                    },
                    icon: const Icon(Icons.undo_rounded, size: 14),
                    label: Text(l10n.architectZoneUndoAlign),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB74D),
                      side: const BorderSide(color: Color(0xFFFFB74D)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                const SizedBox(width: 8),

                // Move Whole Zone Toggle
                FilterChip(
                  selected: tool.isMoveWholeZoneMode,
                  onSelected: (_) => tool.toggleMoveWholeZoneMode(),
                  avatar: Icon(
                    Icons.open_with_rounded,
                    size: 14,
                    color: tool.isMoveWholeZoneMode ? Colors.black : const Color(0xFF69F0AE),
                  ),
                  label: Text(
                    tool.isMoveWholeZoneMode && tool.moveDistanceMeters > 0.01
                        ? l10n.architectZoneMovedDistance(
                            tool.moveDistanceMeters.toStringAsFixed(2))
                        : l10n.architectZoneMove,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: tool.isMoveWholeZoneMode ? Colors.black : Colors.white,
                    ),
                  ),
                  selectedColor: const Color(0xFF69F0AE),
                  backgroundColor: const Color(0xFF263238),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),

                // Undo / Redo
                IconButton(
                  tooltip: l10n.architectZoneUndoAction,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  color: tool.canUndoEdit ? Colors.white : Colors.white24,
                  onPressed: tool.canUndoEdit
                      ? () {
                          tool.undoEditAction();
                          _syncZoneFromTool();
                        }
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: l10n.architectZoneRedoAction,
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  color: tool.canRedoEdit ? Colors.white : Colors.white24,
                  onPressed: tool.canRedoEdit
                      ? () {
                          tool.redoEditAction();
                          _syncZoneFromTool();
                        }
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 4. GPS_Mapping Rotation Slider & Quick Buttons (-90, -15, +15, +90)
          Row(
            children: [
              Text(
                '${l10n.architectZoneRotate}:',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    min: -180.0,
                    max: 180.0,
                    value: tool.editRotationSlider,
                    activeColor: const Color(0xFFFFD600),
                    inactiveColor: Colors.white12,
                    onChanged: (val) => tool.setRotationSlider(val),
                    onChangeEnd: (_) {
                      tool.finishRotationSlider();
                      _syncZoneFromTool();
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '${tool.editRotationSlider.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 6),
              _buildStepButton('-15°', () {
                tool.applyRotationStep(-15.0);
                _syncZoneFromTool();
              }),
              const SizedBox(width: 4),
              _buildStepButton('+15°', () {
                tool.applyRotationStep(15.0);
                _syncZoneFromTool();
              }),
              const SizedBox(width: 4),
              _buildStepButton('+90°', () {
                tool.applyRotationStep(90.0);
                _syncZoneFromTool();
              }),
            ],
          ),

          const SizedBox(height: 4),

          // 5. Boundary Offset Resize Row (-0.20m, +0.20m, -0.50m, +0.50m)
          Row(
            children: [
              Text(
                '${l10n.architectZoneOffset}:',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _buildStepButton('-0.20 m', () {
                tool.applyOffsetStep(-0.20);
                _syncZoneFromTool();
              }),
              const SizedBox(width: 4),
              _buildStepButton('+0.20 m', () {
                tool.applyOffsetStep(0.20);
                _syncZoneFromTool();
              }),
              const SizedBox(width: 4),
              _buildStepButton('-0.50 m', () {
                tool.applyOffsetStep(-0.50);
                _syncZoneFromTool();
              }),
              const SizedBox(width: 4),
              _buildStepButton('+0.50 m', () {
                tool.applyOffsetStep(0.50);
                _syncZoneFromTool();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          style:
                              const TextStyle(color: Colors.white, fontSize: 14),
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
                          style:
                              const TextStyle(color: Colors.white, fontSize: 14),
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
                        for (final preset in ArchitectZone.standardFloorFinishes(l10n))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              label: Text(preset, style: const TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(() => floorController.text = preset);
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
                        for (final preset in ArchitectZone.standardWallFinishes(l10n))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              label: Text(preset, style: const TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(() => wallController.text = preset);
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
                        for (final preset in ArchitectZone.standardCeilingFinishes(l10n))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              label: Text(preset, style: const TextStyle(fontSize: 10)),
                              onPressed: () {
                                setDialogState(() => ceilingController.text = preset);
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
