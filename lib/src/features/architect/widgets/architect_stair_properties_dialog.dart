import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../rendering/architect_elements_painter_helper.dart';
import '../services/architect_stair_rules.dart';
import 'architect_stair_labels.dart';
import 'architect_stair_section_screen.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectStairPropertiesDialog extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectStair stair;
  final bool Function(ArchitectStair) onApply;
  const ArchitectStairPropertiesDialog({
    super.key,
    required this.project,
    required this.stair,
    required this.onApply,
  });
  @override
  State<ArchitectStairPropertiesDialog> createState() =>
      _StairPropertiesState();
}

class _StairPropertiesState extends State<ArchitectStairPropertiesDialog> {
  late ArchitectStair stair;
  late bool legacy;
  ArchitectStairDesign get d => stair.design!;
  ArchitectUnit get unit => widget.project.units;
  @override
  void initState() {
    super.initState();
    legacy = widget.stair.design == null;
    stair = widget.stair.copyWith(
      design: ArchitectStairRules.resolveDesign(
        widget.project,
        widget.project.activeStorey,
        widget.stair.design ??
            const ArchitectStairDesign(shape: StairShape.straight),
      ),
    );
  }

  void update(ArchitectStairDesign next) {
    try {
      next = ArchitectStairRules.resolveDesign(
        widget.project,
        widget.project.activeStorey,
        next,
      );
      next.validate();
      setState(() => stair = stair.copyWith(design: next));
    } on ArgumentError {
      invalid();
    }
  }

