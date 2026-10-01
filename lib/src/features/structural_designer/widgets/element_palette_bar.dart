import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
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
  final bool hasSlabStartCorner;
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
    this.hasSlabStartCorner = false,
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
    final l10n = context.l10n;

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
                  tool: StructuralDrawTool.column,
                  icon: Icons.view_column_rounded,
                  label: l10n.toolColumn,
                ),
                _buildToolButton(
                  tool: StructuralDrawTool.shearWall,
                  icon: Icons.line_weight_rounded,
                  label: l10n.toolShearWall,
                ),
                _buildToolButton(
                  tool: StructuralDrawTool.slab,
                  icon: Icons.crop_square_rounded,
                  label: l10n.toolSlab,
                ),
                // Cantilever Analysis report launcher with badge
                _buildCantileverAnalysisButton(context),
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

    return Expanded(
      child: InkWell(
        onTap: () => onSelectTool(tool),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCantileverAnalysisButton(BuildContext context) {
    final int warningCount = analysisSummary.criticalCount + analysisSummary.warningCount;
    final Color badgeColor = analysisSummary.criticalCount > 0
        ? const Color(0xFFFF1744)
        : const Color(0xFFFFB300);

    return Expanded(
      child: InkWell(
        onTap: onOpenCantileverReport,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                context.l10n.toolCantilevers,
                style: TextStyle(
                  color: warningCount > 0 ? badgeColor : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnOptionsBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('25x25'),
              selected: currentColumnPreset.shape == ColumnShape.rectangular,
              onSelected: (selected) {
                if (selected) {
                  onUpdateColumnPreset(currentColumnPreset.copyWith(
                    shape: ColumnShape.rectangular,
                    width: 0.25,
                    height: 0.25,
                    thickness: 0.25,
                  ));
                }
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(context.l10n.columnShapeLShape),
              selected: currentColumnPreset.shape == ColumnShape.lShape,
              onSelected: (selected) {
                if (selected) {
                  onUpdateColumnPreset(currentColumnPreset.copyWith(
                    shape: ColumnShape.lShape,
                    width: 0.50,
                    height: 0.50,
                    thickness: 0.25,
                  ));
                }
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.rotate_90_degrees_ccw, size: 18),
            tooltip: context.l10n.rotate90,
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
        Text(
          context.l10n.wallThicknessLabel,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
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
        if (isDrawingSlab && (hasSlabStartCorner || slabPointCount > 0)) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x3300E5FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Text(
              context.l10n.previewSlabCorner2Tag,
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            icon: const Icon(Icons.close, size: 16),
            tooltip: context.l10n.cancelSlab,
            onPressed: onClearSlab,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}
