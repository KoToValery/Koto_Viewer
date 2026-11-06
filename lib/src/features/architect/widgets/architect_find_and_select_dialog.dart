// === SECTION: ARCHITECTURAL FIND & SELECT BY CRITERIA DIALOG ===
// Table of Contents:
// 1. TOP-LEVEL LAUNCHER (showArchitectFindAndSelectDialog)
// 2. MAIN DIALOG STATEFUL WIDGET
// 3. CRITERIA CONFIGURATION SECTION
// 4. LIVE MATCHES SUMMARY & STOREY BREAKDOWN
// 5. BATCH MODIFICATION TAB (SKIN ONLY & DIMENSIONS)

import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_fenestration_style.dart';
import '../models/architect_filter_criteria.dart';
import '../services/architect_filter_selection_service.dart';
import '../services/fenestration_library_service.dart';
import '../services/architect_command_controller.dart';
import '../screens/fenestration_editor_screen.dart';

/// Shows the Find & Select / Criteria Selection & Batch Modify dialog.
Future<void> showArchitectFindAndSelectDialog({
  required BuildContext context,
  required ArchitectProject project,
  Set<String> selectedIds = const {},
  required ValueChanged<Set<String>> onSelect,
  required ValueChanged<String> onSwitchStorey,
  required ValueChanged<ArchitectModelCommand> onApplyCommand,
}) async {
  final isCompact = MediaQuery.sizeOf(context).width < 600;

  if (isCompact) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ArchitectFindAndSelectDialog(
          project: project,
          selectedIds: selectedIds,
          onSelect: onSelect,
          onSwitchStorey: onSwitchStorey,
          onApplyCommand: onApplyCommand,
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 620,
            maxHeight: 760,
          ),
          child: ArchitectFindAndSelectDialog(
            project: project,
            selectedIds: selectedIds,
            onSelect: onSelect,
            onSwitchStorey: onSwitchStorey,
            onApplyCommand: onApplyCommand,
          ),
        ),
      ),
    );
  }
}

class ArchitectFindAndSelectDialog extends StatefulWidget {
  final ArchitectProject project;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelect;
  final ValueChanged<String> onSwitchStorey;
  final ValueChanged<ArchitectModelCommand> onApplyCommand;

  const ArchitectFindAndSelectDialog({
    super.key,
    required this.project,
    this.selectedIds = const {},
    required this.onSelect,
    required this.onSwitchStorey,
    required this.onApplyCommand,
  });

  @override
  State<ArchitectFindAndSelectDialog> createState() =>
      _ArchitectFindAndSelectDialogState();
}

