import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import '../rendering/structural_pointer_painter.dart';

/// Bottom dock palette bar for choosing structural elements (columns, walls, slabs, beams, axes),
/// picking standard cross-section presets, configuring custom dimensions, and running analysis.
class ElementPaletteBar extends StatelessWidget {
  final StructuralDrawTool activeTool;
  final ValueChanged<StructuralDrawTool> onSelectTool;
  final StructuralColumn currentColumnPreset;
  final ValueChanged<StructuralColumn> onUpdateColumnPreset;
  final double currentWallThickness;
  final ValueChanged<double> onUpdateWallThickness;
  final double currentBeamWidth;
  final double currentBeamDepth;
  final void Function(double width, double depth)? onUpdateBeamDimensions;
  final double currentSlabThickness;
  final ValueChanged<double> onUpdateSlabThickness;
  final String currentOpeningPreset;
  final ValueChanged<String>? onUpdateOpeningPreset;
  final String currentAxisName;
  final ValueChanged<String>? onUpdateAxisName;
  final bool hasFirstWallEdge;
  final VoidCallback? onClearAxis;
  final bool isDrawingSlab;
  final bool hasSlabStartCorner;
  final int slabPointCount;
  final VoidCallback onCloseSlab;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearSlab;
  final VoidCallback onRotateColumn;
  final VoidCallback onOpenCantileverReport;
  final StructuralAnalysisSummary analysisSummary;
  final VoidCallback? onOpenVerticalCapacityReport;
  final VerticalCapacityReport? verticalCapacityReport;
  final VoidCallback? onOpenSeismicReport;
  final SeismicAnalysisReport? seismicReport;
  final bool hasWallStart;
  final bool hasBeamStart;
  final VoidCallback? onCustomColumnDimensions;
  final VoidCallback? onCustomWallThickness;
  final VoidCallback? onCustomBeamDimensions;
  final VoidCallback? onCustomSlabThickness;
  final VoidCallback? onCustomAxisName;

