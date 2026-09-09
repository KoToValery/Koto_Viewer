import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/route_viewer/widgets/route_layers_sheet.dart';

void main() {
  group('BaseMapType and RouteLayersSettings Tests', () {
    test('BaseMapType properties are properly configured', () {
      expect(BaseMapType.values.length, 3);

      // OpenTopoMap
      final topo = BaseMapType.openTopoMap;
      expect(topo.displayName, 'OpenTopoMap');
      expect(topo.urlTemplate, contains('{s}.tile.opentopomap.org'));
      expect(topo.subdomains, ['a', 'b', 'c']);
      expect(topo.fallbackUrl, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(topo.maxZoom, 17);
      expect(topo.attribution, contains('OpenTopoMap'));

      // OpenStreetMap
      final osm = BaseMapType.openStreetMap;
      expect(osm.displayName, 'OpenStreetMap');
      expect(osm.urlTemplate, contains('tile.openstreetmap.org'));
      expect(osm.fallbackUrl, isNull);
      expect(osm.maxZoom, 19);
      expect(osm.attribution, contains('OpenStreetMap contributors'));

      // CyclOSM
      final cycl = BaseMapType.cyclOsm;
      expect(cycl.displayName, contains('CyclOSM'));
      expect(cycl.urlTemplate, contains('tile-cyclosm.openstreetmap.fr'));
      expect(cycl.subdomains, ['a', 'b', 'c']);
      expect(cycl.fallbackUrl, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(cycl.maxZoom, 18);
      expect(cycl.attribution, contains('CyclOSM'));
    });

    test('RouteLayersSettings defaults and copyWith work correctly', () {
      const defaultSettings = RouteLayersSettings();
      expect(defaultSettings.baseMap, BaseMapType.openTopoMap);
      expect(defaultSettings.showHikingTrails, true);
      expect(defaultSettings.showCyclingTrails, false);
      expect(defaultSettings.trackWidth, 4.0);
      expect(defaultSettings.trackOpacity, 0.9);

      final modified = defaultSettings.copyWith(
        baseMap: BaseMapType.openStreetMap,
        showHikingTrails: false,
        showCyclingTrails: true,
        trackWidth: 5.5,
        trackOpacity: 0.8,
      );

      expect(modified.baseMap, BaseMapType.openStreetMap);
      expect(modified.showHikingTrails, false);
      expect(modified.showCyclingTrails, true);
      expect(modified.trackWidth, 5.5);
      expect(modified.trackOpacity, 0.8);
    });
  });
}