  void invalid() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.stairUnsupported)));

  String length(double value) =>
      '${unit.toUnit(value).toStringAsFixed(unit == ArchitectUnit.meters ? 3 : 1)} ${unit.symbol}';
  Future<void> edit(
    String key,
    String label,
    double value,
    ValueChanged<double> apply, {
    bool metric = true,
    bool integer = false,
    double minimum = .001,
    double maximum = 100,
  }) async {
    var draft = metric ? unit.toUnit(value) : value;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 250,
          child: ArchitectWallDraftingPanel(
            title: label,
            length: draft,
            unit: metric
                ? unit.symbol
                : integer
                ? ''
                : '°',
            minimumLength: metric ? unit.toUnit(minimum) : minimum,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            endLabel: context.l10n.save,
            onLength: (v) => draft = v,
            onEnd: () {
              final number = metric ? unit.fromUnit(draft) : draft;
              if (!number.isFinite ||
                  number < minimum ||
                  number > maximum ||
                  (integer && number != number.roundToDouble())) {
                invalid();
                return;
              }
              Navigator.pop(ctx);
              apply(number);
            },
            onContinue: () {},
            onUnlock: () {},
            onCancel: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  Widget number(
    String key,
    String label,
    double value,
    ValueChanged<double> apply, {
    bool metric = true,
    bool integer = false,
    bool enabled = true,
    double minimum = .001,
    double maximum = 100,
  }) => ListTile(
    key: ValueKey('stair-$key'),
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(
      metric
          ? length(value)
          : integer
          ? '${value.round()}'
          : '${value.toStringAsFixed(0)}°',
    ),
    enabled: enabled,
    onTap: enabled
        ? () => edit(
            key,
            label,
            value,
            apply,
            metric: metric,
            integer: integer,
            minimum: minimum,
            maximum: maximum,
          )
        : null,
  );

  Widget dropdown<T>(
    String key,
    String label,
    T value,
    Iterable<T> options,
    String Function(T) text,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      key: ValueKey('stair-$key-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(text(option), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    ),
  );

  void fit() {
    var next = d.copyWith(
      rulesVersion: d.code == StairCode.bulgaria
          ? ArchitectStairDesign.currentRules
          : d.rulesVersion,
      autoRisers: true,
      autoGoing: true,
      autoWinderSteps: true,
      autoWinderRadius: true,
      isDraft: false,
      landingDepth: d.use == StairUse.outdoorRoute ? 1.5 : 1.2,
    );
    final width = next.code == StairCode.bulgaria
        ? math.max(
            stair.width,
            next.use == StairUse.assembly
                ? 1.6
                : next.isSpiral && next.evacuation == StairEvacuation.over50
                ? 1.5
                : next.accessible ||
                      next.evacuation == StairEvacuation.from16To50
                ? 1.2
                : 1.0,
          )
        : stair.width;
    if (next.isSpiral) {
      final factor = 2 * math.sin(next.anglePerGoing / 2);
      var radius = math.max(.15, next.going / factor - width / 2);
      if (next.code == StairCode.bulgaria) {
        if (next.evacuation == StairEvacuation.from16To50) {
          radius = math.max(radius, .23 / factor - .3);
        }
        if (next.evacuation == StairEvacuation.over50) {
          radius = math.max(radius, math.max(.45, .23 / factor));
        }
      }
      next = next.copyWith(innerRadius: radius);
    }
    next = ArchitectStairRules.resolveDesign(
      widget.project,
      widget.project.activeStorey,
      next,
    );
    try {
      next.validate();
      setState(() {
        stair = stair.copyWith(width: width, design: next);
        legacy = false;
      });
    } on ArgumentError {
      invalid();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final checks = ArchitectStairRules.check(stair);
    final targetMissing =
        d.followStoreys &&
        ArchitectStairRules.linkedRise(
              widget.project,
              widget.project.activeStorey,
              d,
            ) ==
            null;
    if (targetMissing) {
      checks.insert(
        0,
        const StairCheck(StairCheckKind.upperStorey, StairCheckState.error),
      );
    }
    final errors = checks.where((c) => c.state == StairCheckState.error).length;
    final unknown = checks
        .where((c) => c.state == StairCheckState.review)
        .length;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(l.architectProperties),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 136,
                child: CustomPaint(
                  painter: _StairPreview(stair, widget.project),
                ),
              ),
              if (legacy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l.stairLegacy),
                ),
              Row(
                children: [
                  Expanded(
                    child: dropdown(
                      'shape',
                      l.stairShape,
                      d.shape,
                      StairShape.values,
                      (v) => stairShapeLabel(l, v),
                      (v) => update(d.copyWith(shape: v)),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('stair-mirror'),
                    tooltip: d.turnLeft ? l.stairTurnRight : l.stairTurnLeft,
                    onPressed: d.shape == StairShape.straight
                        ? null
                        : () => update(d.copyWith(turnLeft: !d.turnLeft)),
                    icon: Icon(d.turnLeft ? Icons.turn_left : Icons.turn_right),
                  ),
                ],
              ),
              if (d.shape == StairShape.quarterTurn ||
                  d.shape == StairShape.halfTurn)
                Tooltip(
                  message: l.stairWindersHelp,
                  child: SwitchListTile.adaptive(
                    key: const ValueKey('stair-winders'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l.stairWinders),
                    value: d.winderSteps,
                    onChanged: (v) => update(d.copyWith(winderSteps: v)),
                  ),
                ),
              if (d.shape == StairShape.spiralOverlap)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.stairOverlapHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Wrap(
                spacing: 12,
                children: [
                  Tooltip(
                    message: l.stairSmartRailingHelp,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.stairRailing),
                        Switch.adaptive(
                          key: const ValueKey('stair-show-railing'),
                          value: d.showRailing,
                          onChanged: (v) => update(d.copyWith(showRailing: v)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.stairLabel),
                      Switch.adaptive(
                        key: const ValueKey('stair-show-label'),
                        value: d.showLabel,
                        onChanged: (v) => update(d.copyWith(showLabel: v)),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const ValueKey('stair-open-section'),
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text(l.stairSection),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArchitectStairSectionScreen(
                      project: widget.project,
                      stair: stair,
                    ),
                  ),
                ),
              ),
              number(
                'width',
                l.stairClearWidth,
                stair.width,
                (v) => setState(() => stair = stair.copyWith(width: v)),
                maximum: 10,
              ),
              Tooltip(
                message: l.stairHeightModeHelp,
                child: dropdown<bool>(
                  'height-mode',
                  l.stairHeightMode,
                  d.followStoreys,
                  const [true, false],
                  (v) => v ? l.stairFollowStoreys : l.stairHeightManual,
                  (v) => update(d.copyWith(followStoreys: v)),
                ),
              ),
              Tooltip(
                message: l.stairStartOffsetHelp,
                child: number(
                  'start-offset',
                  l.stairStartOffset,
                  d.startOffset,
                  (v) => update(d.copyWith(startOffset: v)),
                  minimum: -100,
                ),
              ),
              number(
                'rise',
                l.stairRise,
                d.rise,
                (v) => update(d.copyWith(rise: v)),
                enabled: !d.followStoreys,
                maximum: 30,
              ),
              if (d.shape == StairShape.spiralOverlap)
                number(
                  'overlap-headroom',
                  l.stairCheckHeadroom,
                  d.overlapHeadroom,
                  (_) {},
                  enabled: false,
                ),
              if (d.followStoreys)
                dropdown<String>(
                  'target',
                  l.stairUpperStorey,
                  targetMissing ? 'missing' : d.upperStoreyId ?? '',
                  [
                    '',
                    for (final floor in widget.project.storeys)
                      if (floor.elevation >
                          widget.project.activeStorey.elevation)
                        floor.id,
                    if (targetMissing) 'missing',
                  ],
                  (id) => id.isEmpty
                      ? l.stairFloorHeight
                      : id == 'missing'
                      ? l.stairCheckUpperStorey
                      : widget.project.storeys
                            .firstWhere((s) => s.id == id)
                            .name,
                  (id) {
                    if (id == 'missing') return;
                    update(
                      ArchitectStairRules.resolveDesign(
                        widget.project,
                        widget.project.activeStorey,
                        d.copyWith(
                          upperStoreyId: id.isEmpty ? null : id,
                          clearUpperStorey: id.isEmpty,
                        ),
                      ),
                    );
                  },
                ),
              dropdown(
                'code',
                l.stairCode,
                d.code,
                StairCode.values,
                (v) => v == StairCode.bulgaria
                    ? l.stairCodeBulgaria
                    : l.stairCodeGeometry,
                (v) => update(d.copyWith(code: v)),
              ),
              if (d.code == StairCode.bulgaria) ...[
                dropdown(
                  'use',
                  l.stairUse,
                  d.use,
                  StairUse.values,
                  (v) => stairUseLabel(l, v),
                  (v) => update(d.copyWith(use: v)),
                ),
                dropdown(
                  'evacuation',
                  l.stairEvacuation,
                  d.evacuation,
                  StairEvacuation.values,
                  (v) => stairEvacuationLabel(l, v),
                  (v) => update(d.copyWith(evacuation: v)),
                ),
              ],
              Tooltip(
                message: l.stairFitHelp,
                child: OutlinedButton.icon(
                  key: const ValueKey('stair-fit'),
                  onPressed: fit,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(l.stairFit),
                ),
              ),
              Text(
                '${d.risers} × ${length(d.riser)} / ${length(d.walkingGoing(stair.width))}',
                textAlign: TextAlign.center,
              ),
              ExpansionTile(
                key: const ValueKey('stair-dimensions'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.stairAdvanced),
                children: [
                  number(
                    'risers',
                    l.stairRisers,
                    d.risers.toDouble(),
                    (v) => update(d.copyWith(manualRisers: v.toInt())),
                    metric: false,
                    integer: true,
                    minimum: 2,
                    maximum: 500,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${l.stairRisers} · ${l.stairAutomatic}'),
                    value: d.manualRisers == null,
                    onChanged: (v) => update(
                      d.copyWith(
                        autoRisers: v,
                        manualRisers: v ? null : d.risers,
                      ),
                    ),
                  ),
                  if (!d.isSpiral) ...[
                    number(
                      'going',
                      l.stairGoing,
                      d.going,
                      (v) => update(d.copyWith(manualGoing: v)),
                      maximum: 2,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${l.stairGoing} · ${l.stairAutomatic}'),
                      value: d.manualGoing == null,
                      onChanged: (v) => update(
                        d.copyWith(
                          autoGoing: v,
                          manualGoing: v ? null : d.going,
                        ),
                      ),
                    ),
                    if (d.hasWinders) ...[
                      Tooltip(
                        message: l.stairWinderCornerHelp,
                        child: dropdown<bool>(
                          'corner',
                          l.stairWinderCorner,
                          d.cornerRiser,
                          const [false, true],
                          (v) => v
                              ? l.stairWinderCornerRiser
                              : l.stairWinderCornerTread,
                          (v) => update(
                            d.copyWith(cornerRiser: v, autoWinderSteps: true),
                          ),
                        ),
                      ),
                      number(
                        'winder-count',
                        l.stairWinderCount,
                        d.winderLayout(stair.width).perQuarter.toDouble(),
                        (v) => update(
                          d.copyWith(
                            manualWinderSteps: v.toInt(),
                            cornerRiser: v.toInt().isEven,
                          ),
                        ),
                        metric: false,
                        integer: true,
                        minimum: 1,
                        maximum: 24,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(l.stairWinderCountAuto),
                        value: d.manualWinderSteps == null,
                        onChanged: (v) => update(
                          d.copyWith(
                            autoWinderSteps: v,
                            manualWinderSteps: v
                                ? null
                                : d.winderLayout(stair.width).perQuarter,
                          ),
                        ),
                      ),
                      number(
                        'winder-radius',
                        l.stairInnerRadius,
                        d.winderLayout(stair.width).radius,
                        (v) => update(d.copyWith(manualWinderRadius: v)),
                        maximum: 20,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(l.stairWinderRadiusAuto),
                        value: d.manualWinderRadius == null,
                        onChanged: (v) => update(
                          d.copyWith(
                            autoWinderRadius: v,
                            manualWinderRadius: v
                                ? null
                                : d.winderLayout(stair.width).radius,
                          ),
                        ),
                      ),
                    ],
                    if (d.flightCount > 1 && !d.hasWinders)
                      number(
                        'landing',
                        l.stairLanding,
                        math.max(stair.width, d.landingDepth),
                        (v) => update(d.copyWith(landingDepth: v)),
                        maximum: 10,
                      ),
                  ] else ...[
                    number(
                      'radius',
                      l.stairInnerRadius,
                      d.innerRadius,
                      (v) => update(d.copyWith(innerRadius: v)),
                      maximum: 20,
                    ),
                    number(
                      'sweep',
                      l.stairSweep,
                      d.sweepDegrees,
                      (v) => update(d.copyWith(sweepDegrees: v)),
                      metric: false,
                      minimum: d.shape == StairShape.spiralOverlap
                          ? 360.001
                          : 30,
                      maximum: d.shape == StairShape.spiralOverlap ? 1080 : 360,
                    ),
                  ],
                  Text(
                    l.stairClearDimensionsHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              ExpansionTile(
                key: const ValueKey('stair-details'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.stairDetails),
                children: [
                  number(
                    'guard-height',
                    l.stairGuardHeight,
                    d.guardHeight,
                    (v) => update(d.copyWith(guardHeight: v)),
                    minimum: .1,
                    maximum: 2,
                  ),
                  number(
                    'handrail-height',
                    l.stairHandrailHeight,
                    d.handrailHeight,
                    (v) => update(d.copyWith(handrailHeight: v)),
                    minimum: .1,
                    maximum: 2,
                  ),
                  number(
                    'concrete',
                    l.stairConcreteThickness,
                    d.concreteThickness,
                    (v) => update(d.copyWith(concreteThickness: v)),
                    minimum: .01,
                    maximum: 1,
                  ),
                  number(
                    'finish',
                    l.stairFinishThickness,
                    d.finishThickness,
                    (v) => update(d.copyWith(finishThickness: v)),
                    minimum: 0,
                    maximum: .15,
                  ),
                  number(
                    'nosing',
                    l.stairNosing,
                    d.nosingProjection,
                    (v) => update(d.copyWith(nosingProjection: v)),
                    minimum: 0,
                    maximum: .1,
                  ),
                  Text(
                    l.stairDetailsHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              ExpansionTile(
                key: ValueKey('stair-checks-$errors'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: errors > 0,
                title: Text('${l.stairChecks} · $errors / $unknown'),
                subtitle: Text('${l.stairCheckError} / ${l.stairCheckReview}'),
                children: [for (final check in checks) checkTile(check)],
              ),
              if (errors > 0 || d.isDraft)
                CheckboxListTile(
                  key: const ValueKey('stair-draft'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.stairDraft),
                  subtitle: Text(l.stairDraftHelp),
                  value: d.isDraft,
                  onChanged: (v) => update(d.copyWith(isDraft: v ?? false)),
                ),
              Text(
                l.stairIncomplete,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (d.code == StairCode.bulgaria)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l.stairRulesSources),
                  children: [
                    TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(ArchitectStairRules.fireSource)),
                      child: Text(l.stairFireSource),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(ArchitectStairRules.accessibilitySource),
                      ),
                      child: Text(l.stairAccessSource),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        KeyedSubtree(
          key: const ValueKey('architect-properties-save'),
          child: FilledButton(
            key: const ValueKey('stair-save'),
            onPressed: legacy || (errors > 0 && !d.isDraft)
                ? null
                : () {
                    if (widget.onApply(stair)) Navigator.pop(context);
                  },
            child: Text(l.save),
          ),
        ),
      ],
    );
  }

  Widget checkTile(StairCheck check) {
    final l = context.l10n;
    String value(double v) => check.kind == StairCheckKind.groupSteps
        ? '${v.round()}'
        : check.kind == StairCheckKind.slope
        ? v.toStringAsFixed(3)
        : length(v);
    final range = [
      if (check.minimum != null) '≥ ${value(check.minimum!)}',
      if (check.maximum != null) '≤ ${value(check.maximum!)}',
    ].join(' · ');
    final color = switch (check.state) {
      StairCheckState.pass => Colors.green,
      StairCheckState.error => Colors.red,
      StairCheckState.advice => Colors.orange,
      StairCheckState.review => Colors.blueGrey,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Tooltip(
        message: stairStateLabel(l, check.state),
        child: Icon(switch (check.state) {
          StairCheckState.pass => Icons.check_circle_outline,
          StairCheckState.error => Icons.error_outline,
          StairCheckState.advice => Icons.info_outline,
          StairCheckState.review => Icons.help_outline,
        }, color: color),
      ),
      title: Text(stairCheckLabel(l, check.kind)),
      subtitle: Text(
        [
          stairStateLabel(l, check.state),
          if (check.actual != null) value(check.actual!),
          if (range.isNotEmpty) range,
          if (check.article != null) check.article!,
        ].join(' · '),
      ),
    );
  }
}

class _StairPreview extends CustomPainter {
  final ArchitectStair stair;
  final ArchitectProject project;
  _StairPreview(this.stair, this.project);
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = stair.plan.bounds.inflate(.2);
    final scale = math.min(
      size.width / math.max(.01, bounds.width),
      size.height / math.max(.01, bounds.height),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    ArchitectElementsPainterHelper.drawStair(
      canvas: canvas,
      stair: stair,
      zoomScale: scale,
      storey: project.activeStorey,
      project: project,
      cutHeight: project.activeStorey.cutPlaneHeight,
      labels: false,
      color: stair.design?.isDraft == true ? Colors.red : Colors.teal,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StairPreview old) =>
      old.stair != stair || old.project != project;
}
