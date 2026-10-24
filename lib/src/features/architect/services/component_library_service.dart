// === SECTION: ARCHITECTURAL COMPONENT LIBRARY SERVICE ===
// Table of Contents:
// 1. SERVICE INITIALIZATION & PERSISTENCE
// 2. STANDARD CATALOG REGISTRY
// 3. QUERY & FILTER METHODS
// 4. ACTIVE SELECTION STATE & CRUD

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/definitions/furniture_components.dart';
import '../components/definitions/kitchen_components.dart';
import '../components/definitions/sanitary_components.dart';
import '../components/dsl/parametric_script_parser.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';
import 'component_geometry_cache.dart';

/// Central repository and library manager for standard and custom architectural components.
class ComponentLibraryService extends ChangeNotifier {
  static final ComponentLibraryService instance =
      ComponentLibraryService._internal();
  ComponentLibraryService._internal();

  static const String _storageKey = 'architect_component_custom_scripts_v1';

  final List<ArchitectComponentDefinition> _standardDefinitions = [
    // Sanitary
    SanitaryToiletWallHung(),
    SanitaryToiletFloorStanding(),
    SanitaryWashbasinCabinet(),
    SanitaryBathtub(),
    SanitaryShower(),
    SanitaryLinearDrain(),
    SanitaryFloorDrain(),
    // Furniture
    FurnitureBedDouble(),
    FurnitureBedSingle(),
    FurnitureWardrobe(),
    FurnitureDiningTableSet(),
    FurnitureSofa(),
    FurnitureOfficeDesk(),
    // Kitchen
    KitchenBaseCabinet(),
    KitchenSinkCabinet(),
    KitchenRefrigerator(),
    KitchenCooktopOven(),
  ];

  final List<ScriptedComponentDefinition> _customScripted = [];
  // Old placed instances retain their original countertop/table dimensions.
  final Map<String, ArchitectComponentDefinition> _legacyDefinitions = {
    'furniture_dining_table': FurnitureDiningTableSet(legacyDimensions: true),
    'sanitary_washbasin_cabinet': SanitaryWashbasinCabinet(
      legacyDimensions: true,
    ),
    'kitchen_sink_cabinet': KitchenSinkCabinet(legacyDimensions: true),
  };
  bool _isLoaded = false;
  Future<void>? _initialization;

  ArchitectComponentDefinition? _activeDefinition;
  Map<String, dynamic> _activeParameters = {};

  ArchitectComponentDefinition get activeDefinition {
    if (_activeDefinition == null) _initDefaults();
    return _activeDefinition!;
  }

  Map<String, dynamic> get activeParameters {
    if (_activeDefinition == null) _initDefaults();
    return Map.unmodifiable(_activeParameters);
  }

  void _initDefaults() {
    _activeDefinition = _standardDefinitions.first;
    _activeParameters = Map.of(_activeDefinition!.defaultParameters);
  }

  /// Initializes the service and loads custom components from persistent storage.
  Future<void> init() => _initialization ??= _load();

  Future<void> _load() async {
    if (_isLoaded) return;
    if (_activeDefinition == null) _initDefaults();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList != null && rawList.isNotEmpty) {
        _customScripted.clear();
        for (final script in rawList) {
          try {
            final def = ParametricScriptParser.parse(script);
            if (!_standardDefinitions.any((d) => d.id == def.id) &&
                !_legacyDefinitions.containsKey(def.id)) {
              _customScripted.removeWhere((d) => d.id == def.id);
              _customScripted.add(def);
            }
          } catch (e) {
            debugPrint('Failed to parse custom component script: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('ComponentLibraryService init error: $e');
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// All registered component definitions (built-in followed by user custom).
  List<ArchitectComponentDefinition> getAllDefinitions() {
    return [..._standardDefinitions, ..._customScripted];
  }

  /// Finds a definition by ID.
  ArchitectComponentDefinition? findDefinition(String id) {
    return getAllDefinitions().where((d) => d.id == id).firstOrNull ??
        _legacyDefinitions[id];
  }

  /// Filter definitions by architectural category.
  List<ArchitectComponentDefinition> getByCategory(
    ArchitectComponentCategory cat,
  ) {
    return getAllDefinitions().where((d) => d.category == cat).toList();
  }

  /// Sets the currently active component for placement.
  void setActiveDefinition(
    ArchitectComponentDefinition def, {
    Map<String, dynamic>? parameters,
  }) {
    _activeDefinition = def;
    _activeParameters = {...def.defaultParameters, ...?parameters};
    notifyListeners();
  }

  /// Updates an active parameter value (e.g. while editing in HUD or inspector).
  void updateActiveParameter(String key, dynamic value) {
    if (_activeDefinition == null) _initDefaults();
    _activeParameters[key] = value;
    notifyListeners();
  }

  void setActiveParameters(Map<String, dynamic> parameters) {
    _activeParameters = {...activeDefinition.defaultParameters, ...parameters};
    notifyListeners();
  }

  /// Saves a new custom scripted definition to persistent storage.
  Future<void> saveCustomScript(String scriptJson) async {
    await init();
    final def = ParametricScriptParser.parse(scriptJson);
    if (_standardDefinitions.any((s) => s.id == def.id) ||
        _legacyDefinitions.containsKey(def.id)) {
      throw const FormatException('A built-in component cannot be overwritten');
    }
    final idx = _customScripted.indexWhere((c) => c.id == def.id);
    final previous = List<ScriptedComponentDefinition>.of(_customScripted);
    if (idx >= 0) {
      _customScripted[idx] = def;
    } else {
      _customScripted.add(def);
    }
    try {
      await _persistCustomScripts();
    } catch (_) {
      _customScripted
        ..clear()
        ..addAll(previous);
      rethrow;
    }
    ComponentGeometryCache.instance.clear();
    if (_activeDefinition?.id == def.id) setActiveDefinition(def);
    notifyListeners();
  }

  /// Deletes a custom scripted definition.
  Future<void> deleteCustomScript(String id) async {
    await init();
    final previous = List<ScriptedComponentDefinition>.of(_customScripted);
    _customScripted.removeWhere((c) => c.id == id);
    try {
      await _persistCustomScripts();
    } catch (_) {
      _customScripted
        ..clear()
        ..addAll(previous);
      rethrow;
    }
    ComponentGeometryCache.instance.clear();
    if (_activeDefinition?.id == id) {
      _initDefaults();
    }
    notifyListeners();
  }

  Future<void> _persistCustomScripts() async {
    final prefs = await SharedPreferences.getInstance();
    final scripts = _customScripted.map((c) => c.rawSourceJson).toList();
    if (!await prefs.setStringList(_storageKey, scripts)) {
      throw StateError('Could not persist component library');
    }
  }
}
