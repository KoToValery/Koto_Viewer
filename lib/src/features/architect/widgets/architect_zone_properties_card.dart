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

  const ArchitectZonePropertiesCard({
    super.key,
    required this.zone,
    required this.tool,
    required this.onZoneUpdated,
    required this.onDeleteZone,
    required this.onClose,
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
          // 1. Top Row: Category Icon, Name edit, Area & Perimeter chips, Delete, Close
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
              Expanded(
                child: InkWell(
                  onTap: () => _showEditNameDialog(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            zone.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Area & Perimeter Chips
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
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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

          // 2. Category Quick Selector Chips
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
                        cat.defaultBgName,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: zone.category == cat,
                      onSelected: (sel) {
                        if (sel) {
                          widget.onZoneUpdated(zone.copyWith(
                            category: cat,
                            name: zone.name == zone.category.defaultBgName
                                ? cat.defaultBgName
                                : zone.name,
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

  void _showEditNameDialog(BuildContext context) {
    final l10n = context.l10n;
    final controller = TextEditingController(text: widget.zone.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22242E),
        title: Text(
          l10n.architectZoneName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.zone.category.defaultBgName,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF161820),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                widget.onZoneUpdated(widget.zone.copyWith(name: newName));
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
