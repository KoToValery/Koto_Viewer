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

          // Global Quick Bar for all layers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Row(
              children: [
                Icon(
                  Icons.line_weight,
                  size: 15,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 6),
                Text(
                  'Всички:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuickAllOption('Оригинална', () => _setAllLineweight(null), theme),
                        const SizedBox(width: 4),
                        _buildQuickAllOption('0.12 мм', () => _setAllLineweight(0.12), theme),
                        const SizedBox(width: 4),
                        _buildQuickAllOption('0.25 мм', () => _setAllLineweight(0.25), theme),
                        const SizedBox(width: 4),
                        _buildQuickAllOption('0.35 мм', () => _setAllLineweight(0.35), theme),
                        const SizedBox(width: 4),
                        _buildQuickAllOption('0.70 мм', () => _setAllLineweight(0.70), theme),
                      ],
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

                      // Layer Details & Line Weight Selector
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
                              '$count ${count == 1 ? "обект" : "обекта"} ${layer.isFrozen ? "• Замразен" : ""}${layer.lineweight != null && layer.lineweight! > 0 ? " • DXF: ${layer.lineweight!.toStringAsFixed(2)} mm" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // AutoCAD Lineweight Selector: Оригинална, 0.12 мм, 0.25 мм, 0.35 мм, 0.70 мм
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLineWeightOption(
                                    label: 'Оригинална',
                                    previewThickness: (layer.lineweight != null && layer.lineweight! > 0)
                                        ? (layer.lineweight! * 4.5).clamp(0.9, 3.5)
                                        : 1.0,
                                    isSelected: layer.customLineweight == null,
                                    onTap: () {
                                      setState(() {
                                        layer.customLineweight = null;
                                      });
                                      widget.onLayersChanged();
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(width: 4),
                                  _buildLineWeightOption(
                                    label: '0.12 мм',
                                    previewThickness: 0.9,
                                    isSelected: layer.customLineweight == 0.12,
                                    onTap: () {
                                      setState(() {
                                        layer.customLineweight = 0.12;
                                      });
                                      widget.onLayersChanged();
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(width: 4),
                                  _buildLineWeightOption(
                                    label: '0.25 мм',
                                    previewThickness: 1.4,
                                    isSelected: layer.customLineweight == 0.25,
                                    onTap: () {
                                      setState(() {
                                        layer.customLineweight = 0.25;
                                      });
                                      widget.onLayersChanged();
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(width: 4),
                                  _buildLineWeightOption(
                                    label: '0.35 мм',
                                    previewThickness: 2.0,
                                    isSelected: layer.customLineweight == 0.35,
                                    onTap: () {
                                      setState(() {
                                        layer.customLineweight = 0.35;
                                      });
                                      widget.onLayersChanged();
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(width: 4),
                                  _buildLineWeightOption(
                                    label: '0.70 мм',
                                    previewThickness: 3.5,
                                    isSelected: layer.customLineweight == 0.70,
                                    onTap: () {
                                      setState(() {
                                        layer.customLineweight = 0.70;
                                      });
                                      widget.onLayersChanged();
                                    },
                                    theme: theme,
                                  ),
                                ],
                              ),
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

  Widget _buildQuickAllOption(String label, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLineWeightOption({
    required String label,
    required double previewThickness,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.25),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: previewThickness,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 4.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
