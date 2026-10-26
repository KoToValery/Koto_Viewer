import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../services/architect_element_id.dart';
import '../services/architect_roof_drainage_geometry.dart';
import 'architect_roof_number_field.dart';

class ArchitectRoofDrainageEditor extends StatelessWidget {
  final ArchitectRoofDrainage value;
  final ValueChanged<ArchitectRoofDrainage> onChanged;
  final ArchitectProject? project;
  final ArchitectRoofPlane? roof;
  final VoidCallback? onPlace;
  final bool embedded;
  final bool allowInternal;
  const ArchitectRoofDrainageEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.project,
    this.roof,
    this.onPlace,
    this.embedded = false,
    this.allowInternal=false,
  });

  String _status(BuildContext context, ArchitectDownpipe pipe) {
    if (project == null || roof == null) return '';
    final floor = project!.storeys
        .where((s) => s.roofs.any((r) => r.id == roof!.id))
        .firstOrNull;
    if (floor == null) return '';
    final status = ArchitectRoofDrainageGeometry.route(
      project!,
      floor,
      roof!.copyWith(drainage: value),
      pipe,
    ).status;
    final l = context.l10n;
    return switch (status) {
      ArchitectDownpipeStatus.ready => l.architectDrainageReady,
      ArchitectDownpipeStatus.noFacade => l.architectDrainageNoFacade,
      ArchitectDownpipeStatus.blocked => l.architectDrainageBlocked,
      ArchitectDownpipeStatus.outsideEaves => l.architectDrainageOutside,
    };
  }

  Future<void> _edit(BuildContext context, [int? index]) async {
    final pipe = index == null
        ? ArchitectDownpipe(id: ArchitectElementId.next('downpipe'))
        : value.downpipes[index];
    final next = await showDialog<ArchitectDownpipe>(
      context: context,
      builder: (_) => _PipeDialog(pipe: pipe, project: project),
    );
    if (next == null) return;
    final pipes = [...value.downpipes];
    if (index == null) {
      pipes.add(next);
    } else {
      pipes[index] = next;
    }
    onChanged(value.copyWith(downpipes: pipes));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(12),
      children: [
        if(allowInternal)Tooltip(message:l.roofGutterInternalHelp,child:DropdownButtonFormField<ArchitectGutterPosition>(
          key:ValueKey('roof-gutter-position-${value.position.name}'),initialValue:value.position,isExpanded:true,
          decoration:InputDecoration(labelText:l.roofGutterPosition),items:[
            DropdownMenuItem(value:ArchitectGutterPosition.external,child:Text(l.roofGutterExternal)),
            DropdownMenuItem(value:ArchitectGutterPosition.internal,child:Text(l.roofGutterInternal))],
          onChanged:(v){if(v!=null)onChanged(value.copyWith(position:v,profile:v==ArchitectGutterPosition.internal?ArchitectGutterProfile.box:null));})),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l.architectDrainageGutter),
          value: value.showGutter,
          onChanged: (v) => onChanged(value.copyWith(showGutter: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l.architectDrainagePipes),
          value: value.showDownpipes,
          onChanged: (v) => onChanged(value.copyWith(showDownpipes: v)),
        ),
        if(value.position!=ArchitectGutterPosition.internal) DropdownButtonFormField<ArchitectGutterProfile>(
          initialValue: value.profile,
          decoration: InputDecoration(labelText: l.architectDrainageProfile),
          items: [
            for (final p in ArchitectGutterProfile.values)
              DropdownMenuItem(
                value: p,
                child: Text(
                  p == ArchitectGutterProfile.halfRound
                      ? l.architectDrainageHalfRound
                      : l.architectDrainageBox,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(value.copyWith(profile: v));
          },
        ),
        DropdownButtonFormField<ArchitectDrainageMaterial>(
          initialValue: value.material,
          decoration: InputDecoration(labelText: l.architectDrainageMaterial),
          items: [
            for (final m in ArchitectDrainageMaterial.values)
              DropdownMenuItem(
                value: m,
                child: Text(switch (m) {
                  ArchitectDrainageMaterial.galvanizedSteel =>
                    l.architectDrainageSteel,
                  ArchitectDrainageMaterial.aluminium =>
                    l.architectDrainageAluminium,
                  ArchitectDrainageMaterial.pvc => l.architectDrainagePvc,
                  ArchitectDrainageMaterial.copper => l.architectDrainageCopper,
                }),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(value.copyWith(material: v));
          },
        ),
        _Number(
          label: l.architectDrainageWidth,
          value: value.gutterWidth * 100,
          min: 8,
          max: 50,
          unit: 'cm',
          onChanged: (v) => onChanged(value.copyWith(gutterWidth: v / 100)),
        ),
        _Number(
          label: l.architectDrainageDepth,
          value: value.gutterDepth * 100,
          min: 4,
          max: 30,
          unit: 'cm',
          onChanged: (v) => onChanged(value.copyWith(gutterDepth: v / 100)),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < value.downpipes.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(
              value: value.downpipes[i].visible,
              onChanged: (v) {
                final pipes = [...value.downpipes];
                pipes[i] = pipes[i].copyWith(visible: v);
                onChanged(value.copyWith(downpipes: pipes));
              },
            ),
            title: Text('${l.architectDrainagePipe} ${i + 1}'),
            subtitle: Text(_status(context, value.downpipes[i])),
            onTap: () => _edit(context, i),
            trailing: IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                final pipes = [...value.downpipes]..removeAt(i);
                onChanged(value.copyWith(downpipes: pipes));
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: Text(l.architectDrainageAdd),
        ),
        if (onPlace != null)
          OutlinedButton.icon(
            onPressed: onPlace,
            icon: const Icon(Icons.touch_app_outlined),
            label: Text(l.architectDrainagePlace),
          ),
      ],
    );
  }
}

