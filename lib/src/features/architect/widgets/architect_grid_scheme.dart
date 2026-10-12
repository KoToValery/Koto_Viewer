import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import 'architect_wall_drafting_panel.dart';

/// The picker chooses bays; dimensions edit their individual physical spans.
class ArchitectGridScheme extends StatelessWidget {
  final List<double> spacingsX, spacingsY;
  final ArchitectUnit unit;
  final void Function(List<double>, List<double>) onChanged;
  const ArchitectGridScheme({
    super.key,
    required this.spacingsX,
    required this.spacingsY,
    required this.unit,
    required this.onChanged,
  });

  void _resize(int x, int y) {
    List<double> resized(List<double> old, int count) => List.generate(
      count.clamp(1, 19),
      (i) => i < old.length
          ? old[i]
          : old.isEmpty
          ? 4
          : old.last,
    );
    onChanged(resized(spacingsX, x), resized(spacingsY, y));
  }

  Future<void> _edit(BuildContext context, bool x, int index) async {
    final list = x ? spacingsX : spacingsY;
    var value = list[index];
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 240,
          child: ArchitectWallDraftingPanel(
            title: x
                ? '${index + 1}–${index + 2}'
                : '${_letter(index)}–${_letter(index + 1)}',
            endLabel: context.l10n.save,
            length: unit.toUnit(value),
            unit: unit.symbol,
            minimumLength: unit.toUnit(.05),
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            onLength: (v) => value = unit.fromUnit(v),
            onEnd: () {
              final next = List<double>.of(list)..[index] = value;
              onChanged(x ? next : spacingsX, x ? spacingsY : next);
              Navigator.of(ctx).pop();
            },
            onContinue: () {},
            onUnlock: () {},
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  static String _letter(int index) => String.fromCharCode(65 + index);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.architectGridBays(spacingsX.length, spacingsY.length)),
        Tooltip(
          message: l.architectGridPickerHelp,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              const columns = 8, rows = 6, height = 132.0;
              void pick(Offset p) => _resize(
                (p.dx / (constraints.maxWidth / columns)).floor().clamp(
                      0,
                      columns - 1,
                    ) +
                    1,
                (p.dy / (height / rows)).floor().clamp(0, rows - 1) + 1,
              );
              return GestureDetector(
                key: const ValueKey('architect-grid-picker'),
                onTapDown: (d) => pick(d.localPosition),
                onPanStart: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: SizedBox(
                  height: height,
                  child: CustomPaint(
                    painter: _BayPickerPainter(
                      spacingsX.length,
                      spacingsY.length,
                      columns,
                      rows,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final layout = _GridSchemeLayout(
              spacingsX,
              spacingsY,
              constraints.maxWidth,
            );
            Widget dimension(bool x, int index) {
              final axes = x
                  ? '${index + 1}–${index + 2}'
                  : '${_letter(index)}–${_letter(index + 1)}';
              final value = unit.format((x ? spacingsX : spacingsY)[index]);
              return Semantics(
                button: true,
                label: l.architectGridSpanLabel(axes, value),
                child: Tooltip(
                  message: l.architectGridSpanLabel(axes, value),
                  child: InkWell(
                    key: ValueKey('grid-gap-${x ? 'x' : 'y'}-$index'),
                    onTap: () => _edit(context, x, index),
                    child: Center(
                      child: Text(
                        value,
                        maxLines: 1,
                        style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 11,
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                key: const ValueKey('architect-grid-preview'),
                width: layout.size.width,
                height: layout.size.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _GridSchemePainter(layout)),
                    ),
                    for (var i = 0; i < spacingsX.length; i++)
                      Positioned(
                        left: layout.xs[i],
                        top: 0,
                        width: layout.xs[i + 1] - layout.xs[i],
                        height: 36,
                        child: dimension(true, i),
                      ),
                    for (var i = 0; i < spacingsY.length; i++)
                      Positioned(
                        left: 0,
                        top: layout.ys[i],
                        width: 52,
                        height: layout.ys[i + 1] - layout.ys[i],
                        child: dimension(false, i),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BayPickerPainter extends CustomPainter {
  final int x, y, columns, rows;
  _BayPickerPainter(this.x, this.y, this.columns, this.rows);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = Size(size.width / columns, size.height / rows);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final rect = Rect.fromLTWH(
          col * cell.width + 2,
          row * cell.height + 2,
          cell.width - 4,
          cell.height - 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()
            ..color = col < x && row < y
                ? const Color(0xFF00BCD4)
                : const Color(0xFF41434D),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BayPickerPainter old) =>
      x != old.x || y != old.y;
}

class _GridSchemeLayout {
  final List<double> xs = [56], ys = [40];
  late final Size size;
  _GridSchemeLayout(List<double> xSteps, List<double> ySteps, double width) {
    final totalX = xSteps.fold(0.0, (a, b) => a + b);
    final totalY = ySteps.fold(0.0, (a, b) => a + b);
    // Keep labels touchable; scroll larger schemes instead of overlapping them.
    var scale = math.max(
      (width - 64) / totalX,
      math.max(64 / xSteps.reduce(math.min), 44 / ySteps.reduce(math.min)),
    );
    scale = math.min(scale, 8192 / math.max(totalX, totalY));
    for (final step in xSteps) {
      xs.add(xs.last + step * scale);
    }
    for (final step in ySteps) {
      ys.add(ys.last + step * scale);
    }
    size = Size(math.max(width, xs.last + 8), ys.last + 8);
  }
}

class _GridSchemePainter extends CustomPainter {
  final _GridSchemeLayout layout;
  _GridSchemePainter(this.layout);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1;
    for (final x in layout.xs) {
      canvas.drawLine(
        Offset(x, layout.ys.first - 4),
        Offset(x, layout.ys.last + 4),
        paint,
      );
    }
    for (final y in layout.ys) {
      canvas.drawLine(
        Offset(layout.xs.first - 4, y),
        Offset(layout.xs.last + 4, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridSchemePainter old) => layout != old.layout;
}
