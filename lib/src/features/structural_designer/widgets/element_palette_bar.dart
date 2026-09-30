import 'package:flutter/material.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/structural_element.dart';
import '../rendering/structural_pointer_painter.dart';

/// Bottom dock palette bar for choosing structural elements (columns, walls, slabs),
/// changing cross-section dimensions, closing polygons, and launching the analysis sheet.
class ElementPaletteBar extends StatelessWidget {
  final StructuralDrawTool activeTool;
  final ValueChanged<StructuralDrawTool> onSelectTool;
  final StructuralColumn currentColumnPreset;
  final ValueChanged<StructuralColumn> onUpdateColumnPreset;
  final double currentWallThickness;
  final ValueChanged<double> onUpdateWallThickness;
  final double currentSlabThickness;
  final ValueChanged<double> onUpdateSlabThickness;
  final bool isDrawingSlab;
  final int slabPointCount;
  final VoidCallback onCloseSlab;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearSlab;
  final VoidCallback onRotateColumn;
  final VoidCallback onOpenCantileverReport;
  final StructuralAnalysisSummary analysisSummary;

  const ElementPaletteBar({
    super.key,
    required this.activeTool,
    required this.onSelectTool,
    required this.currentColumnPreset,
    required this.onUpdateColumnPreset,
    required this.currentWallThickness,
    required this.onUpdateWallThickness,
    required this.currentSlabThickness,
    required this.onUpdateSlabThickness,
    required this.isDrawingSlab,
    required this.slabPointCount,
    required this.onCloseSlab,
    required this.onUndoPoint,
    required this.onClearSlab,
    required this.onRotateColumn,
    required this.onOpenCantileverReport,
    required this.analysisSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF21C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dynamic Sub-bar for Active Tool parameters
            if (activeTool == StructuralDrawTool.column)
              _buildColumnOptionsBar(context)
            else if (activeTool == StructuralDrawTool.shearWall)
              _buildWallOptionsBar(context)
            else if (activeTool == StructuralDrawTool.slab)
              _buildSlabOptionsBar(context),

            const SizedBox(height: 6),

            // Main Tools Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolButton(
                  tool: StructuralDrawTool.select,
                  icon: Icons.pan_tool_rounded,
                  label: 'Навигация',
                ),
                _buildToolButton(
                  tool: StructuralDrawTool.column,
                  icon: Icons.view_column_rounded,
                  label: 'Колона',
                ),
                _buildToolButton(
                  tool: StructuralDrawTool.shearWall,
                  icon: Icons.line_weight_rounded,
                  label: 'Шайба',
                ),
                _buildToolButton(
                  tool: StructuralDrawTool.slab,
                  icon: Icons.crop_square_rounded,
                  label: 'Плоча',
                ),
                // Cantilever Analysis report launcher with badge
                _buildCantileverAnalysisButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required StructuralDrawTool tool,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = activeTool == tool;
    final color = isSelected ? const Color(0xFF00E5FF) : Colors.white70;

    return InkWell(
      onTap: () => onSelectTool(tool),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x3300E5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCantileverAnalysisButton() {
    final int warningCount = analysisSummary.criticalCount + analysisSummary.warningCount;
    final Color badgeColor = analysisSummary.criticalCount > 0
        ? const Color(0xFFFF1744)
        : const Color(0xFFFFB300);

    return InkWell(
      onTap: onOpenCantileverReport,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: warningCount > 0 ? badgeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: warningCount > 0 ? badgeColor : Colors.white24,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: warningCount > 0,
              backgroundColor: badgeColor,
              label: Text(
                '$warningCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: warningCount > 0 ? badgeColor : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Еркери',
              style: TextStyle(
                color: warningCount > 0 ? badgeColor : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnOptionsBar(BuildContext context) {
    final presets = [
      (0.25, 0.25, '25x25'),
      (0.25, 0.50, '25x50'),
      (0.30, 0.60, '30x60'),
      (0.40, 0.40, '40x40'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in presets)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(p.$3),
                selected: currentColumnPreset.shape == ColumnShape.rectangular &&
                    currentColumnPreset.width == p.$1 &&
                    currentColumnPreset.height == p.$2,
                onSelected: (selected) {
                  if (selected) {
                    onUpdateColumnPreset(currentColumnPreset.copyWith(
                      shape: ColumnShape.rectangular,
                      width: p.$1,
                      height: p.$2,
                    ));
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('Ø40 кръгла'),
              selected: currentColumnPreset.shape == ColumnShape.circular,
              onSelected: (selected) {
                if (selected) {
                  onUpdateColumnPreset(currentColumnPreset.copyWith(
                    shape: ColumnShape.circular,
                    width: 0.40,
                    height: 0.40,
                  ));
                }
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.rotate_90_degrees_ccw, size: 18),
            tooltip: 'Завърти на 90°',
            onPressed: onRotateColumn,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWallOptionsBar(BuildContext context) {
    final thicknesses = [0.20, 0.25, 0.30];
    return Row(
      children: [
        const Text(
          'Дебелина на шайба: ',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        for (final t in thicknesses)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('${(t * 100).toInt()} cm'),
              selected: currentWallThickness == t,
              onSelected: (selected) {
                if (selected) onUpdateWallThickness(t);
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  Widget _buildSlabOptionsBar(BuildContext context) {
    final thicknesses = [0.18, 0.20, 0.22, 0.25];
    return Row(
      children: [
        for (final t in thicknesses)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text('h=${(t * 100).toInt()} cm'),
              selected: currentSlabThickness == t,
              onSelected: (selected) {
                if (selected) onUpdateSlabThickness(t);
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
        const Spacer(),
        if (isDrawingSlab) ...[
          IconButton.filledTonal(
            icon: const Icon(Icons.undo, size: 16),
            tooltip: 'Отмени точка',
            onPressed: onUndoPoint,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: Text('Затвори ($slabPointCount)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: slabPointCount >= 3 ? onCloseSlab : null,
          ),
        ],
      ],
    );
  }
}
