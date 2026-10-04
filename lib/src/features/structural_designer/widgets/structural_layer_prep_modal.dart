import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/models/dxf_color_table.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../analysis/structural_underlay_filter.dart';
import '../analysis/wall_axis_detector.dart';
import '../models/wall_axis_models.dart';

/// Modal bottom sheet presented upon entering the BIM Structural Designer module,
/// allowing the engineer to prepare and isolate structural layers (walls, columns, axes)
/// and hide architectural clutter (furniture, hatches, dimensions).
/// Displays a visual progress spinner during multi-second repaints.
class StructuralLayerPrepModal extends StatefulWidget {
  final DxfDocument document;
  final VoidCallback onLayersChanged;
  final ValueChanged<WallAxisDetectionResult>? onAxesDetected;

  const StructuralLayerPrepModal({
    super.key,
    required this.document,
    required this.onLayersChanged,
    this.onAxesDetected,
  });

  /// Displays the layer preparation bottom sheet. Returns true if user confirmed.
  static Future<bool?> show({
    required BuildContext context,
    required DxfDocument document,
    required VoidCallback onLayersChanged,
    ValueChanged<WallAxisDetectionResult>? onAxesDetected,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StructuralLayerPrepModal(
        document: document,
        onLayersChanged: onLayersChanged,
        onAxesDetected: onAxesDetected,
      ),
    );
  }

  @override
  State<StructuralLayerPrepModal> createState() => _StructuralLayerPrepModalState();
}

class _StructuralLayerPrepModalState extends State<StructuralLayerPrepModal> {
  late final Map<String, int> _layerCounts;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _layerCounts = {};
    for (final layerName in widget.document.layers.keys) {
      _layerCounts[layerName] = 0;
    }
    for (final entity in widget.document.entities) {
      final name = entity.layer.trim();
      _layerCounts[name] = (_layerCounts[name] ?? 0) + 1;
    }
    for (final block in widget.document.blocks.values) {
      for (final entity in block.entities) {
        final name = entity.layer.trim();
        _layerCounts[name] = (_layerCounts[name] ?? 0) + 1;
      }
    }
  }

  Future<void> _applyLayerChange(VoidCallback action) async {
    setState(() => _isUpdating = true);
    // Allow UI to paint the progress indicator before heavy re-filtering
    await Future<void>.delayed(const Duration(milliseconds: 150));
    action();
    widget.onLayersChanged();
    if (mounted) {
      setState(() => _isUpdating = false);
    }
  }

  void _isolateStructural() {
    _applyLayerChange(() {
      final visibleSet = StructuralUnderlayFilter.filterLayers(
        layers: widget.document.layers.values,
        entities: widget.document.entities,
        blocks: widget.document.blocks,
      );
      for (final layer in widget.document.layers.values) {
        final shouldBeVisible = visibleSet.contains(layer.name);
        layer.isVisible = shouldBeVisible;
        if (shouldBeVisible && layer.isFrozen) {
          layer.isFrozen = false;
        }
      }
    });
  }

  void _toggleAll(bool visible) {
    _applyLayerChange(() {
      for (final layer in widget.document.layers.values) {
        layer.isVisible = visible;
        if (visible && layer.isFrozen) {
          layer.isFrozen = false;
        }
      }
    });
  }

  void _toggleSingleLayer(DxfLayer layer) {
    _applyLayerChange(() {
      layer.isVisible = !layer.isVisible;
      if (layer.isVisible && layer.isFrozen) {
        layer.isFrozen = false;
      }
    });
  }

  void _autoDetectAndGenerateAxes() {
    _applyLayerChange(() {
      final result = WallAxisDetector.detect(widget.document);
      if (!result.hasWallsFound) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.noWallsDetected),
              backgroundColor: const Color(0xFF33333D),
            ),
          );
        }
        return;
      }
      WallAxisDetector.applyToDocument(widget.document, result);
      widget.onAxesDetected?.call(result);
      _layerCounts.clear();
      for (final layerName in widget.document.layers.keys) {
        _layerCounts[layerName] = 0;
      }
      for (final entity in widget.document.entities) {
        final name = entity.layer.trim();
        _layerCounts[name] = (_layerCounts[name] ?? 0) + 1;
      }
      if (mounted && widget.onAxesDetected == null) {
        final isBg = Localizations.localeOf(context).languageCode == 'bg';
        final axes = WallAxisDetector.convertToStructuralGridAxes(
          result.snappedCenterlines,
          isBulgarian: isBg,
          scale: result.detectedScale,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.wallsAndAxesGeneratedSuccess(
                axes.length,
                result.wallContourSegments.length,
                result.detectedUnitName,
              ),
            ),
            backgroundColor: const Color(0xFF1E88E5),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedLayers = widget.document.layers.values
        .where((l) => (_layerCounts[l.name] ?? 0) > 0 || widget.document.layers.length == 1)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final totalVisible = sortedLayers.where((l) => l.isVisible).length;

    return Stack(
      children: [
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.layers_outlined,
                        color: Color(0xFF00E5FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.layersPreparationTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalVisible / ${sortedLayers.length} ${context.l10n.showAllLayers.toLowerCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Subtitle info banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  context.l10n.layersPreparationSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    height: 1.3,
                  ),
                ),
              ),

              // Quick action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.filter_alt_rounded, size: 16, color: Color(0xFF00E5FF)),
                        label: Text(
                          context.l10n.isolateStructuralLayers,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isUpdating ? null : _isolateStructural,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.white70),
                        label: Text(
                          context.l10n.showAllLayers,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isUpdating ? null : () => _toggleAll(true),
                      ),
                    ),
                  ],
                ),
              ),

              // Auto-detect walls & axes action button
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFF5252)),
                    label: Text(
                      context.l10n.autoDetectWallsAndAxes,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF5252),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isUpdating ? null : _autoDetectAndGenerateAxes,
                  ),
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Layer List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: sortedLayers.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final layer = sortedLayers[index];
                    final count = _layerCounts[layer.name] ?? 0;
                    final isWhite = StructuralUnderlayFilter.isWhiteLayer(layer);
                    final color = DxfColorTable.resolveColor(
                      colorIndex: layer.colorIndex,
                      trueColor: layer.trueColor,
                      isDarkBackground: true,
                    );

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isUpdating ? null : () => _toggleSingleLayer(layer),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Checkbox(
                                value: layer.isVisible,
                                activeColor: const Color(0xFF00E5FF),
                                checkColor: Colors.black,
                                onChanged: _isUpdating
                                    ? null
                                    : (_) => _toggleSingleLayer(layer),
                              ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white30, width: 1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            layer.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isWhite ? FontWeight.bold : FontWeight.normal,
                                              color: layer.isVisible ? Colors.white : Colors.white38,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isWhite) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'WALL',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Color(0xFF00E5FF),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '$count elements',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: layer.isVisible ? Colors.white54 : Colors.white24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Confirm & Load Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                    label: Text(
                      context.l10n.loadStructuralModule,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Updating Loading Indicator Overlay
        if (_isUpdating)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252732),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        context.l10n.updatingLayers,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
