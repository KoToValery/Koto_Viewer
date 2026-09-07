import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/route_viewer/parser/gpx_parser.dart';
import 'package:kotoview/src/features/route_viewer/parser/kml_parser.dart';
import 'package:kotoview/src/features/route_viewer/parser/geojson_parser.dart';

void main() {
  group('Route Parsers Tests', () {
    test('GPX parser parses tracks, elevations, and waypoints', () {
      const gpxContent = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="KoToTest" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Musala Peak Trail</name>
    <desc>Scenic mountain route to Musala summit</desc>
  </metadata>
  <wpt lat="42.1792" lon="23.5855">
    <ele>2925.0</ele>
    <name>Musala Peak</name>
    <desc>Highest summit in the Balkans</desc>
    <sym>Summit</sym>
  </wpt>
  <wpt lat="42.2045" lon="23.5843">
    <ele>2369.0</ele>
    <name>Musala Hut</name>
    <desc>Mountain shelter with fresh water</desc>
    <sym>Hut</sym>
  </wpt>
  <trk>
    <name>Yastrebets to Musala</name>
    <trkseg>
      <trkpt lat="42.2274" lon="23.5818">
        <ele>2369.0</ele>
        <time>2026-08-10T08:00:00Z</time>
      </trkpt>
      <trkpt lat="42.2045" lon="23.5843">
        <ele>2389.0</ele>
        <time>2026-08-10T09:00:00Z</time>
      </trkpt>
      <trkpt lat="42.1792" lon="23.5855">
        <ele>2925.0</ele>
        <time>2026-08-10T11:30:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>''';

      final doc = GpxParser.parse(gpxContent);
      expect(doc.name, equals('Musala Peak Trail'));
      expect(doc.tracks.length, equals(1));
      expect(doc.tracks.first.segments.first.points.length, equals(3));
      expect(doc.waypoints.length, equals(2));
      expect(doc.waypoints.first.name, equals('Musala Peak'));
      expect(doc.minElevationMeters, equals(2369.0));
      expect(doc.maxElevationMeters, equals(2925.0));
      expect(doc.elevationGainMeters, greaterThan(500));
      expect(doc.totalDistanceMeters, greaterThan(4000));
      expect(doc.bounds, isNotNull);
    });

    test('KML parser parses placemarks and linestrings', () {
      const kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Vihren Trail</name>
    <Placemark>
      <name>Vihren Summit</name>
      <Point>
        <coordinates>23.3995,41.7674,2914</coordinates>
      </Point>
    </Placemark>
    <Placemark>
      <name>Main Ridge Track</name>
      <LineString>
        <coordinates>
          23.4158,41.7562,1950 
          23.4078,41.7612,2400 
          23.3995,41.7674,2914
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>''';

      final doc = KmlParser.parse(kmlContent);
      expect(doc.name, equals('Vihren Trail'));
      expect(doc.tracks.length, equals(1));
      expect(doc.tracks.first.segments.first.points.length, equals(3));
      expect(doc.waypoints.length, equals(1));
      expect(doc.waypoints.first.name, equals('Vihren Summit'));
      expect(doc.minElevationMeters, equals(1950.0));
      expect(doc.maxElevationMeters, equals(2914.0));
      expect(doc.bounds, isNotNull);
    });

    test('GeoJSON parser parses FeatureCollection with LineString and Point', () {
      const geoJsonContent = '''{
  "type": "FeatureCollection",
  "name": "Kom-Emine Section",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "Midzhur Peak"},
      "geometry": {
        "type": "Point",
        "coordinates": [22.6806, 43.4042, 2168]
      }
    },
    {
      "type": "Feature",
      "properties": {"name": "Ridge Route"},
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [22.6500, 43.3900, 1800],
          [22.6806, 43.4042, 2168]
        ]
      }
    }
  ]
}''';

      final doc = GeoJsonParser.parse(geoJsonContent);
      expect(doc.name, equals('Kom-Emine Section'));
      expect(doc.tracks.length, equals(1));
      expect(doc.waypoints.length, equals(1));
      expect(doc.totalDistanceMeters, greaterThan(2000));
      expect(doc.maxElevationMeters, equals(2168.0));
    });
  });
}
