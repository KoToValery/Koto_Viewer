import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_stair_perimeter_draft.dart';
import '../services/architect_stair_layout_resolver.dart';
import '../services/architect_stair_rules.dart';
import '../rendering/architect_stair_plan_painter.dart';
import 'architect_wall_drafting_panel.dart';
import 'architect_canvas_hint.dart';
import 'architect_stair_draft_overlay.dart';
import 'architect_stair_labels.dart';

class ArchitectStairPerimeterOverlay extends StatelessWidget {
  final ArchitectStairPerimeterDraft draft;
  final ArchitectProject project;
  final Offset Function(Offset) toScreen;
  final double scale;
  final bool dark;
  final VoidCallback onApply, onCancel, onProperties;
  const ArchitectStairPerimeterOverlay({
    super.key,
    required this.draft,
    required this.project,
    required this.toScreen,
    required this.scale,
    required this.dark,
    required this.onApply,
    required this.onCancel,
    required this.onProperties,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final candidate = draft.reviewing ? draft.preview : draft.committedPreview;
    final preview = candidate ?? draft.preview;
    final issues = preview == null
        ? []
        : ArchitectStairLayoutResolver.check(preview.design!);
    final checks = preview == null
        ? <StairCheck>[]
        : ArchitectStairRules.check(
            preview,
            project: project,
            storey: project.activeStorey,
          );
    final canContinue = draft.canAcceptPart;
    final riser = preview?.design?.riser;
    final riserWarning =
        riser != null && ArchitectStairRules.isRiserOutOfRange(riser);
    final hint = draft.anchor == null
        ? l.stairPerimeterHint
        : draft.reviewing
        ? l.bimExactDistanceInputHelp
        : l.stairPerimeterPickEndpoint;
    final canFinish =
        candidate != null &&
        (!draft.reviewing ||
            (draft.part == StairPerimeterPart.flight && canContinue)) &&
        !riserWarning &&
        issues.isEmpty &&
        (candidate.design!.isDraft ||
            !checks.any((c) => c.state == StairCheckState.error));
    void finish() {
      if (!canFinish || (draft.reviewing && !draft.acceptPart())) return;
      if (draft.complete) onApply();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PerimeterPainter(draft, project, toScreen, scale, dark),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArchitectCanvasHint(
                  message: issues.isNotEmpty
                      ? stairLayoutProblemLabel(l, issues.first.problem)
                      : checks.any((c) => c.state == StairCheckState.error)
                      ? stairCheckLabel(
                          l,
                          checks
                              .firstWhere(
                                (c) => c.state == StairCheckState.error,
                              )
                              .kind,
                        )
                      : preview != null && draft.targetRisers != null
                      ? '${l.stairTargetRisersProgress(preview.design!.risers, draft.targetRisers!)} · $hint'
                      : hint,
                ),
                if (riserWarning) ...[
                  const SizedBox(height: 4),
                  ArchitectCanvasHint(
                    key: const ValueKey('stair-perimeter-riser-warning'),
                    warning: true,
                    message:
                        '${project.formatLength(riser)} · '
                        '${stairRiserRangeWarningText(l)}',
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              key: ValueKey((
                draft.endpointRevision,
                draft.part,
                draft.reviewing,
              )),
              constraints: const BoxConstraints(maxWidth: 344),
              child: ArchitectWallDraftingPanel(
                key: const ValueKey('stair-perimeter-panel'),
                length: project.units.toUnit(draft.length),
                unit: project.units.symbol,
                decimals: project.distanceDecimals,
                continuePrimary: true,
                canEditLength: draft.reviewing,
                canContinue: canContinue,
                canEnd: canFinish,
                showDirection: false,
                minimumLength: draft.reviewing ? project.units.toUnit(.001) : 0,
                title: draft.part == StairPerimeterPart.flight
                    ? l.stairFlight
                    : l.stairLandingPart,
                endLabel: l.applyAction,
                cancelLabel: draft.reviewing ? l.stairRejectSegment : l.cancel,
                extraControls: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<StairPerimeterPart>(
                        isExpanded: true,
                        key: const ValueKey('stair-perimeter-part'),
                        value: draft.part,
                        items: [
                          DropdownMenuItem(
                            value: StairPerimeterPart.flight,
                            child: Text(l.stairFlight),
                          ),
                          DropdownMenuItem(
                            value: StairPerimeterPart.landing,
                            child: Text(l.stairLandingPart),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) draft.choose(v);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: l.architectWallFlipSide,
                      onPressed: draft.flip,
                      icon: const Icon(Icons.flip),
                    ),
                    PopupMenuButton<bool>(
                      tooltip: l.architectProperties,
                      icon: const Icon(Icons.tune),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: true,
                          child: Text(l.architectProperties),
                        ),
                        PopupMenuItem(
                          value: false,
                          enabled: draft.canUndo,
                          child: Text(l.undoAction),
                        ),
                      ],
                      onSelected: (properties) {
                        if (properties) {
                          onProperties();
                        } else {
                          draft.undo();
                        }
                      },
                    ),
                    IconButton(
                      tooltip: l.stairClearWidth,
                      icon: const Icon(Icons.width_normal),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: SizedBox(
                            width: 300,
                            child: ArchitectWallDraftingPanel(
                              length: project.units.toUnit(draft.width),
                              unit: project.units.symbol,
                              title: l.stairClearWidth,
                              showContinue: false,
                              keypadInitiallyOpen: true,
                              showDirection: false,
                              onLength: (v) =>
                                  draft.setWidth(project.units.fromUnit(v)),
                              onEnd: () => Navigator.pop(ctx),
                              onContinue: () {},
                              onUnlock: () {},
                              onCancel: () => Navigator.pop(ctx),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                onLength: (v) => draft.setLength(project.units.fromUnit(v)),
                onContinue: draft.acceptPart,
                onEnd: finish,
                onUnlock: draft.unlock,
                onCancel: draft.reviewing ? draft.rejectPart : onCancel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PerimeterPainter extends CustomPainter {
  final ArchitectStairPerimeterDraft draft;
  final ArchitectProject project;
  final Offset Function(Offset) toScreen;
  final double scale;
  final bool dark;
  _PerimeterPainter(
    this.draft,
    this.project,
    this.toScreen,
    this.scale,
    this.dark,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final color = dark ? Colors.white : Colors.black87;
    final s = draft.preview;
    if (s != null) {
      canvas.save();
      try {
        final origin = toScreen(Offset.zero);
        canvas.translate(origin.dx, origin.dy);
        canvas.scale(scale);
        ArchitectStairPlanPainter.draw(
          canvas: canvas,
          stair: s,
          scale: scale,
          color: color,
          project: project,
          storey: project.activeStorey,
          labels: false,
        );
      } finally {
        canvas.restore();
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final quad in draft.pendingLandingQuads) {
      canvas.drawPath(
        Path()..addPolygon(quad.map(toScreen).toList(), true),
        paint,
      );
    }
    for (final segment in draft.visibleSegments) {
      canvas.drawLine(toScreen(segment.start), toScreen(segment.end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerimeterPainter oldDelegate) => true;
}
