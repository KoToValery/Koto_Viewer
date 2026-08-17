import 'package:flutter/material.dart';
import '../models/dxf_display_settings.dart';

/// Modal bottom sheet for customizing CAD display settings (line thickness, measurement size, point size & style).
class DxfDisplaySettingsSheet extends StatefulWidget {
  final DxfDisplaySettings initialSettings;
  final ValueChanged<DxfDisplaySettings> onSettingsChanged;

  const DxfDisplaySettingsSheet({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required DxfDisplaySettings initialSettings,
    required ValueChanged<DxfDisplaySettings> onSettingsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DxfDisplaySettingsSheet(
        initialSettings: initialSettings,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<DxfDisplaySettingsSheet> createState() => _DxfDisplaySettingsSheetState();
}

class _DxfDisplaySettingsSheetState extends State<DxfDisplaySettingsSheet> {
  late DxfDisplaySettings _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSettings;
  }

  void _update(DxfDisplaySettings newSettings) {
    setState(() {
      _current = newSettings;
    });
    widget.onSettingsChanged(newSettings);
    DxfDisplaySettingsService.updateSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
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
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Settings',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Line thickness, dimensions, and point styles',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    const defaultSettings = DxfDisplaySettings();
                    _update(defaultSettings);
                  },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Default', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Line Thickness Section
                  _buildSectionHeader(
                    icon: Icons.line_weight,
                    title: 'Line Thickness',
                    valueLabel: '${(_current.lineThicknessScale * 100).toStringAsFixed(0)}%',
                    theme: theme,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.remove, size: 16, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: _current.lineThicknessScale,
                          min: 0.3,
                          max: 3.5,
                          divisions: 32,
                          label: '${(_current.lineThicknessScale * 100).toStringAsFixed(0)}%',
                          onChanged: (val) {
                            _update(_current.copyWith(lineThicknessScale: val));
                          },
                        ),
                      ),
                      const Icon(Icons.add, size: 16, color: Colors.grey),
                    ],
                  ),
                  // Quick presets for Line Thickness
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPresetChip(
                        label: 'Thin',
                        scale: 0.6,
                        current: _current.lineThicknessScale,
                        onTap: () => _update(_current.copyWith(lineThicknessScale: 0.6)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Normal',
                        scale: 1.0,
                        current: _current.lineThicknessScale,
                        onTap: () => _update(_current.copyWith(lineThicknessScale: 1.0)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Medium',
                        scale: 1.6,
                        current: _current.lineThicknessScale,
                        onTap: () => _update(_current.copyWith(lineThicknessScale: 1.6)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Thick',
                        scale: 2.4,
                        current: _current.lineThicknessScale,
                        onTap: () => _update(_current.copyWith(lineThicknessScale: 2.4)),
                        theme: theme,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // 2. Measurement Size Section
                  _buildSectionHeader(
                    icon: Icons.straighten,
                    title: 'Dimension Size (L: ...)',
                    valueLabel: '${(_current.measurementScale * 100).toStringAsFixed(0)}%',
                    theme: theme,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.text_decrease, size: 16, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: _current.measurementScale,
                          min: 0.5,
                          max: 2.5,
                          divisions: 20,
                          label: '${(_current.measurementScale * 100).toStringAsFixed(0)}%',
                          onChanged: (val) {
                            _update(_current.copyWith(measurementScale: val));
                          },
                        ),
                      ),
                      const Icon(Icons.text_increase, size: 16, color: Colors.grey),
                    ],
                  ),
                  // Quick presets for Measurement Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPresetChip(
                        label: 'Small (70%)',
                        scale: 0.7,
                        current: _current.measurementScale,
                        onTap: () => _update(_current.copyWith(measurementScale: 0.7)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Normal (100%)',
                        scale: 1.0,
                        current: _current.measurementScale,
                        onTap: () => _update(_current.copyWith(measurementScale: 1.0)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Large (140%)',
                        scale: 1.4,
                        current: _current.measurementScale,
                        onTap: () => _update(_current.copyWith(measurementScale: 1.4)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Extra (180%)',
                        scale: 1.8,
                        current: _current.measurementScale,
                        onTap: () => _update(_current.copyWith(measurementScale: 1.8)),
                        theme: theme,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // 3. Point Size Section
                  _buildSectionHeader(
                    icon: Icons.scatter_plot,
                    title: 'Point Size',
                    valueLabel: '${_current.pointSize.toStringAsFixed(1)} px',
                    theme: theme,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        alignment: Alignment.center,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _current.pointSize,
                          min: 1.5,
                          max: 12.0,
                          divisions: 21,
                          label: '${_current.pointSize.toStringAsFixed(1)} px',
                          onChanged: (val) {
                            _update(_current.copyWith(pointSize: val));
                          },
                        ),
                      ),
                      Container(
                        width: 16,
                        alignment: Alignment.center,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Quick presets for Point Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPresetChip(
                        label: 'Small (2.5px)',
                        scale: 2.5,
                        current: _current.pointSize,
                        onTap: () => _update(_current.copyWith(pointSize: 2.5)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Normal (4px)',
                        scale: 4.0,
                        current: _current.pointSize,
                        onTap: () => _update(_current.copyWith(pointSize: 4.0)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Large (6.5px)',
                        scale: 6.5,
                        current: _current.pointSize,
                        onTap: () => _update(_current.copyWith(pointSize: 6.5)),
                        theme: theme,
                      ),
                      _buildPresetChip(
                        label: 'Heavy (9px)',
                        scale: 9.0,
                        current: _current.pointSize,
                        onTap: () => _update(_current.copyWith(pointSize: 9.0)),
                        theme: theme,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // 4. Point Marker Style Section
                  Row(
                    children: [
                      Icon(Icons.grain, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Point Marker Style',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DxfPointStyle.values.map((style) {
                      final isSelected = style == _current.pointStyle;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _update(_current.copyWith(pointStyle: style)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor.withValues(alpha: 0.3),
                              width: isSelected ? 1.6 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                style.symbol,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? theme.colorScheme.primary : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                style.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? theme.colorScheme.primary : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String valueLabel,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            valueLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required double scale,
    required double current,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isSelected = (current - scale).abs() < 0.05;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
