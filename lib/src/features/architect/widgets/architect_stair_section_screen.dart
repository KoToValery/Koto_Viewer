import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../rendering/architect_elements_painter_helper.dart';
import '../rendering/architect_canvas_palette.dart';
import '../rendering/architect_stair_mesh.dart';
import '../rendering/architect_stair_section_painter.dart';
import '../services/architect_stair_section.dart';
import 'architect_stair_labels.dart';

class ArchitectStairSectionScreen extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectStair stair;
  const ArchitectStairSectionScreen({
    super.key,
    required this.project,
    required this.stair,
  });
  @override
  State<ArchitectStairSectionScreen> createState() => _StairSectionState();
}

class _StairSectionState extends State<ArchitectStairSectionScreen> {
  late Offset origin, axis;
  Offset? firstPoint;
  late final List<StairSolid> solids;
  late ArchitectStairSection section;
  ArchitectStorey get floor => widget.project.activeStorey;
  @override
  void initState() {
    super.initState();
    solids = [
      ...ArchitectStairMesh.body(widget.stair),
      ...ArchitectStairMesh.railings(
        widget.stair,
        storey: floor,
        project: widget.project,
      ),
    ];
    reset();
  }

  void reset() {
    origin = widget.stair.startPoint;
    axis = widget.stair.unitVector;
    firstPoint = null;
    section = ArchitectStairSection.build(
      solids,
      origin,
      axis,
      includeProjection: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark
        ? const ArchitectCanvasPalette.dark()
        : const ArchitectCanvasPalette.light();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.stairSection),
        actions: [
          IconButton(
            key: const ValueKey('stair-section-reset'),
            tooltip: l.stairSectionReset,
            onPressed: () => setState(reset),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l.stairSectionHint),
            ),
            SizedBox(
              height: math.min(240, MediaQuery.sizeOf(context).height * .27),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bounds = widget.stair.plan.bounds.inflate(.3);
                  final scale = math.min(
                    constraints.maxWidth / bounds.width,
                    constraints.maxHeight / bounds.height,
                  );
                  final centre = Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight / 2,
                  );
                  return GestureDetector(
                    key: const ValueKey('stair-section-plan'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final point =
                          bounds.center +
                          (details.localPosition - centre) / scale;
                      setState(() {
                        if (firstPoint == null) {
                          firstPoint = point;
                        } else if ((point - firstPoint!).distance > .03) {
                          origin = firstPoint!;
                          axis = (point - origin) / (point - origin).distance;
                          firstPoint = null;
                          section = ArchitectStairSection.build(
                            solids,
                            origin,
                            axis,
                            includeProjection: true,
                          );
                        }
                      });
                    },
                    child: CustomPaint(
                      painter: _SectionPlan(
                        widget.stair,
                        widget.project,
                        origin,
                        axis,
                        firstPoint,
                        scale,
                        bounds.center,
                        palette,
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                stairPlanLabel(l, widget.stair),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: palette.background,
                child: section.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l.stairSectionEmpty),
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 8,
                        child: CustomPaint(
                          key: const ValueKey('stair-section-detail'),
                          painter: ArchitectStairSectionPainter(
                            section,
                            cutHeight: floor.cutPlaneHeight,
                            palette: palette,
                          ),
                          size: Size.infinite,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${l.stairSectionCutHeight}: ${floor.cutPlaneHeight.toStringAsFixed(2)} m',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPlan extends CustomPainter {
  final ArchitectStair stair;
  final ArchitectProject project;
  final Offset origin, axis, centre;
  final Offset? firstPoint;
  final double scale;
  final ArchitectCanvasPalette palette;
  _SectionPlan(
    this.stair,
    this.project,
    this.origin,
    this.axis,
    this.firstPoint,
    this.scale,
    this.centre,
    this.palette,
  );
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);
    for (final wall in project.activeStorey.walls) {
      canvas.drawPath(
        Path()..addPolygon(wall.polygonCorners, true),
        Paint()..color = palette.foreground(Colors.grey).withValues(alpha: .25),
      );
    }
    ArchitectElementsPainterHelper.drawStair(
      canvas: canvas,
      stair: stair,
      zoomScale: scale,
      cutHeight: project.activeStorey.cutPlaneHeight,
      storey: project.activeStorey,
      project: project,
      labels: false,
      color: palette.foreground(const Color(0xFF00897B)),
      background: palette.background,
    );
    final length = stair.plan.bounds.longestSide * 1.2;
    final a = origin - axis * length, b = origin + axis * length;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFCC5555)
        ..strokeWidth = 1.3 / scale,
    );
    if (firstPoint != null) {
      canvas.drawCircle(firstPoint!, 5 / scale, Paint()..color = Colors.orange);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SectionPlan old) => true;
}