/// Validates each draft field before it can affect persisted geometry.
class _Number extends StatefulWidget {
  final String label, unit;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _Number({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });
  @override
  State<_Number> createState() => _NumberState();
}

class _NumberState extends State<_Number> {
  late final TextEditingController text = TextEditingController(
    text: roofNumber(widget.value),
  );
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      controller: text,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.unit,
      ),
      validator: (s) {
        final v = double.tryParse((s ?? '').replaceAll(',', '.'));
        return v == null || !v.isFinite || v < widget.min || v > widget.max
            ? context.l10n.architectDrainageInvalid
            : null;
      },
      onChanged: (s) {
        final v = double.tryParse(s.replaceAll(',', '.'));
        if (v != null && v.isFinite && v >= widget.min && v <= widget.max) {
          widget.onChanged(v);
        }
      },
    ),
  );
}

class _PipeDialog extends StatefulWidget {
  final ArchitectDownpipe pipe;
  final ArchitectProject? project;
  const _PipeDialog({required this.pipe, this.project});
  @override
  State<_PipeDialog> createState() => _PipeDialogState();
}

class _PipeDialogState extends State<_PipeDialog> {
  late ArchitectDownpipe pipe = widget.pipe;
  final form = GlobalKey<FormState>();
  late final waypoints = TextEditingController(
    text: [
      for (final p in pipe.waypoints)
        '${p.dx.toStringAsFixed(3)}; ${p.dy.toStringAsFixed(3)}',
    ].join('\n'),
  );
  List<Offset>? parseWaypoints(String? text) {
    final result = <Offset>[];
    for (final line
        in (text ?? '').split('\n').where((s) => s.trim().isNotEmpty)) {
      final pair = line
          .split(';')
          .map((s) => double.tryParse(s.trim().replaceAll(',', '.')))
          .toList();
      if (pair.length != 2 || pair.any((n) => n == null || !n.isFinite)) {
        return null;
      }
      result.add(Offset(pair[0]!, pair[1]!));
    }
    return result;
  }

  @override
  void dispose() {
    waypoints.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final walls =
        widget.project?.storeys.expand((s) => s.walls).toList() ??
        <ArchitectWall>[];
    return AlertDialog(
      title: Text(l.architectDrainagePipe),
      content: SizedBox(
        width: 360,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Number(
                  label: l.architectDrainageOffset,
                  value: pipe.offset,
                  min: 0,
                  max: 10000,
                  unit: 'm',
                  onChanged: (v) => pipe = pipe.copyWith(offset: v),
                ),
                _Number(
                  label: l.architectDrainageDiameter,
                  value: pipe.diameter * 100,
                  min: 4,
                  max: 40,
                  unit: 'cm',
                  onChanged: (v) => pipe = pipe.copyWith(diameter: v / 100),
                ),
                _Number(
                  label: l.architectDrainageClearance,
                  value: pipe.wallClearance * 100,
                  min: 1,
                  max: 100,
                  unit: 'cm',
                  onChanged: (v) =>
                      pipe = pipe.copyWith(wallClearance: v / 100),
                ),
                _Number(
                  label: l.architectDrainageOutlet,
                  value: pipe.outletElevation,
                  min: -1000,
                  max: 10000,
                  unit: 'm',
                  onChanged: (v) => pipe = pipe.copyWith(outletElevation: v),
                ),
                DropdownButtonFormField<double>(
                  initialValue: pipe.bendAngle,
                  decoration: InputDecoration(
                    labelText: l.architectDrainageBend,
                  ),
                  items: [
                    for (final a in [45.0, 67.5])
                      DropdownMenuItem(value: a, child: Text('$a°')),
                  ],
                  onChanged: (v) {
                    if (v != null) pipe = pipe.copyWith(bendAngle: v);
                  },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: walls.any((w) => w.id == pipe.facadeWallId)
                      ? pipe.facadeWallId
                      : '',
                  decoration: InputDecoration(
                    labelText: l.architectDrainageFacade,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(l.architectDrainageAuto),
                    ),
                    for (var i = 0; i < walls.length; i++)
                      DropdownMenuItem(
                        value: walls[i].id,
                        child: Text('${l.architectDrainageWall} ${i + 1}'),
                      ),
                  ],
                  onChanged: (v) => pipe = pipe.copyWith(
                    facadeWallId: v,
                    clearFacade: v == '',
                  ),
                ),
                TextFormField(
                  controller: waypoints,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l.architectDrainageWaypoints,
                    helperText: l.architectDrainageWaypointsHelp,
                    helperMaxLines: 4,
                  ),
                  validator: (s) => parseWaypoints(s) == null
                      ? l.architectDrainageInvalid
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(
              context,
              pipe.copyWith(waypoints: parseWaypoints(waypoints.text)!),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
