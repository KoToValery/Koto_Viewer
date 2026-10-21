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

/// Central repository and library manager for standard and custom architectural components.
class ComponentLibraryService extends ChangeNotifier {
  static final ComponentLibraryService instance = ComponentLibraryService._internal();
  ComponentLibraryService._internal();

  static const String _storageKey = 'architect_component_custom_scripts_v1';

  final List<ArchitectComponentDefinition> _standardDefinitions = [
    // Sanitary
    SanitaryToiletWallHung(),
    SanitaryToiletFloorStanding(),
    SanitaryWashbasinCabinet(),
    SanitaryBathtub(),
    SanitaryShower(),
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
  bool _isLoaded = false;

  late ArchitectComponentDefinition _activeDefinition;
  Map<String, dynamic> _activeParameters = {};

  ArchitectComponentDefinition get activeDefinition {
    if (!_isLoaded) _initDefaults();
    return _activeDefinition;
  }

  Map<String, dynamic> get activeParameters {
    if (!_isLoaded) _initDefaults();
    return _activeParameters;
  }

  void _initDefaults() {
    _activeDefinition = _standardDefinitions.first;
    _activeParameters = Map.of(_activeDefinition.defaultParameters);
  }

  /// Initializes the service and loads custom components from persistent storage.
  Future<void> init() async {
    if (_isLoaded) return;
    _initDefaults();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList != null && rawList.isNotEmpty) {
        _customScripted.clear();
        for (final script in rawList) {
          try {
            final def = ParametricScriptParser.parse(script);
            _customScripted.add(def);
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
    if (!_isLoaded) _initDefaults();
    return [..._standardDefinitions, ..._customScripted];
  }

  /// Finds a definition by ID.
  ArchitectComponentDefinition? findDefinition(String id) {
    return getAllDefinitions().firstWhere(
      (d) => d.id == id,
      orElse: () => _standardDefinitions.first,
    );
  }

  /// Filter definitions by architectural category.
  List<ArchitectComponentDefinition> getByCategory(ArchitectComponentCategory cat) {
    return getAllDefinitions().where((d) => d.category == cat).toList();
  }

  /// Sets the currently active component for placement.
  void setActiveDefinition(
    ArchitectComponentDefinition def, {
    Map<String, dynamic>? parameters,
  }) {
    _activeDefinition = def;
    _activeParameters = parameters != null
        ? Map.of(parameters)
        : Map.of(def.defaultParameters);
    notifyListeners();
  }

  /// Updates an active parameter value (e.g. while editing in HUD or inspector).
  void updateActiveParameter(String key, dynamic value) {
    _activeParameters[key] = value;
    notifyListeners();
  }

  /// Saves a new custom scripted definition to persistent storage.
  Future<void> saveCustomScript(String scriptJson) async {
    final def = ParametricScriptParser.parse(scriptJson);
    final idx = _customScripted.indexWhere((c) => c.id == def.id);
    if (idx >= 0) {
      _customScripted[idx] = def;
    } else {
      _customScripted.add(def);
    }
    await _persistCustomScripts();
    notifyListeners();
  }

  /// Deletes a custom scripted definition.
  Future<void> deleteCustomScript(String id) async {
    _customScripted.removeWhere((c) => c.id == id);
    await _persistCustomScripts();
    if (_activeDefinition.id == id) {
      _initDefaults();
    }
    notifyListeners();
  }

  Future<void> _persistCustomScripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scripts = _customScripted.map((c) => c.rawSourceJson).toList();
      await prefs.setStringList(_storageKey, scripts);
    } catch (e) {
      debugPrint('Failed to persist custom component scripts: $e');
    }
  }
}
