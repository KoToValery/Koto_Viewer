import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';
import '../models/seismic_slab_load.dart';

class SeismicLoadDialog extends StatefulWidget {
  final StructuralProject project;
  const SeismicLoadDialog({super.key, required this.project});
  @override
  State<SeismicLoadDialog> createState() => _SeismicLoadDialogState();
}

class _LoadDraft {
  final int storey, slab;
  bool enabled;
  final List<TextEditingController> fields;
  _LoadDraft(this.storey, this.slab, this.enabled, SeismicSlabLoad load)
    : fields = [
        load.permanentKnM2,
        load.variableKnM2,
        load.participation,
      ].map((v) => TextEditingController(text: v.toString())).toList();
  SeismicSlabLoad get value {
    double parse(int i) =>
        double.tryParse(fields[i].text.replaceAll(',', '.')) ?? double.nan;
    return SeismicSlabLoad(
      permanentKnM2: parse(0),
      variableKnM2: parse(1),
      participation: parse(2),
    );
  }
}

class _SeismicLoadDialogState extends State<SeismicLoadDialog> {
  late final List<_LoadDraft> drafts;
  int selected = 0;
  bool error = false;
  @override
  void initState() {
    super.initState();
    drafts = [
      for (var s = 0; s < widget.project.storeys.length; s++)
        for (var p = 0; p < widget.project.storeys[s].slabs.length; p++)
          _LoadDraft(
            s,
            p,
            widget.project.storeys[s].slabs[p].seismicLoad != null,
            widget.project.storeys[s].slabs[p].effectiveSeismicLoad(
              widget.project,
            ),
          ),
    ];
  }

  @override
  void dispose() {
    for (final draft in drafts) {
      for (final field in draft.fields) {
        field.dispose();
      }
    }
    super.dispose();
  }

  void apply() {
    for (var i = 0; i < drafts.length; i++) {
      if (drafts[i].enabled && !drafts[i].value.isValid) {
        setState(() {
          selected = i;
          error = true;
        });
        return;
      }
    }
    final storeys = widget.project.storeys.toList();
    for (final draft in drafts) {
      final storey = storeys[draft.storey], slabs = storey.slabs.toList();
      slabs[draft.slab] = slabs[draft.slab].copyWith(
        seismicLoad: draft.enabled ? draft.value : null,
        clearSeismicLoad: !draft.enabled,
      );
      storeys[draft.storey] = storey.copyWith(slabs: slabs);
    }
    Navigator.of(context).pop(widget.project.copyWith(storeys: storeys));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = drafts.isEmpty ? null : drafts[selected];
    final labels = [
      l10n.seismicLoadPermanent,
      l10n.seismicLoadVariable,
      l10n.seismicLoadParticipation,
    ];
    return AlertDialog(
      title: Text(l10n.seismicLoadsTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.seismicLoadsScope),
              const SizedBox(height: 12),
              if (draft == null)
                Text(l10n.seismicNoSlabBadge)
              else ...[
                DropdownButton<int>(
                  isExpanded: true,
                  value: selected,
                  items: [
                    for (var i = 0; i < drafts.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${widget.project.storeys[drafts[i].storey].name} · ${l10n.seismicLoadSlab(drafts[i].slab + 1)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selected = value;
                        error = false;
                      });
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.seismicLoadOverride),
                  value: draft.enabled,
                  onChanged: (v) => setState(() {
                    draft.enabled = v;
                    error = false;
                    if (!v) {
                      final defaults = [widget.project.deadLoadSuperimposed,
                        widget.project.liveLoad, 0.3];
                      for (var i = 0; i < 3; i++) {
                        draft.fields[i].text = defaults[i].toString();
                      }
                    }
                  }),
                ),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      key: ValueKey('seismic-load-$i'),
                      controller: draft.fields[i],
                      enabled: draft.enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: labels[i],
                        suffixText: i < 2 ? 'kN/m²' : null,
                      ),
                    ),
                  ),
                if (error)
                  Text(
                    l10n.seismicInvalidMassLoads,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: draft == null ? null : apply,
          child: Text(l10n.applyAction),
        ),
      ],
    );
  }
}
