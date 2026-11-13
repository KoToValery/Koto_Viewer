import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_command_controller.dart';
import 'architect_copy_storey_dialog.dart';
import 'architect_dialog.dart';
import 'architect_storey_plan_preview.dart';

/// Storey management shares the workspace controller, history and autosave.
/// Copying uses the same configuration dialog as the drawing workspace.
class ArchitectStoreysScreen extends StatefulWidget {
  final ArchitectCommandController controller;
  final String? initialSelectedStoreyId;

  const ArchitectStoreysScreen({
    super.key,
    required this.controller,
    this.initialSelectedStoreyId,
  });

  @override
  State<ArchitectStoreysScreen> createState() => _ArchitectStoreysScreenState();
}

class _ArchitectStoreysScreenState extends State<ArchitectStoreysScreen> {
  ArchitectProject get project => widget.controller.project;
  late String? _selectedId;

  List<ArchitectStorey> get _storeys =>
      [...project.storeys]..sort((a, b) => b.elevation.compareTo(a.elevation));

  List<ArchitectStorey> get _normalStoreys =>
      _storeys.where((s) => !s.isRoof).toList();

  ArchitectStorey? get _selected =>
      project.storeys.where((s) => s.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedStoreyId ?? project.activeStoreyId;
    _resolveSelection();
    widget.controller.addListener(_changed);
  }

  void _resolveSelection() {
    if (_selected != null) return;
    _selectedId =
        project.storeys
            .where((s) => s.id == project.activeStoreyId)
            .firstOrNull
            ?.id ??
        _normalStoreys.firstOrNull?.id;
  }

  void _changed() {
    if (mounted) setState(_resolveSelection);
  }

