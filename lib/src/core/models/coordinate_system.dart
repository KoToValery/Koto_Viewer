import 'package:flutter/material.dart';

/// Supported Coordinate Reference Systems (CRS).
enum CoordinateSystem {
  bgs2005Cadastral(
    id: 'bgs_2005_cadastral',
    name: 'BGS 2005 (Cadastral / Lambert)',
    epsg: 'EPSG:7801',
    description: 'Standard Bulgarian Cadastral coordinate system (Lambert Conformal Conic)',
    isDefault: true,
  ),
  bgs2005Utm35n(
    id: 'bgs_2005_utm35n',
    name: 'BGS 2005 / UTM Zone 35N',
    epsg: 'EPSG:32635',
    description: 'Bulgarian Military & Geodetic UTM Zone 35N projection',
  ),
  cs1970(
    id: 'cs_1970',
    name: 'CS 1970 (Bulgaria Zones K-3, K-5, K-7, K-9)',
    epsg: 'CS 1970',
    description: 'Historical Bulgarian Geodetic Coordinate System 1970',
  ),
  wgs84Geo(
    id: 'wgs84_geo',
    name: 'WGS 84 (GPS Latitude / Longitude)',
    epsg: 'EPSG:4326',
    description: 'Global Geographic coordinates in decimal degrees',
  ),
  webMercator(
    id: 'web_mercator',
    name: 'WGS 84 / Pseudo-Mercator (Web Mercator)',
    epsg: 'EPSG:3857',
    description: 'Standard projection used by Google Maps, OpenStreetMap, Bing',
  ),
  utmGeneral(
    id: 'utm_general',
    name: 'UTM (Universal Transverse Mercator)',
    epsg: 'UTM Metric',
    description: 'General international metric transverse mercator grid',
  ),
  localCartesian(
    id: 'local_cartesian',
    name: 'Non-projected / Local (X, Y)',
    epsg: 'Local / None',
    description: 'Arbitrary local Cartesian coordinates without geodetic projection',
  );

  final String id;
  final String name;
  final String epsg;
  final String description;
  final bool isDefault;

  const CoordinateSystem({
    required this.id,
    required this.name,
    required this.epsg,
    required this.description,
    this.isDefault = false,
  });

  static CoordinateSystem fromId(String? id) {
    if (id == null) return CoordinateSystem.bgs2005Cadastral;
    for (final crs in CoordinateSystem.values) {
      if (crs.id == id) return crs;
    }
    return CoordinateSystem.bgs2005Cadastral;
  }

  /// Heuristic to guess coordinate system from CAD bounding box.
  static CoordinateSystem detectFromBounds(Rect bounds) {
    final double minX = bounds.left;
    final double maxX = bounds.right;
    final double minY = bounds.top;
    final double maxY = bounds.bottom;

    // Check WGS84 Geographic (Lat: 40..45, Lon: 20..30 in Bulgaria or -90..90, -180..180 globally)
    if (minX >= -180 && maxX <= 180 && minY >= -90 && maxY <= 90) {
      return CoordinateSystem.wgs84Geo;
    }

    // Check BGS 2005 Cadastral: typically X ~ 4,500,000..4,900,000 and Y ~ 8,300,000..8,700,000 (or vice-versa)
    final bool isBgsCadX = (minX >= 4000000 && maxX <= 5200000 && minY >= 8000000 && maxY <= 9000000);
    final bool isBgsCadY = (minY >= 4000000 && maxY <= 5200000 && minX >= 8000000 && maxX <= 9000000);
    if (isBgsCadX || isBgsCadY) {
      return CoordinateSystem.bgs2005Cadastral;
    }

    // Check BGS 2005 UTM 35N: typically Northing ~ 4,500,000..4,900,000 and Easting ~ 200,000..800,000
    final bool isUtm35X = (minX >= 200000 && maxX <= 900000 && minY >= 4000000 && maxY <= 5200000);
    final bool isUtm35Y = (minY >= 200000 && maxY <= 900000 && minX >= 4000000 && maxX <= 5200000);
    if (isUtm35X || isUtm35Y) {
      return CoordinateSystem.bgs2005Utm35n;
    }

    // Check CS 1970 (Values in tens of thousands, e.g. 4000..95000, 20000..90000)
    if (minX >= 0 && maxX <= 150000 && minY >= 0 && maxY <= 150000 && (maxX > 1000 || maxY > 1000)) {
      return CoordinateSystem.cs1970;
    }

    // Small numbers (0 to 1000) -> Local/Non-projected
    if (minX.abs() <= 2000 && maxX.abs() <= 2000 && minY.abs() <= 2000 && maxY.abs() <= 2000) {
      return CoordinateSystem.localCartesian;
    }

    // Default to general UTM or BGS 2005
    return CoordinateSystem.bgs2005Cadastral;
  }
}
