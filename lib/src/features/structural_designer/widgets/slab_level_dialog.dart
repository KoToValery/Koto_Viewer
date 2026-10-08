import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';

/// Edits the same ceiling slab owned by the active working storey.
class SlabLevelDialog extends StatefulWidget {
  final StoreyLevel storey;
  final StructuralSlab slab;
  const SlabLevelDialog({super.key, required this.storey, required this.slab});
  @override
  State<SlabLevelDialog> createState() => _SlabLevelDialogState();
}

class _SlabLevelDialogState extends State<SlabLevelDialog> {
  late final TextEditingController thickness;
  late final TextEditingController top;
  late bool explicit;
  bool error = false;
  double parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? double.nan;
  @override
  void initState() {
    super.initState();
    thickness = TextEditingController(
      text: (widget.slab.thickness * 100).toString(),
    );
    top = TextEditingController(
      text: widget.storey
          .structuralElevationFor(widget.slab)
          .toStringAsFixed(3),
    );
    explicit = widget.slab.topElevation != null;
  }

  @override
  void dispose() {
    thickness.dispose();
    top.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = parse(thickness) / 100;
    final z = explicit
        ? parse(top)
        : widget.storey.structuralElevationFor(
            widget.slab.copyWith(clearTopElevation: true),
          );
    return AlertDialog(
      title: Text(context.l10n.ceilingSlabTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.ceilingSlabContext(widget.storey.elevationLabel)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ceiling-thickness'),
              controller: thickness,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.slabThicknessHCm,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.ceilingExplicitLevel),
              value: explicit,
              onChanged: (v) => setState(() {
                explicit = v;
                if (!v) {
                  top.text = widget.storey
                      .structuralElevationFor(
                        widget.slab.copyWith(clearTopElevation: true),
                      )
                      .toStringAsFixed(3);
                }
                error = false;
              }),
            ),
            TextField(
              key: const ValueKey('ceiling-top'),
              controller: top,
              enabled: explicit,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.ceilingConcreteTop,
                suffixText: 'm',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.ceilingSlabLevels(
                z.isFinite ? z.toStringAsFixed(3) : '—',
                (z - h).isFinite ? (z - h).toStringAsFixed(3) : '—',
              ),
            ),
            Text(context.l10n.ceilingSlabLevelHint),
            if (error)
              Text(
                context.l10n.ceilingSlabInvalid,
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
            final h = parse(thickness) / 100;
            final z = explicit
                ? parse(top)
                : widget.storey.structuralElevationFor(
                    widget.slab.copyWith(clearTopElevation: true),
                  );
            if (!h.isFinite || h <= 0 || !z.isFinite) {
              setState(() => error = true);
              return;
            }
            Navigator.pop(
              context,
              widget.slab.copyWith(
                thickness: h,
                topElevation: explicit ? z : null,
                clearTopElevation: !explicit,
              ),
            );
          },
          child: Text(context.l10n.applyAction),
        ),
      ],
    );
  }
}
