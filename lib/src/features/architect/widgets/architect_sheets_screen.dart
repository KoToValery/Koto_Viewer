import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_drawing_publisher.dart';
import '../services/architect_sheet_composer.dart';
import '../services/architect_pdf_export.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();
double? _parse(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class ArchitectSheetsScreen extends StatefulWidget {
  final ArchitectCommandController controller;
  final ArchitectPublicationSources sources;
  const ArchitectSheetsScreen({
    super.key,
    required this.controller,
    this.sources = const ArchitectPublicationSources(),
  });
  @override
  State<ArchitectSheetsScreen> createState() => _SheetsState();
}

class _SheetsState extends State<ArchitectSheetsScreen> {
  String? sheetId, selected;
  Rect? moving;
  bool busy = false;
  final transform = TransformationController();
  ArchitectProject get project => widget.controller.project;
  ArchitectDocument get document => project.document;
  ArchitectSheet? get sheet =>
      document.sheets.where((e) => e.id == sheetId).firstOrNull ??
      document.sheets.firstOrNull;
  ArchitectDrawingPlacement? get placement =>
      sheet?.placements.where((e) => e.id == selected).firstOrNull;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void commit(ArchitectDocument next) =>
      widget.controller.commit(project.copyWith(document: next));
  void saveSheet(ArchitectSheet value) => commit(
    document.copyWith(
      sheets: [
        for (final s in document.sheets)
          if (s.id == value.id) value else s,
      ],
    ),
  );
  void savePlacement(ArchitectDrawingPlacement value) => saveSheet(
    sheet!.copyWith(
      placements: [
        for (final p in sheet!.placements)
          if (p.id == value.id) value else p,
      ],
    ),
  );

  Future<void> sheetProperties({bool create = false}) async {
    final initial = create
        ? ArchitectSheet(
            id: _id(),
            number:
                'A-${(document.sheets.length + 1).toString().padLeft(2, '0')}',
          )
        : sheet;
    if (initial == null) return;
    final result = await showDialog<ArchitectSheet>(
      context: context,
      builder: (_) => _SheetDialog(initial),
    );
    if (result == null || !mounted) return;
    if (create) {
      commit(document.copyWith(sheets: [...document.sheets, result]));
    } else {
      saveSheet(result);
    }
    setState(() {
      sheetId = result.id;
      selected = null;
    });
  }

  List<ArchitectSavedDrawing> _sourceOptions() {
    final candidates = <ArchitectSavedDrawing>[
      for (final s in project.orderedPlanStoreys)
        ArchitectSavedDrawing(
          id: 'plan:${s.id}',
          sourceId: s.id,
          kind: ArchitectDrawingKind.plan,
          name: s.isRoof ? '' : '${s.name} · ${s.elevationLabel}',
          roof: s.isRoof,
          scale:
              document.viewScales['plan:${s.id}'] ??
              project.dimensionScale.denominator,
        ),
      for (var i = 0; i < project.sections.length; i++)
        ArchitectSavedDrawing(
          id: 'section:${project.sections[i].id}',
          sourceId: project.sections[i].id,
          kind: ArchitectDrawingKind.section,
          name: project.sections[i].name,
          sourceNumber: i + 1,
          scale:
              document.viewScales['section:${project.sections[i].id}'] ??
              project.dimensionScale.denominator,
        ),
      for (var i = 0; i < project.elevations.length; i++)
        ArchitectSavedDrawing(
          id: 'elevation:${project.elevations[i].id}',
          sourceId: project.elevations[i].id,
          kind: ArchitectDrawingKind.elevation,
          sourceNumber: i + 1,
          scale:
              document.viewScales['elevation:${project.elevations[i].id}'] ??
              project.dimensionScale.denominator,
        ),
    ];
    return [
      ...document.drawings,
      ...candidates.where(
        (d) => !document.drawings.any((saved) => saved.id == d.id),
      ),
    ];
  }

  Future<void> placeView() async {
    if (sheet == null) return;
    final l = context.l10n;
    final sources = _sourceOptions()
        .where((d) => ArchitectDrawingPublisher.hasSource(project, d))
        .toList();
    final value = await showDialog<ArchitectSavedDrawing>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(l.architectSheetSource),
        children: [
          for (final source in sources)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, source),
              child: Text(ArchitectSheetComposer.drawingName(source, l)),
            ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final existing = document.drawings
        .where((e) => e.id == value.id)
        .firstOrNull;
    final drawing = existing ?? value;
    final scene = ArchitectDrawingPublisher.build(
      project,
      drawing,
      drawing.scale,
      l,
      sources: widget.sources,
    );
    final index = sheet!.placements.length;
    final frame = Rect.fromLTWH(
      sheet!.marginMm + index * 5,
      sheet!.marginMm + index * 5,
      math.min(scene.bounds.width + 4, sheet!.widthMm - 2 * sheet!.marginMm),
      math.min(
        scene.bounds.height + 4,
        math.max(1, sheet!.heightMm - 2 * sheet!.marginMm - 40),
      ),
    );
    final place = ArchitectDrawingPlacement(
      id: _id(),
      drawingId: drawing.id,
      frame: frame,
      anchor:
          (scene.bounds.topLeft - const Offset(2, 2)) * (drawing.scale / 1000),
      scale: drawing.scale,
      number: '${index + 1}',
    );
    final nextSheet = sheet!.copyWith(
      placements: [...sheet!.placements, place],
    );
    commit(
      document.copyWith(
        drawings: existing == null
            ? [...document.drawings, drawing]
            : document.drawings,
        sheets: [
          for (final s in document.sheets)
            if (s.id == nextSheet.id) nextSheet else s,
        ],
      ),
    );
    setState(() => selected = place.id);
  }

  Future<void> placementProperties() async {
    if (placement == null) return;
    final result = await showDialog<ArchitectDrawingPlacement>(
      context: context,
      builder: (_) =>
          _PlacementDialog(placement!, _sourceOptions(), project.units),
    );
    if (result != null && mounted) {
      final linked = _sourceOptions().firstWhere(
        (d) => d.id == result.drawingId,
      );
      commit(
        document.copyWith(
          drawings: document.drawings.any((d) => d.id == linked.id)
              ? document.drawings
              : [...document.drawings, linked],
          sheets: [
            for (final s in document.sheets)
              if (s.id == sheet!.id)
                s.copyWith(
                  placements: [
                    for (final p in s.placements)
                      if (p.id == result.id) result else p,
                  ],
                )
              else
                s,
          ],
        ),
      );
    }
  }

  void duplicate() {
    final p = placement;
    if (p == null) return;
    final j = p.toJson()
      ..['id'] = _id()
      ..['number'] = '${sheet!.placements.length + 1}'
      ..['locked'] = false;
    final copy = ArchitectDrawingPlacement.fromJson(
      j,
    ).copyWith(frame: p.frame.shift(const Offset(5, 5)));
    saveSheet(sheet!.copyWith(placements: [...sheet!.placements, copy]));
    setState(() => selected = copy.id);
  }

  void align(String side) {
    final p = placement, s = sheet;
    if (p == null || p.locked || s == null) return;
    final r = p.frame;
    final delta = switch (side) {
      'left' => Offset(s.marginMm - r.left, 0),
      'right' => Offset(s.widthMm - s.marginMm - r.right, 0),
      'top' => Offset(0, s.marginMm - r.top),
      _ => Offset(0, s.heightMm - s.marginMm - r.bottom),
    };
    savePlacement(p.copyWith(frame: r.shift(delta)));
  }

  Rect snap(Rect frame) {
    final s = sheet!;
    final xs = [
      s.marginMm,
      s.widthMm - s.marginMm,
      for (final p in s.placements.where((e) => e.id != selected)) ...[
        p.frame.left,
        p.frame.right,
      ],
    ];
    final ys = [
      s.marginMm,
      s.heightMm - s.marginMm,
      for (final p in s.placements.where((e) => e.id != selected)) ...[
        p.frame.top,
        p.frame.bottom,
      ],
    ];
    double delta(List<double> values, double a, double b) {
      var best = 2.0, result = 0.0;
      for (final v in values) {
        for (final edge in [a, b]) {
          if ((v - edge).abs() < best) {
            best = (v - edge).abs();
            result = v - edge;
          }
        }
      }
      return result;
    }

    return frame.shift(
      Offset(
        delta(xs, frame.left, frame.right),
        delta(ys, frame.top, frame.bottom),
      ),
    );
  }

  Future<void> template() async {
    final l = context.l10n;
    final chosen = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(l.architectSheetTemplate),
        children: [
          for (final t in document.templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, t.id),
              child: Text(t.name.isEmpty ? l.architectSheetTemplate : t.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, '@edit'),
            child: Text(l.architectSheetEdit),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted || sheet == null) return;
    if (chosen != '@edit') {
      saveSheet(sheet!.copyWith(templateId: chosen));
      return;
    }
    final initial =
        document.templates
            .where((e) => e.id == sheet?.templateId)
            .firstOrNull ??
        ArchitectSheetTemplate.standard;
    final result = await showDialog<ArchitectSheetTemplate>(
      context: context,
      builder: (_) => _TemplateDialog(initial),
    );
    if (result == null || !mounted || sheet == null) return;
    commit(
      document.copyWith(
        templates: [
          ...document.templates.where((e) => e.id != result.id),
          result,
        ],
        sheets: [
          for (final s in document.sheets)
            if (s.id == sheet!.id) s.copyWith(templateId: result.id) else s,
        ],
      ),
    );
  }

  Future<void> visibility() async {
    final drawing = document.drawings
        .where((e) => e.id == placement?.drawingId)
        .firstOrNull;
    if (drawing == null) return;
    final l = context.l10n;
    final visible = {...drawing.visibility};
    final name = TextEditingController(text: drawing.name);
    final labels = {
      'axes': l.architectSheetAxes,
      'zones': l.architectSheetZones,
      'dimensions': l.architectSheetDimensions,
      'annotations': l.architectSheetAnnotations,
      'markers': l.architectSheetMarkers,
    };
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(l.architectSheetVisibility),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: l.architectSheetNameField,
                ),
              ),
              for (final entry in labels.entries)
                CheckboxListTile(
                  title: Text(entry.value),
                  value: visible[entry.key] != false,
                  onChanged: (v) => update(() => visible[entry.key] = v!),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l.architectSheetCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.architectSheetSave),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      commit(
        document.copyWith(
          drawings: [
            for (final d in document.drawings)
              if (d.id == drawing.id)
                d.copyWith(visibility: visible, name: name.text)
              else
                d,
          ],
        ),
      );
    }
    name.dispose();
  }

  Future<void> output({bool print = false}) async {
    final l = context.l10n;
    var chosen = <String>[if (sheet != null) sheet!.id];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(l.architectSheetSelect),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in document.sheets)
                    CheckboxListTile(
                      title: Text(
                        '${s.number} · ${ArchitectSheetComposer.sheetName(s, l)}',
                      ),
                      subtitle: chosen.contains(s.id)
                          ? Text('${chosen.indexOf(s.id) + 1}')
                          : null,
                      value: chosen.contains(s.id),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          chosen.add(s.id);
                        } else {
                          chosen.remove(s.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l.architectSheetCancel),
            ),
            FilledButton(
              onPressed: chosen.isEmpty ? null : () => Navigator.pop(c, chosen),
              child: Text(
                print ? l.architectSheetPrint : l.architectSheetExport,
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      final snapshot = project;
      final sheets = [
        for (final id in result)
          snapshot.document.sheets.firstWhere((s) => s.id == id),
      ];
      if (sheets.any(
        (s) => ArchitectSheetComposer.missingSources(snapshot, s).isNotEmpty,
      )) {
        throw StateError(l.architectSheetMissingSource);
      }
      final bytes = await ArchitectPdfExport.export(
        snapshot,
        sheets,
        l,
        sources: widget.sources,
      );
      if (print) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          format: PdfPageFormat(
            sheets.first.widthMm * ArchitectPdfExport.pointsPerMm,
            sheets.first.heightMm * ArchitectPdfExport.pointsPerMm,
            marginAll: 0,
          ),
          dynamicLayout: false,
          name: '${snapshot.name}.pdf',
          usePrinterSettings: false,
        );
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: l.architectSheetExport,
          fileName:
              '${snapshot.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: bytes,
        );
        if (path != null &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          await File(path).writeAsBytes(bytes, flush: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : l.architectSheetExportFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final l = context.l10n, s = sheet, p = placement;
      final shown = s == null || moving == null || p == null
          ? s
          : s.copyWith(
              placements: [
                for (final v in s.placements)
                  if (v.id == p.id) v.copyWith(frame: moving) else v,
              ],
            );
      final scene = shown == null
          ? null
          : ArchitectSheetComposer.compose(
              project,
              shown,
              l,
              allowMissing: true,
              sources: widget.sources,
            );
      return Scaffold(
        appBar: AppBar(
          title: Text(l.architectSheets),
          actions: [
            IconButton(
              tooltip: l.architectZoneUndoAction,
              onPressed: widget.controller.canUndo
                  ? widget.controller.undo
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: l.architectZoneRedoAction,
              onPressed: widget.controller.canRedo
                  ? widget.controller.redo
                  : null,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: l.architectSheetAdd,
              onPressed: busy ? null : () => sheetProperties(create: true),
              icon: const Icon(Icons.add),
            ),
            PopupMenuButton<String>(
              enabled: !busy && s != null,
              onSelected: (v) {
                if (v == 'properties') sheetProperties();
                if (v == 'template') template();
                if (v == 'pdf') output();
                if (v == 'print') output(print: true);
                if (v == 'delete') {
                  commit(
                    document.copyWith(
                      sheets: document.sheets
                          .where((e) => e.id != s!.id)
                          .toList(),
                    ),
                  );
                  setState(() {
                    selected = null;
                    sheetId = null;
                  });
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'properties',
                  child: Text(l.architectSheetProperties),
                ),
                PopupMenuItem(
                  value: 'template',
                  child: Text(l.architectSheetTemplate),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Text(l.architectSheetExport),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Text(l.architectSheetPrint),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.architectSheetDelete),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (s != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: s.id,
                      items: [
                        for (final v in document.sheets)
                          DropdownMenuItem(
                            value: v.id,
                            child: Text(
                              '${v.number} · ${ArchitectSheetComposer.sheetName(v, l)}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        sheetId = v;
                        selected = null;
                      }),
                    ),
                    IconButton(
                      tooltip: l.architectSheetPlace,
                      onPressed: placeView,
                      icon: const Icon(Icons.add_to_photos_outlined),
                    ),
                    IconButton(
                      tooltip: l.architectSheetEdit,
                      onPressed: p == null || p.locked
                          ? null
                          : placementProperties,
                      icon: const Icon(Icons.tune),
                    ),
                    IconButton(
                      tooltip: l.architectSheetVisibility,
                      onPressed: p == null ? null : visibility,
                      icon: const Icon(Icons.layers_outlined),
                    ),
                    IconButton(
                      tooltip: l.architectSheetDuplicate,
                      onPressed: p == null ? null : duplicate,
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: p?.locked == true
                          ? l.architectSheetUnlock
                          : l.architectSheetLock,
                      onPressed: p == null
                          ? null
                          : () => savePlacement(p.copyWith(locked: !p.locked)),
                      icon: Icon(
                        p?.locked == true ? Icons.lock : Icons.lock_open,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: l.architectSheetAlign,
                      enabled: p != null && !p.locked,
                      onSelected: align,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'left',
                          child: Text(l.architectSheetLeft),
                        ),
                        PopupMenuItem(
                          value: 'right',
                          child: Text(l.architectSheetRight),
                        ),
                        PopupMenuItem(
                          value: 'top',
                          child: Text(l.architectSheetTop),
                        ),
                        PopupMenuItem(
                          value: 'bottom',
                          child: Text(l.architectSheetBottom),
                        ),
                      ],
                      icon: const Icon(Icons.align_horizontal_left),
                    ),
                    IconButton(
                      tooltip: l.architectSheetDelete,
                      onPressed: p == null || p.locked
                          ? null
                          : () {
                              saveSheet(
                                s.copyWith(
                                  placements: s.placements
                                      .where((e) => e.id != p.id)
                                      .toList(),
                                ),
                              );
                              setState(() => selected = null);
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: s == null
                  ? Center(child: Text(l.architectSheetEmpty))
                  : InteractiveViewer(
                      transformationController: transform,
                      constrained: false,
                      minScale: .15,
                      maxScale: 8,
                      boundaryMargin: const EdgeInsets.all(100),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: s.widthMm * 2,
                          height: s.heightMm * 2,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: Size(s.widthMm * 2, s.heightMm * 2),
                                painter: _SheetPainter(scene!),
                              ),
                              for (final v in shown!.placements)
                                Positioned(
                                  left: v.frame.left * 2,
                                  top: v.frame.top * 2,
                                  width: v.frame.width * 2,
                                  height: v.frame.height * 2,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () =>
                                        setState(() => selected = v.id),
                                    onDoubleTap: () {
                                      final source = document.drawings
                                          .where((e) => e.id == v.drawingId)
                                          .firstOrNull;
                                      if (source != null &&
                                          ArchitectDrawingPublisher.hasSource(
                                            project,
                                            source,
                                          )) {
                                        Navigator.pop(context, source);
                                      }
                                    },
                                    onPanStart: v.locked
                                        ? null
                                        : (_) => setState(() {
                                            selected = v.id;
                                            moving = v.frame;
                                          }),
                                    onPanUpdate: v.locked
                                        ? null
                                        : (e) => setState(
                                            () => moving = (moving ?? v.frame)
                                                .shift(e.delta / 2),
                                          ),
                                    onPanEnd: v.locked
                                        ? null
                                        : (_) {
                                            final r = snap(moving ?? v.frame);
                                            moving = null;
                                            savePlacement(v.copyWith(frame: r));
                                          },
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: selected == v.id
                                              ? Colors.blue
                                              : Colors.grey.withValues(
                                                  alpha: .25,
                                                ),
                                          width: selected == v.id ? 2 : .5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _SheetPainter extends CustomPainter {
  final ArchitectVectorScene scene;
  _SheetPainter(this.scene);
  @override
  void paint(Canvas c, Size size) {
    c.scale(2);
    scene.paint(c);
  }

  @override
  bool shouldRepaint(covariant _SheetPainter oldDelegate) =>
      !identical(scene, oldDelegate.scene);
}

class _SheetDialog extends StatefulWidget {
  final ArchitectSheet initial;
  const _SheetDialog(this.initial);
  @override
  State<_SheetDialog> createState() => _SheetDialogState();
}

class _SheetDialogState extends State<_SheetDialog> {
  late final values = [
    widget.initial.name,
    widget.initial.number,
    widget.initial.author,
    widget.initial.date,
    '${widget.initial.widthMm}',
    '${widget.initial.heightMm}',
    '${widget.initial.marginMm}',
  ].map((v) => TextEditingController(text: v)).toList();
  bool invalid = false;
  @override
  void dispose() {
    for (final c in values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.architectSheetNameField,
      l.architectSheetNumber,
      l.architectSheetAuthor,
      l.architectSheetDate,
      l.architectSheetWidth,
      l.architectSheetHeight,
      l.architectSheetMargin,
    ];
    return AlertDialog(
      title: Text(l.architectSheetProperties),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: 'custom',
                decoration: InputDecoration(labelText: l.architectSheetFormat),
                items: [
                  for (final v in ['A4', 'A3', 'A2', 'A1', 'A0'])
                    DropdownMenuItem(value: v, child: Text(v)),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text(l.architectSheetCustom),
                  ),
                ],
                onChanged: (v) {
                  final formats = {
                    'A4': [297, 210],
                    'A3': [420, 297],
                    'A2': [594, 420],
                    'A1': [841, 594],
                    'A0': [1189, 841],
                  };
                  if (formats.containsKey(v)) {
                    setState(() {
                      values[4].text = '${formats[v]![0]}';
                      values[5].text = '${formats[v]![1]}';
                    });
                  }
                },
              ),
              IconButton(
                tooltip: l.architectSheetRotation,
                icon: const Icon(Icons.screen_rotation),
                onPressed: () => setState(() {
                  final w = values[4].text;
                  values[4].text = values[5].text;
                  values[5].text = w;
                }),
              ),
              for (var i = 0; i < values.length; i++)
                TextField(
                  controller: values[i],
                  decoration: InputDecoration(labelText: labels[i]),
                  keyboardType: i >= 4
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                ),
              if (invalid)
                Text(
                  l.architectSheetInvalid,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.architectSheetCancel),
        ),
        FilledButton(
          onPressed: () {
            final w = _parse(values[4].text),
                h = _parse(values[5].text),
                m = _parse(values[6].text);
            if (w == null ||
                h == null ||
                m == null ||
                !w.isFinite ||
                !h.isFinite ||
                !m.isFinite ||
                w <= 0 ||
                h <= 0 ||
                m < 0 ||
                m * 2 >= math.min(w, h)) {
              setState(() => invalid = true);
              return;
            }
            Navigator.pop(
              context,
              widget.initial.copyWith(
                name: values[0].text,
                number: values[1].text,
                author: values[2].text,
                date: values[3].text,
                widthMm: w,
                heightMm: h,
                marginMm: m,
              ),
            );
          },
          child: Text(l.architectSheetSave),
        ),
      ],
    );
  }
}

class _PlacementDialog extends StatefulWidget {
  final ArchitectDrawingPlacement initial;
  final List<ArchitectSavedDrawing> drawings;
  final ArchitectUnit units;
  const _PlacementDialog(this.initial, this.drawings, this.units);
  @override
  State<_PlacementDialog> createState() => _PlacementDialogState();
}

class _PlacementDialogState extends State<_PlacementDialog> {
  late final fields = [
    widget.initial.number,
    '${widget.initial.frame.left}',
    '${widget.initial.frame.top}',
    '${widget.initial.frame.width}',
    '${widget.initial.frame.height}',
    '${widget.units.toUnit(widget.initial.anchor.dx)}',
    '${widget.units.toUnit(widget.initial.anchor.dy)}',
    '${widget.initial.rotation}',
  ].map((e) => TextEditingController(text: e)).toList();
  late int scale = widget.initial.scale;
  late String? source =
      widget.drawings.any((e) => e.id == widget.initial.drawingId)
      ? widget.initial.drawingId
      : null;
  late bool title = widget.initial.showTitle;
  bool invalid = false;
  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.architectSheetNumber,
      l.architectSheetX,
      l.architectSheetY,
      l.architectSheetWidth,
      l.architectSheetHeight,
      '${l.architectSheetAnchorX} (${widget.units.symbol})',
      '${l.architectSheetAnchorY} (${widget.units.symbol})',
      l.architectSheetRotation,
    ];
    return AlertDialog(
      title: Text(l.architectSheetEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: source,
                decoration: InputDecoration(labelText: l.architectSheetSource),
                items: [
                  for (final d in widget.drawings)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(ArchitectSheetComposer.drawingName(d, l)),
                    ),
                ],
                onChanged: (v) => source = v,
              ),
              DropdownButtonFormField<int>(
                initialValue: scale,
                decoration: InputDecoration(labelText: l.architectSheetScale),
                items: [
                  for (final n in ArchitectDrawingScale.presets)
                    DropdownMenuItem(value: n, child: Text('1:$n')),
                ],
                onChanged: (v) => scale = v!,
              ),
              for (var i = 0; i < fields.length; i++)
                TextField(
                  controller: fields[i],
                  decoration: InputDecoration(labelText: labels[i]),
                  keyboardType: i == 0
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                ),
              SwitchListTile(
                title: Text(l.architectSheetTitle),
                value: title,
                onChanged: (v) => setState(() => title = v),
              ),
              if (invalid)
                Text(
                  l.architectSheetInvalid,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.architectSheetCancel),
        ),
        FilledButton(
          onPressed: () {
            final n = fields.skip(1).map((c) => _parse(c.text)).toList();
            if (source == null ||
                n.any((v) => v == null || !v.isFinite) ||
                n[2]! <= 0 ||
                n[3]! <= 0) {
              setState(() => invalid = true);
              return;
            }
            Navigator.pop(
              context,
              widget.initial.copyWith(
                drawingId: source,
                number: fields[0].text,
                frame: Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!),
                anchor: Offset(
                  widget.units.fromUnit(n[4]!),
                  widget.units.fromUnit(n[5]!),
                ),
                rotation: n[6],
                scale: scale,
                showTitle: title,
              ),
            );
          },
          child: Text(l.architectSheetSave),
        ),
      ],
    );
  }
}

