import 'package:flutter/material.dart';
import '../models/ifc_model.dart';

/// Modal bottom sheet for filtering IFC BIM models by Storey levels and Element categories.
class IfcBimSheet extends StatefulWidget {
  final IfcModel ifcModel;
  final VoidCallback onFiltersChanged;
  final bool isDark;

  const IfcBimSheet({
    super.key,
    required this.ifcModel,
    required this.onFiltersChanged,
    required this.isDark,
  });

  static Future<void> show({
    required BuildContext context,
    required IfcModel ifcModel,
    required VoidCallback onFiltersChanged,
    required bool isDark,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IfcBimSheet(
        ifcModel: ifcModel,
        onFiltersChanged: onFiltersChanged,
        isDark: isDark,
      ),
    );
  }

  @override
  State<IfcBimSheet> createState() => _IfcBimSheetState();
}

class _IfcBimSheetState extends State<IfcBimSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.ifcModel.layers.isNotEmpty ? 4 : 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final model = widget.ifcModel;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
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
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
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
                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.domain_rounded,
                      color: Color(0xFF16A34A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.projectName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${model.schema} • ${model.elements.length} elements',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        model.showAll();
                      });
                      widget.onFiltersChanged();
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Show All'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: isDark ? const Color(0xFF00E5FF) : Theme.of(context).primaryColor,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              tabs: [
                Tab(
                  icon: const Icon(Icons.layers_rounded, size: 20),
                  text: 'Storeys (${model.storeys.length})',
                ),
                Tab(
                  icon: const Icon(Icons.category_rounded, size: 20),
                  text: 'Categories (${model.categories.length})',
                ),
                if (model.layers.isNotEmpty)
                  Tab(
                    icon: const Icon(Icons.view_agenda_rounded, size: 20),
                    text: 'Layers (${model.layers.where((l) => (model.layerCounts[l] ?? 0) > 0).length})',
                  ),
                const Tab(
                  icon: Icon(Icons.info_outline_rounded, size: 20),
                  text: 'Model Info',
                ),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStoreysTab(isDark),
                  _buildCategoriesTab(isDark),
                  if (model.layers.isNotEmpty) _buildLayersTab(isDark),
                  _buildInfoTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreysTab(bool isDark) {
    final model = widget.ifcModel;
    final storeyCounts = model.storeyCounts;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: model.storeys.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final storey = model.storeys[index];
        final isVisible = !model.hiddenStoreys.contains(storey.name);
        final count = storeyCounts[storey.name] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A26) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isVisible
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              child: Icon(
                Icons.stairs_rounded,
                color: isVisible ? const Color(0xFF00E5FF) : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              storey.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Elevation: ${_formatElevation(storey.elevation)} • $count elements',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Isolate Storey',
                  icon: const Icon(Icons.filter_center_focus_rounded, size: 20),
                  color: isDark ? Colors.white70 : Colors.black54,
                  onPressed: () {
                    setState(() {
                      model.isolateStorey(storey.name);
                    });
                    widget.onFiltersChanged();
                  },
                ),
                Switch(
                  value: isVisible,
                  activeThumbColor: const Color(0xFF00E5FF),
                  onChanged: (val) {
                    setState(() {
                      model.toggleStorey(storey.name, val);
                    });
                    widget.onFiltersChanged();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(bool isDark) {
    final model = widget.ifcModel;
    final catCounts = model.categoryCounts;
    final sortedCategories = model.categories.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sortedCategories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cat = sortedCategories[index];
        final isVisible = !model.hiddenCategories.contains(cat);
        final count = catCounts[cat] ?? 0;
        final color = IfcModel.getCategoryColor(cat);
        final icon = IfcModel.getCategoryIcon(cat);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A26) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              cat,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              '$count items',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Isolate Category',
                  icon: const Icon(Icons.filter_center_focus_rounded, size: 20),
                  color: isDark ? Colors.white70 : Colors.black54,
                  onPressed: () {
                    setState(() {
                      model.isolateCategory(cat);
                    });
                    widget.onFiltersChanged();
                  },
                ),
                Switch(
                  value: isVisible,
                  activeThumbColor: color,
                  onChanged: (val) {
                    setState(() {
                      model.toggleCategory(cat, val);
                    });
                    widget.onFiltersChanged();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayersTab(bool isDark) {
    final model = widget.ifcModel;
    final layerCounts = model.layerCounts;
    final sortedLayers = model.layers.where((l) => (layerCounts[l] ?? 0) > 0).toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sortedLayers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final layer = sortedLayers[index];
        final isVisible = !model.hiddenLayers.contains(layer);
        final count = layerCounts[layer] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A26) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isVisible
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              child: Icon(
                Icons.view_agenda_rounded,
                color: isVisible ? const Color(0xFF00E5FF) : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              layer,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              '$count elements',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Isolate Layer',
                  icon: const Icon(Icons.filter_center_focus_rounded, size: 20),
                  color: isDark ? Colors.white70 : Colors.black54,
                  onPressed: () {
                    setState(() {
                      model.isolateLayer(layer);
                    });
                    widget.onFiltersChanged();
                  },
                ),
                Switch(
                  value: isVisible,
                  activeThumbColor: const Color(0xFF00E5FF),
                  onChanged: (val) {
                    setState(() {
                      model.toggleLayer(layer, val);
                    });
                    widget.onFiltersChanged();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(bool isDark) {
    final model = widget.ifcModel;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Project Name', model.projectName, isDark),
          const Divider(),
          _buildInfoRow('BIM Schema', model.schema, isDark),
          const Divider(),
          _buildInfoRow('Total Elements', '${model.elements.length} building items', isDark),
          const Divider(),
          _buildInfoRow('Total Storeys', '${model.storeys.length} floor levels', isDark),
          const Divider(),
          _buildInfoRow('Total Triangles', '${model.totalTriangles} 3D facets', isDark),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Apply & Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
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

  String _formatElevation(double val) {
    if (val.abs() >= 1000.0) {
      return '${val >= 0 ? '+' : ''}${(val / 1000.0).toStringAsFixed(2)} m';
    }
    return '${val >= 0 ? '+' : ''}${val.toStringAsFixed(2)} m';
  }
}
