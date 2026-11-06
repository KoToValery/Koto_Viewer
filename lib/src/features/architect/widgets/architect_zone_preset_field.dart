import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// A dropdown of presets that also preserves arbitrary user-entered values.
class ArchitectZonePresetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final List<String> presets;
  const ArchitectZonePresetField({
    super.key,
    required this.controller,
    required this.label,
    required this.presets,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 14,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      border: const OutlineInputBorder(),
      isDense: false,
      suffixIcon: PopupMenuButton<String>(
        tooltip: label,
        icon: AppIcon(
          AppIconId.expandMore,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onSelected: (value) => controller.text = value,
        itemBuilder: (_) => [
          for (final preset in presets.toSet())
            PopupMenuItem(value: preset, child: Text(preset)),
        ],
      ),
    ),
  );
}
