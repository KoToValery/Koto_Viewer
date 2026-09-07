import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Represents a single geographic point with optional elevation and timestamp.
class GeoPoint {
  final double latitude;
  final double longitude;
  final double? elevation; // In meters
  final DateTime? timestamp;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.timestamp,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  /// Calculate distance to another point using the Haversine formula in meters.
  double distanceTo(GeoPoint other) {
    const double earthRadius = 6371000; // meters
    final double dLat = _degToRad(other.latitude - latitude);
    final double dLon = _degToRad(other.longitude - longitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(latitude)) *
            math.cos(_degToRad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}

/// Represents a waypoint, peak, mountain hut, spring, or POI.
class GeoWaypoint {
  final double latitude;
  final double longitude;
  final double? elevation;
  final String name;
  final String? description;
  final String? symbol;

  const GeoWaypoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
    required this.name,
    this.description,
    this.symbol,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  /// Guesses POI category from name or symbol
  WaypointType get type {
    final lower = '${name.toLowerCase()} ${symbol?.toLowerCase() ?? ''} ${description?.toLowerCase() ?? ''}';
    if (lower.contains('peak') || lower.contains('summit') || lower.contains('вр.') || lower.contains('връх')) {
      return WaypointType.summit;
    }
    if (lower.contains('hut') || lower.contains('chalet') || lower.contains('refuge') || lower.contains('хижа') || lower.contains('заслон')) {
      return WaypointType.hut;
    }
    if (lower.contains('water') || lower.contains('spring') || lower.contains('fountain') || lower.contains('чешма') || lower.contains('извор')) {
      return WaypointType.spring;
    }
    if (lower.contains('camp') || lower.contains('tent') || lower.contains('къмпинг')) {
      return WaypointType.campsite;
    }
    if (lower.contains('view') || lower.contains('lookout') || lower.contains('панорама')) {
      return WaypointType.viewpoint;
    }
    return WaypointType.general;
  }
}

enum WaypointType { summit, hut, spring, campsite, viewpoint, general }

/// A continuous track segment consisting of ordered points.
class GeoTrackSegment {
  final List<GeoPoint> points;
  final double distanceMeters;
  final double elevationGain;
  final double elevationLoss;

  GeoTrackSegment({
    required this.points,
    required this.distanceMeters,
    required this.elevationGain,
    required this.elevationLoss,
  });

  factory GeoTrackSegment.fromPoints(List<GeoPoint> points) {
    double dist = 0.0;
    double gain = 0.0;
    double loss = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      dist += p1.distanceTo(p2);

      if (p1.elevation != null && p2.elevation != null) {
        final diff = p2.elevation! - p1.elevation!;
        if (diff > 0) {
          gain += diff;
        } else {
          loss += diff.abs();
        }
      }
    }

    return GeoTrackSegment(
      points: points,
      distanceMeters: dist,
      elevationGain: gain,
      elevationLoss: loss,
    );
  }
}

/// A track consisting of one or more segments.
class GeoTrack {
  final String name;
  final String? description;
  final List<GeoTrackSegment> segments;

  const GeoTrack({
    required this.name,
    this.description,
    required this.segments,
  });

  double get totalDistanceMeters =>
      segments.fold(0.0, (sum, seg) => sum + seg.distanceMeters);

  double get totalElevationGain =>
      segments.fold(0.0, (sum, seg) => sum + seg.elevationGain);

  double get totalElevationLoss =>
      segments.fold(0.0, (sum, seg) => sum + seg.elevationLoss);

  int get totalPoints =>
      segments.fold(0, (sum, seg) => sum + seg.points.length);
}

/// Complete parsed geographic document for routes, tracks, and waypoints.
class GeoRouteDocument {
  final String name;
  final String? description;
  final List<GeoTrack> tracks;
  final List<GeoWaypoint> waypoints;
  final double totalDistanceMeters;
  final double elevationGainMeters;
  final double elevationLossMeters;
  final double? minElevationMeters;
  final double? maxElevationMeters;
  final LatLngBounds? bounds;

  GeoRouteDocument({
    required this.name,
    this.description,
    required this.tracks,
    required this.waypoints,
    required this.totalDistanceMeters,
    required this.elevationGainMeters,
    required this.elevationLossMeters,
    this.minElevationMeters,
    this.maxElevationMeters,
    this.bounds,
  });

  int get totalPoints =>
      tracks.fold(0, (sum, t) => sum + t.totalPoints) + waypoints.length;

  bool get isEmpty => tracks.isEmpty && waypoints.isEmpty;

  String get formattedDistance {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${totalDistanceMeters.toStringAsFixed(0)} m';
  }

  String get formattedElevationGain {
    return '+${elevationGainMeters.toStringAsFixed(0)} m';
  }

  String get formattedElevationLoss {
    return '-${elevationLossMeters.toStringAsFixed(0)} m';
  }

  String get formattedElevationRange {
    if (minElevationMeters == null || maxElevationMeters == null) return 'N/A';
    return '${minElevationMeters!.toStringAsFixed(0)} m - ${maxElevationMeters!.toStringAsFixed(0)} m';
  }

  /// Calculates bounding box from all track points and waypoints
  static LatLngBounds? calculateBounds(List<GeoTrack> tracks, List<GeoWaypoint> waypoints) {
    double? minLat, maxLat, minLon, maxLon;

    void update(double lat, double lon) {
      minLat = (minLat == null) ? lat : math.min(minLat!, lat);
      maxLat = (maxLat == null) ? lat : math.max(maxLat!, lat);
      minLon = (minLon == null) ? lon : math.min(minLon!, lon);
      maxLon = (maxLon == null) ? lon : math.max(maxLon!, lon);
    }

    for (final track in tracks) {
      for (final seg in track.segments) {
        for (final pt in seg.points) {
          update(pt.latitude, pt.longitude);
        }
      }
    }

    for (final wpt in waypoints) {
      update(wpt.latitude, wpt.longitude);
    }

    if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
      return null;
    }

    // Add tiny padding if all points are identical
    if (minLat == maxLat) {
      minLat = minLat! - 0.005;
      maxLat = maxLat! + 0.005;
    }
    if (minLon == maxLon) {
      minLon = minLon! - 0.005;
      maxLon = maxLon! + 0.005;
    }

    return LatLngBounds(
      LatLng(minLat!, minLon!),
      LatLng(maxLat!, maxLon!),
    );
  }
}
