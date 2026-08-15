import 'package:flutter/material.dart';
import '../models/dxf_color_table.dart';
import '../models/dxf_models.dart';

/// Modal bottom sheet for managing DXF layers (toggle visibility, colors, counts).
class DxfLayerSheet extends StatefulWidget {
  final DxfDocument document;
  final VoidCallback onLayersChanged;
  final bool isDark;

  const DxfLayerSheet({
    super.key,
    required this.document,
    required this.onLayersChanged,
    required this.isDark,
  });

  static Future<void> show({
    required BuildContext context,
    required DxfDocument document,
    required VoidCallback onLayersChanged,
    required bool isDark,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DxfLayerSheet(
        document: document,
        onLayersChanged: onLayersChanged,
        isDark: isDark,
      ),
    );
  }

  @override
  State<DxfLayerSheet> createState() => _DxfLayerSheetState();
}

class _DxfLayerSheetState extends State<DxfLayerSheet> {
  // Count entities per layer
  late final Map<String, int> _layerCounts;

  @override
  void initState() {
    super.initState();
    _layerCounts = {};
    for (final layerName in widget.document.layers.keys) {
      _layerCounts[layerName] = 0;
    }
    for (final entity in widget.document.entities) {
      _layerCounts[entity.layer] = (_layerCounts[entity.layer] ?? 0) + 1;
    }
  }

  void _toggleAll(bool visible) {
    setState(() {
      for (final layer in widget.document.layers.values) {
        layer.isVisible = visible;
      }
    });
    widget.onLayersChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedLayers = widget.document.layers.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final totalVisible = sortedLayers.where((l) => l.isVisible).length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.layers_outlined,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAD Layers',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$totalVisible of ${sortedLayers.length} layers visible',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _toggleAll(true),
                  child: const Text('Show All'),
                ),
                TextButton(
                  onPressed: () => _toggleAll(false),
                  child: const Text('Hide All'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Layer List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sortedLayers.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
              itemBuilder: (context, index) {
                final layer = sortedLayers[index];
                final color = DxfColorTable.resolveColor(
                  colorIndex: layer.colorIndex,
                  trueColor: layer.trueColor,
                  isDarkBackground: widget.isDark,
                );
                final count = _layerCounts[layer.name] ?? 0;

                return SwitchListTile.adaptive(
                  value: layer.isVisible,
                  onChanged: (val) {
                    setState(() {
                      layer.isVisible = val;
                    });
                    widget.onLayersChanged();
                  },
                  secondary: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    layer.name.isEmpty ? 'Unnamed Layer' : layer.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: layer.isVisible ? null : TextDecoration.lineThrough,
                      color: layer.isVisible ? null : theme.disabledColor,
                    ),
                  ),
                  subtitle: Text(
                    '$count ${count == 1 ? "entity" : "entities"} ${layer.isFrozen ? "• Frozen" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
