import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../models/geo_route_models.dart';

class GeoJsonParser {
  /// Parse GeoJSON string.
  static GeoRouteDocument parse(String jsonString, {String defaultName = 'GeoJSON Route'}) {
    final dynamic data = jsonDecode(jsonString);
    final List<GeoTrack> tracks = [];
    final List<GeoWaypoint> waypoints = [];

    String docName = defaultName;
    String? docDesc;

    if (data is Map<String, dynamic>) {
      if (data.containsKey('name')) {
        docName = data['name'].toString();
      }

      final type = data['type']?.toString();
      if (type == 'FeatureCollection') {
        final features = data['features'] as List<dynamic>? ?? [];
        for (final f in features) {
          if (f is Map<String, dynamic>) {
            _parseFeature(f, tracks, waypoints);
          }
        }
      } else if (type == 'Feature') {
        _parseFeature(data, tracks, waypoints);
      } else if (type == 'LineString' || type == 'MultiLineString' || type == 'Point') {
        _parseGeometry(data, {}, tracks, waypoints);
      }
    }

    // Calculate metrics
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
      name: docName,
      description: docDesc,
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

  static Future<GeoRouteDocument> parseFromFile(File file) async {
    final fileName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.(geojson|json)$', caseSensitive: false), '');
    final content = await file.readAsString();
    return parse(content, defaultName: fileName);
  }

  static void _parseFeature(
    Map<String, dynamic> feature,
    List<GeoTrack> tracks,
    List<GeoWaypoint> waypoints,
  ) {
    final properties = (feature['properties'] as Map<String, dynamic>?) ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry != null) {
      _parseGeometry(geometry, properties, tracks, waypoints);
    }
  }

  static void _parseGeometry(
    Map<String, dynamic> geometry,
    Map<String, dynamic> properties,
    List<GeoTrack> tracks,
    List<GeoWaypoint> waypoints,
  ) {
    final type = geometry['type']?.toString();
    final coords = geometry['coordinates'];
    final name = properties['name']?.toString() ?? 'Route';
    final desc = properties['description']?.toString();

    if (type == 'LineString' && coords is List) {
      final points = _parsePointList(coords);
      if (points.isNotEmpty) {
        tracks.add(GeoTrack(
          name: name,
          description: desc,
          segments: [GeoTrackSegment.fromPoints(points)],
        ));
      }
    } else if (type == 'MultiLineString' && coords is List) {
      final List<GeoTrackSegment> segments = [];
      for (final line in coords) {
        if (line is List) {
          final points = _parsePointList(line);
          if (points.isNotEmpty) {
            segments.add(GeoTrackSegment.fromPoints(points));
          }
        }
      }
      if (segments.isNotEmpty) {
        tracks.add(GeoTrack(
          name: name,
          description: desc,
          segments: segments,
        ));
      }
    } else if (type == 'Point' && coords is List) {
      final pt = _parseSinglePoint(coords);
      if (pt != null) {
        waypoints.add(GeoWaypoint(
          latitude: pt.latitude,
          longitude: pt.longitude,
          elevation: pt.elevation,
          name: name,
          description: desc,
        ));
      }
    }
  }

  static List<GeoPoint> _parsePointList(List<dynamic> list) {
    final List<GeoPoint> points = [];
    for (final item in list) {
      if (item is List) {
        final pt = _parseSinglePoint(item);
        if (pt != null) points.add(pt);
      }
    }
    return points;
  }

  static GeoPoint? _parseSinglePoint(List<dynamic> coord) {
    if (coord.length >= 2) {
      final lon = (coord[0] as num?)?.toDouble();
      final lat = (coord[1] as num?)?.toDouble();
      final ele = (coord.length >= 3) ? (coord[2] as num?)?.toDouble() : null;

      if (lat != null && lon != null) {
        return GeoPoint(latitude: lat, longitude: lon, elevation: ele);
      }
    }
    return null;
  }
}
