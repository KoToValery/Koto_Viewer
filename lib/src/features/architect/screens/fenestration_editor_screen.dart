import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../widgets/fenestration_preview.dart';
import '../widgets/fenestration_properties_panel.dart';

class FenestrationEditorScreen extends StatefulWidget {
  final ArchitectFenestrationStyle? initialStyle;
  final FenestrationKind initialKind;
  final bool createNew;
  const FenestrationEditorScreen({
    super.key,
    this.initialStyle,
    this.initialKind = FenestrationKind.window,
    this.createNew = false,
  });
  @override
  State<FenestrationEditorScreen> createState() => _FenestrationEditorState();
}

class _FenestrationEditorState extends State<FenestrationEditorScreen> {
  late ArchitectFenestrationStyle _style;
  late final String _original;
  final _undo = <ArchitectFenestrationStyle>[];
  final _redo = <ArchitectFenestrationStyle>[];
  final _form = GlobalKey<FormState>();
  final _transform = TransformationController();
  final _camera = Cad3DCamera(yaw: -.6, pitch: .25, zoom: 1.5);
  FenestrationPreviewMode _mode = FenestrationPreviewMode.elevation;
  String? _paneId;
  bool _saving = false, _canPop = false;
  double _panelFraction = .45;
  double _startZoom = 1.5;
  final _nameControllers = <TextEditingController>[];
  String _json(ArchitectFenestrationStyle style) => jsonEncode(style.toJson());
  bool get _dirty => _json(_style) != _original;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialStyle ??
        ArchitectFenestrationStyle.standardCatalog().firstWhere(
          (s) => s.kind == widget.initialKind,
        );
    _style = initial.isPreset || widget.createNew
        ? initial.copyWith(
            id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
            name: '',
          )
        : initial;
    _original = _json(_style);
    _paneId = _style.panes.firstOrNull?.id;
  }

  @override
  void dispose() {
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    _transform.dispose();
    super.dispose();
  }

  void _change(ArchitectFenestrationStyle next) {
    if (_json(next) == _json(_style)) return;
    if (next.panes.length != _style.panes.length && !next.hasValidGeometry) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.architectFenestrationInvalidSize)),
      );
      return;
    }
    setState(() {
      _undo.add(_style);
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
      _style = next;
      _syncPane();
    });
  }

  void _syncPane() {
    if (!_style.panes.any((p) => p.id == _paneId)) {
      _paneId = _style.panes.firstOrNull?.id;
    }
  }

  void _history(bool redo) {
    FocusManager.instance.primaryFocus?.unfocus();
    final source = redo ? _redo : _undo, target = redo ? _undo : _redo;
    if (source.isEmpty) return;
    setState(() {
      target.add(_style);
      _style = source.removeLast();
      _syncPane();
    });
  }

  Future<bool> _editName() async {
    final controller = TextEditingController(text: _style.name);
    _nameControllers.add(controller);
    final key = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.architectFenestrationName),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            key: const ValueKey('fenestration-name'),
            decoration: InputDecoration(
              labelText: ctx.l10n.architectFenestrationName,
            ),
            validator: (s) =>
                (s ?? '').trim().isEmpty ? ctx.l10n.propertiesInvalid : null,
            onFieldSubmitted: (s) {
              if (key.currentState!.validate()) Navigator.pop(ctx, s.trim());
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(ctx.l10n.ok),
          ),
        ],
      ),
    );

    if (name == null || !mounted) return false;
    _change(_style.copyWith(name: name));
    return true;
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? true)) return;
    _form.currentState?.save();
    if (!_style.hasValidGeometry) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.architectFenestrationInvalidSize)),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_style.name.trim().isEmpty && !await _editName()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await FenestrationLibraryService.instance.saveStyle(_style);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, saved);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.architectFenestrationSaveError)),
        );
      }
    }
  }

  Future<void> _leave() async {
    final invalidInput = !(_form.currentState?.validate() ?? true);
    _form.currentState?.save();
    FocusManager.instance.primaryFocus?.unfocus();
    final discard =
        (!_dirty && !invalidInput) ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(ctx.l10n.architectFenestrationDiscardTitle),
                content: Text(ctx.l10n.architectFenestrationDiscardMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(ctx.l10n.architectFenestrationKeepEditing),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(ctx.l10n.architectFenestrationDiscard),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _templates() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showDialog<ArchitectFenestrationStyle>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ctx.l10n.architectFenestrationTemplates,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: ctx.l10n.close,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.extent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: .85,
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final preset
                        in ArchitectFenestrationStyle.standardCatalog().where(
                          (s) => s.kind == _style.kind,
                        ))
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, preset),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: SizedBox.expand(
                                    child: FenestrationPreview(style: preset),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  preset.localizedName(ctx.l10n),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      _change(selected.copyWith(id: _style.id, name: _style.name));
      _transform.value = Matrix4.identity();
    }
  }

  Widget _viewport() => LayoutBuilder(
    builder: (context, constraints) {
      final preview = SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: FenestrationPreview(
          style: _style,
          mode: _mode,
          dimensions: true,
          selectedPaneId: _paneId,
          camera: _camera,
        ),
      );
      if (_mode == FenestrationPreviewMode.threeD) {
        return GestureDetector(
          onScaleStart: (_) => _startZoom = _camera.zoom,
          onScaleUpdate: (d) => setState(() {
            _camera.yaw += d.focalPointDelta.dx * .01;
            _camera.pitch = (_camera.pitch + d.focalPointDelta.dy * .01).clamp(
              -math.pi / 2 + .05,
              math.pi / 2 - .05,
            );
            _camera.zoom = (_startZoom * d.scale).clamp(.5, 5);
          }),
          child: preview,
        );
      }
      return ClipRect(
        child: InteractiveViewer(
          transformationController: _transform,
          boundaryMargin: const EdgeInsets.all(100),
          minScale: .5,
          maxScale: 5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _mode != FenestrationPreviewMode.elevation
                ? null
                : (d) {
                    final hit = _style.hitTestFromCanvas(
                      d.localPosition,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );
                    if (hit != null) {
                      setState(() => _paneId = hit.$1.id);
                      HapticFeedback.selectionClick();
                    }
                  },
            child: preview,
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = _style.name.isEmpty
        ? (_style.kind == FenestrationKind.door
              ? l.architectFenestrationNewDoor
              : l.architectFenestrationNewWindow)
        : _style.name;
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _saving ? null : _leave),
          title: InkWell(
            onTap: _editName,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          actions: [
            IconButton(
              tooltip: l.undoAction,
              onPressed: _undo.isEmpty || _saving
                  ? null
                  : () => _history(false),
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: l.architectFenestrationRedo,
              onPressed: _redo.isEmpty || _saving ? null : () => _history(true),
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              key: const ValueKey('fenestration-save'),
              tooltip: l.save,
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<FenestrationPreviewMode>(
                        showSelectedIcon: false,
                        expandedInsets: EdgeInsets.zero,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 4),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            Theme.of(
                              context,
                            ).textTheme.labelLarge!.copyWith(fontSize: 13),
                          ),
                        ),
                        segments: [
                          ButtonSegment(
                            value: FenestrationPreviewMode.elevation,
                            label: Text(
                              l.architectFenestrationElevationShort,
                              maxLines: 1,
                            ),
                          ),
                          ButtonSegment(
                            value: FenestrationPreviewMode.plan,
                            label: Text(
                              l.architectFenestrationPlanShort,
                              maxLines: 1,
                            ),
                          ),
                          ButtonSegment(
                            value: FenestrationPreviewMode.threeD,
                            label: Text(l.architectFenestration3DShort),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (v) => setState(() {
                          _mode = v.first;
                          _transform.value = Matrix4.identity();
                        }),
                      ),
                    ),
                    IconButton(
                      tooltip: l.fitScreen,
                      onPressed: () => setState(() {
                        _transform.value = Matrix4.identity();
                        _camera.yaw = -.6;
                        _camera.pitch = .25;
                        _camera.zoom = 1.5;
                      }),
                      icon: const Icon(Icons.fit_screen),
                    ),
                    IconButton(
                      tooltip: l.architectFenestrationTemplates,
                      onPressed: _templates,
                      icon: const Icon(Icons.grid_view),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panel = FenestrationPropertiesPanel(
                      style: _style,
                      selectedPaneId: _paneId,
                      formKey: _form,
                      onChanged: _change,
                      onSelectPane: (id) => setState(() => _paneId = id),
                    );
                    if (constraints.maxWidth >= 900) {
                      return Row(
                        children: [
                          Expanded(child: _viewport()),
                          const VerticalDivider(width: 1),
                          SizedBox(width: 350, child: panel),
                        ],
                      );
                    }
                    final fraction = MediaQuery.viewInsetsOf(context).bottom > 0
                        ? .7
                        : _panelFraction;
                    return Column(
                      children: [
                        Expanded(child: _viewport()),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (d) => setState(() {
                            _panelFraction =
                                (_panelFraction -
                                        d.delta.dy / constraints.maxHeight)
                                    .clamp(.25, .75);
                          }),
                          child: Container(
                            height: 22,
                            alignment: Alignment.center,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.outline,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height:
                              math.max(0, constraints.maxHeight - 22) *
                              fraction,
                          child: panel,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
