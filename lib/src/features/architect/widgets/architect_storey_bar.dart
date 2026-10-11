import 'package:flutter/material.dart';
import '../models/architect_project.dart';

/// One compact elevation per tab; custom names remain available in tooltips.
class ArchitectStoreyBar extends StatelessWidget {
  final ArchitectProject project;
  final ValueChanged<String> onStoreySelected;
  const ArchitectStoreyBar({
    super.key,
    required this.project,
    required this.onStoreySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (project.storeys.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        itemCount: project.storeys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final storey = project.storeys[index];
          final active = storey.id == project.activeStoreyId;
          final label = storey.elevationLabel;
          final description = storey.name.contains(label)
              ? storey.name
              : '${storey.name} · $label';
          return Tooltip(
            message: description,
            child: Material(
              color: active ? const Color(0xFF00E5FF) : const Color(0xFF282834),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onStoreySelected(storey.id),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.black : Colors.white70,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
