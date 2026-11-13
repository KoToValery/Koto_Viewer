import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_storey_copy_types.dart';
import 'architect_dialog.dart';

/// Transfer form with local staging; the workspace owns command execution.
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
  }) => showDialog<StoreyCopyOptions>(
    context: context,
    builder: (context) => ArchitectCopyStoreyDialog(
      project: project,
      initialSourceStoreyId: initialSourceStoreyId,
      selectedElementIds: selectedElementIds,
      onCopyRequested: (options) => Navigator.of(context).pop(options),
    ),
  );

  @override
  State<ArchitectCopyStoreyDialog> createState() =>
      _ArchitectCopyStoreyDialogState();
}

class _ArchitectCopyStoreyDialogState extends State<ArchitectCopyStoreyDialog> {
  // One row owns every enum represented by its localized category label.
  static const _categoryGroups = [
    [ArchitectStoreyElementType.walls],
    [ArchitectStoreyElementType.columns],
    [ArchitectStoreyElementType.beams],
    [ArchitectStoreyElementType.slabs],
    [ArchitectStoreyElementType.zones],
    [ArchitectStoreyElementType.stairs, ArchitectStoreyElementType.openings],
    [
      ArchitectStoreyElementType.dimensions,
      ArchitectStoreyElementType.elevationMarkers,
    ],
    [
      ArchitectStoreyElementType.annotations,
      ArchitectStoreyElementType.cadPrimitives,
    ],
    [
      ArchitectStoreyElementType.components,
      ArchitectStoreyElementType.floorDrains,
      ArchitectStoreyElementType.decorativeElements,
    ],
  ];

  late ArchitectProject _workingProject = widget.project;
  late String _sourceStoreyId;
  Set<String> _targetStoreyIds = {};
  final _selectedCategories = Set.of(
    ArchitectStoreyElementType.defaultTypicalCategories,
  );
  StoreyCopyMode _mode = StoreyCopyMode.replace;
  bool _adjustWallHeights = true;
  bool _adjustLevelMarkers = true;
  bool _preserveGroups = true;
  late bool _copyOnlySelection;

  List<ArchitectStorey> get _normalStoreys =>
      _workingProject.storeys.where((s) => !s.isRoof).toList()
        ..sort((a, b) => b.elevation.compareTo(a.elevation));

  ArchitectStorey? get _sourceStorey =>
      _workingProject.storeys.where((s) => s.id == _sourceStoreyId).firstOrNull;

  bool get _hasSelection =>
      _sourceStoreyId == widget.initialSourceStoreyId &&
      (widget.selectedElementIds?.isNotEmpty ?? false);

  Set<String>? get _selectionFilter =>
      _hasSelection && _copyOnlySelection ? widget.selectedElementIds : null;

  @override
  void initState() {
    super.initState();
    final normal = _normalStoreys;
    _sourceStoreyId = normal.any((s) => s.id == widget.initialSourceStoreyId)
        ? widget.initialSourceStoreyId
        : normal.firstOrNull?.id ?? '';
    _copyOnlySelection = _hasSelection;
    _targetStoreyIds = _defaultTargets();
  }

  Set<String> _targetsAbove() => {
    for (final s in _normalStoreys)
      if (s.id != _sourceStoreyId &&
          s.elevation > (_sourceStorey?.elevation ?? double.infinity))
        s.id,
  };

  Set<String> _allTargets() => {
    for (final s in _normalStoreys)
      if (s.id != _sourceStoreyId) s.id,
  };

  Set<String> _defaultTargets() {
    final above = _targetsAbove();
    return above.isEmpty ? _allTargets() : above;
  }

  int _count(
    ArchitectStorey? storey,
    Iterable<ArchitectStoreyElementType> types, {
    Set<String>? filter,
  }) => storey == null
      ? 0
      : types.fold(
          0,
          (total, type) =>
              total + type.countInStorey(storey, filterIds: filter),
        );

  int get _elementCount =>
      _count(_sourceStorey, _selectedCategories, filter: _selectionFilter);

  int get _replacementCount => _workingProject.storeys
      .where((s) => _targetStoreyIds.contains(s.id))
      .fold(0, (total, s) => total + _count(s, _selectedCategories));

