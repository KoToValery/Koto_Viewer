import 'architect_dialog.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
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
import '../services/architect_sheet_layout.dart';
import '../services/architect_sheet_geometry.dart';
import 'architect_sheet_viewport.dart';
import 'architect_exchange_export_dialog.dart';

String _paperFormat(double width, double height) {
  for (final e in {
    'A4': (297, 210),
    'A3': (420, 297),
    'A2': (594, 420),
    'A1': (841, 594),
    'A0': (1189, 841),
  }.entries) {
    if ((math.max(width, height) - e.value.$1).abs() < .1 &&
        (math.min(width, height) - e.value.$2).abs() < .1) {
      return e.key;
    }
  }
  return 'custom';
}

String _paperNumber(double value) {
  final text = ArchitectUnit.trimZeros(value.toStringAsFixed(3));
  return text == '-0' ? '0' : text;
}

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
  ArchitectDrawingPlacement? pendingPlacement;
  ArchitectSavedDrawing? pendingDrawing;
  bool cropMode = false;
  bool busy = false;
  final viewportKey = GlobalKey<ArchitectSheetViewportState>();
  final drawingScenes = <Object, ArchitectVectorScene>{};
  Object? sceneRevision;
  AppLocalizations? sceneLabels;
  ArchitectPublicationSources? sceneSources;
  Object? preflightRevision;
  List<String> preflightIssues = const [];

  List<String> layoutIssues(ArchitectSheet value, AppLocalizations l) {
    final key = (
      ArchitectDrawingPublisher.sourceRevision(project),
      document,
      value,
      l.localeName,
    );
    if (key != preflightRevision) {
      preflightRevision = key;
      preflightIssues = ArchitectSheetComposer.issues(project, value, l);
    }
    return preflightIssues;
  }

  Future<void> exchange(ArchitectExchangeFormat format) =>
      showArchitectExchangeExport(
        context,
        project: project,
        format: format,
        drawings: _sourceOptions(),
        sources: widget.sources,
        initialSheetId: sheet?.id,
      );

  void fitSheet() => viewportKey.currentState?.fitSheet();

  void cancelEdit() => setState(() {
    pendingPlacement = null;
    pendingDrawing = null;
    cropMode = false;
  });

  void message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> checkLayout() async {
    final s = sheet;
    if (s == null) return;
    final l = context.l10n, problems = layoutIssues(s, l);
    await showDialog<void>(
      context: context,
      builder: (c) => architectAlertDialog(
        scrollable: true,
        title: Text(
          problems.isEmpty ? l.architectSheetReady : l.architectSheetCheck,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final issue in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(issue),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.close)),
        ],
      ),
    );
  }

  ArchitectDrawingPlacement? fitPlacement(
    ArchitectDrawingPlacement place,
    Rect area,
    ArchitectSavedDrawing drawing, {
    bool reportFailure = true,
  }) {
    final l = context.l10n;
    try {
      return ArchitectSheetLayout.fit(
        place,
        area,
        (scale) => ArchitectDrawingPublisher.build(
          project,
          drawing.copyWith(
            visibility: {...drawing.visibility, ...place.visibilityOverrides},
          ),
          scale,
          l,
          sources: widget.sources,
        ),
        title: (scale) =>
            '${place.number}  ${ArchitectSheetComposer.drawingName(drawing, l)}  1:$scale',
      );
    } on ArchitectSheetFitException {
      if (reportFailure) message(l.architectSheetNoSpace);
      return null;
    }
  }

  void fitView() {
    final p = placement, s = sheet;
    if (p == null || p.locked || s == null) return;
    final drawing = document.drawings
        .where((d) => d.id == p.drawingId)
        .firstOrNull;
    if (drawing == null ||
        !ArchitectDrawingPublisher.hasSource(project, drawing)) {
      return;
    }
    final areas = ArchitectSheetLayout.freeAreas(
      project,
      s,
      context.l10n,
      excludePlacement: p.id,
    );
    final l = context.l10n;
    ArchitectDrawingPlacement? fitted;
    for (final area in areas) {
      final candidate = fitPlacement(p, area, drawing, reportFailure: false);
      if (candidate != null &&
          (fitted == null || candidate.scale < fitted.scale)) {
        fitted = candidate;
      }
    }
    if (fitted == null) {
      message(l.architectSheetNoSpace);
      return;
    }
    savePlacement(fitted);
    if (fitted.scale != p.scale) {
      message(l.architectSheetScaleAdjusted(fitted.scale));
    }
  }

  ArchitectProject get project => widget.controller.project;
  ArchitectDocument get document => project.document;
  ArchitectSheet? get sheet =>
      document.sheets.where((e) => e.id == sheetId).firstOrNull ??
      document.sheets.firstOrNull;
  ArchitectDrawingPlacement? get placement =>
      sheet?.placements.where((e) => e.id == selected).firstOrNull;
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
      pendingPlacement = null;
      pendingDrawing = null;
      cropMode = false;
    });
  }

  List<ArchitectSavedDrawing> _sourceOptions() {
    final candidates = <ArchitectSavedDrawing>[
      for (final s in project.orderedPlanStoreys)
        ArchitectSavedDrawing(
          id: 'plan:${s.id}',
          sourceId: s.id,
          kind: ArchitectDrawingKind.plan,
          name: s.isRoof ? '' : s.name,
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
    if (sources.isEmpty) {
      message(l.architectSheetNoViews);
      return;
    }
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
    final bounds = scene.bounds;
    final gap = ArchitectSheetLayout.gapMm;
    final origin = Offset(sheet!.marginMm, sheet!.marginMm);
    final place = ArchitectDrawingPlacement(
      id: _id(),
      drawingId: drawing.id,
      frame: Rect.fromLTWH(
        origin.dx,
        origin.dy,
        math.max(20, bounds.width + gap),
        math.max(20, bounds.height + gap),
      ),
      anchor:
          (bounds.topLeft - Offset(gap / 2, gap / 2)) * (drawing.scale / 1000),
      scale: drawing.scale,
      number: '${sheet!.placements.length + 1}',
    );
    setState(() {
      pendingDrawing = drawing;
      pendingPlacement = place;
      cropMode = false;
    });
  }

  void placePending(ArchitectDrawingPlacement place) {
    final target = sheet, drawing = pendingDrawing;
    if (target == null || drawing == null || pendingPlacement?.id != place.id) {
      return;
    }
    final nextSheet = sheet!.copyWith(
      placements: [...sheet!.placements, place],
    );
    commit(
      document.copyWith(
        drawings: !document.drawings.any((d) => d.id == drawing.id)
            ? [...document.drawings, drawing]
            : document.drawings,
        sheets: [
          for (final s in document.sheets)
            if (s.id == nextSheet.id) nextSheet else s,
        ],
      ),
    );
    setState(() {
      selected = place.id;
      pendingPlacement = null;
      pendingDrawing = null;
    });
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
    final drawing = document.drawings
        .where((d) => d.id == p.drawingId)
        .firstOrNull;
    if (drawing == null ||
        !ArchitectDrawingPublisher.hasSource(project, drawing)) {
      return;
    }
    setState(() {
      pendingDrawing = drawing;
      pendingPlacement = p.copyWith(
        id: _id(),
        number: '${sheet!.placements.length + 1}',
        locked: false,
        frame: p.frame.shift(const Offset(10, 10)),
      );
      cropMode = false;
    });
  }

  Future<void> changeScale() async {
    final initial = placement;
    if (initial == null || initial.locked) return;
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _ScaleDialog(initial.scale),
    );
    if (!mounted || value == null || placement?.id != initial.id) return;
    savePlacement(ArchitectSheetGeometry.changeScale(initial, value));
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

  Future<void> renameDrawing() async {
    final drawing = document.drawings
        .where((d) => d.id == placement?.drawingId)
        .firstOrNull;
    if (drawing == null) return;
    final l = context.l10n;
    var name = drawing.name;
    final value = await showDialog<String>(
      context: context,
      builder: (c) => architectAlertDialog(
        title: Text(l.commandIconRename),
        content: TextFormField(
          initialValue: name,
          onChanged: (value) => name = value,
          autofocus: true,
          decoration: InputDecoration(labelText: l.architectSheetNameField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l.architectSheetCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, name),
            child: Text(l.architectSheetSave),
          ),
        ],
      ),
    );
    // The name belongs to the saved source. Visibility is edited independently
    // below, so its dialog cannot change any sibling placement accidentally.
    if (mounted && value != null && value != drawing.name) {
      commit(
        document.copyWith(
          drawings: [
            for (final d in document.drawings)
              if (d.id == drawing.id) d.copyWith(name: value) else d,
          ],
        ),
      );
    }
  }

  Future<void> visibility() async {
    final initial = placement;
    if (initial == null) return;
    final drawing = document.drawings
        .where((e) => e.id == initial.drawingId)
        .firstOrNull;
    if (drawing == null) return;
    final l = context.l10n;
    final visible = {...initial.visibilityOverrides};
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
        builder: (c, update) => architectAlertDialog(
          title: Text(l.architectSheetVisibility),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.architectSheetVisibilityHint),
              ),
              for (final entry in labels.entries)
                CheckboxListTile(
                  title: Text(entry.value),
                  value:
                      (visible[entry.key] ?? drawing.visibility[entry.key]) !=
                      false,
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
    if (result == true && mounted && placement?.id == initial.id) {
      savePlacement(initial.copyWith(visibilityOverrides: visible));
    }
  }

  Future<void> output({bool print = false}) async {
    final l = context.l10n;
    var chosen = <String>[if (sheet != null) sheet!.id];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => architectAlertDialog(
          title: Text(l.architectSheetSelect),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.architectSheetExportOrder),
                  const SizedBox(height: 8),
                  for (final s in document.sheets)
                    CheckboxListTile(
                      title: Text(
                        '${s.number} · ${ArchitectSheetComposer.sheetName(s, l)}',
                      ),
                      subtitle: chosen.contains(s.id)
                          ? Text(
                              '${chosen.indexOf(s.id) + 1} · ${s.widthMm.round()} × ${s.heightMm.round()} mm',
                            )
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
        if (path != null && mounted) message(l.architectSheetExported);
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
      final editing = pendingPlacement != null || cropMode;
      final revision = ArchitectDrawingPublisher.sourceRevision(project);
      if (sceneRevision != revision ||
          !identical(sceneLabels, l) ||
          !identical(sceneSources, widget.sources)) {
        drawingScenes.clear();
        sceneRevision = revision;
        sceneLabels = l;
        sceneSources = widget.sources;
      }
      ArchitectVectorScene buildScene(
        ArchitectSheet preview, {
        Set<String> excludePlacements = const {},
      }) {
        final drawing = pendingDrawing;
        final previewProject =
            drawing == null || document.drawings.any((d) => d.id == drawing.id)
            ? project
            : project.copyWith(
                document: document.copyWith(
                  drawings: [...document.drawings, drawing],
                ),
              );
        return ArchitectSheetComposer.compose(
          previewProject,
          preview,
          l,
          allowMissing: true,
          previewOutsideSheet: true,
          excludePlacements: excludePlacements,
          sources: widget.sources,
          drawingScenes: drawingScenes,
        );
      }

      String drawingLabel(ArchitectDrawingPlacement value) {
        final drawing =
            document.drawings
                .where((d) => d.id == value.drawingId)
                .firstOrNull ??
            pendingDrawing;
        final name = drawing == null
            ? l.architectSheetMissingSource
            : ArchitectSheetComposer.drawingName(drawing, l);
        return '${value.number}  $name  1:${value.scale}';
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(l.architectSheets),
          actions: [
            IconButton(
              tooltip: l.architectSheetAdd,
              onPressed: busy || editing
                  ? null
                  : () => sheetProperties(create: true),
              icon: const AppIcon(AppIconId.add),
            ),
            IconButton(
              key: const ValueKey('architect-sheet-export'),
              tooltip: l.architectSheetExport,
              onPressed: busy || editing || s == null ? null : output,
              icon: const AppIcon(AppIconId.pdf),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('architect-sheet-more'),
              enabled: !busy && !editing,
              onSelected: (v) {
                if (v == 'dxfViews') exchange(ArchitectExchangeFormat.dxfViews);
                if (v == 'dxfSheets') {
                  exchange(ArchitectExchangeFormat.dxfSheets);
                }
                if (v == 'ifc') exchange(ArchitectExchangeFormat.ifc);
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
                  enabled: s != null,
                  child: AppMenuLabel(
                    icon: AppIconId.properties,
                    child: Text(l.architectSheetProperties),
                  ),
                ),
                PopupMenuItem(
                  value: 'template',
                  enabled: s != null,
                  child: AppMenuLabel(
                    icon: AppIconId.layoutGrid,
                    child: Text(l.architectSheetTemplate),
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  enabled: s != null,
                  child: AppMenuLabel(
                    icon: AppIconId.pdf,
                    child: Text(l.architectSheetExport),
                  ),
                ),
                PopupMenuItem(
                  value: 'print',
                  enabled: s != null,
                  child: AppMenuLabel(
                    icon: AppIconId.print,
                    child: Text(l.architectSheetPrint),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: s != null,
                  child: AppMenuLabel(
                    icon: AppIconId.delete,
                    child: Text(l.architectSheetDelete),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'dxfViews',
                  key: const ValueKey('architect-sheet-export-dxf-views'),
                  child: AppMenuLabel(
                    icon: AppIconId.file,
                    child: Text(l.architectExportDxfViews),
                  ),
                ),
                PopupMenuItem(
                  value: 'dxfSheets',
                  enabled: s != null,
                  key: const ValueKey('architect-sheet-export-dxf-sheets'),
                  child: AppMenuLabel(
                    icon: AppIconId.layoutGrid,
                    child: Text(l.architectExportDxfSheets),
                  ),
                ),
                PopupMenuItem(
                  value: 'ifc',
                  key: const ValueKey('architect-sheet-export-ifc'),
                  child: AppMenuLabel(
                    icon: AppIconId.building,
                    child: Text(l.architectExportIfc),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (s != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        key: const ValueKey('architect-sheet-selector'),
                        value: s.id,
                        isExpanded: true,
                        items: [
                          for (final v in document.sheets)
                            DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                '${v.number} · ${ArchitectSheetComposer.sheetName(v, l)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                sheetId = v;
                                selected = null;
                                pendingPlacement = null;
                                pendingDrawing = null;
                                cropMode = false;
                              }),
                      ),
                    ),
                    IconButton(
                      tooltip: l.architectZoneUndoAction,
                      onPressed: busy || editing
                          ? null
                          : widget.controller.canUndo
                          ? widget.controller.undo
                          : null,
                      icon: const AppIcon(AppIconId.undo),
                    ),
                    IconButton(
                      tooltip: l.architectZoneRedoAction,
                      onPressed: busy || editing
                          ? null
                          : widget.controller.canRedo
                          ? widget.controller.redo
                          : null,
                      icon: const AppIcon(AppIconId.redo),
                    ),
                    IconButton(
                      tooltip: l.architectSheetFit,
                      onPressed: fitSheet,
                      icon: const AppIcon(AppIconId.fitView),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Tooltip(
                      message: l.architectSheetPlace,
                      child: FilledButton.icon(
                        onPressed: busy || editing ? null : placeView,
                        icon: const AppIcon(AppIconId.imageAdd, size: 18),
                        label: Text(l.architectSheetPlaceShort),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('architect-sheet-preflight'),
                        onPressed: editing ? null : checkLayout,
                        child: Text(
                          layoutIssues(s, l).isEmpty
                              ? l.architectSheetReady
                              : l.architectSheetCheck,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (p != null && !editing)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('architect-sheet-crop'),
                        tooltip: l.architectSheetCrop,
                        onPressed: p.locked || busy
                            ? null
                            : () => setState(() => cropMode = true),
                        icon: const AppIcon(AppIconId.cutOpening),
                      ),
                      IconButton(
                        key: const ValueKey('architect-sheet-scale'),
                        tooltip: l.architectSheetScale,
                        onPressed: p.locked || busy ? null : changeScale,
                        icon: const AppIcon(AppIconId.aspectRatio),
                      ),
                      IconButton(
                        tooltip: l.architectSheetFitView,
                        onPressed: p.locked || busy ? null : fitView,
                        icon: const AppIcon(AppIconId.fitView),
                      ),
                      IconButton(
                        tooltip: l.architectSheetEdit,
                        onPressed: p.locked || busy
                            ? null
                            : placementProperties,
                        icon: const AppIcon(AppIconId.properties),
                      ),
                      IconButton(
                        tooltip: l.architectSheetVisibility,
                        onPressed: busy ? null : visibility,
                        icon: const AppIcon(AppIconId.layers),
                      ),
                      IconButton(
                        tooltip: l.commandIconRename,
                        onPressed: busy ? null : renameDrawing,
                        icon: const AppIcon(AppIconId.rename),
                      ),
                      IconButton(
                        tooltip: l.architectSheetDuplicate,
                        onPressed: busy ? null : duplicate,
                        icon: const AppIcon(AppIconId.duplicate),
                      ),
                      IconButton(
                        tooltip: p.locked
                            ? l.architectSheetUnlock
                            : l.architectSheetLock,
                        onPressed: busy
                            ? null
                            : () =>
                                  savePlacement(p.copyWith(locked: !p.locked)),
                        icon: AppIcon.fromMaterial(
                          p.locked ? Icons.lock : Icons.lock_open,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l.architectSheetAlign,
                        enabled: !busy && !p.locked,
                        onSelected: align,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'left',
                            child: AppMenuLabel(
                              icon: AppIconId.alignLeft,
                              child: Text(l.architectSheetLeft),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'right',
                            child: AppMenuLabel(
                              icon: AppIconId.alignRight,
                              child: Text(l.architectSheetRight),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'top',
                            child: AppMenuLabel(
                              icon: AppIconId.alignTop,
                              child: Text(l.architectSheetTop),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'bottom',
                            child: AppMenuLabel(
                              icon: AppIconId.alignBottom,
                              child: Text(l.architectSheetBottom),
                            ),
                          ),
                        ],
                        icon: const AppIcon(AppIconId.alignLeft),
                      ),
                      IconButton(
                        tooltip: l.architectSheetDelete,
                        onPressed: p.locked || busy
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
                        icon: const AppIcon(AppIconId.delete),
                      ),
                    ],
                  ),
                ),
            ],
            Expanded(
              child: s == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.architectSheetEmpty,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => sheetProperties(create: true),
                              icon: const AppIcon(AppIconId.add),
                              label: Text(l.architectSheetAdd),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ArchitectSheetViewport(
                      key: viewportKey,
                      sheet: s,
                      buildScene: buildScene,
                      buildPaper: (preview) => buildScene(
                        preview,
                        excludePlacements: preview.placements
                            .map((p) => p.id)
                            .toSet(),
                      ),
                      paperRevision: (project, l.localeName, pendingDrawing),
                      contentRevision: (
                        revision,
                        document.drawings,
                        l.localeName,
                        widget.sources,
                      ),
                      buildBackground: (preview, excluded) =>
                          buildScene(preview, excludePlacements: {excluded}),
                      buildContent: (value) =>
                          ArchitectSheetComposer.placementContent(
                            pendingDrawing != null &&
                                    !document.drawings.any(
                                      (d) => d.id == pendingDrawing!.id,
                                    )
                                ? project.copyWith(
                                    document: document.copyWith(
                                      drawings: [
                                        ...document.drawings,
                                        pendingDrawing!,
                                      ],
                                    ),
                                  )
                                : project,
                            value,
                            l,
                            sources: widget.sources,
                            drawingScenes: drawingScenes,
                          ),
                      selectedId: selected,
                      onSelect: (id) => setState(() {
                        selected = id;
                        cropMode = false;
                      }),
                      onMove: savePlacement,
                      onOpenSource: (id) {
                        final source = document.drawings
                            .where((d) => d.id == id)
                            .firstOrNull;
                        if (source != null &&
                            ArchitectDrawingPublisher.hasSource(
                              project,
                              source,
                            )) {
                          Navigator.pop(context, source);
                        }
                      },
                      pendingPlacement: pendingPlacement,
                      onPlace: placePending,
                      onCancelPlacement: cancelEdit,
                      cropMode: cropMode,
                      onCrop: (value) {
                        savePlacement(value);
                        setState(() => cropMode = false);
                      },
                      onCancelCrop: () => setState(() => cropMode = false),
                      busy: busy,
                      titleBlock: ArchitectSheetLayout.titleBlock(project, s),
                      drawingLabel: drawingLabel,
                    ),
            ),
          ],
        ),
      );
    },
  );
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
    return architectAlertDialog(
      title: Text(l.architectSheetProperties),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(
                  _paperFormat(
                    _parse(values[4].text) ?? 0,
                    _parse(values[5].text) ?? 0,
                  ),
                ),
                initialValue: _paperFormat(
                  _parse(values[4].text) ?? 0,
                  _parse(values[5].text) ?? 0,
                ),
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
                icon: const AppIcon(AppIconId.screenRotate),
                onPressed: () => setState(() {
                  final w = values[4].text;
                  values[4].text = values[5].text;
                  values[5].text = w;
                }),
              ),
              for (var i = 0; i < values.length; i++)
                TextField(
                  controller: values[i],
                  onChanged: i == 4 || i == 5 ? (_) => setState(() {}) : null,
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
  late final original = <double>[
    widget.initial.frame.left,
    widget.initial.frame.top,
    widget.initial.frame.width,
    widget.initial.frame.height,
    widget.units.toUnit(widget.initial.anchor.dx),
    widget.units.toUnit(widget.initial.anchor.dy),
    widget.initial.rotation,
  ];
  late final fields = [
    widget.initial.number,
    for (final value in original) _paperNumber(value),
  ].map((e) => TextEditingController(text: e)).toList();
  late final scaleField = TextEditingController(
    text: '${widget.initial.scale}',
  );
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
    scaleField.dispose();
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
    return architectAlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l.architectSheetEdit)),
          Tooltip(
            message: l.architectSheetCropHint,
            child: const AppIcon(AppIconId.help, size: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: source,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.architectSheetSource),
                items: [
                  for (final d in widget.drawings)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        ArchitectSheetComposer.drawingName(d, l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => source = v,
              ),
              _scaleInput(context, scaleField),
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
            final scale = int.tryParse(scaleField.text.trim());
            final n = [
              for (var i = 0; i < original.length; i++)
                fields[i + 1].text == _paperNumber(original[i])
                    ? original[i]
                    : _parse(fields[i + 1].text),
            ];
            if (source == null ||
                scale == null ||
                scale <= 0 ||
                n.any((v) => v == null || !v.isFinite) ||
                n[2]! <= 0 ||
                n[3]! <= 0) {
              setState(() => invalid = true);
              return;
            }
            var next =
                ArchitectSheetGeometry.resizeFrame(
                  widget.initial,
                  Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!),
                ).copyWith(
                  drawingId: source,
                  number: fields[0].text,
                  anchor: Offset(
                    fields[5].text == _paperNumber(original[4])
                        ? widget.initial.anchor.dx
                        : widget.units.fromUnit(n[4]!),
                    fields[6].text == _paperNumber(original[5])
                        ? widget.initial.anchor.dy
                        : widget.units.fromUnit(n[5]!),
                  ),
                  rotation: n[6],
                  showTitle: title,
                );
            if (scale != widget.initial.scale) {
              next = ArchitectSheetGeometry.changeScale(next, scale);
            }
            Navigator.pop(context, next);
          },
          child: Text(l.architectSheetSave),
        ),
      ],
    );
  }
}

