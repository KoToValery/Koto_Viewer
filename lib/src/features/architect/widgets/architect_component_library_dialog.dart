import 'architect_dialog.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../components/dsl/parametric_script_parser.dart';
import '../models/architect_component.dart';
import '../rendering/architect_component_opening_painter.dart';
import '../models/architect_component_definition.dart';
import '../models/architect_fenestration_style.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';
import '../services/fenestration_library_service.dart';
import 'architect_component_labels.dart';
import 'component_dimensions_dialog.dart';
import 'component_studio_dialog.dart';
import 'component_preview_painters.dart';
import 'fenestration_preview.dart';
import '../screens/fenestration_editor_screen.dart';

/// One tap selects an object at its catalog size. Editing is a separate action.
class ArchitectComponentLibraryDialog extends StatefulWidget {
  final ValueChanged<ArchitectComponentDefinition>? onSelectComponent;
  final ValueChanged<ArchitectFenestrationStyle>? onSelectFenestration;
  final VoidCallback? onSelectDownpipe;
  final VoidCallback? onSelectFloorDrain;
  final ArchitectComponentCategory? initialCategory;
  final bool replaceSelection;
  final String? selectedDefinitionId;
  const ArchitectComponentLibraryDialog({
    super.key,
    this.onSelectComponent,
    this.onSelectFenestration,
    this.onSelectDownpipe,
    this.onSelectFloorDrain,
    this.initialCategory,
    this.replaceSelection = false,
    this.selectedDefinitionId,
  });

  static Future<void> show(
    BuildContext context, {
    ValueChanged<ArchitectComponentDefinition>? onSelectComponent,
    ValueChanged<ArchitectFenestrationStyle>? onSelectFenestration,
    VoidCallback? onSelectDownpipe,
    VoidCallback? onSelectFloorDrain,
    ArchitectComponentCategory? initialCategory,
    bool replaceSelection = false,
    String? selectedDefinitionId,
  }) => showDialog(
    context: context,
    builder: (_) => ArchitectComponentLibraryDialog(
      onSelectComponent: onSelectComponent,
      onSelectFenestration: onSelectFenestration,
      onSelectDownpipe: onSelectDownpipe,
      onSelectFloorDrain: onSelectFloorDrain,
      initialCategory: initialCategory,
      replaceSelection: replaceSelection,
      selectedDefinitionId: selectedDefinitionId,
    ),
  );

  @override
  State<ArchitectComponentLibraryDialog> createState() =>
      _ArchitectComponentLibraryDialogState();
}

enum _Source { all, builtIn, custom }

