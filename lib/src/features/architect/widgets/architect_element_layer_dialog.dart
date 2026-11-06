// === SECTION: ARCHITECT ELEMENT LAYER PICKER ===

import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';

Future<String?> showArchitectElementLayerPicker(
  BuildContext context, {
  required ArchitectProject project,
  required String currentLayerId,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) {
    final l = sheetContext.l10n;
    final layers = project.effectiveLayers;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const AppIcon(AppIconId.layers, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l.architectChangeLayer,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: layers.length,
                itemBuilder: (ctx, index) {
                  final layer = layers[index];
                  final isCurrent = layer.id == currentLayerId;
                  final color = layer.colorValue != null
                      ? Color(layer.colorValue!)
                      : Colors.grey;

                  return ListTile(
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      layer.localizedName(l),
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? Colors.cyanAccent : null,
                      ),
                    ),
                    subtitle: Text(layer.id, style: const TextStyle(fontSize: 11)),
                    trailing: isCurrent
                        ? const Icon(Icons.check, color: Colors.cyanAccent)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(layer.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  },
);
