import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';
import '../services/slab_edge_offset.dart';

class SlabEdgeOffsetDialog extends StatefulWidget {
  final List<StructuralSlab> slabs;
  final StructuralSlab slab;
  final double scale;
  final int initialEdge;
  const SlabEdgeOffsetDialog({
    super.key,
    required this.slabs,
    required this.slab,
    required this.scale,
    this.initialEdge = 0,
  });
  @override
  State<SlabEdgeOffsetDialog> createState() => _SlabEdgeOffsetDialogState();
}

class _SlabEdgeOffsetDialogState extends State<SlabEdgeOffsetDialog> {
  final distance = TextEditingController();
  late int edge = widget.initialEdge.clamp(0, widget.slab.polygon.length - 1);
  bool error = false;
  @override
  void dispose() {
    distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.slab.polygon;
    return AlertDialog(
      title: Text(context.l10n.slabEdgeOffset),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: edge,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.slabEdgeNumber,
              ),
              items: List.generate(
                p.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${i + 1} · ${((p[(i + 1) % p.length] - p[i]).distance / widget.scale).toStringAsFixed(3)} m',
                  ),
                ),
              ),
              onChanged: (value) {
                if (value != null) setState(() => edge = value);
              },
            ),
            TextField(
              controller: distance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.slabEdgeDistance,
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.slabEdgeHint),
            if (error)
              Text(
                context.l10n.slabEdgeInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final cm = double.tryParse(distance.text.replaceAll(',', '.'));
            final result = cm == null
                ? null
                : SlabEdgeOffset.move(
                    slabs: widget.slabs,
                    slabId: widget.slab.id,
                    edge: edge,
                    metres: cm / 100,
                    scale: widget.scale,
                  );
            if (result == null) {
              setState(() => error = true);
              return;
            }
            Navigator.pop(context, result);
          },
          child: Text(context.l10n.applyAction),
        ),
      ],
    );
  }
}
