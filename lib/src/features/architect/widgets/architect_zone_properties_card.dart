import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';

/// Floating property inspector card for the currently selected functional zone.
class ArchitectZonePropertiesCard extends StatelessWidget {
  final ArchitectZone zone;
  final ValueChanged<ArchitectZone> onZoneUpdated;
  final VoidCallback onDeleteZone;
  final VoidCallback onClose;

  const ArchitectZonePropertiesCard({
    super.key,
    required this.zone,
    required this.onZoneUpdated,
    required this.onDeleteZone,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xF21C1E26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zone.color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Category Icon, Name edit, Area, Delete, Close
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(zone.category.icon, size: 18, color: zone.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _showEditNameDialog(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            zone.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_rounded, size: 14, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              ),
              // Area & Perimeter Chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: zone.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${zone.area.toStringAsFixed(2)} m²',
                  style: TextStyle(
                    color: zone.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: l10n.architectDeleteZone,
                onPressed: onDeleteZone,
                visualDensity: VisualDensity.compact,
              ),
              // Close / Deselect Button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Category Quick Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final cat in ArchitectZoneCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      avatar: Icon(cat.icon, size: 12, color: cat.color),
                      label: Text(
                        cat.defaultBgName,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: zone.category == cat,
                      onSelected: (sel) {
                        if (sel) {
                          onZoneUpdated(zone.copyWith(
                            category: cat,
                            name: zone.name == zone.category.defaultBgName
                                ? cat.defaultBgName
                                : zone.name,
                          ));
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final l10n = context.l10n;
    final controller = TextEditingController(text: zone.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22242E),
        title: Text(
          l10n.architectZoneName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: zone.category.defaultBgName,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF161820),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отказ'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                onZoneUpdated(zone.copyWith(name: newName));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Запази'),
          ),
        ],
      ),
    );
  }
}
