import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';

// === SECTION: INDEX ===
// === SECTION: CONCRETE PRESETS ===
// === SECTION: PARAMETERS SHEET ===

// === SECTION: CONCRETE PRESETS ===

const _concretePresets = <(String, double)>[
  ('C20/25', 30000.0),
  ('C25/30', 31000.0),
  ('C30/37', 33000.0),
  ('C35/45', 34000.0),
];

/// Common Bulgarian & European reference accelerations a_gR (as fraction of g).
const _agPresets = <double>[0.10, 0.15, 0.23, 0.27, 0.32];

// === SECTION: PARAMETERS SHEET ===

/// Mobile-first bottom sheet for entering project-wide seismic & load inputs
/// once per project.
class ProjectDesignParametersSheet extends StatefulWidget {
  final StructuralProject project;
  final ValueChanged<StructuralProject> onApply;

  const ProjectDesignParametersSheet({
    super.key,
    required this.project,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required StructuralProject project,
    required ValueChanged<StructuralProject> onApply,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ProjectDesignParametersSheet(
      project: project,
      onApply: (updated) {
        Navigator.of(ctx).pop();
        onApply(updated);
      },
    ),
  );

  @override
  State<ProjectDesignParametersSheet> createState() =>
      _ProjectDesignParametersSheetState();
}

class _ProjectDesignParametersSheetState
    extends State<ProjectDesignParametersSheet> {
  late double? _agR;
  late SeismicSoilType _soil;
  late SeismicImportanceClass _importance;
  late SeismicSystemKind? _systemOverride;
  late DriftDamageCategory _driftCategory;
  late String _concreteGrade;
  late double _concreteE;

  late final TextEditingController _agCtrl;
  late final TextEditingController _deadCtrl;
  late final TextEditingController _liveCtrl;
  late final TextEditingController _facadeCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.project.designParameters ?? const ProjectDesignParameters();
    _agR = p.agR;
    _soil = p.soilType;
    _importance = p.importanceClass;
    _systemOverride = p.systemOverride;
    _driftCategory = p.driftCategory;
    _concreteGrade = widget.project.concreteGrade;
    _concreteE = widget.project.concreteE;

    _agCtrl = TextEditingController(
      text: _agR == null ? '' : _agR!.toStringAsFixed(2),
    );
    _deadCtrl = TextEditingController(
      text: widget.project.deadLoadSuperimposed.toStringAsFixed(2),
    );
    _liveCtrl = TextEditingController(
      text: widget.project.liveLoad.toStringAsFixed(2),
    );
    _facadeCtrl = TextEditingController(
      text: widget.project.facadeWallLoad.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _agCtrl.dispose();
    _deadCtrl.dispose();
    _liveCtrl.dispose();
    _facadeCtrl.dispose();
    super.dispose();
  }

  double? _parseNumber(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    return v != null && v.isFinite ? v : null;
  }

  void _apply() {
    final parsedAg = _agCtrl.text.trim().isEmpty
        ? null
        : _parseNumber(_agCtrl.text);
    final validAg = parsedAg != null && parsedAg > 0 && parsedAg <= 1.5
        ? parsedAg
        : null;
    final dead = _parseNumber(_deadCtrl.text) ?? widget.project.deadLoadSuperimposed;
    final live = _parseNumber(_liveCtrl.text) ?? widget.project.liveLoad;
    final facade = _parseNumber(_facadeCtrl.text) ?? widget.project.facadeWallLoad;

    final nextParams = ProjectDesignParameters(
      agR: validAg,
      soilType: _soil,
      importanceClass: _importance,
      systemOverride: _systemOverride,
      driftCategory: _driftCategory,
    );

    widget.onApply(
      widget.project.copyWith(
        concreteGrade: _concreteGrade,
        concreteE: _concreteE,
        deadLoadSuperimposed: dead.clamp(0.0, 30.0),
        liveLoad: live.clamp(0.0, 30.0),
        facadeWallLoad: facade.clamp(0.0, 50.0),
        designParameters: nextParams,
      ),
    );
  }

  String _soilTooltip(AppLocalizations l10n, SeismicSoilType s) => switch (s) {
    SeismicSoilType.a => l10n.designParamsSoilTooltipA,
    SeismicSoilType.b => l10n.designParamsSoilTooltipB,
    SeismicSoilType.c => l10n.designParamsSoilTooltipC,
    SeismicSoilType.d => l10n.designParamsSoilTooltipD,
    SeismicSoilType.e => l10n.designParamsSoilTooltipE,
  };

  String _systemLabel(AppLocalizations l10n, SeismicSystemKind? s) =>
      switch (s) {
        null => l10n.designParamsSystemAuto,
        SeismicSystemKind.wall => l10n.designParamsSystemWall,
        SeismicSystemKind.frame => l10n.designParamsSystemFrame,
        SeismicSystemKind.dual => l10n.designParamsSystemDual,
        SeismicSystemKind.lowDuctility => l10n.designParamsSystemLow,
      };

  String _driftLabel(AppLocalizations l10n, DriftDamageCategory d) =>
      switch (d) {
        DriftDamageCategory.brittle => l10n.designParamsDriftBrittle,
        DriftDamageCategory.ductile => l10n.designParamsDriftDuctile,
        DriftDamageCategory.nonInterfering => l10n.designParamsDriftFree,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final previewParams = ProjectDesignParameters(
      agR: _agR,
      soilType: _soil,
      importanceClass: _importance,
      systemOverride: _systemOverride,
      driftCategory: _driftCategory,
    );
    final resolvedQ = (_systemOverride ?? SeismicSystemKind.wall).defaultQ;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1E24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.designParamsTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      l10n.designParamsApply,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(l10n.designParamsSeismicSection),
                      const SizedBox(height: 6),
                      Text(
                        l10n.designParamsAgLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _choiceChip(
                            label: l10n.designParamsAgNotSet,
                            selected: _agR == null,
                            onTap: () => setState(() {
                              _agR = null;
                              _agCtrl.text = '';
                            }),
                          ),
                          for (final g in _agPresets)
                            _choiceChip(
                              label: '${g.toStringAsFixed(2)}g',
                              selected:
                                  _agR != null && (_agR! - g).abs() < 1e-4,
                              onTap: () => setState(() {
                                _agR = g;
                                _agCtrl.text = g.toStringAsFixed(2);
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 140,
                        child: _numberField(
                          controller: _agCtrl,
                          label: l10n.designParamsAgCustom,
                          onChanged: (v) => setState(() {
                            final n = _parseNumber(v);
                            _agR = (n != null && n > 0 && n <= 1.5) ? n : null;
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.designParamsSoilLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in SeismicSoilType.values)
                            Tooltip(
                              message: _soilTooltip(l10n, s),
                              child: _choiceChip(
                                label: s.code,
                                selected: _soil == s,
                                onTap: () => setState(() => _soil = s),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.designParamsImportanceLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in SeismicImportanceClass.values)
                            _choiceChip(
                              label: '${c.roman} (${c.gammaI.toStringAsFixed(1)})',
                              selected: _importance == c,
                              onTap: () => setState(() => _importance = c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.designParamsSystemLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in <SeismicSystemKind?>[
                            null,
                            ...SeismicSystemKind.values,
                          ])
                            _choiceChip(
                              label: _systemLabel(l10n, s),
                              selected: _systemOverride == s,
                              onTap: () => setState(() => _systemOverride = s),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.designParamsDriftLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in DriftDamageCategory.values)
                            _choiceChip(
                              label: _driftLabel(l10n, d),
                              selected: _driftCategory == d,
                              onTap: () => setState(() => _driftCategory = d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.designParamsSpectrumSource(
                          previewParams.spectrum.source,
                          resolvedQ.toStringAsFixed(1),
                        ),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 22),
                      _sectionHeader(l10n.designParamsMaterialsSection),
                      const SizedBox(height: 6),
                      Text(
                        l10n.designParamsConcreteLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (grade, e) in _concretePresets)
                            _choiceChip(
                              label: grade,
                              selected: _concreteGrade == grade,
                              onTap: () => setState(() {
                                _concreteGrade = grade;
                                _concreteE = e;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _numberField(
                              controller: _deadCtrl,
                              label: l10n.designParamsDeadLabel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _numberField(
                              controller: _liveCtrl,
                              label: l10n.designParamsLiveLabel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _numberField(
                              controller: _facadeCtrl,
                              label: l10n.designParamsFacadeLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.checkPreliminary,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF00E5FF),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0x3300E5FF) : const Color(0xFF282B34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF00E5FF) : Colors.white24,
          width: selected ? 1.4 : 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF00E5FF) : Colors.white,
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ),
  );

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF282B34),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
      ),
    ),
  );
}
