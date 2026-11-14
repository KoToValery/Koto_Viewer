import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import 'architect_railing_catalog.dart';

/// Catalog metadata is independent of translated names and project snapshots.
enum ArchitectWallFamily {
  brick,
  aerated,
  concrete,
  plasterboard,
  brickEps,
  brickWool,
  aeratedWool,
  concreteWool,
  sandwich,
  logs,
}

class ArchitectWallTemplate {
  final ArchitectWallFamily family;
  final ArchitectWallType type;

  /// Main dimensions only; complete layer thicknesses remain in [type].
  final List<double> dimensions;
  const ArchitectWallTemplate(this.family, this.type, this.dimensions);
}

/// Generic editable drawing assemblies, without certified performance claims.
/// Browsing this library never mutates a saved project or its existing types.
class ArchitectWallLibrary {
  static ArchitectMaterialLayer _layer(
    String id,
    ArchitectMaterial material,
    ArchitectLayerRole role,
    double thickness,
  ) => ArchitectMaterialLayer(
    id: id,
    material: material,
    role: role,
    thickness: thickness,
  );

  static ArchitectWallTemplate _masonry(
    String id,
    ArchitectWallFamily family,
    ArchitectMaterial core,
    double depth, {
    ArchitectMaterial? insulation,
    double insulationDepth = 0,
  }) {
    final exterior = insulation != null;
    final layers = List<ArchitectMaterialLayer>.unmodifiable([
      if (insulation != null)
        _layer(
          'insulation',
          insulation,
          ArchitectLayerRole.insulation,
          insulationDepth,
        ),
      _layer('core', core, ArchitectLayerRole.core, depth),
    ]);
    return ArchitectWallTemplate(
      family,
      ArchitectWallType(
        id: id,
        name: '',
        usage: exterior ? WallUsage.exterior : WallUsage.interior,
        totalThickness: layers.fold(0, (sum, l) => sum + l.thickness),
        layers: layers,
      ),
      List<double>.unmodifiable([depth, if (exterior) insulationDepth]),
    );
  }

  static ArchitectWallTemplate _stud(
    String id,
    double core, {
    bool doubleBoard = false,
  }) {
    final layers = List<ArchitectMaterialLayer>.unmodifiable([
      _layer(
        'board_a',
        ArchitectMaterial.plasterboard,
        ArchitectLayerRole.finish,
        .0125,
      ),
      if (doubleBoard)
        _layer(
          'board_a_inner',
          ArchitectMaterial.plasterboard,
          ArchitectLayerRole.finish,
          .0125,
        ),
      _layer('frame', ArchitectMaterial.panel, ArchitectLayerRole.core, core),
      if (doubleBoard)
        _layer(
          'board_b_inner',
          ArchitectMaterial.plasterboard,
          ArchitectLayerRole.finish,
          .0125,
        ),
      _layer(
        'board_b',
        ArchitectMaterial.plasterboard,
        ArchitectLayerRole.finish,
        .0125,
      ),
    ]);
    return ArchitectWallTemplate(
      ArchitectWallFamily.plasterboard,
      ArchitectWallType(
        id: id,
        name: '',
        usage: WallUsage.interior,
        totalThickness: core + (doubleBoard ? .05 : .025),
        layers: layers,
        system: ArchitectWallSystem(
          kind: ArchitectWallSystemKind.studFrame,
          insulationDepth: doubleBoard ? .10 : .05,
        ),
      ),
      List<double>.unmodifiable([core + (doubleBoard ? .05 : .025)]),
    );
  }

  static ArchitectWallTemplate _sandwich(String id, double depth) =>
      ArchitectWallTemplate(
        ArchitectWallFamily.sandwich,
        ArchitectWallType(
          id: id,
          name: '',
          usage: WallUsage.exterior,
          totalThickness: depth,
          system: const ArchitectWallSystem(
            kind: ArchitectWallSystemKind.sandwichPanels,
          ),
          layers: List<ArchitectMaterialLayer>.unmodifiable([
            _layer(
              'outer_skin',
              ArchitectMaterial.steel,
              ArchitectLayerRole.finish,
              .0005,
            ),
            _layer(
              'panel_core',
              ArchitectMaterial.pir,
              ArchitectLayerRole.core,
              depth - .001,
            ),
            _layer(
              'inner_skin',
              ArchitectMaterial.steel,
              ArchitectLayerRole.finish,
              .0005,
            ),
          ]),
        ),
        List<double>.unmodifiable([depth]),
      );

