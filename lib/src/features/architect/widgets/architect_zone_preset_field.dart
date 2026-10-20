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
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0x22FFFFFF),
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: PopupMenuButton<String>(
        tooltip: label,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        onSelected: (value) => controller.text = value,
        itemBuilder: (_) => [
          for (final preset in presets.toSet())
            PopupMenuItem(value: preset, child: Text(preset)),
        ],
      ),
    ),
  );
}
