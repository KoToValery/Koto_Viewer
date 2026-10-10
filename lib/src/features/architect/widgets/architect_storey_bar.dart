import 'package:flutter/material.dart';
import '../models/architect_project.dart';

/// Horizontal storey switcher bar displaying elevation badges.
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
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        itemCount: project.storeys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {

          final storey = project.storeys[index];
          final isActive = storey.id == project.activeStoreyId;

          return Material(
            color: isActive
                ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
                : const Color(0xFF282834),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onStoreySelected(storey.id),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF00E5FF)
                        : Colors.white.withValues(alpha: 0.1),
                    width: isActive ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      storey.name,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF00E5FF)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        storey.elevationLabel,
                        style: TextStyle(
                          color: isActive ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