  static ArchitectWallTemplate _logs(String id, double diameter) =>
      ArchitectWallTemplate(
        ArchitectWallFamily.logs,
        ArchitectWallType(
          id: id,
          name: '',
          usage: WallUsage.exterior,
          totalThickness: diameter,
          system: const ArchitectWallSystem(
            kind: ArchitectWallSystemKind.roundLogs,
          ),
          layers: List<ArchitectMaterialLayer>.unmodifiable([
            _layer(
              'log',
              ArchitectMaterial.timber,
              ArchitectLayerRole.core,
              diameter,
            ),
          ]),
        ),
        List<double>.unmodifiable([diameter]),
      );

  static final List<ArchitectWallTemplate> templates = List.unmodifiable([
    _masonry(
      'factory_brick_120',
      ArchitectWallFamily.brick,
      ArchitectMaterial.brick,
      .12,
    ),
    _masonry(
      'factory_brick_250',
      ArchitectWallFamily.brick,
      ArchitectMaterial.brick,
      .25,
    ),
    _masonry(
      'factory_aerated_100',
      ArchitectWallFamily.aerated,
      ArchitectMaterial.aeratedConcrete,
      .10,
    ),
    _masonry(
      'factory_aerated_150',
      ArchitectWallFamily.aerated,
      ArchitectMaterial.aeratedConcrete,
      .15,
    ),
    _masonry(
      'factory_concrete_200',
      ArchitectWallFamily.concrete,
      ArchitectMaterial.concrete,
      .20,
    ),
    _masonry(
      'factory_concrete_250',
      ArchitectWallFamily.concrete,
      ArchitectMaterial.concrete,
      .25,
    ),
    _stud('factory_stud_100', .075),
    _stud('factory_stud_150', .10, doubleBoard: true),
    _masonry(
      'factory_brick_250_eps_120',
      ArchitectWallFamily.brickEps,
      ArchitectMaterial.brick,
      .25,
      insulation: ArchitectMaterial.eps,
      insulationDepth: .12,
    ),
    _masonry(
      'factory_brick_250_eps_150',
      ArchitectWallFamily.brickEps,
      ArchitectMaterial.brick,
      .25,
      insulation: ArchitectMaterial.eps,
      insulationDepth: .15,
    ),
    _masonry(
      'factory_brick_250_wool_150',
      ArchitectWallFamily.brickWool,
      ArchitectMaterial.brick,
      .25,
      insulation: ArchitectMaterial.stoneWool,
      insulationDepth: .15,
    ),
    _masonry(
      'factory_aerated_250_wool_120',
      ArchitectWallFamily.aeratedWool,
      ArchitectMaterial.aeratedConcrete,
      .25,
      insulation: ArchitectMaterial.stoneWool,
      insulationDepth: .12,
    ),
    _masonry(
      'factory_concrete_200_wool_150',
      ArchitectWallFamily.concreteWool,
      ArchitectMaterial.concrete,
      .20,
      insulation: ArchitectMaterial.stoneWool,
      insulationDepth: .15,
    ),
    _sandwich('factory_sandwich_100', .10),
    _sandwich('factory_sandwich_150', .15),
    _logs('factory_logs_200', .20),
    _logs('factory_logs_240', .24),
  ]);

  static final List<ArchitectWallType> presets = List.unmodifiable([
    for (final template in templates) template.type,
  ]);

  static ArchitectWallTemplate? descriptorFor(ArchitectWallType type) {
    final match = templates
        .where((t) => t.type.id == (type.labelId ?? type.id))
        .firstOrNull;
    if (match == null ||
        match.type.system.kind != type.system.kind ||
        match.type.resolvedLocation != type.resolvedLocation ||
        match.type.isParapet != type.isParapet) {
      return null;
    }
    String materials(ArchitectWallType value) => value.resolvedLayers
        .map((l) => '${l.material.name}/${l.role.name}')
        .join('|');
    // A saved factory ID may have been repurposed into a different assembly.
    return materials(match.type) == materials(type) ? match : null;
  }

  static const String customStorageKey = 'architect_custom_wall_types_v1';
  static final List<ArchitectWallType> _customTypes = [];

