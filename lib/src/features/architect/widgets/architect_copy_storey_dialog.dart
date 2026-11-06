// === SECTION: ARCHITECT COPY STOREY DIALOG ===
// Table of Contents:
// 1. DIALOG CONTAINER & STATE
// 2. SOURCE & SELECTION MODE SECTION
// 3. CATEGORY CHIP SELECTORS WITH ELEMENT COUNTS
// 4. TARGET STOREYS MULTI-SELECT & BATCH ADDER
// 5. CONFLICT RESOLUTION (Replace vs Merge) & HEIGHT ADAPTATION OPTIONS
// 6. ACTION FOOTER & DISPATCH

import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_storey_copy_types.dart';
import '../services/architect_command_controller.dart';

class ArchitectCopyStoreyDialog extends StatefulWidget {
  final ArchitectProject project;
  final String initialSourceStoreyId;
  final Set<String>? selectedElementIds;
  final ValueChanged<StoreyCopyOptions>? onCopyRequested;

  const ArchitectCopyStoreyDialog({
    super.key,
    required this.project,
    required this.initialSourceStoreyId,
    this.selectedElementIds,
    this.onCopyRequested,
  });

  static Future<StoreyCopyOptions?> show(
    BuildContext context, {
    required ArchitectProject project,
    required String initialSourceStoreyId,
    Set<String>? selectedElementIds,
  }) {
    return showDialog<StoreyCopyOptions>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ArchitectCopyStoreyDialog(
        project: project,
        initialSourceStoreyId: initialSourceStoreyId,
        selectedElementIds: selectedElementIds,
        onCopyRequested: (options) => Navigator.of(context).pop(options),
      ),
    );
  }

  @override
  State<ArchitectCopyStoreyDialog> createState() =>
      _ArchitectCopyStoreyDialogState();
}

class _ArchitectCopyStoreyDialogState extends State<ArchitectCopyStoreyDialog> {
  late String _sourceStoreyId;
  late Set<String> _targetStoreyIds;
  late Set<ArchitectStoreyElementType> _selectedCategories;
  late StoreyCopyMode _mode;
  late bool _adjustWallHeights;
  late bool _adjustLevelMarkers;
  late bool _preserveGroups;
  late bool _copyOnlySelection;

  bool _showBatchAdder = false;
  int _batchCount = 3;
  double _batchHeight = 2.80;
  late ArchitectProject _workingProject;

  @override
  void initState() {
    super.initState();
    _workingProject = widget.project;
    _sourceStoreyId = widget.initialSourceStoreyId;
    _copyOnlySelection = widget.selectedElementIds != null &&
        widget.selectedElementIds!.isNotEmpty;
    _mode = StoreyCopyMode.replace;
    _adjustWallHeights = true;
    _adjustLevelMarkers = true;
    _preserveGroups = true;

    _selectedCategories = Set.of(
      ArchitectStoreyElementType.defaultTypicalCategories,
    );

    // Default target storeys: all normal storeys above the source storey
    _targetStoreyIds = _defaultTargetStoreys();
  }

  Set<String> _defaultTargetStoreys() {
    final source = _workingProject.storeys
        .where((s) => s.id == _sourceStoreyId)
        .firstOrNull;
    if (source == null) return {};

    final targets = _workingProject.storeys
        .where((s) => !s.isRoof && s.elevation > source.elevation)
        .map((s) => s.id)
        .toSet();

    if (targets.isEmpty) {
      // If none above, pick all other normal storeys
      return _workingProject.storeys
          .where((s) => !s.isRoof && s.id != _sourceStoreyId)
          .map((s) => s.id)
          .toSet();
    }
    return targets;
  }

  ArchitectStorey? get _sourceStorey => _workingProject.storeys
      .where((s) => s.id == _sourceStoreyId)
      .firstOrNull;

  void _selectAllAbove() {
    final source = _sourceStorey;
    if (source == null) return;
    setState(() {
      _targetStoreyIds = _workingProject.storeys
          .where((s) => !s.isRoof && s.elevation > source.elevation)
          .map((s) => s.id)
          .toSet();
    });
  }

