import 'package:flutter/material.dart';
import '../models/dxf_color_table.dart';
import '../models/dxf_models.dart';

/// Context menu bottom sheet displayed upon Long-Press or Right-Click on a CAD entity.
/// Displays layer name with direct options to Hide or Isolate the layer.
class DxfEntityContextSheet extends StatelessWidget {
  final DxfEntity entity;
  final DxfDocument document;
  final bool isDark;
  final VoidCallback onHideLayer;
  final VoidCallback onIsolateLayer;
  final VoidCallback onShowAllLayers;
  final VoidCallback onOpenLayerManager;

  const DxfEntityContextSheet({
    super.key,
    required this.entity,
    required this.document,
    required this.isDark,
    required this.onHideLayer,
    required this.onIsolateLayer,
    required this.onShowAllLayers,
    required this.onOpenLayerManager,
  });

  static Future<void> show({
    required BuildContext context,
    required DxfEntity entity,
    required DxfDocument document,
    required bool isDark,
    required VoidCallback onHideLayer,
    required VoidCallback onIsolateLayer,
    required VoidCallback onShowAllLayers,
    required VoidCallback onOpenLayerManager,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DxfEntityContextSheet(
        entity: entity,
        document: document,
        isDark: isDark,
        onHideLayer: onHideLayer,
        onIsolateLayer: onIsolateLayer,
        onShowAllLayers: onShowAllLayers,
        onOpenLayerManager: onOpenLayerManager,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layerName = entity.layer.trim().isEmpty ? '0 (Default)' : entity.layer;
    final layer = document.layers[entity.layer];

    final layerColor = DxfColorTable.resolveColor(
      colorIndex: entity.colorIndex,
      trueColor: entity.trueColor,
      layerColor: layer != null
          ? DxfColorTable.resolveColor(
              colorIndex: layer.colorIndex,
              trueColor: layer.trueColor,
              isDarkBackground: isDark,
            )
          : null,
      isDarkBackground: isDark,
    );

    // Check if any layers are currently hidden
    final bool hasHiddenLayers = document.layers.values.any((l) => !l.isVisible);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2433) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Layer Header Card (showing only Layer name and color)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A26) : const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E6EE),
                  ),
                ),
                child: Row(
                  children: [
                    // Layer color circle
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: layerColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white70,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: layerColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Layer name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LAYER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            layerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_buildEntityDetailsCard(context) != null) ...[
                _buildEntityDetailsCard(context)!,
              ],

              // Action 1: Hide this Layer
              _buildActionButton(
                context,
                icon: Icons.visibility_off_outlined,
                iconColor: const Color(0xFFFF5252),
                label: 'Hide Layer "$layerName"',
                subLabel: 'Temporarily hide all entities on this layer',
                onTap: () {
                  Navigator.pop(context);
                  onHideLayer();
                },
              ),

              const SizedBox(height: 8),

              // Action 2: Isolate this Layer
              _buildActionButton(
                context,
                icon: Icons.filter_center_focus_outlined,
                iconColor: const Color(0xFF00E5FF),
                label: 'Isolate Layer "$layerName"',
                subLabel: 'Hide all other layers and keep only this layer visible',
                onTap: () {
                  Navigator.pop(context);
                  onIsolateLayer();
                },
              ),

              if (hasHiddenLayers) ...[
                const SizedBox(height: 8),
                // Action 3: Show All Layers
                _buildActionButton(
                  context,
                  icon: Icons.visibility_outlined,
                  iconColor: const Color(0xFF00E676),
                  label: 'Show All Layers',
                  subLabel: 'Unhide all previously hidden layers',
                  onTap: () {
                    Navigator.pop(context);
                    onShowAllLayers();
                  },
                ),
              ],

              const SizedBox(height: 8),

              // Action 4: Open CAD Layer Manager
              _buildActionButton(
                context,
                icon: Icons.layers_outlined,
                iconColor: const Color(0xFFFFD600),
                label: 'CAD Layer Manager',
                subLabel: 'View entity counts, lineweights, and layer controls',
                onTap: () {
                  Navigator.pop(context);
                  onOpenLayerManager();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2B384E) : const Color(0xFFEAEDF2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildEntityDetailsCard(BuildContext context) {
    if (entity is DxfInsert) {
      final insert = entity as DxfInsert;
      return Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A26) : const Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E6EE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.widgets_outlined,
                  size: 18,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'BLOCK: ${insert.blockName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pos: (${insert.insertPoint.dx.toStringAsFixed(1)}, ${insert.insertPoint.dy.toStringAsFixed(1)})'
              '${insert.rotationDeg != 0 ? ' • Rot: ${insert.rotationDeg.toStringAsFixed(1)}°' : ''}'
              '${(insert.scaleX != 1.0 || insert.scaleY != 1.0) ? ' • Scale: ${insert.scaleX.toStringAsFixed(2)}x' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (insert.attributes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E6EE),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'ATTRIBUTES (${insert.attributes.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    children: insert.attributes.map((attr) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blueGrey.shade900 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                attr.tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attr.value.isNotEmpty ? attr.value : '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (attr.isInvisible)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.visibility_off_outlined,
                                  size: 13,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else if (entity is DxfText && (entity as DxfText).tag != null) {
      final text = entity as DxfText;
      return Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A26) : const Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E6EE),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.blueGrey.shade900 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text.tag!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return null;
  }
}