  /// Returns whether [id] belongs to a built-in factory wall or railing preset.
  static bool isFactoryId(String id) => ArchitectWallType.isFactoryId(id);

  /// Cached globally shared user-created wall types loaded across projects.
  static List<ArchitectWallType> get customTypes =>
      List.unmodifiable(_customTypes);

  @visibleForTesting
  static void clearCustomCacheForTesting() => _customTypes.clear();

  /// Loads custom wall types saved across all projects from [SharedPreferences].
  static Future<List<ArchitectWallType>> loadCustomTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(customStorageKey);
    final loaded = <String, ArchitectWallType>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final entry in jsonDecode(raw) as List) {
          try {
            final type = ArchitectWallType.fromJson(
              Map<String, dynamic>.from(entry as Map),
            );
            if (!type.isFactoryPreset && type.isCatalogType) {
              loaded[type.id] = type;
            }
          } on Object {
            /* Ignore damaged custom wall entry. */
          }
        }
      } on Object {
        /* Ignore damaged custom wall library payload. */
      }
    }
    _customTypes
      ..clear()
      ..addAll(loaded.values);
    return customTypes;
  }

  /// Persists a user-created custom wall type so it is available in all projects.
  static Future<bool> saveCustomType(ArchitectWallType type) async {
    if (type.isFactoryPreset || !type.isCatalogType) return false;
    final entries = await loadCustomTypes();
    final merged = <String, ArchitectWallType>{
      for (final existing in entries) existing.id: existing,
      type.id: type,
    };
    _customTypes
      ..clear()
      ..addAll(merged.values);
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      customStorageKey,
      jsonEncode(_customTypes.map((t) => t.toJson()).toList()),
    );
  }

  /// Deletes a user-created custom wall type by [id]; factory presets cannot be deleted.
  static Future<bool> deleteCustomType(String id) async {
    if (isFactoryId(id)) return false;
    final entries = await loadCustomTypes();
    final next = entries.where((t) => t.id != id).toList();
    _customTypes
      ..clear()
      ..addAll(next);
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      customStorageKey,
      jsonEncode(_customTypes.map((t) => t.toJson()).toList()),
    );
  }

  /// Imports any custom catalog wall types from [project] into global storage.
  static Future<void> syncFromProject(ArchitectProject project) async {
    final customInProject = project.wallTypes.where(
      (t) => t.isCatalogType && !t.isFactoryPreset,
    );
    if (customInProject.isEmpty) {
      await loadCustomTypes();
      return;
    }
    final existing = await loadCustomTypes();
    final merged = <String, ArchitectWallType>{
      for (final type in existing) type.id: type,
    };
    var changed = false;
    for (final type in customInProject) {
      if (!merged.containsKey(type.id)) {
        merged[type.id] = type;
        changed = true;
      }
    }
    if (!changed) return;
    _customTypes
      ..clear()
      ..addAll(merged.values);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      customStorageKey,
      jsonEncode(_customTypes.map((t) => t.toJson()).toList()),
    );
  }

  /// Returns [project] with globally saved custom wall types merged in.
  static ArchitectProject mergeCustomTypes(ArchitectProject project) {
    if (_customTypes.isEmpty) return project;
    final existingIds = {for (final t in project.wallTypes) t.id};
    final additions = [
      for (final t in _customTypes)
        if (!existingIds.contains(t.id) && t.isCatalogType) t,
    ];
    if (additions.isEmpty) return project;
    return project.copyWith(wallTypes: [...project.wallTypes, ...additions]);
  }

  static List<ArchitectWallType> available(
    Iterable<ArchitectWallType> projectTypes,
  ) {
    final project = projectTypes.where((type) => type.isCatalogType).toList();
    return List.unmodifiable(
      {
        if (!project.any((type) => type.isCatalogType))
          for (final type in ArchitectWallType.standardCatalog(
            includeSpecial: true,
          ))
            type.id: type,
        for (final type in presets) type.id: type,
        for (final type in ArchitectRailingCatalog.presets) type.id: type,
        for (final type in _customTypes)
          if (type.isCatalogType) type.id: type,
        // Saved definitions always take precedence, even when a factory ID was edited.
        for (final type in project) type.id: type,
      }.values,
    );
  }
}
