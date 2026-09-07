import 'dart:io';
import 'dart:math' as math;
import 'package:xml/xml.dart';
import '../models/geo_route_models.dart';

class GpxParser {
  /// Parse a GPX document from a string.
  static GeoRouteDocument parse(String xmlContent, {String defaultName = 'Route'}) {
    final document = XmlDocument.parse(xmlContent);
    final gpxElement = document.findElements('gpx').firstOrNull ?? document.rootElement;

    String routeName = defaultName;
    String? routeDesc;

    // Metadata name
    final metadata = gpxElement.findElements('metadata').firstOrNull;
    if (metadata != null) {
      final nameEl = metadata.findElements('name').firstOrNull;
      if (nameEl != null && nameEl.innerText.trim().isNotEmpty) {
        routeName = nameEl.innerText.trim();
      }
      final descEl = metadata.findElements('desc').firstOrNull;
      if (descEl != null && descEl.innerText.trim().isNotEmpty) {
        routeDesc = descEl.innerText.trim();
      }
    }

    final List<GeoTrack> tracks = [];
    final List<GeoWaypoint> waypoints = [];

    // 1. Parse Tracks (<trk>)
    final trkElements = gpxElement.findElements('trk');
    for (final trk in trkElements) {
      final trackName = trk.findElements('name').firstOrNull?.innerText.trim() ?? routeName;
      final trackDesc = trk.findElements('desc').firstOrNull?.innerText.trim();

      final List<GeoTrackSegment> segments = [];
      for (final trkseg in trk.findElements('trkseg')) {
        final List<GeoPoint> points = [];
        for (final trkpt in trkseg.findElements('trkpt')) {
          final pt = _parsePoint(trkpt);
          if (pt != null) points.add(pt);
        }
        if (points.isNotEmpty) {
          segments.add(GeoTrackSegment.fromPoints(points));
        }
      }

      if (segments.isNotEmpty) {
        tracks.add(GeoTrack(
          name: trackName,
          description: trackDesc,
          segments: segments,
        ));
      }
    }

    // 2. Parse Routes (<rte>) as tracks if no <trk> or alongside them
    final rteElements = gpxElement.findElements('rte');
    for (final rte in rteElements) {
      final routeTrackName = rte.findElements('name').firstOrNull?.innerText.trim() ?? 'Route';
      final routeTrackDesc = rte.findElements('desc').firstOrNull?.innerText.trim();

      final List<GeoPoint> points = [];
      for (final rtept in rte.findElements('rtept')) {
        final pt = _parsePoint(rtept);
        if (pt != null) points.add(pt);
      }
      if (points.isNotEmpty) {
        tracks.add(GeoTrack(
          name: routeTrackName,
          description: routeTrackDesc,
          segments: [GeoTrackSegment.fromPoints(points)],
        ));
      }
    }

    // 3. Parse Waypoints (<wpt>)
    final wptElements = gpxElement.findElements('wpt');
    for (final wpt in wptElements) {
      final latStr = wpt.getAttribute('lat');
      final lonStr = wpt.getAttribute('lon');
      if (latStr == null || lonStr == null) continue;

      final lat = double.tryParse(latStr);
      final lon = double.tryParse(lonStr);
      if (lat == null || lon == null) continue;

      final eleStr = wpt.findElements('ele').firstOrNull?.innerText.trim();
      final ele = eleStr != null ? double.tryParse(eleStr) : null;
      final name = wpt.findElements('name').firstOrNull?.innerText.trim() ?? 'Waypoint';
      final desc = wpt.findElements('desc').firstOrNull?.innerText.trim();
      final sym = wpt.findElements('sym').firstOrNull?.innerText.trim();

      waypoints.add(GeoWaypoint(
        latitude: lat,
        longitude: lon,
        elevation: ele,
        name: name,
        description: desc,
        symbol: sym,
      ));
    }

    // Calculate aggregated metrics
    double totalDist = 0;
    double totalGain = 0;
    double totalLoss = 0;
    double? minEle;
    double? maxEle;

    for (final t in tracks) {
      totalDist += t.totalDistanceMeters;
      totalGain += t.totalElevationGain;
      totalLoss += t.totalElevationLoss;

      for (final s in t.segments) {
        for (final p in s.points) {
          if (p.elevation != null) {
            minEle = (minEle == null) ? p.elevation : math.min(minEle, p.elevation!);
            maxEle = (maxEle == null) ? p.elevation : math.max(maxEle, p.elevation!);
          }
        }
      }
    }

    for (final w in waypoints) {
      if (w.elevation != null) {
        minEle = (minEle == null) ? w.elevation : math.min(minEle, w.elevation!);
        maxEle = (maxEle == null) ? w.elevation : math.max(maxEle, w.elevation!);
      }
    }

    final bounds = GeoRouteDocument.calculateBounds(tracks, waypoints);

    return GeoRouteDocument(
      name: routeName,
      description: routeDesc,
      tracks: tracks,
      waypoints: waypoints,
      totalDistanceMeters: totalDist,
      elevationGainMeters: totalGain,
      elevationLossMeters: totalLoss,
      minElevationMeters: minEle,
      maxElevationMeters: maxEle,
      bounds: bounds,
    );
  }

  /// Parse a GPX file from the local filesystem.
  static Future<GeoRouteDocument> parseFromFile(File file) async {
    final content = await file.readAsString();
    final fileName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '');
    return parse(content, defaultName: fileName);
  }

  static GeoPoint? _parsePoint(XmlElement element) {
    final latStr = element.getAttribute('lat');
    final lonStr = element.getAttribute('lon');
    if (latStr == null || lonStr == null) return null;

    final lat = double.tryParse(latStr);
    final lon = double.tryParse(lonStr);
    if (lat == null || lon == null) return null;

    final eleStr = element.findElements('ele').firstOrNull?.innerText.trim();
    final ele = eleStr != null ? double.tryParse(eleStr) : null;

    final timeStr = element.findElements('time').firstOrNull?.innerText.trim();
    DateTime? time;
    if (timeStr != null) {
      time = DateTime.tryParse(timeStr);
    }

    return GeoPoint(
      latitude: lat,
      longitude: lon,
      elevation: ele,
      timestamp: time,
    );
  }
}
