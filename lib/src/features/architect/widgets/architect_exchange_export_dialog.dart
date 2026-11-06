import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_drawing_publisher.dart';
import '../services/architect_dxf_export.dart';
import '../services/architect_ifc_export.dart';
import '../services/architect_sheet_composer.dart';
import 'architect_dialog.dart';

enum ArchitectExchangeFormat { dxfViews, dxfSheets, ifc }

Future<void> showArchitectExchangeExport(
  BuildContext context, {
  required ArchitectProject project,
  required ArchitectExchangeFormat format,
  required List<ArchitectSavedDrawing> drawings,
  ArchitectPublicationSources sources = const ArchitectPublicationSources(),
  String? initialSheetId,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ArchitectExchangeExportDialog(
    project: project,
    format: format,
    drawings: drawings,
    sources: sources,
    initialSheetId: initialSheetId,
  ),
);

/// The captured project is the export snapshot. Editing and camera state never
/// enter an exchange job, and the source project is never modified by export.
class ArchitectExchangeExportDialog extends StatefulWidget {
  const ArchitectExchangeExportDialog({
    super.key,
    required this.project,
    required this.format,
    required this.drawings,
    this.sources = const ArchitectPublicationSources(),
    this.initialSheetId,
  });

  final ArchitectProject project;
  final ArchitectExchangeFormat format;
  final List<ArchitectSavedDrawing> drawings;
  final ArchitectPublicationSources sources;
  final String? initialSheetId;

  @override
  State<ArchitectExchangeExportDialog> createState() => _ExchangeExportState();
}

class _ExchangeExportState extends State<ArchitectExchangeExportDialog> {
  late final drawings = widget.drawings
      .where((d) => ArchitectDrawingPublisher.hasSource(widget.project, d))
      .toList();
  late final chosen = <String>{
    if (widget.format == ArchitectExchangeFormat.dxfViews)
      ...drawings.map((d) => d.id)
    else if (widget.initialSheetId != null)
      widget.initialSheetId!
    else
      ...widget.project.document.sheets.map((s) => s.id),
  };
  ArchitectIfcSchema schema = ArchitectIfcSchema.ifc2x3;
  bool busy = false, cancelled = false;
  double progress = 0;
  String? error;

  String title(AppLocalizations l) => switch (widget.format) {
    ArchitectExchangeFormat.dxfViews => l.architectExportDxfViews,
    ArchitectExchangeFormat.dxfSheets => l.architectExportDxfSheets,
    ArchitectExchangeFormat.ifc => l.architectExportIfc,
  };

  bool get isCancelled => cancelled || !mounted;
  void updateProgress(double value) {
    if (!mounted || cancelled || (progress - value).abs() < .01) return;
    setState(() => progress = value.clamp(0.0, 1.0));
  }

  Future<bool> save(String name, Uint8List bytes) async {
    architectCheckExportCancelled(() => isCancelled);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: context.l10n.architectExportTitle,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [name.split('.').last],
      bytes: bytes,
    );
    if (path == null || isCancelled) return false;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  Future<void> run() async {
    final l = context.l10n;
    setState(() {
      busy = true;
      cancelled = false;
      progress = 0;
      error = null;
    });
    try {
      final name = widget.project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      ArchitectIfcExportResult? report;
      Map<String, Uint8List> files;
      switch (widget.format) {
        case ArchitectExchangeFormat.dxfViews:
          files = await ArchitectDxfExport.exportViews(
            widget.project,
            drawings.where((d) => chosen.contains(d.id)).toList(),
            l,
            sources: widget.sources,
            onProgress: updateProgress,
            isCancelled: () => isCancelled,
          );
        case ArchitectExchangeFormat.dxfSheets:
          final sheets = widget.project.document.sheets
              .where((s) => chosen.contains(s.id))
              .toList();
          final problems = [
            for (final sheet in sheets)
              ...ArchitectSheetComposer.issues(widget.project, sheet, l),
          ];
          if (problems.isNotEmpty) {
            setState(() => error = problems.toSet().join('\n'));
            return;
          }
          files = await ArchitectDxfExport.exportSheets(
            widget.project,
            sheets,
            l,
            sources: widget.sources,
            onProgress: updateProgress,
            isCancelled: () => isCancelled,
          );
        case ArchitectExchangeFormat.ifc:
          report = await ArchitectIfcExport.exportProject(
            widget.project,
            l,
            schema: schema,
            onProgress: updateProgress,
            isCancelled: () => isCancelled,
          );
          files = {
            '${name.isEmpty ? widget.project.id : name}.ifc': report.bytes,
          };
      }
      architectCheckExportCancelled(() => isCancelled);
      if (files.isEmpty) throw StateError('Empty exchange result');
      final outputName = files.length == 1
          ? files.keys.single
          : '${name.isEmpty ? widget.project.id : name}.zip';
      final bytes = files.length == 1
          ? files.values.single
          : await compute(_zipExports, files);
      final saved = await save(outputName, bytes);
      if (!mounted || isCancelled || !saved) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      if (report != null) {
        await _showReport(navigator.context, report, l);
      }
    } on ArchitectExportCancelled {
      if (mounted) Navigator.pop(context);
    } on ArchitectExportElementError catch (e) {
      if (mounted) {
        setState(() => error = l.architectExportElementFailed(e.elementId));
      }
    } catch (_) {
      if (mounted) setState(() => error = l.architectExportFailed);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showReport(
    BuildContext host,
    ArchitectIfcExportResult result,
    AppLocalizations l,
  ) {
    // Use the navigator's surviving context after closing the export route.
    return showDialog<void>(
      context: host,
      builder: (c) => architectAlertDialog(
        title: Text(l.architectExportReport),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.architectExportIfcReport(
                result.parametricCount,
                result.fallbackCount,
              ),
            ),
            for (final notice in result.notices)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${notice.elementId}: ${switch (notice.code) {
                    'proxy' => l.architectExportProxy,
                    'surfaceFallback' => l.architectExportSurfaceFallback,
                    'missingGeometry' => l.architectExportMissingGeometry,
                    'unhostedOpening' => l.architectExportUnhostedOpening,
                    _ => l.architectExportFallback,
                  }}',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.close)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isIfc = widget.format == ArchitectExchangeFormat.ifc;
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) setState(() => cancelled = true);
      },
      child: architectAlertDialog(
        title: Text(title(l)),
        content: SizedBox(
          width: 440,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    Text(l.architectExportPreparing),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                    ),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).round()}%'),
                  ] else if (isIfc) ...[
                    DropdownButtonFormField<ArchitectIfcSchema>(
                      key: const ValueKey('architect-export-ifc-schema'),
                      initialValue: schema,
                      decoration: InputDecoration(
                        labelText: l.architectExportIfcSchema,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ArchitectIfcSchema.ifc2x3,
                          child: Text('IFC2x3'),
                        ),
                        DropdownMenuItem(
                          value: ArchitectIfcSchema.ifc4,
                          child: Text('IFC4'),
                        ),
                      ],
                      onChanged: (value) => setState(() => schema = value!),
                    ),
                    const SizedBox(height: 12),
                    Text(l.architectExportIfcHint),
                  ] else if (widget.format == ArchitectExchangeFormat.dxfViews)
                    for (final drawing in drawings)
                      CheckboxListTile(
                        key: ValueKey('architect-export-view-${drawing.id}'),
                        title: Text(
                          ArchitectSheetComposer.drawingName(drawing, l),
                        ),
                        value: chosen.contains(drawing.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            chosen.add(drawing.id);
                          } else {
                            chosen.remove(drawing.id);
                          }
                        }),
                      )
                  else
                    for (final sheet in widget.project.document.sheets)
                      CheckboxListTile(
                        key: ValueKey('architect-export-sheet-${sheet.id}'),
                        title: Text(
                          '${sheet.number} · ${ArchitectSheetComposer.sheetName(sheet, l)}',
                        ),
                        value: chosen.contains(sheet.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            chosen.add(sheet.id);
                          } else {
                            chosen.remove(sheet.id);
                          }
                        }),
                      ),
                  if (!busy && !isIfc && chosen.isEmpty)
                    Text(l.architectSheetNoViews),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('architect-export-cancel'),
            onPressed: () {
              if (busy) {
                setState(() => cancelled = true);
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(l.cancel),
          ),
          if (!busy)
            FilledButton(
              key: const ValueKey('architect-export-run'),
              onPressed: isIfc || chosen.isNotEmpty ? run : null,
              child: Text(l.architectExportRun),
            ),
        ],
      ),
    );
  }
}

Uint8List _zipExports(Map<String, Uint8List> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    if (entry.key.contains('/') ||
        entry.key.contains('\\') ||
        entry.key == '..' ||
        entry.key == '.' ||
        entry.key.contains(':')) {
      throw ArgumentError('Invalid exchange archive filename');
    }
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
