import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/route_viewer/services/location_compass_service.dart';
import 'package:kotoview/src/features/route_viewer/services/web_compass/web_compass.dart';

void main() {
  group('CompassHeadingData Tests', () {
    test('reports reliable when accuracy is good (<= 35 degrees)', () {
      const data = CompassHeadingData(heading: 120.0, accuracy: 12.0);
      expect(data.heading, 120.0);
      expect(data.accuracy, 12.0);
      expect(data.isUnreliable, isFalse);
    });

    test('reports unreliable when accuracy is null (uncalibrated)', () {
      const data = CompassHeadingData(heading: 45.0, accuracy: null);
      expect(data.isUnreliable, isTrue);
    });

    test('reports unreliable when accuracy is greater than 35 degrees', () {
      const data = CompassHeadingData(heading: 180.0, accuracy: 40.0);
      expect(data.isUnreliable, isTrue);
    });
  });

  group('WebCompassPlatform on non-web VM tests', () {
    test('stub returns false for isSupported on non-web', () {
      expect(WebCompassPlatform.isSupported, isFalse);
    });

    test('stub returns null stream on non-web', () {
      expect(WebCompassPlatform.getCompassStream(), isNull);
    });

    test('stub requestPermission returns true', () async {
      final res = await WebCompassPlatform.requestPermission();
      expect(res, isTrue);
    });

    test('LocationCompassService.requestCompassPermission returns future bool', () async {
      final res = await LocationCompassService.requestCompassPermission();
      expect(res, isTrue);
    });
  });
}
