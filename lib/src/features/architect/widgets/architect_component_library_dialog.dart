import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../components/dsl/parametric_script_parser.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';
import '../models/architect_fenestration_style.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';
import '../services/fenestration_library_service.dart';
import 'architect_component_labels.dart';
import 'component_studio_dialog.dart';
import 'component_preview_painters.dart';

/// One tap selects an object at its catalog size. Editing is a separate action.
class ArchitectComponentLibraryDialog extends StatefulWidget {
  final ValueChanged<ArchitectComponentDefinition>? onSelectComponent;
  final ValueChanged<ArchitectFenestrationStyle>? onSelectFenestration;
  const ArchitectComponentLibraryDialog({
    super.key,
    this.onSelectComponent,
    this.onSelectFenestration,
  });

  static Future<void> show(
    BuildContext context, {
    ValueChanged<ArchitectComponentDefinition>? onSelectComponent,
    ValueChanged<ArchitectFenestrationStyle>? onSelectFenestration,
  }) => showDialog(
    context: context,
    builder: (_) => ArchitectComponentLibraryDialog(
      onSelectComponent: onSelectComponent,
      onSelectFenestration: onSelectFenestration,
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
  bool _show3d = false;

  @override
  void initState() {
    super.initState();
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
      backgroundColor: const Color(0xFF1E1E26),
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
                      l.architectLibrary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.architectLibraryImportHelp,
                    icon: const Icon(
                      Icons.file_upload_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: _import,
                  ),
                  IconButton(
                    tooltip: l.architectComponentStudioTitle,
                    icon: const Icon(Icons.code, color: Colors.white70),
                    onPressed: () => ComponentStudioDialog.show(context),
                  ),
                  IconButton(
                    tooltip: l.close,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l.search,
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: IconButton(
                    key: const ValueKey('component-library-preview-mode'),
                    tooltip: _show3d
                        ? l.architectComponentView2d
                        : l.architectComponentView3d,
                    icon: Icon(
                      _show3d ? Icons.crop_square : Icons.view_in_ar,
                      color: Colors.white70,
                    ),
                    onPressed: () => setState(() => _show3d = !_show3d),
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _search = value),
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
                        dropdownColor: const Color(0xFF262633),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        value: _category,
                        hint: Text(
                          l.architectLibraryAll,
                          style: const TextStyle(color: Colors.white),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l.architectLibraryAll),
                          ),
                          for (final c in ArchitectComponentCategory.values)
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
                        dropdownColor: const Color(0xFF262633),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
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
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: definitions.isEmpty && styles.isEmpty
                  ? Center(
                      child: Text(
                        l.architectComponentNoItems,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: phone ? 190 : 220,
                        mainAxisExtent: 158,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: definitions.length + styles.length,
                      itemBuilder: (context, index) {
                        if (index >= definitions.length) {
                          final style = styles[index - definitions.length];
                          return _card(
                            style.localizedName(l),
                            '${(style.defaultWidth * 100).round()}×${(style.defaultHeight * 100).round()} cm',
                            Icon(
                              style.kind == FenestrationKind.door
                                  ? Icons.meeting_room_outlined
                                  : Icons.window,
                              size: 48,
                              color: Colors.blueGrey,
                            ),
                            () {
                              widget.onSelectFenestration?.call(style);
                              Navigator.of(context).pop();
                            },
                          );
                        }
                        final d = definitions[index];
                        final geometry = ComponentGeometryCache.instance
                            .getOrCompute(d, d.defaultParameters);
                        final sizes = ['width', 'depth', 'height']
                            .map(
                              (key) => ((d.defaultParameters[key] as num) * 100)
                                  .round(),
                            )
                            .join('×');
                        return _card(
                          componentLabel(l, d),
                          '$sizes cm',
                          CustomPaint(
                            painter: _show3d
                                ? ComponentMeshPreviewPainter(
                                    geometry.mesh3d,
                                    .55,
                                    .65,
                                  )
                                : _ComponentThumbnailPainter(geometry.block2d),
                          ),
                          () {
                            library.setActiveDefinition(d);
                            widget.onSelectComponent?.call(d);
                            Navigator.of(context).pop();
                          },
                          onEdit: d is ScriptedComponentDefinition
                              ? () => ComponentStudioDialog.show(
                                  context,
                                  initialScriptJson: d.rawSourceJson,
                                )
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
  }) => Card(
    color: const Color(0xFF2A2A38),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
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
                        tooltip: context.l10n.architectComponentStudioTitle,
                        icon: const Icon(Icons.code, size: 18),
                        onPressed: onEdit,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              dimensions,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
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

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ComponentThumbnailPainter oldDelegate) =>
      oldDelegate.block != block;
}