  const ElementPaletteBar({
    super.key,
    required this.activeTool,
    required this.onSelectTool,
    required this.currentColumnPreset,
    required this.onUpdateColumnPreset,
    required this.currentWallThickness,
    required this.onUpdateWallThickness,
    this.currentBeamWidth = 0.25,
    this.currentBeamDepth = 0.50,
    this.onUpdateBeamDimensions,
    required this.currentSlabThickness,
    required this.onUpdateSlabThickness,
    this.currentOpeningPreset = 'shaft',
    this.onUpdateOpeningPreset,
    this.currentAxisName = '1',
    this.onUpdateAxisName,
    this.hasFirstWallEdge = false,
    this.onClearAxis,
    required this.isDrawingSlab,
    this.hasSlabStartCorner = false,
    required this.slabPointCount,
    required this.onCloseSlab,
    required this.onUndoPoint,
    required this.onClearSlab,
    required this.onRotateColumn,
    required this.onOpenCantileverReport,
    required this.analysisSummary,
    this.onOpenVerticalCapacityReport,
    this.verticalCapacityReport,
    this.onOpenSeismicReport,
    this.seismicReport,
    this.hasWallStart = false,
    this.hasBeamStart = false,
    this.onCustomColumnDimensions,
    this.onCustomWallThickness,
    this.onCustomBeamDimensions,
    this.onCustomSlabThickness,
    this.onCustomAxisName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF5181A20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Dynamic Action Guidance Hint Banner
            _buildGuidanceBanner(context),

            // 2. Dynamic Scrollable Sub-bar for Active Tool parameters
            if (activeTool == StructuralDrawTool.gridAxis)
              _buildGridAxisOptionsBar(context)
            else if (activeTool == StructuralDrawTool.column)
              _buildColumnOptionsBar(context)
            else if (activeTool == StructuralDrawTool.shearWall)
              _buildWallOptionsBar(context)
            else if (activeTool == StructuralDrawTool.beam)
              _buildBeamOptionsBar(context)
            else if (activeTool == StructuralDrawTool.slab)
              _buildSlabOptionsBar(context)
            else if (activeTool == StructuralDrawTool.slabOpening)
              _buildOpeningOptionsBar(context),

            const SizedBox(height: 6),

            // 3. Main Tools Row with visual separation between drawing & analysis
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  _buildToolButton(
                    tool: StructuralDrawTool.gridAxis,
                    icon: Icons.grid_3x3_rounded,
                    label: context.l10n.toolGridAxis,
                  ),
                  _buildToolButton(
                    tool: StructuralDrawTool.column,
                    icon: Icons.view_column_rounded,
                    label: context.l10n.toolColumn,
                  ),
                  _buildToolButton(
                    tool: StructuralDrawTool.shearWall,
                    icon: Icons.line_weight_rounded,
                    label: context.l10n.toolShearWall,
                  ),
                  _buildToolButton(
                    tool: StructuralDrawTool.beam,
                    icon: Icons.horizontal_rule_rounded,
                    label: context.l10n.toolBeam,
                  ),
                  _buildToolButton(
                    tool: StructuralDrawTool.slab,
                    icon: Icons.crop_square_rounded,
                    label: context.l10n.toolSlab,
                  ),
                  _buildToolButton(
                    tool: StructuralDrawTool.slabOpening,
                    icon: Icons.tab_unselected_rounded,
                    label: context.l10n.toolOpening,
                  ),
                  // Vertical divider between modeling elements and engineering checks
                  Container(
                    height: 28,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white24,
                  ),
                  // Cantilever Analysis report launcher with badge
                  _buildCantileverAnalysisButton(context),
                  // EC2 Vertical Capacity report launcher with badge
                  _buildVerticalCapacityButton(context),
                  // EC8 Seismic Analysis report launcher with badge
                  _buildSeismicAnalysisButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceBanner(BuildContext context) {
    final l10n = context.l10n;
    final (IconData icon, String message, Color color) = switch (activeTool) {
      StructuralDrawTool.column => (
          Icons.adjust_rounded,
          'Посочете място или задръжте за визьор',
          const Color(0xFF00E5FF),
        ),
      StructuralDrawTool.shearWall => hasWallStart
          ? (
              Icons.straighten_rounded,
              'Посочете крайна точка на шайбата',
              const Color(0xFFFFB300),
            )
          : (
              Icons.place_outlined,
              'Посочете начална точка на шайбата',
              const Color(0xFF00E5FF),
            ),
      StructuralDrawTool.beam => hasBeamStart
          ? (
              Icons.straighten_rounded,
              'Посочете крайна точка на гредата',
              const Color(0xFFFFB300),
            )
          : (
              Icons.place_outlined,
              'Посочете начална точка на гредата',
              const Color(0xFF00E5FF),
            ),
      StructuralDrawTool.slab => hasSlabStartCorner
          ? (
              Icons.check_circle_outline,
              l10n.previewSlabCorner2Tag,
              const Color(0xFFFFB300),
            )
          : (
              Icons.crop_square_rounded,
              l10n.previewSlabCorner1Tag,
              const Color(0xFF00E5FF),
            ),
      StructuralDrawTool.slabOpening => (
          Icons.tab_unselected_rounded,
          'Посочете отвор върху съществуваща плоча',
          const Color(0xFFFF9800),
        ),
      StructuralDrawTool.gridAxis => hasFirstWallEdge
          ? (
              Icons.filter_2_rounded,
              l10n.secondWallSidePrompt,
              const Color(0xFFFFB300),
            )
          : (
              Icons.filter_1_rounded,
              l10n.firstWallSidePrompt,
              const Color(0xFFFF453A),
            ),
      _ => (
          Icons.touch_app_outlined,
          'Изберете инструмент за чертане или редакция',
          Colors.white70,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onSelectTool(tool),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x3300E5FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
              width: 1.5,
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

    return Container(
      constraints: const BoxConstraints(minWidth: 50),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onOpenCantileverReport,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
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

  Widget _buildVerticalCapacityButton(BuildContext context) {
    final report = verticalCapacityReport;
    final int alertCount =
        (report?.criticalColumnsCount ?? 0) + (report?.punchingRiskCount ?? 0);
    final Color badgeColor = (report?.criticalColumnsCount ?? 0) > 0
        ? const Color(0xFFFF1744)
        : ((report?.warningColumnsCount ?? 0) > 0 || (report?.punchingRiskCount ?? 0) > 0
            ? const Color(0xFFFFB300)
            : const Color(0xFF00E676));

    final bool hasAlerts = alertCount > 0;

    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onOpenVerticalCapacityReport,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: hasAlerts ? badgeColor.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasAlerts ? badgeColor : Colors.white24,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: hasAlerts,
                backgroundColor: badgeColor,
                label: Text(
                  '$alertCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                child: Icon(
                  Icons.domain_rounded,
                  color: hasAlerts ? badgeColor : const Color(0xFF00E5FF),
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.ec2FeasibilityButton,
                style: TextStyle(
                  color: hasAlerts ? badgeColor : const Color(0xFF00E5FF),
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

  Widget _buildSeismicAnalysisButton(BuildContext context) {
    final report = seismicReport;
    final int alertCount = (report?.totalFloatingColumnsCount ?? 0) +
        (report?.hasTorsionalSensitivity == true ? 1 : 0) +
        (report?.hasSoftStorey == true ? 1 : 0);

    final Color badgeColor = (report?.totalFloatingColumnsCount ?? 0) > 0 ||
            (report?.hasSoftStorey == true)
        ? const Color(0xFFD500F9)
        : (report?.hasTorsionalSensitivity == true
            ? const Color(0xFFFF1744)
            : (report?.hasWallDeficit == true
                ? const Color(0xFFFFB300)
                : const Color(0xFF00E676)));

    final bool hasAlerts = alertCount > 0 || (report?.hasWallDeficit == true);

    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onOpenSeismicReport,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: hasAlerts ? badgeColor.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasAlerts ? badgeColor : Colors.white24,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: alertCount > 0,
                backgroundColor: badgeColor,
                label: Text(
                  '$alertCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                child: Icon(
                  Icons.waves_rounded,
                  color: hasAlerts ? badgeColor : const Color(0xFFD500F9),
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.ec8SeismicButton,
                style: TextStyle(
                  color: hasAlerts ? badgeColor : const Color(0xFFD500F9),
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
    final columnPresets = [
      (ColumnShape.rectangular, 0.25, 0.25, 0.25, '25×25'),
      (ColumnShape.rectangular, 0.25, 0.50, 0.25, '25×50'),
      (ColumnShape.rectangular, 0.30, 0.30, 0.30, '30×30'),
      (ColumnShape.rectangular, 0.25, 0.60, 0.25, '25×60'),
      (ColumnShape.rectangular, 0.30, 0.50, 0.30, '30×50'),
      (ColumnShape.circular, 0.30, 0.30, 0.30, 'Ø 30'),
      (ColumnShape.lShape, 0.50, 0.50, 0.25, context.l10n.columnShapeLShape),
    ];

    final bool matchesAnyPreset = columnPresets.any((p) =>
        currentColumnPreset.shape == p.$1 &&
        (currentColumnPreset.width - p.$2).abs() < 1e-3 &&
        (currentColumnPreset.height - p.$3).abs() < 1e-3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final (shape, w, h, t, label) in columnPresets) ...[
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text(label),
                selected: currentColumnPreset.shape == shape &&
                    (currentColumnPreset.width - w).abs() < 1e-3 &&
                    (currentColumnPreset.height - h).abs() < 1e-3,
                onSelected: (selected) {
                  if (selected) {
                    onUpdateColumnPreset(currentColumnPreset.copyWith(
                      shape: shape,
                      width: w,
                      height: h,
                      thickness: t,
                    ));
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          if (!matchesAnyPreset)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text(
                  currentColumnPreset.shape == ColumnShape.circular
                      ? 'Ø ${(currentColumnPreset.width * 100).round()} cm'
                      : '${(currentColumnPreset.width * 100).round()}×${(currentColumnPreset.height * 100).round()}',
                ),
                selected: true,
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton.filledTonal(
            icon: const Icon(Icons.rotate_90_degrees_ccw, size: 18),
            tooltip: context.l10n.rotate90,
            onPressed: onRotateColumn,
            visualDensity: VisualDensity.compact,
          ),
          if (onCustomColumnDimensions != null) ...[
            const SizedBox(width: 4),
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Размери...', style: TextStyle(fontSize: 11)),
              onPressed: onCustomColumnDimensions,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWallOptionsBar(BuildContext context) {
    final thicknesses = [0.15, 0.20, 0.25, 0.30, 0.35];
    final bool matchesPreset =
        thicknesses.any((t) => (currentWallThickness - t).abs() < 1e-3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Text(
            context.l10n.wallThicknessLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          for (final t in thicknesses)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text('${(t * 100).toInt()} cm'),
                selected: (currentWallThickness - t).abs() < 1e-3,
                onSelected: (selected) {
                  if (selected) onUpdateWallThickness(t);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (!matchesPreset)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text('${(currentWallThickness * 100).round()} cm'),
                selected: true,
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (onCustomWallThickness != null)
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Друга...', style: TextStyle(fontSize: 11)),
              onPressed: onCustomWallThickness,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildSlabOptionsBar(BuildContext context) {
    final thicknesses = [0.15, 0.18, 0.20, 0.22, 0.25, 0.30];
    final bool matchesPreset =
        thicknesses.any((t) => (currentSlabThickness - t).abs() < 1e-3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final t in thicknesses)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('h=${(t * 100).toInt()} cm'),
                selected: (currentSlabThickness - t).abs() < 1e-3,
                onSelected: (selected) {
                  if (selected) onUpdateSlabThickness(t);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (!matchesPreset)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('h=${(currentSlabThickness * 100).round()} cm'),
                selected: true,
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (onCustomSlabThickness != null) ...[
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Друга...', style: TextStyle(fontSize: 11)),
              onPressed: onCustomSlabThickness,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
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
      ),
    );
  }

  Widget _buildBeamOptionsBar(BuildContext context) {
    final beamSizes = [
      (0.25, 0.50, '25×50'),
      (0.25, 0.60, '25×60'),
      (0.25, 0.40, '25×40'),
      (0.25, 0.30, '25×30 (скрита)'),
      (0.30, 0.50, '30×50'),
      (0.30, 0.60, '30×60'),
    ];

    final bool matchesPreset = beamSizes.any((b) =>
        (currentBeamWidth - b.$1).abs() < 1e-3 &&
        (currentBeamDepth - b.$2).abs() < 1e-3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final (w, d, label) in beamSizes)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text(label),
                selected: (currentBeamWidth - w).abs() < 1e-3 &&
                    (currentBeamDepth - d).abs() < 1e-3,
                onSelected: (selected) {
                  if (selected && onUpdateBeamDimensions != null) {
                    onUpdateBeamDimensions!(w, d);
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (!matchesPreset)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text(
                    '${(currentBeamWidth * 100).round()}×${(currentBeamDepth * 100).round()}'),
                selected: true,
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (onCustomBeamDimensions != null)
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Размери...', style: TextStyle(fontSize: 11)),
              onPressed: onCustomBeamDimensions,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildOpeningOptionsBar(BuildContext context) {
    final l10n = context.l10n;
    final presets = [
      ('shaft', 'Шахта (40×60)'),
      ('elevator', 'Асансьор (1.8×2.0)'),
      ('stairs', 'Стълби (2.4×4.5)'),
      ('custom', l10n.openingPresetCustom),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final (key, label) in presets)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: currentOpeningPreset == key,
                onSelected: (selected) {
                  if (selected && onUpdateOpeningPreset != null) {
                    onUpdateOpeningPreset!(key);
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridAxisOptionsBar(BuildContext context) {
    final l10n = context.l10n;
    final quickNames = [
      '1', '2', '3', '4', '5', '6', '7', '8',
      'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж',
      'A', 'B', 'C', 'D', 'E'
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33FF453A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF453A)),
            ),
            child: Text(
              '${l10n.toolGridAxis}: $currentAxisName',
              style: const TextStyle(
                color: Color(0xFFFF453A),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          for (final name in quickNames)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                label: Text(name, style: const TextStyle(fontSize: 11)),
                backgroundColor: currentAxisName == name ? const Color(0x55FF453A) : null,
                onPressed: () => onUpdateAxisName?.call(name),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (onCustomAxisName != null) ...[
            const SizedBox(width: 4),
            ActionChip(
              avatar: const Icon(Icons.edit_note_rounded, size: 14),
              label: const Text('Име...', style: TextStyle(fontSize: 11)),
              onPressed: onCustomAxisName,
              visualDensity: VisualDensity.compact,
            ),
          ],
          if (hasFirstWallEdge) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x3300E5FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E5FF)),
              ),
              child: Text(
                l10n.secondWallSidePrompt,
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onClearAxis,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