  void _selectAllStoreys() {
    setState(() {
      _targetStoreyIds = _workingProject.storeys
          .where((s) => !s.isRoof && s.id != _sourceStoreyId)
          .map((s) => s.id)
          .toSet();
    });
  }

  void _batchAddTypicalStoreys() {
    if (_batchCount <= 0) return;
    setState(() {
      _workingProject = _workingProject.batchAddTypicalStoreys(
        count: _batchCount,
        typicalHeight: _batchHeight,
      );
      _targetStoreyIds = _defaultTargetStoreys();
      _showBatchAdder = false;
    });
  }

  int _countElementsToCopy() {
    final source = _sourceStorey;
    if (source == null) return 0;
    final filter = _copyOnlySelection ? widget.selectedElementIds : null;
    var count = 0;
    for (final cat in _selectedCategories) {
      count += cat.countInStorey(source, filterIds: filter);
    }
    return count;
  }

  void _submit() {
    final l = context.l10n;
    if (_targetStoreyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.architectNoTargetStoreysSelected),
          backgroundColor: Colors.amber[900],
        ),
      );
      return;
    }

    final total = _countElementsToCopy();
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.architectNoElementsSelected),
          backgroundColor: Colors.amber[900],
        ),
      );
      return;
    }

    final options = StoreyCopyOptions(
      sourceStoreyId: _sourceStoreyId,
      targetStoreyIds: _targetStoreyIds,
      elementTypes: _selectedCategories,
      selectedElementIds:
          _copyOnlySelection ? widget.selectedElementIds : null,
      mode: _mode,
      adjustWallHeights: _adjustWallHeights,
      adjustLevelMarkers: _adjustLevelMarkers,
      preserveGroups: _preserveGroups,
    );

    if (widget.onCopyRequested != null) {
      widget.onCopyRequested!(options);
    } else {
      Navigator.of(context).pop(options);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final normalStoreys = _workingProject.storeys
        .where((s) => !s.isRoof)
        .toList()
      ..sort((a, b) => b.elevation.compareTo(a.elevation));

    final source = _sourceStorey;
    final elementsCount = _countElementsToCopy();
    final targetCount = _targetStoreyIds.length;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const AppIcon(
                    AppIconId.duplicate,
                    color: Color(0xFF00E5FF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.architectCopyElementsByStorey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l.architectStoreysScreenTitle,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIconId.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  // Scope Toggle (if selection exists)
                  if (widget.selectedElementIds != null &&
                      widget.selectedElementIds!.isNotEmpty) ...[
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l.architectCopyAllStoreyElements),
                          icon: const Icon(Icons.layers_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(
                            l.architectCopySelectedOnly(
                              widget.selectedElementIds!.length,
                            ),
                          ),
                          icon: const Icon(Icons.check_box_rounded, size: 16),
                        ),
                      ],
                      selected: {_copyOnlySelection},
                      onSelectionChanged: (set) =>
                          setState(() => _copyOnlySelection = set.first),
                      style: SegmentedButton.styleFrom(
                        backgroundColor: const Color(0xFF282834),
                        selectedBackgroundColor: const Color(0xFF00E5FF),
                        selectedForegroundColor: Colors.black,
                        foregroundColor: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Source Storey Selection
                  Row(
                    children: [
                      Text(
                        l.architectCopySourceStorey,
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282834),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sourceStoreyId,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF282834),
                              items: [
                                for (final s in normalStoreys)
                                  DropdownMenuItem(
                                    value: s.id,
                                    child: Text(
                                      '${s.name} (${s.elevationLabel})',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                              onChanged: (id) {
                                if (id == null) return;
                                setState(() {
                                  _sourceStoreyId = id;
                                  _targetStoreyIds = _defaultTargetStoreys();
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Categories Filter
                  Row(
                    children: [
                      const Text(
                        'Категории елементи',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedCategories = Set.of(
                            ArchitectStoreyElementType.defaultTypicalCategories,
                          );
                        }),
                        child: Text(l.architectSelectAllStoreys),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedCategories.clear()),
                        child: Text(l.architectClearStoreySelection),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat
                          in ArchitectStoreyElementType.defaultTypicalCategories)
                        _buildCategoryChip(cat, source),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Target Storeys Section
                  Row(
                    children: [
                      Text(
                        l.architectCopyTargetStoreys,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _selectAllAbove,
                        child: Text(l.architectSelectAllAbove),
                      ),
                      TextButton(
                        onPressed: _selectAllStoreys,
                        child: Text(l.architectSelectAllStoreys),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _targetStoreyIds.clear()),
                        child: Text(l.architectClearStoreySelection),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF282834),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                      children: [
                        for (final s in normalStoreys)
                          if (s.id != _sourceStoreyId)
                            CheckboxListTile(
                              dense: true,
                              activeColor: const Color(0xFF00E5FF),
                              checkColor: Colors.black,
                              value: _targetStoreyIds.contains(s.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _targetStoreyIds.add(s.id);
                                  } else {
                                    _targetStoreyIds.remove(s.id);
                                  }
                                });
                              },
                              title: Text(
                                '${s.name} · ${s.elevationLabel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'H = ${s.height.toStringAsFixed(2)} m · ${l.architectStoreyElementsCount(s.walls.length + s.columns.length + s.slabs.length + s.zones.length)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                      ],
                    ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Batch Storey Generator Expansion
                  if (!_showBatchAdder)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: Text(l.architectBatchAddStoreys),
                        onPressed: () => setState(() => _showBatchAdder = true),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242430),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _batchCount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l.architectBatchAddCount,
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) =>
                                  _batchCount = int.tryParse(v) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _batchHeight.toStringAsFixed(2),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: l.architectBatchAddHeight,
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) =>
                                  _batchHeight = double.tryParse(v) ?? 2.80,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _batchAddTypicalStoreys,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                            ),
                            child: Text(l.architectBatchAddButton),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _showBatchAdder = false),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // 4. Mode & Adaptation Settings
                  Text(
                    l.architectCopyModeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282834),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                      children: [
                        RadioListTile<StoreyCopyMode>(
                          dense: true,
                          activeColor: const Color(0xFF00E5FF),
                          value: StoreyCopyMode.replace,
                          groupValue: _mode,
                          onChanged: (m) => setState(() => _mode = m!),
                          title: Text(
                            l.architectCopyModeReplace,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            l.architectCopyModeReplaceHelp,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        RadioListTile<StoreyCopyMode>(
                          dense: true,
                          activeColor: const Color(0xFF00E5FF),
                          value: StoreyCopyMode.merge,
                          groupValue: _mode,
                          onChanged: (m) => setState(() => _mode = m!),
                          title: Text(
                            l.architectCopyModeMerge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            l.architectCopyModeMergeHelp,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white12),
                        SwitchListTile(
                          dense: true,
                          activeColor: const Color(0xFF00E5FF),
                          value: _adjustWallHeights,
                          onChanged: (v) =>
                              setState(() => _adjustWallHeights = v),
                          title: Text(
                            l.architectAdjustWallHeightsToStorey,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          activeColor: const Color(0xFF00E5FF),
                          value: _adjustLevelMarkers,
                          onChanged: (v) =>
                              setState(() => _adjustLevelMarkers = v),
                          title: Text(
                            l.architectAdjustElevationMarkers,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          activeColor: const Color(0xFF00E5FF),
                          value: _preserveGroups,
                          onChanged: (v) =>
                              setState(() => _preserveGroups = v),
                          title: Text(
                            l.architectPreserveGroups,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282834),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '$elementsCount ел. ➔ $targetCount ет.',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: targetCount > 0 && elementsCount > 0
                        ? _submit
                        : null,
                    icon: const AppIcon(
                      AppIconId.duplicate,
                      size: 16,
                      color: Colors.black,
                    ),
                    label: Text(
                      l.architectCopyElementsButton,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    ArchitectStoreyElementType cat,
    ArchitectStorey? source,
  ) {
    final count = source != null
        ? cat.countInStorey(
            source,
            filterIds: _copyOnlySelection ? widget.selectedElementIds : null,
          )
        : 0;
    final isSelected = _selectedCategories.contains(cat);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.black)
          : null,
      label: Text('${cat.localizedLabel(context.l10n)} ($count)'),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFF282834),
      selectedColor: const Color(0xFF00E5FF),
      side: BorderSide(
        color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCategories.add(cat);
          } else {
            _selectedCategories.remove(cat);
          }
        });
      },
    );
  }
}
