import 'package:flutter/material.dart';
import '../models/coordinate_system.dart';
import '../services/coordinate_system_service.dart';

/// Modal dialog for selecting the application-wide default Coordinate Reference System.
class CoordinateSettingsDialog extends StatefulWidget {
  const CoordinateSettingsDialog({super.key});

  static Future<CoordinateSystem?> show(BuildContext context) {
    return showDialog<CoordinateSystem>(
      context: context,
      builder: (context) => const CoordinateSettingsDialog(),
    );
  }

  @override
  State<CoordinateSettingsDialog> createState() => _CoordinateSettingsDialogState();
}

class _CoordinateSettingsDialogState extends State<CoordinateSettingsDialog> {
  late CoordinateSystem _selected;
  String _searchQuery = '';
  String _selectedRegion = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _regions = const ['All', 'Balkans', 'Europe', 'Americas', 'Global'];

  @override
  void initState() {
    super.initState();
    _selected = CoordinateSystemService.activeSystemNotifier.value;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoordinateSystem> get _filteredSystems {
    return CoordinateSystem.values.where((crs) {
      final matchesRegion = _selectedRegion == 'All' || crs.region == _selectedRegion;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          crs.name.toLowerCase().contains(q) ||
          crs.country.toLowerCase().contains(q) ||
          crs.epsg.toLowerCase().contains(q) ||
          crs.description.toLowerCase().contains(q);
      return matchesRegion && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredSystems;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.public_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Coordinate Reference Systems',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Official Geodetic & Cadastral Systems (${CoordinateSystem.values.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by country, projection, or EPSG code...',
                hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
            const SizedBox(height: 8),

            // Region Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _regions.map((region) {
                  final isSelected = _selectedRegion == region;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(region),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRegion = region);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Systems List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No coordinate system found for "$_searchQuery"',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final crs = filtered[index];
                        final isCurrent = crs == _selected;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() => _selected = crs);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? theme.colorScheme.primary
                                      : theme.dividerColor.withValues(alpha: 0.35),
                                  width: isCurrent ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Radio<CoordinateSystem>(
                                    value: crs,
                                    groupValue: _selected,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selected = val);
                                      }
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              crs.countryFlag,
                                              style: const TextStyle(fontSize: 15),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                crs.name,
                                                style: TextStyle(
                                                  fontWeight:
                                                      isCurrent ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isCurrent
                                                      ? theme.colorScheme.primary
                                                      : theme.textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                            ),
                                            if (crs.isDefault)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Default',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.09),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                crs.country,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                crs.epsg,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: 'monospace',
                                                  color: theme.textTheme.bodySmall?.color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          crs.description,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textTheme.bodyMedium?.color
                                                ?.withValues(alpha: 0.65),
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
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Save Selection'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            await CoordinateSystemService.setCoordinateSystem(_selected);
            navigator.pop(_selected);
          },
        ),
      ],
    );
  }
}
