import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'models/geo_route_models.dart';
import 'parser/geojson_parser.dart';
import 'parser/gpx_parser.dart';
import 'parser/kml_parser.dart';
import 'services/location_compass_service.dart';
import 'widgets/compass_cone_painter.dart';
import 'widgets/route_info_sheet.dart';
import 'widgets/route_layers_sheet.dart';

class RouteViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const RouteViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<RouteViewerScreen> createState() => _RouteViewerScreenState();
}

class _RouteViewerScreenState extends State<RouteViewerScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  GeoRouteDocument? _document;
  bool _isLoading = true;
  String? _errorMessage;
  late String _fileName;

  // Layer settings
  RouteLayersSettings _layersSettings = const RouteLayersSettings();

  // Location & Compass state
  Position? _currentPosition;
  double? _currentHeading;
  bool _isLocationActive = false;
  bool _followUser = false;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<double?>? _compassSub;

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _loadRouteFile();
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRouteFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found at path: ${widget.filePath}');
      }

      final lower = widget.filePath.toLowerCase();
      final GeoRouteDocument doc;

      if (lower.endsWith('.gpx')) {
        doc = await GpxParser.parseFromFile(file);
      } else if (lower.endsWith('.kml') || lower.endsWith('.kmz')) {
        doc = await KmlParser.parseFromFile(file);
      } else if (lower.endsWith('.geojson') || lower.endsWith('.geo.json') || lower.endsWith('.json')) {
        doc = await GeoJsonParser.parseFromFile(file);
      } else {
        // Fallback try GPX then KML then GeoJSON
        final content = await file.readAsString();
        if (content.contains('<gpx')) {
          doc = GpxParser.parse(content, defaultName: _fileName);
        } else if (content.contains('<kml')) {
          doc = KmlParser.parse(content, defaultName: _fileName);
        } else {
          doc = GeoJsonParser.parse(content, defaultName: _fileName);
        }
      }

      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });

        // Fit map bounds once layout is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitRouteBounds();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load route file: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _fitRouteBounds() {
    if (_document == null || _document!.bounds == null) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _document!.bounds!,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        ),
      );
    } catch (_) {}
  }

  void _centerOnWaypoint(GeoWaypoint wpt) {
    _mapController.move(wpt.toLatLng(), 15.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Centered on: ${wpt.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- Location & Compass Handling ---

  Future<void> _toggleLocation() async {
    if (_isLocationActive) {
      if (_currentPosition != null) {
        // Recenter on user and re-enable follow mode
        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16.0,
        );
        setState(() => _followUser = true);
      } else {
        _stopLocationTracking();
      }
      return;
    }

    // Request permission on-demand
    final state = await LocationCompassService.requestPermission();
    if (!mounted) return;

    if (state == LocationPermissionState.granted) {
      _startLocationTracking();
    } else if (state == LocationPermissionState.serviceDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled on your device.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (state == LocationPermissionState.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is permanently denied. Please enable it in Settings.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission was denied.'),
        ),
      );
    }
  }

  void _startLocationTracking() {
    setState(() {
      _isLocationActive = true;
      _followUser = true;
    });

    // Initial position
    LocationCompassService.getCurrentPosition().then((pos) {
      if (pos != null && mounted) {
        setState(() => _currentPosition = pos);
        if (_followUser) {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 15.5);
        }
      }
    });

    // Stream updates
    _positionSub = LocationCompassService.getPositionStream()?.listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      if (_followUser) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
      }
    });

    // Compass heading
    _compassSub = LocationCompassService.getCompassStream()?.listen((heading) {
      if (!mounted) return;
      if (heading != null) {
        setState(() => _currentHeading = heading);
      }
    });
  }

  void _stopLocationTracking() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _positionSub = null;
    _compassSub = null;
    if (mounted) {
      setState(() {
        _isLocationActive = false;
        _followUser = false;
        _currentPosition = null;
      });
    }
  }

  void _showLayersSheet() {
    RouteLayersSheet.show(
      context: context,
      currentSettings: _layersSettings,
      onChanged: (updated) {
        setState(() => _layersSettings = updated);
      },
    );
  }

  void _showInfoSheet() {
    if (_document == null) return;
    RouteInfoSheet.show(
      context: context,
      document: _document!,
      fileName: _fileName,
      onSelectWaypoint: _centerOnWaypoint,
    );
  }

  void _shareRouteFile() {
    Share.shareXFiles(
      [XFile(widget.filePath)],
      subject: _document?.name ?? _fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _document?.name.isNotEmpty == true ? _document!.name : _fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_document != null && _document!.totalDistanceMeters > 0)
              Text(
                '${_document!.formattedDistance} • ${_document!.formattedElevationGain}',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
              )
            else
              Text(
                _fileName,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Route Details',
            onPressed: _document != null ? _showInfoSheet : null,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Route',
            onPressed: _shareRouteFile,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading outdoor route & map...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadRouteFile,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final doc = _document!;
    final center = doc.bounds != null
        ? LatLng(
            (doc.bounds!.north + doc.bounds!.south) / 2,
            (doc.bounds!.east + doc.bounds!.west) / 2,
          )
        : const LatLng(42.5, 25.0); // Default Bulgaria center

    return Stack(
      children: [
        // 1. FlutterMap Component
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12.0,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _followUser) {
                setState(() => _followUser = false);
              }
            },
          ),
          children: [
            // Base Layer: Configurable (OpenTopoMap, OpenStreetMap, CyclOSM)
            TileLayer(
              key: ValueKey(_layersSettings.baseMap),
              urlTemplate: _layersSettings.baseMap.urlTemplate,
              subdomains: _layersSettings.baseMap.subdomains,
              fallbackUrl: _layersSettings.baseMap.fallbackUrl,
              maxZoom: _layersSettings.baseMap.maxZoom,
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              userAgentPackageName: 'com.koto.kotoviewer',
            ),

            // Overlay Layer: Waymarked Trails (Hiking)
            if (_layersSettings.showHikingTrails)
              TileLayer(
                urlTemplate: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.koto.kotoviewer',
                maxZoom: 17,
              ),

            // Overlay Layer: Waymarked Trails (Cycling/MTB)
            if (_layersSettings.showCyclingTrails)
              TileLayer(
                urlTemplate: 'https://tile.waymarkedtrails.org/cycling/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.koto.kotoviewer',
                maxZoom: 17,
              ),

            // Route Polylines
            PolylineLayer(
              polylines: _buildPolylines(doc),
            ),

            // Route Markers (Start, End, Waypoints, Live Location)
            MarkerLayer(
              markers: _buildMarkers(doc),
            ),

            // Mandatory License & Attribution banner
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 90, right: 8),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xCCFFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      _buildAttributionText(),
                      style: const TextStyle(fontSize: 9, color: Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // 2. Floating Map Action Buttons
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Layers button
              _buildFloatingButton(
                icon: Icons.layers_rounded,
                tooltip: 'Map Overlays',
                onPressed: _showLayersSheet,
              ),
              const SizedBox(height: 10),

              // Fit to route button
              _buildFloatingButton(
                icon: Icons.center_focus_strong_rounded,
                tooltip: 'Fit Route',
                onPressed: _fitRouteBounds,
              ),
              const SizedBox(height: 10),

              // GPS / My Location button
              _buildFloatingButton(
                icon: _isLocationActive ? Icons.my_location_rounded : Icons.location_searching_rounded,
                tooltip: _isLocationActive ? 'Center on Location' : 'Show My Location',
                color: _isLocationActive ? const Color(0xFF2563EB) : null,
                iconColor: _isLocationActive ? Colors.white : null,
                onPressed: _toggleLocation,
              ),
            ],
          ),
        ),

        // 3. Bottom Route Stats Quick Bar
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildBottomSummaryCard(doc, theme),
        ),
      ],
    );
  }

  String _buildAttributionText() {
    final buffer = StringBuffer(_layersSettings.baseMap.attribution);
    if (_layersSettings.showHikingTrails || _layersSettings.showCyclingTrails) {
      buffer.write(' | Trails: © Waymarked Trails (CC-BY-SA)');
    }
    return buffer.toString();
  }

  List<Polyline> _buildPolylines(GeoRouteDocument doc) {
    final List<Polyline> lines = [];
    final trackColor = const Color(0xFFDC2626).withValues(alpha: _layersSettings.trackOpacity);
    final casingColor = Colors.white.withValues(alpha: _layersSettings.trackOpacity * 0.85);

    for (final track in doc.tracks) {
      for (final seg in track.segments) {
        if (seg.points.length < 2) continue;
        final latLngs = seg.points.map((p) => p.toLatLng()).toList();

        // 1. Casing / border line for maximum readability on mountain contours
        lines.add(
          Polyline(
            points: latLngs,
            strokeWidth: _layersSettings.trackWidth + 2.5,
            color: casingColor,
          ),
        );

        // 2. Main track line
        lines.add(
          Polyline(
            points: latLngs,
            strokeWidth: _layersSettings.trackWidth,
            color: trackColor,
          ),
        );
      }
    }

    return lines;
  }

  List<Marker> _buildMarkers(GeoRouteDocument doc) {
    final List<Marker> markers = [];

    // 1. Start and Finish markers on the main track
    if (doc.tracks.isNotEmpty && doc.tracks.first.segments.isNotEmpty) {
      final firstSeg = doc.tracks.first.segments.first;
      if (firstSeg.points.isNotEmpty) {
        final startPt = firstSeg.points.first.toLatLng();
        markers.add(
          Marker(
            point: startPt,
            width: 32,
            height: 32,
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF16A34A),
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            ),
          ),
        );
      }

      final lastTrack = doc.tracks.last;
      if (lastTrack.segments.isNotEmpty) {
        final lastSeg = lastTrack.segments.last;
        if (lastSeg.points.isNotEmpty) {
          final endPt = lastSeg.points.last.toLatLng();
          markers.add(
            Marker(
              point: endPt,
              width: 32,
              height: 32,
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFDC2626),
                child: Icon(Icons.sports_score_rounded, color: Colors.white, size: 18),
              ),
            ),
          );
        }
      }
    }

    // 2. Waypoints / POIs
    for (final wpt in doc.waypoints) {
      markers.add(
        Marker(
          point: wpt.toLatLng(),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${wpt.name}${wpt.elevation != null ? ' (${wpt.elevation!.toStringAsFixed(0)} m)' : ''}',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: _buildWaypointMarkerIcon(wpt.type),
          ),
        ),
      );
    }

    // 3. User Live GPS Marker with compass heading cone
    if (_currentPosition != null) {
      final userLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      markers.add(
        Marker(
          point: userLatLng,
          width: 80,
          height: 80,
          child: UserLocationMarker(heading: _currentHeading),
        ),
      );
    }

    return markers;
  }

  Widget _buildWaypointMarkerIcon(WaypointType type) {
    Color bg;
    IconData icon;
    switch (type) {
      case WaypointType.summit:
        bg = const Color(0xFFDC2626);
        icon = Icons.flag_rounded;
        break;
      case WaypointType.hut:
        bg = const Color(0xFFD97706);
        icon = Icons.cabin_rounded;
        break;
      case WaypointType.spring:
        bg = const Color(0xFF0284C7);
        icon = Icons.water_drop_rounded;
        break;
      case WaypointType.campsite:
        bg = const Color(0xFF16A34A);
        icon = Icons.nature_people_rounded;
        break;
      case WaypointType.viewpoint:
        bg = const Color(0xFF9333EA);
        icon = Icons.remove_red_eye_rounded;
        break;
      case WaypointType.general:
        bg = const Color(0xFF475569);
        icon = Icons.location_on_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
    Color? iconColor,
  }) {
    return Material(
      color: color ?? Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(
              icon,
              size: 22,
              color: iconColor ?? Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSummaryCard(GeoRouteDocument doc, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xEE1E293B) : const Color(0xEEFFFFFF),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showInfoSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Distance badge
              _buildSummaryItem(
                icon: Icons.straighten_rounded,
                label: 'Distance',
                value: doc.formattedDistance,
                color: const Color(0xFF2563EB),
              ),
              const Spacer(),
              Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
              const Spacer(),

              // Elevation gain badge
              _buildSummaryItem(
                icon: Icons.arrow_upward_rounded,
                label: 'Gain',
                value: doc.formattedElevationGain,
                color: const Color(0xFF16A34A),
              ),
              const Spacer(),
              Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
              const Spacer(),

              // Altitude Range badge
              _buildSummaryItem(
                icon: Icons.height_rounded,
                label: 'Altitude',
                value: doc.formattedElevationRange,
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_less_rounded, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ],
    );
  }
}