class _ArchitectFindAndSelectDialogState
    extends State<ArchitectFindAndSelectDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ArchitectFilterCriteria _criteria;

  // Criteria toggle flags & controllers
  bool _filterWidth = false;
  FilterOperator _widthOp = FilterOperator.exact;
  final _widthCtrl = TextEditingController(text: '1.20');

  bool _filterHeight = false;
  FilterOperator _heightOp = FilterOperator.exact;
  final _heightCtrl = TextEditingController(text: '1.40');

  bool _filterSill = false;
  FilterOperator _sillOp = FilterOperator.exact;
  final _sillCtrl = TextEditingController(text: '0.85');

  bool _filterStyle = false;
  String? _styleId;

  bool _filterSpecId = false;
  FilterStringOperator _specIdOp = FilterStringOperator.exact;
  final _specIdCtrl = TextEditingController(text: 'W1');

  // Batch modification state
  bool _skinOnly = true;
  String? _newStyleId;

  bool _modifyWidth = false;
  final _newWidthCtrl = TextEditingController(text: '1.20');

  bool _modifyHeight = false;
  final _newHeightCtrl = TextEditingController(text: '1.40');

  bool _modifySill = false;
  final _newSillCtrl = TextEditingController(text: '0.85');

  bool _modifySpecId = false;
  final _newSpecIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _criteria = const ArchitectFilterCriteria(
      scope: ArchitectFilterScope.allStoreys,
      fenestrationKind: FenestrationKind.window,
    );

    // If an element is currently selected, automatically sample its criteria
    if (widget.selectedIds.isNotEmpty) {
      _sampleFromSelection(widget.selectedIds.first);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _sillCtrl.dispose();
    _specIdCtrl.dispose();
    _newWidthCtrl.dispose();
    _newHeightCtrl.dispose();
    _newSillCtrl.dispose();
    _newSpecIdCtrl.dispose();
    super.dispose();
  }

  void _sampleFromSelection(String elementId) {
    final sampled = ArchitectFilterSelectionService.sampleFromElement(
      widget.project,
      elementId,
    );

    setState(() {
      _criteria = _criteria.copyWith(
        fenestrationKind: sampled.fenestrationKind,
      );

      if (sampled.widthFilter != null) {
        _filterWidth = true;
        _widthOp = sampled.widthFilter!.operator;
        _widthCtrl.text = sampled.widthFilter!.value.toStringAsFixed(2);
      }
      if (sampled.heightFilter != null) {
        _filterHeight = true;
        _heightOp = sampled.heightFilter!.operator;
        _heightCtrl.text = sampled.heightFilter!.value.toStringAsFixed(2);
      }
      if (sampled.sillHeightFilter != null) {
        _filterSill = true;
        _sillOp = sampled.sillHeightFilter!.operator;
        _sillCtrl.text = sampled.sillHeightFilter!.value.toStringAsFixed(2);
      }
      if (sampled.styleIdFilter != null &&
          sampled.styleIdFilter!.isNotEmpty) {
        _filterStyle = true;
        _styleId = sampled.styleIdFilter;
      }
      if (sampled.specIdFilter != null) {
        _filterSpecId = true;
        _specIdOp = sampled.specIdFilter!.operator;
        _specIdCtrl.text = sampled.specIdFilter!.value;
      }

      _rebuildCriteria();
    });
  }

  void _rebuildCriteria() {
    final wVal = double.tryParse(_widthCtrl.text.replaceAll(',', '.'));
    final hVal = double.tryParse(_heightCtrl.text.replaceAll(',', '.'));
    final sVal = double.tryParse(_sillCtrl.text.replaceAll(',', '.'));

    _criteria = _criteria.copyWith(
      widthFilter: _filterWidth && wVal != null
          ? DimensionFilterCriteria(operator: _widthOp, value: wVal)
          : null,
      clearWidthFilter: !_filterWidth || wVal == null,
      heightFilter: _filterHeight && hVal != null
          ? DimensionFilterCriteria(operator: _heightOp, value: hVal)
          : null,
      clearHeightFilter: !_filterHeight || hVal == null,
      sillHeightFilter: _filterSill && sVal != null
          ? DimensionFilterCriteria(operator: _sillOp, value: sVal)
          : null,
      clearSillHeightFilter: !_filterSill || sVal == null,
      styleIdFilter: _filterStyle ? _styleId : null,
      clearStyleIdFilter: !_filterStyle,
      specIdFilter: _filterSpecId && _specIdCtrl.text.trim().isNotEmpty
          ? StringFilterCriteria(
              operator: _specIdOp,
              value: _specIdCtrl.text.trim(),
            )
          : null,
      clearSpecIdFilter: !_filterSpecId || _specIdCtrl.text.trim().isEmpty,
    );
  }

  List<ArchitectFilterMatch> _evaluateMatches() {
    return ArchitectFilterSelectionService.query(widget.project, _criteria);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final matches = _evaluateMatches();
    final storeysCount = matches.map((m) => m.storeyId).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.architectFindAndSelect),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.colorize, size: 18),
                label: Text(l.architectSampleFromSelection),
                onPressed: () =>
                    _sampleFromSelection(widget.selectedIds.first),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.search, size: 20),
              text: l.architectToolSelect,
            ),
            Tab(
              icon: const Icon(Icons.tune, size: 20),
              text: l.architectBatchModify,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Matches Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
            child: Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.architectFilterMatchesCount(matches.length, storeysCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchAndSelectTab(matches),
                _buildBatchModifyTab(matches),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSelectTab(List<ArchitectFilterMatch> matches) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final activeStoreyMatches = matches
        .where((m) => m.storeyId == widget.project.activeStoreyId)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Scope selection
        Text(
          l.architectScopeAllStoreys,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ArchitectFilterScope>(
          segments: [
            ButtonSegment(
              value: ArchitectFilterScope.allStoreys,
              label: Text(l.architectScopeAllStoreys),
              icon: const Icon(Icons.apartment, size: 18),
            ),
            ButtonSegment(
              value: ArchitectFilterScope.activeStorey,
              label: Text(l.architectScopeActiveStorey),
              icon: const Icon(Icons.layers, size: 18),
            ),
          ],
          selected: {_criteria.scope},
          onSelectionChanged: (set) {
            setState(() {
              _criteria = _criteria.copyWith(scope: set.first);
            });
          },
        ),
        const SizedBox(height: 16),

        // 2. Element Kind
        Row(
          children: [
            FilterChip(
              label: Text(l.architectToolWindow),
              avatar: const AppIcon(AppIconId.window, size: 16),
              selected: _criteria.fenestrationKind == FenestrationKind.window,
              onSelected: (sel) {
                setState(() {
                  _criteria = _criteria.copyWith(
                    fenestrationKind: FenestrationKind.window,
                  );
                  _styleId = null;
                  _newStyleId = null;
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l.architectToolDoor),
              avatar: const AppIcon(AppIconId.door, size: 16),
              selected: _criteria.fenestrationKind == FenestrationKind.door,
              onSelected: (sel) {
                setState(() {
                  _criteria = _criteria.copyWith(
                    fenestrationKind: FenestrationKind.door,
                  );
                  _styleId = null;
                  _newStyleId = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Criteria Filter Rows
        Text(
          l.architectFilterCriteria,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Width
        _buildDimensionFilterRow(
          label: l.architectPropertyWidth,
          active: _filterWidth,
          onActiveChanged: (val) {
            setState(() {
              _filterWidth = val;
              _rebuildCriteria();
            });
          },
          op: _widthOp,
          onOpChanged: (op) {
            setState(() {
              _widthOp = op;
              _rebuildCriteria();
            });
          },
          controller: _widthCtrl,
        ),
        const SizedBox(height: 8),

        // Height
        _buildDimensionFilterRow(
          label: l.architectPropertyHeight,
          active: _filterHeight,
          onActiveChanged: (val) {
            setState(() {
              _filterHeight = val;
              _rebuildCriteria();
            });
          },
          op: _heightOp,
          onOpChanged: (op) {
            setState(() {
              _heightOp = op;
              _rebuildCriteria();
            });
          },
          controller: _heightCtrl,
        ),
        const SizedBox(height: 8),

        // Sill Height
        _buildDimensionFilterRow(
          label: l.architectPropertySill,
          active: _filterSill,
          onActiveChanged: (val) {
            setState(() {
              _filterSill = val;
              _rebuildCriteria();
            });
          },
          op: _sillOp,
          onOpChanged: (op) {
            setState(() {
              _sillOp = op;
              _rebuildCriteria();
            });
          },
          controller: _sillCtrl,
        ),
        const SizedBox(height: 8),

        // Style / Raster Filter
        Builder(
          builder: (context) {
            final styles = FenestrationLibraryService.instance.getStylesForKind(
              _criteria.fenestrationKind ?? FenestrationKind.window,
            );
            final hasMatch = _styleId != null && styles.any((s) => s.id == _styleId);

            return Card.outlined(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _filterStyle,
                      onChanged: (val) {
                        setState(() {
                          _filterStyle = val ?? false;
                          _rebuildCriteria();
                        });
                      },
                    ),
                    Text(
                      l.architectFenestrationStyle,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: hasMatch || _styleId != null ? _styleId : null,
                        hint: Text(l.architectFilterAnyStyle),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(l.architectFilterAnyStyle),
                          ),
                          for (final s in styles)
                            DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.localizedName(l),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (_styleId != null && !hasMatch)
                            DropdownMenuItem(
                              value: _styleId,
                              child: Text(
                                _styleId!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _filterStyle
                            ? (val) {
                                setState(() {
                                  _styleId = val;
                                  _rebuildCriteria();
                                });
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Spec ID Filter
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _filterSpecId,
                  onChanged: (val) {
                    setState(() {
                      _filterSpecId = val ?? false;
                      _rebuildCriteria();
                    });
                  },
                ),
                Text(l.architectDoorSpecId, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: DropdownButton<FilterStringOperator>(
                    value: _specIdOp,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(
                        value: FilterStringOperator.exact,
                        child: Text(l.architectOperatorExact),
                      ),
                      DropdownMenuItem(
                        value: FilterStringOperator.contains,
                        child: const Text('Contains'),
                      ),
                    ],
                    onChanged: _filterSpecId
                        ? (val) {
                            if (val != null) {
                              setState(() {
                                _specIdOp = val;
                                _rebuildCriteria();
                              });
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _specIdCtrl,
                    enabled: _filterSpecId,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _rebuildCriteria(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        if (activeStoreyMatches.isNotEmpty)
          FilledButton.icon(
            icon: const Icon(Icons.check_box_outlined),
            label: Text(
              '${l.architectSelectMatching} (${activeStoreyMatches.length})',
            ),
            onPressed: () {
              final ids = activeStoreyMatches.map((m) => m.elementId).toSet();
              widget.onSelect(ids);
              Navigator.of(context).pop();
            },
          ),
        const SizedBox(height: 16),

        // Storey breakdown list
        if (matches.isNotEmpty) ...[
          Text(
            '${l.architectScopeAllStoreys}:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ..._buildStoreyMatchesCards(matches),
        ],
      ],
    );
  }

  List<Widget> _buildStoreyMatchesCards(List<ArchitectFilterMatch> matches) {
    final l = context.l10n;
    final byStorey = <String, List<ArchitectFilterMatch>>{};
    for (final m in matches) {
      byStorey.putIfAbsent(m.storeyId, () => []).add(m);
    }

    return byStorey.entries.map((entry) {
      final storeyId = entry.key;
      final storeyMatches = entry.value;
      final storeyName = storeyMatches.first.storeyName;
      final isCurrent = storeyId == widget.project.activeStoreyId;

      return Card.filled(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: Icon(
            isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 20,
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(
            '$storeyName (${storeyMatches.length})',
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isCurrent
              ? TextButton(
                  onPressed: () {
                    widget.onSelect(
                      storeyMatches.map((m) => m.elementId).toSet(),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(l.architectToolSelect),
                )
              : TextButton(
                  onPressed: () {
                    widget.onSwitchStorey(storeyId);
                    widget.onSelect(
                      storeyMatches.map((m) => m.elementId).toSet(),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(l.architectSwitchStoreyAndSelect),
                ),
        ),
      );
    }).toList();
  }

  Widget _buildDimensionFilterRow({
    required String label,
    required bool active,
    required ValueChanged<bool> onActiveChanged,
    required FilterOperator op,
    required ValueChanged<FilterOperator> onOpChanged,
    required TextEditingController controller,
  }) {
    final l = context.l10n;

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: active,
              onChanged: (val) => onActiveChanged(val ?? false),
            ),
            SizedBox(
              width: 90,
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 85,
              child: DropdownButton<FilterOperator>(
                value: op,
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(
                    value: FilterOperator.exact,
                    child: Text(l.architectOperatorExact),
                  ),
                  DropdownMenuItem(
                    value: FilterOperator.greaterThan,
                    child: Text(l.architectOperatorGreater),
                  ),
                  DropdownMenuItem(
                    value: FilterOperator.lessThan,
                    child: Text(l.architectOperatorLess),
                  ),
                ],
                onChanged: active
                    ? (val) {
                        if (val != null) onOpChanged(val);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: active,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: widget.project.units.symbol,
                ),
                onChanged: (_) => _rebuildCriteria(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 5: BATCH MODIFICATION TAB (SKIN ONLY & DIMENSIONS)
  // ===========================================================================

  Widget _buildBatchModifyTab(List<ArchitectFilterMatch> matches) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final targetKind = _criteria.fenestrationKind ?? FenestrationKind.window;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Target Raster / Skin Selection
        Text(
          l.architectTargetRasterStyle,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final styles =
                FenestrationLibraryService.instance.getStylesForKind(targetKind);
            final hasMatch =
                _newStyleId != null && styles.any((s) => s.id == _newStyleId);

            return DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: hasMatch || _newStyleId != null ? _newStyleId : null,
              decoration: InputDecoration(
                labelText: l.architectTargetRasterStyle,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final s in styles)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.localizedName(l),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (_newStyleId != null && !hasMatch)
                  DropdownMenuItem(
                    value: _newStyleId,
                    child: Text(
                      _newStyleId!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (val) {
                setState(() {
                  _newStyleId = val;
                });
              },
            );
          },
        ),
        const SizedBox(height: 8),

        // "Design Custom Raster" button
        OutlinedButton.icon(
          icon: const Icon(Icons.tune, size: 18),
          label: Text(l.architectCreateCustomRaster),
          onPressed: () async {
            final result = await Navigator.of(context).push<ArchitectFenestrationStyle?>(
              MaterialPageRoute(
                builder: (_) => FenestrationEditorScreen(
                  initialKind: targetKind,
                  createNew: true,
                ),
              ),
            );
            if (result != null && mounted) {
              await FenestrationLibraryService.instance.saveStyle(result);
              setState(() {
                _newStyleId = result.id;
              });
            }
          },
        ),
        const SizedBox(height: 12),

        // CRITICAL TOGGLE: Skin Only (Keep Dimensions)
        Card.filled(
          color: theme.colorScheme.primaryContainer.withAlpha(80),
          child: SwitchListTile.adaptive(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              l.architectSkinOnly,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              l.architectSkinOnlyDesc,
              style: theme.textTheme.bodySmall,
            ),
            value: _skinOnly,
            onChanged: (val) => setState(() => _skinOnly = val),
          ),
        ),
        const Divider(height: 32),

        // Optional Dimension Overrides
        Text(
          l.architectChangeDimensions,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildDimensionOverrideRow(
          label: l.architectNewWidth,
          active: _modifyWidth,
          onActiveChanged: (v) => setState(() => _modifyWidth = v),
          controller: _newWidthCtrl,
        ),
        const SizedBox(height: 8),
        _buildDimensionOverrideRow(
          label: l.architectNewHeight,
          active: _modifyHeight,
          onActiveChanged: (v) => setState(() => _modifyHeight = v),
          controller: _newHeightCtrl,
        ),
        const SizedBox(height: 8),
        _buildDimensionOverrideRow(
          label: l.architectNewSillHeight,
          active: _modifySill,
          onActiveChanged: (v) => setState(() => _modifySill = v),
          controller: _newSillCtrl,
        ),
        const SizedBox(height: 8),

        // Optional Mark Override
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _modifySpecId,
                  onChanged: (v) => setState(() => _modifySpecId = v ?? false),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    l.architectChangeSpecId,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newSpecIdCtrl,
                    enabled: _modifySpecId,
                    decoration: InputDecoration(
                      labelText: l.architectNewSpecId,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Apply Batch Modification Button
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.done_all),
          label: Text(l.architectBatchModifyApply(matches.length)),
          onPressed: matches.isEmpty
              ? null
              : () {
                  final parsedW = _modifyWidth
                      ? double.tryParse(_newWidthCtrl.text.replaceAll(',', '.'))
                      : null;
                  final parsedH = _modifyHeight
                      ? double.tryParse(_newHeightCtrl.text.replaceAll(',', '.'))
                      : null;
                  final parsedS = _modifySill
                      ? double.tryParse(_newSillCtrl.text.replaceAll(',', '.'))
                      : null;
                  final parsedSpec = _modifySpecId ? _newSpecIdCtrl.text : null;

                  final command = BatchModifyArchitectElementsCommand(
                    targetMatches: matches,
                    skinOnly: _skinOnly,
                    newStyleId: _newStyleId,
                    newWidth: parsedW,
                    newHeight: parsedH,
                    newSillHeight: parsedS,
                    newSpecId: parsedSpec,
                  );

                  widget.onApplyCommand(command);
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l.architectBatchModifySuccess(
                          matches.length,
                          matches.map((m) => m.storeyId).toSet().length,
                        ),
                      ),
                    ),
                  );
                },
        ),
      ],
    );
  }

  Widget _buildDimensionOverrideRow({
    required String label,
    required bool active,
    required ValueChanged<bool> onActiveChanged,
    required TextEditingController controller,
  }) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: active,
              onChanged: (v) => onActiveChanged(v ?? false),
            ),
            SizedBox(
              width: 120,
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: active,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixText: widget.project.units.symbol,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
