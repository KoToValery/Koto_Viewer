import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/geo_route_models.dart';

class KmlParser {
  /// Parse KML XML string.
  static GeoRouteDocument parse(String xmlContent, {String defaultName = 'KML Route'}) {
    final document = XmlDocument.parse(xmlContent);
    final kmlElement = document.findElements('kml').firstOrNull ?? document.rootElement;

    String docName = defaultName;
    String? docDesc;

    final docElement = kmlElement.findElements('Document').firstOrNull ?? kmlElement;
    final nameEl = docElement.findElements('name').firstOrNull;
    if (nameEl != null && nameEl.innerText.trim().isNotEmpty) {
      docName = nameEl.innerText.trim();
    }
    final descEl = docElement.findElements('description').firstOrNull;
    if (descEl != null && descEl.innerText.trim().isNotEmpty) {
      docDesc = descEl.innerText.trim();
    }

    final List<GeoTrack> tracks = [];
    final List<GeoWaypoint> waypoints = [];

    // Find all Placemarks recursively
    final placemarks = docElement.findAllElements('Placemark');
    for (final pm in placemarks) {
      final pmName = pm.findElements('name').firstOrNull?.innerText.trim() ?? 'Point';
      final pmDesc = pm.findElements('description').firstOrNull?.innerText.trim();

      // Check for LineString
      final lineStrings = pm.findAllElements('LineString');
      for (final ls in lineStrings) {
        final coordEl = ls.findElements('coordinates').firstOrNull;
        if (coordEl != null) {
          final points = _parseCoordinateString(coordEl.innerText);
          if (points.isNotEmpty) {
            tracks.add(GeoTrack(
              name: pmName,
              description: pmDesc,
              segments: [GeoTrackSegment.fromPoints(points)],
            ));
          }
        }
      }

      // Check for Points
      final points = pm.findAllElements('Point');
      for (final p in points) {
        final coordEl = p.findElements('coordinates').firstOrNull;
        if (coordEl != null) {
          final pts = _parseCoordinateString(coordEl.innerText);
          if (pts.isNotEmpty) {
            final pt = pts.first;
            waypoints.add(GeoWaypoint(
              latitude: pt.latitude,
              longitude: pt.longitude,
              elevation: pt.elevation,
              name: pmName,
              description: pmDesc,
            ));
          }
        }
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

  /// Parses KML or KMZ file from filesystem.
  static Future<GeoRouteDocument> parseFromFile(File file) async {
    final fileName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.(kml|kmz)$', caseSensitive: false), '');
    final lower = file.path.toLowerCase();

    if (lower.endsWith('.kmz')) {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find doc.kml or first .kml file
      ArchiveFile? kmlFile;
      for (final f in archive) {
        if (f.name.toLowerCase().endsWith('.kml')) {
          kmlFile = f;
          if (f.name.toLowerCase().contains('doc.kml')) break;
        }
      }

      if (kmlFile != null) {
        final content = utf8.decode(kmlFile.content as List<int>, allowMalformed: true);
        return parse(content, defaultName: fileName);
      }
      throw Exception('No KML file found inside KMZ archive.');
    } else {
      final content = await file.readAsString();
      return parse(content, defaultName: fileName);
    }
  }

  /// Parses KML coordinate tuples: "lon,lat,alt lon,lat,alt ..."
  static List<GeoPoint> _parseCoordinateString(String coordsStr) {
    final List<GeoPoint> points = [];
    final tokens = coordsStr.trim().split(RegExp(r'\s+'));

    for (final token in tokens) {
      if (token.isEmpty) continue;
      final parts = token.split(',');
      if (parts.length >= 2) {
        final lon = double.tryParse(parts[0].trim());
        final lat = double.tryParse(parts[1].trim());
        final ele = (parts.length >= 3) ? double.tryParse(parts[2].trim()) : null;

        if (lat != null && lon != null) {
          points.add(GeoPoint(
            latitude: lat,
            longitude: lon,
            elevation: ele,
          ));
        }
      }
    }

    return points;
  }
}
