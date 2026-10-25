import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_material_layer.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'architect_material_layer_label.dart';

/// Paper preview: physical boundaries and sparse hatches stay legible in both themes.
class ArchitectWallLayerPreview extends StatelessWidget {
  final List<ArchitectMaterialLayer> layers;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  const ArchitectWallLayerPreview({
    super.key,
    required this.layers,
    this.selectedIndex,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final widths = _weights(layers);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < layers.length; i++)
            Expanded(
              flex: widths[i],
              child: Semantics(
                label: layers[i].material.label(context.l10n),
                selected: i == selectedIndex,
                button: onSelected != null,
                child: Tooltip(
                  message: layers[i].material.label(context.l10n),
                  child: GestureDetector(
                    onTap: onSelected == null ? null : () => onSelected!(i),
                    child: CustomPaint(
                      painter: _LayerPainter(
                        layers[i],
                        i == selectedIndex,
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  static List<int> _weights(List<ArchitectMaterialLayer> layers) {
    final total = layers.fold<double>(0, (sum, l) => sum + l.thickness);
    return [
      for (final l in layers)
        math.max(5, (l.thickness / (total > 0 ? total : 1) * 100).round()),
    ];
  }
}

class _LayerPainter extends CustomPainter {
  final ArchitectMaterialLayer layer;
  final bool selected;
  final Color accent;
  _LayerPainter(this.layer, this.selected, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final ink = Paint()
      ..color = const Color(0xFF484848)
      ..strokeWidth = .6;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (layer.role == ArchitectLayerRole.insulation) {
      for (var x = 3.0; x < size.width; x += 6) {
        for (var y = 3.0; y < size.height; y += 6) {
          canvas.drawCircle(Offset(x, y), .65, ink);
        }
      }
    } else if (layer.role == ArchitectLayerRole.core) {
      for (var x = -size.height; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          ink,
        );
      }
    }
    canvas.restore();
    canvas.drawRect(
      (Offset.zero & size).deflate(.5),
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.role == ArchitectLayerRole.core ? 1.2 : .6,
    );
    if (selected) {
      canvas.drawRect(
        Rect.fromLTWH(0, math.max(0, size.height - 3), size.width, 3),
        Paint()..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(_LayerPainter old) =>
      old.layer != layer || old.selected != selected || old.accent != accent;
}
