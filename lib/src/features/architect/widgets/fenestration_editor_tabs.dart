// === SECTION: FENESTRATION EDITOR TAB PANELS ===
// Table of Contents:
// 1. STEP 1: FRAME & GRID DRAFTING PANEL (Dimensions, Divisions, Keypad)
// 2. STEP 2: OPERABILITY & INNER SASH PROFILE PANEL
// 3. STEP 3: INFILL & MUNTINS (GLAZING BARS) PANEL
// 4. CASING / TRIM PANEL (Façade siding over wall/insulation)
// 5. TECHNICAL PROFILE & GLAZING SPECS PANEL
// 6. PRESETS CATALOG PICKER PANEL

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_fenestration_style.dart';

// ===========================================================================
// SECTION 1: STEP 1 - FRAME & GRID DRAFTING PANEL
// ===========================================================================

/// Step 1: Overall opening dimensions, division raster, and exact metric leaf sizing.
class FenestrationStep1FrameGridTab extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final String? selectedPaneId;
  final ValueChanged<String?> onSelectPane;
  final ValueChanged<ArchitectFenestrationStyle> onChanged;
  final void Function(bool isWidth)? onOpenKeypad;

  const FenestrationStep1FrameGridTab({
    super.key,
    required this.style,
    required this.selectedPaneId,
    required this.onSelectPane,
    required this.onChanged,
    this.onOpenKeypad,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final panes = style.rootSubdivision.collectPanes();
    final selectedPane = panes.where((p) => p.id == selectedPaneId).firstOrNull ??
        panes.firstOrNull;
    final currentRect = selectedPane != null
        ? style.getPaneRect(selectedPane.id)
        : null;

    final paneW = currentRect?.width ?? style.defaultWidth;
    final paneH = currentRect?.height ?? style.defaultHeight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Overall Frame Dimensions
          Text(
            l10n.architectFenestrationDimensions,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 8),

          // Total Width
          Text(
            '${l10n.architectShapeWidth}: ${(style.defaultWidth * 100).round()} cm',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Slider(
            value: style.defaultWidth,
            min: 0.50,
            max: 3.60,
            divisions: 31,
            label: '${(style.defaultWidth * 100).round()} cm',
            onChanged: (val) => onChanged(style.copyWith(defaultWidth: val)),
          ),

          // Total Height
          Text(
            '${l10n.architectShapeHeight}: ${(style.defaultHeight * 100).round()} cm',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Slider(
            value: style.defaultHeight,
            min: 0.50,
            max: 3.00,
            divisions: 25,
            label: '${(style.defaultHeight * 100).round()} cm',
            onChanged: (val) => onChanged(style.copyWith(defaultHeight: val)),
          ),

          // Sill Height
          Text(
            '${l10n.architectWindowSill}: ${(style.defaultSillHeight * 100).round()} cm',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Slider(
            value: style.defaultSillHeight,
            min: 0.00,
            max: 1.50,
            divisions: 15,
            label: '${(style.defaultSillHeight * 100).round()} cm',
            onChanged: (val) => onChanged(style.copyWith(defaultSillHeight: val)),
          ),

          const Divider(height: 24),

          // Section: Division Raster Tools (Членения)
          Text(
            l10n.architectFenestrationDivisions,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.splitscreen_rounded, size: 16),
                label: Text(l10n.architectFenestrationAddMullion),
                onPressed: () {
                  if (selectedPane != null) {
                    onChanged(style.splitPane(selectedPane.id, vertical: true));
                  } else {
                    final newSub = style.rootSubdivision.split(
                      vertical: true,
                      count: style.rootSubdivision.children.length + 1,
                    );
                    onChanged(style.copyWith(rootSubdivision: newSub));
                  }
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.table_rows_rounded, size: 16),
                label: Text(l10n.architectFenestrationAddTransom),
                onPressed: () {
                  if (selectedPane != null) {
                    onChanged(style.splitPane(selectedPane.id, vertical: false));
                  } else {
                    final newSub = style.rootSubdivision.split(
                      vertical: false,
                      count: style.rootSubdivision.children.length + 1,
                    );
                    onChanged(style.copyWith(rootSubdivision: newSub));
                  }
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text(l10n.architectFenestrationRemoveSplit),
                onPressed: () {
                  if (selectedPane != null && style.rootSubdivision.isSplit) {
                    onChanged(style.collapsePane(selectedPane.id));
                  } else {
                    onChanged(style.copyWith(
                      rootSubdivision: style.rootSubdivision.collapse(),
                    ));
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section: Selected Leaf Pane Metric Sizing (Точни размери)
          if (selectedPane != null) ...[
            Row(
              children: [
                Text(
                  '${l10n.architectFenestrationSelectedLeaf}:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                if (panes.length > 1)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < panes.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('${i + 1}'),
                                selected: panes[i].id == selectedPane.id,
                                onSelected: (_) => onSelectPane(panes[i].id),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Exact Dimension Buttons (triggers wall keypad)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l10n.architectFenestrationSelectedLeaf} ${(paneW * 100).round()} × ${(paneH * 100).round()} cm',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.dialpad_rounded, size: 16),
                          label: Text(
                            '${l10n.architectFenestrationLeafWidth} (${(paneW * 100).round()} cm)',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => onOpenKeypad?.call(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.dialpad_rounded, size: 16),
                          label: Text(
                            '${l10n.architectFenestrationLeafHeight} (${(paneH * 100).round()} cm)',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => onOpenKeypad?.call(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Width Quick Slider
                  Text(
                    '${l10n.architectFenestrationLeafWidth}: ${(paneW * 100).round()} cm',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: paneW.clamp(0.20, style.defaultWidth),
                    min: 0.20,
                    max: style.defaultWidth,
                    onChanged: (val) {
                      onChanged(
                        style.setPaneMetricDimension(selectedPane.id, val, true),
                      );
                    },
                  ),

                  // Height Quick Slider
                  Text(
                    '${l10n.architectFenestrationLeafHeight}: ${(paneH * 100).round()} cm',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: paneH.clamp(0.20, style.defaultHeight),
                    min: 0.20,
                    max: style.defaultHeight,
                    onChanged: (val) {
                      onChanged(
                        style.setPaneMetricDimension(selectedPane.id, val, false),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// SECTION 2: STEP 2 - OPERABILITY & SASH PROFILE PANEL
// ===========================================================================

/// Step 2: Operability mode per leaf with auto-generated inner sash frame.
class FenestrationStep2OperabilityTab extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final String? selectedPaneId;
  final ValueChanged<String?> onSelectPane;
  final ValueChanged<ArchitectFenestrationStyle> onChanged;

  const FenestrationStep2OperabilityTab({
    super.key,
    required this.style,
    required this.selectedPaneId,
    required this.onSelectPane,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final panes = style.rootSubdivision.collectPanes();
    final selectedPane = panes.where((p) => p.id == selectedPaneId).firstOrNull ??
        panes.firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.architectFenestrationStep2,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 8),

          // Pane selector if multiple
          if (panes.length > 1) ...[
            Text(
              '${l10n.architectFenestrationSelectedLeaf}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (int i = 0; i < panes.length; i++)
                  ChoiceChip(
                    label: Text('${i + 1}'),
                    selected: panes[i].id == selectedPane?.id,
                    onSelected: (_) => onSelectPane(panes[i].id),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          if (selectedPane != null) ...[
            Text(
              l10n.architectFenestrationPaneType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildTypeChip(
                  context,
                  selectedPane,
                  PaneType.fixedGlazing,
                  l10n.architectFenestrationPaneFixed,
                  Icons.crop_square_rounded,
                ),
                _buildTypeChip(
                  context,
                  selectedPane,
                  PaneType.casementLeft,
                  l10n.architectFenestrationPaneTurnLeft,
                  Icons.chevron_left_rounded,
                ),
                _buildTypeChip(
                  context,
                  selectedPane,
                  PaneType.casementRight,
                  l10n.architectFenestrationPaneTurnRight,
                  Icons.chevron_right_rounded,
                ),
                _buildTypeChip(
                  context,
                  selectedPane,
                  PaneType.tiltAndTurn,
                  l10n.architectFenestrationPaneTiltTurn,
                  Icons.sync_alt_rounded,
                ),
                _buildTypeChip(
                  context,
                  selectedPane,
                  PaneType.topHopper,
                  l10n.architectFenestrationPaneTopHopper,
                  Icons.arrow_upward_rounded,
                ),
                _buildTypeChip(
                  context,
                  selectedPane,
                  PaneType.doorLeaf,
                  l10n.architectFenestrationPaneDoorLeaf,
                  Icons.door_front_door_rounded,
                ),
              ],
            ),

            const Divider(height: 24),

            // Inner Operable Sash Profile Width Setting
            if (selectedPane.isOpenable) ...[
              Text(
                '${l10n.architectFenestrationSashProfile}: ${(selectedPane.sashProfileWidth * 1000).round()} mm',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Slider(
                value: selectedPane.sashProfileWidth,
                min: 0.050,
                max: 0.085,
                divisions: 7,
                label: '${(selectedPane.sashProfileWidth * 1000).round()} mm',
                onChanged: (val) {
                  final updated = selectedPane.copyWith(sashProfileWidth: val);
                  onChanged(style.updatePane(updated));
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTypeChip(
    BuildContext context,
    FenestrationPane pane,
    PaneType type,
    String label,
    IconData icon,
  ) {
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: pane.paneType == type,
      onSelected: (sel) {
        if (sel) {
          final updatedPane = pane.copyWith(paneType: type);
          final updatedTree = style.rootSubdivision.updatePane(updatedPane);
          onChanged(style.copyWith(rootSubdivision: updatedTree));
        }
      },
      visualDensity: VisualDensity.compact,
    );
  }
}

// ===========================================================================
// SECTION 3: STEP 3 - INFILL & MUNTINS PANEL
// ===========================================================================

/// Step 3: Infill type (Glazing vs Solid Panel) and Muntin Grid (Шпроси).
class FenestrationStep3InfillMuntinsTab extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final String? selectedPaneId;
  final ValueChanged<String?> onSelectPane;
  final ValueChanged<ArchitectFenestrationStyle> onChanged;

  const FenestrationStep3InfillMuntinsTab({
    super.key,
    required this.style,
    required this.selectedPaneId,
    required this.onSelectPane,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final panes = style.rootSubdivision.collectPanes();
    final selectedPane = panes.where((p) => p.id == selectedPaneId).firstOrNull ??
        panes.firstOrNull;

    final isSolid = selectedPane?.isSolidPanel ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.architectFenestrationStep3,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(height: 8),

          // Pane selector if multiple
          if (panes.length > 1) ...[
            Text(
              '${l10n.architectFenestrationSelectedLeaf}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (int i = 0; i < panes.length; i++)
                  ChoiceChip(
                    label: Text('${i + 1}'),
                    selected: panes[i].id == selectedPane?.id,
                    onSelected: (_) => onSelectPane(panes[i].id),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          if (selectedPane != null) ...[
            // Infill Type (Glass vs Solid Panel)
            Text(
              l10n.architectFenestrationPaneType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.layers_rounded, size: 16),
                  label: Text(l10n.architectFenestrationInfillGlazing),
                  selected: !isSolid,
                  onSelected: (sel) {
                    if (sel && isSolid) {
                      final updated = selectedPane.copyWith(
                        paneType: PaneType.fixedGlazing,
                      );
                      onChanged(style.updatePane(updated));
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.view_sidebar_rounded, size: 16),
                  label: Text(l10n.architectFenestrationInfillSolid),
                  selected: isSolid,
                  onSelected: (sel) {
                    if (sel && !isSolid) {
                      final updated = selectedPane.copyWith(
                        paneType: PaneType.solidPanel,
                      );
                      onChanged(style.updatePane(updated));
                    }
                  },
                ),
              ],
            ),

            const Divider(height: 24),

            // Muntin Bars (Шпроси)
            Text(
              l10n.architectFenestrationMuntins,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Muntin Preset Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: Text(l10n.architectFenestrationMuntinNone),
                  onPressed: () {
                    final updated = selectedPane.copyWith(
                      muntinCols: 0,
                      muntinRows: 0,
                    );
                    onChanged(style.updatePane(updated));
                  },
                ),
                ActionChip(
                  label: Text(l10n.architectFenestrationMuntinClassic),
                  onPressed: () {
                    final updated = selectedPane.copyWith(
                      muntinCols: 1,
                      muntinRows: 1,
                    );
                    onChanged(style.updatePane(updated));
                  },
                ),
                ActionChip(
                  label: Text(l10n.architectFenestrationMuntinVictorian),
                  onPressed: () {
                    final updated = selectedPane.copyWith(
                      muntinCols: 1,
                      muntinRows: 2,
                    );
                    onChanged(style.updatePane(updated));
                  },
                ),
                ActionChip(
                  label: Text(l10n.architectFenestrationMuntinGrid3x3),
                  onPressed: () {
                    final updated = selectedPane.copyWith(
                      muntinCols: 2,
                      muntinRows: 2,
                    );
                    onChanged(style.updatePane(updated));
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Vertical Muntins
            Text(
              '${l10n.architectFenestrationMuntinCols}: ${selectedPane.muntinCols}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: selectedPane.muntinCols.toDouble(),
              min: 0,
              max: 6,
              divisions: 6,
              label: '${selectedPane.muntinCols}',
              onChanged: (val) {
                final updated = selectedPane.copyWith(
                  muntinCols: val.round(),
                );
                onChanged(style.updatePane(updated));
              },
            ),

            // Horizontal Muntins
            Text(
              '${l10n.architectFenestrationMuntinRows}: ${selectedPane.muntinRows}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: selectedPane.muntinRows.toDouble(),
              min: 0,
              max: 6,
              divisions: 6,
              label: '${selectedPane.muntinRows}',
              onChanged: (val) {
                final updated = selectedPane.copyWith(
                  muntinRows: val.round(),
                );
                onChanged(style.updatePane(updated));
              },
            ),

            // Muntin Profile Width
            Text(
              '${l10n.architectFenestrationMuntinWidth}: ${(selectedPane.muntinWidth * 1000).round()} mm',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: selectedPane.muntinWidth,
              min: 0.018,
              max: 0.035,
              divisions: 17,
              label: '${(selectedPane.muntinWidth * 1000).round()} mm',
              onChanged: (val) {
                final updated = selectedPane.copyWith(
                  muntinWidth: val,
                );
                onChanged(style.updatePane(updated));
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// SECTION 4: CASING / TRIM TAB PANEL
// ===========================================================================

/// Tab 4: Exterior Casing / Trim parameters (Обрамчване).
class FenestrationCasingTab extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final ValueChanged<ArchitectFenestrationStyle> onChanged;

  const FenestrationCasingTab({
    super.key,
    required this.style,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text(
              l10n.architectFenestrationCasing,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(l10n.architectFenestrationWallContextHelp),
            value: style.hasCasing,
            onChanged: (val) => onChanged(style.copyWith(hasCasing: val)),
            contentPadding: EdgeInsets.zero,
          ),

          if (style.hasCasing) ...[
            const Divider(),
            // Casing Width
            Text(
              '${l10n.architectFenestrationCasingWidth}: ${(style.casingWidth * 100).round()} cm',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: style.casingWidth,
              min: 0.04,
              max: 0.20,
              divisions: 16,
              label: '${(style.casingWidth * 100).round()} cm',
              onChanged: (val) => onChanged(style.copyWith(casingWidth: val)),
            ),

            const SizedBox(height: 8),
            // Casing Projection
            Text(
              '${l10n.architectFenestrationCasingProjection}: ${(style.casingProjection * 100).round()} cm',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: style.casingProjection,
              min: 0.01,
              max: 0.08,
              divisions: 7,
              label: '${(style.casingProjection * 100).round()} cm',
              onChanged: (val) =>
                  onChanged(style.copyWith(casingProjection: val)),
            ),

            const SizedBox(height: 8),
            // Include Bottom Casing
            CheckboxListTile(
              title: Text(l10n.architectFenestrationIncludeBottomCasing),
              value: style.includeBottomCasing,
              onChanged: (val) => onChanged(
                style.copyWith(includeBottomCasing: val ?? false),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 12),
            // Color Swatches
            Text(
              '${l10n.architectFenestrationCasingColor}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildColorCircle(const Color(0xFFECEFF1)), // White/Off-white
                _buildColorCircle(const Color(0xFFCFD8DC)), // Light gray
                _buildColorCircle(const Color(0xFF546E7A)), // Slate gray
                _buildColorCircle(const Color(0xFF263238)), // Anthracite
                _buildColorCircle(const Color(0xFF8D6E63)), // Wood oak
                _buildColorCircle(const Color(0xFF4E342E)), // Dark walnut
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    final isSelected = style.casingColorValue == color.toARGB32();
    return GestureDetector(
      onTap: () => onChanged(style.copyWith(casingColorValue: color.toARGB32())),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white24,
            width: isSelected ? 3.0 : 1.0,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 5: PROFILE & GLAZING SPECS PANEL
// ===========================================================================

/// Tab 5: Frame & Glazing technical specs (5-chamber 70mm & double glass 24mm).
class FenestrationProfileTab extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final ValueChanged<ArchitectFenestrationStyle> onChanged;

  const FenestrationProfileTab({
    super.key,
    required this.style,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5-Chamber Frame
          ListTile(
            leading: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF00E5FF)),
            title: Text(l10n.architectFenestrationFrame5Chamber),
            subtitle: Text(
              '${(style.frameDepth * 1000).round()} mm • '
              '${(style.frameFaceWidth * 1000).round()} mm',
            ),
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(),
          // Double Glazing
          ListTile(
            leading: const Icon(Icons.layers_rounded, color: Color(0xFF0288D1)),
            title: Text(l10n.architectFenestrationGlazingDouble),
            subtitle: Text(
              '${(style.glazingThickness * 1000).round()} mm (4-16-4)',
            ),
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(),
          // Wall Placement Note
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
            title: Text(l10n.architectFenestrationMountingPlane),
            subtitle: Text(l10n.architectFenestrationMountingPlaneHelp),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SECTION 6: PRESETS CATALOG PICKER PANEL
// ===========================================================================

/// Tab 6: Built-in standard preset catalog.
class FenestrationPresetsTab extends StatelessWidget {
  final ValueChanged<ArchitectFenestrationStyle> onSelectPreset;

  const FenestrationPresetsTab({
    super.key,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final presets = ArchitectFenestrationStyle.standardCatalog();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: presets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final p = presets[idx];
        return ListTile(
          leading: Icon(
            p.kind == FenestrationKind.window
                ? Icons.window_rounded
                : Icons.door_front_door_rounded,
            color: const Color(0xFF00E5FF),
          ),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${(p.defaultWidth * 100).round()}x${(p.defaultHeight * 100).round()} cm'
            '${p.hasCasing ? " • ${l10n.architectFenestrationWithCasing}" : ""}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => onSelectPreset(p),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}