  void _changeSource(String? id) {
    if (id == null || id == _sourceStoreyId) return;
    setState(() {
      _sourceStoreyId = id;
      _copyOnlySelection = false;
      _targetStoreyIds = _defaultTargets();
    });
  }

  void _submit() {
    if (_targetStoreyIds.isEmpty || _elementCount == 0) return;
    final originalIds = widget.project.storeys.map((s) => s.id).toSet();
    final options = StoreyCopyOptions(
      sourceStoreyId: _sourceStoreyId,
      targetStoreyIds: Set.of(_targetStoreyIds),
      elementTypes: Set.of(_selectedCategories),
      selectedElementIds: _selectionFilter == null
          ? null
          : Set.of(_selectionFilter!),
      additionalStoreys: [
        for (final s in _workingProject.storeys)
          if (!originalIds.contains(s.id)) s,
      ],
      mode: _mode,
      adjustWallHeights: _adjustWallHeights,
      adjustLevelMarkers: _adjustLevelMarkers,
      preserveGroups: _preserveGroups,
    );
    if (widget.onCopyRequested case final callback?) {
      callback(options);
    } else {
      Navigator.of(context).pop(options);
    }
  }

  Future<void> _addStoreys() async {
    final l = context.l10n;
    final form = GlobalKey<FormState>();
    var count = 3;
    var height = _sourceStorey?.height ?? 2.8;
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => architectAlertDialog(
        title: Text(l.architectCopyNewStoreys),
        content: SizedBox(
          width: 340,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('architect-copy-batch-count'),
                  initialValue: '$count',
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.architectBatchAddCount,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 1 || parsed > 100
                        ? l.architectCopyBatchInvalid
                        : null;
                  },
                  onSaved: (value) => count = int.parse(value!.trim()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('architect-copy-batch-height'),
                  initialValue: height.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.architectBatchAddHeight,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      value?.trim().replaceAll(',', '.') ?? '',
                    );
                    return parsed == null || !parsed.isFinite || parsed <= 0
                        ? l.architectCopyBatchInvalid
                        : null;
                  },
                  onSaved: (value) =>
                      height = double.parse(value!.trim().replaceAll(',', '.')),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('architect-copy-batch-submit'),
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(context, true);
            },
            child: Text(l.architectBatchAddButton),
          ),
        ],
      ),
    );
    if (added != true || !mounted) return;
    setState(() {
      final originalIds = _workingProject.storeys.map((s) => s.id).toSet();
      for (var i = 0; i < count; i++) {
        _workingProject = _workingProject.addStoreyAbove(
          name: l.architectCopyStoreyName(_normalStoreys.length + 1),
          height: height,
        );
      }
      _targetStoreyIds.addAll({
        for (final s in _normalStoreys)
          if (!originalIds.contains(s.id)) s.id,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    // Use the same neutral form surfaces as the architectural property editors.
    final scheme = base.colorScheme.copyWith(
      surface: dark ? const Color(0xff20242b) : Colors.white,
      onSurface: dark ? const Color(0xffe6e8eb) : const Color(0xff20252d),
      onSurfaceVariant: dark
          ? const Color(0xffb3bac5)
          : const Color(0xff586270),
      outlineVariant: dark ? const Color(0xff3c444f) : const Color(0xffe1e5eb),
      surfaceContainerLow: dark
          ? const Color(0xff262b33)
          : const Color(0xfff7f8fa),
      surfaceTint: Colors.transparent,
    );
    final theme = base.copyWith(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Dialog(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 850),
            child: RepaintBoundary(
              key: const ValueKey('architect-copy-surface'),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 760 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(context),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Expanded(
                        child: wide
                            ? _wideBody(context)
                            : _compactBody(context),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      _footer(context, wide: wide),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppIcon(
              AppIconId.duplicate,
              size: 22,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.architectCopyDialogTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const AppIcon(AppIconId.close, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _wideBody(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sourceSection(context),
              const SizedBox(height: 20),
              _categoriesSection(context),
            ],
          ),
        ),
      ),
      VerticalDivider(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      Expanded(
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _targetsSection(context),
              const SizedBox(height: 24),
              _settingsSection(context),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _compactBody(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('architect-copy-scroll'),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sourceSection(context),
        const SizedBox(height: 28),
        _categoriesSection(context),
        const SizedBox(height: 28),
        _targetsSection(context),
        const SizedBox(height: 24),
        _settingsSection(context),
      ],
    ),
  );

  Widget _sectionTitle(BuildContext context, int number, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text('$number', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceSection(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context, 1, l.architectCopyFrom),
        DropdownButtonFormField<String>(
          key: const ValueKey('architect-copy-source'),
          initialValue: _sourceStorey?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.architectCopySourceStorey,
            floatingLabelBehavior: FloatingLabelBehavior.never,
          ),
          // Newly staged levels are empty destinations, never source templates.
          items: [
            for (final storey in _normalStoreys.where(
              (s) =>
                  widget.project.storeys.any((original) => original.id == s.id),
            ))
              DropdownMenuItem(
                value: storey.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        storey.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      storey.elevationLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: _changeSource,
        ),
        if (_sourceStorey case final source?) ...[
          const SizedBox(height: 10),
          Text(
            '${l.architectStoreyHeightLabel}: ${source.height.toStringAsFixed(2)} m',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasSelection) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const ValueKey('architect-copy-scope-all'),
                label: Text(l.architectCopyScopeAll),
                selected: !_copyOnlySelection,
                onSelected: (_) => setState(() => _copyOnlySelection = false),
              ),
              ChoiceChip(
                key: const ValueKey('architect-copy-scope-selection'),
                label: Text(
                  l.architectCopyScopeSelection(
                    widget.selectedElementIds!.length,
                  ),
                ),
                selected: _copyOnlySelection,
                onSelected: (_) => setState(() => _copyOnlySelection = true),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _quickAction(String key, String label, VoidCallback action) =>
      TextButton(key: ValueKey(key), onPressed: action, child: Text(label));

  Widget _categoriesSection(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context, 2, l.architectCopyWhat),
        Wrap(
          spacing: 4,
          children: [
            _quickAction(
              'architect-copy-categories-all',
              l.architectCopyAll,
              () => setState(
                () => _selectedCategories.addAll(
                  ArchitectStoreyElementType.defaultTypicalCategories,
                ),
              ),
            ),
            _quickAction(
              'architect-copy-categories-none',
              l.architectCopyNone,
              () => setState(_selectedCategories.clear),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _outlinedGroup(context, [
          for (final types in _categoryGroups) _categoryRow(context, types),
        ]),
      ],
    );
  }

  Widget _categoryRow(
    BuildContext context,
    List<ArchitectStoreyElementType> types,
  ) {
    final count = _count(_sourceStorey, types, filter: _selectionFilter);
    final selected = types.every(_selectedCategories.contains);
    return CheckboxListTile(
      key: ValueKey('architect-copy-category-${types.first.name}'),
      value: selected,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      title: Text(
        types.first.localizedLabel(context.l10n),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      secondary: _countBadge(context, count),
      onChanged: (checked) => setState(() {
        checked == true
            ? _selectedCategories.addAll(types)
            : _selectedCategories.removeAll(types);
      }),
    );
  }

  Widget _countBadge(BuildContext context, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _outlinedGroup(BuildContext context, List<Widget> rows) =>
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      );

  Widget _targetsSection(BuildContext context) {
    final l = context.l10n;
    final targets = _normalStoreys
        .where((s) => s.id != _sourceStoreyId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context, 3, l.architectCopyTo),
        if (targets.isNotEmpty) ...[
          Wrap(
            spacing: 4,
            children: [
              _quickAction(
                'architect-copy-targets-above',
                l.architectCopyAbove,
                () => setState(() => _targetStoreyIds = _targetsAbove()),
              ),
              _quickAction(
                'architect-copy-targets-all',
                l.architectCopyAll,
                () => setState(() => _targetStoreyIds = _allTargets()),
              ),
              _quickAction(
                'architect-copy-targets-none',
                l.architectCopyNone,
                () => setState(_targetStoreyIds.clear),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _outlinedGroup(context, [
            for (final storey in targets)
              CheckboxListTile(
                key: ValueKey('architect-copy-target-${storey.id}'),
                value: _targetStoreyIds.contains(storey.id),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                selected: _targetStoreyIds.contains(storey.id),
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .04),
                title: Text(
                  storey.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l.architectStoreyElementsCount(
                    _count(
                      storey,
                      ArchitectStoreyElementType.defaultTypicalCategories,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                secondary: Text(
                  storey.elevationLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: (checked) => setState(() {
                  checked == true
                      ? _targetStoreyIds.add(storey.id)
                      : _targetStoreyIds.remove(storey.id);
                }),
              ),
          ]),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              l.architectCopyTargetsEmpty,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('architect-copy-new-storeys'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Tooltip(
              message: l.architectCopyNewStoreysHelp,
              child: Text(l.architectCopyNewStoreys),
            ),
            onPressed: _addStoreys,
          ),
        ),
      ],
    );
  }

  Widget _settingsSection(BuildContext context) {
    final l = context.l10n;
    return _outlinedGroup(context, [
      ExpansionTile(
        key: const ValueKey('architect-copy-settings'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          l.architectCopySettings,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          _mode == StoreyCopyMode.replace
              ? l.architectCopyReplace
              : l.architectCopyMerge,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final mode in StoreyCopyMode.values)
                      Tooltip(
                        message: mode == StoreyCopyMode.replace
                            ? l.architectCopyModeReplaceHelp
                            : l.architectCopyModeMergeHelp,
                        child: ChoiceChip(
                          key: ValueKey('architect-copy-mode-${mode.name}'),
                          label: Text(
                            mode == StoreyCopyMode.replace
                                ? l.architectCopyReplace
                                : l.architectCopyMerge,
                          ),
                          selected: _mode == mode,
                          onSelected: (_) => setState(() => _mode = mode),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == StoreyCopyMode.replace
                      ? l.architectCopyModeReplaceHelp
                      : l.architectCopyModeMergeHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _setting(
            context,
            'architect-copy-adjust-walls',
            l.architectCopyWallHeights,
            l.architectAdjustWallHeightsToStorey,
            _adjustWallHeights,
            (value) => setState(() => _adjustWallHeights = value),
          ),
          _setting(
            context,
            'architect-copy-adjust-levels',
            l.architectCopyLevelMarkers,
            l.architectAdjustElevationMarkers,
            _adjustLevelMarkers,
            (value) => setState(() => _adjustLevelMarkers = value),
          ),
          _setting(
            context,
            'architect-copy-adjust-groups',
            l.architectCopyGroups,
            l.architectPreserveGroups,
            _preserveGroups,
            (value) => setState(() => _preserveGroups = value),
          ),
        ],
      ),
    ]);
  }

  Widget _setting(
    BuildContext context,
    String key,
    String label,
    String help,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Tooltip(
    message: help,
    child: SwitchListTile(
      key: ValueKey(key),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );

  Widget _footer(BuildContext context, {required bool wide}) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final elements = _elementCount;
    final canCopy = elements > 0 && _targetStoreyIds.isNotEmpty;
    final replaced = _replacementCount;
    final originalIds = widget.project.storeys.map((s) => s.id).toSet();
    final newCount = _workingProject.storeys
        .where((s) => !originalIds.contains(s.id))
        .length;
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.architectCopySummary(elements, _targetStoreyIds.length),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (newCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            l.architectCopyNewStoreysSummary(newCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (canCopy && _mode == StoreyCopyMode.replace && replaced > 0) ...[
          const SizedBox(height: 4),
          Text(
            l.architectCopyReplaceImpact(replaced),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final submit = ElevatedButton.icon(
      key: const ValueKey('architect-copy-submit'),
      onPressed: canCopy ? _submit : null,
      icon: const AppIcon(AppIconId.duplicate, size: 18),
      label: Text(l.architectCopyAction),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        minimumSize: const Size(132, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 20, vertical: 16),
      child: wide
          ? Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                const SizedBox(width: 8),
                submit,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [summary, const SizedBox(height: 12), submit],
            ),
    );
  }
}