class _TemplateDialog extends StatefulWidget {
  final ArchitectSheetTemplate initial;
  const _TemplateDialog(this.initial);
  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final name = TextEditingController(text: widget.initial.name);
  late List<ArchitectTitleItem> items = [...widget.initial.items];
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> edit(ArchitectTitleItem item) async {
    final l = context.l10n;
    final fields = [
      item.text,
      '${item.rect.left}',
      '${item.rect.top}',
      '${item.rect.width}',
      '${item.rect.height}',
      '${item.textMm}',
    ].map((e) => TextEditingController(text: e)).toList();
    var field = item.field, border = item.border, invalid = false;
    final result = await showDialog<ArchitectTitleItem>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(l.architectSheetField),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ArchitectTitleField>(
                    initialValue: field,
                    items: [
                      for (final f in ArchitectTitleField.values)
                        DropdownMenuItem(
                          value: f,
                          child: Text(_fieldLabel(l, f)),
                        ),
                    ],
                    onChanged: (v) => field = v!,
                  ),
                  for (var i = 0; i < fields.length; i++)
                    TextField(
                      controller: fields[i],
                      decoration: InputDecoration(
                        labelText: [
                          l.architectSheetText,
                          l.architectSheetX,
                          l.architectSheetY,
                          l.architectSheetWidth,
                          l.architectSheetHeight,
                          l.architectAnnotationSize,
                        ][i],
                      ),
                    ),
                  SwitchListTile(
                    title: Text(l.architectSheetBorder),
                    value: border,
                    onChanged: (v) => update(() => border = v),
                  ),
                  if (invalid) Text(l.architectSheetInvalid),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l.architectSheetCancel),
            ),
            FilledButton(
              onPressed: () {
                final n = fields.skip(1).map((e) => _parse(e.text)).toList();
                if (n.any((v) => v == null || !v.isFinite) ||
                    n[2]! < 0 ||
                    n[3]! < 0 ||
                    n[4]! <= 0) {
                  update(() => invalid = true);
                  return;
                }
                Navigator.pop(
                  c,
                  ArchitectTitleItem(
                    id: item.id,
                    rect: Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!),
                    text: fields[0].text,
                    textMm: n[4]!,
                    field: field,
                    border: border,
                  ),
                );
              },
              child: Text(l.architectSheetSave),
            ),
          ],
        ),
      ),
    );
    for (final f in fields) {
      f.dispose();
    }
    if (result != null && mounted) {
      setState(() {
        final index = items.indexWhere((e) => e.id == item.id);
        if (index < 0) {
          items.add(result);
        } else {
          items[index] = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.architectSheetTemplate),
      content: SizedBox(
        width: 500,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: l.architectSheetTemplateName,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(_fieldLabel(l, item.field)),
                      subtitle: Text(
                        item.field == ArchitectTitleField.text
                            ? item.text
                            : '${item.rect.width} × ${item.rect.height} mm',
                      ),
                      onTap: () => edit(item),
                      trailing: IconButton(
                        tooltip: l.architectSheetDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => items.remove(item)),
                      ),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => edit(
                ArchitectTitleItem(
                  id: _id(),
                  rect: const Rect.fromLTWH(0, 30, 180, 10),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l.architectSheetAddCell),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.architectSheetCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ArchitectSheetTemplate(
              id: widget.initial.id == 'standard' ? _id() : widget.initial.id,
              name: name.text,
              items: items,
            ),
          ),
          child: Text(l.architectSheetSave),
        ),
      ],
    );
  }
}

String _fieldLabel(AppLocalizations l, ArchitectTitleField f) => switch (f) {
  ArchitectTitleField.text => l.architectSheetText,
  ArchitectTitleField.project => l.architectSheetProject,
  ArchitectTitleField.drawing => l.architectSheetDrawing,
  ArchitectTitleField.number => l.architectSheetNumber,
  ArchitectTitleField.scale => l.architectSheetScale,
  ArchitectTitleField.author => l.architectSheetAuthor,
  ArchitectTitleField.date => l.architectSheetDate,
};
