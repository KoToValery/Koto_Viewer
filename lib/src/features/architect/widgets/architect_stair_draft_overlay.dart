import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../rendering/architect_stair_plan_painter.dart';
import '../services/architect_properties_session.dart';
import '../services/architect_stair_draft_controller.dart';
import '../services/architect_stair_layout_resolver.dart';
import '../services/architect_stair_rules.dart';
import 'architect_canvas_hint.dart';
import 'architect_property_number_field.dart';
import 'architect_stair_labels.dart';

String stairLayoutProblemLabel(
  AppLocalizations l,
  StairLayoutProblem problem,
) => switch (problem) {
  StairLayoutProblem.polygon => l.stairLayoutPolygonError,
  StairLayoutProblem.connection => l.stairLayoutConnectionError,
  StairLayoutProblem.cell => l.stairLayoutCellError,
  StairLayoutProblem.length => l.stairLayoutLengthError,
  StairLayoutProblem.total => l.stairLayoutTotalError,
  StairLayoutProblem.collision => l.stairLayoutCollisionError,
  StairLayoutProblem.clearance => l.stairLayoutClearanceError,
};

class ArchitectStairDraftOverlay extends StatelessWidget {
  final ArchitectStairDraftController draft;
  final ArchitectProject project;
  final Offset Function(Offset) toScreen, toModel;
  final double scale;
  final bool darkCanvas;
  final VoidCallback onApply, onCancel, onProperties;
  static final _checks = Expando<List<StairCheck>>();
  const ArchitectStairDraftOverlay({
    super.key,
    required this.draft,
    required this.project,
    required this.toScreen,
    required this.toModel,
    required this.scale,
    required this.onApply,
    required this.onCancel,
    required this.onProperties,
    this.darkCanvas = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, colors = Theme.of(context).colorScheme;
    final preview = draft.preview;
    List<StairCheck> checks = [];
    try {
      if (preview != null && draft.complete) {
        preview.design!.validate();
        checks = _checks[preview] ??= ArchitectStairRules.check(
          preview,
          project: project,
          storey: project.activeStorey,
        );
      }
    } on ArgumentError {
      /* An invalid edit stays visible until corrected. */
    }
    final issues = draft.issues;
    if (preview?.design?.followStoreys == true &&
        ArchitectStairRules.linkedRise(
              project,
              project.activeStorey,
              preview!.design!,
            ) ==
            null) {
      checks = [
        ...checks,
        const StairCheck(StairCheckKind.upperStorey, StairCheckState.error),
      ];
    }
    final errors = checks
        .where((c) => c.state == StairCheckState.error)
        .toList();
    var valid = false;
    try {
      preview?.design?.validate();
      valid = preview != null;
    } on ArgumentError {
      valid = false;
    }
    final canApply =
        valid &&
        draft.complete &&
        issues.isEmpty &&
        draft.fitCandidate == null &&
        (errors.isEmpty || preview!.design!.isDraft);
    final hint = switch (draft.mode) {
      StairDraftMode.flight =>
        draft.start == null ? l.stairPickStart : l.stairPickEnd,
      StairDraftMode.cell => l.stairDrawCell,
      StairDraftMode.landing => l.stairDrawLanding,
      StairDraftMode.edit => l.stairEditHint,
    };
    Widget action(
      String key,
      String label,
      IconData icon,
      VoidCallback? callback,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: label,
      icon: Icon(icon, size: 20),
      onPressed: callback,
    );
    String part(String id) {
      if (id == 'cell') return l.stairCell;
      final f = draft.layout.flights.indexWhere((f) => f.id == id);
      return f >= 0
          ? l.stairFlightNumber(f + 1)
          : l.stairLandingNumber(
              draft.layout.landings.indexWhere((p) => p.id == id) + 1,
            );
    }

    final problem = draft.inputProblem ?? issues.firstOrNull?.problem;
    final issue = issues.firstOrNull;
    final headroom = checks
        .where((c) => c.kind == StairCheckKind.headroom)
        .firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DraftPainter(
                draft,
                toScreen,
                scale,
                darkCanvas,
                l,
                project,
              ),
            ),
          ),
        ),
        if (draft.mode == StairDraftMode.edit && draft.fitCandidate == null)
          ..._grips(context),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: colors.surface,
                elevation: 1,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        key: const ValueKey('stair-draft-part'),
                        isExpanded: true,
                        hint: Text(l.stairCustom),
                        value:
                            [
                              ...draft.layout.flights.map((f) => f.id),
                              ...draft.layout.landings.map((p) => p.id),
                              if (draft.layout.cell.isNotEmpty) 'cell',
                            ].contains(draft.selectedId)
                            ? draft.selectedId
                            : null,
                        items: [
                          for (final id in [
                            ...draft.layout.flights.map((f) => f.id),
                            ...draft.layout.landings.map((p) => p.id),
                            if (draft.layout.cell.isNotEmpty) 'cell',
                          ])
                            DropdownMenuItem(value: id, child: Text(part(id))),
                        ],
                        onChanged: (id) {
                          if (id != null) draft.select(id);
                        },
                      ),
                    ),
                    action(
                      'stair-draft-part-properties',
                      l.architectProperties,
                      Icons.tune,
                      draft.selectedFlight == null &&
                              draft.selectedPolygon.isEmpty
                          ? onProperties
                          : () => _editPart(context),
                    ),
                    action(
                      'stair-draft-levels',
                      l.stairHeightMode,
                      Icons.layers_outlined,
                      onProperties,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Tooltip(
                message: l.stairEditHelp,
                child: ArchitectCanvasHint(
                  message: draft.fitCandidate != null
                      ? l.stairFitProposal
                      : hint,
                ),
              ),
              if (preview != null)
                ArchitectCanvasHint(
                  message:
                      '${preview.design!.risers} × ${project.formatLength(preview.design!.riser)} / '
                      '${project.formatLength(preview.design!.going)}',
                ),
              if (problem != null)
                ArchitectCanvasHint(
                  message:
                      '${issue != null && issue.partId.isNotEmpty ? '${part(issue.partId)}: ' : ''}'
                      '${stairLayoutProblemLabel(l, problem)}'
                      '${issue?.suggestedRun == null ? '' : '\n${l.stairSuggestedRun(project.formatLength(issue!.suggestedRun!))}'}',
                ),
              if (problem == null && errors.isNotEmpty)
                ArchitectCanvasHint(
                  message:
                      '${stairCheckLabel(l, errors.first.kind)}: '
                      '${stairStateLabel(l, errors.first.state)}',
                ),
              if (headroom != null)
                Tooltip(
                  message: l.stairHeadroomModelHelp,
                  child: ArchitectCanvasHint(
                    message:
                        '${l.stairCheckHeadroom}: '
                        '${headroom.actual == null ? stairStateLabel(l, headroom.state) : project.formatLength(headroom.actual!)}',
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Material(
            color: colors.surface,
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  action(
                    'stair-draft-flight',
                    l.stairFlight,
                    Icons.stairs_outlined,
                    draft.fitCandidate != null ? null : draft.beginFlight,
                  ),
                  action(
                    'stair-draft-landing',
                    l.stairLanding,
                    Icons.crop_square,
                    draft.layout.flights.isEmpty ? null : draft.addLanding,
                  ),
                  action(
                    'stair-draft-cell',
                    l.stairCell,
                    Icons.polyline_outlined,
                    () => draft.beginPolygon(cell: true),
                  ),
                  if (draft.mode == StairDraftMode.cell ||
                      draft.mode == StairDraftMode.landing)
                    action(
                      'stair-draft-close',
                      l.stairCloseContour,
                      Icons.done_all,
                      draft.points.length >= 3 ? draft.finishPolygon : null,
                    ),
                  action(
                    'stair-draft-undo',
                    l.undoAction,
                    Icons.undo,
                    draft.canUndo ? draft.undo : null,
                  ),
                  action(
                    'stair-draft-fit',
                    l.stairFit,
                    Icons.auto_fix_high,
                    draft.complete ? draft.proposeFit : null,
                  ),
                  if (draft.fitCandidate != null) ...[
                    action(
                      'stair-draft-accept-fit',
                      l.stairAcceptFit,
                      Icons.playlist_add_check,
                      draft.acceptFit,
                    ),
                    action(
                      'stair-draft-reject-fit',
                      l.cancel,
                      Icons.undo,
                      draft.rejectFit,
                    ),
                  ],
                  action(
                    'stair-draft-apply',
                    l.applyAction,
                    Icons.check,
                    canApply ? onApply : null,
                  ),
                  action('stair-draft-cancel', l.cancel, Icons.close, onCancel),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _grips(BuildContext context) {
    Widget grip(
      String key,
      Offset local,
      ValueChanged<Offset> move, {
      VoidCallback? tap,
      VoidCallback? hold,
      bool square = false,
    }) {
      final p = toScreen(draft.toWorld(local));
      return Positioned(
        left: p.dx - 22,
        top: p.dy - 22,
        width: 44,
        height: 44,
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          onLongPress: hold,
          onPanStart: (_) => draft.beginGesture(),
          onPanUpdate: (d) =>
              move(toModel(toScreen(draft.toWorld(local)) + d.delta)),
          onPanEnd: (_) => draft.endGesture(),
          onPanCancel: draft.endGesture,
          child: Center(
            child: Container(
              width: square ? 9 : 12,
              height: square ? 9 : 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: square ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    final result = <Widget>[];
    final polygon = draft.selectedPolygon;
    for (var i = 0; i < polygon.length; i++) {
      result.add(
        grip(
          'stair-grip-vertex-$i',
          polygon[i],
          (p) => draft.moveVertex(i, p),
          tap: () => _editVertex(context, i),
          hold: () => draft.removeVertex(i),
        ),
      );
      final mid = (polygon[i] + polygon[(i + 1) % polygon.length]) / 2;
      result.add(
        grip(
          'stair-grip-edge-$i',
          mid,
          (p) => draft.moveEdge(i, p - draft.toWorld(mid)),
          square: true,
          tap: () => _editEdge(context, i),
        ),
      );
    }
    final f = draft.selectedFlight;
    if (f != null) {
      result.add(
        grip(
          'stair-grip-start',
          f.origin,
          (p) => draft.updateFlight(
            f.copyWith(origin: draft.toLocal(p)),
            remember: false,
          ),
          tap: () => _editPart(context),
        ),
      );
      result.add(
        grip('stair-grip-end', f.end(draft.design.going), (p) {
          final delta = draft.toLocal(p) - f.origin;
          if (delta.distance < .01 || f.fixedRun != null || f.countLocked)
            return;
          draft.updateFlight(
            f.copyWith(
              axis: delta / delta.distance,
              risers: math.max(
                2,
                (delta.distance / draft.design.going).round() + 1,
              ),
            ),
            remember: false,
          );
        }, tap: () => _editPart(context)),
      );
      final widthPoint =
          (f.origin + f.end(draft.design.going)) / 2 + f.normal * f.width / 2;
      result.add(
        grip(
          'stair-grip-width',
          widthPoint,
          (p) {
            final delta =
                draft.toLocal(p) - (f.origin + f.end(draft.design.going)) / 2;
            final width =
                2 * (delta.dx * f.normal.dx + delta.dy * f.normal.dy).abs();
            if (width > .05)
              draft.updateFlight(f.copyWith(width: width), remember: false);
          },
          square: true,
          tap: () => _editPart(context),
        ),
      );
    }
    return result;
  }

  Future<void> _editVertex(BuildContext context, int index) async {
    final l = context.l10n;
    draft.beginGesture();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.stairContour),
        content: SizedBox(
          width: 260,
          child: AnimatedBuilder(
            animation: draft,
            builder: (context, _) {
              final p = draft.toWorld(draft.selectedPolygon[index]);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final x in [true, false])
                    ArchitectPropertyNumberField(
                      key: ValueKey('stair-vertex-${x ? 'x' : 'y'}'),
                      project: project,
                      label: x ? 'X' : 'Y',
                      value: x ? p.dx : p.dy,
                      descriptor: const ArchitectPropertyDescriptor(
                        'coordinate',
                        minimum: -1e6,
                        maximum: 1e6,
                      ),
                      onChanged: (v) => draft.moveVertex(
                        index,
                        x ? Offset(v, p.dy) : Offset(p.dx, v),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.save)),
        ],
      ),
    );
    draft.endGesture();
  }

  Future<void> _editEdge(BuildContext context, int index) async {
    final l = context.l10n;
    draft.beginGesture();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.stairContour),
        content: SizedBox(
          width: 260,
          child: AnimatedBuilder(
            animation: draft,
            builder: (context, _) {
              final polygon = draft.selectedPolygon;
              final a = polygon[index], next = (index + 1) % polygon.length;
              final delta = polygon[next] - a;
              return ArchitectPropertyNumberField(
                key: const ValueKey('stair-edge-length'),
                project: project,
                label: l.stairRun,
                value: delta.distance,
                descriptor: const ArchitectPropertyDescriptor(
                  'edgeLength',
                  maximum: 100,
                ),
                onChanged: (v) {
                  if (delta.distance > 1e-8)
                    draft.moveVertex(
                      next,
                      draft.toWorld(a + delta / delta.distance * v),
                    );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              draft.insertVertex(index);
            },
            child: Text(l.stairInsertVertex),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.save)),
        ],
      ),
    );
    draft.endGesture();
  }

  Future<void> _editPart(BuildContext context) async {
    final l = context.l10n;
    final id = draft.selectedId;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.architectProperties),
        content: SizedBox(
          width: 300,
          child: AnimatedBuilder(
            animation: draft,
            builder: (context, _) {
              final f = draft.selectedFlight;
              final worldAxis = f == null
                  ? const Offset(1, 0)
                  : draft.toWorld(f.origin + f.axis) - draft.toWorld(f.origin);
              Widget number(
                String key,
                String label,
                double value,
                ValueChanged<double> change, {
                ArchitectPropertyMeasure measure =
                    ArchitectPropertyMeasure.length,
                double minimum = .001,
                double maximum = 100,
              }) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ArchitectPropertyNumberField(
                  key: ValueKey('stair-part-$key'),
                  project: project,
                  label: label,
                  value: value,
                  descriptor: ArchitectPropertyDescriptor(
                    key,
                    measure: measure,
                    minimum: minimum,
                    maximum: maximum,
                  ),
                  onChanged: change,
                ),
              );
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f != null) ...[
                      number(
                        'x',
                        'X',
                        draft.toWorld(f.origin).dx,
                        (v) => draft.updateFlight(
                          f.copyWith(
                            origin: draft.toLocal(
                              Offset(v, draft.toWorld(f.origin).dy),
                            ),
                          ),
                        ),
                        minimum: -1e6,
                        maximum: 1e6,
                      ),
                      number(
                        'y',
                        'Y',
                        draft.toWorld(f.origin).dy,
                        (v) => draft.updateFlight(
                          f.copyWith(
                            origin: draft.toLocal(
                              Offset(draft.toWorld(f.origin).dx, v),
                            ),
                          ),
                        ),
                        minimum: -1e6,
                        maximum: 1e6,
                      ),
                      number(
                        'width',
                        l.stairClearWidth,
                        f.width,
                        (v) => draft.updateFlight(f.copyWith(width: v)),
                        maximum: 10,
                      ),
                      number(
                        'run',
                        l.stairRun,
                        f.fixedRun ?? f.run(draft.design.going),
                        draft.setRun,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.stairLockRun),
                        value: f.fixedRun != null,
                        onChanged: (v) => draft.updateFlight(
                          f.copyWith(
                            fixedRun: v ? f.run(draft.design.going) : null,
                            clearFixedRun: !v,
                          ),
                        ),
                      ),
                      number(
                        'risers',
                        l.stairRisers,
                        f.risers.toDouble(),
                        (v) => draft.updateFlight(
                          f.copyWith(risers: v.toInt(), countLocked: true),
                        ),
                        measure: ArchitectPropertyMeasure.count,
                        minimum: 2,
                        maximum: 500,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.stairLockCount),
                        value: f.countLocked,
                        onChanged: (v) =>
                            draft.updateFlight(f.copyWith(countLocked: v)),
                      ),
                      number(
                        'direction',
                        l.stairDirection,
                        math.atan2(worldAxis.dy, worldAxis.dx) * 180 / math.pi,
                        (v) => draft.updateFlight(
                          f.copyWith(
                            axis:
                                draft.toLocal(
                                  draft.toWorld(f.origin) +
                                      Offset(
                                        math.cos(v * math.pi / 180),
                                        math.sin(v * math.pi / 180),
                                      ),
                                ) -
                                f.origin,
                          ),
                        ),
                        measure: ArchitectPropertyMeasure.angle,
                        minimum: -360,
                        maximum: 360,
                      ),
                    ],
                    number(
                      'going',
                      l.stairGoing,
                      draft.design.going,
                      (v) => draft.setGoing(v, locked: true),
                      maximum: 2,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.stairLockGoing),
                      value: draft.layout.goingLocked,
                      onChanged: (v) =>
                          draft.setGoing(draft.design.going, locked: v),
                    ),
                    if (draft.selectedPolygon.isNotEmpty)
                      OutlinedButton(
                        key: const ValueKey('stair-part-redraw'),
                        child: Text(l.stairContour),
                        onPressed: () {
                          Navigator.pop(ctx);
                          draft.beginPolygon(cell: id == 'cell');
                        },
                      ),
                    if (draft.layout.flights.isNotEmpty)
                      TextButton(
                        child: Text(l.deletePrevious),
                        onPressed: () {
                          Navigator.pop(ctx);
                          draft.removeLastPart();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.save)),
        ],
      ),
    );
  }
}