class _ArchitectComponentLibraryDialogState
    extends State<ArchitectComponentLibraryDialog> {
  ArchitectComponentCategory? _category;
  _Source _source = _Source.all;
  String _search = '';
  ColorScheme get colors => Theme.of(context).colorScheme;
  FenestrationPreviewMode _previewMode = FenestrationPreviewMode.plan;
  bool get _show3d => _previewMode == FenestrationPreviewMode.threeD;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    ComponentLibraryService.instance.addListener(_refresh);
    FenestrationLibraryService.instance.addListener(_refresh);
    ComponentLibraryService.instance.init();
    FenestrationLibraryService.instance.init();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ComponentLibraryService.instance.removeListener(_refresh);
    FenestrationLibraryService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw const FormatException();
      final source = utf8.decode(bytes);
      ParametricScriptParser.parse(source);
      if (!mounted) return;
      await ComponentStudioDialog.show(context, initialScriptJson: source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.architectLibraryImportError)),
        );
      }
    }
  }

  bool _matches(String name) =>
      name.toLowerCase().contains(_search.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phone = MediaQuery.sizeOf(context).width < 600;
    final library = ComponentLibraryService.instance;
    final definitions = library
        .getAllDefinitions()
        .where(
          (d) =>
              (_category == null || d.category == _category) &&
              (_source == _Source.all ||
                  (d is ScriptedComponentDefinition) ==
                      (_source == _Source.custom)) &&
              _matches(componentLabel(l, d)),
        )
        .toList();
    final presetIds = ArchitectFenestrationStyle.standardCatalog()
        .map((s) => s.id)
        .toSet();
    final styles = FenestrationLibraryService.instance
        .getAllStyles()
        .where(
          (s) =>
              !widget.replaceSelection &&
              (_category == null ||
                  (_category == ArchitectComponentCategory.doors &&
                      s.kind == FenestrationKind.door) ||
                  (_category == ArchitectComponentCategory.windows &&
                      s.kind == FenestrationKind.window)) &&
              (_source == _Source.all ||
                  presetIds.contains(s.id) == (_source == _Source.builtIn)) &&
              _matches(s.localizedName(l)),
        )
        .toList();
    return Dialog(
      insetPadding: EdgeInsets.all(phone ? 8 : 24),
      backgroundColor: colors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.replaceSelection
                          ? l.architectComponentReplace
                          : l.architectLibrary,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.architectLibraryImportHelp,
                    icon: AppIcon(
                      AppIconId.upload,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: _import,
                  ),
                  IconButton(
                    tooltip: l.architectComponentStudioTitle,
                    icon: AppIcon(
                      AppIconId.code,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => ComponentStudioDialog.show(context),
                  ),
                  IconButton(
                    tooltip: l.close,
                    icon: AppIcon(
                      AppIconId.close,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                style: TextStyle(color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: l.search,
                  hintStyle: TextStyle(color: colors.onSurfaceVariant),
                  prefixIcon: AppIcon(
                    AppIconId.search,
                    color: colors.onSurfaceVariant,
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SegmentedButton<FenestrationPreviewMode>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: FenestrationPreviewMode.elevation,
                    label: Text(l.architectFenestrationElevationShort),
                  ),
                  ButtonSegment(
                    value: FenestrationPreviewMode.plan,
                    label: Text(l.architectFenestrationPlanShort),
                  ),
                  ButtonSegment(
                    value: FenestrationPreviewMode.threeD,
                    label: Text(
                      l.architectFenestration3DShort,
                      key: const ValueKey('component-library-preview-mode'),
                    ),
                  ),
                ],
                selected: {_previewMode},
                onSelectionChanged: (v) =>
                    setState(() => _previewMode = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ArchitectComponentCategory>(
                        key: const ValueKey('component-library-category'),
                        isExpanded: true,
                        dropdownColor: colors.surfaceContainerHigh,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                          fontSize: 13,
                        ),
                        value: _category,
                        hint: Text(
                          l.architectLibraryAll,
                          style: TextStyle(color: colors.onSurface),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l.architectLibraryAll),
                          ),
                          for (final c in ArchitectComponentCategory.values)
                            if (!widget.replaceSelection ||
                                (c != ArchitectComponentCategory.doors &&
                                    c != ArchitectComponentCategory.windows))
                              DropdownMenuItem(
                                value: c,
                                child: Text(componentCategoryLabel(l, c)),
                              ),
                        ],
                        onChanged: (value) => setState(() => _category = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_Source>(
                        key: const ValueKey('component-library-source'),
                        isExpanded: true,
                        dropdownColor: colors.surfaceContainerHigh,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                          fontSize: 13,
                        ),
                        value: _source,
                        items: [
                          DropdownMenuItem(
                            value: _Source.all,
                            child: Text(l.architectLibrarySourceAll),
                          ),
                          DropdownMenuItem(
                            value: _Source.builtIn,
                            child: Text(l.architectLibraryBuiltIn),
                          ),
                          DropdownMenuItem(
                            value: _Source.custom,
                            child: Text(l.architectLibraryCustom),
                          ),
                        ],
                        onChanged: (value) => setState(() => _source = value!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            if (widget.onSelectFloorDrain != null &&
                (_category == null ||
                    _category == ArchitectComponentCategory.sanitary) &&
                _source != _Source.custom &&
                _matches(l.architectToolFloorDrain))
              ListTile(
                leading: AppIcon(AppIconId.water, color: Color(0xFF00E5FF)),
                title: Text(
                  l.architectToolFloorDrain,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  l.architectFloorDrainLibraryDesc,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing: AppIcon(
                  AppIconId.chevronRight,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSelectFloorDrain!();
                },
              ),
            if (widget.onSelectDownpipe != null &&
                _category == null &&
                _source != _Source.custom &&
                _matches(l.architectDrainageSmart))
              ListTile(
                leading: AppIcon(
                  AppIconId.water,
                  color: colors.onSurfaceVariant,
                ),
                title: Text(
                  l.architectDrainageSmart,
                  style: TextStyle(color: colors.onSurface),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSelectDownpipe!();
                },
              ),
            Expanded(
              child: definitions.isEmpty && styles.isEmpty
                  ? Center(
                      child: Text(
                        l.architectComponentNoItems,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: phone ? 190 : 220,
                        mainAxisExtent:
                            188 +
                            40 *
                                (MediaQuery.textScalerOf(
                                      context,
                                    ).scale(1).clamp(1, 2) -
                                    1),
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: definitions.length + styles.length,
                      itemBuilder: (context, index) {
                        if (index >= definitions.length) {
                          final style = styles[index - definitions.length];
                          final isCustomStyle = !presetIds.contains(style.id);
                          return _card(
                            style.localizedName(l),
                            '${ArchitectFenestrationStyle.centimeters(style.defaultWidth)}×${ArchitectFenestrationStyle.centimeters(style.defaultHeight)} cm',
                            FenestrationPreview(
                              style: style,
                              mode: _previewMode,
                            ),
                            () {
                              widget.onSelectFenestration?.call(style);
                              Navigator.of(context).pop();
                            },
                            onEdit: () =>
                                Navigator.push<ArchitectFenestrationStyle>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FenestrationEditorScreen(
                                      initialStyle: style,
                                    ),
                                  ),
                                ),
                            editTooltip: l.architectFenestrationEdit,
                            editIcon: Icons.edit_outlined,
                            onDelete: isCustomStyle
                                ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => architectAlertDialog(
                                        title: Text(
                                          l.architectFenestrationDelete,
                                        ),
                                        content: Text(
                                          l.architectFenestrationDeleteConfirm(
                                            style.localizedName(l),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(l.cancel),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(l.delete),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FenestrationLibraryService.instance
                                          .deleteStyle(style.id);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l.architectFenestrationDeleteSuccess,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        }
                        final d = definitions[index];
                        final geometry = ComponentGeometryCache.instance
                            .getOrCompute(d, d.defaultParameters);
                        final sizes =
                            [
                                  'width',
                                  'depth',
                                  if (d.id != 'service_chimney') 'height',
                                ]
                                .map(
                                  (key) => componentDimensionCm(
                                    d.defaultParameters[key] as num,
                                  ),
                                )
                                .join('×');
                        return _card(
                          componentLabel(l, d),
                          '$sizes cm',
                          CustomPaint(
                            painter:
                                _previewMode != FenestrationPreviewMode.plan
                                ? ComponentMeshPreviewPainter(
                                    geometry.mesh3d,
                                    _show3d ? .55 : 0,
                                    _show3d
                                        ? .65 +
                                              (d.id == 'service_fireplace'
                                                  ? math.pi
                                                  : 0)
                                        : math.pi,
                                  )
                                : _ComponentThumbnailPainter(geometry.block2d),
                          ),
                          () {
                            if (!widget.replaceSelection) {
                              library.setActiveDefinition(d);
                            }
                            widget.onSelectComponent?.call(d);
                            Navigator.of(context).pop();
                          },
                          itemKey: ValueKey('component-library-item-${d.id}'),
                          selected: d.id == widget.selectedDefinitionId,
                          onEdit: d is ScriptedComponentDefinition
                              ? () => ComponentStudioDialog.show(
                                  context,
                                  initialScriptJson: d.rawSourceJson,
                                )
                              : !widget.replaceSelection
                              ? () async {
                                  final values =
                                      await ComponentDimensionsDialog.show(
                                        context,
                                        d,
                                        d.defaultParameters,
                                      );
                                  if (values == null || !context.mounted) {
                                    return;
                                  }
                                  library.setActiveDefinition(
                                    d,
                                    parameters: values,
                                  );
                                  widget.onSelectComponent?.call(d);
                                  Navigator.of(context).pop();
                                }
                              : null,
                          editTooltip: l.architectProperties,
                          editIcon: Icons.tune,
                          help: serviceComponentHelp(l, d.id),
                          onDelete: d is ScriptedComponentDefinition
                              ? () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => architectAlertDialog(
                                      title: Text(l.architectComponentDelete),
                                      content: Text(
                                        l.architectComponentDeleteConfirm(
                                          componentLabel(l, d),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(l.cancel),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(l.delete),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await library.deleteCustomScript(d.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l.architectComponentDeleted,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    String name,
    String dimensions,
    Widget preview,
    VoidCallback select, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    String? editTooltip,
    IconData? editIcon,
    String? help,
    Key? itemKey,
    bool selected = false,
  }) => Card(
    color: selected ? colors.secondaryContainer : colors.surfaceContainerHigh,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: itemKey,
      onTap: select,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.white, child: preview),
                  if (onEdit != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF263238),
                          backgroundColor: Colors.white,
                        ),
                        tooltip:
                            editTooltip ??
                            context.l10n.architectComponentStudioTitle,
                        icon: editIcon == null
                            ? AppIcon(AppIconId.code, size: 18)
                            : Icon(editIcon, size: 18),
                        onPressed: onEdit,
                      ),
                    ),
                  if (onDelete != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                        tooltip: context.l10n.delete,
                        icon: AppIcon(
                          AppIconId.delete,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        onPressed: onDelete,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Tooltip(
              message: help ?? name,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              dimensions,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ComponentThumbnailPainter extends CustomPainter {
  final ArchitectComponentBlock2D block;

  const _ComponentThumbnailPainter(this.block);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final b = block.bounds;
    final bw = b.width > 1e-4 ? b.width : 0.60;
    final bd = b.height > 1e-4 ? b.height : 0.60;

    final scaleX = (size.width * 0.75) / bw;
    final scaleY = (size.height * 0.75) / bd;
    final scale = math.min(scaleX, scaleY);

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.scale(scale, scale);
    canvas.translate(-b.center.dx, -b.center.dy);

    // Draw whiteout background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(block.boundsMask, bgPaint);

    // Draw outline
    final strokePaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.2 / scale
      ..style = PaintingStyle.stroke;
    canvas.drawPath(block.outline, strokePaint);

    // Draw details
    final detailPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 0.8 / scale
      ..style = PaintingStyle.stroke;
    for (final p in block.detailPaths) {
      canvas.drawPath(p, detailPaint);
    }
    ArchitectComponentOpeningPainter.draw(canvas, block, detailPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ComponentThumbnailPainter oldDelegate) =>
      oldDelegate.block != block;
}
