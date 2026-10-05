import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/models/dxf_color_table.dart';
import '../../dxf_viewer/models/dxf_models.dart';

/// Modal bottom sheet allowing the structural engineer to arbitrarily customize which
/// CAD layers are included in the Underlay Filter ("Филтър подложка").
class UnderlayFilterConfigSheet extends StatefulWidget {
  final DxfDocument document;
  final Set<String> activeFilterLayers;
  final ValueChanged<Set<String>> onFilterLayersChanged;
  final VoidCallback onResetToAuto;
  final bool isDark;

  const UnderlayFilterConfigSheet({
    super.key,
    required this.document,
    required this.activeFilterLayers,
    required this.onFilterLayersChanged,
    required this.onResetToAuto,
    this.isDark = true,
  });

  static Future<void> show({
    required BuildContext context,
    required DxfDocument document,
    required Set<String> activeFilterLayers,
    required ValueChanged<Set<String>> onFilterLayersChanged,
    required VoidCallback onResetToAuto,
    bool isDark = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnderlayFilterConfigSheet(
        document: document,
        activeFilterLayers: activeFilterLayers,
        onFilterLayersChanged: onFilterLayersChanged,
        onResetToAuto: onResetToAuto,
        isDark: isDark,
      ),
    );
  }

  @override
  State<UnderlayFilterConfigSheet> createState() => _UnderlayFilterConfigSheetState();
}

class _UnderlayFilterConfigSheetState extends State<UnderlayFilterConfigSheet> {
  late Set<String> _selectedLayers;
  late final Map<String, int> _layerCounts;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedLayers = Set<String>.from(widget.activeFilterLayers);

    // Precalculate entity counts
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleLayer(String layerName, bool value) {
    setState(() {
      if (value) {
        _selectedLayers.add(layerName);
      } else {
        _selectedLayers.remove(layerName);
      }
    });
    widget.onFilterLayersChanged(_selectedLayers);
  }

  void _selectAll() {
    setState(() {
      _selectedLayers = widget.document.layers.keys.toSet();
    });
    widget.onFilterLayersChanged(_selectedLayers);
  }

  void _clearAll() {
    setState(() {
      _selectedLayers.clear();
    });
    widget.onFilterLayersChanged(_selectedLayers);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allLayers = widget.document.layers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final filteredLayers = _searchQuery.isEmpty
        ? allLayers
        : allLayers.where((l) => l.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1B2433) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x3300E5FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.filter_alt_rounded, color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.underlayFilterTitle,
                          style: TextStyle(
                            color: widget.isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.underlayFilterSubtitle,
                          style: TextStyle(
                            color: widget.isDark ? Colors.white60 : Colors.black54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Quick actions bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF00E5FF)),
                      label: Text(l10n.underlayFilterAutoReset, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        widget.onResetToAuto();
                        Navigator.pop(context);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.select_all_rounded, size: 14),
                      label: Text(l10n.underlayFilterSelectAll, style: const TextStyle(fontSize: 11)),
                      onPressed: _selectAll,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.clear_all_rounded, size: 14),
                      label: Text(l10n.underlayFilterClearAll, style: const TextStyle(fontSize: 11)),
                      onPressed: _clearAll,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),

            // Search input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchLayers,
                  hintStyle: TextStyle(color: widget.isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: widget.isDark ? Colors.white54 : Colors.black54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: widget.isDark ? const Color(0xFF131A26) : const Color(0xFFF3F5F8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: Colors.white10),

            // Layers list
            Expanded(
              child: ListView.separated(
                itemCount: filteredLayers.length,
                padding: const EdgeInsets.symmetric(vertical: 4),
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: Colors.white10),
                itemBuilder: (context, index) {
                  final layer = filteredLayers[index];
                  final isIncluded = _selectedLayers.contains(layer.name);
                  final entityCount = _layerCounts[layer.name] ?? 0;

                  final color = DxfColorTable.resolveColor(
                    colorIndex: layer.colorIndex,
                    trueColor: layer.trueColor,
                    isDarkBackground: widget.isDark,
                  );

                  return SwitchListTile(
                    value: isIncluded,
                    onChanged: (val) => _toggleLayer(layer.name, val),
                    secondary: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white70,
                          width: 1.5,
                        ),
                      ),
                    ),
                    title: Text(
                      layer.name,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$entityCount entities',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                    activeThumbColor: const Color(0xFF00E5FF),
                    activeTrackColor: const Color(0x6600E5FF),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