class _DraftPainter extends CustomPainter {
  final ArchitectStairDraftController draft;
  final Offset Function(Offset) toScreen;
  final double scale;
  final bool dark;
  final AppLocalizations l;
  final ArchitectProject project;
  _DraftPainter(
    this.draft,
    this.toScreen,
    this.scale,
    this.dark,
    this.l,
    this.project,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final color = dark ? Colors.white : Colors.black87;
    void polygon(List<Offset> points, {bool closed = true, double width = 1}) {
      if (points.isEmpty) return;
      final p = Path()
        ..addPolygon(
          points.map((p) => toScreen(draft.toWorld(p))).toList(),
          closed,
        );
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..style = PaintingStyle.stroke,
      );
    }

    final stair = draft.preview;
    var painted = false;
    if (stair != null) {
      var saved = false;
      try {
        stair.design!.validate();
        canvas.save();
        saved = true;
        final zero = toScreen(Offset.zero);
        canvas.translate(zero.dx, zero.dy);
        canvas.scale(scale);
        ArchitectStairPlanPainter.draw(
          canvas: canvas,
          stair: stair,
          scale: scale,
          color: color,
          storey: project.activeStorey,
          project: project,
          l10n: l,
        );
        canvas.restore();
        saved = false;
        painted = true;
      } on ArgumentError {
        if (saved) canvas.restore();
        for (final f in draft.layout.flights) {
          polygon(f.footprint(draft.design.going));
        }
      }
    }
    for (var i = 0; i < draft.layout.landings.length; i++) {
      if (!painted || i >= draft.layout.flights.length - 1)
        polygon(draft.layout.landings[i].polygon);
    }
    polygon(draft.layout.cell, width: 1.5);
    polygon(draft.points, closed: false);
    if (draft.points.isNotEmpty && draft.cursor != null) {
      polygon([draft.points.last, draft.cursor!], closed: false);
    }
    final candidate = draft.candidateFlight;
    if (draft.mode == StairDraftMode.flight && candidate != null) {
      polygon(candidate.footprint(draft.design.going), width: 1.5);
    }
    final selected = draft.selectedFlight;
    if (selected != null)
      polygon(selected.footprint(draft.design.going), width: 2);
  }

  @override
  bool shouldRepaint(covariant _DraftPainter oldDelegate) => true;
}
