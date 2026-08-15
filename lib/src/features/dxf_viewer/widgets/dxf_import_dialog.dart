import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/coordinate_system.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_math.dart';

enum DxfImportAction {
  importOriginal,
  importCentered,
}

/// Dialog displayed before importing a DXF file to inspect entities and verify coordinates.
class DxfImportDialog extends StatelessWidget {
  final File file;
  final DxfDocument currentDoc;
  final DxfDocument importedDoc;
  final CoordinateSystem activeCrs;

  const DxfImportDialog({
    super.key,
    required this.file,
    required this.currentDoc,
    required this.importedDoc,
    required this.activeCrs,
  });

  static Future<DxfImportAction?> show({
    required BuildContext context,
    required File file,
    required DxfDocument currentDoc,
    required DxfDocument importedDoc,
    required CoordinateSystem activeCrs,
  }) {
    return showDialog<DxfImportAction>(
      context: context,
      builder: (context) => DxfImportDialog(
        file: file,
        currentDoc: currentDoc,
        importedDoc: importedDoc,
        activeCrs: activeCrs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);

    final currentBounds = currentDoc.bounds;
    final importedBounds = importedDoc.bounds;

    final importedCrs = CoordinateSystem.detectFromBounds(importedBounds);

    // Check if coordinates match or have similar scale / overlap
    final bool boundsOverlap = currentBounds.overlaps(importedBounds);
    final double distCenters = (currentBounds.center - importedBounds.center).distance;
    final double maxDim = [
      currentBounds.width,
      currentBounds.height,
      importedBounds.width,
      importedBounds.height,
    ].reduce((a, b) => a > b ? a : b);

    final bool coordsMatch = boundsOverlap || distCenters <= (maxDim * 3.0 + 5000.0);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.file_download_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Import DXF into Drawing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 18, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$fileSizeKb KB',
                          style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.layers_outlined,
                          label: '${importedDoc.totalLayers} Layers',
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          icon: Icons.category_outlined,
                          label: '${importedDoc.totalEntities} Entities',
                          theme: theme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Coordinate Verification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Verification Status Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: coordsMatch
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: coordsMatch
                        ? Colors.green.withValues(alpha: 0.4)
                        : Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      coordsMatch ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      color: coordsMatch ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coordsMatch
                                ? 'Coordinates Match Current Drawing'
                                : 'Coordinate Range Discrepancy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: coordsMatch ? Colors.green.shade700 : Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coordsMatch
                                ? 'Imported entities will align at their exact geodetic/CAD coordinates.'
                                : 'The coordinates of the imported file differ from the active drawing. It will be placed at its original coordinates.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Coordinate Extents Comparison
              _buildExtentsRow(
                title: 'Current Drawing (${activeCrs.name}):',
                minX: currentBounds.left,
                maxX: currentBounds.right,
                minY: currentBounds.top,
                maxY: currentBounds.bottom,
                theme: theme,
              ),
              const SizedBox(height: 8),
              _buildExtentsRow(
                title: 'Imported File (Detected: ${importedCrs.name}):',
                minX: importedBounds.left,
                maxX: importedBounds.right,
                minY: importedBounds.top,
                maxY: importedBounds.bottom,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Import DXF'),
          onPressed: () => Navigator.pop(context, DxfImportAction.importOriginal),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildExtentsRow({
    required String title,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            'X: [${DxfMath.formatDistance(minX)} .. ${DxfMath.formatDistance(maxX)}]\n'
            'Y: [${DxfMath.formatDistance(minY)} .. ${DxfMath.formatDistance(maxY)}]',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
