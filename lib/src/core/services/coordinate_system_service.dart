import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coordinate_system.dart';

/// Service to persist and manage the active default Coordinate Reference System.
class CoordinateSystemService {
  static const String _keyCoordinateSystem = 'koto_default_coordinate_system';

  static final ValueNotifier<CoordinateSystem> activeSystemNotifier =
      ValueNotifier<CoordinateSystem>(CoordinateSystem.bgs2005Cadastral);

  static Future<void> init() async {
    final system = await getCoordinateSystem();
    activeSystemNotifier.value = system;
  }

  static Future<CoordinateSystem> getCoordinateSystem() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyCoordinateSystem);
    return CoordinateSystem.fromId(id);
  }

  static Future<void> setCoordinateSystem(CoordinateSystem system) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCoordinateSystem, system.id);
    activeSystemNotifier.value = system;
  }
}
