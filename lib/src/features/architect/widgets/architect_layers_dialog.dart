// === SECTION: ARCHITECT LAYERS DIALOG ===

import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';

class ArchitectLayersDialog extends StatefulWidget {
  final ArchitectProject project;
  final ValueChanged<ArchitectLayer> onToggleVisibility;
  final void Function(String name, int? colorValue) onCreateLayer;
  final ValueChanged<ArchitectLayer> onDeleteLayer;
  final VoidCallback onShowAll;
  final bool? underlaysVisible;
  final ValueChanged<bool>? onToggleUnderlays;

  const ArchitectLayersDialog({
    super.key,
    required this.project,
    required this.onToggleVisibility,
    required this.onCreateLayer,
    required this.onDeleteLayer,
    required this.onShowAll,
    this.underlaysVisible,
    this.onToggleUnderlays,
  });

  @override
  State<ArchitectLayersDialog> createState() => _ArchitectLayersDialogState();
}

class _ArchitectLayersDialogState extends State<ArchitectLayersDialog> {
  int _elementCountForLayer(String layerId, ArchitectStorey storey) {
    var count = 0;
    for (final w in storey.walls) {
      if (widget.project.elementLayerId(w.id, ArchitectLayer.wallLayerId) == layerId) count++;
      for (final d in w.doors) {
        if (widget.project.elementLayerId(d.id, ArchitectLayer.doorLayerId) == layerId) count++;
      }
      for (final wn in w.windows) {
        if (widget.project.elementLayerId(wn.id, ArchitectLayer.windowLayerId) == layerId) count++;
      }
    }
    for (final s in storey.slabs) {
      if (widget.project.elementLayerId(s.id, ArchitectLayer.slabLayerId) == layerId) count++;
    }
    for (final r in storey.roofs) {
      if (widget.project.elementLayerId(r.id, ArchitectLayer.roofLayerId) == layerId) count++;
    }
    for (final c in storey.columns) {
      if (widget.project.elementLayerId(c.id, ArchitectLayer.columnLayerId) == layerId) count++;
    }
    for (final b in storey.beams) {
      if (widget.project.elementLayerId(b.id, ArchitectLayer.beamLayerId) == layerId) count++;
    }
    for (final st in storey.stairs) {
      if (widget.project.elementLayerId(st.id, ArchitectLayer.stairLayerId) == layerId) count++;
    }
    for (final z in storey.zones) {
      if (widget.project.elementLayerId(z.id, ArchitectLayer.zoneLayerId) == layerId) count++;
    }
    for (final d in storey.dimensions) {
      if (widget.project.elementLayerId(d.id, ArchitectLayer.dimensionLayerId) == layerId) count++;
    }
    for (final a in storey.annotations) {
      if (widget.project.elementLayerId(a.id, ArchitectLayer.textLayerId) == layerId) count++;
    }
    for (final g in widget.project.gridAxes) {
      if (widget.project.elementLayerId(g.id, ArchitectLayer.gridLayerId) == layerId) count++;
    }
    for (final cp in storey.cadPrimitives) {
      final defLayer = cp.type == CadPrimitiveType.hatch
          ? ArchitectLayer.hatchLayerId
          : ArchitectLayer.cadLayerId;
      if (widget.project.elementLayerId(cp.id, defLayer) == layerId) count++;
    }
    for (final comp in storey.components) {
      if (widget.project.elementLayerId(comp.id, ArchitectLayer.furnitureLayerId) == layerId) count++;
    }
    for (final fd in storey.floorDrains) {
      if (widget.project.elementLayerId(fd.id, ArchitectLayer.drainageLayerId) == layerId) count++;
    }
    if (layerId == ArchitectLayer.cadUnderlayLayerId) {
      if (widget.project.cadUnderlayForStorey(storey.id) != null) count++;
    }
    if (layerId == ArchitectLayer.rasterUnderlayLayerId) {
      count += widget.project.rasterUnderlaysForStorey(storey.id).length;
    }
    if (layerId == ArchitectLayer.geodesyLayerId) {
      final survey = widget.project.geodeticSurvey;
      if (survey != null) {
        count += survey.contoursForStorey(storey.id).length;
        count += survey.pointsForStorey(storey.id).length;
      }
    }
    return count;
  }

  void _showAddLayerDialog(BuildContext context) {
    final l = context.l10n;
    final controller = TextEditingController();
    Color selectedColor = const Color(0xFF00E5FF);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.architectNewLayer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.architectLayerName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.architectLayerColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final color in const [
                        Color(0xFF00E5FF),
                        Color(0xFFFFB300),
                        Color(0xFF81C784),
                        Color(0xFFE57373),
                        Color(0xFFBA68C8),
                        Color(0xFF90CAF9),
                      ])
                        GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  widget.onCreateLayer(name, selectedColor.toARGB32());
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final layers = ArchitectLayer.sortedForDisplay(
      widget.project.effectiveLayers,
      l,
    );
    final storey = widget.project.activeStorey;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const AppIcon(AppIconId.layers, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.architectLayers,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIconId.visible, size: 18),
                    tooltip: l.architectAllLayersVisible,
                    onPressed: widget.onShowAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (widget.onToggleUnderlays != null) ...[
              SwitchListTile.adaptive(
                key: const ValueKey('layers-toggle-underlays'),
                secondary: AppIcon(
                  (widget.underlaysVisible ?? true)
                      ? AppIconId.visible
                      : AppIconId.hidden,
                  size: 20,
                ),
                title: Text(l.architectVisibilityUnderlays),
                value: widget.underlaysVisible ?? true,
                onChanged: widget.onToggleUnderlays,
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: layers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final layer = layers[index];
                  final count = _elementCountForLayer(layer.id, storey);
                  final color = layer.colorValue != null
                      ? Color(layer.colorValue!)
                      : Colors.grey;

                  return ListTile(
                    key: ValueKey(layer.id),
                    leading: IconButton(
                      icon: AppIcon(
                        layer.visible ? AppIconId.visible : AppIconId.hidden,
                        color: layer.visible ? null : Colors.grey,
                      ),
                      onPressed: () => widget.onToggleVisibility(layer),
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            layer.localizedName(l),
                            style: TextStyle(
                              color: layer.visible ? null : Colors.grey,
                              fontWeight: layer.isStandard
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${layer.id} · $count',
                      style: TextStyle(
                        fontSize: 12,
                        color: layer.visible ? Colors.white60 : Colors.white30,
                      ),
                    ),
                    trailing: !layer.isStandard
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            tooltip: l.architectDeleteLayer,
                            onPressed: () => widget.onDeleteLayer(layer),
                          )
                        : null,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l.architectNewLayer),
                    onPressed: () => _showAddLayerDialog(context),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.close),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
