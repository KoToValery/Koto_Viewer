import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import 'architect_roof_number_field.dart';

class ArchitectAutoRoofPreviewDialog extends StatefulWidget {
  final ArchitectProject project;
  final List<ArchitectRoofPlane> generated;
  final AutoRoofType type;
  final String? selectedRoofId;
  const ArchitectAutoRoofPreviewDialog({
    super.key,
    required this.project,
    required this.generated,
    required this.type,
    this.selectedRoofId,
  });
  @override
  State<ArchitectAutoRoofPreviewDialog> createState() => _PreviewState();
}

class _PreviewState extends State<ArchitectAutoRoofPreviewDialog> {
  late final groups = <String, List<ArchitectRoofPlane>>{};
  int? target;
  @override
  void initState() {
    super.initState();
    for (final roof in widget.project.activeStorey.roofs) {
      final key = roof.roofGroupId?.isNotEmpty == true
          ? roof.roofGroupId!
          : roof.id;
      (groups[key] ??= []).add(roof);
    }
    if (groups.isEmpty) {
      target = -1;
    } else if (groups.length == 1) {
      target = 0;
    }
    if (widget.selectedRoofId != null) {
      final list = groups.values.toList();
      for (var i = 0; i < list.length; i++) {
        if (list[i].any((r) => r.id == widget.selectedRoofId)) target = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final replacing = target == -2
        ? widget.project.activeStorey.roofs.map((r) => r.id).toSet()
        : target != null && target! >= 0
        ? groups.values.elementAt(target!).map((r) => r.id).toSet()
        : <String>{};
    final kept = widget.project.activeStorey.roofs
        .where((r) => !replacing.contains(r.id))
        .toList();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.roofUiAutoPreview,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: l.close,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(
          '${widget.type.label(l)} · ${l.roofUiGeneratedCount(widget.generated.length)}',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: CustomPaint(
            key: const ValueKey('roof-auto-preview-plan'),
            painter: _PlanPainter(
              widget.generated,
              kept,
              widget.project.activeStorey.walls
                  .map((w) => w.polygonCorners)
                  .toList(),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          children: [
            _PlanLegend(label: l.roofUiNewLegend),
            _PlanLegend(label: l.roofUiKeptLegend, dashed: true),
          ],
        ),
        Text(
          '${widget.generated.first.assembly.preset.label(l)} · ${roofNumber(widget.generated.first.slopeDegrees)}°',
        ),
        if (groups.isNotEmpty)
          DropdownButtonFormField<int>(
            key: const ValueKey('roof-auto-target'),
            initialValue: target,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.roofUiTarget),
            items: [
              DropdownMenuItem(value: -1, child: Text(l.roofUiAddRoof)),
              if (groups.length > 1)
                DropdownMenuItem(
                  value: -2,
                  child: Text(
                    l.roofUiReplaceFloor(
                      widget.project.activeStorey.roofs.length,
                    ),
                  ),
                ),
              for (var i = 0; i < groups.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    l.roofUiReplaceRoof(
                      i + 1,
                      groups.values.elementAt(i).length,
                    ),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => target = v),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            target == -2
                ? l.roofUiReplaceFloor(replacing.length)
                : l.roofUiReviewHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            const Spacer(),
            FilledButton(
              key: const ValueKey('roof-auto-apply'),
              onPressed: target == null
                  ? null
                  : () => Navigator.pop(context, replacing),
              child: Text(
                target != null && target! != -1
                    ? l.roofUiReplace
                    : l.roofUiCreate,
              ),
            ),
          ],
        ),
      ],
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(
        child: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16), child: content),
        ),
      );
    }
    return Dialog(
      child: SizedBox(
        width: 680,
        height: 680,
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }
}

class _PlanLegend extends StatelessWidget {
  final String label;
  final bool dashed;
  const _PlanLegend({required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 24,
        child: Row(
          children: List.generate(
            dashed ? 3 : 1,
            (_) => Expanded(
              child: Container(
                height: dashed ? 1 : 1.5,
                margin: EdgeInsets.only(right: dashed ? 3 : 0),
                color: const Color(0xFF505050),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _PlanPainter extends CustomPainter {
  final List<ArchitectRoofPlane> generated, kept;
  final List<List<Offset>> walls;
  _PlanPainter(this.generated, this.kept, this.walls);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final points = [
      ...walls.expand((p) => p),
      for (final roof in [...generated, ...kept]) ...roof.points,
    ];
    if (points.isEmpty) return;
    final bounds = (Path()..addPolygon(points, false)).getBounds();
    final scale = math.min(
      (size.width - 24) / math.max(bounds.width, .1),
      (size.height - 24) / math.max(bounds.height, .1),
    );
    Offset map(Offset p) =>
        Offset(size.width / 2, size.height / 2) + (p - bounds.center) * scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final roof in generated) {
      final polygon = roof.points.map(map).toList();
      final p = Path()..addPolygon(polygon, true);
      canvas.drawPath(p, Paint()..color = const Color(0xFFF6F6F6));
      canvas.drawPath(
        p,
        Paint()
          ..color = const Color(0xFF252525)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
      final e = roof.eavesEdge;
      canvas.drawLine(
        map(e.$1),
        map(e.$2),
        Paint()
          ..color = const Color(0xFF252525)
          ..strokeWidth = 2.3,
      );
    }
    for (final wall in walls) {
      canvas.drawPath(
        Path()..addPolygon(wall.map(map).toList(), true),
        Paint()
          ..color = const Color(0xFFB5B5B5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
    for (final roof in kept) {
      final p = Path()..addPolygon(roof.points.map(map).toList(), true);
      for (final hole in roof.holes) {
        p.addPolygon(hole.map(map).toList(), true);
      }
      for (final metric in p.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 9) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 5, metric.length)),
            Paint()
              ..color = const Color(0xFF696969)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanPainter old) =>
      old.kept != kept || old.generated != generated;
}
