import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_math.dart';

/// Modal bottom sheet showing drawing metadata, extents, and entity breakdown.
class DxfInfoSheet extends StatelessWidget {
  final DxfDocument document;
  final String fileName;
  final int fileSizeBytes;

  const DxfInfoSheet({
    super.key,
    required this.document,
    required this.fileName,
    required this.fileSizeBytes,
  });

  static Future<void> show({
    required BuildContext context,
    required DxfDocument document,
    required String fileName,
    required int fileSizeBytes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DxfInfoSheet(
        document: document,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = document.bounds;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
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
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Drawing Properties & Statistics',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Quick Summary Cards
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      icon: Icons.layers_outlined,
                      label: 'Layers',
                      value: document.totalLayers.toString(),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      icon: Icons.category_outlined,
                      label: 'Entities',
                      value: document.totalEntities.toString(),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      icon: Icons.grid_view_outlined,
                      label: 'Blocks',
                      value: document.totalBlocks.toString(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Extents & Dimensions
                _buildSectionHeader(context, 'Drawing Dimensions (Extents)'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Drawing Units', '${document.unit.label} (${document.unit.symbol})'),
                      const Divider(height: 16),
                      _buildInfoRow('Width (ΔX)', '${DxfMath.formatCadNumber(document.width)} ${document.unit.symbol} (${DxfMath.formatDistance(document.width, unit: document.unit)} m)'),
                      const Divider(height: 16),
                      _buildInfoRow('Height (ΔY)', '${DxfMath.formatCadNumber(document.height)} ${document.unit.symbol} (${DxfMath.formatDistance(document.height, unit: document.unit)} m)'),
                      const Divider(height: 16),
                      _buildInfoRow('X Range', '${DxfMath.formatCadNumber(bounds.left)} → ${DxfMath.formatCadNumber(bounds.right)}'),
                      const Divider(height: 16),
                      _buildInfoRow('Y Range', '${DxfMath.formatCadNumber(bounds.top)} → ${DxfMath.formatCadNumber(bounds.bottom)}'),
                      const Divider(height: 16),
                      _buildInfoRow('File Size', _formatFileSize(fileSizeBytes)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Entity Breakdown
                _buildSectionHeader(context, 'Entity Breakdown'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: document.entityStats.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