  @override
  void didUpdateWidget(covariant ArchitectStoreysScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _resolveSelection();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  int _elementCount(ArchitectStorey s) =>
      ArchitectStoreyElementType.values.fold<int>(
        0,
        (sum, type) => sum + type.countInStorey(s),
      ) +
      s.pathways.length +
      s.streets.length +
      s.siteFences.length +
      s.vegetation.length;

  void _returnToDrawing() => Navigator.of(context).pop(_selected?.id);

  Future<void> _editStorey([ArchitectStorey? storey]) async {
    final l = context.l10n;
    final form = GlobalKey<FormState>();
    var name =
        storey?.name ?? l.architectCopyStoreyName(_normalStoreys.length + 1);
    var height = storey?.height ?? _selected?.height ?? 2.8;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => architectAlertDialog(
        title: Text(
          storey == null ? l.architectStoreyAdd : l.architectStoreyEdit,
        ),
        content: SizedBox(
          width: 360,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('architect-storeys-name'),
                  initialValue: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.architectPropertyName,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l.architectStoreyNameRequired
                      : null,
                  onSaved: (value) => name = value!.trim(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('architect-storeys-height'),
                  initialValue: height.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.architectStoreyHeightLabel,
                    suffixText: 'm',
                  ),
                  validator: (value) => _positiveHeight(value) == null
                      ? l.architectStoreyHeightInvalid
                      : null,
                  onSaved: (value) => height = _positiveHeight(value)!,
                ),
                if (storey != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l.architectStoreyLevelsHelp,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('architect-storeys-save'),
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(ctx, true);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (storey == null) {
      final before = project.storeys.map((s) => s.id).toSet();
      final next = project.addStoreyAbove(name: name, height: height);
      _selectedId = next.storeys.firstWhere((s) => !before.contains(s.id)).id;
      widget.controller.commit(next);
    } else {
      final current = project.storeys
          .where((s) => s.id == storey.id)
          .firstOrNull;
      if (current == null) return;
      widget.controller.execute(
        UpdateArchitectStoreyProperties(
          current.copyWith(name: name, height: height),
          recalculateAbove: height != current.height,
        ),
      );
    }
  }

  double? _positiveHeight(String? text) {
    final value = double.tryParse(text?.trim().replaceAll(',', '.') ?? '');
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  Future<void> _addSeveral() async {
    final l = context.l10n;
    final form = GlobalKey<FormState>();
    var count = 3;
    var height = _selected?.height ?? 2.8;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => architectAlertDialog(
        title: Text(l.architectStoreyAddSeveral),
        content: SizedBox(
          width: 360,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('architect-storeys-batch-count'),
                  initialValue: '$count',
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
                  key: const ValueKey('architect-storeys-batch-height'),
                  initialValue: height.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l.architectStoreyHeightLabel,
                    suffixText: 'm',
                  ),
                  validator: (value) => _positiveHeight(value) == null
                      ? l.architectStoreyHeightInvalid
                      : null,
                  onSaved: (value) => height = _positiveHeight(value)!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('architect-storeys-batch-submit'),
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(ctx, true);
            },
            child: Text(l.architectBatchAddButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final before = project.storeys.map((s) => s.id).toSet();
    var next = project;
    for (var i = 0; i < count; i++) {
      final number = next.storeys.where((s) => !s.isRoof).length + 1;
      next = next.addStoreyAbove(
        name: l.architectCopyStoreyName(number),
        height: height,
      );
    }
    _selectedId = next.storeys.firstWhere((s) => !before.contains(s.id)).id;
    widget.controller.commit(next);
  }

  Future<void> _copyElements() async {
    final source = _selected;
    if (source == null || source.isRoof) return;
    final options = await ArchitectCopyStoreyDialog.show(
      context,
      project: project,
      initialSourceStoreyId: source.id,
    );
    if (options == null || !mounted) return;
    final (_, result) = ArchitectStoreyCopyService.copyElements(
      project,
      options,
    );
    widget.controller.execute(CopyArchitectElementsAcrossStoreys(options));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.architectCopySuccess(
            result.totalCopied,
            result.targetStoreyCount,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStorey(ArchitectStorey storey) async {
    if (storey.isRoof || _normalStoreys.length <= 1) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => architectAlertDialog(
        title: Text(l.deleteStorey),
        content: Text(l.architectDeleteStoreyConfirm(storey.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('architect-storeys-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        project.storeys.any((s) => s.id == storey.id) &&
        _normalStoreys.length > 1) {
      widget.controller.execute(DeleteArchitectStorey(storey.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final scheme = base.colorScheme.copyWith(
      surface: dark ? const Color(0xff20242b) : Colors.white,
      onSurface: dark ? const Color(0xffe6e8eb) : const Color(0xff20252d),
      onSurfaceVariant: dark
          ? const Color(0xffb3bac5)
          : const Color(0xff586270),
      outlineVariant: dark ? const Color(0xff3c444f) : const Color(0xffe1e5eb),
      surfaceContainerLow: dark
          ? const Color(0xff191d23)
          : const Color(0xfff7f8fa),
      surfaceTint: Colors.transparent,
    );
    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      child: Builder(
        builder: (context) {
          final l = context.l10n;
          return Scaffold(
            backgroundColor: scheme.surfaceContainerLow,
            appBar: AppBar(
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
              surfaceTintColor: Colors.transparent,
              title: Text(l.architectStoreyManagerTitle),
              leading: IconButton(
                key: const ValueKey('architect-storeys-back'),
                tooltip: l.architectStoreyReturnDrawing,
                onPressed: _returnToDrawing,
                icon: const AppIcon(AppIconId.back),
              ),
              actions: [
                IconButton(
                  key: const ValueKey('architect-storeys-undo'),
                  tooltip: l.architectZoneUndoAction,
                  onPressed: widget.controller.canUndo
                      ? widget.controller.undo
                      : null,
                  icon: const AppIcon(AppIconId.undo),
                ),
                IconButton(
                  key: const ValueKey('architect-storeys-redo'),
                  tooltip: l.architectZoneRedoAction,
                  onPressed: widget.controller.canRedo
                      ? widget.controller.redo
                      : null,
                  icon: const AppIcon(AppIconId.redo),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide =
                          constraints.maxWidth >= 820 &&
                          MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                      return wide ? _wideBody(context) : _compactBody(context);
                    },
                  ),
                ),
              ),
            ),
            bottomNavigationBar: _footer(context),
          );
        },
      ),
    );
  }

  Widget _overview(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            project.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.architectStoreyCountChip(_normalStoreys.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('architect-storeys-add'),
                icon: const AppIcon(AppIconId.add, size: 18),
                label: Text(l.architectStoreyAdd),
                onPressed: () => _editStorey(),
              ),
              OutlinedButton.icon(
                key: const ValueKey('architect-storeys-batch'),
                icon: const AppIcon(AppIconId.layers, size: 18),
                label: Text(l.architectStoreyAddSeveral),
                onPressed: _addSeveral,
              ),
              OutlinedButton.icon(
                key: const ValueKey('architect-storeys-copy'),
                icon: const AppIcon(AppIconId.duplicate, size: 18),
                label: Text(l.architectCopyStoreyTab),
                onPressed: _selected == null || _selected!.isRoof
                    ? null
                    : _copyElements,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wideBody(BuildContext context) => Column(
    children: [
      _overview(context),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 350,
                child: ListView.separated(
                  primary: false,
                  itemCount: _storeys.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _storeyCard(context, _storeys[index]),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SingleChildScrollView(
                  primary: false,
                  child: _selected == null
                      ? const SizedBox.shrink()
                      : _details(context, _selected!, compact: false),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _compactBody(BuildContext context) => ListView(
    key: const ValueKey('architect-storeys-scroll'),
    padding: const EdgeInsets.only(bottom: 16),
    children: [
      _overview(context),
      for (final storey in _storeys)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: _storeyCard(context, storey, expand: storey.id == _selectedId),
        ),
    ],
  );

  Widget _storeyCard(
    BuildContext context,
    ArchitectStorey storey, {
    bool expand = false,
  }) {
    final theme = Theme.of(context);
    final selected = storey.id == _selectedId;
    return Material(
      key: ValueKey('architect-storeys-card-${storey.id}'),
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: .04)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('architect-storeys-select-${storey.id}'),
            onTap: () => setState(() => _selectedId = storey.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppIcon(
                      storey.isRoof
                          ? AppIconId.roof
                          : selected
                          ? AppIconId.checkCircle
                          : AppIconId.layers,
                      size: 22,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storey.isRoof
                              ? context.l10n.architectRoofPlan
                              : storey.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          storey.elevationLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.architectStoreyElementsCount(
                            _elementCount(storey),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!storey.isRoof)
                    IconButton(
                      key: ValueKey('architect-storeys-edit-${storey.id}'),
                      tooltip: context.l10n.architectStoreyEdit,
                      onPressed: () => _editStorey(storey),
                      icon: const AppIcon(AppIconId.edit, size: 18),
                    ),
                ],
              ),
            ),
          ),
          if (expand) _details(context, storey, compact: true),
        ],
      ),
    );
  }

  Widget _details(
    BuildContext context,
    ArchitectStorey storey, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final content = Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Text(
              storey.isRoof ? l.architectRoofPlan : storey.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (storey.isRoof)
            Text(
              l.architectStoreyRoofAuto,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _metric(
                  context,
                  l.architectStoreyHeightLabel,
                  '${storey.height.toStringAsFixed(2)} m',
                ),
                if (!compact)
                  _metric(
                    context,
                    l.architectStoreyElevationLabel,
                    storey.elevationLabel,
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text(l.architectPlanPreviewTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          ArchitectStoreyPlanPreview(
            project: project,
            storey: storey,
            height: compact ? 170 : 340,
          ),
          if (!storey.isRoof) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('architect-storeys-detail-edit-${storey.id}'),
                  icon: const AppIcon(AppIconId.edit, size: 18),
                  label: Text(l.architectStoreyEdit),
                  onPressed: () => _editStorey(storey),
                ),
                if (_normalStoreys.length > 1)
                  TextButton.icon(
                    key: ValueKey('architect-storeys-delete-${storey.id}'),
                    icon: const AppIcon(AppIconId.delete, size: 18),
                    label: Text(l.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _deleteStorey(storey),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    if (compact) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: content,
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _footer(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Row(
              children: [
                if (MediaQuery.sizeOf(context).width >= 700 &&
                    _selected != null) ...[
                  Expanded(
                    child: Text(
                      _selected!.isRoof
                          ? context.l10n.architectRoofPlan
                          : _selected!.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
                Expanded(
                  flex: MediaQuery.sizeOf(context).width >= 700 ? 0 : 1,
                  child: FilledButton.icon(
                    key: const ValueKey('architect-storeys-return'),
                    onPressed: _returnToDrawing,
                    icon: const AppIcon(AppIconId.back, size: 18),
                    label: Text(context.l10n.architectStoreyReturnDrawing),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
