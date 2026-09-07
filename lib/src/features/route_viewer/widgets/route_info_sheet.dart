import 'package:flutter/material.dart';
import '../models/geo_route_models.dart';

class RouteInfoSheet extends StatelessWidget {
  final GeoRouteDocument document;
  final String fileName;
  final ValueChanged<GeoWaypoint>? onSelectWaypoint;

  const RouteInfoSheet({
    super.key,
    required this.document,
    required this.fileName,
    this.onSelectWaypoint,
  });

  static Future<void> show({
    required BuildContext context,
    required GeoRouteDocument document,
    required String fileName,
    ValueChanged<GeoWaypoint>? onSelectWaypoint,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RouteInfoSheet(
        document: document,
        fileName: fileName,
        onSelectWaypoint: onSelectWaypoint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.route_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name.isNotEmpty ? document.name : fileName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fileName,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Statistics Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: document.formattedDistance,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Elevation Gain',
                    value: document.formattedElevationGain,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Elevation Loss',
                    value: document.formattedElevationLoss,
                    color: const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.height_rounded,
                    label: 'Altitude Range',
                    value: document.formattedElevationRange,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (document.description != null && document.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                document.description!,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],

            // Waypoints / POIs List
            Text(
              'Waypoints (${document.waypoints.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: document.waypoints.isEmpty
                  ? Center(
                      child: Text(
                        'No standalone waypoints found in this file.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.separated(
                      itemCount: document.waypoints.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final wpt = document.waypoints[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: _buildWaypointIcon(wpt.type),
                          title: Text(
                            wpt.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (wpt.elevation != null) '${wpt.elevation!.toStringAsFixed(0)} m',
                              '${wpt.latitude.toStringAsFixed(4)}, ${wpt.longitude.toStringAsFixed(4)}',
                              if (wpt.description != null && wpt.description!.isNotEmpty) wpt.description!,
                            ].join(' • '),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelectWaypoint?.call(wpt);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.summit:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFFFEE2E2),
          child: Icon(Icons.flag_rounded, color: Color(0xFFDC2626), size: 16),
        );
      case WaypointType.hut:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFFFEF3C7),
          child: Icon(Icons.cabin_rounded, color: Color(0xFFD97706), size: 16),
        );
      case WaypointType.spring:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFFE0F2FE),
          child: Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 16),
        );
      case WaypointType.campsite:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFFDCFCE7),
          child: Icon(Icons.nature_people_rounded, color: Color(0xFF16A34A), size: 16),
        );
      case WaypointType.viewpoint:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFFF3E8FF),
          child: Icon(Icons.remove_red_eye_rounded, color: Color(0xFF9333EA), size: 16),
        );
      case WaypointType.general:
        return const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFFF1F5F9),
          child: Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 16),
        );
    }
  }
}
