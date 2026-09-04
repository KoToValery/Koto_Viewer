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
      final name = entity.layer.trim();
      _layerCounts[name] = (_layerCounts[name] ?? 0) + 1;
    }
    for (final block in widget.document.blocks.values) {
      for (final entity in block.entities) {
        final name = entity.layer.trim();
        _layerCounts[name] = (_layerCounts[name] ?? 0) + 1;
      }
    }
  }

  void _toggleAll(bool visible) {
    setState(() {
      for (final layer in widget.document.layers.values) {
        layer.isVisible = visible;
        if (visible && layer.isFrozen) {
          layer.isFrozen = false;
        }
      }
    });
    widget.onLayersChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedLayers = widget.document.layers.values
        .where((l) => (_layerCounts[l.name] ?? 0) > 0 || widget.document.layers.length == 1)
        .toList()
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

          // Global Quick Bar for all layers with Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            child: Row(
              children: [
                Icon(
                  Icons.line_weight,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lineweight for all:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.35),
                      width: 0.9,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double?>(
                      value: null,
                      hint: Text(
                        'Select for all...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                      isDense: true,
                      dropdownColor: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      items: [
                        DropdownMenuItem<double?>(
                          value: null,
                          child: _buildDropdownItemRow(label: 'Original', thickness: 1.0, theme: theme),
                        ),
                        DropdownMenuItem<double?>(
                          value: 0.12,
                          child: _buildDropdownItemRow(label: '0.12 mm', thickness: 0.9, theme: theme),
                        ),
                        DropdownMenuItem<double?>(
                          value: 0.25,
                          child: _buildDropdownItemRow(label: '0.25 mm', thickness: 1.4, theme: theme),
                        ),
                        DropdownMenuItem<double?>(
                          value: 0.35,
                          child: _buildDropdownItemRow(label: '0.35 mm', thickness: 2.0, theme: theme),
                        ),
                        DropdownMenuItem<double?>(
                          value: 0.70,
                          child: _buildDropdownItemRow(label: '0.70 mm', thickness: 3.5, theme: theme),
                        ),
                      ],
                      onChanged: (val) {
                        _setAllLineweight(val);
                      },
                    ),
                  ),
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

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Layer Color Indicator
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Layer Details & Dropdown Lineweight Selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              layer.name.isEmpty ? 'Unnamed Layer' : layer.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                decoration: layer.isVisible ? null : TextDecoration.lineThrough,
                                color: layer.isVisible ? null : theme.disabledColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count ${count == 1 ? "object" : "objects"} ${layer.isFrozen ? "• Frozen" : ""}${layer.lineweight != null && layer.lineweight! > 0 ? " • DXF: ${layer.lineweight!.toStringAsFixed(2)} mm" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Lineweight Dropdown Menu
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lineweight: ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                                Container(
                                  height: 27,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<double?>(
                                      value: layer.customLineweight,
                                      isDense: true,
                                      icon: Icon(Icons.arrow_drop_down, size: 17, color: theme.colorScheme.primary),
                                      dropdownColor: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      items: [
                                        DropdownMenuItem<double?>(
                                          value: null,
                                          child: _buildDropdownItemRow(
                                            label: 'Original',
                                            thickness: (layer.lineweight != null && layer.lineweight! > 0)
                                                ? (layer.lineweight! * 4.5).clamp(0.9, 3.5)
                                                : 1.0,
                                            theme: theme,
                                          ),
                                        ),
                                        DropdownMenuItem<double?>(
                                          value: 0.12,
                                          child: _buildDropdownItemRow(label: '0.12 mm', thickness: 0.9, theme: theme),
                                        ),
                                        DropdownMenuItem<double?>(
                                          value: 0.25,
                                          child: _buildDropdownItemRow(label: '0.25 mm', thickness: 1.4, theme: theme),
                                        ),
                                        DropdownMenuItem<double?>(
                                          value: 0.35,
                                          child: _buildDropdownItemRow(label: '0.35 mm', thickness: 2.0, theme: theme),
                                        ),
                                        DropdownMenuItem<double?>(
                                          value: 0.70,
                                          child: _buildDropdownItemRow(label: '0.70 mm', thickness: 3.5, theme: theme),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          layer.customLineweight = val;
                                        });
                                        widget.onLayersChanged();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Visibility Switch
                      Switch.adaptive(
                        value: layer.isVisible,
                        onChanged: (val) {
                          setState(() {
                            layer.isVisible = val;
                            if (val && layer.isFrozen) {
                              layer.isFrozen = false;
                            }
                          });
                          widget.onLayersChanged();
                        },
                      ),
                    ],
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

  void _setAllLineweight(double? weight) {
    setState(() {
      for (final layer in widget.document.layers.values) {
        layer.customLineweight = weight;
      }
    });
    widget.onLayersChanged();
  }

  Widget _buildDropdownItemRow({
    required String label,
    required double thickness,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: thickness,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