Widget _scaleInput(BuildContext context, TextEditingController controller) {
  final l = context.l10n;
  return TextField(
    key: const ValueKey('architect-sheet-scale-input'),
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: l.architectSheetScale,
      prefixText: '1:',
      suffixIcon: PopupMenuButton<int>(
        tooltip: l.architectSheetScale,
        icon: const AppIcon(AppIconId.expandMore, size: 20),
        onSelected: (value) => controller.text = '$value',
        itemBuilder: (_) => [
          for (final value in ArchitectDrawingScale.presets)
            PopupMenuItem(value: value, child: Text('1:$value')),
        ],
      ),
    ),
  );
}

class _ScaleDialog extends StatefulWidget {
  final int initial;
  const _ScaleDialog(this.initial);
  @override
  State<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<_ScaleDialog> {
  late final controller = TextEditingController(text: '${widget.initial}');
  bool invalid = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return architectAlertDialog(
      title: Text(l.architectSheetScale),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scaleInput(context, controller),
            const SizedBox(height: 12),
            Text(l.architectSheetScaleHint),
            if (invalid)
              Text(
                l.architectSheetInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed: () {
            final value = int.tryParse(controller.text.trim());
            if (value == null || value <= 0) {
              setState(() => invalid = true);
              return;
            }
            Navigator.pop(context, value);
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
        builder: (c, update) => architectAlertDialog(
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
    return architectAlertDialog(
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
                        icon: const AppIcon(AppIconId.delete),
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
              icon: const AppIcon(AppIconId.add),
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
