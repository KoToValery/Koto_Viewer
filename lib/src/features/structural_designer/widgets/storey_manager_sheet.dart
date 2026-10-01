import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';

/// Bottom sheet dialog for managing building storeys, floor heights,
/// ArchiCAD-style Trace Reference (ghost story), and duplicating typical floors.
class StoreyManagerSheet extends StatelessWidget {
  final StructuralProject project;
  final ValueChanged<int> onSelectStorey;
  final ValueChanged<GhostStoreyMode> onGhostModeChanged;
  final void Function(int index, double newHeight) onUpdateHeight;
  final VoidCallback onAddStorey;
  final VoidCallback onDuplicateCurrentStorey;
  final void Function(int index) onDeleteStorey;

  const StoreyManagerSheet({
    super.key,
    required this.project,
    required this.onSelectStorey,
    required this.onGhostModeChanged,
    required this.onUpdateHeight,
    required this.onAddStorey,
    required this.onDuplicateCurrentStorey,
    required this.onDeleteStorey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Row(
              children: [
                const Icon(Icons.layers_rounded, color: Color(0xFF00E5FF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.storeyManagerTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Trace Reference (ArchiCAD Ghost Story) Controls
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility_rounded,
                          size: 16, color: Color(0xFFFFB300)),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.traceReferenceTitle,
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<GhostStoreyMode>(
                    segments: [
                      ButtonSegment(
                        value: GhostStoreyMode.none,
                        label: Text(context.l10n.traceRefNone),
                      ),
                      ButtonSegment(
                        value: GhostStoreyMode.below,
                        label: Text(context.l10n.traceRefBelow),
                        icon: const Icon(Icons.arrow_downward, size: 16),
                      ),
                      ButtonSegment(
                        value: GhostStoreyMode.above,
                        label: Text(context.l10n.traceRefAbove),
                        icon: const Icon(Icons.arrow_upward, size: 16),
                      ),
                    ],
                    selected: {project.ghostMode},
                    onSelectionChanged: (set) => onGhostModeChanged(set.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Storeys List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: project.storeys.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  // Display from highest storey to lowest (standard architectural order)
                  final storeyIdx = project.storeys.length - 1 - idx;
                  final storey = project.storeys[storeyIdx];
                  final bool isActive = storeyIdx == project.activeStoreyIndex;

                  return Container(
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0x3300E5FF)
                          : const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF00E5FF)
                            : Colors.white12,
                        width: isActive ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isActive
                            ? const Color(0xFF00E5FF)
                            : Colors.white24,
                        child: Text(
                          '${storeyIdx + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        storey.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        context.l10n.storeyElevationSub(
                          storey.elevation.toStringAsFixed(2),
                          storey.height.toStringAsFixed(2),
                          storey.columns.length,
                          storey.shearWalls.length,
                        ),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_road_rounded,
                                size: 18, color: Colors.white70),
                            tooltip: context.l10n.changeHeightH,
                            onPressed: () => _showEditHeightDialog(
                              context,
                              storey.height,
                              (h) => onUpdateHeight(storeyIdx, h),
                            ),
                          ),
                          if (project.storeys.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.redAccent),
                              tooltip: context.l10n.deleteStorey,
                              onPressed: () => onDeleteStorey(storeyIdx),
                            ),
                        ],
                      ),
                      onTap: () {
                        onSelectStorey(storeyIdx);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons: Add storey & Duplicate typical storey
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onAddStorey();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.newStorey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onDuplicateCurrentStorey();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    label: Text(context.l10n.duplicateTypical),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHeightDialog(
      BuildContext context, double currentH, ValueChanged<double> onSave) {
    final controller = TextEditingController(text: currentH.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: Text(context.l10n.storeyClearHeight,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            suffixText: 'm',
            suffixStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 1.5 && val < 10.0) {
                onSave(val);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }
}
